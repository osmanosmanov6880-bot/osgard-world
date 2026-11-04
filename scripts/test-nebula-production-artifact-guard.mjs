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
  // R41 owner-directed release: synthetic binary pins, no fake hardware proof.
  const r41={...stable,approved_variant:'R41',
    release_status:'R41_OWNER_DIRECTED_OVERRIDE',
    approval:{
      owner_directed_release:true,release_risk_accepted:true,
      physical_device_qa:'NOT_PERFORMED',hardware_qa_certified:false,
      authorization_source:'repository owner instruction',
      authorized_date:'2026-11-04',verification_workflow_run_id:41842409047,
      native_source_commit_sha:'09413461988ae2aa68f1260fdad5d2de42d90f84',
      web_export_commit_sha:'3e2bc2f57209db101779b28afc24997522972174'
    }};
  const r41Match=await inspectProductionArtifact(r41,temp);
  assert.equal(r41Match.variant,'R41');
  assert.equal(r41Match.status,'OWNER_DIRECTED_OVERRIDE_BYTES_MATCH');
  await assert.rejects(inspectProductionArtifact({
    ...r41,approval:{...r41.approval,physical_device_qa:'PASSED'}
  },temp),/disclose missing physical-device QA/);
  await assert.rejects(inspectProductionArtifact({
    ...r41,approval:{...r41.approval,hardware_qa_certified:true}
  },temp),/hardware QA explicitly false/);
  await assert.rejects(inspectProductionArtifact({
    ...r41,approval:{...r41.approval,verification_workflow_run_id:0}
  },temp),/Modern owner override requires exact source/);
  await assert.rejects(inspectProductionArtifact({
    ...r41,approval:{...r41.approval,web_export_commit_sha:r41.approval.native_source_commit_sha}
  },temp),/Modern owner override requires exact source/);
  for(const variant of ['R42','R43','R44','R45','R46','R47']){
    const owner={...r41,approved_variant:variant,
      release_status:variant+'_OWNER_DIRECTED_OVERRIDE',
      approval:{...r41.approval,
        verification_workflow_run_id:41845777254}};
    const proof=await inspectProductionArtifact(owner,temp);
    assert.equal(proof.variant,variant,'Synthetic signed-off metadata only');
    await assert.rejects(inspectProductionArtifact({...owner,
      approval:{...owner.approval,hardware_qa_certified:true}},temp),
      /hardware QA explicitly false/);
    await assert.rejects(inspectProductionArtifact({...owner,
      approval:{...owner.approval,physical_device_qa:'PASSED'}},temp),
      /disclose missing physical-device QA/);
  }
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
