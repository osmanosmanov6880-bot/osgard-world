#!/usr/bin/env node
/**
 * W28 independent prelaunch decision support. NEVER deploys or certifies phones.
 * Only immutable GitHub source evidence, real manually reviewed phone captures
 * and verified human pilot can justify a human GO decision.
 */
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { pathToFileURL } from 'node:url'
import { reviewEvidenceMatrix } from './r135-hardware-matrix.mjs'
import { reviewPilotSessions } from './r135-w28-pilot-evidence.mjs'

const SHA40 = /^[a-f0-9]{40}$/
const SHA64 = /^[a-f0-9]{64}$/
const VERSION = 'r135-integrated-w27-candidate-20261025'

const validSha = (value, pattern) => typeof value === 'string' && pattern.test(value)
const isTrue = value => value === true
const fail = reason => { throw new Error('W28 prelaunch evidence rejected: ' + reason) }

export function assessLaunch({ active, pin, software, phoneSessions = [],
                                pilot = {}, legal = {}, operations = {} }) {
  if (!active || typeof active !== 'object') fail('no live source-controlled release selector')
  if (!pin || typeof pin !== 'object') fail('W27 candidate pin is missing')
  if (!validSha(pin.source_commit,SHA40) ||
      !validSha(pin.archive_sha256,SHA64) ||
      !validSha(pin.manifest_sha256,SHA64))
    fail('W27 source/ZIP/manifest hashes are not immutable SHA values')
  if (!Array.isArray(phoneSessions)) fail('physical captures must be an explicit array')

  const blockers = []
  const block = (condition, message) => { if (!condition) blockers.push(message) }
  const frames = pin.screenshots_sha256
  const expectedFlags = [
    'reviewed_luxury_desktop','reviewed_luxury_mobile',
    'reviewed_settings_desktop','reviewed_settings_mobile',
    'reviewed_settings_persistence','reviewed_coach_desktop',
    'reviewed_coach_mobile','reviewed_real_causal_errors',
    'reviewed_replay_desktop','reviewed_replay_mobile',
    'reviewed_replay_safety','reviewed_mastery_persistence',
    'reviewed_art_lighting','reviewed_audio_opt_in',
    'reviewed_bilingual_captions','reviewed_privacy_consent_purge',
    'reviewed_hero_real_pbr','reviewed_eco_restored',
    'reviewed_no_overlap','reviewed_ru_en','browser_three_fault_cases'
  ]
  block(pin.version === VERSION, 'W27_CANDIDATE_VERSION_UNVERIFIED')
  block(pin.physical_phone_fps_verified === false &&
        pin.photorealistic_aaa_certified === false,
        'NO_SOFTWARE_BASED_HARDWARE_OR_AAA_CERTIFICATION')
  block(frames && typeof frames === 'object' &&
        !Array.isArray(frames) &&
        Object.keys(frames).length === 29 &&
        new Set(Object.values(frames)).size === 29 &&
        Object.values(frames).every(h => validSha(h,SHA64)),
        'W27_29_ORIGINAL_FRAMES_NOT_INDEPENDENTLY_VERIFIED')
  block(expectedFlags.every(f => isTrue(pin[f])),
        'W27_GENUINE_GAMEPLAY_AUDIO_PRIVACY_HERO_ECO_REVIEWS_MISSING')
  block(Number.isSafeInteger(pin.artifact_run_id) &&
        Number.isSafeInteger(pin.native_run_id) &&
        pin.artifact_run_id > 0 && pin.native_run_id > 0,
        'NATIVE_AND_WEBGL_WORKFLOW_IDS_MISSING')

  const softwareMatch = software &&
    software.status === 'W27_SOFTWARE_ACCEPTED_HARDWARE_HOLD' &&
    software.source_commit === pin.source_commit &&
    software.manifest_sha256 === pin.manifest_sha256 &&
    software.archive_sha256 === pin.archive_sha256 &&
    software.original_png_frames === 29 &&
    ['desktop-1366','mobile-390'].every(device =>
      software.actual_godot_chromium_diagnostics?.[device]?.genuine_cases === 3)
  block(softwareMatch, 'INDEPENDENT_W27_NATIVE_WEBGL_3_FAULT_PBR_EVIDENCE_NOT_ACCEPTED')

  const exactActive =
    active.channel === 'w27' &&
    active.pin_file === 'scripts/r135-w27-release-pin.json' &&
    Number.isSafeInteger(active.promotion_gate_run_id) &&
    active.promotion_gate_run_id > 0
  block(exactActive, 'LIVE_W27_SOURCE_SELECTOR_AND_INDEPENDENT_GATE_NOT_ACTIVE')
  block(operations.https_manifest_source === pin.source_commit &&
        operations.https_manifest_sha256 === pin.manifest_sha256 &&
        operations.wasm_gzip_http_200 === true &&
        operations.pck_range_http_206 === true &&
        operations.rollback_W21_ready === true,
        'REAL_LIVE_HTTPS_BYTES_AND_W21_ROLLBACK_UNVERIFIED')

  let hardware = null
  try {
    hardware = reviewEvidenceMatrix(phoneSessions, pin)
    block(hardware.missing.length === 0 && hardware.reviewed_structural_sessions >= 16,
      'PHYSICAL_ANDROID_IPHONE_EIGHT_CELL_16_SESSION_MATRIX_MISSING')
  } catch {
    blockers.push('PHYSICAL_DEVICE_EVIDENCE_INVALID_OR_UNREVIEWED')
  }
  // The structural matrix and user agent can still be spoofed. Do not infer
  // independent phone hardware measurements from self-attestation/JSON.
  block(operations.actual_independent_hardware_human_review === true &&
        operations.human_hardware_originals_reviewed === true,
        'INDEPENDENT_PHYSICAL_PHONE_HARDWARE_REVIEW_NOT_SIGNED')

  // Never trust user-provided aggregate "25 pilot participants" alone:
  // derive the counters from individual source-matched one-time original
  // session hashes. Even then software cannot attest that a person is real.
  let pilotReview = {}
  if (Array.isArray(pilot.sessions)) {
    try {
      pilotReview = reviewPilotSessions(pilot.sessions,pin.source_commit)
    } catch {
      blockers.push('ORIGINAL_HUMAN_PILOT_RECORDS_INVALID_OR_UNREVIEWED')
    }
  }
  block(pilotReview.status === 'REVIEW_REQUIRED_NOT_HUMAN_CERTIFIED',
        'PILOT_INDIVIDUAL_SOURCE_BOUND_SESSION_RECORDS_MISSING')
  const participants = Number(pilotReview.independent_volunteers)
  const safetySuccess = Number(pilotReview.correct_safety_explanations)
  block(Number.isSafeInteger(participants) && participants >= 20 && participants <= 50,
        '20_TO_50_VOLUNTARY_HUMAN_BETA_SESSIONS_NOT_DOCUMENTED')
  block(Number.isSafeInteger(safetySuccess) && safetySuccess >= 0 &&
        participants > 0 && safetySuccess <= participants &&
        safetySuccess / participants >= 0.80,
        'SAFETY_EXPLANATIONS_BELOW_80_PERCENT_OR_UNMEASURED')
  block(pilotReview.interlock_bypasses === 0 &&
        pilotReview.lost_saves === 0 && pilotReview.blocking_device_crashes === 0,
        'INTERLOCK_DATA_LOSS_OR_DEVICE_BLOCKERS_UNKNOWN')
  block(pilotReview.original_session_records_reviewed === true &&
        pilotReview.reviewer_confirms_real_humans === true,
        'NO_INDEPENDENT_HUMAN_BETA_EVIDENCE')

  block(legal.original_pbr_source_license_reviewed === true &&
        legal.procedural_audio_source_license_reviewed === true &&
        legal.font_license_reviewed === true &&
        legal.privacy_and_training_disclaimer_reviewed === true,
        'SOURCE_LICENSE_PRIVACY_AND_SAFETY_DOCUMENTATION_UNREVIEWED')
  block(operations.owner_approved_production_switch === true,
        'OWNER_FINAL_MANUAL_GO_REQUIRED')

  const uniqueBlockers = [...new Set(blockers)]
  return {
    schema: 'OSGARD_R135_W28_GO_NO_GO_V1',
    status: uniqueBlockers.length ? 'NO_GO_HOLD' : 'EVIDENCE_COMPLETE_HUMAN_RELEASE_REQUIRED',
    candidate_source_sha: pin.source_commit,
    base_live_channel: active.channel,
    independent_phone_structural_status: hardware?.status ?? 'MISSING',
    pilot_reported_volunteers: Number.isFinite(participants) ? participants : null,
    blockers: uniqueBlockers,
    // No script, JSON report or CI workflow can push the VPS release live.
    automatic_deploy_authorized: false,
    physical_phone_hardware_certified_by_this_script: false,
    physical_thermals_battery_certified_by_this_script: false,
    human_final_release_decision_required: true
  }
}

function main() {
  const args = process.argv.slice(2)
  const value = name => {
    const i = args.indexOf(name)
    return i >= 0 && args[i+1] ? args[i+1] : null
  }
  const read = filename => JSON.parse(readFileSync(resolve(filename),'utf8'))
  const selectorFile = value('--selector') || 'scripts/r135-active-release.json'
  const pinFile = value('--pin')
  if (!pinFile) {
    console.error('Usage: node scripts/r135-w28-launch-decision.mjs --pin REVIEWED_W27_PIN.json ' +
      '[--selector active.json] [--software independent.json] [--phone-matrix sessions.json] ' +
      '[--pilot human-pilot.json] [--licenses licenses.json] [--operations signed-operations.json]')
    process.exitCode = 2
    return
  }
  const result = assessLaunch({
    active: read(selectorFile),
    pin: read(pinFile),
    software: value('--software') ? read(value('--software')) : {},
    phoneSessions: value('--phone-matrix') ? read(value('--phone-matrix')).sessions : [],
    pilot: value('--pilot') ? read(value('--pilot')) : {},
    legal: value('--licenses') ? read(value('--licenses')) : {},
    operations: value('--operations') ? read(value('--operations')) : {}
  })
  console.log(JSON.stringify(result,null,2))
  if (result.status !== 'EVIDENCE_COMPLETE_HUMAN_RELEASE_REQUIRED') process.exitCode = 3
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main()
}
