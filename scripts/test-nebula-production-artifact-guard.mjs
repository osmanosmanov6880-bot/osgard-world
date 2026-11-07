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
  for(const variant of ['R42','R43','R44','R45','R46','R47','R48','R49','R50','R51','R52','R54','R55','R56','R57']){
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
  // R49 remains a strict *negative* gate until separately approved,
  // with real WebAssembly bytes pinned in a later release PR commit.
  const r49={...r41,approved_variant:'R49',
    release_status:'R49_OWNER_DIRECTED_OVERRIDE'};
  await assert.rejects(inspectProductionArtifact({
    ...r49,release_status:'R49_PASSED_HARDWARE_QA'
  },temp),/Owner override must explicitly record authorization/);
  await assert.rejects(inspectProductionArtifact({
    ...r49,approval:{...r49.approval,web_export_commit_sha:
      r49.approval.native_source_commit_sha}
  },temp),/Modern owner override requires exact source/);
  await assert.rejects(inspectProductionArtifact({
    ...r49,approval:{...r49.approval,physical_device_qa:'PASSED'}
  },temp),/disclose missing physical-device QA/);
  await assert.rejects(inspectProductionArtifact({
    ...r49,artifacts:{...expected,'index.js':'0'.repeat(40)}
  },temp),/unapproved index.js bytes/);
  await assert.rejects(inspectProductionArtifact({
    ...r49,artifacts:{...expected,unreviewed:'0'.repeat(40)}
  },temp),/exactly four hashed game assets/);
  // R50 is not allowed to claim a physical phone test or altered exports.
  const r50={...r41,approved_variant:'R50',
    release_status:'R50_OWNER_DIRECTED_OVERRIDE'};
  await assert.rejects(inspectProductionArtifact({
    ...r50,release_status:'R50_HARDWARE_QA_APPROVED'
  },temp),/Owner override must explicitly record authorization/);
  await assert.rejects(inspectProductionArtifact({
    ...r50,approval:{...r50.approval,physical_device_qa:'PASSED'}
  },temp),/disclose missing physical-device QA/);
  await assert.rejects(inspectProductionArtifact({
    ...r50,approval:{...r50.approval,hardware_qa_certified:true}
  },temp),/hardware QA explicitly false/);
  await assert.rejects(inspectProductionArtifact({
    ...r50,approval:{...r50.approval,
      native_source_commit_sha:r50.approval.web_export_commit_sha}
  },temp),/Modern owner override requires exact source/);
  await assert.rejects(inspectProductionArtifact({
    ...r50,artifacts:{...expected,'index.pck':'0'.repeat(40)}
  },temp),/unapproved index.pck bytes/);
  // R51 is an owner-directed software release, not physical-device
  // certification. Refuse altered binaries, false attestations, bad ancestry.
  const r51={...r41,approved_variant:'R51',
    release_status:'R51_OWNER_DIRECTED_OVERRIDE'};
  const r51Good=await inspectProductionArtifact(r51,temp);
  assert.equal(r51Good.variant,'R51');
  await assert.rejects(inspectProductionArtifact({
    ...r51,release_status:'R51_HARDWARE_QA_APPROVED'
  },temp),/Owner override must explicitly record authorization/);
  await assert.rejects(inspectProductionArtifact({
    ...r51,approval:{...r51.approval,physical_device_qa:'PASSED'}
  },temp),/disclose missing physical-device QA/);
  await assert.rejects(inspectProductionArtifact({
    ...r51,approval:{...r51.approval,hardware_qa_certified:true}
  },temp),/hardware QA explicitly false/);
  await assert.rejects(inspectProductionArtifact({
    ...r51,approval:{...r51.approval,verification_workflow_run_id:0}
  },temp),/Modern owner override requires exact source/);
  await assert.rejects(inspectProductionArtifact({
    ...r51,approval:{...r51.approval,
      native_source_commit_sha:r51.approval.web_export_commit_sha}
  },temp),/Modern owner override requires exact source/);
  await assert.rejects(inspectProductionArtifact({
    ...r51,artifacts:{...expected,'index.pck':'0'.repeat(40)}
  },temp),/unapproved index.pck bytes/);
  await assert.rejects(inspectProductionArtifact({
    ...r51,artifacts:{...expected,extra:'0'.repeat(40)}
  },temp),/exactly four hashed game assets/);

  // R52: never confuse a successful Web export with physical-device QA.
  // These are synthetic negative cases; bytes and provenance remain pinned.
  const r52={...r41,approved_variant:'R52',
    release_status:'R52_OWNER_DIRECTED_OVERRIDE'};
  const r52Good=await inspectProductionArtifact(r52,temp);
  assert.equal(r52Good.variant,'R52');
  for (const malicious of [
    {...r52,release_status:'R52_HARDWARE_QA_APPROVED'},
    {...r52,approval:{...r52.approval,physical_device_qa:'PASSED'}},
    {...r52,approval:{...r52.approval,hardware_qa_certified:true}},
    {...r52,approval:{...r52.approval,verification_workflow_run_id:0}},
    {...r52,approval:{...r52.approval,web_export_commit_sha:r52.approval.native_source_commit_sha}},
    {...r52,artifacts:{...expected,'index.html':'0'.repeat(40)}},
    {...r52,artifacts:{...expected,'index.pck':'0'.repeat(40)}},
    {...r52,artifacts:{...expected,extra:'0'.repeat(40)}}
  ]) {
    await assert.rejects(inspectProductionArtifact(malicious,temp),
      /Owner override|Modern owner override|hardware QA explicitly false|unapproved index|exactly four hashed/);
  }

  const r54={...r41,approved_variant:'R54',release_status:'R54_OWNER_DIRECTED_OVERRIDE'};
  const r54Good=await inspectProductionArtifact(r54,temp);
  assert.equal(r54Good.variant,'R54');
  assert.equal(r54Good.status,'OWNER_DIRECTED_OVERRIDE_BYTES_MATCH');
  for(const malicious of [
    {...r54,release_status:'R54_HARDWARE_QA_APPROVED'},
    {...r54,approval:{...r54.approval,physical_device_qa:'PASSED'}},
    {...r54,approval:{...r54.approval,hardware_qa_certified:true}},
    {...r54,approval:{...r54.approval,verification_workflow_run_id:0}},
    {...r54,approval:{...r54.approval,web_export_commit_sha:r54.approval.native_source_commit_sha}},
    {...r54,artifacts:{...expected,'index.html':'0'.repeat(40)}},
    {...r54,artifacts:{...expected,'index.pck':'0'.repeat(40)}},
    {...r54,artifacts:{...expected,extra:'0'.repeat(40)}}
  ]) {
    await assert.rejects(inspectProductionArtifact(malicious,temp),
      /Owner override|Modern owner override|hardware QA explicitly false|unapproved index|exactly four hashed/);
  }

  const r55={...r41,approved_variant:'R55',release_status:'R55_OWNER_DIRECTED_OVERRIDE'};
  const r55Good=await inspectProductionArtifact(r55,temp);
  assert.equal(r55Good.variant,'R55');
  assert.equal(r55Good.status,'OWNER_DIRECTED_OVERRIDE_BYTES_MATCH');
  for(const malicious of [
    {...r55,release_status:'R55_HARDWARE_QA_APPROVED'},
    {...r55,approval:{...r55.approval,physical_device_qa:'PASSED'}},
    {...r55,approval:{...r55.approval,hardware_qa_certified:true}},
    {...r55,approval:{...r55.approval,verification_workflow_run_id:0}},
    {...r55,approval:{...r55.approval,web_export_commit_sha:r55.approval.native_source_commit_sha}},
    {...r55,artifacts:{...expected,'index.html':'0'.repeat(40)}},
    {...r55,artifacts:{...expected,'index.pck':'0'.repeat(40)}},
    {...r55,artifacts:{...expected,extra:'0'.repeat(40)}},
  ]) {
    await assert.rejects(inspectProductionArtifact(malicious,temp),
      /Owner override|Modern owner override|hardware QA explicitly false|unapproved index|exactly four hashed/);
  }

  // R56 exact synthetic pin: prove fake phone results, hash drift, and
  // copied commit provenance never become a production entitlement.
  const r56={...r41,approved_variant:'R56',release_status:'R56_OWNER_DIRECTED_OVERRIDE'};
  const r56Match=await inspectProductionArtifact(r56,temp);
  assert.equal(r56Match.variant,'R56');
  assert.equal(r56Match.status,'OWNER_DIRECTED_OVERRIDE_BYTES_MATCH');
  for(const malicious of [
    {...r56,release_status:'R56_HARDWARE_QA_APPROVED'},
    {...r56,approval:{...r56.approval,physical_device_qa:'PASSED'}},
    {...r56,approval:{...r56.approval,hardware_qa_certified:true}},
    {...r56,approval:{...r56.approval,verification_workflow_run_id:0}},
    {...r56,approval:{...r56.approval,web_export_commit_sha:r56.approval.native_source_commit_sha}},
    {...r56,artifacts:{...expected,'index.html':'0'.repeat(40)}},
    {...r56,artifacts:{...expected,'index.pck':'0'.repeat(40)}},
    {...r56,artifacts:{...expected,extra:'0'.repeat(40)}},
  ]) {
    await assert.rejects(inspectProductionArtifact(malicious,temp),
      /Owner override|Modern owner override|hardware QA explicitly false|unapproved index|exactly four hashed/);
  }

  const r57={...r41,approved_variant:'R57',release_status:'R57_OWNER_DIRECTED_OVERRIDE'};
  const r57Good=await inspectProductionArtifact(r57,temp);
  assert.equal(r57Good.variant,'R57');
  assert.equal(r57Good.status,'OWNER_DIRECTED_OVERRIDE_BYTES_MATCH');
  for(const malicious of [
    {...r57,release_status:'R57_HARDWARE_QA_APPROVED'},
    {...r57,approval:{...r57.approval,physical_device_qa:'PASSED'}},
    {...r57,approval:{...r57.approval,hardware_qa_certified:true}},
    {...r57,approval:{...r57.approval,verification_workflow_run_id:0}},
    {...r57,approval:{...r57.approval,web_export_commit_sha:r57.approval.native_source_commit_sha}},
    {...r57,artifacts:{...expected,'index.html':'0'.repeat(40)}},
    {...r57,artifacts:{...expected,'index.pck':'0'.repeat(40)}},
    {...r57,artifacts:{...expected,extra:'0'.repeat(40)}},
  ]) {
    await assert.rejects(inspectProductionArtifact(malicious,temp),
      /Owner override|Modern owner override|hardware QA explicitly false|unapproved index|exactly four hashed/);
  }
  const r58={...r41,approved_variant:'R58',release_status:'R58_OWNER_DIRECTED_OVERRIDE'};
  const r58Good=await inspectProductionArtifact(r58,temp);
  assert.equal(r58Good.variant,'R58');
  assert.equal(r58Good.status,'OWNER_DIRECTED_OVERRIDE_BYTES_MATCH');
  for(const malicious of [
    {...r58,release_status:'R58_HARDWARE_QA_APPROVED'},
    {...r58,approval:{...r58.approval,physical_device_qa:'PASSED'}},
    {...r58,approval:{...r58.approval,hardware_qa_certified:true}},
    {...r58,approval:{...r58.approval,verification_workflow_run_id:0}},
    {...r58,approval:{...r58.approval,web_export_commit_sha:r58.approval.native_source_commit_sha}},
    {...r58,artifacts:{...expected,'index.html':'0'.repeat(40)}},
    {...r58,artifacts:{...expected,'index.pck':'0'.repeat(40)}},
    {...r58,artifacts:{...expected,extra:'0'.repeat(40)}},
  ]) {
    await assert.rejects(inspectProductionArtifact(malicious,temp),
      /Owner override|Modern owner override|hardware QA explicitly false|unapproved index|exactly four hashed/);
  }
  const r59={...r41,approved_variant:'R59',release_status:'R59_OWNER_DIRECTED_OVERRIDE'};
  const r59Good=await inspectProductionArtifact(r59,temp);
  assert.equal(r59Good.variant,'R59');
  assert.equal(r59Good.status,'OWNER_DIRECTED_OVERRIDE_BYTES_MATCH');
  for(const malicious of [
    {...r59,release_status:'R59_HARDWARE_QA_APPROVED'},
    {...r59,approval:{...r59.approval,physical_device_qa:'PASSED'}},
    {...r59,approval:{...r59.approval,hardware_qa_certified:true}},
    {...r59,approval:{...r59.approval,verification_workflow_run_id:0}},
    {...r59,approval:{...r59.approval,web_export_commit_sha:r59.approval.native_source_commit_sha}},
    {...r59,artifacts:{...expected,'index.html':'0'.repeat(40)}},
    {...r59,artifacts:{...expected,'index.pck':'0'.repeat(40)}},
    {...r59,artifacts:{...expected,extra:'0'.repeat(40)}},
  ]) {
    await assert.rejects(inspectProductionArtifact(malicious,temp),
      /Owner override|Modern owner override|hardware QA explicitly false|unapproved index|exactly four hashed/);
  }
  const r60={...r41,approved_variant:'R60',release_status:'R60_OWNER_DIRECTED_OVERRIDE'};
  const r60Good=await inspectProductionArtifact(r60,temp);
  assert.equal(r60Good.variant,'R60');
  assert.equal(r60Good.status,'OWNER_DIRECTED_OVERRIDE_BYTES_MATCH');
  for(const malicious of [
    {...r60,release_status:'R60_HARDWARE_QA_APPROVED'},
    {...r60,approval:{...r60.approval,physical_device_qa:'PASSED'}},
    {...r60,approval:{...r60.approval,hardware_qa_certified:true}},
    {...r60,approval:{...r60.approval,verification_workflow_run_id:0}},
    {...r60,approval:{...r60.approval,web_export_commit_sha:r60.approval.native_source_commit_sha}},
    {...r60,artifacts:{...expected,'index.html':'0'.repeat(40)}},
    {...r60,artifacts:{...expected,'index.pck':'0'.repeat(40)}},
    {...r60,artifacts:{...expected,extra:'0'.repeat(40)}},
  ]) {
    await assert.rejects(inspectProductionArtifact(malicious,temp),
      /Owner override|Modern owner override|hardware QA explicitly false|unapproved index|exactly four hashed/);
  }
  const r61={...r41,approved_variant:'R61',release_status:'R61_OWNER_DIRECTED_OVERRIDE'};
  const r61Good=await inspectProductionArtifact(r61,temp);
  assert.equal(r61Good.variant,'R61');
  assert.equal(r61Good.status,'OWNER_DIRECTED_OVERRIDE_BYTES_MATCH');
  for(const malicious of [
    {...r61,release_status:'R61_HARDWARE_QA_APPROVED'},
    {...r61,approval:{...r61.approval,physical_device_qa:'PASSED'}},
    {...r61,approval:{...r61.approval,hardware_qa_certified:true}},
    {...r61,approval:{...r61.approval,verification_workflow_run_id:0}},
    {...r61,approval:{...r61.approval,web_export_commit_sha:r61.approval.native_source_commit_sha}},
    {...r61,artifacts:{...expected,'index.html':'0'.repeat(40)}},
    {...r61,artifacts:{...expected,'index.pck':'0'.repeat(40)}},
    {...r61,artifacts:{...expected,extra:'0'.repeat(40)}},
  ]) {
    await assert.rejects(inspectProductionArtifact(malicious,temp),
      /Owner override|Modern owner override|hardware QA explicitly false|unapproved index|exactly four hashed/);
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
