/**
 * OSA CINEMA V35: immutable snapshot guard for original historical editorial
 * records. It never authorizes distribution of films, payments or rights.
 * A deliberate legal/release policy update requires an independently reviewed
 * change to the pinned Git blob hashes AND a separate publication workflow.
 */
import { constants } from 'node:fs'
import { open, lstat } from 'node:fs/promises'
import { createHash } from 'node:crypto'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

export const PINNED_ORIGINAL_BLOBS = Object.freeze({
  'docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json': '78cb70b58eae55df457eab50ccf9c509a8d48bf9',
  'docs/OSA_CINEMA_V18_PRIVATE_FOUR_TRACK_QA.json': 'd9841fe926f5a40232830c66812c1b573e5a5353',
  'docs/OSA_CINEMA_V20_PRIVATE_RELEASE_POLICY.json': '94c9fe3a68705bad9eb76ce189ad50cf0a082726',
})
const originalIds = ['osa-v15-trailer-ru','osa-v15-trailer-en','osa-v15-directors-ru','osa-v15-directors-en']
const humanDecisions = ['spoken_language','commercial_rights','final_cut_sound','synced_webvtt',
  'durable_delivery','live_browser_acceptance','publisher_authorization']
const sha256 = data => createHash('sha256').update(data).digest('hex')
export const gitBlobSha = bytes => createHash('sha1')
  .update(Buffer.from('blob '+bytes.length+'\0','utf8')).update(bytes).digest('hex')
function requireSafe(condition, reason) {
  if(!condition) throw Error('OSA_V35_HISTORICAL_HOLD: '+reason)
}
function exactNames(actual,expected) {
  return Array.isArray(actual) && actual.length===expected.length &&
    new Set(actual).size===actual.length && actual.every(x=>expected.includes(x))
}
async function pinnedRead(root,relative){
  const path=join(resolve(root),...relative.split('/'))
  for(let cur=path;;cur=dirname(cur)){
    const st=await lstat(cur)
    requireSafe(!st.isSymbolicLink() && (cur===path?st.isFile():st.isDirectory()),
      'linked or nonregular historical document path: '+relative)
    if(dirname(cur)===cur)break
  }
  const stat=await lstat(path)
  requireSafe(stat.size>0 && stat.size<=512*1024,'historical document size out of bounds: '+relative)
  const handle=await open(path,constants.O_RDONLY|(constants.O_NOFOLLOW||0))
  try{
    const before=await handle.stat()
    requireSafe(before.dev===stat.dev && before.ino===stat.ino && before.size===stat.size,
      'historical document changed before opening: '+relative)
    const bytes=await handle.readFile()
    const after=await handle.stat()
    requireSafe(after.dev===before.dev && after.ino===before.ino && after.size===before.size &&
      after.mtimeMs===before.mtimeMs && after.ctimeMs===before.ctimeMs &&
      bytes.length===before.size,'historical document changed during read: '+relative)
    return bytes
  }finally{await handle.close()}
}
/** Pure policy audit, separated from file reading for negative fixtures. */
export function auditEvidenceSnapshot(documents,pins=PINNED_ORIGINAL_BLOBS,{allowCheckoutCrlf=false}={}){
  requireSafe(documents&&typeof documents==='object'&&!Array.isArray(documents),
    'historical source set missing')
  requireSafe(exactNames(Object.keys(documents),Object.keys(PINNED_ORIGINAL_BLOBS)),
    'historical source set differs from the three originals')
  const decoded={}
  const results=[]
  for(const path of Object.keys(PINNED_ORIGINAL_BLOBS)){
    const bytes=documents[path]
    requireSafe(Buffer.isBuffer(bytes) && bytes.length>0 && bytes.length<=512*1024,
      'historical source missing or oversized: '+path)
    const rawBlob=gitBlobSha(bytes)
    // Git for Windows may checkout text files with CRLF while the committed
    // Git blob remains LF. This is the ONLY allowed byte transformation.
    const canonicalBytes=rawBlob===pins[path] ? bytes :
      allowCheckoutCrlf ? Buffer.from(bytes.toString('utf8').replace(/\r\n/g,'\n'),'utf8') : bytes
    const blob=gitBlobSha(canonicalBytes)
    requireSafe(pins[path]===blob,'historical source changed: '+path+' (Git blob SHA mismatch)')
    let data
    try{data=JSON.parse(bytes.toString('utf8'))}catch{throw Error('OSA_V35_HISTORICAL_HOLD: invalid historical JSON: '+path)}
    requireSafe(data&&typeof data==='object'&&!Array.isArray(data), 'historical JSON must be object: '+path)
    decoded[path]=data
    results.push({path,gitBlobSha:blob,sha256:sha256(canonicalBytes),bytes:canonicalBytes.length,
      checkoutLineEndingsNormalized:rawBlob!==blob})
  }
  const v16=decoded['docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json']
  const v18=decoded['docs/OSA_CINEMA_V18_PRIVATE_FOUR_TRACK_QA.json']
  const v20=decoded['docs/OSA_CINEMA_V20_PRIVATE_RELEASE_POLICY.json']
  requireSafe(v16.schemaVersion===1 && typeof v16.status==='string' &&
    v16.status==='PRIVATE_EDITORIAL_WORKPRINTS_NOT_APPROVED_FOR_PUBLICATION' &&
    Array.isArray(v16.assets) && exactNames(v16.assets.map(a=>a?.id),originalIds),
    'V16 original editorial workprint inventory no longer matches')
  requireSafe(v18.schemaVersion===1 && v18.status==='PRIVATE_FOUR_AUDIO_TRACK_EDITORIAL_MASTER_NOT_LICENSED_FOR_RELEASE' &&
    v18.publicationAuthorized===false && v18.rightsCleared===false &&
    (!Object.hasOwn(v18,'paidCheckoutEnabled')||v18.paidCheckoutEnabled===false) &&
    Array.isArray(v18.audioTracks) && v18.audioTracks.length===4,
    'V18 genuine historical audio QA has changed or claims release authorization')
  requireSafe(v20.schemaVersion===1 && v20.status==='PRIVATE_ONLY_RELEASE_NOT_AUTHORIZED' &&
    v20.publicationAuthorized===false && v20.rightsCleared===false &&
    v20.paidCheckoutEnabled===false &&
    exactNames(v20.mandatoryHumanDecisions,humanDecisions) &&
    Array.isArray(v20.assets) && exactNames(v20.assets.map(a=>a?.sourceId),originalIds),
    'V20 private release policy is missing mandatory NO-GO requirements')
  const v16Assets=new Map(v16.assets.map(a=>[a.id,a]))
  for(const a of v20.assets){
    requireSafe(a.originalSha256===v16Assets.get(a.sourceId).sha256 &&
      a.voiceApproved===false && a.captionsApproved===false &&
      a.rightsApproved===false && a.deliveryVerified===false,
      'V20 media evidence mismatches V16 or asserts unapproved rights')
  }
  return Object.freeze({schemaVersion:1,stage:'V35_HISTORICAL_CODE_REPOSITORY_GUARD',
    originalDocuments:results,verifiedHistoricalSnapshot:pins===PINNED_ORIGINAL_BLOBS,
    testOrCustomPinMode:pins!==PINNED_ORIGINAL_BLOBS,verifiedFilmBytes:false,
    filmRightsVerified:false,publicationAuthorized:false,rightsCleared:false,
    paidCheckoutEnabled:false,releaseDecision:'NO_GO',
    note:'Exact historical repository source bytes verified. This is not a film, legal, or publisher signoff.'})
}
export async function verifyHistoricalEvidence({root}={}){
  requireSafe(typeof root==='string' && root.length>0,'explicit repository root required')
  const files={}
  for(const path of Object.keys(PINNED_ORIGINAL_BLOBS))files[path]=await pinnedRead(root,path)
  return auditEvidenceSnapshot(files,PINNED_ORIGINAL_BLOBS,
    {allowCheckoutCrlf:process.platform==='win32'})
}
if(process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  const args=process.argv.slice(2)
  if(args.length!==2 || args[0]!=='--root'){
    console.error('Usage: node scripts/osa-cinema-v35-historical-guard.mjs --root /absolute/repo')
    process.exitCode=2
  }else{
    verifyHistoricalEvidence({root:args[1]}).then(v=>{
      console.log(JSON.stringify(v,null,2))
      console.log('OSA CINEMA historical records verified; public film and payment remain NO-GO')
    }).catch(e=>{console.error(e.message);process.exitCode=1})
  }
}
