import test from 'node:test'
import assert from 'node:assert/strict'
import {readFileSync} from 'node:fs'

const source=readFileSync(new URL('./omega-live-webgl.spec.mjs',import.meta.url),'utf8')
const helper=readFileSync(new URL('./omega-browser-evidence.mjs',import.meta.url),'utf8')
const workflow=readFileSync(new URL('../.github/workflows/omega-r11-actual-browser-qa.yml',import.meta.url),'utf8')

test('release E2E uses genuine WebGL pixels for all four moments',()=>{
  assert.match(source,/captureAnimatedWebGLViewport/)
  // R72 captures the first REAL frame inside a bounded loader-rejection
  // loop and three further frames after player input. Older contracts counted
  // only inline .png syntax, reporting a false CI failure when capture improved.
  assert.equal((source.match(/\(await captureAnimatedWebGLViewport\(page\)\)\.png/g)||[]).length,3)
  assert.equal((source.match(/const capture=await captureAnimatedWebGLViewport\(page\)/g)||[]).length,1)
  assert.match(source,/worldProof=realGameFrameEvidence\(frame\)/)
  assert.doesNotMatch(source,/await page\.screenshot\(/)
  assert.match(source,/expect\(entryMotion,[\s\S]*?\)\.toBeGreaterThan\(0\.08\)/)
  assert.match(source,/expect\(driveMotion,[\s\S]*?\)\.toBeGreaterThan\(0\.08\)/)
  assert.match(source,/waitForExactPublishedRelease/)
})

test('capture tool retains strict non-fake evidence and all three live routes',()=>{
  assert.match(helper,/Page\.captureScreenshot/)
  assert.match(helper,/captureLiveGodotCanvas/)
  assert.match(helper,/page\.screenshot/)
  assert.match(helper,/No authentic WebGL pixels could be captured/)
  assert.match(helper,/Real WebGL canvas capture is not a valid PNG/)
})

test('public browser PR gate exercises the new capture contract',()=>{
  assert.match(workflow,/node --test scripts\/omega-live-webgl-capture\.contract\.test\.mjs/)
  assert.match(workflow,/scripts\/omega-live-webgl-capture\.contract\.test\.mjs/)
  // R82 permits exactly one master-only live recheck when this reviewed
  // workflow is promoted. An arbitrary game push must never be treated as
  // evidence from the SSH-published WebAssembly.
  assert.match(workflow,/^  push:\n    branches: \[master\]\n    paths:\n      - '\.github\/workflows\/omega-r11-actual-browser-qa\.yml'/m)
  assert.doesNotMatch(workflow.slice(workflow.indexOf('  actual-desktop-phone-webgl:')),/github\.event_name == 'pull_request'/)
  assert.match(workflow.slice(workflow.indexOf('  actual-desktop-phone-webgl:')),/github\.ref == 'refs\/heads\/master'/)
})
