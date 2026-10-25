import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { validateManifest, isDurablePublicationUrl, parseVtt, releaseBlockers, evaluate } from './osa-cinema-v16-workprint-qa.mjs'
const manifest=JSON.parse(await readFile('docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json','utf8'))

test('exact four workprints, trusted hashes and no public URLs',()=>{
  const assets=validateManifest(manifest)
  assert.equal(assets.length,4)
  assert.equal(new Set(assets.map(x=>x.edition+':'+x.locale)).size,4)
  assert.ok(assets.every(x=>x.sha256.length===64 && x.sizeBytes>4000000))
  assert.equal(manifest.status,'PRIVATE_EDITORIAL_WORKPRINTS_NOT_APPROVED_FOR_PUBLICATION')
  assert.ok(!JSON.stringify(manifest).match(/_jwt=|https:\/\/dnznrvs/i))
})

test('no permanent URL loopholes',()=>{
  for(const val of ['https://example.com/trailer.mp4?token=secret','https://cdn.cloudfront.net/movie.mp4','http://x.test/movie.mp4','//evil.test/a','/osa-library/media/../secret.mp4','/osa-library/media/a.mp4?expires=6','https://runwayml.com/m.mp4','https://cdn.com/f.mp4#private'])assert.equal(isDurablePublicationUrl(val),false,val)
  assert.equal(isDurablePublicationUrl('/osa-library/media/approved/scene-01.mp4'),true)
  assert.equal(isDurablePublicationUrl('https://cinema.example.org/scene-01.mp4'),true)
})

test('VTT parser requires actual non-empty ordered cues within runtime',()=>{
  assert.equal(parseVtt('WEBVTT\n\n00:00:00.000 --> 00:00:01.400\nHello world\n',45).valid,true)
  assert.equal(parseVtt('WEBVTT\n\n',45).valid,false)
  assert.equal(parseVtt('WEBVTT\n\n00:00:48.000 --> 00:00:55.000\nLate cue\n',45).valid,false)
  assert.equal(parseVtt('WEBVTT\n\n00:00:00.000 --> 00:00:02.000\nOne\n\n00:00:01.500 --> 00:00:03.000\nTwo\n',45).valid,false)
  assert.equal(parseVtt('Not VTT',45).valid,false)
})

test('correct original bytes do not imply legal or language approval',()=>{
  const a=validateManifest(manifest)[0]
  const probe={exists:true,sha256:a.sha256,sizeBytes:a.sizeBytes,durationSeconds:a.durationSeconds,width:a.width,height:a.height,videoCodec:'h264',audioCodec:'aac',audioLanguageTag:'und'}
  const blockers=releaseBlockers(a,probe,{},{valid:false},{})
  assert.deepEqual(blockers,['rights_evidence_not_verified','final_cut_not_approved','language_audio_not_reviewed','approved_synced_captions_missing','durable_delivery_not_verified'])
  const overlyOptimistic=releaseBlockers(a,probe,{rightsStatus:'cleared',editorialStatus:'approved',audioLanguageStatus:'verified',verifiedAudioLocale:a.locale,captionsStatus:'approved',deliveryUrl:'/osa-library/media/test.mp4',deliveryVerified:true},{valid:true,cues:10},{rights:false,editorial:false,audio:false,captions:false})
  assert.ok(overlyOptimistic.includes('rights_evidence_not_verified'))
  assert.ok(overlyOptimistic.includes('final_cut_not_approved'))
  assert.ok(overlyOptimistic.includes('approved_synced_captions_missing'))
})

test('missing masters remain blocked but ordinary audit exits honestly',async()=>{
  const report=await evaluate('/empty-osa-v16-nonexistent',manifest)
  assert.equal(report.summary.total,4)
  assert.equal(report.summary.ready,0)
  assert.ok(report.assets.every(x=>x.blockers.includes('master_file_missing')))
})
