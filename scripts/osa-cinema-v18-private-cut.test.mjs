import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const data = async path => JSON.parse(await readFile(path, 'utf8'))
const scene = await data('docs/OSA_CINEMA_V18_PRIVATE_SCENE_CUT_QC.json')
const four = await data('docs/OSA_CINEMA_V18_PRIVATE_FOUR_TRACK_QA.json')
const original = await data('docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json')
const origMap = new Map(original.assets.map(asset => [asset.id, asset]))

test('V18 four real sources have exact original MP4 SHA and truthful edition', () => {
  assert.equal(scene.assets.length, 4)
  assert.equal(scene.publicationAuthorized, false)
  const ids = new Set()
  for (const row of scene.assets) {
    assert.ok(!ids.has(row.id), 'Duplicate video source identity')
    ids.add(row.id)
    assert.equal(row.originalSha256, origMap.get(row.id)?.sha256)
    assert.equal(row.originalBytes, origMap.get(row.id)?.sizeBytes)
    assert.equal(row.locale, origMap.get(row.id)?.locale)
    assert.equal(row.publicationAuthorized, false)
    assert.equal(row.sceneCutTimecodes.length, row.sceneCutCount)
    assert.equal(row.shots.length, row.sceneCutCount + 1)
  }
})

test('RU/EN workprint and preview 64/10 scene cut positions genuinely align', () => {
  const by = Object.fromEntries(scene.assets.map(a => [a.source, a]))
  assert.equal(by['ru-workprint'].sceneCutCount, 64)
  assert.equal(by['en-workprint'].sceneCutCount, 64)
  assert.equal(by['ru-preview'].sceneCutCount, 10)
  assert.equal(by['en-preview'].sceneCutCount, 10)
  for (const [a,b] of [['ru-workprint','en-workprint'],['ru-preview','en-preview']]) {
    assert.deepEqual(by[a].sceneCutTimecodes, by[b].sceneCutTimecodes)
  }
  assert.equal(scene.cutSync.workprintsMatchedWithin60ms, true)
  assert.equal(scene.cutSync.previewsMatchedWithin60ms, true)
  for (const t of [5,79,157]) {
    assert.ok(by['ru-workprint'].sceneCutTimecodes.some(x => Math.abs(x-t) < .06),'Proposed act entry is not an observed cut')
  }
  assert.ok(by['ru-workprint'].shots.every(s => s.durationSeconds > 0))
  assert.ok(Math.abs(by['ru-workprint'].shots.at(-1).endSeconds-239) < .05)
})

test('Real private four-track master has genuine bitstream identities and safe draft mix', () => {
  assert.equal(four.publicationAuthorized, false)
  assert.equal(four.file, 'OSA_CINEMA_V18_PRIVATE_FOUR_TRACK_EDITORIAL_239S.mp4')
  assert.equal(four.sha256.length, 64)
  assert.ok(four.sizeBytes > 130_000_000)
  assert.ok(Math.abs(four.durationSeconds - 239) < .1)
  assert.equal(four.picture.codec, 'h264')
  assert.equal(four.picture.width, 1920)
  assert.equal(four.picture.height, 1080)
  assert.equal(four.originalPictureAndBothOriginalSoundtracksBitstreamSha256Match, true)
  assert.equal(four.verifiedOutputDecodedAllFiveStreamsWithoutErrors, true)
  assert.equal(four.audioTracks.length, 4)
  assert.deepEqual(four.audioTracks.map(a => a.codec), ['aac','aac','aac','aac'])
  assert.deepEqual(four.audioTracks.map(a => a.isDefault), [true,false,false,false])
  for (const a of four.audioTracks.slice(2)) {
    assert.ok(a.integratedLufs > -20 && a.integratedLufs < -10)
    assert.ok(a.truePeakDbtp <= -1)
  }
})

test('Measured private media can never be interpreted as cleared public film', async () => {
  assert.equal(four.rightsCleared, false)
  assert.equal(four.finalMixApproved, false)
  assert.equal(four.actualVoiceLanguagesApproved, false)
  assert.equal(four.syncedCaptionsApproved, false)
  assert.equal(four.durablePublicUrlsPresent, false)
  assert.ok(!JSON.stringify(four).includes('https://'))
  assert.ok(!JSON.stringify(scene).includes('https://'))
  const edl = await readFile('docs/OSA_CINEMA_V18_PRIVATE_EDL_SUMMARY.md','utf8')
  assert.ok(edl.includes('65 shots') && edl.includes('11 shots'))
  assert.ok(edl.includes('not an artistic assessment') || edl.includes('not final edit approvals'))
})
