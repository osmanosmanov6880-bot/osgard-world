/**
 * OSA CINEMA V24: actual private release-candidate file inspection.
 * Never writes media, enables URLs, or declares legal/editorial authorization.
 * The human-authored plan is a statement to VERIFY, not an approval token.
 */
import { createHash } from 'node:crypto'
import { createReadStream, constants } from 'node:fs'
import { lstat, open, readFile, writeFile, mkdir } from 'node:fs/promises'
import { basename, dirname, join, resolve, sep } from 'node:path'
import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { inspectWebVtt } from './osa-cinema-v19-caption-qc.mjs'

const HASH=/^[0-9a-f]{64}$/
const NAME=/^[A-Za-z0-9][A-Za-z0-9_.-]{0,100}$/
const EXPECTED=['directors-workprint:en','directors-workprint:ru','trailer-workprint:en','trailer-workprint:ru']
const LIMIT_MEDIA=4_000_000_000
const LIMIT_CAPTIONS=2_000_000
const MANDATORY_EXTERNAL=['documented_commercial_rights','verified_spoken_language','final_director_and_sound_signoff','human_approved_captions','protected_durable_delivery','real_device_browser_acceptance','publisher_release_authorization']

export function validateCandidatePlan(plan, originals){
  if(plan?.schemaVersion!==1 || plan?.project!=='OSA CINEMA' || !Array.isArray(plan.assets)||plan.assets.length!==4) throw Error('V24 final master plan must cover exactly four editions')
  if(!Array.isArray(originals?.assets)||originals.assets.length!==4)throw Error('Original V16 source inventory is missing')
  const orig=new Map(originals.assets.map(a=>[a.id,a]))
  if(orig.size!==4)throw Error('Duplicate original source IDs')
  const seen=new Set(), paths=new Set(), slots=[]
  for(const a of plan.assets){
    if(typeof a.id!=='string'||!orig.has(a.id)||seen.has(a.id))throw Error('Unknown or repeated final edition ID')
    seen.add(a.id)
    const o=orig.get(a.id)
    if(a.locale!==o.locale||a.edition!==o.edition||a.sourceSha256!==o.sha256||!HASH.test(a.sourceSha256))throw Error('Candidate source does not match V16 original')
    if(!NAME.test(a.masterName||'')||!a.masterName.endsWith('.mp4')||basename(a.masterName)!==a.masterName)throw Error('Unsafe final master name')
    if(!NAME.test(a.captionName||'')||!a.captionName.endsWith('.vtt')||basename(a.captionName)!==a.captionName)throw Error('Unsafe final caption name')
    for(const path of ['masters/'+a.masterName,'captions/'+a.captionName]){
      if(paths.has(path))throw Error('Two editions refer to the same private file')
      paths.add(path)
    }
    if(!HASH.test(a.masterSha256||'')||!HASH.test(a.captionSha256||'')||
       !Number.isSafeInteger(a.masterBytes)||a.masterBytes<1000||a.masterBytes>LIMIT_MEDIA||
       !Number.isSafeInteger(a.width)||a.width<320||a.width>7680||
       !Number.isSafeInteger(a.height)||a.height<180||a.height>4320||
       !(a.durationSeconds>0)||a.durationSeconds>3600)throw Error('Unsafe or missing media integrity metadata')
    if(a.audioLanguageClaim!==a.locale)throw Error('Locale and audio language claim disagree')
    slots.push(a.edition+':'+a.locale)
  }
  if(JSON.stringify(slots.sort())!==JSON.stringify(EXPECTED))throw Error('RU/EN trailer/full edition coverage incomplete')
  if(plan.publicationAuthorized!==false||plan.commercialRightsCleared!==false)throw Error('Unlicensed file declared published or rights-cleared')
  return plan.assets
}

async function safeDir(path){
  try{const s=await lstat(path);return s.isDirectory()&&!s.isSymbolicLink()}catch{return false}
}
async function safeFile(path,maxBytes){
  try{const s=await lstat(path);return s.isFile()&&!s.isSymbolicLink()&&s.size>0&&s.size<=maxBytes?s:null}catch{return null}
}
async function hashWithNoFollow(path){
  const f=await open(path,constants.O_RDONLY|constants.O_NOFOLLOW)
  try {
    const h=createHash('sha256');const buf=Buffer.allocUnsafe(1024*1024)
    let offset=0
    while(true){const {bytesRead}=await f.read(buf,0,buf.length,offset);if(!bytesRead)break;h.update(buf.subarray(0,bytesRead));offset+=bytesRead}
    return h.digest('hex')
  }finally{await f.close()}
}
function probe(file){
  const result=spawnSync('ffprobe',['-v','error','-show_entries','format=duration:stream=codec_type,codec_name,width,height','-of','json',file],{encoding:'utf8',timeout:45000,maxBuffer:200000})
  if(result.error||result.status!==0) return {ok:false,code:'ffprobe_failed'}
  try{
    const d=JSON.parse(result.stdout),videos=d.streams.filter(s=>s.codec_type==='video'),audios=d.streams.filter(s=>s.codec_type==='audio')
    if(videos.length!==1||audios.length!==1)return {ok:false,code:'unexpected_stream_layout'}
    return {ok:true,videoCodec:videos[0].codec_name,audioCodec:audios[0].codec_name,width:videos[0].width,height:videos[0].height,durationSeconds:Number(d.format.duration)}
  }catch{return {ok:false,code:'malformed_ffprobe_json'}}
}
function fullyDecode(file){
  const p=spawnSync('ffmpeg',['-nostdin','-hide_banner','-loglevel','error','-threads','2','-i',file,'-map','0:v:0','-map','0:a:0','-f','null','-'],{encoding:'utf8',timeout:240000,maxBuffer:400000})
  return p.status===0&&!p.error
}
export async function inspectFinalMasters(root,plan,originals,{decode=true}={}){
  const assets=validateCandidatePlan(plan,originals)
  const absolute=resolve(root)
  const rootOkay=await safeDir(absolute),masterOkay=rootOkay&&await safeDir(join(absolute,'masters')),captionOkay=rootOkay&&await safeDir(join(absolute,'captions'))
  const rows=[]
  for(const a of assets){
    const blockers=[]
    let mediaVerified=false,captionVerified=false,mediaScan=null,captionQc=null
    const mediaFile=join(absolute,'masters',a.masterName),captionFile=join(absolute,'captions',a.captionName)
    if(!masterOkay)blockers.push('master_directory_missing_or_symlink')
    else{
      const stat=await safeFile(mediaFile,LIMIT_MEDIA)
      if(!stat)blockers.push('master_missing_unsafe_or_oversized')
      else{
        if(stat.size!==a.masterBytes)blockers.push('master_byte_size_mismatch')
        const sha=await hashWithNoFollow(mediaFile).catch(()=>null)
        if(sha!==a.masterSha256)blockers.push('master_sha256_mismatch')
        if(stat.size===a.masterBytes&&sha===a.masterSha256){
          const p=probe(mediaFile);mediaScan=p
          if(!p.ok||p.videoCodec!=='h264'||p.audioCodec!=='aac'||p.width!==a.width||p.height!==a.height||!Number.isFinite(p.durationSeconds)||Math.abs(p.durationSeconds-a.durationSeconds)>.12)blockers.push('master_codec_duration_or_resolution_mismatch')
          else if(decode&&!fullyDecode(mediaFile))blockers.push('master_full_decode_failed')
          else mediaVerified=true
        }
      }
    }
    if(!captionOkay)blockers.push('caption_directory_missing_or_symlink')
    else{
      const stat=await safeFile(captionFile,LIMIT_CAPTIONS)
      if(!stat)blockers.push('caption_missing_unsafe_or_oversized')
      else{
        const sha=await hashWithNoFollow(captionFile).catch(()=>null)
        if(sha!==a.captionSha256)blockers.push('caption_sha256_mismatch')
        else{
          captionQc=inspectWebVtt(await readFile(captionFile,'utf8'),a.durationSeconds)
          if(!captionQc.captionCandidatePass)blockers.push('caption_webvtt_syntax_timing_or_readability_failed')
          else captionVerified=true
        }
      }
    }
    rows.push({id:a.id,locale:a.locale,edition:a.edition,originalSha256:a.sourceSha256,finalSha256:a.masterSha256,captionSha256:a.captionSha256,
      technicalCandidatePassed:mediaVerified&&captionVerified,mediaVerified,captionVerified,
      scan:mediaScan?.ok?mediaScan:null,captionSummary:captionQc?.summary||null,captionErrors:captionQc?.errors||[],captionWarnings:captionQc?.warnings||[],blockers,
      humanAudioLanguageApproved:false,humanSubtitlesApproved:false,commercialRightsCleared:false,publisherAuthorized:false})
  }
  const ready=rows.filter(r=>r.technicalCandidatePassed).length
  return {schemaVersion:1,project:'OSA CINEMA',status:ready===4?'TECHNICAL_CANDIDATE_READY_NOT_LICENSED':'PRIVATE_TECHNICAL_HOLD',
    technical:{total:4,passed:ready,failed:4-ready},assets:rows,remainingExternalGates:MANDATORY_EXTERNAL,
    recordedFilmReleaseAuthorized:false,publicCatalogueWriteAllowed:false,paidCheckoutAllowed:false,
    warning:'Media hashes, FFmpeg and caption syntax cannot prove spoken language, copyright rights or artistic signoff. This tool never deploys.'}
}
function parseArgs(args){
  const o={root:'',plan:'',original:'docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json',report:'',strictTechnical:false,strictRelease:false}
  for(let i=0;i<args.length;i++){
    const a=args[i]
    if(a==='--root')o.root=args[++i]
    else if(a==='--plan')o.plan=args[++i]
    else if(a==='--originals')o.original=args[++i]
    else if(a==='--report')o.report=args[++i]
    else if(a==='--strict-technical')o.strictTechnical=true
    else if(a==='--strict-publication')o.strictRelease=true
    else throw Error('Unknown CLI parameter '+a)
  }
  if(!o.root||!o.plan)throw Error('Required --root PRIVATE_DIRECTORY --plan PRIVATE_FINAL_MANIFEST.json')
  return o
}
export async function main(args=process.argv.slice(2)){
  const o=parseArgs(args)
  const [p,s]=await Promise.all([readFile(o.plan,'utf8'),readFile(o.original,'utf8')])
  const report=await inspectFinalMasters(o.root,JSON.parse(p),JSON.parse(s))
  if(o.report){
    const out=resolve(o.report),sourceRoot=resolve(o.root)
    if(out===sourceRoot||out.startsWith(sourceRoot+sep))throw Error('QA report must be outside the private source directory')
    await mkdir(dirname(out),{recursive:true});await writeFile(out,JSON.stringify(report,null,2)+'\n',{mode:0o600,flag:'wx'})
  }
  console.log('OSA_V24_FINAL_QA '+JSON.stringify({status:report.status,technical:report.technical,releaseAuthorized:false}))
  if(o.strictTechnical&&report.technical.failed)process.exitCode=1
  if(o.strictRelease)process.exitCode=2
  return report
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url))main().catch(e=>{console.error(e.message);process.exitCode=2})
