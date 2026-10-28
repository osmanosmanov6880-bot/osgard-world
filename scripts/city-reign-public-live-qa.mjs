// Independent public acceptance of the REAL SSH-published CITY REIGN Godot
// WebGL2 game. The test does not generate fake scenery or substitute frames.
import { chromium } from '@playwright/test'
import { PNG } from 'pngjs'
import { mkdirSync, writeFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { captureAnimatedWebGLViewport } from './omega-browser-evidence.mjs'
import { realGameFrameEvidence } from './omega-world-frame-evidence.mjs'

const BASE = 'https://osgard.world/games/city-reign/'
// Explicit 40-character SHAs are injected by the exact-source SSH job.
 // A legacy R160 default supports the historical manual evidence workflow.
const SHA = process.env.CITY_REIGN_EXPECTED_SHA || '14f78e346574b10d7bceed70d61bd731b37529ef'
if (!/^[0-9a-f]{40}$/.test(SHA)) throw Error('Expected source SHA must be exactly forty hex characters')
const OUT = resolve(process.env.CITY_REIGN_PUBLIC_EVIDENCE_DIR ||
  'city-reign-live-public-evidence')
mkdirSync(OUT, { recursive: true })
const summary = {
  title: 'CITY REIGN — real browser acceptance of public original Godot',
  source_sha: SHA,
  public_url: BASE,
  software_gpu_ci_only: true,
  physical_mobile_fps_verified: false,
  high_end_aaa_art_verified: false,
  screens: [],
  status: 'RUNNING'
}

function sampleDifference(first, second) {
  const a = PNG.sync.read(first), b = PNG.sync.read(second)
  let delta = 0, samples = 0
  for (let y = 2; y < 38; y++) for (let x = 2; x < 58; x++) {
    const sample = (image, channel) => {
      const ix = Math.min(image.width - 1,
        Math.floor((x + 0.5) * image.width / 60))
      const iy = Math.min(image.height - 1,
        Math.floor((y + 0.5) * image.height / 40))
      return image.data[(iy * image.width + ix) * 4 + channel]
    }
    for (let k = 0; k < 3; k++) {
      delta += Math.abs(sample(a, k) - sample(b, k))
      samples++
    }
  }
  return delta / samples
}

async function verifyViewport(browser, name, dimensions, mobile) {
  const context = await browser.newContext({
    viewport: dimensions, deviceScaleFactor: 1,
    isMobile: mobile, hasTouch: mobile,
    locale: 'ru-RU',
    serviceWorkers: 'block'
  })
  const page = await context.newPage()
  const failures = []
  page.on('pageerror', e => failures.push(e.message))
  page.on('crash', () => failures.push('Original Godot renderer crashed'))
  try {
    const response = await page.goto(BASE + '?public_qa=' + name, {
      waitUntil: 'domcontentloaded', timeout: 55000
    })
    if (response?.status() !== 200)
      throw new Error('Original public game HTML must return HTTP 200')
    const canvas = page.locator('#canvas')
    await canvas.waitFor({ state: 'visible', timeout: 60000 })
    await page.waitForFunction(
      () => document.querySelector('#status') === null, null,
      { timeout: 160000 }
    )
    const engine = await canvas.evaluate(el => {
      const gl = el.getContext('webgl2')
      return {
        actualWebGL2: !!gl,
        lost: gl?.isContextLost() ?? true,
        nativeCanvas: [el.width, el.height]
      }
    })
    if (!engine.actualWebGL2 || engine.lost)
      throw new Error('Live page is NOT a working original Godot WebGL2 canvas')
    let sourceFrame, sourceEvidence
    for (let attempt = 0; attempt < 5; attempt++) {
      await page.waitForTimeout(attempt === 0 ? 4000 : 1700)
      sourceFrame = (await captureAnimatedWebGLViewport(page)).png
      sourceEvidence = realGameFrameEvidence(sourceFrame)
      if (sourceEvidence.realWorldEdges) break
    }
    if (!sourceEvidence.realWorldEdges)
      throw new Error('Live CITY REIGN displayed a loader or blank page, not an actual 3D city')
    writeFileSync(resolve(OUT, name + '-real-Godot-world.png'), sourceFrame)
    const record = {
      name, dimensions, mobile, engine,
      originalFrame: sourceEvidence,
      sourceVerified: true,
      actualInputChecked: false
    }
    if (!mobile) {
      await page.mouse.click(Math.floor(dimensions.width / 2),
        Math.floor(dimensions.height / 2))
      await page.keyboard.press('Tab')
      await page.waitForTimeout(1600)
      const secondFrame = (await captureAnimatedWebGLViewport(page)).png
      const difference = sampleDifference(sourceFrame, secondFrame)
      writeFileSync(resolve(OUT, name + '-real-city-operations-Tab.png'), secondFrame)
      if (difference <= 9)
        throw new Error('Original published game TAB command center did not open')
      record.actualInputChecked = true
      record.tabScreenDifference = difference
      // CITY REIGN R160: check the NEW camera on the true PUBLIC engine,
      // after the original TAB cabinet closes. Not a CI fixture or website.
      await page.keyboard.press('Tab')
      await page.waitForTimeout(1700)
      const priorView = (await captureAnimatedWebGLViewport(page)).png
      await page.keyboard.press('v')
      await page.waitForTimeout(2400)
      const nextView = (await captureAnimatedWebGLViewport(page)).png
      const cameraDifference = sampleDifference(priorView, nextView)
      writeFileSync(resolve(OUT,name+'-real-3d-camera-after-V.png'),nextView)
      if(cameraDifference <= 6)
        throw new Error('PUBLIC R160 camera V did not physically change original city 3D perspective')
      record.actualCameraSwitchChecked = true
      record.originalCameraPixelDifference = cameraDifference
    }
    if (failures.length)
      throw new Error('Real public Godot browser runtime errors: ' + failures.join('; '))
    summary.screens.push(record)
    console.log('PASS LIVE ORIGINAL GODOT:', JSON.stringify(record))
  } finally {
    await context.close()
  }
}

async function run() {
  const browser = await chromium.launch({
    headless: true,
    args: ['--enable-webgl', '--ignore-gpu-blocklist',
      '--use-gl=angle', '--use-angle=gl']
  })
  try {
    const page = await browser.newPage()
    const manifestResponse = await page.request.get(BASE + 'release.json?verify=public-real-browser', {
      timeout: 25000,
      headers: { 'Cache-Control': 'no-cache' }
    })
    if (manifestResponse.status() !== 200)
      throw new Error('No public release manifest')
    const manifest = await manifestResponse.json()
    if (manifest.source_commit !== SHA ||
      manifest.channel !== 'city-reign-preview' ||
      manifest.main_scene !== 'res://scenes/main.tscn' ||
      manifest.engine !== 'Godot 4.4.1' ||
      !manifest.files?.['index.wasm'] || !manifest.files?.['index.pck'])
      throw new Error('Published source SHA, native main scene or channel does not match')
    await page.close()
    await verifyViewport(browser, 'desktop-1366x768',
      { width: 1366, height: 768 }, false)
    await verifyViewport(browser, 'mobile-390x844',
      { width: 390, height: 844 }, true)
    summary.status = 'PASS'
    console.log('PASS: exact published source, true desktop and mobile-size WebGL2, original 3D and TAB')
  } finally {
    await browser.close()
  }
}

try {
  await run()
} catch (err) {
  summary.status = 'FAIL'
  summary.error = String(err?.stack || err)
  console.error('FAIL: source-locked public Godot browser acceptance:', summary.error)
  process.exitCode = 1
} finally {
  writeFileSync(resolve(OUT, 'PUBLIC-REAL-GODOT-ACCEPTANCE.json'),
    JSON.stringify(summary, null, 2) + '\n')
}
