/** OSA CINEMA V28: offline intake for FOUR actual final-candidate MP4+VTT pairs.
 * The program can only prepare a technical manifest. It cannot approve a release.
 */
import { createHash } from 'node:crypto'
import { constants } from 'node:fs'
import { lstat, open, readFile, writeFile, mkdir, readdir } from 'node:fs/promises'
import { resolve, join, dirname, sep } from 'node:path'
import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { inspectWebVtt } from './osa-cinema-v19-caption-qc.mjs'

const SHA=/^[a-f0-9]{64}$/
const ID=/^osa-[a-z0-9-]{3,70}$/
const EXPECTED=new Set(['directors-workprint:ru','directors-workprint:en','trailer-workprint:ru','trailer-workprint:en'])
const LIMIT_MP4=4_000_000_000
const LIMIT_VTT=2_000_000
const PROBE_TIMEOUT_MS=45000

async function isSafeDir(path) {
  const s=await lstat(path)
  if(!s.isDirectory()||s.isSymbolicLink())throw Error('Not a real directory: '+path)
}
async function safeReadAndHash(path,limit,{text=false}={}) {
  const st=await lstat(path)
  if(!st.isFile()||st.isSymbolicLink()||st.size===0||st.size>limit)throw Error('Missing, symlinked, empty or oversized file: '+path)
  const fd=await open(path,constants.O_RDONLY | constants.O_NOFOLLOW)
  try {
    const actual=await fd.stat()
    if(!actual.isFile()||actual.size!==st.size)throw Error('File changed while being opened: '+path)
    const hash=createHash('sha256'), chunks=[],buffer=Buffer.allocUnsafe(1024*1024)
    let pos=0
    while(pos<actual.size){
      const {bytesRead}=await fd.read(buffer,0,Math.min(buffer.length,actual.size-pos),pos)
      if(bytesRead===0)throw Error('File truncated during reading: '+path)
      const portion=buffer.subarray(0,bytesRead)
      hash.update(portion)
      if(text)chunks.push(Buffer.from(portion))
      pos+=bytesRead
    }
    const after=await fd.stat()
    if(after.size!==actual.size||after.mtimeMs!==actual.mtimeMs)throw Error('File changed while hashing: '+path)
    return {bytes:pos,sha256:hash.digest('hex'),content:text?Buffer.concat(chunks).toString('utf8'):null}
  } finally {await fd.close()}
}
function metadata(file) {
  const p=spawnSync('ffprobe',['-v','error','-show_entries','format=duration:stream=codec_type,codec_name,width,height','-of','json',file],{encoding:'utf8',timeout:PROBE_TIMEOUT_MS,maxBuffer:500000})
  if(p.error||p.status!==0)throw Error('FFprobe cannot read final candidate MP4: '+file)
  let r;try{r=JSON.parse(p.stdout)}catch{throw Error('Invalid FFprobe JSON: '+file)}
  const video=r.streams?.filter(x=>x.codec_type==='video')||[]
  const audio=r.streams?.filter(x=>x.codec_type==='audio')||[]
  const duration=Number(r.format?.duration)
  if(video.length!==1||audio.length!==1||video[0].codec_name!=='h264'||audio[0].codec_name!=='aac'||
    !Number.isSafeInteger(video[0].width)||!Number.isSafeInteger(video[0].height)||
    video[0].width<320||video[0].height<180||video[0].width>7680||video[0].height>4320||
    !Number.isFinite(duration)||duration<=0||duration>3600)throw Error('Unsupported final candidate streams: '+file)
  return {durationSeconds:duration,width:video[0].width,height:video[0].height}
}
export function validateCanonical(originals) {
  if(!Array.isArray(originals?.assets)||originals.assets.length!==4)throw Error('V16 inventory must have exactly four editions')
  const ids=new Set(),slots=new Set()
  for(const a of originals.assets){
    if(!ID.test(a.id||'')||ids.has(a.id)||!EXPECTED.has(a.edition+':'+a.locale)||slots.has(a.edition+':'+a.locale)||!SHA.test(a.sha256||''))throw Error('Invalid or duplicate canonical original')
    ids.add(a.id);slots.add(a.edition+':'+a.locale)
  }
  if(slots.size!==4)throw Error('Incomplete four-edition original inventory')
  return originals.assets
}
export async function buildPrivateCandidatePlan(root,originals) {
  const assets=validateCanonical(originals)
  const source=resolve(root)
  const masterDir=join(source,'masters'),captionDir=join(source,'captions')
  await isSafeDir(source);await isSafeDir(masterDir);await isSafeDir(captionDir)
  const expectedMedia=new Set(assets.map(a=>a.id+'.mp4'))
  const expectedCaptions=new Set(assets.map(a=>a.id+'.vtt'))
  const mediaEntries=await readdir(masterDir),captionEntries=await readdir(captionDir)
  if(mediaEntries.length!==4||captionEntries.length!==4||
    mediaEntries.some(f=>!expectedMedia.has(f))||captionEntries.some(f=>!expectedCaptions.has(f)))throw Error('Final directory must contain exactly the four canonical MP4s and four VTTs')
  const out=[]
  for(const a of assets){
    const masterName=a.id+'.mp4',captionName=a.id+'.vtt'
    const masterFile=join(masterDir,masterName),captionFile=join(captionDir,captionName)
    const mp4=await safeReadAndHash(masterFile,LIMIT_MP4)
    const vtt=await safeReadAndHash(captionFile,LIMIT_VTT,{text:true})
    const scanned=metadata(masterFile)
    const caption=inspectWebVtt(vtt.content,scanned.durationSeconds)
    if(!caption.captionCandidatePass)throw Error('Caption syntax/timing/readability failed: '+captionName)
    out.push({id:a.id,edition:a.edition,locale:a.locale,sourceSha256:a.sha256,
      masterName,masterSha256:mp4.sha256,masterBytes:mp4.bytes,
      captionName,captionSha256:vtt.sha256,audioLanguageClaim:a.locale,
      durationSeconds:scanned.durationSeconds,width:scanned.width,height:scanned.height})
  }
  return {schemaVersion:1,project:'OSA CINEMA',stage:'V28_TECHNICAL_INTAKE_ONLY',
    publicationAuthorized:false,commercialRightsCleared:false,
    notes:'Speech/language, synchronized words, music, image rights and publisher signoff are NOT checked here.',
    assets:out}
}
export async function makePlanFromFiles({root,originals,out}) {
  if(!root||!originals||!out)throw Error('Missing --root, --originals or --out')
  const source=resolve(root), target=resolve(out)
  if(target===source||target.startsWith(source+sep))throw Error('Write reports outside the private media directory')
  const existing=JSON.parse(await readFile(originals,'utf8'))
  const report=await buildPrivateCandidatePlan(root,existing)
  await mkdir(dirname(target),{recursive:true})
  await writeFile(target,JSON.stringify(report,null,2)+'\n',{flag:'wx',mode:0o600})
  return report
}
async function main(args){
  let root=null,originals='docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json',out=null
  for(let i=0;i<args.length;i++){
    if(args[i]==='--root')root=args[++i]
    else if(args[i]==='--originals')originals=args[++i]
    else if(args[i]==='--out')out=args[++i]
    else throw Error('Unknown V28 argument: '+args[i])
  }
  const result=await makePlanFromFiles({root,originals,out})
  console.log('OSA_V28_PRIVATE_TECHNICAL_INTAKE '+JSON.stringify({candidateCount:result.assets.length,approved:false,publicationAuthorized:false,output:resolve(out)}))
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url))main(process.argv.slice(2)).catch(e=>{console.error(e.message);process.exitCode=2})
