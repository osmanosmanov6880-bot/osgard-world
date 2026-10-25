/**
 * OSA CINEMA V33 — guarded offline first-run for the V31 owner control room.
 * No uploads, file publication, fake rights confirmations, or film creation.
 * All owner films stay on disk and are checked by the existing V28 pipeline.
 */
import { constants } from 'node:fs'
import { lstat, mkdir, readFile, readdir, realpath, rm, rmdir, writeFile } from 'node:fs/promises'
import { createHash, randomBytes } from 'node:crypto'
import { spawn, spawnSync } from 'node:child_process'
import { createInterface } from 'node:readline/promises'
import { stdin, stdout } from 'node:process'
import { resolve, join, relative, isAbsolute, dirname, sep } from 'node:path'
import { fileURLToPath } from 'node:url'
import { buildPrivateCandidatePlan, validateCanonical } from './osa-cinema-v28-final-intake.mjs'
import { startPrivateOwnerConsole } from './osa-cinema-v31-owner-console.mjs'

const MANIFEST = fileURLToPath(new URL('../docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json', import.meta.url))
const HISTORICAL_QA = fileURLToPath(new URL('../docs/OSA_CINEMA_V18_PRIVATE_FOUR_TRACK_QA.json', import.meta.url))
const PACKAGE_ROOT = resolve(fileURLToPath(new URL('..', import.meta.url)))
const HEX = /^[a-f0-9]{64}$/
const MAX_DIAG = 180_000
const NODE_MIN = 22
const RELEASE = Object.freeze({publicationAuthorized:false, rightsCleared:false, paidCheckoutEnabled:false, releaseDecision:'NO_GO'})

function assert(condition, message) {if(!condition)throw Error(message)}
function nested(a,b){const rel=relative(a,b);return rel===''||(!rel.startsWith('..'+sep)&&rel!=='..'&&!isAbsolute(rel))}
function guardAbsolute(path,label){
  assert(typeof path==='string'&&isAbsolute(path)&&!path.includes('\0'),`Укажите абсолютный путь для ${label}`)
  // UNC shares, extended Windows network namespaces and POSIX // hosts are not owner-only disks.
  assert(!path.replace(/\\/g,'/').startsWith('//'),`${label}: сетевые UNC-пути и перенаправления запрещены; выберите локальный диск`)
  return resolve(path)
}
function privateOwnerPath(path,label){
  const target=guardAbsolute(path,label)
  assert(!nested(PACKAGE_ROOT,target)&&!nested(target,PACKAGE_ROOT),
    `${label}: закрытые фильмы и отчёты должны быть ВНЕ папки программы и её родительских каталогов`)
  return target
}
/** Refuse symlinked ancestors, not only a symlink at the final directory.
 * For example: /private/link/film is not safe merely because film itself is real.
 * lstat every existing ancestor, even when the final owner folder is not created yet.
 */
export async function rejectLinkedAncestors(path,label='Приватный путь'){
  const final=resolve(path)
  const segments=[]
  for(let part=final;;part=dirname(part)){
    segments.push(part)
    if(dirname(part)===part)break
  }
  for(const part of segments.reverse()){
    let st
    try{st=await lstat(part)}catch(e){if(e.code==='ENOENT')continue;throw e}
    assert(!st.isSymbolicLink(),`${label}: символическая ссылка в родительском пути запрещена: ${part}`)
    assert(st.isDirectory(),`${label}: родительский путь не является папкой: ${part}`)
  }
  return final
}
async function existsDir(path, label,{allowMissing=false}={}) {
  try{
    const st=await lstat(path)
    assert(st.isDirectory()&&!st.isSymbolicLink(),`${label} не должна быть ссылкой или файлом`)
    // Existing directories must be owner-only: mode 0700, or stricter.
    // Do not silently chmod an owner's pre-existing shared directory.
    if(process.platform!=='win32')
      assert((st.mode&0o077)===0,
        `${label}: папка доступна другим пользователям; задайте chmod 700 и повторите: ${path}`)
    return realpath(path)
  }catch(err){if(err.code==='ENOENT'&&allowMissing)return null;throw err}
}
/**
 * Create only the missing directories, one by one, remembering every newly
 * created component. A failed setup can then undo only empty directories it
 * created; existing owner data is never deleted or chmod-ed.
 * This is a best-effort local filesystem transaction, not an OS-wide lock.
 */
async function ensureOwnerDirectory(path,label,created){
  const already=await existsDir(path,label,{allowMissing:true})
  if(already)return already
  const missing=[]
  for(let part=path;;part=dirname(part)){
    try{
      const ancestor=await lstat(part)
      assert(ancestor.isDirectory()&&!ancestor.isSymbolicLink(),'Unsafe existing parent for '+label)
      break
    }catch(e){if(e.code!=='ENOENT')throw e}
    missing.push(part)
    assert(dirname(part)!==part,'No real parent directory available for '+label)
  }
  for(const part of missing.reverse()){
    await mkdir(part,{mode:0o700})
    created.push(part)
    await rejectLinkedAncestors(part,label)
    await existsDir(part,label)
  }
  return existsDir(path,label)
}
async function rollbackNewDirectories(created){
  for(const path of [...created].reverse()){
    // rmdir refuses nonempty directories, so pre-existing or concurrently
    // created user contents are never recursively removed.
    try{await rmdir(path)}catch{/* Preserve unexpected contents and original error. */}
  }
}
async function readCanonical(){const inventory=JSON.parse(await readFile(MANIFEST,'utf8'));return validateCanonical(inventory)}
/** Package fixture awareness: some historic V18 docs in earlier owner ZIPs are test-only. */
export async function historicalProvenanceWarning({qaPath=HISTORICAL_QA}={}){
  try{
    const qa=JSON.parse(await readFile(qaPath,'utf8'))
    const hash=qa.sha256||''
    const placeholder=/^([a-f0-9])\1{63}$/.test(hash)
    const emptyTracks=!Array.isArray(qa.audioTracks)||qa.audioTracks.length!==4||
      qa.audioTracks.some(track=>!track||Object.keys(track).length===0)
    if(placeholder||emptyTracks)return {status:'TEST_FIXTURE_NOT_ACTUAL_MEDIA_EVIDENCE',verifiedRealPrivateMaster:false,
      detail:'The bundled V18 engineering fixture cannot prove real recorded-film sound/picture provenance.'}
    return {status:'QA_METADATA_PRESENT_NOT_INDEPENDENTLY_REVIEWED',verifiedRealPrivateMaster:false,
      detail:'Hashes in a file alone cannot prove that the underlying master has been independently reviewed.'}
  }catch{return {status:'HISTORICAL_QA_MISSING_OR_INVALID',verifiedRealPrivateMaster:false,
      detail:'Authentic private historical master evidence must be supplied and reviewed separately.'}}
}
function runVersion(command,args=['-version']){
  const result=spawnSync(command,args,{encoding:'utf8',timeout:12000,windowsHide:true,maxBuffer:120000})
  if(result.error||result.status!==0)return {available:false,version:null}
  const line=(result.stdout||result.stderr||'').split(/\r?\n/)[0].slice(0,140)
  return {available:true,version:line}
}
export function verifyTools({checkFFmpeg=true}={}){
  const node=Number(process.versions.node.split('.')[0])
  const ffmpeg=checkFFmpeg?runVersion('ffmpeg'): {available:true,version:'not checked'}
  const ffprobe=checkFFmpeg?runVersion('ffprobe'): {available:true,version:'not checked'}
  return {node:{available:Number.isInteger(node)&&node>=NODE_MIN,version:process.versions.node},ffmpeg,ffprobe}
}
export async function preparePrivateWorkspace({root,reportsRoot}){
  const media=privateOwnerPath(root,'папки фильма'),reports=privateOwnerPath(reportsRoot,'папки отчётов')
  assert(!nested(media,reports)&&!nested(reports,media),'Папка отчётов должна находиться отдельно от папки фильма')
  // Resolve the immutable expected list before creating any private directory.
  const expected=(await readCanonical()).flatMap(a=>[`masters/${a.id}.mp4`,`captions/${a.id}.vtt`])
  const proposed=[
    [media,'Папка фильма'],[reports,'Папка отчётов'],
    [join(media,'masters'),'Папка мастеров'],
    [join(media,'captions'),'Папка субтитров'],
  ]
  // V33: complete READ-ONLY preflight of every existing target and ancestor.
  // V32.1 preflight covered just the two roots, so a bad existing masters or
  // captions folder could cause setup to fail after another folder was made.
  for(const [path,label] of proposed){
    await rejectLinkedAncestors(path,label)
    await existsDir(path,label,{allowMissing:true})
  }
  const created=[]
  try{
    const mediaReal=await ensureOwnerDirectory(media,'Папка фильма',created)
    const reportsReal=await ensureOwnerDirectory(reports,'Папка отчётов',created)
    await rejectLinkedAncestors(mediaReal,'Папка фильма')
    await rejectLinkedAncestors(reportsReal,'Папка отчётов')
    assert(!nested(mediaReal,reportsReal)&&!nested(reportsReal,mediaReal),'Обнаружены вложенные/совпадающие реальные папки')
    await ensureOwnerDirectory(join(mediaReal,'masters'),'Папка мастеров',created)
    await ensureOwnerDirectory(join(mediaReal,'captions'),'Папка субтитров',created)
    return {...RELEASE,mediaRoot:mediaReal,reportsRoot:reportsReal,expected,filesCreated:0}
  }catch(error){
    await rollbackNewDirectories(created)
    throw error
  }
}

async function checkCandidate(file,extension){
  try{
    const st=await lstat(file)
    if(!st.isFile()||st.isSymbolicLink())return 'symlink_or_not_file'
    const limit=extension==='mp4'?4_000_000_000:2_000_000
    if(st.size<=0||st.size>limit)return 'empty_or_oversized'
    if(extension==='vtt'){
      const f=await readFile(file,'utf8')
      if(!f.replace(/^\uFEFF/,'').startsWith('WEBVTT'))return 'invalid_webvtt_header'
    }
    return null
  }catch(err){if(err.code==='ENOENT')return 'missing';throw err}
}

/** A cheap diagnostic (metadata + directory inventory); deep=true calls the actual V28 codec/VTT/SHA verifier. */
export async function inspectOwnerWorkspace({root,reportsRoot,deep=false,checkFFmpeg=true}){
  const media=privateOwnerPath(root,'папки фильма'),reports=privateOwnerPath(reportsRoot,'папки отчётов')
  assert(!nested(media,reports)&&!nested(reports,media),'Папки фильма и отчётов не должны совпадать или находиться одна в другой')
  await rejectLinkedAncestors(media,'Папка фильма')
  await rejectLinkedAncestors(reports,'Папка отчётов')
  const tools=verifyTools({checkFFmpeg})
  const blockers=[]
  if(!tools.node.available)blockers.push('node22_required')
  if(!tools.ffmpeg.available)blockers.push('ffmpeg_missing')
  if(!tools.ffprobe.available)blockers.push('ffprobe_missing')
  const mediaReal=await existsDir(media,'Папка фильма',{allowMissing:true})
  const reportsReal=await existsDir(reports,'Папка отчётов',{allowMissing:true})
  if(!mediaReal)blockers.push('private_media_root_missing')
  if(!reportsReal)blockers.push('separate_reports_root_missing')
  if(mediaReal&&reportsReal)assert(!nested(mediaReal,reportsReal)&&!nested(reportsReal,mediaReal),'Две реальные папки не должны пересекаться')
  const expected=(await readCanonical()).flatMap(a=>[{name:`masters/${a.id}.mp4`,kind:'mp4'},{name:`captions/${a.id}.vtt`,kind:'vtt'}])
  const missing=[],invalid=[],unexpected=[],available=[]
  if(mediaReal){
    for(const dirName of ['masters','captions']){
      const dir=join(mediaReal,dirName)
      await rejectLinkedAncestors(dir,`Папка ${dirName}`)
      const safe=await existsDir(dir,`Папка ${dirName}`,{allowMissing:true})
      if(!safe){blockers.push(dirName+'_directory_missing');continue}
      const expectedHere=new Set(expected.filter(e=>e.name.startsWith(dirName+'/')).map(e=>e.name.split('/')[1]))
      for(const fileName of await readdir(dir))if(!expectedHere.has(fileName))unexpected.push(`${dirName}/${fileName}`)
    }
    for(const item of expected){
      const status=await checkCandidate(join(mediaReal,...item.name.split('/')),item.kind)
      if(status==='missing')missing.push(item.name)
      else if(status)invalid.push({file:item.name,reason:status})
      else available.push(item.name)
    }
  }else missing.push(...expected.map(x=>x.name))
  if(unexpected.length)blockers.push('unexpected_media_or_caption_files')
  if(missing.length)blockers.push('required_media_or_captions_missing')
  if(invalid.length)blockers.push('unsafe_or_invalid_file')
  let deepVerification=null
  if(deep&&blockers.length===0){
    try{
      const assets=await buildPrivateCandidatePlan(mediaReal,{assets:await readCanonical()})
      assert(assets.assets.length===4&&assets.publicationAuthorized===false,'V28 strict intake must confirm 4 technical candidates')
      deepVerification=assets.assets.map(a=>({id:a.id,locale:a.locale,edition:a.edition,mp4Sha256:a.masterSha256,mp4Bytes:a.masterBytes,vttSha256:a.captionSha256,durationSeconds:a.durationSeconds}))
    }catch(e){blockers.push('v28_full_media_validation_failed');invalid.push({file:'V28_DEEP_VERIFICATION',reason:String(e.message).slice(0,350)})}
  }
  const readiness=blockers.length===0 && (!deep||deepVerification?.length===4)
  const historicalProvenance=await historicalProvenanceWarning()
  return {schemaVersion:1,project:'OSA CINEMA',stage:'V32_LOCAL_OWNER_STARTUP_DIAGNOSTIC',checkedAt:new Date().toISOString(),...RELEASE,historicalProvenance,
    readyForPrivateTechnicalPreflight:readiness,deepVerified:Boolean(deepVerification),tools,
    expectedCount:8,presentCount:available.length,missing,invalid,unexpected,blockers,
    mediaCandidates:deepVerification||[],note:'Technical readiness does NOT verify spoken language, rights or publisher authorization.'}
}

/** Pairwise write with cleanup: a missing checksum must not leave an orphan
 * private report that looks finalized. A custom writer is only used by tests.
 */
export async function savePrivateDiagnostic({diagnostic,reportsRoot,writeFileImpl=writeFile}){
  const path=privateOwnerPath(reportsRoot,'папки отчётов')
  await rejectLinkedAncestors(path,'Папка отчётов')
  const reports=await existsDir(path,'Папка отчётов')
  assert(diagnostic?.stage==='V32_LOCAL_OWNER_STARTUP_DIAGNOSTIC'&&
    diagnostic.publicationAuthorized===false&&diagnostic.rightsCleared===false&&
    diagnostic.paidCheckoutEnabled===false&&diagnostic.releaseDecision==='NO_GO',
    'Refuse an untrusted or publisher-approved diagnostic')
  const base='OSA-V32-DIAGNOSTIC-'+new Date().toISOString().replace(/[-:.TZ]/g,'').slice(0,14)+'-'+randomBytes(5).toString('hex')
  const content=JSON.stringify(diagnostic,null,2)+'\n'
  assert(Buffer.byteLength(content)<=MAX_DIAG,'Private diagnostic is too large')
  const file=join(reports,base+'.json'),sumFile=join(reports,base+'.sha256')
  const hash=createHash('sha256').update(content).digest('hex')
  assert(HEX.test(hash),'SHA256 calculation failed')
  const newFiles=[]
  try{
    await writeFileImpl(file,content,{flag:'wx',mode:0o600})
    newFiles.push(file)
    await writeFileImpl(sumFile,hash+'  '+base+'.json\n',{flag:'wx',mode:0o600})
    newFiles.push(sumFile)
    // A completed pair must be independently readable and match its digest.
    assert(createHash('sha256').update(await readFile(file)).digest('hex')===hash,
      'Diagnostic changed after being written')
    assert((await readFile(sumFile,'utf8')).trim()===hash+'  '+base+'.json',
      'Diagnostic checksum sidecar is incomplete')
    return {reportName:base+'.json',sha256:hash}
  }catch(error){
    for(const entry of newFiles.reverse()){
      try{await rm(entry,{force:true})}catch{/* Preserve original write failure. */}
    }
    throw error
  }
}

export async function openLocalConsole({root,reportsRoot,password,openBrowser=true}){
  assert(typeof password==='string'&&password.length>=16&&password.length<=256,'Используйте пароль от 16 до 256 символов')
  const diagnosis=await inspectOwnerWorkspace({root,reportsRoot,deep:true})
  assert(diagnosis.readyForPrivateTechnicalPreflight,'Не хватает материалов: '+[...diagnosis.blockers,...diagnosis.missing].join(', '))
  const service=await startPrivateOwnerConsole({root,reportsRoot,password})
  if(openBrowser){
    try{
      const args=process.platform==='win32'?['/c','start','""',service.url]:[service.url]
      const command=process.platform==='win32'?'cmd':process.platform==='darwin'?'open':'xdg-open'
      const child=spawn(command,args,{stdio:'ignore',windowsHide:true,detached:true})
      child.on('error',()=>{})
      child.unref()
    }catch{/* The URL is always printed; browser launch is optional. */}
  }
  return service
}

async function askHidden(question){
  assert(stdin.isTTY&&typeof stdin.setRawMode==='function','Пароль вводится только в интерактивном терминале')
  stdout.write(question)
  let password=''
  return new Promise((resolvePromise,rejectPromise)=>{
    const wasRaw=stdin.isRaw
    stdin.setRawMode(true)
    stdin.resume()
    const cleanup=()=>{stdin.off('data',onData);stdin.setRawMode(Boolean(wasRaw));stdout.write('\n')}
    function onData(bytes){
      const string=bytes.toString('utf8')
      for(const symbol of string){
        if(symbol==='\r'||symbol==='\n'){cleanup();resolvePromise(password);return}
        if(symbol==='\u0003'){cleanup();rejectPromise(Error('Ввод отменён'));return}
        if(symbol==='\b'||symbol==='\u007f'){password=password.slice(0,-1);continue}
        if(symbol>=' '&&password.length<256)password+=symbol
      }
    }
    stdin.on('data',onData)
  })
}
function renderStatus(d){
  stdout.write('\n=== OSA CINEMA · ПРИВАТНЫЙ КАБИНЕТ ===\n')
  stdout.write(`Инструменты: Node ${d.tools.node.version}; FFmpeg ${d.tools.ffmpeg.available?'OK':'НЕТ'}; FFprobe ${d.tools.ffprobe.available?'OK':'НЕТ'}\n`)
  stdout.write(`Материалы: ${d.presentCount}/8; закрытый статус: ${d.readyForPrivateTechnicalPreflight?'ГОТОВО К ТЕХНИЧЕСКОЙ ПРОВЕРКЕ':'НЕПОЛНЫЙ КОМПЛЕКТ'}\n`)
  for(const missing of d.missing)stdout.write('  НУЖЕН ФАЙЛ: '+missing+'\n')
  for(const issue of d.invalid)stdout.write('  ПРОБЛЕМА: '+issue.file+' ('+issue.reason+')\n')
  for(const extra of d.unexpected)stdout.write('  ЛИШНИЙ ФАЙЛ: '+extra+'\n')
  for(const b of d.blockers)if(!['required_media_or_captions_missing','unsafe_or_invalid_file','unexpected_media_or_caption_files'].includes(b))stdout.write('  ПРЕПЯТСТВИЕ: '+b+'\n')
  if(d.historicalProvenance?.status==='TEST_FIXTURE_NOT_ACTUAL_MEDIA_EVIDENCE')stdout.write('ВНИМАНИЕ: архивный V18 QA содержит тестовый пример, а не подтверждение исходного фильма.\n')
  stdout.write('ПУБЛИКАЦИЯ / ОПЛАТА: ЗАПРЕЩЕНЫ до независимых разрешений.\n')
}

async function runInteractive(){
  const input=createInterface({input:stdin,output:stdout,terminal:true})
  let root,reportsRoot
  try{
    stdout.write('OSA CINEMA · Первый запуск\nНужны две отдельные закрытые папки. Никакие фильмы не отправляются в интернет.\n')
    root=(await input.question('Полный путь к папке фильма: ')).trim().replace(/^"|"$/g,'')
    reportsRoot=(await input.question('Полный путь к папке отчётов: ')).trim().replace(/^"|"$/g,'')
  }finally{input.close()}
  const prep=await preparePrivateWorkspace({root,reportsRoot})
  stdout.write('Папки подготовлены. Файлы не создавались: нужно положить 4 настоящих MP4 и 4 WebVTT.\n')
  let d=await inspectOwnerWorkspace({root:prep.mediaRoot,reportsRoot:prep.reportsRoot})
  renderStatus(d)
  const saved=await savePrivateDiagnostic({diagnostic:d,reportsRoot:prep.reportsRoot})
  stdout.write(`Закрытый диагностический протокол: ${saved.reportName}\n`)
  if(!d.readyForPrivateTechnicalPreflight){stdout.write('Перенесите недостающие файлы в мастера/субтитры и запустите программу повторно.\n');return 2}
  stdout.write('Проверяю настоящий кодек, таймкоды и SHA-256 каждого файла…\n')
  d=await inspectOwnerWorkspace({root:prep.mediaRoot,reportsRoot:prep.reportsRoot,deep:true})
  renderStatus(d)
  if(!d.readyForPrivateTechnicalPreflight)return 2
  const password=await askHidden('Новый пароль локального кабинета (16+ символов; не показывается): ')
  const service=await openLocalConsole({root:prep.mediaRoot,reportsRoot:prep.reportsRoot,password})
  stdout.write('Кабинет открыт: '+service.url+'\nНажмите Ctrl+C для остановки; локальные видео никогда не публикуются.\n')
  await new Promise(resolvePromise=>{
    let stopping=false
    const finish=()=>{if(stopping)return;stopping=true;service.close().then(resolvePromise,resolvePromise)}
    process.once('SIGINT',finish);process.once('SIGTERM',finish)
  })
  return 0
}
function parseArgs(argv){
  if(argv.length===0)return {command:'interactive'}
  const command=argv[0]
  assert(['prepare','doctor','launch','help'].includes(command),'Команда: prepare | doctor | launch | help')
  const options={}
  for(let i=1;i<argv.length;i++){
    const key=argv[i]
    if(key==='--full'||key==='--no-browser'){assert(!options[key],'Повторный флаг');options[key]=true;continue}
    assert(['--root','--reports-root'].includes(key),'Неизвестный параметр '+key)
    const value=argv[++i]
    assert(value&&!options[key],'Не указан или повторён '+key)
    options[key]=value
  }
  if(command!=='help')assert(options['--root']&&options['--reports-root'],'Нужны --root и --reports-root')
  return {command,options}
}
async function main(){
  const opts=parseArgs(process.argv.slice(2));if(opts.command==='help'){
    stdout.write('node scripts/osa-cinema-v32-first-run.mjs prepare --root "D:\\OSA_PRIVATE\\film" --reports-root "D:\\OSA_PRIVATE_REPORTS"\n')
    stdout.write('node scripts/osa-cinema-v32-first-run.mjs doctor --root ... --reports-root ... [--full]\n')
    stdout.write('Двойной щелчок START_OSA_CINEMA.cmd запускает мастер первого запуска на Windows.\n')
    return 0
  }
  if(opts.command==='interactive')return runInteractive()
  const root=opts.options['--root'],reportsRoot=opts.options['--reports-root']
  if(opts.command==='prepare'){
    const p=await preparePrivateWorkspace({root,reportsRoot})
    stdout.write('Подготовлено: '+p.mediaRoot+' и '+p.reportsRoot+'\nОжидаются 8 настоящих файлов; ничего не создано вместо них.\n')
    return 0
  }
  if(opts.command==='doctor'){
    const d=await inspectOwnerWorkspace({root,reportsRoot,deep:Boolean(opts.options['--full'])})
    renderStatus(d)
    if(await existsDir(guardAbsolute(reportsRoot,'папки отчётов'),'Папка отчётов',{allowMissing:true})){
      const saved=await savePrivateDiagnostic({diagnostic:d,reportsRoot})
      stdout.write('Отчёт: '+saved.reportName+' / '+saved.sha256+'\n')
    }
    return d.readyForPrivateTechnicalPreflight?0:2
  }
  if(opts.command==='launch'){
    const secretValue=await askHidden('Пароль (не менее 16 символов): ')
    const service=await openLocalConsole({root,reportsRoot,password:secretValue,openBrowser:!opts.options['--no-browser']})
    stdout.write('Только локально: '+service.url+'\nДля выхода нажмите Ctrl+C.\n')
    await new Promise(resolvePromise=>{
      let stopped=false
      const f=()=>{if(stopped)return;stopped=true;service.close().then(resolvePromise,resolvePromise)}
      process.once('SIGINT',f);process.once('SIGTERM',f)
    })
  }
  return 0
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url))
  main().then(code=>{process.exitCode=code}).catch(err=>{console.error('OSA_CINEMA_V32_STOPPED: '+err.message);process.exitCode=1})
