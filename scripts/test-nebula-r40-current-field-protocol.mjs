#!/usr/bin/env node
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const protocol=fs.readFileSync('docs/nebula/R40-ON-DEVICE-AB-PROTOCOL.md','utf8');
const source=JSON.parse(fs.readFileSync('.github/nebula-r40-qa-one-shot-source.json','utf8'));
const pin=JSON.parse(fs.readFileSync('.github/nebula-r40-qa-ci-artifact-pin.json','utf8'));
const prod=JSON.parse(fs.readFileSync('.github/nebula-production-allowlist.json','utf8'));

test('testers are sent to the one pinned, actual isolated QA and the approved R38 baseline',()=>{
  assert.equal(source.candidate_pr,375);
  assert.equal(pin.candidate_pr,source.candidate_pr);
  assert.equal(pin.candidate_head_sha,source.candidate_head_sha);
  assert.equal(String(pin.ci_run_id),String(source.source_run_id));
  assert.equal(source.qa_path,'/games/remix/nebula-r40-qa/');
  assert.equal(source.staging_only,true);
  assert.equal(source.approved_for_production,false);
  assert.equal(pin.production_approved,false);
  assert.equal(prod.approved_variant,'R38');
  assert.equal(prod.approval,null);
  assert.ok(protocol.includes('https://osgard.world/games/remix/arena-v2/nebula-3d/'));
  assert.ok(protocol.includes('https://osgard.world'+source.qa_path));
  assert.ok(protocol.includes('PR #'+source.candidate_pr));
  assert.ok(protocol.includes(source.candidate_head_sha));
  assert.ok(protocol.includes(String(source.source_run_id)));
  assert.doesNotMatch(protocol,/#342\b/,'do not send phone testers to a closed pre-pin PR');
});
test('protocol fingerprints the actual CI archive and required original game binaries',()=>{
  assert.ok(protocol.includes(pin.ci_archive_sha256));
  for(const asset of ['index.wasm','index.pck']){
    assert.ok(protocol.includes(pin.files[asset].sha256),asset+' digest omitted');
  }
  assert.match(protocol,/NEBULA_R40_BRIDGE_BATCH_3X32/);
  assert.match(protocol,/nebula-r40-qa-ci-artifact-pin\.json/);
});
test('physical collection cannot be replaced with CI emulation or arbitrary JSON',()=>{
  for(const word of ['NEBULA_R12_HARDWARE_BENCHMARK','FPS','20 С','JSON','108','12']){
    assert.ok(protocol.includes(word),'Expected physical QA requirement: '+word);
  }
  assert.match(protocol,/SwiftShader/);
  assert.match(protocol,/iPhone Safari/);
  assert.match(protocol,/20-second sample/);
  assert.match(protocol,/без автоматической отправки/i);
  assert.match(protocol,/R38/);
  assert.match(protocol,/R40/);
});
