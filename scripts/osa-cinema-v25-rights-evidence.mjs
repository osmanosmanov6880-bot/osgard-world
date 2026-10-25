/**
 * OSA CINEMA V25: owner-side evidence coverage checker.
 * Verifies that claimed source IDs link to actual hashed local PDF bytes.
 * DOES NOT interpret contracts or provide an opinion on commercial rights.
 */
import { createHash } from 'node:crypto'
import { createReadStream, constants } from 'node:fs'
import { lstat, open, readFile, writeFile, mkdir } from 'node:fs/promises'
import { basename, dirname, join, resolve, sep } from 'node:path'
import { fileURLToPath } from 'node:url'
const SHA=/^[a-f0-9]{64}$/
const ID=/^[a-z][a-z0-9-]{2,75}$/
const SAFE_PDF=/^[a-zA-Z0-9_-]{3,90}\.pdf$/
const TYPES=new Set(['video','photograph','music','voice','graphics','logo','stock','ai-generated','other'])
export function validateUsage(usage,masterPlan){
  if(usage?.schemaVersion!==1||usage.project!=='OSA CINEMA'||usage.releaseAuthorized!==false||!Array.isArray(usage.sources)||!Array.isArray(usage.editions))throw Error('Invalid or falsely authorized rights coverage manifest')
  if(!Array.isArray(masterPlan?.assets)||masterPlan.assets.length!==4)throw Error('Expected four final candidate editions')
  const known=new Map(masterPlan.assets.map(a=>[a.id,a]))
  if(known.size!==4||usage.editions.length!==4)throw Error('Duplicated or missing media editions')
  const usedIds=new Set(),keyset=new Set()
  for(const a of usage.editions){
    if(!known.has(a.finalId)||usedIds.has(a.finalId)||a.finalSha256!==known.get(a.finalId).masterSha256)throw Error('Rights coverage edition SHA does not match final candidate')
    usedIds.add(a.finalId)
    if(!Array.isArray(a.sourceIds)||a.sourceIds.length===0||new Set(a.sourceIds).size!==a.sourceIds.length)throw Error('Missing or duplicate source usage links')
  }
  const sourceNames=new Set(),docNames=new Set()
  for(const s of usage.sources){
    if(!ID.test(s.id||'')||sourceNames.has(s.id)||!TYPES.has(s.type)||!SHA.test(s.sourceSha256||''))throw Error('Unsafe, missing or repeated rights source')
    sourceNames.add(s.id)
    if(!SAFE_PDF.test(s.evidenceFile||'')||basename(s.evidenceFile)!==s.evidenceFile||docNames.has(s.evidenceFile)||!SHA.test(s.evidenceSha256||''))throw Error('Invalid or duplicated evidence identity')
    docNames.add(s.evidenceFile)
    if(s.commercialRightsApproved!==false||s.evidenceHumanReviewed!==false)throw Error('Do not assert rights approval in an unreviewed technical coverage manifest')
  }
  for(const ed of usage.editions){for(const id of ed.sourceIds){
    if(!sourceNames.has(id))throw Error('Unregistered source used in final film: '+id)
    keyset.add(id)
  }}
  if(sourceNames.size===0||keyset.size!==sourceNames.size)throw Error('Orphaned or missing source evidence')
  return true
}
async function safeDir(path){try{const s=await lstat(path);return s.isDirectory()&&!s.isSymbolicLink()}catch{return false}}
async function inspectDoc(path,expected){
  let stat;try{stat=await lstat(path)}catch{return {ok:false,reason:'missing_license_document'}}
  if(!stat.isFile()||stat.isSymbolicLink()||stat.size<30||stat.size>20_000_000)return {ok:false,reason:'unsafe_evidence_document'}
  let fp
  try{fp=await open(path,constants.O_RDONLY|constants.O_NOFOLLOW)}catch{return {ok:false,reason:'unsafe_evidence_document'}}
  try{
    const magic=Buffer.alloc(5);await fp.read(magic,0,5,0)
    if(magic.toString()!=='%PDF-')return {ok:false,reason:'evidence_not_pdf'}
    const hash=createHash('sha256'),buf=Buffer.allocUnsafe(256*1024);let offset=0
    while(true){const {bytesRead}=await fp.read(buf,0,buf.length,offset);if(!bytesRead)break;hash.update(buf.subarray(0,bytesRead));offset+=bytesRead}
    return hash.digest('hex')===expected?{ok:true,reason:null}:{ok:false,reason:'rights_evidence_hash_mismatch'}
  }finally{await fp.close()}
}
export async function auditRightsEvidence(root,usage,masterPlan){
  validateUsage(usage,masterPlan)
  const abs=resolve(root),rights=join(abs,'rights');const safe=await safeDir(abs)&&await safeDir(rights)
  const rows=[]
  for(const s of usage.sources){
    const file=safe?await inspectDoc(join(rights,s.evidenceFile),s.evidenceSha256):{ok:false,reason:'rights_directory_missing_or_symlink'}
    rows.push({sourceId:s.id,type:s.type,usedIn:usage.editions.filter(e=>e.sourceIds.includes(s.id)).map(e=>e.finalId),evidenceSha256:s.evidenceSha256,
      evidenceBytesVerified:file.ok,evidenceState:file.ok?'document_bytes_present_human_legal_review_pending':file.reason,commercialRightsApproved:false,legalInterpretationAvailable:false})
  }
  const present=rows.filter(r=>r.evidenceBytesVerified).length
  return {schemaVersion:1,project:'OSA CINEMA',status:present===rows.length?'DOCUMENT_BYTES_COMPLETE_LEGAL_HOLD':'RIGHTS_DOCUMENTATION_INCOMPLETE',
    coverage:{registeredSources:rows.length,documentBytesVerified:present,missing:rows.length-present,coveredEditions:4},sources:rows,
    independentLegalSignoffPresent:false,rightsCleared:false,publishAllowed:false,
    disclaimer:'A matching PDF digest is neither proof of ownership nor permission to distribute. A qualified independent legal review is mandatory.'}
}
async function cli(argv){
  const opts={root:'',usage:'',masters:'',report:'',strict:false}
  for(let i=0;i<argv.length;i++){
    const a=argv[i]
    if(a==='--root')opts.root=argv[++i]
    else if(a==='--usage')opts.usage=argv[++i]
    else if(a==='--masters')opts.masters=argv[++i]
    else if(a==='--report')opts.report=argv[++i]
    else if(a==='--strict-legal-release')opts.strict=true
    else throw Error('Unknown flag '+a)
  }
  if(!opts.root||!opts.usage||!opts.masters)throw Error('Expected --root --usage --masters')
  const [usage,masters]=await Promise.all([readFile(opts.usage,'utf8'),readFile(opts.masters,'utf8')])
  const r=await auditRightsEvidence(opts.root,JSON.parse(usage),JSON.parse(masters))
  if(opts.report){const out=resolve(opts.report),source=resolve(opts.root);if(out===source||out.startsWith(source+sep))throw Error('Keep audit output outside private evidence directory');await mkdir(dirname(out),{recursive:true});await writeFile(out,JSON.stringify(r,null,2)+'\n',{flag:'wx',mode:0o600})}
  console.log('OSA_V25_RIGHTS_HOLD '+JSON.stringify({status:r.status,coverage:r.coverage,publishAllowed:false}))
  if(opts.strict)process.exitCode=2
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url))cli(process.argv.slice(2)).catch(e=>{console.error(e.message);process.exitCode=2})
