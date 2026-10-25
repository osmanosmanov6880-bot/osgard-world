#!/usr/bin/env node
// Voluntary LOCAL physical-browser capture for R135, not a CI SwiftShader score.
// Requires a user-connected DevTools CDP endpoint; no external telemetry service.
import { chromium } from 'playwright'
import { mkdir, writeFile, readFile } from 'node:fs/promises'
import { createHash } from 'node:crypto'
import { summarizeRafIntervalsMs } from './r135-frame-metrics.mjs'
import { dirname, resolve } from 'node:path'
import process from 'node:process'

const args = process.argv.slice(2)
const value = (name, fallback = '') => {
  const i = args.indexOf(name)
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback
}
const endpoint = value('--cdp')
const url = value('--url', 'https://osgard.world/games/r135-service/')
const output = resolve(value('--out', 'r135-device-capture.json'))
const duration = Number(value('--seconds', '60'))
const attestedPhysical = args.includes('--physical-device-attested')
const expectedVersion = value('--expect-version', 'r135-web-legibility-w11-20261024')
const expectedSource = value('--expect-source', '6f4b98a5c7785669cb10ff68def621a2d8eed7fa')
const expectedManifestSha = value('--expect-manifest-sha256', '289a14960b06f684498f04f04c6892bd6b91f102c961f66ff27343a3e054a3dd')
const expectedMode = value('--mode', 'ECO').toUpperCase()
const expectedQuality = expectedMode === 'ECO' ? 0 : expectedMode === 'HERO' ? 2 : -1
if (!endpoint || !Number.isFinite(duration) || duration < 20 || duration > 300 ||
    expectedQuality < 0 || !/^[0-9a-f]{40}$/.test(expectedSource) || !/^[0-9a-f]{64}$/.test(expectedManifestSha)) {
  console.error('Usage: node scripts/r135-device-evidence.mjs --cdp http://127.0.0.1:9222 --url https://osgard.world/games/r135-service/ --seconds 60 --mode ECO|HERO --out report.json [--physical-device-attested] [--expect-version VERSION --expect-source SHA40 --expect-manifest-sha256 SHA64]')
  process.exit(2)
}
const cdpu = new URL(endpoint)
if (cdpu.protocol !== 'http:' || !['127.0.0.1', 'localhost', '[::1]'].includes(cdpu.hostname)) {
  throw new Error('Remote CDP debug sockets are prohibited: forward authorized phone CDP to localhost only')
}
if (attestedPhysical && new URL(url).origin !== 'https://osgard.world') {
  throw new Error('A physical release certification cannot be attached to a nonproduction URL')
}

const quantile = (sorted, p) => sorted[Math.max(0, Math.min(sorted.length - 1, Math.floor((sorted.length - 1) * p)))]
const sleep = ms => new Promise(resolveDelay => setTimeout(resolveDelay, ms))
const browser = await chromium.connectOverCDP(endpoint, { timeout: 30_000 })
try {
  const context = browser.contexts()[0]
  if (!context) throw new Error('CDP endpoint has no browser context')
  let page = context.pages().find(p => p.url().startsWith(url)) ?? await context.newPage()
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 120_000 })
  await page.waitForFunction(
    () => window.__OSGARD_R135_QA?.scene_ready && window.__OSGARD_R135_QA?.loaded?.endsWith('.glb'),
    null, { timeout: 120_000 }
  )
  // Hash the REAL manifest bytes from the loaded origin; never regenerate JSON
  // or trust a user-entered version string for the hardware report.
  const manifestText = await page.evaluate(async () => {
    const response = await fetch(new URL('release.json', location.href), { cache: 'no-store' })
    if (!response.ok) throw new Error('R135 manifest could not be read: HTTP ' + response.status)
    return response.text()
  })
  const manifestSha256 = createHash('sha256').update(manifestText, 'utf8').digest('hex')
  const release = JSON.parse(manifestText)
  if (release.version !== expectedVersion || release.source_commit !== expectedSource
      || manifestSha256 !== expectedManifestSha) {
    throw new Error('Physical performance evidence points to wrong game bytes: ' +
      JSON.stringify({version:release.version, source:release.source_commit, manifest_sha256:manifestSha256}))
  }
  const firstMode = await page.evaluate(() => window.__OSGARD_R135_QA?.quality)
  if (firstMode !== expectedQuality) {
    throw new Error('Select ' + expectedMode + ' in the real Godot game before capture (actual quality=' + firstMode + ')')
  }
  await page.evaluate(() => {
    const record = {intervals_ms: [], last: null, running: true, hidden_breaks: 0}
    window.__OSGARD_R135_W12_RAF = record
    const collect = timestamp => {
      if (!record.running) return
      if (document.visibilityState === 'visible') {
        if (record.last !== null && timestamp > record.last) record.intervals_ms.push(timestamp - record.last)
        record.last = timestamp
      } else {
        record.last = null
        record.hidden_breaks++
      }
      requestAnimationFrame(collect)
    }
    requestAnimationFrame(collect)
  })
  const samples = []
  const startedAt = Date.now()
  while (Date.now() - startedAt < duration * 1000) {
    const value = await page.evaluate(() => {
      const state = window.__OSGARD_R135_QA || {}
      return {
        time_ms: performance.now(),
        fps: Number(state.render_fps_sample),
        visible: document.visibilityState === 'visible',
        quality: state.quality,
        motion_enabled: state.motion_enabled,
        viewport: [state.viewport_w, state.viewport_h],
        heap_bytes: performance.memory?.usedJSHeapSize ?? null
      }
    })
    samples.push(value)
    await sleep(250)
  }
  const callbackFrames = await page.evaluate(() => {
    const record = window.__OSGARD_R135_W12_RAF
    if (!record) throw new Error('W12 visible-page frame observer missing')
    record.running = false
    return { intervals_ms: record.intervals_ms, hidden_breaks: record.hidden_breaks }
  })
  const changedMode = samples.some(s => s.quality !== expectedQuality)
  if (changedMode || (await page.evaluate(() => window.__OSGARD_R135_QA?.quality)) !== expectedQuality) {
    throw new Error('The physical performance sample mixes ECO and HERO settings')
  }
  const callbackPacing = summarizeRafIntervalsMs(callbackFrames.intervals_ms)
  const valid = samples.filter(s => s.visible && Number.isFinite(s.fps) && s.fps > 0)
  if (valid.length < 30) throw new Error('Insufficient foreground/positive-FPS samples for evidence')
  const fps = valid.map(s => s.fps).sort((a, b) => a - b)
  const percentBelow30 = valid.filter(s => s.fps < 30).length / valid.length
  const frame = await page.evaluate(() => ({
    user_agent: navigator.userAgent,
    hardware_concurrency: navigator.hardwareConcurrency ?? null,
    device_memory_gib: navigator.deviceMemory ?? null,
    device_pixel_ratio: devicePixelRatio,
    screen_size: [screen.width, screen.height],
    final_scene: window.__OSGARD_R135_QA?.schema ?? null
  }))
  const png = output.replace(/\.json$/i, '') + '.png'
  await mkdir(dirname(output), { recursive: true })
  await page.screenshot({ path: png, fullPage: true })
  const pngSha256 = createHash('sha256').update(await readFile(png)).digest('hex')
  const summary = {
    status: 'CAPTURED_NOT_HARDWARE_CERTIFIED',
    release: { version: release.version, source_commit: release.source_commit, engine: release.engine,
      raw_manifest_sha256: manifestSha256 },
    tested_mode: expectedMode,
    exact_requested_url: url,
    timestamp_utc: new Date().toISOString(),
    capture_seconds: duration,
    connected_browser: frame,
    software_or_unknown_unless_attested: !attestedPhysical,
    user_attested_physical_device: attestedPhysical,
    browser_raf_callback_pacing_NOT_GPU_frametime: {
      ...callbackPacing,
      hidden_callback_interruptions: callbackFrames.hidden_breaks,
      raw_interval_samples_ms: callbackFrames.intervals_ms,
    },
    raw_godot_fps_samples: samples,
    screenshot_sha256: pngSha256,
    sampled_render_fps_not_frame_time_one_percent_low: {
      valid_samples: valid.length,
      median: quantile(fps, .5),
      p05: quantile(fps, .05),
      p01: quantile(fps, .01),
      p95: quantile(fps, .95),
      fraction_samples_below_30: Number(percentBelow30.toFixed(4))
    },
    thermal_measurement_c: null,
    battery_impact_measured: false,
    touch_latency_measured: false,
    screenshot: png,
    warnings: [
      'Godot FPS samples are not true frametime 1% lows.',
      'This is a capture utility; thermals/battery and hands-on usability need separate evidence.',
      'A CDP endpoint alone does not prove a physical device, use explicit attestation.',
      'rAF callback pacing is not GPU frame completion or per-frame Godot CPU/GPU timing.',
      'The physical-device checkbox is user-attested and is not an independent cryptographic hardware attestation.',
      'No measured temperature, battery, touch latency or subjective usability is implied by this script.'
    ]
  }
  await writeFile(output, JSON.stringify(summary, null, 2) + '\n')
  console.log(JSON.stringify({ status: summary.status, output,
    fps_median: summary.sampled_render_fps_not_frame_time_one_percent_low.median,
    raf_p99_ms: callbackPacing.p99_interval_ms,
    raf_one_percent_low_fps: callbackPacing.callback_pacing_one_percent_low_fps }, null, 2))
} finally {
  await browser.close()
}
