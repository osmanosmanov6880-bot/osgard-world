#!/usr/bin/env node
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';

const HELPER='scripts/preserve-nebula-r40-qa.sh';
const HEAD='9efb03c246a28a168886e2aa494872e907ea78cd';
const FILES=['index.html','index.js','index.wasm','index.pck'];
function fixture(){
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'nebula-r40-qa-preserve-'));
  const active=path.join(root,'live','games','remix','nebula-r40-qa');
  const candidate=path.join(root,'candidate','html','games','remix','nebula-r40-qa');
  const pin=path.join(root,'pinned-head.sha');
  fs.mkdirSync(active,{recursive:true});
  fs.mkdirSync(candidate,{recursive:true});
  fs.writeFileSync(pin,HEAD+'\n');
  for(const f of FILES){
    fs.writeFileSync(path.join(active,f),'CI-R40-APPROVED-'+f);
    fs.writeFileSync(path.join(candidate,f),'STALE-SPA-BUNDLE-'+f);
  }
  fs.writeFileSync(path.join(active,'R40_DEVICE_ARTIFACT_PROVENANCE.txt'),
    'pull_request_head_sha='+HEAD+'\n'+
    'ci_checkout_sha='+'f'.repeat(40)+'\n'+
    'source_branch=release/nebula-r40-final-hardware-qa-20261025\n'+
    'release_status=HARDWARE_QA_ONLY_NOT_PRODUCTION\n');
  function attest(){
    const sums=FILES.map(f=>createHash('sha256').update(
      fs.readFileSync(path.join(active,f))).digest('hex')+'  '+f).join('\n')+'\n';
    fs.writeFileSync(path.join(active,'R40_DEVICE_ARTIFACT_SHA256.txt'),sums);
  }
  attest();
  return {root,active,candidate,pin,attest,cleanup:()=>fs.rmSync(root,{recursive:true,force:true})};
}
function run(s){
  return spawnSync('sh',[HELPER,s.active,s.candidate,s.pin],{encoding:'utf8',timeout:6000});
}
test('a valid isolated QA survives a whole-site candidate swap byte-for-byte',()=>{
  const f=fixture();
  try{
    const x=run(f);
    assert.equal(x.status,0,x.stderr);
    assert.match(x.stdout,/NEBULA_R40_QA_PRESERVED/);
    for(const name of FILES){
      assert.deepEqual(fs.readFileSync(path.join(f.candidate,name)),
        fs.readFileSync(path.join(f.active,name)));
    }
    const check=spawnSync('sha256sum',['-c','R40_DEVICE_ARTIFACT_SHA256.txt'],
      {cwd:f.candidate,encoding:'utf8'});
    assert.equal(check.status,0,check.stderr);
  }finally{f.cleanup()}
});
test('unpublished QA does not invent original source data',()=>{
  const f=fixture();
  try{
    fs.rmSync(path.join(f.active,'R40_DEVICE_ARTIFACT_SHA256.txt'));
    const x=run(f);
    assert.equal(x.status,0,x.stderr);
    assert.match(x.stdout,/NEBULA_R40_QA_NOT_STAGED/);
    assert.match(fs.readFileSync(path.join(f.candidate,'index.html'),'utf8'),/^STALE-SPA/);
  }finally{f.cleanup()}
});
test('tampered active WASM blocks activation and does not touch candidate',()=>{
  const f=fixture();
  try{
    fs.appendFileSync(path.join(f.active,'index.wasm'),'tampered');
    const x=run(f);
    assert.notEqual(x.status,0);
    assert.match(x.stderr,/QA bytes changed/);
    assert.match(fs.readFileSync(path.join(f.candidate,'index.wasm'),'utf8'),/^STALE-SPA/);
  }finally{f.cleanup()}
});
test('wrong pinned candidate head does not preserve unknown game',()=>{
  const f=fixture();
  try{
    fs.writeFileSync(f.pin,'0'.repeat(40)+'\n');
    const x=run(f);
    assert.notEqual(x.status,0);
    assert.match(x.stderr,/provenance differs/);
    assert.match(fs.readFileSync(path.join(f.candidate,'index.html'),'utf8'),/^STALE-SPA/);
  }finally{f.cleanup()}
});
test('extra checksum entry, missing file and symlinked source fail closed',()=>{
  const f=fixture();
  try{
    fs.appendFileSync(path.join(f.active,'R40_DEVICE_ARTIFACT_SHA256.txt'),
      '0'.repeat(64)+'  ../etc/passwd\n');
    assert.notEqual(run(f).status,0);
    f.attest();
    fs.rmSync(path.join(f.active,'index.pck'));
    assert.notEqual(run(f).status,0);
    fs.writeFileSync(path.join(f.active,'index.pck'),'RESTORED');
    f.attest();
    fs.rmSync(path.join(f.active,'index.js'));
    fs.symlinkSync(path.join(f.active,'index.html'),path.join(f.active,'index.js'));
    assert.notEqual(run(f).status,0);
  }finally{f.cleanup()}
});
test('activation retains attested QA before swapping frontend root, never promotes',()=>{
  const shell=fs.readFileSync('scripts/activate-frontend-remote.sh','utf8');
  const deploy=fs.readFileSync('.github/workflows/deploy-frontend.yml','utf8');
  const helper=fs.readFileSync(HELPER,'utf8');
  const index=shell.indexOf('sh /tmp/osgard-gh-next/preserve-nebula-r40-qa.sh');
  const swap=shell.indexOf('mv /usr/share/nginx/html /tmp/osgard-gh-previous');
  assert.ok(index>=0&&swap>index,'QA must be preserved before root swap');
  assert.match(shell,/sha256sum -c R40_DEVICE_ARTIFACT_SHA256\.txt/);
  assert.match(deploy,/cp scripts\/preserve-nebula-r40-qa\.sh osgard-release\/preserve-nebula-r40-qa\.sh/);
  assert.match(deploy,/node --test scripts\/omega-frontend-preservation\.test\.mjs scripts\/nebula-r40-qa-preservation\.test\.mjs/);
  assert.match(deploy,/nebula-r40-qa-head\.sha/);
  assert.doesNotMatch(helper,/\/games\/remix\/arena-v2\/nebula-3d\/index/);
});
