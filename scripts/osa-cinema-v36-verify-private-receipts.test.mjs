import { test } from 'node:test'
import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { mkdtemp, mkdir, writeFile, readFile, symlink, rm, realpath } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { auditPrivateReceipts, verifyPrivateReceiptDirectory } from './osa-cinema-v36-verify-private-receipts.mjs'
import { EXTERNAL_GATES } from './osa-cinema-v27-release-board.mjs'

const hash = b => createHash('sha256').update(b).digest('hex')
const fp = obj => hash(JSON.stringify(obj))
const names = ['V28_CANDIDATE_MANIFEST.json','V24_MEDIA_QA.json','V26_PRIVATE_DELIVERY_QA.json']
const rights = ['V25_RIGHTS_BYTES_QA.json','V27_FINAL_NO_GO_BOARD.json']
const last = 'V29_OWNER_PREFLIGHT_NO_GO.json'
const id = ['osa-v15-trailer-ru','osa-v15-trailer-en','osa-v15-directors-ru','osa-v15-directors-en']
const hex = n => n.toString(16).padStart(64,'0')
function fixture({withRights=false}={}) {
  // Synthetic documents ONLY; no film, copyright clearance, or production is represented.
  const assets=id.map((name,i)=>({id:name,edition:i<2?'trailer-workprint':'directors-workprint',
    locale:i%2?'en':'ru',sourceSha256:hex(i+1),masterName:name+'.mp4',masterSha256:hex(i+11),
    masterBytes:100+i,captionName:name+'.vtt',captionSha256:hex(i+21),durationSeconds:20}))
  const v28={schemaVersion:1,project:'OSA CINEMA',stage:'V28_TECHNICAL_INTAKE_ONLY',
    publicationAuthorized:false,commercialRightsCleared:false,assets}
  const v24={schemaVersion:1,project:'OSA CINEMA',stage:'V24_PRIVATE_MEDIA_QA',
    recordedFilmReleaseAuthorized:false,paidCheckoutAllowed:false,technical:{passed:4,failed:0},
    assets:assets.map(a=>({id:a.id,technicalCandidatePassed:true,finalSha256:a.masterSha256,
      originalSha256:a.sourceSha256,captionSha256:a.captionSha256,mediaVerified:true,captionVerified:true,
      blockers:[],humanAudioLanguageApproved:false,commercialRightsCleared:false,publisherAuthorized:false}))}
  const v26=assets.map(a=>({status:'LOOPBACK_RANGE_QA_PASS_NOT_PUBLIC',
    fullContentVerified:true,publicationAuthorized:false,sourceSha256:a.masterSha256,bytes:a.masterBytes}))
  const v25={schemaVersion:1,project:'OSA CINEMA',stage:'V25_PRIVATE_RIGHTS_BYTES_QA',
    rightsCleared:false,publishAllowed:false,sources:[],coverage:{documentBytesVerified:2}}
  const v27={schemaVersion:1,project:'OSA CINEMA',stage:'V27_INDEPENDENT_RELEASE_DECISION_PENDING',
    result:'NO_GO',technicalCandidateEvidenceComplete:false,publicFilmPublicationAuthorized:false,
    paidCheckoutEnabled:false,productionDeploymentPerformed:false}
  const v29={schemaVersion:1,project:'OSA CINEMA',stage:'V29_PRIVATE_OWNER_PREFLIGHT',result:'NO_GO',
    candidatePinnedToPreviousHash:false,publicationAuthorized:false,rightsCleared:false,
    paidCheckoutEnabled:false,publicCatalogueWriteAllowed:false,productionDeploymentPerformed:false,
    candidateAssets:assets.map(a=>({id:a.id,edition:a.edition,locale:a.locale,
      finalSha256:a.masterSha256,captionSha256:a.captionSha256})),
    technical:{mastersPassed:4,privateHttpPassed:4,evidenceDocumentsVerified:withRights?2:0,
      evidenceTechnicallyComplete:false},
    fingerprints:{v28:fp(v28),v24:fp(v24),v26:v26.map(fp),v25:withRights?fp(v25):null,
      v27:withRights?fp(v27):null},
    blockers:[...(!withRights?['rights_usage_manifest_and_real_document_ledger_missing']:[]),...EXTERNAL_GATES],
    independentExternalAuthorizationsOutstanding:[...EXTERNAL_GATES]}
  return {[names[0]]:v28,[names[1]]:v24,[names[2]]:v26,
    ...(withRights?{[rights[0]]:v25,[rights[1]]:v27}:{}),[last]:v29}
}
async function makeFolder(records){
  const directory=await mkdtemp(join(await realpath(tmpdir()),'osa-v36-synthetic-receipts-'))
  const order=[...names,...(Object.hasOwn(records,rights[0])?rights:[]),last]
  const sums=[]
  for(const filename of order){
    const bytes=JSON.stringify(records[filename],null,2)+'\n'
    await writeFile(join(directory,filename),bytes,{mode:0o600})
    sums.push(hash(bytes)+'  '+filename)
  }
  await writeFile(join(directory,'CHECKSUMS.sha256'),sums.join('\n')+'\n',{mode:0o600})
  return directory
}
async function replaceWithRehash(directory,filename,object){
  await writeFile(join(directory,filename),JSON.stringify(object,null,2)+'\n')
  const order=[...names,...(await readFile(join(directory,'CHECKSUMS.sha256'),'utf8')).includes('V25_')?rights:[],last]
  const entries=[]
  for(const name of order)entries.push(hash(await readFile(join(directory,name)))+'  '+name)
  await writeFile(join(directory,'CHECKSUMS.sha256'),entries.join('\n')+'\n')
}

test('V36 offline receipt directory, all-or-nothing self-consistency, release remains NO-GO',async t=>{
  for(const hasRights of [false,true]){
    await t.test('synthetic '+(hasRights?'with':'without')+' rights metadata: PASS never authorizes film',async()=>{
      const fixtureData=fixture({withRights:hasRights})
      const directory=await makeFolder(fixtureData)
      try{
        const result=await verifyPrivateReceiptDirectory({directory})
        assert.equal(result.reportSelfConsistent,true)
        assert.equal(result.receiptRecordsValidated,hasRights?6:4)
        assert.equal(result.decision,'NO_GO')
        for(const key of ['publicationAuthorized','rightsCleared','paidCheckoutEnabled',
          'legalRightsEstablished','publisherAuthorizationVerified','underlyingMediaBytesRechecked',
          'receiptsCryptographicallySigned','humanEditorialApprovalEstablished'])assert.equal(result[key],false)
        assert.deepEqual(result.outstandingIndependentGates,[...EXTERNAL_GATES])
      }finally{await rm(directory,{recursive:true,force:true})}
    })
  }
  const baseline=fixture({withRights:true})
  await t.test('pure structure validation refuses forged publication even if manifest is rehashed',()=>{
    const d=structuredClone(baseline)
    d[last].paidCheckoutEnabled=true
    assert.throws(()=>auditPrivateReceipts(d,{hasRights:true}),/promote the film/)
  })
  await t.test('V28 changed media digest cannot match V29 record, even with updated checksum',()=>{
    const d=structuredClone(baseline)
    d[names[0]].assets[0].masterSha256=hex(99)
    d[last].fingerprints.v28=fp(d[names[0]])
    assert.throws(()=>auditPrivateReceipts(d,{hasRights:true}),/final candidate bytes|V24 master evidence/)
  })
  await t.test('V25 counterfeit rights approval blocked, even with updated fingerprint',()=>{
    const d=structuredClone(baseline)
    d[rights[0]].rightsCleared=true
    d[last].fingerprints.v25=fp(d[rights[0]])
    assert.throws(()=>auditPrivateReceipts(d,{hasRights:true}),/commercial rights/)
  })
  await t.test('missing independent external approval slot blocked',()=>{
    const d=structuredClone(baseline)
    d[last].independentExternalAuthorizationsOutstanding.pop()
    assert.throws(()=>auditPrivateReceipts(d,{hasRights:true}),/external human/)
  })
  await t.test('duplicate candidate edition blocked',()=>{
    const d=structuredClone(baseline)
    d[names[0]].assets[1].locale='ru'
    assert.throws(()=>auditPrivateReceipts(d,{hasRights:true}),/duplicate edition/)
  })
  await t.test('additional unexpected executable causes fail-closed before report reading',async()=>{
    const directory=await makeFolder(baseline)
    try{
      await writeFile(join(directory,'injected.mjs'),'console.log("injected")')
      await assert.rejects(verifyPrivateReceiptDirectory({directory}),/extra, duplicate or missing/)
    }finally{await rm(directory,{recursive:true,force:true})}
  })
  await t.test('checksum mismatches block tampered receipts',async()=>{
    const directory=await makeFolder(baseline)
    try{
      await writeFile(join(directory,last),JSON.stringify({...baseline[last],result:'GO'}))
      await assert.rejects(verifyPrivateReceiptDirectory({directory}),/SHA-256 mismatch/)
    }finally{await rm(directory,{recursive:true,force:true})}
  })
  await t.test('rehashed malicious release report fails semantic guard',async()=>{
    const directory=await makeFolder(baseline)
    try{
      await replaceWithRehash(directory,last,{...baseline[last],publicationAuthorized:true})
      await assert.rejects(verifyPrivateReceiptDirectory({directory}),/promote the film/)
    }finally{await rm(directory,{recursive:true,force:true})}
  })
  await t.test('partial V25/V27 ledger rejected',async()=>{
    const directory=await makeFolder(baseline)
    try{
      await rm(join(directory,rights[0]))
      await assert.rejects(verifyPrivateReceiptDirectory({directory}),/partial V25\/V27/)
    }finally{await rm(directory,{recursive:true,force:true})}
  })
  await t.test('checksum references with traversal or reordered filename rejected',async()=>{
    const directory=await makeFolder(baseline)
    try{
      const file=join(directory,'CHECKSUMS.sha256')
      const s=await readFile(file,'utf8')
      await writeFile(file,s.replace('V28_CANDIDATE_MANIFEST.json','../escape.json'))
      await assert.rejects(verifyPrivateReceiptDirectory({directory}),/unsafe checksum-manifest/)
    }finally{await rm(directory,{recursive:true,force:true})}
  })
  await t.test('linked report file is refused, even if content matches',async()=>{
    if(process.platform==='win32')return
    const directory=await makeFolder(baseline)
    try{
      const f=join(directory,last),target=join(await realpath(tmpdir()),'osa-v36-target-'+process.pid+'.json')
      await writeFile(target,await readFile(f))
      await rm(f)
      await symlink(target,f)
      try{await assert.rejects(verifyPrivateReceiptDirectory({directory}),/linked/)}finally{await rm(target,{force:true})}
    }finally{await rm(directory,{recursive:true,force:true})}
  })
  await t.test('missing evidence directory fails, not automatic success',async()=>{
    const canonical=await realpath(tmpdir())
    await assert.rejects(verifyPrivateReceiptDirectory({directory:join(canonical,'osa-v36-missing-bundle')}))
  })
  await t.test('non-absolute input is forbidden',async()=>{
    await assert.rejects(verifyPrivateReceiptDirectory({directory:'relative/reports'}),/absolute local/)
  })
})