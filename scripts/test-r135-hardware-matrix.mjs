#!/usr/bin/env node
// All inputs here are SYNTHETIC and cannot be submitted as hardware evidence.
import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { REQUIRED_CELLS, reviewEvidenceMatrix } from './r135-hardware-matrix.mjs'
import { summarizeRafIntervalsMs } from './r135-frame-metrics.mjs'
const pin = { version: 'r135-structure-test-ONLY', source_commit: 'a'.repeat(40),
  manifest_sha256: 'b'.repeat(64) }
const noPhones = reviewEvidenceMatrix([], pin)
assert.equal(noPhones.status, 'HOLD_DEVICE_EVIDENCE_MISSING')
assert.equal(noPhones.missing.length, 8)
const intervals = Array.from({ length: 340 }, () => 16.667)
const pacing = summarizeRafIntervalsMs(intervals)
const UA = {
  'android-chrome': 'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit Chrome/126',
  'iphone-safari': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0) AppleWebKit Version/17 Mobile Safari/604.1'
}
function fixture(cell, id) {
  const isPortrait = cell.orientation === 'portrait'
  const viewport = isPortrait ? [390, 844] : [844, 390]
  return {
    platform: cell.platform, orientation: cell.orientation, mode: cell.mode,
    session_id: 'synthetic-fixture-' + id, user_reviewed_touch: true,
    original_frame_reviewed: true,
    capture: {
      status: 'CAPTURED_NOT_HARDWARE_CERTIFIED',
      user_attested_physical_device: true, software_or_unknown_unless_attested: false,
      release: { version: pin.version, source_commit: pin.source_commit,
        raw_manifest_sha256: pin.manifest_sha256 },
      tested_mode: cell.mode, capture_seconds: 60,
      connected_browser: { user_agent: UA[cell.platform] },
      raw_godot_fps_samples: Array.from({ length: 120 }, () => ({
        visible: true, quality: cell.mode === 'ECO' ? 0 : 2,
        fps: 60, viewport
      })),
      browser_raf_callback_pacing_NOT_GPU_frametime: {
        ...pacing, raw_interval_samples_ms: intervals
      },
      sampled_render_fps_not_frame_time_one_percent_low: { median: 60 },
      screenshot_sha256: createHash('sha256').update('synthetic-only-' + id).digest('hex')
    }
  }
}
const one = fixture(REQUIRED_CELLS[0], 0)
assert.equal(reviewEvidenceMatrix([one],pin).missing.length, 8)
assert.throws(() => reviewEvidenceMatrix([{ ...one, capture: {
  ...one.capture, user_attested_physical_device: false } }], pin), /attestation/)
assert.throws(() => reviewEvidenceMatrix([{ ...one, capture: {
  ...one.capture, release: {...one.capture.release, source_commit:'c'.repeat(40)} } }], pin), /manifest mismatch/)
assert.throws(() => reviewEvidenceMatrix([{ ...one, capture: {
  ...one.capture, browser_raf_callback_pacing_NOT_GPU_frametime: {
    ...one.capture.browser_raf_callback_pacing_NOT_GPU_frametime, p99_interval_ms: 0.1
  } } }], pin), /raw samples/)
const full = REQUIRED_CELLS.flatMap((cell,i) => [fixture(cell, i*2), fixture(cell, i*2+1)])
assert.throws(() => reviewEvidenceMatrix([full[0],{...full[1],capture:{
  ...full[1].capture,screenshot_sha256:full[0].capture.screenshot_sha256}}],pin),/reused/)
const complete = reviewEvidenceMatrix(full,pin)
assert.equal(complete.status, 'REVIEW_REQUIRED_NOT_HARDWARE_CERTIFIED')
assert.equal(complete.missing.length, 0)
assert.equal(complete.reviewed_structural_sessions, 16)
console.log('W16 synthetic validator tests PASS; no physical Android/iPhone results have been collected')
