import test from 'node:test'
import assert from 'node:assert/strict'
import {readFileSync} from 'node:fs'

const source=readFileSync(new URL('./omega-live-webgl.spec.mjs',import.meta.url),'utf8')
const helper=readFileSync(new URL('./omega-browser-evidence.mjs',import.meta.url),'utf8')
const evidence=readFileSync(new URL('./omega-world-frame-evidence.mjs',import.meta.url),'utf8')
const workflow=readFileSync(new URL('../.github/workflows/omega-r11-actual-browser-qa.yml',import.meta.url),'utf8')

test('release E2E uses genuine WebGL pixels for all four moments',()=>{
  assert.match(source,/captureAnimatedWebGLViewport/)
  // R82 authentic startup proof must wait in the SAME Chromium session.
  // 3 later captures prove real touch/keyboard motion; no synthetic PNGs,
  // re-run of Playwright test, or loader accepting shortcut is permitted.
  assert.equal((source.match(/\(await captureAnimatedWebGLViewport\(page\)\)\.png/g)||[]).length,3)
  assert.match(source,/waitForRealGodotWorldFrame\(/)
  assert.match(source,/\(\)=>captureAnimatedWebGLViewport\(page\)/)
  assert.match(source,/expect\(readiness\.ready,[\s\S]*?\)\.toBe\(true\)/)
  assert.match(source,/expect\(worldProof\.realWorldEdges,[\s\S]*?\)\.toBe\(true\)/)
  assert.match(evidence,/realGameFrameEvidence\(capture\.png\)/)
  assert.match(evidence,/maxAttempts=24/)
  assert.match(evidence,/maxWaitMs=80000/)
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
  assert.doesNotMatch(workflow,/^  push:/m)
  assert.doesNotMatch(workflow.slice(workflow.indexOf('  actual-desktop-phone-webgl:')),/github\.event_name == 'push'/)
})
