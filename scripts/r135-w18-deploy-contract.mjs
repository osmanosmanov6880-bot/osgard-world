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
function result(root) {
  return spawnSync('bash', ['scripts/r135-release-selector.sh'], {
    cwd: root, encoding: 'utf8'
  })
}
const w14Selector = {channel:'w14', pin_file:'scripts/r135-w14-release-pin.json',
  promotion_gate_run_id:null}
assert.ok(['w14','w18'].includes(current.channel),'only reviewed release channels allowed')
if (current.channel === 'w14') {
  assert.deepEqual(
    {channel:current.channel, pin:current.pin_file, gate:current.promotion_gate_run_id},
    {channel:'w14', pin:w14Selector.pin_file, gate:null},
    'Retained W14 channel must not carry W18 promotion metadata')
} else {
  assert.equal(current.pin_file,'scripts/r135-w18-release-pin.json')
  assert.ok(Number.isSafeInteger(current.promotion_gate_run_id) &&
    current.promotion_gate_run_id > 0,
    'W18 production requires a specific reviewed independent acceptance run')
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
assert.equal(fixture().status,0,'valid fixed W14 selector must retain the public release'); tested++
for(const mutation of [
  x => ({...x,channel:'w18',pin_file:'scripts/r135-w18-release-pin.json'}),
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
// W18 long-term archive is an alternative source of IDENTICAL reviewed bytes,
// not another dynamic channel, stale web fallback, or unreviewed producer.
for (const literal of [
  'ARCHIVE_FROM_ACTIONS=0',
  'if [[ "$ARCHIVE_FROM_ACTIONS" != 1 ]]; then',
  'r135-premium-learning-w18-reviewed-archive-20261025',
  'R135_W18_ORIGINAL_EVIDENCE.zip',
  '.digest==$hash',
  '--member-pin scripts/r135-w18-evidence-member-pin.json',
  '--evidence "$ROOT/R135_W18_ORIGINAL_EVIDENCE.zip"',
  'python3 scripts/r135-w18-release-recover.py',
  'python3 scripts/r135-w18-promotion-qa.py --pin "$PIN" --artifact "$ROOT"',
]) {
  assert.ok(deploy.includes(literal), 'missing W18 durable SHA/recovery safeguard: '+literal)
}
const w18Section = deploy.slice(
  deploy.indexOf('elif [[ "$PIN" == scripts/r135-w18-release-pin.json ]]; then'),
  deploy.indexOf('          else\n            echo \'Unreviewed R135 channel refused\'', 
    deploy.indexOf('elif [[ "$PIN" == scripts/r135-w18-release-pin.json ]]; then'))
)
assert.ok(w18Section.includes('GATE_JOBS') &&
  w18Section.includes('PIN_AT_GATE') &&
  w18Section.indexOf('GATE_JOBS') < w18Section.indexOf('ARCHIVE_FROM_ACTIONS'),
  'W18 archive fallback must not bypass independent original-artifact review')
assert.ok(!w18Section.includes('r135-verified-live-recover.py'),
  'W18 fallback must never reuse a stale production server copy')

console.log('R135 W18 production fail-closed static/selector tests PASS:',tested,
  'runtime selector cases; no SSH, deploy or hardware was executed.')
