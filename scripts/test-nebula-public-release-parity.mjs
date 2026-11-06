#!/usr/bin/env node
// Pure local negative suite: no network, no production writes.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { createHash } from 'node:crypto';
import { verifyPublicRelease } from './nebula-public-release-parity.mjs';

const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'nebula-public-parity-'));
const required = ['index.html','index.js','index.wasm','index.pck'];
function hash(bytes) {
  return createHash('sha1').update('blob '+bytes.length+'\0').update(bytes).digest('hex');
}
function makePolicy(variant = 'R49') {
  const artifacts = {};
  for (const name of required) {
    const bytes = Buffer.from('NEBULA_TEST_'+name+'_v1');
    fs.writeFileSync(path.join(directory,name),bytes);
    artifacts[name] = hash(bytes);
  }
  return {
    schema:'NEBULA_PRODUCTION_ASSET_ALLOWLIST_V1',
    approved_variant:variant,
    release_status:variant+'_OWNER_DIRECTED_OVERRIDE',
    artifacts,
    approval:{
      owner_directed_release:true,
      release_risk_accepted:true,
      authorization_source:'repository owner instruction',
      authorized_date:'2026-11-05',
      physical_device_qa:'NOT_PERFORMED',
      hardware_qa_certified:false,
      verification_workflow_run_id:42044976256,
      native_source_commit_sha:'a'.repeat(40),
      web_export_commit_sha:'b'.repeat(40)
    }
  };
}

try {
  const good=makePolicy('R49');
  const evidence=await verifyPublicRelease(good,directory);
  assert.equal(evidence.variant,'R49');
  assert.equal(Object.keys(evidence.files).length,4);

  await assert.rejects(verifyPublicRelease(good, '/no-such-game-artifact-dir'),
    /no downloaded HTTPS artifact directory/);
  fs.writeFileSync(path.join(directory,'index.pck'), 'TAMPERED');
  await assert.rejects(verifyPublicRelease(good,directory),/unapproved index.pck bytes/);

  makePolicy('R49');
  const wrongHashes={...good, artifacts:{...good.artifacts,'index.wasm':'0'.repeat(40)}};
  await assert.rejects(verifyPublicRelease(wrongHashes,directory),
    /unapproved index.wasm bytes/);

  makePolicy('R49');

  // R54 accepts only exact pinned byte payloads and owner disclosure.
  const localR54=makePolicy('R54');
  const matchedR54=await verifyPublicRelease(localR54,directory);
  assert.equal(matchedR54.variant,'R54');
  makePolicy('R49');
  await assert.rejects(verifyPublicRelease({...good, approved_variant:'R53'},directory),
    /unexpected approved build/);

  await assert.rejects(verifyPublicRelease({
    ...good, approval:{...good.approval,physical_device_qa:'PASSED'}
  },directory), /Owner override must explicitly record authorization/);
  await assert.rejects(verifyPublicRelease({
    ...good, approval:{...good.approval, hardware_qa_certified:true}
  },directory), /Modern owner override requires exact source/);
  await assert.rejects(verifyPublicRelease({
    ...good, approval:{...good.approval,
      web_export_commit_sha:good.approval.native_source_commit_sha}
  },directory), /Modern owner override requires exact source/);
  await assert.rejects(verifyPublicRelease({
    ...good, artifacts:{...good.artifacts,additional:'f'.repeat(40)}
  },directory), /exactly four hashed game assets/);

  fs.unlinkSync(path.join(directory,'index.js'));
  await assert.rejects(verifyPublicRelease(good,directory), /ENOENT|missing or empty/);
  console.log('NEBULA_PUBLIC_PARITY_NEGATIVE_TESTS_SUCCESS');
} finally {
  fs.rmSync(directory,{recursive:true,force:true});
}
