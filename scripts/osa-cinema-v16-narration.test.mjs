import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { validateNarrationManifest, narrationBlockers, auditNarrations } from './osa-cinema-v16-narration-qa.mjs'
const manifest=JSON.parse(await readFile('docs/OSA_CINEMA_V16_NARRATION_MANIFEST.json','utf8'))
test('six real registered audio editions, no fake release',()=>{
  const a=validateNarrationManifest(manifest)
  assert.equal(a.length,6)
  assert.equal(new Set(a.map(x=>x.locale+'-'+x.act)).size,6)
  assert.ok(a.every(x=>x.publicationStatus==='blocked'&&x.sha256.length===64))
  assert.ok(!JSON.stringify(a).includes('https://'))
})
test('audio stream validity cannot bypass missing speech and licensing checks',()=>{
  const a=validateNarrationManifest(manifest)[0]
  const matching={exists:true,sha256:a.sha256,sizeBytes:a.sizeBytes,durationSeconds:a.durationSeconds,codec:'mp3',channels:1,sampleRate:44100}
  assert.deepEqual(narrationBlockers(a,matching),['spoken_language_not_listening_verified','rights_and_commercial_license_missing','editorial_and_script_approval_missing','real_synced_captions_or_transcript_missing','durable_delivery_missing'])
  assert.ok(narrationBlockers(a,{...matching,sha256:'a'.repeat(64)}).includes('audio_bytes_or_hash_changed'))
  assert.ok(narrationBlockers(a,{...matching,durationSeconds:NaN}).includes('audio_stream_or_duration_mismatch'))
})
test('nonexistent user-owned MP3 cannot be treated as an approved source',async()=>{
  const r=await auditNarrations('/missing-private-osa-audio',manifest)
  assert.equal(r.summary.total,6)
  assert.equal(r.summary.technicalMatches,0)
  assert.equal(r.summary.releaseReady,0)
  assert.ok(r.assets.every(x=>x.blockers.includes('private_audio_file_missing')))
})
