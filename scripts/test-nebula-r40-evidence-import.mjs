#!/usr/bin/env node
// Synthetic CI fixtures only. These never establish actual hardware proof.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const KIT=path.join(ROOT,'scripts/nebula-r40-field-kit.mjs');
const IMPORT=path.join(ROOT,'scripts/nebula-r40-evidence-import.mjs');
const PROGRESS=path.join(ROOT,'scripts/nebula-r40-device-progress.mjs');
const exec=(program,...args)=>spawnSync(process.execPath,[program,...args],
  {cwd:ROOT,encoding:'utf8',timeout:30000,maxBuffer:1048576});
function fixture(temp){
  const kit=path.join(temp,'kit');
  const init=exec(KIT,'init',kit);
  assert.equal(init.status,0,init.stderr);
  const downloads=path.join(temp,'phone-downloads');
  fs.mkdirSync(downloads);
  return {kit,manifest:path.join(kit,'manifest.json'),downloads};
}
function report(stamp,variant='R38',extra={}){
  return {
    schema:'NEBULA_R12_HARDWARE_BENCHMARK',
    quality:0,quality_changed:false,quality_gate:'MEETS_TARGET',
    valid_frames:900,excluded_long_frames:0,sample_seconds:20,
    adapter_reported:'Adreno 740',runtime:'Web',
    avg_fps:51,one_percent_low_fps:34,p95_frame_ms:21,p99_frame_ms:29,
    resolution_width:390,resolution_height:844,date_unix:stamp,
    ...(variant==='R40'?{build_variant:'NEBULA_R40_BRIDGE_BATCH_3X32'}:{}),
    ...extra
  };
}
function files(folder,variant='R38',start=1790002001,extra={}){
  const names=[];
  for(let i=0;i<3;i++){
    const filename=path.join(folder,'source-'+variant+'-'+start+'-'+i+'.json');
    fs.writeFileSync(filename,JSON.stringify(report(start+i,variant,extra)));
    names.push(filename);
  }
  return names;
}
function state(manifest){
  const x=exec(PROGRESS,manifest);
  assert.equal(x.status,0,x.stderr);
  return JSON.parse(x.stdout);
}
function withTemp(prefix,fn){
  const temp=fs.mkdtempSync(path.join(os.tmpdir(),prefix));
  try{fn(temp);}finally{fs.rmSync(temp,{recursive:true,force:true});}
}

test('byte-identical batch import of three original-shaped R38 and R40 game reports',()=>{
  withTemp('nebula-r40-import-success-',temp=>{
    const {kit,manifest,downloads}=fixture(temp);
    const baseline=files(downloads,'R38');
    const originals=baseline.map(x=>fs.readFileSync(x));
    const a=exec(IMPORT,manifest,'json','android_low','portrait','MAX','R38',...baseline);
    assert.equal(a.status,0,a.stderr);
    const result=JSON.parse(a.stdout);
    assert.equal(result.imported.length,3);
    assert.equal(result.remaining_json,105);
    assert.equal(result.production_approved,false);
    assert.equal(result.field_work_approved,false);
    const m=JSON.parse(fs.readFileSync(manifest,'utf8'));
    assert.equal(m.field_work,false);
    const slots=m.devices[0].runs[0].baseline;
    for(let i=0;i<3;i++){
      assert.deepEqual(fs.readFileSync(path.join(kit,slots[i])),originals[i]);
      assert.deepEqual(fs.readFileSync(baseline[i]),originals[i]);
    }
    const candidate=files(downloads,'R40',1790003001);
    const b=exec(IMPORT,manifest,'json','android_low','portrait','MAX','R40',...candidate);
    assert.equal(b.status,0,b.stderr);
    assert.equal(state(manifest).found_json,6);
    assert.equal(JSON.parse(fs.readFileSync(manifest,'utf8')).field_work,false);
    const retry=exec(IMPORT,manifest,'json','android_low','portrait','MAX','R38',...baseline);
    assert.notEqual(retry.status,0,'Overwrite of imported originals must be rejected');
    assert.equal(state(manifest).found_json,6);
  });
});

test('wrong build marker and software GPU never survive an attempted batch import',()=>{
  withTemp('nebula-r40-import-negative-',temp=>{
    const {kit,manifest,downloads}=fixture(temp);
    const original=files(downloads,'R38');
    const bad=exec(IMPORT,manifest,'json','android_low','portrait','MAX','R40',...original);
    assert.notEqual(bad.status,0,'A baseline must not be laundered into R40');
    assert.equal(fs.readdirSync(path.join(kit,'reports')).length,0);
    const gpu=files(downloads,'R38',1790004001,{adapter_reported:'SwiftShader'});
    const invalid=exec(IMPORT,manifest,'json','android_low','portrait','MAX','R38',...gpu);
    assert.notEqual(invalid.status,0);
    assert.equal(fs.readdirSync(path.join(kit,'reports')).length,0);
    assert.equal(state(manifest).found_json,0);
    assert.equal(JSON.parse(fs.readFileSync(manifest,'utf8')).field_work,false);
  });
});

test('duplicate measurement timestamps, incomplete files and arbitrary JSON are rejected with rollback',()=>{
  withTemp('nebula-r40-import-dedup-',temp=>{
    const {kit,manifest,downloads}=fixture(temp);
    const repeated=files(downloads,'R38',1790005001);
    const second=JSON.parse(fs.readFileSync(repeated[1],'utf8'));
    second.date_unix=1790005001;
    second.avg_fps=49;
    fs.writeFileSync(repeated[1],JSON.stringify(second));
    const wrong=exec(IMPORT,manifest,'json','android_low','portrait','MAX','R38',...repeated);
    assert.notEqual(wrong.status,0);
    assert.equal(fs.readdirSync(path.join(kit,'reports')).length,0);
    const arbitrary=files(downloads,'R38',1790006001);
    fs.writeFileSync(arbitrary[1],JSON.stringify({schema:'not-a-game-benchmark'}));
    const reject=exec(IMPORT,manifest,'json','android_low','portrait','MAX','R38',...arbitrary);
    assert.notEqual(reject.status,0);
    assert.equal(fs.readdirSync(path.join(kit,'reports')).length,0);
    const insufficient=exec(IMPORT,manifest,'json','android_low','portrait','MAX','R38',
      arbitrary[0],arbitrary[2]);
    assert.notEqual(insufficient.status,0);
    assert.equal(state(manifest).found_json,0);
  });
});

test('screenshot imports preserve original bytes and reject duplicate contents',()=>{
  withTemp('nebula-r40-import-image-',temp=>{
    const {kit,manifest,downloads}=fixture(temp);
    const first=path.join(downloads,'original-screenshot.png');
    const buf=Buffer.alloc(15000,0x37);
    Buffer.from([137,80,78,71,13,10,26,10]).copy(buf);
    fs.writeFileSync(first,buf);
    const ok=exec(IMPORT,manifest,'image','android_low','portrait','R38',first);
    assert.equal(ok.status,0,ok.stderr);
    assert.equal(state(manifest).found_screenshots,1);
    const duplicate=exec(IMPORT,manifest,'image','android_low','landscape','R38',first);
    assert.notEqual(duplicate.status,0);
    assert.equal(state(manifest).found_screenshots,1);
    assert.equal(fs.readdirSync(path.join(kit,'images')).length,1);
    assert.equal(JSON.parse(fs.readFileSync(manifest,'utf8')).field_work,false);
  });
});

test('unsafe manifest output path cannot escape the kit or overwrite another file',()=>{
  withTemp('nebula-r40-import-path-',temp=>{
    const {kit,manifest,downloads}=fixture(temp);
    const original=files(downloads,'R38',1790007001);
    const m=JSON.parse(fs.readFileSync(manifest,'utf8'));
    m.devices[0].runs[0].baseline[0]='reports/../../../outside.json';
    fs.writeFileSync(manifest,JSON.stringify(m));
    const rejected=exec(IMPORT,manifest,'json','android_low','portrait','MAX','R38',...original);
    assert.notEqual(rejected.status,0);
    assert.equal(fs.readdirSync(path.join(kit,'reports')).length,0);
    assert.equal(fs.existsSync(path.join(temp,'outside.json')),false);
  });
});
