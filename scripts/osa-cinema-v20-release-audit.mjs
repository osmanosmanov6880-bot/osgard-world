/** V20 fail-closed release audit. No checkbox or JSON file can grant copyright clearance. */
import { readFile, lstat, readdir, writeFile } from 'node:fs/promises'
import { join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createHash } from 'node:crypto'

const EVIDENCE_KINDS=['rights','spoken_language','final_edit_audio','captions','durable_delivery','live_browser','publisher']
const CHECKED = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/
const REVIEWER = /^[a-zA-Z0-9_.-]{3,90}$/
const HASH = /^[a-f0-9]{64}$/

export function baselineIntegrity(original,scene,four) {
  if (!Array.isArray(original?.assets) || original.assets.length!==4 || !Array.isArray(scene?.assets) || scene.assets.length!==4) throw Error('Incomplete film provenance chain')
  if (four?.publicationAuthorized!==false || four?.rightsCleared!==false || four?.finalMixApproved!==false) throw Error('Unverified V18 rights falsely marked approved')
  if (four?.audioTracks?.length!==4 || four?.picture?.width!==1920 || four?.picture?.height!==1080 || !HASH.test(four.sha256||'')) throw Error('Four-track technical master identity not recorded')
  if (!four?.originalPictureAndBothOriginalSoundtracksBitstreamSha256Match || !four?.verifiedOutputDecodedAllFiveStreamsWithoutErrors) throw Error('Private audio/video integrity unverified')
  const map=new Map(original.assets.map(x=>[x.id,x]))
  if(map.size!==4 || new Set(original.assets.map(x=>x.edition+':'+x.locale)).size!==4) throw Error('Duplicate source identity')
  for(const row of scene.assets){
    const src=map.get(row.id)
    if(!src || src.locale!==row.locale || src.sha256!==row.originalSha256 || src.sizeBytes!==row.originalBytes || !['ru','en'].includes(row.locale) || row.publicationAuthorized!==false) throw Error('Picture cut source provenance mismatch')
    const count=src.edition==='directors-workprint'?64:10
    if(row.sceneCutCount!==count || row.sceneCutTimecodes?.length!==count || row.shots?.length!==count+1) throw Error('Unverified 64/10 editorial cut map')
  }
  for(const edition of ['directors-workprint','trailer-workprint']){
    const ru=scene.assets.find(x=>x.id===original.assets.find(a=>a.locale==='ru' && a.edition===edition)?.id)
    const en=scene.assets.find(x=>x.id===original.assets.find(a=>a.locale==='en' && a.edition===edition)?.id)
    if(!ru || !en || JSON.stringify(ru.sceneCutTimecodes)!==JSON.stringify(en.sceneCutTimecodes)) throw Error('RU/EN cut timelines diverge')
  }
  return { sourceCount:4,fullFilmCutsPerLocale:64,previewCutsPerLocale:10,fourTrackSha256:four.sha256,verifiedPrivateEngineeringBaseline:true }
}
export function releaseMatrix(provenance, evidence={}) {
  if(provenance?.verifiedPrivateEngineeringBaseline!==true) throw Error('Missing proven technical baseline')
  const blockers=['human_spoken_language_review','documented_commercial_rights_review','director_sound_signoff','approved_synced_ru_en_webvtt','permanent_delivery_with_range_and_mime','real_desktop_mobile_playback_acceptance','explicit_publisher_authorization']
  // Documents submitted to an offline desk are evidence candidates, not legal/editorial proof.
  return { schemaVersion:1, project:'OSA CINEMA', stage:'V20_PRIVATE_ENGINEERING', privateTechnicalBaseline:provenance, evidenceCandidates:evidence, remainingMandatoryBlockers:blockers, publicationAuthorized:false, mediaCatalogueMutationAllowed:false, checkoutEnabled:false, pendingHumanLegalReview:true, warning:'Only a separate human-reviewed release decision and tested protected production delivery can ever approve publication. This command cannot issue that decision.' }
}
export async function auditPrivateEvidence(root, assets) {
  const s=await lstat(root)
  if(!s.isDirectory() || s.isSymbolicLink())throw Error('Unsafe evidence root')
  const records=[]
  for(const asset of assets){
    if(!/^osa-[a-z0-9-]+$/.test(asset.id) || !HASH.test(asset.sha256||''))throw Error('Unsafe evidence identity')
    const per={sourceId:asset.id,evidenceCandidates:{},humanVerificationRequired:true}
    for(const kind of EVIDENCE_KINDS){
      const path=join(root,asset.id,kind+'.json')
      let status='missing'
      try{
        const st=await lstat(path)
        if(!st.isFile() || st.isSymbolicLink() || st.size>100000 || st.size<50){status='unsafe_file'}
        else {
          const v=JSON.parse(await readFile(path,'utf8'))
          status=v.sourceId===asset.id && v.sourceSha256===asset.sha256 && REVIEWER.test(v.reviewerId||'') && CHECKED.test(v.reviewedAt||'') && HASH.test(v.evidenceSha256||'') && v.reviewRequested===true && v.reviewerNotes?.length>=12 ? 'document_supplied_not_approved' : 'invalid_document'
        }
      }catch(e){if(e.code!=='ENOENT')status='invalid_document'}
      per.evidenceCandidates[kind]=status
    }
    records.push(per)
  }
  return {status:'PRIVATE_EVIDENCE_REQUIRES_REAL_INDEPENDENT_HUMAN_REVIEW',records,rightsCleared:false,publicationAuthorized:false}
}
async function main(args){
  let root='.', evidenceDir=null, reportFile=null, strict=false
  for(let i=0;i<args.length;i++){
    const a=args[i]
    if(a==='--root') root=args[++i]
    else if(a==='--private-evidence-dir') evidenceDir=args[++i]
    else if(a==='--report')reportFile=args[++i]
    else if(a==='--strict-publication')strict=true
    else throw Error('Unknown parameter '+a)
  }
  const source=JSON.parse(await readFile(join(root,'docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json'),'utf8'))
  const scenes=JSON.parse(await readFile(join(root,'docs/OSA_CINEMA_V18_PRIVATE_SCENE_CUT_QC.json'),'utf8'))
  const four=JSON.parse(await readFile(join(root,'docs/OSA_CINEMA_V18_PRIVATE_FOUR_TRACK_QA.json'),'utf8'))
  const verified=baselineIntegrity(source,scenes,four)
  const evidence=evidenceDir?await auditPrivateEvidence(resolve(evidenceDir),source.assets):{}
  const report=releaseMatrix(verified,evidence)
  if(reportFile)await writeFile(resolve(reportFile),JSON.stringify(report,null,2)+'\n')
  console.log('OSA_CINEMA_V20_NO_PUBLICATION '+JSON.stringify(report))
  if(strict)process.exitCode=1 // Human+legal approvals and actual production film playback not performed here.
}
if(process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)) main(process.argv.slice(2)).catch(e=>{console.error(e.stack||String(e));process.exitCode=1})
