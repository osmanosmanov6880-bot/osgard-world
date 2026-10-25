#!/usr/bin/env node
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
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
  const absent={...stable,artifacts:{...expected}};
  delete absent.artifacts['index.pck'];
  await assert.rejects(inspectProductionArtifact(absent,temp),/exactly four hashed/);
  const spoofed={...stable,approval:{human_visual_approved:true}};
  await assert.rejects(inspectProductionArtifact(spoofed,temp),/cannot claim R40 approval/);
  console.log('NEBULA_PRODUCTION_ASSET_GUARD_NEGATIVE_QA_SUCCESS real_devices=0');
}finally{fs.rmSync(temp,{recursive:true,force:true});}
