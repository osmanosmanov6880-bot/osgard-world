#!/usr/bin/env node
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { gitBlobHash,inspectProductionArtifact } from './nebula-production-artifact-guard.mjs';
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'nebula-artifact-gate-'));
const files=['index.html','index.js','index.wasm','index.pck'];
try{
  const expected={};
  for(const name of files){
    const file=path.join(temp,name);
    fs.writeFileSync(file,Buffer.from('synthetic-release-gate-'+name));
    expected[name]=await gitBlobHash(file);
  }
  const stable={schema:'NEBULA_PRODUCTION_ASSET_ALLOWLIST_V1',
    approved_variant:'R38',release_status:'R38_PINNED_PRODUCTION_BASELINE',
    artifacts:expected,approval:null};
  const first=await inspectProductionArtifact(stable,temp);
  assert.equal(first.variant,'R38');
  fs.appendFileSync(path.join(temp,'index.wasm'),'unauthorized');
  await assert.rejects(inspectProductionArtifact(stable,temp),/unapproved index.wasm bytes/);
  fs.writeFileSync(path.join(temp,'index.wasm'),Buffer.from('synthetic-release-gate-index.wasm'));
  const unsupported={...stable,approved_variant:'R40',
    release_status:'R40_HARDWARE_QA_APPROVED',approval:{human_visual_approved:true}};
  await assert.rejects(inspectProductionArtifact(unsupported,temp),/requires explicit human-reviewed evidence/);
  // Synthetic metadata only, never an assertion about actual phone evidence.
  const pinned=JSON.parse(fs.readFileSync('.github/nebula-r40-qa-one-shot-source.json','utf8'));
  const ciDigests=Object.fromEntries(files.map(name=>[
    name,createHash('sha256').update(fs.readFileSync(path.join(temp,name))).digest('hex')]));
  const syntheticApproval={...stable,approved_variant:'R40',
    release_status:'R40_HARDWARE_QA_APPROVED',
    approval:{
      human_visual_approved:true,real_device_reviewed:true,
      reviewer:'CI_SYNTHETIC_ONLY',candidate_pr:pinned.candidate_pr,
      candidate_head_sha:pinned.candidate_head_sha,
      source_run_id:pinned.source_run_id,private_evidence_sha256:'f'.repeat(64),
      original_json_count:108,screenshot_count:12,
      actual_android_count:2,actual_iphone_count:1,
      reviewed_at_utc:'2026-10-25T10:00:00Z',
      ci_artifacts_sha256:ciDigests
    }};
  const matching=await inspectProductionArtifact(syntheticApproval,temp);
  assert.equal(matching.variant,'R40','Synthetic unit metadata tests code only, not actual release');
  const wrongHead={...syntheticApproval,approval:{
    ...syntheticApproval.approval,candidate_head_sha:'0'.repeat(40)}};
  await assert.rejects(inspectProductionArtifact(wrongHead,temp),/must match pinned QA candidate/);
  const wrongRun={...syntheticApproval,approval:{
    ...syntheticApproval.approval,source_run_id:'99999999999'}};
  await assert.rejects(inspectProductionArtifact(wrongRun,temp),/must match pinned QA candidate/);
  const missingCI={...syntheticApproval,approval:{
    ...syntheticApproval.approval,ci_artifacts_sha256:{...ciDigests}}};
  delete missingCI.approval.ci_artifacts_sha256['index.pck'];
  await assert.rejects(inspectProductionArtifact(missingCI,temp),/requires all four original CI/);
  const wrongDigest={...syntheticApproval,approval:{
    ...syntheticApproval.approval,ci_artifacts_sha256:{
      ...ciDigests,'index.wasm':'0'.repeat(64)}}};
  await assert.rejects(inspectProductionArtifact(wrongDigest,temp),/R40 CI SHA-256 mismatch for index.wasm/);

  const absent={...stable,artifacts:{...expected}};
  delete absent.artifacts['index.pck'];
  await assert.rejects(inspectProductionArtifact(absent,temp),/exactly four hashed/);
  const spoofed={...stable,approval:{human_visual_approved:true}};
  await assert.rejects(inspectProductionArtifact(spoofed,temp),/cannot claim R40 approval/);
  console.log('NEBULA_PRODUCTION_ASSET_GUARD_NEGATIVE_QA_SUCCESS real_devices=0 r40_ci_source_pin=verified synthetic_only=true');
}finally{fs.rmSync(temp,{recursive:true,force:true});}
