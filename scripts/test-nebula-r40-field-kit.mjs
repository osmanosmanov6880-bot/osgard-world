#!/usr/bin/env node
// Tests for the PRIVATE evidence starter kit and conservative progress counts.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const KIT=path.join(ROOT,'scripts/nebula-r40-field-kit.mjs');
const PROGRESS=path.join(ROOT,'scripts/nebula-r40-device-progress.mjs');
const TEMPLATE=path.join(ROOT,'docs/nebula/R40-DEVICE-FIELD-MANIFEST.example.json');
const exec=(file,...args)=>spawnSync(process.execPath,[file,...args],{cwd:ROOT,encoding:'utf8'});

test('creates empty private phone kit with 108 report slots and 12 image slots',()=>{
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'nebula-r40-kit-test-'));
  const dir=path.join(root,'field');
  try{
    const first=exec(KIT,'init',dir);
    assert.equal(first.status,0,first.stderr);
    const report=JSON.parse(first.stdout);
    assert.equal(report.status,'EMPTY_KIT_CREATED_NOT_APPROVED');
    assert.equal(report.required_json,108);
    assert.equal(report.required_screenshots,12);
    assert.equal(report.created_json,0);
    assert.equal(report.production_approval,false);
    assert.deepEqual(fs.readdirSync(path.join(dir,'reports')),[]);
    assert.deepEqual(fs.readdirSync(path.join(dir,'images')),[]);
    assert.equal(fs.readFileSync(path.join(dir,'manifest.json'),'utf8'),
      fs.readFileSync(TEMPLATE,'utf8'));
    const checklist=fs.readFileSync(path.join(dir,'CHECKLIST.md'),'utf8');
    assert.equal((checklist.match(/\[ \]/g)||[]).length,42);
    const progress=exec(PROGRESS,path.join(dir,'manifest.json'));
    assert.equal(progress.status,0,progress.stderr);
    const p=JSON.parse(progress.stdout);
    assert.equal(p.expected_json,108);
    assert.equal(p.found_json,0);
    assert.equal(p.remaining_json,108);
    assert.equal(p.expected_screenshots,12);
    assert.equal(p.remaining_screenshots,12);
    assert.equal(p.production_approval,false);
    const original=fs.readFileSync(path.join(dir,'manifest.json'),'utf8');
    const again=exec(KIT,'init',dir);
    assert.notEqual(again.status,0,'A second init must fail closed');
    assert.match(again.stderr,/not empty/i);
    assert.equal(fs.readFileSync(path.join(dir,'manifest.json'),'utf8'),original);
  }finally{fs.rmSync(root,{recursive:true,force:true});}
});

test('incomplete manifest cannot shrink progress denominator below 108/12',()=>{
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'nebula-r40-progress-test-'));
  try{
    const manifest=JSON.parse(fs.readFileSync(TEMPLATE,'utf8'));
    manifest.devices[0].runs=[];
    manifest.devices[1].visual.landscape={approved:false,notes:''};
    manifest.devices.splice(2,1);
    const filename=path.join(root,'manifest.json');
    fs.writeFileSync(filename,JSON.stringify(manifest));
    const result=exec(PROGRESS,filename);
    assert.equal(result.status,0,result.stderr);
    const p=JSON.parse(result.stdout);
    assert.equal(p.expected_json,108);
    assert.equal(p.remaining_json,108);
    assert.equal(p.expected_screenshots,12);
    assert.equal(p.remaining_screenshots,12);
    assert.equal(p.minimum_devices,3);
    assert.equal(p.devices_declared,2);
    assert.equal(p.production_approval,false);
  }finally{fs.rmSync(root,{recursive:true,force:true});}
});

test('duplicate contents in renamed JSON cannot be double-counted',()=>{
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'nebula-r40-duplicate-test-'));
  try{
    const manifest=JSON.parse(fs.readFileSync(TEMPLATE,'utf8'));
    const pair=manifest.devices[0].runs[0].baseline;
    fs.mkdirSync(path.join(root,'reports'));
    const payload=JSON.stringify({schema:'fixture-only',source:'NOT_HARDWARE'});
    for(const rel of pair.slice(0,2))fs.writeFileSync(path.join(root,rel),payload);
    const filename=path.join(root,'manifest.json');
    fs.writeFileSync(filename,JSON.stringify(manifest));
    const result=exec(PROGRESS,filename);
    assert.equal(result.status,0,result.stderr);
    const p=JSON.parse(result.stdout);
    assert.equal(p.found_json,1);
    assert.equal(p.duplicate_files,1);
    assert.equal(p.remaining_json,107);
    assert.equal(p.production_approval,false);
  }finally{fs.rmSync(root,{recursive:true,force:true});}
});

test('refuses initialization inside the tracked repository',()=>{
  const dir=path.join(ROOT,'unsafe-private-qa');
  const result=exec(KIT,'init',dir);
  assert.notEqual(result.status,0);
  assert.match(result.stderr,/outside the repository/);
  assert.equal(fs.existsSync(dir),false);
});
