/**
 * OSA CINEMA V47: fail-closed verification of the production roadmap packet.
 *
 * Reads only public non-secret repo metadata. Passing this check certifies the
 * engineering/planning packet, NEVER a finished movie, rights, playback or
 * authorization to publish/charge. Film bytes and private approval reports
 * must not be supplied to this program or GitHub Actions.
 */
import { createHash } from 'node:crypto'
import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { EXTERNAL_GATES } from './osa-cinema-v27-release-board.mjs'

const here = dirname(fileURLToPath(import.meta.url))
const repoRoot = resolve(here, '..')
const SHA = /^[a-f0-9]{64}$/
const ORIGINAL_IDS = [
  'osa-v15-trailer-ru',
  'osa-v15-trailer-en',
  'osa-v15-directors-ru',
  'osa-v15-directors-en'
]
const LOCKED_FLAGS = ['publicationAuthorized', 'rightsCleared', 'paidCheckoutEnabled']
const REQUIRED_WORKSTREAMS = 'ABCDEFG'.split('')

export function readV47Sources(root = repoRoot) {
  const json = path => JSON.parse(readFileSync(resolve(root, path), 'utf8'))
  return {
    board: json('docs/OSA_CINEMA_V47_EXECUTION_BOARD.json'),
    policy: json('docs/OSA_CINEMA_V20_PRIVATE_RELEASE_POLICY.json'),
    workprints: json('docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json'),
    narrations: json('docs/OSA_CINEMA_V16_NARRATION_MANIFEST.json'),
    cinemaSource: readFileSync(resolve(root, 'src/OSACinema.tsx'), 'utf8'),
    v27Gates: EXTERNAL_GATES
  }
}

export function validateV47Packet({ board, policy, workprints, narrations, cinemaSource, v27Gates }) {
  const errors = []
  const requireValid = (condition, code) => { if (!condition) errors.push(code) }
  requireValid(board?.schemaVersion === 1 && board?.project === 'OSA CINEMA' &&
    board?.revision === 'V47_PRODUCTION_TO_PREMIERE_PROGRAM' &&
    board?.status === 'PROGRAM_PACKET_ONLY_NOT_A_FILM_RELEASE',
    'v47_is_not_a_locked_planning_packet')
  requireValid(board?.baseline?.verifiedV46Sha ===
    'f538502be933a178827fb91a9a296ed88127c461' &&
    board?.baseline?.mergedPr === 545 &&
    board?.baseline?.publicPath === '/osa-cinema' &&
    board?.baseline?.publicProduct === 'EIGHT_SCENE_EDUCATIONAL_STILL_IMAGE_EXPERIENCE' &&
    board?.baseline?.publicProductStatus === 'V46_LIVE_ACCEPTED',
    'approved_v46_baseline_changed')
  requireValid(board?.film?.type === 'FOUR_MINUTE_PRIVATE_WORKPRINT_NOT_LICENSED_FINAL_FILM' &&
    board?.film?.releaseDecision === 'NO_GO' &&
    board?.film?.sourceWorkprintsVerified === true &&
    board?.film?.finalHumanApprovedMastersVerified === false &&
    board?.film?.externalApprovalsVerified === false,
    'v47_film_readiness_misrepresented')

  requireValid(policy?.schemaVersion === 1 &&
    policy?.status === 'PRIVATE_ONLY_RELEASE_NOT_AUTHORIZED',
    'v20_private_release_policy_missing')
  for (const flag of LOCKED_FLAGS) {
    requireValid(board?.film?.[flag] === false && policy?.[flag] === false,
      'publication_or_commercial_gate_unlocked:' + flag)
  }
  requireValid(Array.isArray(policy?.assets) && policy.assets.length === 4 &&
    policy.assets.every(a => a.voiceApproved === false &&
      a.captionsApproved === false && a.rightsApproved === false &&
      a.deliveryVerified === false && SHA.test(a.originalSha256 || '')),
    'v20_per_asset_human_approval_falsified')
  requireValid(Array.isArray(policy?.mandatoryHumanDecisions) &&
    policy.mandatoryHumanDecisions.length >= 7,
    'v20_mandatory_human_decisions_removed')

  const originals = Array.isArray(workprints?.assets) ? workprints.assets : []
  requireValid(workprints?.status === 'PRIVATE_EDITORIAL_WORKPRINTS_NOT_APPROVED_FOR_PUBLICATION' &&
    originals.length === 4 && ORIGINAL_IDS.every((id, index) =>
      originals[index]?.id === id && SHA.test(originals[index]?.sha256 || '') &&
      originals[index]?.durationSeconds === (id.includes('trailer') ? 45 : 239)),
    'four_original_workprints_or_durations_mismatch')
  requireValid(JSON.stringify(board?.film?.plannedFinalEditions) === JSON.stringify([
    'osa-v15-directors-ru', 'osa-v15-directors-en',
    'osa-v15-trailer-ru', 'osa-v15-trailer-en'
  ]) && board?.film?.plannedFinalCaptionFiles === 4 &&
    board?.film?.privateNarrationGuideTracks === 6,
    'candidate_master_inventory_mismatch')
  requireValid(originals.length === 4 &&
    originals.every(o => policy?.assets?.some(a =>
      a.sourceId === o.id && a.originalSha256 === o.sha256)),
    'v20_and_v16_original_sha_mismatch')

  const voiceAssets = Array.isArray(narrations?.assets) ? narrations.assets : []
  requireValid(narrations?.status === 'PRIVATE_NARRATION_MASTERS_NOT_APPROVED_FOR_PUBLIC_RELEASE' &&
    voiceAssets.length === 6 &&
    new Set(voiceAssets.map(a => a.id)).size === 6 &&
    voiceAssets.every(a =>
      (a.locale === 'ru' || a.locale === 'en') &&
      [1, 2, 3].includes(a.act) &&
      a.rightsStatus === 'unverified' &&
      a.languageStatus === 'unverified' &&
      a.publicationStatus === 'blocked' && SHA.test(a.sha256 || '')),
    'six_original_voice_guides_misrepresented')

  const scenes = Array.isArray(board?.scenes) ? board.scenes : []
  requireValid(scenes.length === 8 && scenes.every((s, idx) =>
    s.number === idx + 1 &&
    s.act === (idx < 2 ? 1 : idx < 6 ? 2 : 3) &&
    typeof s.ruTitle === 'string' && s.ruTitle.length > 12 &&
    typeof s.enTitle === 'string' && s.enTitle.length > 12 &&
    typeof s.proposedVisualTreatment === 'string' &&
    s.treatmentStatus === 'PROPOSED_NOT_VERIFIED_AGAINST_FILM'),
    'eight_canonical_scenes_or_proposed_storyboard_changed')
  if (typeof cinemaSource !== 'string') {
    errors.push('live_cinema_source_missing')
  } else {
    // Names must really exist in the deployed eight-scene interactive source;
    // a V47 storyboard must not invent already published movie footage.
    for (const locale of ['ru', 'en']) {
      let lastOffset = -1
      for (const scene of scenes) {
        const title = locale === 'ru' ? scene.ruTitle : scene.enTitle
        const marker = "title:'" + title + "'"
        const offset = cinemaSource.indexOf(marker, lastOffset + 1)
        requireValid(offset > lastOffset && offset >= 0,
          'missing_or_reordered_live_' + locale + '_scene_' + scene.number)
        if (offset >= 0) lastOffset = offset
      }
    }
  }

  const workstreams = Array.isArray(board?.workstreams) ? board.workstreams : []
  requireValid(workstreams.length === 7 &&
    workstreams.every((w, i) => w.id === REQUIRED_WORKSTREAMS[i] &&
      (w.status?.startsWith('BLOCKED_') || w.status === 'NOT_AUTHORIZED') &&
      Array.isArray(w.references) && w.references.length > 0 &&
      typeof w.output === 'string' && w.output.length > 10),
    'unearned_completion_or_missing_production_workstream')
  const roleSet = Array.isArray(v27Gates) ? v27Gates : []
  const gateRows = Array.isArray(board?.externalGates) ? board.externalGates : []
  requireValid(roleSet.length === 8 && gateRows.length === 8 &&
    new Set(gateRows.map(g => g.id)).size === 8 &&
    roleSet.every((id, index) =>
      gateRows[index]?.id === id &&
      gateRows[index]?.status === 'HOLD_EXTERNAL_EVIDENCE_NOT_SUPPLIED' &&
      gateRows[index]?.evidenceInPublicRepo === false &&
      typeof gateRows[index]?.needed === 'string' &&
      gateRows[index]?.needed.length > 10),
    'eight_independent_v27_signoffs_missing_or_falsified')
  const banned = board?.constraints?.doNotUpload || []
  requireValid(board?.constraints?.noPublicVideo === true &&
    board?.constraints?.noCheckout === true &&
    board?.constraints?.noAutomaticGo === true &&
    Array.isArray(banned) &&
    ['private-mp4', 'private-webvtt', 'license-pdf', 'signing-private-keys']
      .every(item => banned.includes(item)),
    'private_media_security_guard_removed')
  requireValid(Array.isArray(board?.sourceOfTruth) &&
    ['docs/OSA_CINEMA_V20_PRIVATE_RELEASE_POLICY.json',
      'scripts/osa-cinema-v27-release-board.mjs']
      .every(path => board.sourceOfTruth.includes(path)),
    'historical_policy_source_of_truth_removed')

  return {
    schemaVersion: 1,
    project: 'OSA CINEMA',
    stage: 'V47_PRODUCTION_PROGRAM_CONTRACT',
    engineeringPacketVerified: errors.length === 0,
    actualFilmMasterApprovalVerified: false,
    independentlyVerifiedLegalRights: false,
    publicationAuthorized: false,
    paidCheckoutEnabled: false,
    releaseDecision: 'NO_GO',
    canonicalScenes: scenes.length,
    sourceWorkprints: originals.length,
    privateVoiceGuides: voiceAssets.length,
    productionWorkstreams: workstreams.length,
    externalGateCount: gateRows.length,
    externalGatesApproved: 0,
    errors
  }
}

export function calculateV47BoardFingerprint(board) {
  return createHash('sha256').update(JSON.stringify(board)).digest('hex')
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const sources = readV47Sources()
    const report = validateV47Packet(sources)
    report.boardFingerprintSha256 = calculateV47BoardFingerprint(sources.board)
    console.log(JSON.stringify(report, null, 2))
    if (!report.engineeringPacketVerified) process.exitCode = 1
  } catch (error) {
    console.error(JSON.stringify({
      stage: 'V47_PRODUCTION_PROGRAM_CONTRACT',
      engineeringPacketVerified: false,
      publicationAuthorized: false,
      releaseDecision: 'NO_GO',
      error: 'V47_REQUIRED_REPOSITORY_INPUT_UNAVAILABLE'
    }))
    process.exitCode = 1
  }
}
