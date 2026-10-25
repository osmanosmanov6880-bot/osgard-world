import test from 'node:test'
import assert from 'node:assert/strict'
import {readFileSync} from 'node:fs'

const source=readFileSync(new URL('./omega-live-webgl.spec.mjs',import.meta.url),'utf8')
const helper=readFileSync(new URL('./omega-browser-evidence.mjs',import.meta.url),'utf8')
const workflow=readFileSync(new URL('../.github/workflows/omega-r11-actual-browser-qa.yml',import.meta.url),'utf8')

test('release E2E uses genuine WebGL pixels for all four moments',()=>{
  assert.match(source,/captureAnimatedWebGLViewport/)
  assert.equal((source.match(/\(await captureAnimatedWebGLViewport\(page\)\)\.png/g)||[]).length,4)
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
  assert.match(workflow,/push:[\s\S]*?branches: \[master\]/)
  assert.match(workflow,/github\.event_name == 'push'/)
})
