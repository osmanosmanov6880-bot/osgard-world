#!/usr/bin/env node
import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { reviewPilotSessions } from './r135-w28-pilot-evidence.mjs'

const source='a'.repeat(40)
const fake=(i)=>({
  anonymous_one_time_session:'synthetic_'+String(i).padStart(5,'0'),
  source_commit:source,
  platform:i%3===0?'desktop':i%3===1?'android-chrome':'iphone-safari',
  case_scenarios_attempted:3,
  explanation_correct_in_own_words:i<16,
  completed_all_three_cases:i<17,
  consent_given_to_anonymized_research:true,
  reviewer_observed_real_person:true, // fixture only; NOT a real attestation
  source_original_evidence_reviewed:true, // fixture only
  interlock_bypass_count:0,
  lost_saves:0,
  blocking_device_crashes:0,
  original_gameplay_log_sha256:createHash('sha256').update('SYNTHETIC_ONLY_'+i).digest('hex')
})
let count=0
const fixture=Array.from({length:20},(_,i)=>fake(i))
let result=reviewPilotSessions(fixture,source)
assert.equal(result.independent_volunteers,20)
assert.equal(result.correct_safety_explanations,16)
assert.equal(result.status,'REVIEW_REQUIRED_NOT_HUMAN_CERTIFIED')
assert.equal(result.human_test_authenticity_certified_by_software,false)
count+=4
const reject=(records,pattern)=>{assert.throws(()=>reviewPilotSessions(records,source),new RegExp(pattern));count++}
reject([fake(1),fake(1)],'duplicate')
reject([{...fake(0),source_commit:'b'.repeat(40)}],'different')
reject([{...fake(0),email:'person@example.com'}],'personal')
reject([{...fake(0),device_id:'ABC'}],'personal')
reject([{...fake(0),full_url:'https://example.com?token=secret'}],'personal')
reject([{...fake(0),case_scenarios_attempted:2}],'three')
reject([{...fake(0),consent_given_to_anonymized_research:false}],'consent')
reject([{...fake(0),original_gameplay_log_sha256:'invalid'}],'original')
reject([{...fake(0),interlock_bypass_count:-1}],'counter')
reject([{...fake(0),platform:'synthetic-phone'}],'browser')
reject([{...fake(0),scenario_details:{phone:'private'}}],'nested')
reject(Array.from({length:51},(_,i)=>fake(i)),'oversized')
const small=reviewPilotSessions(fixture.slice(0,19),source)
assert.equal(small.status,'HOLD_INSUFFICIENT_REAL_BETA_SESSIONS');count++
const blocked=reviewPilotSessions([...fixture.slice(0,19),
 {...fake(19),lost_saves:1}],source)
assert.equal(blocked.lost_saves,1);count++
console.log('W28 structurally source-pinned pilot SAFE PASS:',count,
  'synthetic test cases; no real humans, no personal IDs, no automatic release')
