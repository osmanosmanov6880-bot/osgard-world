import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// Regression: R14's real Chromium test was cancelled by a later skipped
// workflow_run, even after the Godot WebAssembly had deployed correctly.
const workflow=readFileSync('.github/workflows/omega-r11-actual-browser-qa.yml','utf8')
test('new release acceptance runs cannot cancel each other',()=>{
  assert.match(workflow,/group: omega-live-webgl-\$\{\{ github\.run_id \}\}/)
  assert.match(workflow,/cancel-in-progress: false/)
  assert.doesNotMatch(workflow,/group: omega-r11-browser-\$\{\{ github\.event_name \}\}-\$\{\{ github\.ref \}\}/)
})
test('only master manual, master workflow promotion or successful verified master SSH can accept live',()=>{
  assert.match(workflow,/github\.event_name == 'workflow_dispatch'/)
  assert.match(workflow,/^  push:\n    branches: \[master\]\n    paths:\n      - '\.github\/workflows\/omega-r11-actual-browser-qa\.yml'/m)
  assert.match(workflow,/github\.event_name == 'push'/)
  assert.match(workflow,/github\.ref == 'refs\/heads\/master'/)
  assert.doesNotMatch(workflow,/^  push:\n    branches: \[master\]\n  workflow_run:/m,'only edits to R11 workflow may trigger push rechecks')
  assert.match(workflow,/github\.event\.workflow_run\.conclusion == 'success'/)
  assert.match(workflow,/github\.event\.workflow_run\.head_branch == 'master'/)
  assert.match(workflow,/workflows: \['OSGARD Omega verified Godot direct SSH deploy'\]/)
})
test('neither PR nor failed SSH run may report a nonpublished game as browser passing',()=>{
  const header=workflow.slice(workflow.indexOf('  actual-desktop-phone-webgl:'),workflow.indexOf('    steps:',workflow.indexOf('  actual-desktop-phone-webgl:')))
  assert.doesNotMatch(header,/github\.event_name == 'pull_request'/)
  assert.match(header,/github\.event_name == 'push'/)
  assert.match(header,/github\.ref == 'refs\/heads\/master'/)
  assert.match(header,/github\.event_name == 'workflow_dispatch'/)
  assert.match(header,/github\.event\.workflow_run\.conclusion == 'success'/)
  assert.match(header,/github\.event\.workflow_run\.conclusion == 'success'/)
  assert.match(workflow,/npx playwright test --config playwright\.omega-live-webgl\.config\.mjs/)
})
