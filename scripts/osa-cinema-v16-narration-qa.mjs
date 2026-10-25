/** Private OSA Cinema narration QC. Never infers spoken language or grants rights. */
import { createHash } from 'node:crypto'
import { createReadStream } from 'node:fs'
import { readFile, lstat, mkdir, writeFile } from 'node:fs/promises'
import { spawnSync } from 'node:child_process'
import { basename, dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const EXPECTED='docs/OSA_CINEMA_V16_NARRATION_MANIFEST.json'
export function validateNarrationManifest(doc){
  if(doc?.schemaVersion!==1||doc?.assets?.length!==6)throw Error('Expected exactly six private act audio records')
  const keyed=new Set()
  for(const x of doc.assets){
    const key=x.locale+':'+x.act
    if(!['ru','en'].includes(x.locale)||![1,2,3].includes(x.act)||keyed.has(key))throw Error('Duplicate/missing RU/EN act')
    keyed.add(key)
    if(typeof x.file!=='string'||x.file!==basename(x.file)||!x.file.endsWith('.mp3'))throw Error('Unsafe filename')
    if(!/^[a-f0-9]{64}$/.test(x.sha256)||!Number.isSafeInteger(x.sizeBytes)||x.sizeBytes<10000)throw Error('No valid recorded-source fingerprint')
    if(x.durationSeconds<1||x.durationSeconds>600||x.audioCodec!=='mp3'||x.sampleRate!==44100||x.channels!==1)throw Error('Unverified MP3 metadata')
    if(x.publicationStatus!=='blocked'||x.rightsStatus!=='unverified'||x.languageStatus!=='unverified')throw Error('Private audio incorrectly promoted to released status')
  }
  return doc.assets
}
export function narrationBlockers(ref,real){
  const reasons=[]
  if(!real?.exists)reasons.push('private_audio_file_missing')
  else {
    if(ref.sha256!==real.sha256||ref.sizeBytes!==real.sizeBytes)reasons.push('audio_bytes_or_hash_changed')
    if(real.probeError||real.codec!=='mp3'||real.channels!==1||real.sampleRate!==44100||!Number.isFinite(real.durationSeconds)||Math.abs(real.durationSeconds-ref.durationSeconds)>.12)reasons.push('audio_stream_or_duration_mismatch')
  }
  reasons.push('spoken_language_not_listening_verified','rights_and_commercial_license_missing','editorial_and_script_approval_missing','real_synced_captions_or_transcript_missing','durable_delivery_missing')
  return reasons
}
async function inspect(root,ref){
  let st
  try{st=await lstat(join(root,ref.file))}catch(err){return{exists:false,probeError:err.code||String(err)}}
  if(!st.isFile()||st.isSymbolicLink())return{exists:false,probeError:'not regular source file'}
  const full=join(root,ref.file),hash=createHash('sha256')
  for await(const chunk of createReadStream(full))hash.update(chunk)
  const fp=spawnSync('ffprobe',['-v','error','-show_entries','format=duration:stream=codec_name,codec_type,channels,sample_rate','-of','json',full],{encoding:'utf8',timeout:30000,maxBuffer:500000})
  if(fp.error||fp.status!==0)return{exists:true,sizeBytes:st.size,sha256:hash.digest('hex'),probeError:fp.error?.message||fp.stderr||'ffprobe error'}
  try{
    const j=JSON.parse(fp.stdout||'{}'),audio=j.streams?.find(s=>s.codec_type==='audio')
    return{exists:true,sizeBytes:st.size,sha256:hash.digest('hex'),durationSeconds:Number(j.format?.duration),codec:audio?.codec_name,channels:Number(audio?.channels),sampleRate:Number(audio?.sample_rate)}
  }catch{return{exists:true,sizeBytes:st.size,sha256:hash.digest('hex'),probeError:'invalid_ffprobe_json'}}
}
export async function auditNarrations(root,doc){
  const entries=validateNarrationManifest(doc),assets=[]
  for(const ref of entries){
    const real=await inspect(root,ref)
    const blockers=narrationBlockers(ref,real)
    assets.push({id:ref.id,locale:ref.locale,act:ref.act,file:ref.file,real,technicalMatch:!blockers.includes('private_audio_file_missing')&&!blockers.includes('audio_bytes_or_hash_changed')&&!blockers.includes('audio_stream_or_duration_mismatch'),releaseReady:false,blockers})
  }
  return{schemaVersion:1,status:'PRIVATE_AUDIO_QA_ONLY_NOT_AUTHORIZED_TO_PUBLISH',summary:{total:assets.length,technicalMatches:assets.filter(x=>x.technicalMatch).length,releaseReady:0},assets}
}
async function main(){
  const args=process.argv.slice(2)
  let root='osa-media-staging',report=null,strict=false
  for(let i=0;i<args.length;i++){
    if(args[i]==='--root')root=args[++i]
    else if(args[i]==='--report')report=args[++i]
    else if(args[i]==='--strict-ready')strict=true
    else throw Error('Unknown argument '+args[i])
  }
  const result=await auditNarrations(resolve(root),JSON.parse(await readFile(EXPECTED,'utf8')))
  if(report){await mkdir(dirname(resolve(report)),{recursive:true});await writeFile(report,JSON.stringify(result,null,2)+'\n')}
  console.log('OSA_CINEMA_V16_NARRATION_QA '+JSON.stringify(result.summary))
  if(strict&&result.summary.releaseReady<result.summary.total)process.exitCode=1
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url))main().catch(e=>{console.error(e);process.exitCode=1})
