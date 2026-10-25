import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile, writeFile, mkdir, mkdtemp, symlink, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { spawnSync } from 'node:child_process'
import { baselineIntegrity, releaseMatrix, auditPrivateEvidence } from './osa-cinema-v20-release-audit.mjs'
const json=async p=>JSON.parse(await readFile(p,'utf8'))
const originals=await json('docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json')
const scenes=await json('docs/OSA_CINEMA_V18_PRIVATE_SCENE_CUT_QC.json')
const four=await json('docs/OSA_CINEMA_V18_PRIVATE_FOUR_TRACK_QA.json')

test('real V16/V18 picture and audio identities form an exact technical baseline',()=>{
  const v=baselineIntegrity(originals,scenes,four)
  assert.equal(v.verifiedPrivateEngineeringBaseline,true)
  assert.equal(v.fullFilmCutsPerLocale,64)
  assert.equal(v.previewCutsPerLocale,10)
})
test('fake source hash, cut drift and false rights flag all fail validation',()=>{
  assert.throws(()=>baselineIntegrity(originals,{...scenes,assets:scenes.assets.map((x,i)=>i===0?{...x,originalSha256:'f'.repeat(64)}:x)},four),/mismatch/)
  assert.throws(()=>baselineIntegrity(originals,{...scenes,assets:scenes.assets.map((x,i)=>i===1?{...x,sceneCutTimecodes:[...x.sceneCutTimecodes.slice(0,-1),999]}:x)},four),/diverge/)
  assert.throws(()=>baselineIntegrity(originals,scenes,{...four,rightsCleared:true}),/rights/)
})
test('upload of arbitrary optimistic approval files does not authorize public release',()=>{
  const v=releaseMatrix(baselineIntegrity(originals,scenes,four),{everything:'approved',rights:true,allChecksPassed:true})
  assert.equal(v.publicationAuthorized,false)
  assert.equal(v.checkoutEnabled,false)
  assert.equal(v.remainingMandatoryBlockers.length,7)
  assert.equal(v.pendingHumanLegalReview,true)
})
test('private evidence candidates require strict source IDs and never grant legal authorization',async()=>{
  const dir=await mkdtemp(join(tmpdir(),'osa-v20-proof-'))
  try{
    await mkdir(join(dir,originals.assets[0].id))
    const asset=originals.assets[0]
    const f=join(dir,asset.id,'rights.json')
    await writeFile(f,JSON.stringify({sourceId:asset.id,sourceSha256:asset.sha256,reviewerId:'real-reviewer',reviewedAt:'2026-10-25T12:00:00Z',evidenceSha256:'a'.repeat(64),reviewRequested:true,reviewerNotes:'Submitted only for independent legal review'}))
    const evidence=await auditPrivateEvidence(dir,originals.assets)
    assert.equal(evidence.records[0].evidenceCandidates.rights,'document_supplied_not_approved')
    assert.equal(evidence.rightsCleared,false)
    assert.equal(evidence.publicationAuthorized,false)
    await rm(f)
    await symlink(join(dir,'nonexistent'),f)
    const second=await auditPrivateEvidence(dir,originals.assets)
    assert.notEqual(second.records[0].evidenceCandidates.rights,'document_supplied_not_approved')
  } finally {await rm(dir,{recursive:true,force:true})}
})
test('strict publication command must fail despite measured engineering success',()=>{
  const proc=spawnSync(process.execPath,['scripts/osa-cinema-v20-release-audit.mjs','--strict-publication'],{encoding:'utf8'})
  assert.equal(proc.status,1)
  assert.match(proc.stdout,/"publicationAuthorized":false/)
})
