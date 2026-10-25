#!/usr/bin/env node
// No production side effects. Negative tests must reject accidental W18
// activation without a reviewed source-controlled selector and promotion run.
import assert from 'node:assert/strict'
import { readFileSync, writeFileSync, mkdirSync, mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { spawnSync } from 'node:child_process'

const deploy = readFileSync('.github/workflows/deploy-frontend.yml', 'utf8')
const current = JSON.parse(readFileSync('scripts/r135-active-release.json','utf8'))
const selectorScript = readFileSync('scripts/r135-release-selector.sh','utf8')
const w14Pin = readFileSync('scripts/r135-w14-release-pin.json', 'utf8')
const syntacticW19Pin = JSON.stringify({
  version:'r135-luxury-academy-w19-candidate-20261025',
  source_commit:'a'.repeat(40),
  manifest_sha256:'b'.repeat(64)
})
function result(root) {
  return spawnSync('bash', ['scripts/r135-release-selector.sh'], {
    cwd: root, encoding: 'utf8'
  })
}
const w14Selector = {channel:'w14', pin_file:'scripts/r135-w14-release-pin.json',
  promotion_gate_run_id:null}
assert.ok(['w14','w18','w19'].includes(current.channel),'only reviewed release channels allowed')
if (current.channel === 'w14') {
  assert.deepEqual(
    {channel:current.channel, pin:current.pin_file, gate:current.promotion_gate_run_id},
    {channel:'w14', pin:w14Selector.pin_file, gate:null},
    'Retained W14 channel must not carry W18 promotion metadata')
} else {
  assert.equal(current.pin_file,
    current.channel === 'w18'
      ? 'scripts/r135-w18-release-pin.json'
      : 'scripts/r135-w19-release-pin.json')
  assert.ok(Number.isSafeInteger(current.promotion_gate_run_id) &&
    current.promotion_gate_run_id > 0,
    'W18/W19 production requires a specific reviewed independent acceptance run')
}
const liveSelection = result(process.cwd())
assert.equal(liveSelection.status,0,
  'Actual source-controlled release selection must be syntactically valid')
assert.equal(liveSelection.stdout.trim(),current.pin_file,
  'Public deploy selector must match the reviewed active channel')
let tested=0
function fixture(modify = x => x, modifiedPin = w14Pin) {
  const root = mkdtempSync(join(tmpdir(),'r135-release-channel-'))
  try {
    mkdirSync(join(root,'scripts'))
    writeFileSync(join(root,'scripts/r135-release-selector.sh'),selectorScript)
    writeFileSync(join(root,'scripts/r135-active-release.json'),
      JSON.stringify(modify({...w14Selector})))
    writeFileSync(join(root,'scripts/r135-w14-release-pin.json'),modifiedPin)
    return result(root)
  } finally {
    rmSync(root,{recursive:true,force:true})
  }
}
function fixtureW19(mutate = x => x, content = syntacticW19Pin) {
  const root = mkdtempSync(join(tmpdir(),'r135-w19-selector-'))
  try {
    mkdirSync(join(root,'scripts'))
    writeFileSync(join(root,'scripts/r135-release-selector.sh'),selectorScript)
    writeFileSync(join(root,'scripts/r135-active-release.json'),
      JSON.stringify(mutate({
        channel:'w19', pin_file:'scripts/r135-w19-release-pin.json',
        promotion_gate_run_id:123456789
      })))
    writeFileSync(join(root,'scripts/r135-w19-release-pin.json'),content)
    return result(root)
  } finally {
    rmSync(root,{recursive:true,force:true})
  }
}
assert.equal(fixtureW19().status,0,
  'Only a syntactically pinned W19 channel may be selected; this is NOT gate attestation'); tested++
for (const mutator of [
  x => ({...x,promotion_gate_run_id:null}),
  x => ({...x,promotion_gate_run_id:0}),
  x => ({...x,promotion_gate_run_id:'latest'}),
  x => ({...x,pin_file:'scripts/r135-w18-release-pin.json'}),
]) {
  assert.notEqual(fixtureW19(mutator).status,0,'Invalid W19 selector accepted')
  tested++
}
assert.notEqual(fixtureW19(x=>x,JSON.stringify({
  version:'r135-luxury-academy-w19-candidate-20261025',
  source_commit:'not-a-commit',manifest_sha256:'b'.repeat(64)
})).status,0,'W19 non-SHA source accepted'); tested++

assert.equal(fixture().status,0,'valid fixed W14 selector must retain the public release'); tested++
for(const mutation of [
  x => ({...x,channel:'w18',pin_file:'scripts/r135-w18-release-pin.json'}),
  x => ({...x,channel:'w19',pin_file:'scripts/r135-w19-release-pin.json'}),
  x => ({...x,channel:'latest'}),
  x => ({...x,channel:'w14',promotion_gate_run_id:12345}),
  x => ({...x,channel:'w14',pin_file:'scripts/r135-w18-release-pin.json'}),
  x => ({...x,channel:'w14',pin_file:'../unsafe'}),
]) {
  assert.notEqual(fixture(mutation).status,0,'invalid channel could trigger an unsafe deploy')
  tested++
}
const spoofPin = JSON.stringify({...JSON.parse(w14Pin),source_commit:'FAKE'})
assert.notEqual(fixture(x=>x,spoofPin).status,0,'unreviewed SHA must fail'); tested++
assert.ok(deploy.includes('PIN="$(bash scripts/r135-release-selector.sh)"'),
  'R135 stage must read persistent on-disk W14/W18 selector')
const usages = (deploy.match(/PIN="\$\(bash scripts\/r135-release-selector\.sh\)"/g) || []).length
assert.equal(usages,4,'all four staging, Nginx, SSH and live smoke gates must use SAME active release')
for(const proof of [
  'scripts/r135-w18-promotion-qa.py',
  'scripts/r135-w19-promotion-qa.py',
  'scripts/r135-w19-extract-durable-evidence.py',
  'W19_ORIGINAL_SCREENSHOTS_AND_GAMEPLAY_EVIDENCE.zip',
  'r135-luxury-academy-w19-reviewed-webgl-20261025',
  'independently-accept-real-w19',
  'r135-w19-promotion-gate.yml',
  'scripts/r135-w19-release-pin.json',
  'scripts/r135-verified-live-recover.py',
  'scripts/r135-release-stage.py',
  'independently-accept-real-candidate',
  'GATE_JOBS',
  'promotion_gate_run_id',
  'PIN_AT_GATE',
  'gh run download "$RUN_ID"',
  '.expired == false',
  'scripts/r135-release-selector.sh',
  'OSGARD_EXPECTED_R135_MANIFEST_SHA256',
  'node scripts/r135-production-smoke.mjs'
]) {
  assert.ok(deploy.includes(proof),'missing R135 immutable deployment safeguard: '+proof)
}
assert.ok(deploy.includes('if [[ "$PIN" == scripts/r135-w14-release-pin.json ]]; then'),
  'W14 must be explicitly separate from W18')
assert.ok(deploy.includes('elif [[ "$PIN" == scripts/r135-w18-release-pin.json ]]; then'),
  'W18 must never use floating W14 fallback')
assert.ok(!deploy.includes('PIN=scripts/r135-w18-release-pin.json'),
  'W18 must never become implicit default release')
assert.ok(deploy.includes('elif [[ "$PIN" == scripts/r135-w19-release-pin.json ]]; then'),
  'W19 must require a distinct immutable promotion branch')
assert.ok(!deploy.includes('PIN=scripts/r135-w19-release-pin.json'),
  'W19 must never become implicit default release')
console.log('R135 W18 production fail-closed static/selector tests PASS:',tested,
  'runtime selector cases; no SSH, deploy or hardware was executed.')
