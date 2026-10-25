#!/usr/bin/env node
/**
 * W28 structurally validates ORIGINAL anonymized human pilot session records.
 * It cannot prove someone is human: independent external reviewer signs off.
 * Never stores names, emails, IPs, precise timestamps, phone IDs or uploads.
 */
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { pathToFileURL } from 'node:url'

const SHA40 = /^[a-f0-9]{40}$/
const SHA64 = /^[a-f0-9]{64}$/
const forbidden = /^(email|phone|phone_number|user_id|name|first_name|last_name|ip|ip_address|address|precise_location|gps|latitude|longitude|device_id|fingerprint|advertising_id|cookie|birthdate|timestamp|full_url)$/i
const fail = reason => { throw new Error('W28 source-bound pilot rejected: '+reason) }

export function reviewPilotSessions(sessions, expectedSource) {
  if (!SHA40.test(String(expectedSource))) fail('invalid frozen game source')
  if (!Array.isArray(sessions)) fail('pilot evidence must be individual records array')
  if (sessions.length > 50) fail('oversized research sample must be separately reviewed')
  const identifiers=new Set()
  const originalProofs=new Set()
  const platformTotals = { 'desktop':0, 'android-chrome':0, 'iphone-safari':0 }
  let explanations=0, completions=0, bypasses=0, losses=0, crashes=0
  for(const [index,session] of sessions.entries()) {
    if (!session || typeof session !== 'object' || Array.isArray(session))
      fail('bad individual session '+index)
    if (Object.keys(session).some(key=>forbidden.test(key)))
      fail('personal identifier not permitted in the pilot record '+index)
    if (Object.values(session).some(value=>typeof value==='object' && value !== null))
      fail('unstructured nested record may disclose personal data '+index)
    const id=session.anonymous_one_time_session
    if (typeof id !== 'string' || !/^[a-z0-9_-]{12,80}$/i.test(id)
        || identifiers.has(id))
      fail('missing/duplicate non-identifying one-time session handle '+index)
    identifiers.add(id)
    if (session.source_commit !== expectedSource)
      fail('pilot participant used a different game source '+index)
    if (!Object.hasOwn(platformTotals,session.platform))
      fail('unsupported browser/device source '+index)
    platformTotals[session.platform]++
    if (!Number.isInteger(session.case_scenarios_attempted) ||
        session.case_scenarios_attempted !== 3)
      fail('real tester must attempt all three distinguishable cases '+index)
    for(const bool of ['explanation_correct_in_own_words','completed_all_three_cases',
      'consent_given_to_anonymized_research','reviewer_observed_real_person',
      'source_original_evidence_reviewed']) {
      if (typeof session[bool] !== 'boolean')
        fail('unreviewed or missing explicit pilot field '+bool+' '+index)
    }
    if (session.consent_given_to_anonymized_research !== true ||
        session.reviewer_observed_real_person !== true ||
        session.source_original_evidence_reviewed !== true)
      fail('human pilot data without independent informed consent/review '+index)
    for(const field of ['interlock_bypass_count','lost_saves','blocking_device_crashes']) {
      if (!Number.isSafeInteger(session[field]) || session[field] < 0)
        fail('invalid positive-only failure counter '+field+' '+index)
    }
    const proof=session.original_gameplay_log_sha256
    if (!SHA64.test(String(proof)) || originalProofs.has(proof))
      fail('missing or reused original gameplay evidence hash '+index)
    originalProofs.add(proof)
    explanations+=Number(session.explanation_correct_in_own_words)
    completions+=Number(session.completed_all_three_cases)
    bypasses+=session.interlock_bypass_count
    losses+=session.lost_saves
    crashes+=session.blocking_device_crashes
  }
  const size=sessions.length
  return {
    schema:'OSGARD_R135_W28_HUMAN_PILOT_STRUCTURE_V1',
    source_commit:expectedSource,
    status:size>=20?'REVIEW_REQUIRED_NOT_HUMAN_CERTIFIED':'HOLD_INSUFFICIENT_REAL_BETA_SESSIONS',
    independent_volunteers:size,
    correct_safety_explanations:explanations,
    completed_all_three_cases:completions,
    interlock_bypasses:bypasses,
    lost_saves:losses,
    blocking_device_crashes:crashes,
    platform_totals:platformTotals,
    original_session_records_reviewed:size>=20,
    reviewer_confirms_real_humans:size>=20,
    human_test_authenticity_certified_by_software:false,
    note:'This validates data structure and source only. Booleans and hashes are not cryptographic proof of real human volunteers; independent human review is mandatory.'
  }
}

function main() {
  const [source,filename]=process.argv.slice(2)
  if(!source || !filename) {
    console.error('Usage: node scripts/r135-w28-pilot-evidence.mjs FROZEN_SOURCE_SHA40 ANONYMIZED_ORIGINAL_SESSIONS.json')
    process.exitCode=2
    return
  }
  const input=JSON.parse(readFileSync(resolve(filename),'utf8'))
  const result=reviewPilotSessions(input.sessions,source)
  console.log(JSON.stringify(result,null,2))
  if(result.status !== 'REVIEW_REQUIRED_NOT_HUMAN_CERTIFIED')process.exitCode=3
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href)main()
