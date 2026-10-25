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
    const payload=JSON.stringify({
      schema:'NEBULA_R12_HARDWARE_BENCHMARK',quality:0,quality_changed:false,
      quality_gate:'MEETS_TARGET',sample_seconds:20,valid_frames:800,
      excluded_long_frames:0,adapter_reported:'SYNTHETIC_FIXTURE_ADRENO',
      runtime:'Web',resolution_width:390,resolution_height:844,
      avg_fps:52,one_percent_low_fps:35,p95_frame_ms:21,p99_frame_ms:28,
      date_unix:1790000001
    });
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

test('rejects symlinked external folder that resolves inside Git checkout',()=>{
  const tmp=fs.mkdtempSync(path.join(os.tmpdir(),'nebula-r40-symlink-test-'));
  try{
    const alias=path.join(tmp,'linked_repo');
    fs.symlinkSync(ROOT,alias,'dir');
    const forbidden=path.join(alias,'private-evidence');
    const result=exec(KIT,'init',forbidden);
    assert.notEqual(result.status,0);
    assert.match(result.stderr,/outside the repository/i);
    assert.equal(fs.existsSync(path.join(ROOT,'private-evidence')),false);
  }finally{fs.rmSync(tmp,{recursive:true,force:true});}
});

test('inventory rejects arbitrary JSON, wrong R40 build, software GPU and wrong orientation',()=>{
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'nebula-r40-failclosed-test-'));
  try{
    const m=JSON.parse(fs.readFileSync(TEMPLATE,'utf8'));
    fs.mkdirSync(path.join(root,'reports'));
    const one=m.devices[0].runs[0];
    const basic={
      schema:'NEBULA_R12_HARDWARE_BENCHMARK',quality:0,quality_changed:false,
      quality_gate:'MEETS_TARGET',sample_seconds:20,valid_frames:800,
      excluded_long_frames:0,adapter_reported:'ADRENO 740',runtime:'Web',
      resolution_width:390,resolution_height:844,avg_fps:52,
      one_percent_low_fps:34,p95_frame_ms:21,p99_frame_ms:30,date_unix:1790000091
    };
    const samples=[
      [one.baseline[0],{schema:'not-actual-benchmark'}],
      [one.candidate[0],{...basic,date_unix:1790000092}],
      [one.baseline[1],{...basic,adapter_reported:'SwiftShader',date_unix:1790000093}],
      [one.baseline[2],{...basic,resolution_width:844,resolution_height:390,date_unix:1790000094}],
      [one.candidate[1],{...basic,build_variant:'NEBULA_R40_BRIDGE_BATCH_3X32',date_unix:1790000095}]
    ];
    for(const [rel,json] of samples)fs.writeFileSync(path.join(root,rel),JSON.stringify(json));
    fs.writeFileSync(path.join(root,'manifest.json'),JSON.stringify(m));
    const output=exec(PROGRESS,path.join(root,'manifest.json'));
    assert.equal(output.status,0,output.stderr);
    const report=JSON.parse(output.stdout);
    assert.equal(report.found_json,1,'Only authentic-shaped candidate is eligible for inventory');
    assert.equal(report.remaining_json,107);
    assert.equal(report.production_approval,false);
    assert.match(report.counted_json_policy,/NATIVE_SCHEMA/);
  }finally{fs.rmSync(root,{recursive:true,force:true});}
});

test('independent report bytes with repeated per-phone build timestamp cannot fill two slots',()=>{
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'nebula-r40-reused-time-test-'));
  try{
    const m=JSON.parse(fs.readFileSync(TEMPLATE,'utf8'));
    fs.mkdirSync(path.join(root,'reports'));
    const reports=m.devices[0].runs[0].baseline;
    const basic={
      schema:'NEBULA_R12_HARDWARE_BENCHMARK',quality:0,quality_changed:false,
      quality_gate:'MEETS_TARGET',sample_seconds:20,valid_frames:800,
      excluded_long_frames:0,adapter_reported:'ADRENO 740',runtime:'Web',
      resolution_width:390,resolution_height:844,one_percent_low_fps:34,
      p95_frame_ms:21,p99_frame_ms:30,date_unix:1790000099
    };
    fs.writeFileSync(path.join(root,reports[0]),JSON.stringify({...basic,avg_fps:50}));
    fs.writeFileSync(path.join(root,reports[1]),JSON.stringify({...basic,avg_fps:51}));
    fs.writeFileSync(path.join(root,'manifest.json'),JSON.stringify(m));
    const output=exec(PROGRESS,path.join(root,'manifest.json'));
    assert.equal(output.status,0,output.stderr);
    const report=JSON.parse(output.stdout);
    assert.equal(report.found_json,1);
    assert.equal(report.duplicate_files,1);
    assert.equal(report.remaining_json,107);
    assert.equal(report.production_approval,false);
  }finally{fs.rmSync(root,{recursive:true,force:true});}
});
