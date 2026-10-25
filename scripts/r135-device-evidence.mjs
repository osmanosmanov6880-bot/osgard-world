#!/usr/bin/env node
// Voluntary LOCAL physical-browser capture for R135, not a CI SwiftShader score.
// Requires a user-connected DevTools CDP endpoint; no external telemetry service.
import { chromium } from 'playwright'
import { mkdir, writeFile } from 'node:fs/promises'
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
if (!endpoint || !Number.isFinite(duration) || duration < 20 || duration > 300) {
  console.error('Usage: node scripts/r135-device-evidence.mjs --cdp http://127.0.0.1:9222 --url URL --seconds 60 --out report.json [--physical-device-attested]')
  process.exit(2)
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
  const release = await page.evaluate(async () => {
    const response = await fetch(new URL('release.json', location.href), { cache: 'no-store' })
    if (!response.ok) throw new Error('R135 manifest could not be read: HTTP ' + response.status)
    const data = await response.json()
    return { version: data.version, source_commit: data.source_commit, engine: data.engine }
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
  const summary = {
    status: 'CAPTURED',
    release,
    timestamp_utc: new Date().toISOString(),
    capture_seconds: duration,
    connected_browser: frame,
    software_or_unknown_unless_attested: !attestedPhysical,
    user_attested_physical_device: attestedPhysical,
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
      'A CDP endpoint alone does not prove a physical device, use explicit attestation.'
    ]
  }
  await writeFile(output, JSON.stringify(summary, null, 2) + '\n')
  console.log(JSON.stringify({ status: 'CAPTURED', output, fps_median: summary.sampled_render_fps_not_frame_time_one_percent_low.median }, null, 2))
} finally {
  await browser.close()
}
