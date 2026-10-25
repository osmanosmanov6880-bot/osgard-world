/**
 * OSA CINEMA V27: the non-deploying, fail-closed release-evidence board.
 * It binds candidate technical/evidence reports to exact file hashes. Even
 * perfect reports do not constitute license, human approval or production QA.
 */
import { createHash } from 'node:crypto'
import { readFile, writeFile, mkdir } from 'node:fs/promises'
import { dirname, resolve, sep } from 'node:path'
import { fileURLToPath } from 'node:url'
const SHA=/^[a-f0-9]{64}$/
export const EXTERNAL_GATES=Object.freeze([
 'independent_documented_commercial_rights_legal_opinion',
 'independently_verified_ru_en_spoken_content',
 'signed_final_director_and_sound_approval',
 'human_approved_final_ru_en_subtitles',
 'real_production_https_access_and_integrity',
 'independent_real_mobile_and_desktop_browser_acceptance',
 'publisher_signed_authorization_for_exact_release_hash',
 'proven_production_rollback_and_post_release_observability'
])
const hash=v=>createHash('sha256').update(JSON.stringify(v)).digest('hex')
export function buildGoNoGoBoard(v24,v25,delivery=[]){
  if(v24?.schemaVersion!==1||v24.project!=='OSA CINEMA'||v24.recordedFilmReleaseAuthorized!==false||v24.publicCatalogueWriteAllowed!==false||v24.paidCheckoutAllowed!==false||!Array.isArray(v24.assets)||v24.assets.length!==4)throw Error('V24 final-master evidence is missing or fraudulently released')
  if(v25?.schemaVersion!==1||v25.project!=='OSA CINEMA'||v25.rightsCleared!==false||v25.publishAllowed!==false||!Array.isArray(v25.sources)||!v25.coverage)throw Error('V25 legal evidence is missing or falsely cleared')
  if(!Array.isArray(delivery)||delivery.length!==4)throw Error('Four local delivery QA receipts required')
  const ids=new Set(v24.assets.map(a=>a.id));if(ids.size!==4)throw Error('Duplicate V24 edition source identities')
  const rows=[],technicalBlockers=[]
  for(const a of v24.assets){
    if(!SHA.test(a.originalSha256||'')||!SHA.test(a.finalSha256||'')||!SHA.test(a.captionSha256||''))throw Error('Invalid source/master/caption identity')
    const matched=delivery.filter(d=>d.sourceSha256===a.finalSha256)
    const coverage=v25.sources.filter(s=>s.usedIn?.includes(a.id))
    const ready=Boolean(a.technicalCandidatePassed&&a.mediaVerified&&a.captionVerified&&Array.isArray(a.blockers)&&a.blockers.length===0)
    if(!ready)technicalBlockers.push('v24_master_or_captions_not_verified:'+a.id)
    if(coverage.length===0||coverage.some(s=>!s.evidenceBytesVerified))technicalBlockers.push('v25_rights_document_bytes_missing:'+a.id)
    if(matched.length!==1||matched[0]?.safeLoopbackVerified!==true||matched[0]?.status!=='LOOPBACK_RANGE_QA_PASS_NOT_PUBLIC'||matched[0]?.errors?.length!==0||
      matched[0]?.tests?.head!==200||matched[0]?.tests?.firstRange?.status!==206||matched[0]?.tests?.invalidRange!==416||
      matched[0]?.productionDeploymentVerified!==false||matched[0]?.publicationAuthorized!==false)technicalBlockers.push('v26_local_delivery_not_verified:'+a.id)
    rows.push({id:a.id,locale:a.locale,edition:a.edition,finalSha256:a.finalSha256,captionSha256:a.captionSha256,technicalMasterPass:ready,
      rightsDocumentBytesReported:coverage.length>0&&coverage.every(s=>s.evidenceBytesVerified),localRangeEvidence:matched.length===1&&matched[0]?.status==='LOOPBACK_RANGE_QA_PASS_NOT_PUBLIC',
      humanReviewed:false,publiclyReleased:false})
  }
  if(v25.coverage.coveredEditions!==4||v25.coverage.documentBytesVerified!==v25.coverage.registeredSources||v25.coverage.missing!==0)technicalBlockers.push('v25_incomplete_rights_evidence_inventory')
  if(v24.technical.passed!==4||v24.technical.failed!==0)technicalBlockers.push('v24_incomplete_four_master_coverage')
  const technicalReady=technicalBlockers.length===0
  return {schemaVersion:1,project:'OSA CINEMA',stage:'V27_INDEPENDENT_RELEASE_DECISION_PENDING',
    result:'NO_GO',technicalCandidateEvidenceComplete:technicalReady,technicalBlockers,
    verifiedReportFingerprints:{v24:hash(v24),v25:hash(v25),v26:delivery.map(hash)},candidateAssetFingerprint:hash(rows.map(r=>[r.id,r.finalSha256,r.captionSha256])),
    editions:rows,externalAuthorizationsNotProvided:EXTERNAL_GATES,
    publicFilmPublicationAuthorized:false,paidCheckoutEnabled:false,productionDeploymentPerformed:false,
    note:'Integrity/evidence checks are not a rights license. A separate real legal/editorial signoff, physically tested production and human publisher decision are required. No automatic GO command exists.'}
}
async function main(args){
 const o={v24:'',v25:'',v26:'',out:'',strict:false}
 for(let i=0;i<args.length;i++){
  const a=args[i]
  if(a==='--v24')o.v24=args[++i]
  else if(a==='--v25')o.v25=args[++i]
  else if(a==='--v26')o.v26=args[++i]
  else if(a==='--out')o.out=args[++i]
  else if(a==='--strict-publish')o.strict=true
  else throw Error('Unknown option '+a)
 }
 if(!o.v24||!o.v25||!o.v26)throw Error('Expected --v24 --v25 --v26')
 const [a,b,c]=await Promise.all([o.v24,o.v25,o.v26].map(x=>readFile(x,'utf8').then(JSON.parse)))
 const board=buildGoNoGoBoard(a,b,c)
 if(o.out){const out=resolve(o.out);await mkdir(dirname(out),{recursive:true});await writeFile(out,JSON.stringify(board,null,2)+'\n',{mode:0o600,flag:'wx'})}
 console.log('OSA_CINEMA_V27_NO_GO '+JSON.stringify({result:board.result,technicalComplete:board.technicalCandidateEvidenceComplete,technicalBlockers:board.technicalBlockers,externalGates:board.externalAuthorizationsNotProvided.length}))
 if(o.strict)process.exitCode=2
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url))main(process.argv.slice(2)).catch(e=>{console.error(e.message);process.exitCode=2})
