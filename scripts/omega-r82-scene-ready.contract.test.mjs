import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const spec=readFileSync('scripts/omega-live-webgl.spec.mjs','utf8')
const frameProof=readFileSync('scripts/omega-world-frame-evidence.mjs','utf8')
const r11=readFileSync('.github/workflows/omega-r11-actual-browser-qa.yml','utf8')
const r50=readFileSync('.github/workflows/omega-r50-release-evidence-qa.yml','utf8')

test('R82 waits for genuine Godot scene pixels, never certifies a still-loading splash',()=>{
  const start=spec.indexOf('const scenePaintStartedAt=Date.now()')
  const end=spec.indexOf("await testInfo.attach('godot-real-world-frame-proof.json'",start)
  assert.ok(start>0 && end>start,'real-game readiness loop must remain present')
  const proofLoop=spec.slice(start,end)
  assert.match(proofLoop,/const maxSceneWaitMs=45_000/)
  assert.match(proofLoop,/const maxSceneCaptures=18/)
  assert.match(proofLoop,/attempt<=maxSceneCaptures/)
  assert.match(proofLoop,/await captureAnimatedWebGLViewport\(page\)/)
  assert.match(proofLoop,/worldProof=realGameFrameEvidence\(frame\)/)
  assert.match(proofLoop,/if\(worldProof\.realWorldEdges\)break/)
  assert.match(proofLoop,/if\(remainingMs<=0 \|\| attempt===maxSceneCaptures\)break/)
  assert.match(proofLoop,/await page\.waitForTimeout\(Math\.min\(1800,remainingMs\)\)/)
  assert.match(spec,/expect\(worldProof\.realWorldEdges,[\s\S]*?'public WebGL frame must show an actual world\/HUD, not the splash screen'\)\.toBe\(true\)/)
  assert.match(spec,/scenePaintElapsedMs:Date\.now\(\)-scenePaintStartedAt/)
  assert.doesNotMatch(proofLoop,/splash.*toBe\(true\)|mock|fake\.png|placeholder/i)
  assert.match(frameProof,/realWorldEdges/)
})

test('R82 R11 runs honest software Mesa WebGL with no browser retries',()=>{
  assert.match(r11,/sudo apt-get install -y xvfb libgl1-mesa-dri libegl1 libgl1/)
  assert.match(r11,/OMEGA_CI_GL_BACKEND: mesa/)
  assert.match(r11,/LIBGL_ALWAYS_SOFTWARE: "1"/)
  assert.match(r11,/xvfb-run -a -s '-screen 0 1920x1080x24'/)
  assert.match(r11,/npx playwright test --config playwright\.omega-live-webgl\.config\.mjs --retries=0/)
  assert.doesNotMatch(r11,/run: npx playwright test --config playwright\.omega-live-webgl\.config\.mjs/)
})

test('R82 preserves original HTTP 7-of-7 and no-hardware-GO public R50',()=>{
  assert.match(r50,/omega-live-integrity\.py/)
  assert.match(r50,/public_verified_sha256.*==7/)
  assert.match(r50,/missing-two-physical-hardware-reports/)
  assert.match(r50,/--retries=0 --reporter=json/)
  assert.match(r50,/github\.ref == 'refs\/heads\/master'/)
})

test('R82 R11 one-time push retest is strictly bound to reviewed master workflow',()=>{
  assert.match(r11,/^  push:\n    branches: \[master\]\n    paths:\n      - '\.github\/workflows\/omega-r11-actual-browser-qa\.yml'/m)
  const job=r11.slice(r11.indexOf('  actual-desktop-phone-webgl:'))
  assert.doesNotMatch(job,/github\.event_name == 'pull_request'/)
  assert.match(job,/github\.event_name == 'push'/)
  assert.match(job,/github\.ref == 'refs\/heads\/master'/)
  assert.match(job,/github\.event\.workflow_run\.conclusion == 'success'/)
  assert.match(job,/github\.event\.workflow_run\.head_branch == 'master'/)
})
