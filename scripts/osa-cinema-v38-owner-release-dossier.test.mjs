import { test } from 'node:test'
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { EXTERNAL_GATES } from './osa-cinema-v27-release-board.mjs'
import { composePrivateDossier, auditPrivateOwnerDossier, parseArgs } from './osa-cinema-v38-owner-release-dossier.mjs'

const hash = 'a'.repeat(64)
function objects() {
  return {
    historical: { stage:'V35_HISTORICAL_CODE_REPOSITORY_GUARD',
      verifiedHistoricalSnapshot:true,testOrCustomPinMode:false,releaseDecision:'NO_GO',
      publicationAuthorized:false,rightsCleared:false,paidCheckoutEnabled:false },
    receipts: {stage:'V36_PRIVATE_RECEIPT_INTEGRITY',
      reportSelfConsistent:true,receiptRecordsValidated:4,decision:'NO_GO',
      publicationAuthorized:false,rightsCleared:false,paidCheckoutEnabled:false,
      outstandingIndependentGates:[...EXTERNAL_GATES]},
    media: {stage:'V37_PRIVATE_MEDIA_BYTE_AUDIT',bytesMatched:true,
      reportPackageSelfConsistent:true,verifiedPrivateVideoFiles:4,
      verifiedPrivateCaptionFiles:4,checkedWebvttHeadersAndFirstCues:true,
      perEdition:[1,2,3,4].map(i=>({id:'osa-demo-'+i,bytesMatched:true})),
      decision:'NO_GO',publicationAuthorized:false,rightsCleared:false,
      paidCheckoutEnabled:false,publicCatalogueWriteAllowed:false,
      productionDeploymentPerformed:false},
  }
}
function signed() {
  return {stage:'V30_INDEPENDENT_EXTERNAL_SIGNATURE_VERIFICATION',
    status:'ALL_EIGHT_SIGNATURES_CRYPTOGRAPHICALLY_VERIFIED_PRIVATE_ONLY',
    verifiedSignatures:8,requiredSignatures:8,missingRoles:[],invalidRoles:[],
    releaseFingerprint:hash,signerRegistrySha256:hash,
    publicFilmPublicationAuthorized:false,paidCheckoutEnabled:false,
    legalContentReviewedBySoftware:false,publisherLegalAuthorityVerifiedBySoftware:false,
    realProductionVerifiedBySoftware:false,
    decision:'NO_GO_UNTIL_INDEPENDENT_FINAL_HUMAN_AND_PRODUCTION_RELEASE'}
}
const opts=['--repo-root','/private/source','--receipts-dir','/private/reports',
  '--masters-dir','/private/masters','--captions-dir','/private/captions']

test('V38 private dossier contract blocks false release claims', async t => {
  await t.test('all technical stages pass but commercial film remains explicitly NO_GO',()=>{
    const r=composePrivateDossier(objects())
    assert.equal(r.releaseDecision,'NO_GO')
    assert.equal(r.publicationAuthorized,false)
    assert.equal(r.rightsCleared,false)
    assert.equal(r.paidCheckoutEnabled,false)
    assert.equal(r.productionDeploymentPerformed,false)
    assert.equal(r.evidence.checkedLocalMP4,4)
    assert.equal(r.evidence.checkedLocalWebVTT,4)
    assert.equal(r.evidence.signedClaimsStatus,'NOT_PROVIDED')
    assert.deepEqual(r.independentLegalHumanAndProductionGatesStillRequired,EXTERNAL_GATES)
    assert.equal(Object.hasOwn(r,'privateKeys'),false)
  })
  await t.test('cryptographic acceptance of claims never constitutes legal or editorial approval',()=>{
    const d=objects();d.receipts.receiptRecordsValidated=6;d.signatures=signed()
    const r=composePrivateDossier(d)
    assert.equal(r.evidence.signedClaimCount,8)
    assert.equal(r.evidence.signedClaimsStatus,'CRYPTOGRAPHICALLY_VERIFIED_PRIVATE_ONLY')
    assert.equal(r.legalRightsIndependentReviewComplete,false)
    assert.equal(r.publisherLegalAuthorityEstablishedBySoftware,false)
    assert.equal(r.releaseDecision,'NO_GO')
  })
  await t.test('custom or test historical pins do not satisfy real history',()=>{
    const d=objects();d.historical.testOrCustomPinMode=true
    assert.throws(()=>composePrivateDossier(d),/historical/)
  })
  await t.test('historical source mutation or publication flip blocks dossier',()=>{
    const d=objects();d.historical.verifiedHistoricalSnapshot=false
    assert.throws(()=>composePrivateDossier(d),/historical/)
    const q=objects();q.historical.publicationAuthorized=true
    assert.throws(()=>composePrivateDossier(q),/historical/)
  })
  await t.test('missing receipts or fake receipt publication blocks dossier',()=>{
    const d=objects();d.receipts.reportSelfConsistent=false
    assert.throws(()=>composePrivateDossier(d),/receipts/)
    const q=objects();q.receipts.rightsCleared=true
    assert.throws(()=>composePrivateDossier(q),/receipts/)
  })
  await t.test('missing external human gates blocks dossier',()=>{
    const d=objects();d.receipts.outstandingIndependentGates.pop()
    assert.throws(()=>composePrivateDossier(d),/receipts/)
  })
  await t.test('missing or duplicated private editions blocks dossier',()=>{
    const d=objects();d.media.perEdition[1].id=d.media.perEdition[0].id
    assert.throws(()=>composePrivateDossier(d),/MP4/)
    const q=objects();q.media.verifiedPrivateCaptionFiles=3
    assert.throws(()=>composePrivateDossier(q),/MP4/)
  })
  await t.test('tampered private V37 release flags block dossier',()=>{
    const d=objects();d.media.paidCheckoutEnabled=true
    assert.throws(()=>composePrivateDossier(d),/MP4/)
    const q=objects();q.media.productionDeploymentPerformed=true
    assert.throws(()=>composePrivateDossier(q),/MP4/)
  })
  await t.test('cryptographic claims require six original receipts and no missing role',()=>{
    const d=objects();d.signatures=signed()
    assert.throws(()=>composePrivateDossier(d),/rights evidence/)
    const q=objects();q.receipts.receiptRecordsValidated=6;q.signatures=signed()
    q.signatures.missingRoles=['publisher']
    assert.throws(()=>composePrivateDossier(q),/V30 signer/)
  })
  await t.test('expired, incomplete or legally inflated V30 claims are never promoted',()=>{
    const d=objects();d.receipts.receiptRecordsValidated=6;d.signatures=signed()
    d.signatures.status='EXTERNAL_ATTESTATIONS_HOLD'
    assert.throws(()=>composePrivateDossier(d),/V30 signer/)
    const q=objects();q.receipts.receiptRecordsValidated=6;q.signatures=signed()
    q.signatures.publisherLegalAuthorityVerifiedBySoftware=true
    assert.throws(()=>composePrivateDossier(q),/V30 signer/)
  })
  await t.test('all required CLI flags are accepted in any order',()=>{
    const parsed=parseArgs([...opts])
    assert.equal(parsed.repoRoot,'/private/source')
    assert.equal(parsed.receiptsDir,'/private/reports')
  })
  await t.test('unknown flags, omitted values and duplicate flags are rejected',()=>{
    assert.throws(()=>parseArgs(['--not-a-real-flag','n',...opts]),/argument/)
    assert.throws(()=>parseArgs([...opts,'--masters-dir','repeated']),/argument/)
    assert.throws(()=>parseArgs(opts.slice(0,6)),/required/)
  })
  await t.test('external signing mode requires all four independent options',()=>{
    assert.throws(()=>parseArgs([...opts,'--registry','/private/pub.json']),/all four signer options/)
    const good=[...opts,'--registry','/private/pub.json','--registry-sha256',hash,
      '--attestations','/private/claims.json','--evidence-dir','/private/pdf']
    assert.equal(parseArgs(good).registrySha256,hash)
    assert.throws(()=>parseArgs(good.map(v=>v===hash?'not-a-sha':v)),/SHA-256/)
  })
  await t.test('unsafe missing absolute private directory fails closed before reading media',async()=>{
    await assert.rejects(auditPrivateOwnerDossier({repoRoot:'/tmp/repo',receiptsDir:'relative/path',
      mastersDir:'/tmp/masters',captionsDir:'/tmp/captions'}),/absolute local/)
  })
  await t.test('CLI with missing evidence emits HOLD with nonzero exit and no private info',()=>{
    const run=spawnSync(process.execPath,[fileURLToPath(new URL('./osa-cinema-v38-owner-release-dossier.mjs',import.meta.url)),...opts],
      {encoding:'utf8',timeout:10000})
    assert.equal(run.status,1)
    assert.match(run.stderr,/HOLD/)
    assert.doesNotMatch(run.stdout,/TECHNICAL_EVIDENCE_VERIFIED/)
    assert.doesNotMatch(run.stdout,/publicationAuthorized.*true/)
  })
})
