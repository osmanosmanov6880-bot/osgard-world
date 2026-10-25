#!/usr/bin/env node
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const cleanup='scripts/cleanup-frontend-transport.sh';
function harness(){
  const dir=fs.mkdtempSync(path.join(os.tmpdir(),'osgard-transport-test-'));
  const ssh=path.join(dir,'ssh');
  fs.writeFileSync(ssh,['#!/bin/sh',
    'printf "%s\\n" "$@" > "$MOCK_CAPTURE"',
    'exit "${MOCK_SSH_EXIT:-0}"',''].join('\n'));
  fs.chmodSync(ssh,0o755);
  const capture=path.join(dir,'capture.txt');
  const run=(extra={})=>spawnSync('bash',[cleanup],{encoding:'utf8',timeout:5000,
    env:{...process.env,PATH:dir+path.delimiter+process.env.PATH,
      HOST:'example.com',USER:'osgard',GITHUB_RUN_ID:'40204194073',
      MOCK_CAPTURE:capture,MOCK_SSH_EXIT:'0',...extra}});
  const read=()=>fs.existsSync(capture)?fs.readFileSync(capture,'utf8'):'';
  const reset=()=>fs.existsSync(capture)&&fs.rmSync(capture);
  return {run,read,reset,close:()=>fs.rmSync(dir,{recursive:true,force:true})};
}
test('removes ONLY this Actions run transport directory, not game or rollback',()=>{
  const h=harness();try{
    const r=h.run();assert.equal(r.status,0,r.stderr);
    assert.match(r.stdout,/FRONTEND_TRANSPORT_CLEANED/);
    const calls=h.read().trim().split('\n');
    assert.equal(calls[calls.length-1],"rm -rf -- '/tmp/osgard-gh-release-40204194073'");
    assert.ok(calls.includes('osgard@example.com'));
    assert.ok(!calls.some(x=>/docker|nginx|\/usr\/|rollback|osgard-gh-previous/.test(x)));
  }finally{h.close()}
});
test('rejects ID injection, missing host or dangerous SSH target BEFORE network',()=>{
  const h=harness();try{
    for(const bad of [
      {GITHUB_RUN_ID:'../bad'}, {GITHUB_RUN_ID:'40204194073;rm -rf /'},
      {GITHUB_RUN_ID:'-100'}, {GITHUB_RUN_ID:''},
      {HOST:''},{USER:''},{HOST:'-oDanger'},
      {USER:'-evil'},{HOST:'evil\nextra'}
    ]){
      h.reset();const r=h.run(bad);
      assert.equal(r.status,2,JSON.stringify(bad)+' '+r.stderr);
      assert.equal(h.read(),'','No remote command when context invalid');
    }
  }finally{h.close()}
});
test('SSH failure is a reported error; never a successful cleanup',()=>{
  const h=harness();try{const r=h.run({MOCK_SSH_EXIT:'19'});
    assert.equal(r.status,19);assert.doesNotMatch(r.stdout,/TRANSPORT_CLEANED/);
  }finally{h.close()}
});
test('YAML covers failed stage, stale preactivation, skipped activation and postactivation failures',()=>{
  const y=fs.readFileSync('.github/workflows/deploy-frontend.yml','utf8');
  const anchors=[
    'id: frontend_stage','id: frontend_activate',
    'lease_rc=0', 'exit "$lease_rc"',
    "steps.frontend_stage.outcome == 'failure'",
    "steps.frontend_stage.outcome == 'success' && steps.frontend_activate.outcome == 'skipped'",
    "steps.frontend_activate.outcome == 'success'"
  ];
  for(const a of anchors)assert.ok(y.includes(a),'Missing cleanup contract '+a);
  assert.match(y,/bash scripts\/check-frontend-release-freshness\.sh \|\| lease_rc=\$\?/);
  const act=y.indexOf('- name: Activate verified archive with config rollback');
  const firstCleanup=y.indexOf('bash scripts/cleanup-frontend-transport.sh',act);
  const remoteExec=y.indexOf('scp -i ~/.ssh/osgard_deploy scripts/activate-frontend-remote.sh',act);
  assert.ok(firstCleanup>act&&firstCleanup<remoteExec,'Stale source cleanup BEFORE any remote activation');
  assert.match(y,/timeout 30s bash scripts\/cleanup-frontend-transport\.sh/g);
  assert.ok(y.split('timeout 30s bash scripts/cleanup-frontend-transport.sh').length>=5);
  assert.doesNotMatch(y,/Retire only this successful SSH transport archive\n\s+if: success\(\)/);
});

test('master W19 protected frontend path survives cleanup integration',()=>{
  const y=fs.readFileSync('.github/workflows/deploy-frontend.yml','utf8');
  assert.ok(y.includes('W19_ORIGINAL_SCREENSHOTS_AND_GAMEPLAY_EVIDENCE.zip'));
  assert.ok(y.includes('r135-w19-release-pin.json'));
  assert.ok(y.includes('r135-luxury-academy-w19-candidate-20261025'));
  assert.ok(y.includes('W19_ORIGINAL_SCREENSHOTS_AND_GAMEPLAY_EVIDENCE.zip'));
  assert.ok(y.includes('test "$PIN" = scripts/r135-w18-release-pin.json') || y.includes('if [[ "$PIN" == scripts/r135-w18-release-pin.json ]]'));
  assert.ok(y.includes('r135-w19-release-pin.json'));
  assert.ok(y.includes('bash scripts/check-frontend-release-freshness.sh || lease_rc=$?'));
});

test('master W20 protected frontend path survives cleanup integration',()=>{
  const y=fs.readFileSync('.github/workflows/deploy-frontend.yml','utf8');
  assert.ok(y.includes('W20_ORIGINAL_SCREENSHOTS_AND_GAMEPLAY_EVIDENCE.zip'));
  assert.ok(y.includes('r135-w20-release-pin.json'));
  assert.ok(y.includes('r135-player-settings-w20-candidate-20261025'));
  assert.ok(y.includes('independently-review-exact-W20'));
  assert.ok(y.includes('python3 scripts/r135-w20-promotion-qa.py --pin "$PIN" --artifact "$ROOT"'));
  assert.ok(y.includes('W19_ORIGINAL_SCREENSHOTS_AND_GAMEPLAY_EVIDENCE.zip'));
  assert.ok(y.includes('bash scripts/check-frontend-release-freshness.sh || lease_rc=$?'));
});
