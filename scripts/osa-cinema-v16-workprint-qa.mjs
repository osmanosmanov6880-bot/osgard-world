/** Offline workprint verification. Intentionally cannot grant copyright or editorial clearance. */
import { createHash } from 'node:crypto'
import { createReadStream } from 'node:fs'
import { lstat, readFile, writeFile, mkdir } from 'node:fs/promises'
import { spawnSync } from 'node:child_process'
import { basename, dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

export const DEFAULT_MANIFEST = 'docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json'
const HEX64 = /^[0-9a-f]{64}$/
const ID = /^[a-z0-9-]{5,70}$/
const BAD_URL = /(?:token|signature|expires|credential|policy|jwt|key|x-amz-)/i

export function validateManifest(manifest) {
  if (manifest?.schemaVersion !== 1 || !Array.isArray(manifest.assets) || manifest.assets.length < 1) throw new Error('Invalid workprint manifest schema')
  const ids = new Set()
  for (const asset of manifest.assets) {
    if (!ID.test(asset.id || '') || ids.has(asset.id)) throw new Error('Invalid or repeated workprint ID')
    ids.add(asset.id)
    if (!['ru', 'en'].includes(asset.locale) || !['trailer-workprint', 'directors-workprint'].includes(asset.edition)) throw new Error('Unexpected workprint locale or edition')
    if (typeof asset.file !== 'string' || asset.file !== basename(asset.file) || !asset.file.endsWith('.mp4')) throw new Error('Non-local or invalid file name')
    if (!HEX64.test(asset.sha256 || '') || !Number.isSafeInteger(asset.sizeBytes) || asset.sizeBytes < 10000) throw new Error('Invalid byte/hash provenance')
    if (!(asset.durationSeconds > 0) || !(asset.width > 0) || !(asset.height > 0)) throw new Error('Missing media metadata')
    if (asset.videoCodec !== 'h264' || asset.audioCodec !== 'aac') throw new Error('Unverified codec declaration')
  }
  return manifest.assets
}

export function isDurablePublicationUrl(value) {
  if (typeof value !== 'string' || !value.trim() || value.includes('\\') || value.startsWith('//')) return false
  const path = value.trim()
  if (path.startsWith('/')) {
    if (!path.startsWith('/osa-library/media/')) return false
    if (path.includes('..') || path.includes('?') || path.includes('#')) return false
    return true
  }
  try {
    const url = new URL(path)
    return url.protocol === 'https:' && !url.username && !url.password && !url.search && !BAD_URL.test(url.search) && !/cloudfront\.net$|runwayml\.com$/i.test(url.hostname) && url.hash === ''
  } catch { return false }
}

export function parseVtt(vtt, maxDurationSeconds) {
  if (typeof vtt !== 'string' || !vtt.startsWith('WEBVTT')) return {valid:false,reason:'missing_webvtt_header',cues:0}
  const lines = vtt.replace(/\r/g,'').split('\n')
  const cueRE = /^(\d{2,}):(\d{2}):(\d{2})\.(\d{3}) --> (\d{2,}):(\d{2}):(\d{2})\.(\d{3})(?:\s.*)?$/
  const seconds = a => Number(a[0])*3600+Number(a[1])*60+Number(a[2])+Number(a[3])/1000
  let cues=0, lastEnd=0
  for(let i=1;i<lines.length;i++){
    if(!lines[i].includes('-->'))continue
    const m=lines[i].match(cueRE)
    if(!m)return {valid:false,reason:'invalid_cue_time',cues}
    const start=seconds(m.slice(1,5)), end=seconds(m.slice(5,9))
    if(start<lastEnd-.001 || start>=end || end>maxDurationSeconds+.02)return {valid:false,reason:'overlap_or_out_of_range',cues}
    if(!lines.slice(i+1).some(line=>line.trim() && !line.includes('-->')))return {valid:false,reason:'empty_cue_text',cues}
    const nextText=lines.slice(i+1).find(line=>line.trim())
    if(!nextText || nextText.includes('-->'))return {valid:false,reason:'missing_cue_text',cues}
    lastEnd=end;cues++
  }
  return cues ? {valid:true,reason:null,cues} : {valid:false,reason:'no_cues',cues:0}
}

export function releaseBlockers(asset, probe, review={}, captionResult=null, evidence={}) {
  const blockers=[]
  if(!probe?.exists)blockers.push('master_file_missing')
  else {
    if(probe.sha256!==asset.sha256 || probe.sizeBytes!==asset.sizeBytes)blockers.push('master_integrity_mismatch')
    if(probe.probeError || !Number.isFinite(Number(probe.durationSeconds)) || Math.abs(Number(probe.durationSeconds)-asset.durationSeconds)>.1 || probe.width!==asset.width || probe.height!==asset.height || probe.videoCodec!==asset.videoCodec || probe.audioCodec!==asset.audioCodec)blockers.push('media_probe_mismatch')
  }
  if(review.rightsStatus!=='cleared' || !evidence.rights)blockers.push('rights_evidence_not_verified')
  if(review.editorialStatus!=='approved' || !evidence.editorial)blockers.push('final_cut_not_approved')
  if(review.audioLanguageStatus!=='verified' || review.verifiedAudioLocale!==asset.locale || !evidence.audio)blockers.push('language_audio_not_reviewed')
  if(review.captionsStatus!=='approved' || !captionResult?.valid || !evidence.captions)blockers.push('approved_synced_captions_missing')
  if(!isDurablePublicationUrl(review.deliveryUrl) || review.deliveryVerified!==true)blockers.push('durable_delivery_not_verified')
  return blockers
}

async function verifyEvidence(root,path){
  if(typeof path!=='string' || path.includes('..') || path.startsWith('/') || path.includes('\\'))return false
  if(!path.startsWith('evidence/'))return false
  try { const p=await lstat(join(root,path));return p.isFile() && !p.isSymbolicLink() && p.size>30 }catch{return false}
}
async function hashFile(file){
  const hash=createHash('sha256')
  for await (const chunk of createReadStream(file))hash.update(chunk)
  return hash.digest('hex')
}
function inspectMp4(file){
  const probe=spawnSync('ffprobe',['-v','error','-show_entries','format=duration:stream=codec_type,codec_name,width,height:stream_tags=language','-of','json',file],{encoding:'utf8',timeout:30000,maxBuffer:1000000})
  if(probe.status!==0 || probe.error) return {probeError: probe.error?.message || probe.stderr || 'ffprobe failed'}
  try {
    const parsed=JSON.parse(probe.stdout)
    const video=parsed.streams?.find(s=>s.codec_type==='video')
    const audio=parsed.streams?.find(s=>s.codec_type==='audio')
    return {durationSeconds:Number(parsed.format?.duration),width:video?.width,height:video?.height,videoCodec:video?.codec_name,audioCodec:audio?.codec_name,audioLanguageTag:audio?.tags?.language||'und'}
  }catch{return {probeError:'invalid ffprobe JSON'}}
}
export async function evaluate(root, manifest, approvals={assets:{}}, options={}) {
  const assets=validateManifest(manifest)
  const rows=[]
  for(const asset of assets){
    let probe={exists:false}
    const path=join(root,asset.file)
    try {
      const st=await lstat(path)
      if(st.isFile() && !st.isSymbolicLink()) probe={exists:true,sizeBytes:st.size,sha256:await hashFile(path),...inspectMp4(path)}
      else probe={exists:false,probeError:'not a regular file'}
    }catch(err){probe={exists:false,probeError:err.code||err.message}}
    const review=approvals.assets?.[asset.id] || {}
    const evidence={rights:await verifyEvidence(root,review.rightsEvidencePath),editorial:await verifyEvidence(root,review.editorialEvidencePath),audio:await verifyEvidence(root,review.audioEvidencePath),captions:await verifyEvidence(root,review.captionReviewEvidencePath)}
    let captionResult=null
    if(typeof review.captionsPath==='string' && /^captions\/[A-Za-z0-9_.-]+\.vtt$/.test(review.captionsPath)) {
      try {captionResult=parseVtt(await readFile(join(root,review.captionsPath),'utf8'),asset.durationSeconds)}catch{captionResult={valid:false,reason:'vtt_file_unavailable'}}
    }
    const blockers=releaseBlockers(asset,probe,review,captionResult,evidence)
    rows.push({id:asset.id,locale:asset.locale,edition:asset.edition,file:asset.file,probe,captionResult,blockers,ready:!blockers.length})
  }
  const ready=rows.filter(r=>r.ready).length
  return {schemaVersion:1,status:ready===rows.length?'all_release_gates_passed':'blocked_pending_human_and_delivery_evidence',verifiedAt:new Date().toISOString(),summary:{total:rows.length,ready,blocked:rows.length-ready},assets:rows,policy:'This file reports verification evidence; it is not a copyright license or a production deploy approval.'}
}

function parseArgs(args){
  const o={root:'osa-media-staging',manifest:DEFAULT_MANIFEST,approvals:null,report:null,strict:false}
  for(let i=0;i<args.length;i++){
    if(args[i]==='--root')o.root=args[++i]
    else if(args[i]==='--manifest')o.manifest=args[++i]
    else if(args[i]==='--approvals')o.approvals=args[++i]
    else if(args[i]==='--report')o.report=args[++i]
    else if(args[i]==='--strict-ready')o.strict=true
    else throw new Error('Unknown argument: '+args[i])
  }return o
}
async function main(){
  const opts=parseArgs(process.argv.slice(2))
  const manifest=JSON.parse(await readFile(opts.manifest,'utf8'))
  const approvals=opts.approvals?JSON.parse(await readFile(opts.approvals,'utf8')):undefined
  const report=await evaluate(resolve(opts.root),manifest,approvals)
  if(opts.report){await mkdir(dirname(resolve(opts.report)),{recursive:true});await writeFile(opts.report,JSON.stringify(report,null,2)+'\n')}
  console.log('OSA_CINEMA_V16_WORKPRINT_QA '+JSON.stringify({summary:report.summary,status:report.status,blockedAssets:report.assets.filter(x=>!x.ready).map(x=>({id:x.id,blockers:x.blockers}))}))
  if(opts.strict&&report.summary.blocked)process.exitCode=1
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url))main().catch(e=>{console.error(e.stack||e);process.exitCode=1})
