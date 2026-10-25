#!/usr/bin/env node
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {validate,loadPin,inspectFiles} from './nebula-r40-ci-pin.mjs';

const real=loadPin();
const qa=JSON.parse(fs.readFileSync('.github/nebula-r40-qa-one-shot-source.json','utf8'));
const copy=()=>structuredClone(real);
test('permanent QA pin matches exact original CI source and is never release authorization',()=>{
  assert.equal(real.candidate_pr,375);
  assert.equal(real.candidate_head_sha,qa.candidate_head_sha);
  assert.equal(String(real.ci_run_id),String(qa.source_run_id));
  assert.equal(real.production_approved,false);
  assert.equal(Object.keys(real.files).length,4);
  assert.match(real.ci_archive_sha256,/^[0-9a-f]{64}$/);
});
test('foreign source, altered run, extra asset or fake approval is rejected',()=>{
  const wrong=copy();wrong.candidate_head_sha='0'.repeat(40);
  assert.throws(()=>validate(wrong,qa),/candidate commit/);
  const run=copy();run.ci_run_id='0';
  assert.throws(()=>validate(run,qa),/CI run/);
  const extra=copy();extra.files['fake.js']={sha256:'a'.repeat(64),bytes:1};
  assert.throws(()=>validate(extra,qa),/exactly four/);
  const approved=copy();approved.production_approved=true;
  assert.throws(()=>validate(approved,qa),/cannot grant production/);
});
test('unit fixture checks all four exact byte hashes and blocks altered data',()=>{
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'nebula-ci-pin-'));
  try{
    const pin=copy();
    for(const name of Object.keys(pin.files)){
      const bytes=Buffer.from('SIMULATED_UNIT_TEST_ONLY_'+name);
      fs.writeFileSync(path.join(root,name),bytes);
      pin.files[name]={sha256:createHash('sha256').update(bytes).digest('hex'),bytes:bytes.length};
    }
    assert.equal(inspectFiles(root,pin).verified.length,4);
    fs.appendFileSync(path.join(root,'index.wasm'),'tampered');
    assert.throws(()=>inspectFiles(root,pin),/byte count mismatch/);
    fs.writeFileSync(path.join(root,'index.wasm'),
      Buffer.from('SIMULATED_UNIT_TEST_ONLY_index.wasm'));
    fs.rmSync(path.join(root,'index.pck'));
    fs.symlinkSync(path.join(root,'index.html'),path.join(root,'index.pck'));
    assert.throws(()=>inspectFiles(root,pin),/unsafe or missing file/);
  }finally{fs.rmSync(root,{recursive:true,force:true});}
});
