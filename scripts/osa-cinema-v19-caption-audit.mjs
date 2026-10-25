#!/usr/bin/env node
/**
 * OSA Cinema V19: audit local human-edited VTT draft files against 4 exact
 * original picture editions. Neither this report nor a valid VTT proves speech,
 * editorial signoff, recording rights, or public-release authorization.
 */
import {readFile,lstat,mkdir,writeFile} from 'node:fs/promises'
import {resolve,join,dirname} from 'node:path'
import {fileURLToPath} from 'node:url'
import {createHash} from 'node:crypto'
import {parseWebVtt} from './osa-cinema-v19-caption-core.mjs'

const MANIFEST='docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json'
export function filenameForSource(id){if(!/^osa-v15-(trailer|directors)-(ru|en)$/.test(id))throw Error('Unsafe source ID');return 'OSA_PRIVATE_'+id+'.vtt'}
export function captionStats(cues,duration){
 const seconds=cues.reduce((n,x)=>n+(x.end-x.start),0)
 const warnings=[]
 for(let i=0;i<cues.length;i++){
  const c=cues[i],lines=c.text.split('\n')
  if(lines.some(line=>[...line].length>42))warnings.push('overlong_line_at_cue_'+i)
  if((c.end-c.start)<.5)warnings.push('very_short_cue_'+i)
  if((c.end-c.start)>8)warnings.push('long_duration_cue_'+i)
 }
 return {cueCount:cues.length,firstStart:cues.length?cues[0].start:null,lastEnd:cues.length?cues.at(-1).end:null,captionSeconds:Number(seconds.toFixed(3)),coveragePercent:Number((seconds/duration*100).toFixed(2)),warnings}
}
export async function auditDraftDirectory(folder,manifest){
 if(manifest?.assets?.length!==4)throw Error('Four original workprint editions required')
 const rows=[]
 const ids=new Set()
 for(const source of manifest.assets){
  if(!source?.id||ids.has(source.id)||!Number.isFinite(source.durationSeconds)||!(/^[a-f0-9]{64}$/).test(source.sha256))throw Error('Invalid original source manifest')
  ids.add(source.id)
  const filename=filenameForSource(source.id),path=join(folder,filename)
  let state='missing',details=null,sha256=null,error=null
  try{
   const st=await lstat(path)
   if(!st.isFile()||st.isSymbolicLink()||st.size>800000||st.size<10)throw Error('Unsafe or empty draft VTT')
   const raw=await readFile(path,'utf8')
   const cues=parseWebVtt(raw,source.durationSeconds)
   if(!cues.length)throw Error('No actual caption cues')
   state='technical_draft_valid'
   sha256=createHash('sha256').update(raw).digest('hex')
   details=captionStats(cues,source.durationSeconds)
  }catch(e){if(e.code==='ENOENT')state='missing';else {state='invalid_draft';error=String(e.message).slice(0,250)}}
  rows.push({sourceId:source.id,locale:source.locale,sourceSha256:source.sha256,sourceDuration:source.durationSeconds,privateDraftFile:filename,privateDraftSha256:sha256,state,details,error,
   spokenLanguageHumanVerified:false,transcriptionAccuracyApproved:false,rightsCleared:false,publicDeliveryVerified:false,releaseAuthorized:false})
 }
 return {schemaVersion:1,scope:'PRIVATE_CAPTION_DRAFT_AUDIT_ONLY',summary:{total:rows.length,validTechnicalDrafts:rows.filter(x=>x.state==='technical_draft_valid').length,missing:rows.filter(x=>x.state==='missing').length,invalid:rows.filter(x=>x.state==='invalid_draft').length,approvedForPublication:0},assets:rows,releaseAuthorized:false,
  note:'Valid WebVTT syntax and timestamps do not establish transcription accuracy, permissions, or a released movie.'}
}
async function main(){
 const args=process.argv.slice(2);let folder='osa-private-captions',output=null,strict=false
 for(let i=0;i<args.length;i++){
  const x=args[i]
  if(x==='--root')folder=args[++i]
  else if(x==='--report')output=args[++i]
  else if(x==='--strict-cues')strict=true
  else throw Error('Unknown argument: '+x)
 }
 const manifest=JSON.parse(await readFile(MANIFEST,'utf8'))
 const result=await auditDraftDirectory(resolve(folder),manifest)
 if(output){await mkdir(dirname(resolve(output)),{recursive:true});await writeFile(resolve(output),JSON.stringify(result,null,2)+'\n')}
 console.log('OSA_CINEMA_V19_CAPTION_DRAFT_QA '+JSON.stringify(result.summary))
 if(strict&&result.summary.validTechnicalDrafts!==result.summary.total)process.exitCode=1
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url))main().catch(e=>{console.error(e);process.exitCode=1})
