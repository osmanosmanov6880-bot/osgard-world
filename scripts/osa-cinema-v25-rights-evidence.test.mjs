import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtemp, mkdir, writeFile, symlink, rm } from 'node:fs/promises'
import { createHash } from 'node:crypto'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { validateUsage, auditRightsEvidence } from './osa-cinema-v25-rights-evidence.mjs'
const sha=v=>createHash('sha256').update(v).digest('hex')
const pdf=Buffer.from('%PDF-1.7\nSynthetic offline receipt for validating evidence bytes only.\n%%EOF')
const ids=['osa-v15-trailer-ru','osa-v15-trailer-en','osa-v15-directors-ru','osa-v15-directors-en']
const plan={assets:ids.map((id,i)=>({id,masterSha256:String(i+1).repeat(64)}))}
const usage={schemaVersion:1,project:'OSA CINEMA',releaseAuthorized:false,
  editions:plan.assets.map((a,i)=>({finalId:a.id,finalSha256:a.masterSha256,sourceIds:['origin-'+i]})),
  sources:plan.assets.map((a,i)=>({id:'origin-'+i,type:'ai-generated',sourceSha256:String(i+5).repeat(64),evidenceFile:'source_'+i+'.pdf',evidenceSha256:sha(pdf),commercialRightsApproved:false,evidenceHumanReviewed:false}))}
let root
test.before(async()=>{root=await mkdtemp(join(tmpdir(),'osa-v25-'));await mkdir(join(root,'rights'));for(const s of usage.sources)await writeFile(join(root,'rights',s.evidenceFile),pdf)})
test.after(async()=>{if(root)await rm(root,{recursive:true,force:true})})
test('actual PDF evidence bytes present means legal HOLD, not rights clearance',async()=>{
  const r=await auditRightsEvidence(root,usage,plan)
  assert.equal(r.coverage.documentBytesVerified,4)
  assert.equal(r.status,'DOCUMENT_BYTES_COMPLETE_LEGAL_HOLD')
  assert.equal(r.rightsCleared,false)
  assert.equal(r.publishAllowed,false)
})
test('an unknown source or a changed final film SHA is rejected',()=>{
  const x=structuredClone(usage);x.editions[0].sourceIds=['unknown'];assert.throws(()=>validateUsage(x,plan),/Unregistered/)
  const y=structuredClone(usage);y.editions[0].finalSha256='a'.repeat(64);assert.throws(()=>validateUsage(y,plan),/SHA/)
})
test('coverage map refuses forged legal clearances and source traversal',()=>{
  const x=structuredClone(usage);x.sources[0].commercialRightsApproved=true
  assert.throws(()=>validateUsage(x,plan),/rights approval/)
  const y=structuredClone(usage);y.sources[0].evidenceFile='../contract.pdf'
  assert.throws(()=>validateUsage(y,plan),/Invalid/)
})
test('tampered PDF content is blocked even when filename and metadata agree',async()=>{
  const x=structuredClone(usage);x.sources[0].evidenceSha256=sha('changed')
  const r=await auditRightsEvidence(root,x,plan)
  assert.equal(r.coverage.missing,1)
  assert.equal(r.sources[0].evidenceState,'rights_evidence_hash_mismatch')
})
test('symlinked PDF files are not accepted as evidence',async()=>{
  const s=usage.sources[0],p=join(root,'rights',s.evidenceFile)
  await rm(p);await symlink(join(root,'rights',usage.sources[1].evidenceFile),p)
  const r=await auditRightsEvidence(root,usage,plan)
  assert.equal(r.sources[0].evidenceState,'unsafe_evidence_document')
})
