#!/usr/bin/env node
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const SCRIPT='scripts/check-frontend-release-freshness.sh';
const HEAD='a'.repeat(40);
const NEXT='b'.repeat(40);
function testHarness(){
  const dir=fs.mkdtempSync(path.join(os.tmpdir(),'osgard-freshness-test-'));
  const fake=path.join(dir,'gh');
  const shim=[
    '#!/bin/sh',
    '[ "$1" = api ] || exit 14',
    '[ "$2" = repos/example/repo/branches/master ] || exit 15',
    '[ "$3" = --jq ] && [ "$4" = .commit.sha ] || exit 16',
    '[ "$MOCK_API_FAIL" != 1 ] || exit 17',
    'printf "%s\\n" "$MOCK_MASTER_SHA"',
    ''
  ].join('\n');
  fs.writeFileSync(fake,shim);
  fs.chmodSync(fake,0o755);
  const run=(more={})=>spawnSync('bash',[SCRIPT],{
    encoding:'utf8',timeout:5000,
    env:{...process.env,PATH:dir+path.delimiter+process.env.PATH,
      GITHUB_REF:'refs/heads/master',
      GITHUB_REPOSITORY:'example/repo',GITHUB_SHA:HEAD,
      GH_TOKEN:'mock-read-only-token',MOCK_MASTER_SHA:HEAD,...more}
  });
  return {run,cleanup:()=>fs.rmSync(dir,{force:true,recursive:true})};
}
test('fresh reviewed master SHA can proceed; no server actions',()=>{
  const h=testHarness();
  try{
    const r=h.run();
    assert.equal(r.status,0,r.stderr);
    assert.match(r.stdout,/FRONTEND_RELEASE_FRESHNESS_OK/);
    assert.doesNotMatch(fs.readFileSync(SCRIPT,'utf8'),/ssh -i|scp -i|docker exec|git push/);
  }finally{h.cleanup()}
});
test('superseded master MUST block even if archive already passed checksum',()=>{
  const h=testHarness();
  try{
    const r=h.run({MOCK_MASTER_SHA:NEXT});
    assert.equal(r.status,42);
    assert.match(r.stderr,/FRONTEND_RELEASE_SUPERSEDED/);
  }finally{h.cleanup()}
});
test('GitHub API outage or corrupted master response cannot become release approval',()=>{
  const h=testHarness();
  try{
    const down=h.run({MOCK_API_FAIL:'1'});
    assert.equal(down.status,3);
    assert.match(down.stderr,/GITHUB_UNAVAILABLE/);
    const bad=h.run({MOCK_MASTER_SHA:'not-a-sha'});
    assert.equal(bad.status,3);
    assert.match(bad.stderr,/INVALID_HEAD/);
  }finally{h.cleanup()}
});
test('unknown SHA, foreign ref or missing token must fail before API call',()=>{
  const h=testHarness();
  try{
    for(const env of [
      {GITHUB_REF:'refs/pull/123/merge'},
      {GITHUB_SHA:'bad'},
      {GH_TOKEN:''},
      {GITHUB_REPOSITORY:'other user/private'}
    ]){
      const r=h.run(env);
      assert.equal(r.status,2,r.stderr);
      assert.match(r.stderr,/INVALID_CONTEXT/);
    }
  }finally{h.cleanup()}
});
test('release workflow rejects stale master early, before expensive builds and both SSH boundaries',()=>{
  const w=fs.readFileSync('.github/workflows/deploy-frontend.yml','utf8');
  const guard='bash scripts/check-frontend-release-freshness.sh';
  const uses=[...w.matchAll(/bash scripts\/check-frontend-release-freshness\.sh/g)].map(m=>m.index);
  assert.equal(uses.length,4,'Release must verify source at four independent boundaries');
  const checkout=w.indexOf('- uses: actions/checkout@v4');
  const npmInstall=w.indexOf('- run: npm ci');
  const validation=w.indexOf('- name: Verify release integrity and payment recovery boundaries');
  const godot=w.indexOf('- name: Validate the Godot game project contract');
  const stage=w.indexOf('- name: Stage archive and verify checksum');
  const activate=w.indexOf('- name: Activate verified archive with config rollback');
  const stageSsh=w.indexOf('ssh -i ~/.ssh/osgard_deploy',stage);
  const activateScp=w.indexOf('scp -i ~/.ssh/osgard_deploy',activate);
  assert.ok(checkout>=0&&npmInstall>checkout&&validation>npmInstall);
  assert.ok(godot>validation&&stage>godot&&activate>stage);
  assert.ok(uses[0]>checkout&&uses[0]<npmInstall,
    'Queued stale commits must fail before downloading npm packages');
  assert.ok(uses[1]>validation&&uses[1]<godot,
    'A master changed during checks must fail before Godot/large binary work');
  assert.ok(uses[2]>stage&&uses[2]<stageSsh&&stageSsh<activate,
    'Staging can never SSH a stale frontend source');
  assert.ok(uses[3]>activate&&uses[3]<activateScp,
    'Activation cannot continue if master changed during upload');
  const first=w.indexOf('- name: Abort obsolete queued releases');
  const second=w.indexOf('- name: Recheck release SHA after validations');
  assert.ok(first>checkout&&first<uses[0]&&second>validation&&second<uses[1]);
  const protectedStages=[
    w.slice(first,npmInstall),
    w.slice(second,godot),
    w.slice(stage,stageSsh),
    w.slice(activate,activateScp)
  ];
  const authHeader='GH_TOKEN: '+'$'+'{{ github.token }}';
  for(const stageText of protectedStages){
    assert.ok(stageText.includes(authHeader),
      'All four checks need an authenticated, read-only GitHub API token');
    assert.ok(stageText.includes(guard));
  }
});
