import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
const load=(path)=>JSON.parse(readFileSync(new URL('../'+path,import.meta.url),'utf8'))
const v48=load('docs/OSA_CINEMA_V48_LOCAL_MEDIA_CANDIDATE_20261027.json')
const v20=load('docs/OSA_CINEMA_V20_PRIVATE_RELEASE_POLICY.json')
const HEX=/^[0-9a-f]{64}$/
test('V48 has exactly 4 MP4 and 4 WebVTT hashes (not fake public URLs)',()=>{
 assert.equal(v48.revision,'V48_OWNER_LOCAL_REMASTER_EVIDENCE')
 assert.equal(v48.assets.length,8)
 assert.equal(v48.assets.filter(a=>a.kind==='video').length,4)
 assert.equal(v48.assets.filter(a=>a.kind==='webvtt').length,4)
 assert.equal(new Set(v48.assets.map(a=>a.id)).size,8)
 assert.equal(new Set(v48.assets.map(a=>a.sha256)).size,8)
 for(const a of v48.assets){
  assert.match(a.id,/^osa-v48-(directors|trailer)-(ru|en)(-captions)?$/)
  assert.match(a.sha256,HEX)
  assert.ok(Number.isSafeInteger(a.bytes)&&a.bytes>100)
  assert.ok(a.path.startsWith(a.kind==='video'?'masters/':'captions/'))
  if(a.kind==='video')assert.ok(a.durationSeconds===239||a.durationSeconds===45)
  if(a.kind==='webvtt')assert.ok(a.cueCount>=8)
 }
 assert.equal(v48.localMediaAvailableInPublicGitHub,false)
 assert.equal(v48.publicVideoUrl,null)
})
test('V48 software-only packet never claims public premiere or human caption review',()=>{
 assert.equal(v48.status,'LOCAL_MEDIA_CANDIDATE_TECH_PASS_NOT_PUBLISHED')
 assert.equal(v48.releaseDecision,'NO_GO')
 assert.equal(v48.publicationAuthorized,false)
 assert.equal(v48.productionPlaybackVerified,false)
 assert.equal(v48.independentVerbatimCaptionReviewVerified,false)
 assert.equal(v48.rightsCleared,false)
 assert.equal(v48.paidCheckoutEnabled,false)
 assert.equal(v48.checks.localOriginalAVCaption,363)
 assert.equal(v48.checks.localHttpRange,61)
 assert.equal(v48.checks.chromium.status,'BLOCKED_BY_ADMINISTRATOR_NOT_PASS')
 assert.equal(v48.checks.fourCaptionReadingSpeedWarnings,4)
 assert.match(v48.sourceBaselineSha,/^[0-9a-f]{40}$/)
 assert.equal(v48.sourceBaselineSha,'a633907b06a5c7c0b0e88a81165946b1cf66ca83')
})
test('historical V20 production guard remains a hard NO_GO',()=>{
 assert.equal(v20.publicationAuthorized,false)
 assert.equal(v20.rightsCleared,false)
 assert.equal(v20.paidCheckoutEnabled,false)
 assert.equal(v20.status,'PRIVATE_ONLY_RELEASE_NOT_AUTHORIZED')
 assert.ok(v20.assets.every(a=>a.voiceApproved===false && a.captionsApproved===false && a.deliveryVerified===false))
})
