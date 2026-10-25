import { test } from 'node:test'
import assert from 'node:assert/strict'
import { generateKeyPairSync, sign, createHash } from 'node:crypto'
import { mkdtemp, mkdir, writeFile, readFile, rm, symlink } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { spawnSync } from 'node:child_process'
import { EXTERNAL_GATES } from './osa-cinema-v27-release-board.mjs'
import { releaseFingerprint, validateTrustedRegistry, signedMessage, verifyExternalAttestations } from './osa-cinema-v30-external-attestations.mjs'
import { makeSignedApproval } from './osa-cinema-v30-sign-approval.mjs'

const digest=x=>createHash('sha256').update(x).digest('hex')
const hash=s=>digest(Buffer.from(s))
function preflight(){
  const slots=[['osa-directors-ru','directors-workprint','ru'],['osa-directors-en','directors-workprint','en'],['osa-trailer-ru','trailer-workprint','ru'],['osa-trailer-en','trailer-workprint','en']]
  return {schemaVersion:1,project:'OSA CINEMA',stage:'V29_PRIVATE_OWNER_PREFLIGHT',result:'NO_GO',
    candidatePinnedToPreviousHash:true,publicationAuthorized:false,rightsCleared:false,
    paidCheckoutEnabled:false,publicCatalogueWriteAllowed:false,productionDeploymentPerformed:false,
    technical:{mastersPassed:4,privateHttpPassed:4,evidenceDocumentsVerified:8,evidenceTechnicallyComplete:true},
    candidateAssets:slots.map(([id,edition,locale],i)=>({id,edition,locale,finalSha256:hash('media'+i),captionSha256:hash('captions'+i)})),
    fingerprints:{v28:hash('v28'),v24:hash('v24'),v25:hash('v25'),v26:[0,1,2,3].map(x=>hash('v26'+x)),v27:hash('v27')},
    independentExternalAuthorizationsOutstanding:[...EXTERNAL_GATES],blockers:[...EXTERNAL_GATES]}
}
async function fixture(){
  const dir=await mkdtemp(join(tmpdir(),'osa-v30-'))
  const evidenceDir=join(dir,'evidence');await mkdir(evidenceDir)
  const keys=[],signers=[],approvals=[]
  const pf=preflight(),fp=releaseFingerprint(pf)
  const signedAt=new Date(Date.now()-86400000).toISOString()
  const expiresAt=new Date(Date.now()+86400000*30).toISOString()
  for(const [i,gate] of EXTERNAL_GATES.entries()){
    const {privateKey,publicKey}=generateKeyPairSync('ed25519')
    const keyId='role-key-'+(i+1), evidenceFile='approval_'+(i+1)+'.pdf'
    const pdf=Buffer.from('%PDF-1.7\nSYNTHETIC TEST EVIDENCE - NOT A LICENSE '+gate+'\n%%EOF\n')
    await writeFile(join(evidenceDir,evidenceFile),pdf)
    const a={schemaVersion:1,project:'OSA CINEMA',releaseFingerprint:fp,gate,keyId,
      evidenceFile,evidenceSha256:digest(pdf),decision:'approved',signedAt,expiresAt,signature:''}
    a.signature=sign(null,signedMessage(a),privateKey).toString('base64')
    approvals.push(a);signers.push({gate,keyId,publicKeyPem:publicKey.export({type:'spki',format:'pem'})});keys.push(privateKey)
  }
  const registry={schemaVersion:1,project:'OSA CINEMA',signers}
  const attestations={schemaVersion:1,project:'OSA CINEMA',approvals}
  return {dir,evidenceDir,pf,registry,attestations,keys,registrySha256:digest(JSON.stringify(registry))}
}
const verify=x=>verifyExternalAttestations({preflight:x.pf,registry:x.registry,registrySha256:x.registrySha256,attestations:x.attestations,evidenceDir:x.evidenceDir})

test('V30 complete crypto attestations never publish a film',async t=>{
 const x=await fixture()
 try{
  await t.test('eight independent Ed25519 keys and real PDF bytes verify',async()=>{
    const r=await verify(x)
    assert.equal(r.verifiedSignatures,8)
    assert.equal(r.status,'ALL_EIGHT_SIGNATURES_CRYPTOGRAPHICALLY_VERIFIED_PRIVATE_ONLY')
    assert.equal(r.publicFilmPublicationAuthorized,false)
    assert.equal(r.paidCheckoutEnabled,false)
    assert.equal(r.legalContentReviewedBySoftware,false)
    assert.equal(r.decision,'NO_GO_UNTIL_INDEPENDENT_FINAL_HUMAN_AND_PRODUCTION_RELEASE')
  })
  await t.test('missing editor signoff is explicit hold',async()=>{
    const a=structuredClone(x.attestations);a.approvals.pop()
    const r=await verifyExternalAttestations({...x,preflight:x.pf,attestations:a})
    assert.equal(r.verifiedSignatures,7)
    assert.equal(r.missingRoles.length,1)
    assert.equal(r.status,'EXTERNAL_ATTESTATIONS_HOLD')
  })
  await t.test('forged approval or swapped release fingerprint fails signature verification',async()=>{
    const a=structuredClone(x.attestations);a.approvals[0].evidenceSha256=hash('evil')
    const r=await verifyExternalAttestations({...x,preflight:x.pf,attestations:a})
    assert.equal(r.verifiedSignatures,7)
    assert.equal(r.invalidRoles[0].reason,'invalid_ed25519_signature')
    const b=structuredClone(x.attestations);b.approvals[0].releaseFingerprint=hash('wrong-release')
    const mismatch=await verifyExternalAttestations({...x,preflight:x.pf,attestations:b})
    assert.equal(mismatch.invalidRoles[0].reason,'approval_refers_to_other_release')
  })
  await t.test('modified PDF content destroys verified evidence',async()=>{
    const path=join(x.evidenceDir,x.attestations.approvals[0].evidenceFile)
    const original=await readFile(path)
    await writeFile(path,'%PDF-1.7\nALTERED\n%%EOF\n')
    const r=await verify(x)
    assert.equal(r.invalidRoles[0].reason,'document_sha256_or_pdf_header_mismatch')
    await writeFile(path,original)
  })
  await t.test('symlink evidence is never read',async()=>{
    const name=x.attestations.approvals[1].evidenceFile,path=join(x.evidenceDir,name)
    const original=await readFile(path);await rm(path)
    await symlink(join(x.evidenceDir,x.attestations.approvals[0].evidenceFile),path)
    const r=await verify(x)
    assert.equal(r.invalidRoles[0].reason,'missing_or_unsafe_evidence_pdf')
    await rm(path);await writeFile(path,original)
  })
  await t.test('duplicate role or evidence document rejected',async()=>{
    const d=structuredClone(x.attestations);d.approvals[1].gate=d.approvals[0].gate
    await assert.rejects(verifyExternalAttestations({...x,preflight:x.pf,attestations:d}),/Duplicate external role/)
    const e=structuredClone(x.attestations);e.approvals[1].evidenceFile=e.approvals[0].evidenceFile
    await assert.rejects(verifyExternalAttestations({...x,preflight:x.pf,attestations:e}),/independent evidence/)
  })
  await t.test('duplicated cryptographic signer cannot impersonate second role',()=>{
    const bad=structuredClone(x.registry)
    bad.signers[1].publicKeyPem=bad.signers[0].publicKeyPem
    assert.throws(()=>validateTrustedRegistry(bad),/one cryptographic signer/)
  })
  await t.test('identity injection cannot mark record published',()=>{
    const p=preflight();p.publicationAuthorized=true
    assert.throws(()=>releaseFingerprint(p),/falsely approved/)
    const bad=preflight();bad.candidateAssets[1].finalSha256=bad.candidateAssets[0].finalSha256
    assert.throws(()=>releaseFingerprint(bad),/Duplicated MP4/)
  })
  await t.test('unverified rights, unsigned plan or missing pinned SHA blocked',()=>{
    const p=preflight();p.technical.evidenceDocumentsVerified=0
    assert.throws(()=>releaseFingerprint(p),/Four real technical/)
    const q=preflight();q.candidatePinnedToPreviousHash=false
    assert.throws(()=>releaseFingerprint(q),/Unpinned/)
  })
  await t.test('future-dated and expired approval are rejected',async()=>{
    const a=structuredClone(x.attestations)
    a.approvals[0].expiresAt=new Date(Date.now()-3600000).toISOString()
    const r=await verifyExternalAttestations({...x,preflight:x.pf,attestations:a})
    assert.equal(r.invalidRoles[0].reason,'expired_or_invalid_approval_window')
  })
  await t.test('offline signing helper produces a directly verifiable detached approval',()=>{
    const original=x.attestations.approvals[0]
    const statement={...original};delete statement.signature
    const signer=makeSignedApproval(statement,x.keys[0].export({type:'pkcs8',format:'pem'}))
    assert.equal(signer.signature,original.signature)
    assert.throws(()=>makeSignedApproval(original,x.keys[0].export({type:'pkcs8',format:'pem'})),/unsigned statement/)
  })
  await t.test('real CLI checks out-of-band trusted registry SHA, rejects altered registries, never GO',async()=>{
    const pre=join(x.dir,'preflight.json'),registryPath=join(x.dir,'trusted-registry.json'),
      approvalsPath=join(x.dir,'approvals.json'),resultPath=join(x.dir,'result.json')
    await writeFile(pre,JSON.stringify(x.pf))
    await writeFile(registryPath,JSON.stringify(x.registry))
    await writeFile(approvalsPath,JSON.stringify(x.attestations))
    const script=new URL('./osa-cinema-v30-external-attestations.mjs',import.meta.url).pathname
    const args=['--preflight',pre,'--registry',registryPath,'--registry-sha256',x.registrySha256,
      '--attestations',approvalsPath,'--evidence-dir',x.evidenceDir,'--out',resultPath]
    const run=spawnSync(process.execPath,[script,...args],{encoding:'utf8',timeout:10000})
    assert.equal(run.status,0,run.stderr)
    const saved=JSON.parse(await readFile(resultPath,'utf8'))
    assert.equal(saved.verifiedSignatures,8)
    assert.equal(saved.publicFilmPublicationAuthorized,false)
    assert.equal(saved.decision,'NO_GO_UNTIL_INDEPENDENT_FINAL_HUMAN_AND_PRODUCTION_RELEASE')
    const bad=spawnSync(process.execPath,[script,...args.map(v=>v===x.registrySha256?hash('swapped'):v)],{encoding:'utf8',timeout:10000})
    assert.equal(bad.status,1)
    assert.match(bad.stderr,/out-of-band SHA256/)
  })
  await t.test('hidden publication flag is rejected, not ignored',()=>{
    const a=structuredClone(x.attestations.approvals[0]);a.publicationAuthorized=true
    assert.throws(()=>signedMessage(a),/Unexpected or missing/)
  })
 }finally{await rm(x.dir,{recursive:true,force:true})}
})
