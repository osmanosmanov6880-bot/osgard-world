import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtemp, mkdir, writeFile, readFile, readdir, symlink, rm, rename, chmod, stat, realpath } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join, dirname } from 'node:path'
import { createHash } from 'node:crypto'
import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { verifyTools, preparePrivateWorkspace, inspectOwnerWorkspace, savePrivateDiagnostic, openLocalConsole, historicalProvenanceWarning } from './osa-cinema-v32-first-run.mjs'

const sha=data=>createHash('sha256').update(data).digest('hex')
const manifestUrl=new URL('../docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json',import.meta.url)
const inventory=JSON.parse(await readFile(manifestUrl,'utf8'))
function ffmpeg(file,frequency){
  const r=spawnSync('ffmpeg',['-nostdin','-hide_banner','-loglevel','error','-filter_threads','1',
    '-f','lavfi','-i','testsrc2=s=640x360:r=10:d=1.5',
    '-f','lavfi','-i',`sine=frequency=${frequency}:sample_rate=48000:duration=1.5`,
    '-map','0:v:0','-map','1:a:0','-c:v','libx264','-threads','1','-preset','ultrafast',
    '-pix_fmt','yuv420p','-c:a','aac','-shortest','-movflags','+faststart','-y',file],
  {encoding:'utf8',timeout:65000,maxBuffer:600000})
  assert.equal(r.status,0,r.error?.message||r.stderr)
}
async function login(url,password){
  const home=await fetch(url+'/')
  assert.equal(home.status,200)
  const markup=await home.text()
  const token=markup.match(/name="csrf" value="([a-f0-9]{64})"/)?.[1]
  assert.ok(token)
  const sent=await fetch(url+'/login',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded','Origin':url},
    body:new URLSearchParams({csrf:token,password}),redirect:'manual'})
  assert.equal(sent.status,303)
  const cookie=sent.headers.get('set-cookie')?.split(';')[0]
  assert.ok(cookie)
  return cookie
}

test('V32 private first-run — real owner handoff, no fake media, no publication', {timeout:200000}, async t=>{
 const temp=await mkdtemp(join(await realpath(tmpdir()),'osa-v32-'))
 const film=join(temp,'films'), reports=join(temp,'evidence')
 try{
   await t.test('Node 22 and local FFmpeg/FFprobe are actually available',()=>{
     const result=verifyTools()
     assert.equal(result.node.available,true)
     assert.equal(result.ffmpeg.available,true)
     assert.equal(result.ffprobe.available,true)
     assert.match(result.ffmpeg.version,/ffmpeg version/i)
   })
   await t.test('prepare creates private directories but never fake MP4, captions, licenses or signatures',async()=>{
     const created=await preparePrivateWorkspace({root:film,reportsRoot:reports})
     assert.equal(created.publicationAuthorized,false)
     assert.equal(created.rightsCleared,false)
     assert.equal(created.paidCheckoutEnabled,false)
     assert.equal(created.expected.length,8)
     assert.deepEqual(await readdir(join(film,'masters')),[])
     assert.deepEqual(await readdir(join(film,'captions')),[])
     if(process.platform!=='win32')assert.equal((await stat(reports)).mode&0o777,0o700)
   })
   await t.test('diagnostic names the exact missing eight, no ready or fake approval',async()=>{
     const d=await inspectOwnerWorkspace({root:film,reportsRoot:reports})
     assert.equal(d.readyForPrivateTechnicalPreflight,false)
     assert.equal(d.presentCount,0)
     assert.equal(d.missing.length,8)
     assert.equal(d.mediaCandidates.length,0)
     assert.equal(d.publicationAuthorized,false)
     assert.equal(d.releaseDecision,'NO_GO')
     assert.ok(d.blockers.includes('required_media_or_captions_missing'))
   })
   await t.test('writes a non-overwriting private report with exact independent checksum',async()=>{
     const d=await inspectOwnerWorkspace({root:film,reportsRoot:reports})
     const x=await savePrivateDiagnostic({diagnostic:d,reportsRoot:reports})
     const file=join(reports,x.reportName), bytes=await readFile(file)
     assert.equal(sha(bytes),x.sha256)
     assert.equal((await readFile(join(reports,x.reportName.replace('.json','.sha256')),'utf8')).trim(),`${x.sha256}  ${x.reportName}`)
     assert.ok(!bytes.toString().includes(film),'No absolute owner film path in diagnostic')
     assert.ok(!bytes.toString().includes('password'),'No credentials in diagnostic')
     if(process.platform!=='win32')assert.equal((await stat(file)).mode&0o777,0o600)
   })
   await t.test('rejects nesting, shared root, or symbolic-link paths',async()=>{
     await assert.rejects(preparePrivateWorkspace({root:film,reportsRoot:join(film,'bad')}),/отдельно/)
     await assert.rejects(preparePrivateWorkspace({root:film,reportsRoot:film}),/отдельно/)
     const fake=join(temp,'symlinked')
     await symlink(film,fake)
     await assert.rejects(preparePrivateWorkspace({root:fake,reportsRoot:reports}),/ссылк/)
     await rm(fake)
   })
   await t.test('owner files cannot live in or above the software package',async()=>{
     const appRoot=dirname(fileURLToPath(new URL('../docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json',import.meta.url)))
     const packageRoot=dirname(appRoot)
     const accidental=join(packageRoot,'ACCIDENTAL_MOVIE_FOLDER')
     await assert.rejects(preparePrivateWorkspace({root:accidental,reportsRoot:reports}),/ВНЕ папки программы/)
     await assert.rejects(inspectOwnerWorkspace({root:accidental,reportsRoot:reports}),/ВНЕ папки программы/)
     await assert.rejects(preparePrivateWorkspace({root:film,reportsRoot:packageRoot}),/ВНЕ папки программы/)
     await assert.rejects(savePrivateDiagnostic({diagnostic:await inspectOwnerWorkspace({root:film,reportsRoot:reports}),reportsRoot:packageRoot}),/ВНЕ папки программы/)
     await assert.rejects(preparePrivateWorkspace({root:film,reportsRoot:dirname(packageRoot)}),/ВНЕ папки программы/)
     await assert.rejects(stat(accidental),{code:'ENOENT'},'No private directory created inside the shipped program')
   })
   await t.test('UNC paths are not a private local disk',async()=>{
     await assert.rejects(preparePrivateWorkspace({root:'//remote-host/shared/film',reportsRoot:reports}),/сетевые UNC-пути/)
     await assert.rejects(preparePrivateWorkspace({root:film,reportsRoot:'//remote-host/shared/reports'}),/сетевые UNC-пути/)
   })
   await t.test('existing publicly readable owner folder must be fixed before any new files are made',async()=>{
     if(process.platform==='win32')return
     const weakReports=join(temp,'open-reports')
     const newFilm=join(temp,'should-not-be-created')
     await mkdir(weakReports,{mode:0o755})
     await chmod(weakReports,0o755)
     await assert.rejects(preparePrivateWorkspace({root:newFilm,reportsRoot:weakReports}),/chmod 700/)
     await assert.rejects(stat(newFilm),{code:'ENOENT'},'Preparation must not leave half-created private directories')
     await assert.rejects(inspectOwnerWorkspace({root:film,reportsRoot:weakReports}),/chmod 700/)
     await assert.rejects(savePrivateDiagnostic({diagnostic:await inspectOwnerWorkspace({root:film,reportsRoot:reports}),reportsRoot:weakReports}),/chmod 700/)
     await chmod(weakReports,0o700)
     const fixed=await preparePrivateWorkspace({root:newFilm,reportsRoot:weakReports})
     assert.equal(fixed.filesCreated,0)
     assert.equal((await stat(newFilm)).mode&0o777,0o700)
   })
   await t.test('symlinked PARENT paths must be rejected before owner folders or reports are accessed',async()=>{
     const physicalParent=join(temp,'physical-private-parent')
     await mkdir(physicalParent)
     const alias=join(temp,'shortcut-parent')
     await symlink(physicalParent,alias,'dir')
     const linkedFilm=join(alias,'movie')
     const linkedReports=join(alias,'receipts')
     try{
       await assert.rejects(preparePrivateWorkspace({root:linkedFilm,reportsRoot:reports}),/символическая ссылка/)
       await assert.rejects(preparePrivateWorkspace({root:film,reportsRoot:linkedReports}),/символическая ссылка/)
       await assert.rejects(inspectOwnerWorkspace({root:linkedFilm,reportsRoot:reports}),/символическая ссылка/)
       const d=await inspectOwnerWorkspace({root:film,reportsRoot:reports})
       await assert.rejects(savePrivateDiagnostic({diagnostic:d,reportsRoot:linkedReports}),/символическая ссылка/)
       assert.deepEqual(await readdir(physicalParent),[], 'No directories were created behind the symlink')
     }finally{await rm(alias)}
   })
   await t.test('zero-byte and tampered caption headers are explicit blockers',async()=>{
     const id=inventory.assets[0].id, file=join(film,'captions',id+'.vtt')
     await writeFile(file,'')
     let d=await inspectOwnerWorkspace({root:film,reportsRoot:reports})
     assert.ok(d.invalid.some(e=>e.file.endsWith('.vtt')&&e.reason==='empty_or_oversized'))
     await writeFile(file,'NOT WEBVTT\n')
     d=await inspectOwnerWorkspace({root:film,reportsRoot:reports})
     assert.ok(d.invalid.some(e=>e.file.endsWith('.vtt')&&e.reason==='invalid_webvtt_header'))
     await rm(file)
   })
   await t.test('a forged V18 fixture never proves film bytes, even when installed GitHub QA differs',async()=>{
     const fake=join(temp,'fabricated-v18.json')
     await writeFile(fake,JSON.stringify({sha256:'a'.repeat(64),audioTracks:[{},{},{},{}],
       originalPictureAndBothOriginalSoundtracksBitstreamSha256Match:true,
       verifiedOutputDecodedAllFiveStreamsWithoutErrors:true}))
     const status=await historicalProvenanceWarning({qaPath:fake})
     assert.equal(status.status,'TEST_FIXTURE_NOT_ACTUAL_MEDIA_EVIDENCE')
     assert.equal(status.verifiedRealPrivateMaster,false)
     const archiveStatus=await historicalProvenanceWarning()
     assert.ok(['TEST_FIXTURE_NOT_ACTUAL_MEDIA_EVIDENCE',
       'QA_METADATA_PRESENT_NOT_INDEPENDENTLY_REVIEWED','HISTORICAL_QA_MISSING_OR_INVALID'].includes(archiveStatus.status))
     assert.equal(archiveStatus.verifiedRealPrivateMaster,false)
     const diagnostic=await inspectOwnerWorkspace({root:film,reportsRoot:reports})
     assert.equal(diagnostic.historicalProvenance.verifiedRealPrivateMaster,false)
     assert.equal(diagnostic.publicationAuthorized,false)
   })
   await t.test('preflight is refused before all eight real user files exist',async()=>{
     await assert.rejects(openLocalConsole({root:film,reportsRoot:reports,password:'long-private-pw-for-tests',openBrowser:false}),/Не хватает материалов/)
   })
   // Real media fixtures (no mocks) on the private disk only.
   for(const [i,asset] of inventory.assets.entries()){
     ffmpeg(join(film,'masters',asset.id+'.mp4'),440+i*120)
     await writeFile(join(film,'captions',asset.id+'.vtt'),`WEBVTT\n\n00:00:00.000 --> 00:00:01.400\nSynthetic test caption ${i}\n`)
   }
   await t.test('4 real H264/AAC and 4 actual WebVTT pass deep V28 SHA and codec validation without public authorization',async()=>{
     const shallow=await inspectOwnerWorkspace({root:film,reportsRoot:reports})
     assert.equal(shallow.readyForPrivateTechnicalPreflight,true)
     assert.equal(shallow.deepVerified,false)
     const deep=await inspectOwnerWorkspace({root:film,reportsRoot:reports,deep:true})
     assert.equal(deep.readyForPrivateTechnicalPreflight,true)
     assert.equal(deep.deepVerified,true)
     assert.equal(deep.mediaCandidates.length,4)
     assert.ok(deep.mediaCandidates.every(a=>a.mp4Sha256.length===64&&a.vttSha256.length===64&&a.mp4Bytes>1000))
     assert.equal(deep.publicationAuthorized,false)
   })
   await t.test('real local console starts only with good media and enforces password, cookie and logout',async()=>{
     const password='a-long-independent-local-owner-secret'
     const service=await openLocalConsole({root:film,reportsRoot:reports,password,openBrowser:false})
     try{
       assert.match(service.url,/^http:\/\/127\.0\.0\.1:\d+$/)
       let result=await fetch(service.url+'/api/status')
       assert.equal(result.status,401)
       const cookie=await login(service.url,password)
       result=await fetch(service.url+'/api/status',{headers:{Cookie:cookie}})
       assert.equal(result.status,200)
       const d=await result.json()
       assert.equal(d.releaseDecision,'NO_GO')
       assert.equal(d.publicationAuthorized,false)
       const html=await (await fetch(service.url+'/',{headers:{Cookie:cookie}})).text()
       const csrf=html.match(/const csrf='([a-f0-9]{64})'/)?.[1]
       assert.ok(csrf)
       const logout=await fetch(service.url+'/api/logout',{method:'POST',headers:{Cookie:cookie,'Origin':service.url,'X-OSA-CSRF':csrf}})
       assert.equal(logout.status,200)
       assert.equal((await fetch(service.url+'/api/status',{headers:{Cookie:cookie}})).status,401)
     }finally{await service.close()}
   })
   await t.test('extra MP4 and swapped captions block both preview and deep preflight',async()=>{
     const extra=join(film,'masters','pirated-unregistered.mp4')
     await writeFile(extra,'NEVER TREAT AS A CANDIDATE')
     try{
       const d=await inspectOwnerWorkspace({root:film,reportsRoot:reports,deep:true})
       assert.equal(d.readyForPrivateTechnicalPreflight,false)
       assert.deepEqual(d.unexpected,['masters/pirated-unregistered.mp4'])
     }finally{await rm(extra)}
     const file=join(film,'captions',inventory.assets[0].id+'.vtt'),backup=file+'.untrusted'
     await rename(file,backup)
     await symlink(backup,file)
     try{const d=await inspectOwnerWorkspace({root:film,reportsRoot:reports});assert.ok(d.invalid.some(e=>e.reason==='symlink_or_not_file'))}
     finally{await rm(file);await rename(backup,file)}
   })
   await t.test('syntactically WebVTT but overlapping/wrong cues are rejected by deep validation',async()=>{
     const p=join(film,'captions',inventory.assets[1].id+'.vtt')
     const old=await readFile(p)
     await writeFile(p,'WEBVTT\n\n00:00:00.000 --> 00:00:55.000\nToo long for the movie\n')
     try{const d=await inspectOwnerWorkspace({root:film,reportsRoot:reports,deep:true});assert.equal(d.readyForPrivateTechnicalPreflight,false);assert.ok(d.blockers.includes('v28_full_media_validation_failed'))}
     finally{await writeFile(p,old)}
   })
   await t.test('forged publication permission in a diagnostic cannot be written',async()=>{
     const legit=await inspectOwnerWorkspace({root:film,reportsRoot:reports})
     const altered={...legit,publicationAuthorized:true}
     await assert.rejects(savePrivateDiagnostic({diagnostic:altered,reportsRoot:reports}),/Refuse/)
   })
   await t.test('CLI prepare and doctor are actual working processes with honest NO-GO and safe exit codes',async()=>{
     const exec=fileURL=>spawnSync(process.execPath,[fileURL,'doctor','--root',film,'--reports-root',reports,'--full'],{encoding:'utf8',timeout:90000,maxBuffer:300000})
     const script=new URL('./osa-cinema-v32-first-run.mjs',import.meta.url).pathname
     const good=exec(script)
     assert.equal(good.status,0,good.stderr)
     assert.match(good.stdout,/ГОТОВО К ТЕХНИЧЕСКОЙ ПРОВЕРКЕ/)
     assert.match(good.stdout,/ЗАПРЕЩЕНЫ/)
     const incompleteDir=join(temp,'empty')
     const prepared=spawnSync(process.execPath,[script,'prepare','--root',incompleteDir,'--reports-root',join(temp,'emptyReports')],{encoding:'utf8',timeout:12000})
     assert.equal(prepared.status,0,prepared.stderr)
     const hold=spawnSync(process.execPath,[script,'doctor','--root',incompleteDir,'--reports-root',join(temp,'emptyReports')],{encoding:'utf8',timeout:15000})
     assert.equal(hold.status,2)
     assert.match(hold.stdout,/НЕПОЛНЫЙ КОМПЛЕКТ/)
   })
 }finally{await rm(temp,{recursive:true,force:true})}
})
