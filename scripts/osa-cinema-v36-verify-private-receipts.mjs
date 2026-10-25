/**
 * OSA CINEMA V36: independently inspect the *offline* V29 report directory.
 * This verifies record consistency and tamper evidence inside the package.
 * It does NOT authenticate the publisher, inspect underlying media, clear rights,
 * or ever authorize a public film, payments or deployment.
 */
import { constants } from 'node:fs'
import { lstat, readdir, open } from 'node:fs/promises'
import { createHash } from 'node:crypto'
import { dirname, join, resolve, isAbsolute } from 'node:path'
import { fileURLToPath } from 'node:url'
import { EXTERNAL_GATES } from './osa-cinema-v27-release-board.mjs'

const BASE = ['V28_CANDIDATE_MANIFEST.json','V24_MEDIA_QA.json','V26_PRIVATE_DELIVERY_QA.json']
const RIGHTS = ['V25_RIGHTS_BYTES_QA.json','V27_FINAL_NO_GO_BOARD.json']
const END = 'V29_OWNER_PREFLIGHT_NO_GO.json'
const CHECKS = 'CHECKSUMS.sha256'
const SHA = /^[a-f0-9]{64}$/
const SLOTS = new Set(['trailer-workprint:ru','trailer-workprint:en', 'directors-workprint:ru','directors-workprint:en'])
const hash = data => createHash('sha256').update(data).digest('hex')
const fingerprint = obj => hash(JSON.stringify(obj))
const assertSafe = (truth,msg) => { if(!truth) throw Error('OSA_V36_EVIDENCE_HOLD: '+msg) }
const exactSet = (values,expected) => Array.isArray(values) && values.length===expected.length &&
  new Set(values).size===expected.length && expected.every(x=>values.includes(x))
const privateFlags = d => d?.publicationAuthorized===false && d?.rightsCleared===false &&
  d?.paidCheckoutEnabled===false

async function ensurePlainTree(path) {
  for(let p=resolve(path);;p=dirname(p)) {
    const st=await lstat(p)
    assertSafe(!st.isSymbolicLink() && st.isDirectory(),'symbolic-linked or invalid evidence directory')
    if(dirname(p)===p)break
  }
}
async function safeRead(path,maximum=2_000_000) {
  const before=await lstat(path)
  assertSafe(before.isFile() && !before.isSymbolicLink() && before.size>0 && before.size<=maximum,
    'missing, linked, empty or oversized report')
  const fd=await open(path,constants.O_RDONLY | (constants.O_NOFOLLOW||0))
  try {
    const initial=await fd.stat()
    assertSafe((process.platform==='win32' || (before.mode & 0o077)===0), 'private report is readable by others')
    assertSafe(initial.isFile() && initial.ino===before.ino && initial.dev===before.dev && initial.size===before.size,
      'report changed before read')
    const bytes=await fd.readFile()
    const after=await fd.stat()
    assertSafe(bytes.length===initial.size && after.size===initial.size &&
      after.mtimeMs===initial.mtimeMs && after.ctimeMs===initial.ctimeMs &&
      after.ino===initial.ino && after.dev===initial.dev,'report changed while reading')
    return bytes
  } finally {await fd.close()}
}
function validCandidates(assets) {
  assertSafe(Array.isArray(assets) && assets.length===4,'exact four final MP4/VTT candidates required')
  const slots=new Set(),ids=new Set(),mp4=new Set(),vtt=new Set()
  for(const a of assets) {
    assertSafe(a && typeof a==='object' && /^osa-[a-z0-9-]{3,70}$/.test(a.id||'') &&
      SLOTS.has(a.edition+':'+a.locale) && SHA.test(a.sourceSha256||'') &&
      SHA.test(a.masterSha256||'') && SHA.test(a.captionSha256||'') &&
      a.masterName===a.id+'.mp4' && a.captionName===a.id+'.vtt' &&
      Number.isSafeInteger(a.masterBytes) && a.masterBytes>0,'invalid final candidate identity')
    assertSafe(!slots.has(a.edition+':'+a.locale) && !ids.has(a.id) &&
      !mp4.has(a.masterSha256) && !vtt.has(a.captionSha256),'duplicate edition or final bytes')
    slots.add(a.edition+':'+a.locale);ids.add(a.id);mp4.add(a.masterSha256);vtt.add(a.captionSha256)
  }
  assertSafe(slots.size===4,'incomplete bilingual short and long editions')
}
/** Pure structure/fingerprint check after exact bytes were verified against CHECKSUMS.sha256. */
export function auditPrivateReceipts(records, {hasRights}) {
  const [v28,v24,v26,v29]=[records[BASE[0]],records[BASE[1]],records[BASE[2]],records[END]]
  assertSafe(v28?.schemaVersion===1 && v28.project==='OSA CINEMA' &&
    v28.stage==='V28_TECHNICAL_INTAKE_ONLY' && v28.publicationAuthorized===false &&
    v28.commercialRightsCleared===false, 'V28 manifest is not private technical intake')
  validCandidates(v28.assets)
  assertSafe(v24?.schemaVersion===1 && v24.project==='OSA CINEMA' &&
    v24.technical?.passed===4 && v24.technical?.failed===0 &&
    Array.isArray(v24.assets) && v24.assets.length===4 &&
    v24.recordedFilmReleaseAuthorized===false && v24.paidCheckoutAllowed===false,
    'V24 lacks four privately verified masters or falsely authorizes release')
  assertSafe(exactSet(v24.assets.map(a=>a.id),v28.assets.map(a=>a.id)),
    'V24 master identities differ from V28')
  const byId=new Map(v28.assets.map(a=>[a.id,a]))
  for(const a of v24.assets){const src=byId.get(a.id)
    assertSafe(a.originalSha256===src.sourceSha256 && a.finalSha256===src.masterSha256 &&
      a.captionSha256===src.captionSha256 && a.mediaVerified===true &&
      a.captionVerified===true && a.technicalCandidatePassed===true &&
      Array.isArray(a.blockers) && a.blockers.length===0 &&
      a.humanAudioLanguageApproved===false && a.commercialRightsCleared===false &&
      a.publisherAuthorized===false, 'V24 master evidence differs or claims human release')
  }
  assertSafe(Array.isArray(v26) && v26.length===4 && v26.every(x=>x?.status==='LOOPBACK_RANGE_QA_PASS_NOT_PUBLIC' &&
    x.fullContentVerified===true && x.publicationAuthorized===false),
    'V26 must contain four private-only delivery results')
  assertSafe(v29?.schemaVersion===1 && v29.project==='OSA CINEMA' &&
    v29.stage==='V29_PRIVATE_OWNER_PREFLIGHT' && v29.result==='NO_GO' &&
    privateFlags(v29) && v29.publicCatalogueWriteAllowed===false &&
    v29.productionDeploymentPerformed===false, 'V29 owner report attempts to promote the film')
  assertSafe(exactSet(v29.independentExternalAuthorizationsOutstanding,EXTERNAL_GATES) &&
    Array.isArray(v29.blockers) && EXTERNAL_GATES.every(g=>v29.blockers.includes(g)),
    'V29 external human and production gates are missing')
  assertSafe(v29.technical?.mastersPassed===4 && v29.technical.privateHttpPassed===4 &&
    v29.fingerprints?.v28===fingerprint(v28) && v29.fingerprints.v24===fingerprint(v24) &&
    exactSet(v29.fingerprints.v26,v26.map(fingerprint)), 'V29 technical totals or fingerprints disagree')
  assertSafe(Array.isArray(v29.candidateAssets) && v29.candidateAssets.length===4,
    'V29 final candidates missing')
  const aMap=new Map(v28.assets.map(a=>[a.id,a]))
  assertSafe(exactSet(v29.candidateAssets.map(a=>a.id),v28.assets.map(a=>a.id)),
    'V29 final candidate identifiers changed')
  for(const item of v29.candidateAssets) {
    const original=aMap.get(item.id)
    assertSafe(item.edition===original.edition && item.locale===original.locale &&
      item.finalSha256===original.masterSha256 && item.captionSha256===original.captionSha256,
      'V29 final candidate bytes differ from V28')
  }
  const deliveryHashes=new Set(v26.map(a=>a.sourceSha256))
  assertSafe(exactSet([...deliveryHashes],v28.assets.map(a=>a.masterSha256)),
    'V26 private delivery reports do not bind exactly four V28 files')
  if(hasRights) {
    const v25=records[RIGHTS[0]],v27=records[RIGHTS[1]]
    assertSafe(v25?.schemaVersion===1 && v25.project==='OSA CINEMA' &&
      v25.rightsCleared===false && v25.publishAllowed===false &&
      Array.isArray(v25.sources) && Number.isSafeInteger(v25.coverage?.documentBytesVerified),
      'V25 falsely asserts commercial rights')
    assertSafe(v27?.schemaVersion===1 && v27.project==='OSA CINEMA' &&
      v27.result==='NO_GO' && v27.publicFilmPublicationAuthorized===false &&
      v27.paidCheckoutEnabled===false && v27.productionDeploymentPerformed===false,
      'V27 falsely asserts legal or production release')
    assertSafe(v29.fingerprints.v25===fingerprint(v25) &&
      v29.fingerprints.v27===fingerprint(v27) &&
      v29.technical.evidenceDocumentsVerified===v25.coverage.documentBytesVerified &&
      v29.technical.evidenceTechnicallyComplete===v27.technicalCandidateEvidenceComplete,
      'V25/V27 evidence fingerprints or coverage disagree')
  } else {
    assertSafe(v29.fingerprints.v25===null && v29.fingerprints.v27===null &&
      v29.technical.evidenceDocumentsVerified===0 &&
      v29.technical.evidenceTechnicallyComplete===false &&
      v29.blockers.includes('rights_usage_manifest_and_real_document_ledger_missing'),
      'Absent rights receipts cannot be claimed present')
  }
  return Object.freeze({schemaVersion:1,project:'OSA CINEMA',stage:'V36_PRIVATE_RECEIPT_INTEGRITY',
    receiptRecordsValidated:hasRights?6:4,reportSelfConsistent:true,
    receiptsCryptographicallySigned:false,underlyingMediaBytesRechecked:false,
    legalRightsEstablished:false,humanEditorialApprovalEstablished:false,
    productionHttpsAndDeviceAcceptance:false,publisherAuthorizationVerified:false,
    publicationAuthorized:false,rightsCleared:false,paidCheckoutEnabled:false,
    outstandingIndependentGates:[...EXTERNAL_GATES],decision:'NO_GO',
    notice:'Checksums detect changes relative to this local manifest. They do not authenticate its author, the underlying media, legal rights or release authority.'})
}
export async function verifyPrivateReceiptDirectory({directory}) {
  assertSafe(typeof directory==='string' && isAbsolute(directory),'absolute local evidence directory required')
  const dir=resolve(directory)
  assertSafe(!dir.replace(/\\/g,'/').startsWith('//'),'network UNC evidence paths refused')
  await ensurePlainTree(dir)
  const dirStat=await lstat(dir)
  assertSafe(process.platform==='win32' || (dirStat.mode & 0o077)===0,
    'private receipt directory is readable by other users')
  const names=await readdir(dir)
  const hasRights=RIGHTS.every(name=>names.includes(name))
  assertSafe(hasRights===RIGHTS.some(name=>names.includes(name)), 'partial V25/V27 rights receipt pair')
  const expected=[...BASE,...(hasRights?RIGHTS:[]),END,CHECKS]
  assertSafe(exactSet(names,expected),'extra, duplicate or missing receipt file')
  const checksumText=(await safeRead(join(dir,CHECKS),2048)).toString('utf8')
  const lines=checksumText.trimEnd().split('\n')
  const reportNames=expected.filter(x=>x!==CHECKS)
  assertSafe(lines.length===reportNames.length,'checksum manifest has an incorrect number of entries')
  const records={}
  for(let i=0;i<reportNames.length;i++) {
    const match=/^([a-f0-9]{64})  ([A-Z0-9_]+\.json)$/.exec(lines[i])
    assertSafe(Boolean(match) && match[2]===reportNames[i],'unexpected or unsafe checksum-manifest entry')
    const raw=await safeRead(join(dir,reportNames[i]))
    assertSafe(hash(raw)===match[1],'SHA-256 mismatch: '+reportNames[i])
    try{records[reportNames[i]]=JSON.parse(raw.toString('utf8'))}
    catch{throw Error('OSA_V36_EVIDENCE_HOLD: invalid JSON report '+reportNames[i])}
  }
  return auditPrivateReceipts(records,{hasRights})
}
if(process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  if(process.argv.length!==4 || process.argv[2]!=='--evidence-dir') {
    console.error('Usage: node scripts/osa-cinema-v36-verify-private-receipts.mjs --evidence-dir /absolute/private/V29-folder')
    process.exitCode=2
  } else {
    verifyPrivateReceiptDirectory({directory:process.argv[3]}).then(result=>{
      console.log(JSON.stringify(result,null,2))
      console.log('OSA CINEMA V36: receipt files self-consistent; public film and payment still NO-GO')
    }).catch(e=>{console.error(e.message);process.exitCode=1})
  }
}