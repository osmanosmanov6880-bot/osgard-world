import test from 'node:test'
import assert from 'node:assert/strict'
import {readFileSync} from 'node:fs'
const workflow=readFileSync('.github/workflows/omega-godot-web.yml','utf8')
test('R40 six-candidate calibrated physics gets a bounded real CI runtime',()=>{
  assert.match(workflow,/test_seconds=15/)
  assert.match(workflow,/v59_r40_force_motor_calibration\.gd/)
  assert.match(workflow,/test_seconds=110/)
  assert.match(workflow,/timeout --signal=TERM --kill-after=5s "\$\{test_seconds\}s" godot/)
  assert.match(workflow,/for test_file in godot\/empire-omega\/tests\/\*\.gd/)
  assert.match(workflow,/Failed Godot test/)
  assert.match(workflow,/exit "\$failures"/)
})
test('production never exports an untested R42 physics runtime',()=>{
  const testStep=workflow.indexOf('Execute native Godot city-smoke and gameplay regression tests')
  const exportStep=workflow.indexOf('Export authentic Godot 4.4.1 Web application')
  const sshStep=workflow.indexOf('Commit verified native runtime')
  assert.ok(testStep>0 && exportStep>testStep && sshStep>exportStep)
  assert.doesNotMatch(workflow,/continue-on-error: true/)
  assert.match(workflow,/omega-build-freshness\.py/)
  assert.match(workflow,/public\/games\/omega-3d-preview/)
})
