#!/usr/bin/env node
// W16 STRUCTURAL evidence gate, not a phone/GPU certification.
// Synthetic fixtures and user attestations never prove physical devices.
import { readFileSync } from 'node:fs'
import { resolve, basename, dirname, join } from 'node:path'
import { pathToFileURL } from 'node:url'
import { createHash } from 'node:crypto'
import { summarizeRafIntervalsMs } from './r135-frame-metrics.mjs'

export const REQUIRED_CELLS = ['android-chrome', 'iphone-safari'].flatMap(platform =>
  ['portrait', 'landscape'].flatMap(orientation =>
    ['ECO', 'HERO'].map(mode => ({ platform, orientation, mode }))))
const SHA40 = /^[a-f0-9]{40}$/
const SHA64 = /^[a-f0-9]{64}$/
const error = (reason) => { throw new Error('R135 W16 evidence rejected: ' + reason) }
function median(values) {
  const sorted = [...values].sort((a, b) => a - b)
  return sorted[Math.floor((sorted.length - 1) / 2)]
}

export function reviewEvidenceMatrix(records, pin) {
  if (!pin || !SHA40.test(pin.source_commit) || !SHA64.test(pin.manifest_sha256) ||
      typeof pin.version !== 'string' || !pin.version.startsWith('r135-'))
    error('invalid immutable release pin')
  if (!Array.isArray(records)) error('expected a JSON array of source captures')
  const uniqueSessionIds = new Set()
  const uniqueScreenshots = new Set()
  const counts = new Map()
  const metrics = []
  for (const [i, record] of records.entries()) {
    if (!record || typeof record !== 'object') error('invalid capture ' + i)
    const { platform, orientation, mode, session_id, capture } = record
    if (!REQUIRED_CELLS.some(cell =>
      cell.platform === platform && cell.orientation === orientation && cell.mode === mode))
      error('unknown hardware matrix cell ' + i)
    if (typeof session_id !== 'string' || session_id.length < 8 ||
        uniqueSessionIds.has(session_id)) error('duplicate/invalid session ID ' + i)
    uniqueSessionIds.add(session_id)
    if (record.user_reviewed_touch !== true || record.original_frame_reviewed !== true)
      error('independent hands-on original-frame review missing ' + i)
    if (!capture || capture.status !== 'CAPTURED_NOT_HARDWARE_CERTIFIED' ||
        capture.user_attested_physical_device !== true ||
        capture.software_or_unknown_unless_attested !== false)
      error('missing explicit physical-device attestation ' + i)
    if (!capture.release || capture.release.version !== pin.version ||
        capture.release.source_commit !== pin.source_commit ||
        capture.release.raw_manifest_sha256 !== pin.manifest_sha256)
      error('source/manifest mismatch ' + i)
    if (capture.tested_mode !== mode || !Number.isFinite(capture.capture_seconds) ||
        capture.capture_seconds < 60) error('mode or duration changed ' + i)
    const agent = String(capture.connected_browser?.user_agent || '')
    if (platform === 'android-chrome' && !(/Android/i.test(agent) && /Chrome/i.test(agent)))
      error('non-Android Chrome report ' + i)
    if (platform === 'iphone-safari' &&
        !(/iPhone/i.test(agent) && /Safari/i.test(agent) && !/CriOS|FxiOS|EdgiOS/i.test(agent)))
      error('not an independently captured iPhone Safari report ' + i)
    const samples = capture.raw_godot_fps_samples
    const neededQuality = mode === 'ECO' ? 0 : 2
    if (!Array.isArray(samples) || samples.length < 100 ||
        samples.some(s => !s || !s.visible || s.quality !== neededQuality ||
          !Number.isFinite(s.fps) || s.fps <= 0 || s.fps > 300 ||
          !Array.isArray(s.viewport) || s.viewport.length !== 2))
      error('missing or mixed visible Godot FPS samples ' + i)
    const [w, h] = samples[0].viewport
    if (!(w >= 200 && h >= 200) ||
        ((h > w) ? 'portrait' : 'landscape') !== orientation ||
        samples.some(s => s.viewport[0] !== w || s.viewport[1] !== h))
      error('mixed or incorrect orientation ' + i)
    const callback = capture.browser_raf_callback_pacing_NOT_GPU_frametime
    const raw = callback?.raw_interval_samples_ms
    if (!Array.isArray(raw) || raw.length < 300) error('insufficient raw rAF callback evidence ' + i)
    const calculated = summarizeRafIntervalsMs(raw)
    if (Math.abs(Number(callback.p99_interval_ms) - calculated.p99_interval_ms) > 0.1 ||
        Math.abs(Number(callback.callback_pacing_one_percent_low_fps) -
          calculated.callback_pacing_one_percent_low_fps) > 0.1)
      error('reported callback summary does not match raw samples ' + i)
    const reportedMedian = Number(capture.sampled_render_fps_not_frame_time_one_percent_low?.median)
    const computedMedian = median(samples.map(s => s.fps))
    if (!Number.isFinite(reportedMedian) || Math.abs(reportedMedian - computedMedian) > 0.5)
      error('reported sampled FPS does not match raw values ' + i)
    const imageHash = String(capture.screenshot_sha256 || '')
    if (!SHA64.test(imageHash) || uniqueScreenshots.has(imageHash))
      error('absent or reused original screenshot hash ' + i)
    uniqueScreenshots.add(imageHash)
    const cell = platform + '/' + orientation + '/' + mode
    counts.set(cell, (counts.get(cell) || 0) + 1)
    metrics.push({ cell, session_id, callback_p99_ms: calculated.p99_interval_ms,
      callback_one_percent_low_fps_NOT_GPU: calculated.callback_pacing_one_percent_low_fps,
      sampled_godot_fps_median_NOT_GPU_frametime: computedMedian })
  }
  const missing = REQUIRED_CELLS.map(c => ({
    cell: c.platform + '/' + c.orientation + '/' + c.mode,
    actual_independent_sessions: counts.get(c.platform + '/' + c.orientation + '/' + c.mode) || 0,
    required_independent_sessions: 2
  })).filter(c => c.actual_independent_sessions < 2)
  return {
    status: missing.length ? 'HOLD_DEVICE_EVIDENCE_MISSING' : 'REVIEW_REQUIRED_NOT_HARDWARE_CERTIFIED',
    reviewed_structural_sessions: records.length, required_matrix_cells: 8, missing, metrics,
    note: 'JSON/UA/user attestation is not a cryptographic hardware proof. Safari and Android require actual authorized independent review; rAF is not GPU frametime.'
  }
}

function runCli() {
  const [pinFile, evidenceFile] = process.argv.slice(2)
  if (!pinFile || !evidenceFile) {
    console.error('Usage: node scripts/r135-hardware-matrix.mjs <immutable-pin.json> <evidence-sessions.json>')
    process.exitCode = 2
    return
  }
  const pin = JSON.parse(readFileSync(resolve(pinFile), 'utf8'))
  const document = JSON.parse(readFileSync(resolve(evidenceFile), 'utf8'))
  const sessions = document.sessions
  if (!Array.isArray(sessions)) error('evidence JSON must contain sessions array')
  // Original screenshot bytes are checked separately from potentially forged JSON claims.
  const directory = dirname(resolve(evidenceFile))
  for (const record of sessions) {
    const file = record.original_screenshot
    if (typeof file !== 'string' || file !== basename(file) || !file.endsWith('.png'))
      error('screenshot filename must be a relative PNG basename')
    const digest = createHash('sha256').update(readFileSync(join(directory, file))).digest('hex')
    if (digest !== record.capture?.screenshot_sha256) error('original PNG bytes changed: ' + file)
  }
  const result = reviewEvidenceMatrix(sessions, pin)
  console.log(JSON.stringify(result, null, 2))
  // An honest missing physical-phone matrix must BLOCK certification.
  if (result.missing.length) process.exitCode = 3
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) runCli()
