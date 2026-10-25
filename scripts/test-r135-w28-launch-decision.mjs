#!/usr/bin/env node
import assert from 'node:assert/strict'
import { assessLaunch } from './r135-w28-launch-decision.mjs'

const pin = {
  version:'r135-integrated-w27-candidate-20261025',
  source_commit:'a'.repeat(40), manifest_sha256:'b'.repeat(64),
  archive_sha256:'c'.repeat(64), artifact_run_id:555,
  native_run_id:556, physical_phone_fps_verified:false,
  photorealistic_aaa_certified:false,
  screenshots_sha256:Object.fromEntries(
    Array.from({length:29},(_,i)=>['synthetic-frame-'+i,BigInt(i+1).toString(16).padStart(64,'0')])),
}
const flags = [
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
for(const f of flags)pin[f]=true

const software = {
  status:'W27_SOFTWARE_ACCEPTED_HARDWARE_HOLD',
  source_commit:pin.source_commit,
  manifest_sha256:pin.manifest_sha256,
  archive_sha256:pin.archive_sha256,
  original_png_frames:29,
  actual_godot_chromium_diagnostics:{
    'desktop-1366':{genuine_cases:3},
    'mobile-390':{genuine_cases:3}
  }
}
const active={channel:'w21',pin_file:'scripts/r135-w21-release-pin.json',
  promotion_gate_run_id:40215573327}
const review={active,pin,software,phoneSessions:[],pilot:{},legal:{},operations:{}}
const result=assessLaunch(review)
assert.equal(result.status,'NO_GO_HOLD')
assert.equal(result.automatic_deploy_authorized,false)
assert.equal(result.physical_phone_hardware_certified_by_this_script,false)
assert.equal(result.human_final_release_decision_required,true)
assert.ok(result.blockers.includes('PHYSICAL_ANDROID_IPHONE_EIGHT_CELL_16_SESSION_MATRIX_MISSING'))
assert.ok(result.blockers.includes('20_TO_50_VOLUNTARY_HUMAN_BETA_SESSIONS_NOT_DOCUMENTED'))
assert.ok(result.blockers.includes('LIVE_W27_SOURCE_SELECTOR_AND_INDEPENDENT_GATE_NOT_ACTIVE'))
let tests=4
const reject=(candidate,pattern)=>{
  assert.throws(()=>assessLaunch(candidate),new RegExp(pattern))
  tests++
}
reject({...review,pin:{...pin,source_commit:'latest'}},'immutable')
reject({...review,pin:{...pin,manifest_sha256:'wrong'}},'immutable')
reject({...review,phoneSessions:'not an array'},'explicit array')
assert.ok(assessLaunch({...review,pin:{...pin,physical_phone_fps_verified:true}})
  .blockers.includes('NO_SOFTWARE_BASED_HARDWARE_OR_AAA_CERTIFICATION'))
tests++
assert.ok(assessLaunch({...review,pin:{...pin,screenshots_sha256:{
  ...pin.screenshots_sha256,'extra frame':'d'.repeat(64)}}})
  .blockers.includes('W27_29_ORIGINAL_FRAMES_NOT_INDEPENDENTLY_VERIFIED'))
tests++
assert.ok(assessLaunch({...review,software:{...software,source_commit:'e'.repeat(40)}})
  .blockers.includes('INDEPENDENT_W27_NATIVE_WEBGL_3_FAULT_PBR_EVIDENCE_NOT_ACCEPTED'))
tests++
assert.ok(assessLaunch({...review,phoneSessions:[],
  operations:{actual_independent_hardware_human_review:true,
    human_hardware_originals_reviewed:true}})
  .blockers.includes('PHYSICAL_ANDROID_IPHONE_EIGHT_CELL_16_SESSION_MATRIX_MISSING'))
tests++
const fakePilot={independent_volunteers:25,correct_safety_explanations:24,
  interlock_bypasses:0,lost_saves:0,blocking_device_crashes:0,
  original_session_records_reviewed:true,reviewer_confirms_real_humans:true}
const stillNo=assessLaunch({...review,pilot:fakePilot,phoneSessions:[]})
assert.equal(stillNo.status,'NO_GO_HOLD')
assert.ok(stillNo.blockers.includes('INDEPENDENT_PHYSICAL_PHONE_HARDWARE_REVIEW_NOT_SIGNED'))
assert.equal(stillNo.automatic_deploy_authorized,false)
tests++
const underExplained={...fakePilot,correct_safety_explanations:19}
assert.ok(assessLaunch({...review,pilot:underExplained}).blockers
  .includes('SAFETY_EXPLANATIONS_BELOW_80_PERCENT_OR_UNMEASURED'))
tests++
const lost={...fakePilot,lost_saves:1}
assert.ok(assessLaunch({...review,pilot:lost}).blockers
  .includes('INTERLOCK_DATA_LOSS_OR_DEVICE_BLOCKERS_UNKNOWN'))
tests++
console.log('W28 evidence-first beta NO-GO PASS:',tests,
  'synthetic negative scenarios; 0 physical phones, 0 human sessions, 0 auto-deploy')
