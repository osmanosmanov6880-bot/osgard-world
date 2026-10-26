import test from 'node:test'
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { resolve, dirname } from 'node:path'
import { readV47Sources, validateV47Packet, calculateV47BoardFingerprint } from './osa-cinema-v47-production-board.mjs'

const sources = readV47Sources()
const inspect = patch => {
  const altered = structuredClone(sources)
  patch?.(altered)
  return validateV47Packet(altered)
}
const mustReject = (patch, expected) => {
  const result = inspect(patch)
  assert.equal(result.engineeringPacketVerified, false)
  assert.equal(result.releaseDecision, 'NO_GO')
  assert.equal(result.publicationAuthorized, false)
  assert.equal(result.paidCheckoutEnabled, false)
  assert.ok(result.errors.some(error => error.includes(expected)),
    'expected blocker "' + expected + '" in ' + result.errors.join(', '))
}

test('V47 baseline validates an engineering plan but categorically denies film GO', () => {
  const result = inspect()
  assert.deepEqual(result.errors, [])
  assert.equal(result.engineeringPacketVerified, true)
  assert.equal(result.releaseDecision, 'NO_GO')
  assert.equal(result.actualFilmMasterApprovalVerified, false)
  assert.equal(result.independentlyVerifiedLegalRights, false)
  assert.equal(result.publicationAuthorized, false)
  assert.equal(result.externalGatesApproved, 0)
  assert.equal(result.canonicalScenes, 8)
  assert.equal(result.sourceWorkprints, 4)
  assert.equal(result.privateVoiceGuides, 6)
  assert.equal(result.productionWorkstreams, 7)
  assert.equal(result.externalGateCount, 8)
})

test('CLI is reproducible, machine readable and stays NO_GO even on success', () => {
  const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
  const outcome = spawnSync(process.execPath,
    [resolve(root, 'scripts/osa-cinema-v47-production-board.mjs')],
    { cwd: root, encoding: 'utf8', timeout: 10000 })
  assert.equal(outcome.status, 0, outcome.stderr)
  assert.equal(outcome.stderr, '')
  const report = JSON.parse(outcome.stdout)
  assert.equal(report.engineeringPacketVerified, true)
  assert.equal(report.releaseDecision, 'NO_GO')
  assert.match(report.boardFingerprintSha256, /^[a-f0-9]{64}$/)
  assert.equal(report.boardFingerprintSha256, calculateV47BoardFingerprint(sources.board))
})

test('publication/rights/checkout cannot be asserted in V47 or historic V20', () => {
  for (const flag of ['publicationAuthorized', 'rightsCleared', 'paidCheckoutEnabled']) {
    mustReject(data => { data.board.film[flag] = true }, 'unlocked:' + flag)
    mustReject(data => { data.policy[flag] = true }, 'unlocked:' + flag)
  }
})

test('an alleged final film or fabricated human approval is rejected', () => {
  mustReject(data => { data.board.film.releaseDecision = 'GO' }, 'readiness_misrepresented')
  mustReject(data => { data.board.film.finalHumanApprovedMastersVerified = true }, 'readiness_misrepresented')
  mustReject(data => { data.board.film.externalApprovalsVerified = true }, 'readiness_misrepresented')
  mustReject(data => { data.policy.assets[0].rightsApproved = true }, 'per_asset_human_approval_falsified')
  mustReject(data => { data.policy.assets[1].deliveryVerified = true }, 'per_asset_human_approval_falsified')
})

test('the real original film identifiers, durations and SHA cross-check with V20', () => {
  mustReject(data => { data.workprints.assets[0].durationSeconds = 239 },
    'four_original_workprints_or_durations_mismatch')
  mustReject(data => { data.workprints.assets[1].id = 'synthetic-trailer' },
    'four_original_workprints_or_durations_mismatch')
  mustReject(data => { data.policy.assets[0].originalSha256 = '1'.repeat(64) },
    'v20_and_v16_original_sha_mismatch')
  mustReject(data => { data.board.film.plannedFinalCaptionFiles = 3 },
    'candidate_master_inventory_mismatch')
})

test('six private audio guides are not commercially cleared material', () => {
  mustReject(data => { data.narrations.assets[0].rightsStatus = 'approved' },
    'six_original_voice_guides_misrepresented')
  mustReject(data => { data.narrations.assets[1].publicationStatus = 'public' },
    'six_original_voice_guides_misrepresented')
  mustReject(data => { data.narrations.assets.pop() },
    'six_original_voice_guides_misrepresented')
})

test('the eight recorded-film storyboard proposals are anchored to the real eight-scene UX', () => {
  mustReject(data => { data.board.scenes[1].number = 11 },
    'eight_canonical_scenes_or_proposed_storyboard_changed')
  mustReject(data => { data.board.scenes[4].treatmentStatus = 'RECORDED_AND_APPROVED' },
    'eight_canonical_scenes_or_proposed_storyboard_changed')
  mustReject(data => { data.board.scenes[0].ruTitle = 'Unknown story title' },
    'missing_or_reordered_live_ru_scene_1')
  mustReject(data => { data.board.scenes[5].enTitle = 'Fabricated licensed film' },
    'missing_or_reordered_live_en_scene_6')
  mustReject(data => { data.cinemaSource = null }, 'live_cinema_source_missing')
})

test('all seven production workstreams remain explicitly blocked', () => {
  mustReject(data => { data.board.workstreams[0].status = 'DONE' },
    'unearned_completion_or_missing_production_workstream')
  mustReject(data => { data.board.workstreams.splice(3, 1) },
    'unearned_completion_or_missing_production_workstream')
  mustReject(data => { data.board.workstreams[6].references = [] },
    'unearned_completion_or_missing_production_workstream')
})

test('the eight independent external roles match the actual V27 release board exactly', () => {
  mustReject(data => { data.board.externalGates[0].status = 'APPROVED' },
    'eight_independent_v27_signoffs_missing_or_falsified')
  mustReject(data => { data.board.externalGates.pop() },
    'eight_independent_v27_signoffs_missing_or_falsified')
  mustReject(data => { data.board.externalGates[6].evidenceInPublicRepo = true },
    'eight_independent_v27_signoffs_missing_or_falsified')
  mustReject(data => { data.board.externalGates[0].id = data.board.externalGates[1].id },
    'eight_independent_v27_signoffs_missing_or_falsified')
})

test('private footage, captions, licenses and signing keys cannot be uploaded by this stage', () => {
  mustReject(data => { data.board.constraints.noPublicVideo = false },
    'private_media_security_guard_removed')
  mustReject(data => { data.board.constraints.noAutomaticGo = false },
    'private_media_security_guard_removed')
  mustReject(data => { data.board.constraints.doNotUpload = [] },
    'private_media_security_guard_removed')
  mustReject(data => { data.board.sourceOfTruth = [] },
    'historical_policy_source_of_truth_removed')
})

test('a tampered baseline or missing required inputs fails closed', () => {
  mustReject(data => { data.board.baseline.verifiedV46Sha = '0'.repeat(40) },
    'approved_v46_baseline_changed')
  mustReject(data => { data.board = null }, 'v47_is_not_a_locked_planning_packet')
  mustReject(data => { data.policy = null }, 'v20_private_release_policy_missing')
})

test('the board has a deterministic fingerprint and not a single release-authorization endpoint', () => {
  const first = calculateV47BoardFingerprint(sources.board)
  const second = calculateV47BoardFingerprint(structuredClone(sources.board))
  assert.equal(first, second)
  assert.match(first, /^[a-f0-9]{64}$/)
  const altered = structuredClone(sources.board)
  altered.scenes[0].proposedVisualTreatment += ' (edit)'
  assert.notEqual(first, calculateV47BoardFingerprint(altered))
  assert.ok(!JSON.stringify(sources.board).includes('"releaseDecision":"GO"'))
  assert.ok(!JSON.stringify(sources.board).includes('"publicationAuthorized":true'))
})
