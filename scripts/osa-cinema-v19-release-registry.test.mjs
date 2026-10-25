import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
const get = async path => JSON.parse(await readFile(path,'utf8'))
const original = await get('docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json')
const cuts = await get('docs/OSA_CINEMA_V18_PRIVATE_SCENE_CUT_QC.json')
const mix = await get('docs/OSA_CINEMA_V18_PRIVATE_FOUR_TRACK_QA.json')
const release = await get('docs/OSA_CINEMA_V19_RELEASE_GATES.json')
const html = await readFile('tools/osa-cinema-v19-private-timeline.html','utf8')

test('V19 locked sources and measured cut map are identical to V16/V18',()=>{
  const originals = new Map(original.assets.map(a=>[a.id,a]))
  const measured = new Map(cuts.assets.map(a=>[a.id,a]))
  assert.equal(release.recordedEditions.length,4)
  assert.equal(new Set(release.recordedEditions.map(e=>e.sourceId)).size,4)
  for (const asset of release.recordedEditions) {
    const src = originals.get(asset.sourceId),cut = measured.get(asset.sourceId)
    assert.ok(src && cut,asset.sourceId)
    assert.equal(asset.expectedOriginalSha256,src.sha256)
    assert.equal(asset.locale,src.locale)
    assert.equal(asset.edition,src.edition)
    assert.equal(asset.measuredCutCount,cut.sceneCutCount)
    assert.equal(asset.publicationAuthorized,false)
    assert.equal(asset.captionIntake,'PENDING_REAL_WEBVTT')
    assert.equal(asset.spokenLanguageReview,'PENDING_HUMAN')
  }
  assert.equal(release.technicalBaseline.fourTrackPrivateMasterSha256,mix.sha256)
  assert.equal(release.technicalBaseline.privateMasterIsLicensed,false)
})

test('V19 private editor embeds measured V18 cut times rather than invented values',()=>{
  const long = html.match(/const LONG = (\[[^;]+\]);/)
  const short = html.match(/const SHORT = (\[[^;]+\]);/)
  assert.ok(long && short)
  const workprint = cuts.assets.find(a=>a.source==='ru-workprint')
  const preview = cuts.assets.find(a=>a.source==='ru-preview')
  assert.deepEqual(JSON.parse(long[1]),workprint.sceneCutTimecodes)
  assert.deepEqual(JSON.parse(short[1]),preview.sceneCutTimecodes)
})

test('V19 contract cannot be interpreted as a public recorded film release or paid item',()=>{
  assert.equal(release.recordedFilmPublicReleaseAuthorized,false)
  assert.equal(release.publicationAuthorized,false)
  assert.equal(release.paidAvailability,false)
  assert.equal(release.existingPublicProduct,'V15 interactive eight-scene educational experience only')
  assert.ok(release.mandatoryGates.length>=7)
  assert.equal(release.mandatoryGates.every(g=>g.sufficientForRelease===false),true)
  assert.ok(release.mandatoryGates.some(g=>g.id==='rights_chain' && g.status==='PENDING'))
  assert.ok(!JSON.stringify(release).includes('https://'))
  assert.equal(mix.publicationAuthorized,false)
})
