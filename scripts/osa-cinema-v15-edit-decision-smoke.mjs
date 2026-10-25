import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const base = 'public/osa-library/'
const edl = JSON.parse(readFileSync(base + 'osa-cinema-v15-edit-decision-list.json', 'utf8'))
const csv = readFileSync(base + 'media-inventory.csv', 'utf8')
const sceneComponent = readFileSync('src/OSACinema.tsx','utf8')
const lessonRegistry = readFileSync('src/osaLessonRegistry.ts', 'utf8')
const mediaCatalog = readFileSync('src/osaMediaCatalog.ts','utf8')

function splitCsvRow(line) {
  let current='', quoting=false
  const cells=[]
  for(let i=0;i<line.length;i++) {
    const ch=line[i]
    if(ch==='"') {
      if(quoting && line[i+1]==='"'){current+='"';i++}
      else quoting=!quoting
    } else if(ch===',' && !quoting) {cells.push(current);current=''}
    else current+=ch
  }
  cells.push(current)
  assert.equal(quoting,false,'Malformed quoted CSV line')
  return cells
}
const lines=csv.trim().split(/\r?\n/)
const headers=splitCsvRow(lines.shift())
const entries=lines.map(line=>Object.fromEntries(headers.map((key,i)=>[key,splitCsvRow(line)[i]??''])))
const assets=new Map(entries.map(row=>[row.asset_id,row]))
assert.equal(assets.size,entries.length,'Every source media asset id must be unique')
const expectedSlugs=[
  'intelligence-and-imitation','how-language-models-work','power-of-knowledge','signal-and-noise',
  'verify-an-ai-answer','privacy-before-prompting','human-in-the-loop','investigate-the-future'
]
assert.equal(edl.schemaVersion,1)
assert.equal(edl.sourceOfTruth,base+'media-inventory.csv')
assert.equal(edl.courseSceneCount,8)
assert.deepEqual(edl.scenes.map(x=>x.slug),expectedSlugs,'EDL must match the real eight-scene order')
assert.equal(edl.publicationGate.ready,false,'Unapproved source clips may not be published automatically')
assert.equal(edl.releaseStatus,'EDITORIAL_DRAFT_NO_PLAYABLE_SOURCES')
assert.ok(edl.policies.requireRightsClearance && edl.policies.requireSHA256 && edl.policies.requireMeasuredTimecodes)
assert.ok(!edl.policies.shortLivedSignedLinks)
assert.ok(!/https?:\/\/|_jwt|signature=/i.test(JSON.stringify(edl)), 'Do not store ephemeral media URLs')
let videos=0
for (const [index,scene] of edl.scenes.entries()) {
  assert.equal(scene.index,index)
  assert.ok(lessonRegistry.includes(scene.slug),'Unknown canonical lesson slug: '+scene.slug)
  assert.ok(scene.title?.ru?.length>8 && scene.title?.en?.length>8)
  assert.ok(scene.candidateShots.length>=2,'Need edit alternatives for every chapter')
  const unique=new Set()
  for (const shot of scene.candidateShots) {
    assert.equal(shot.order,unique.size+1)
    assert.ok(!unique.has(shot.assetId),'Repeated shot within one chapter')
    unique.add(shot.assetId)
    const source=assets.get(shot.assetId)
    assert.ok(source,'EDL references missing source: '+shot.assetId)
    assert.equal(source.kind,'video','Video shot mapped to non-video asset')
    assert.equal(source.slug,shot.inventorySlug)
    assert.equal(shot.reviewStatus,'PENDING_ORIGINAL_EXPORT_AND_RIGHTS_QC')
    assert.equal(shot.finalIncluded,false)
    assert.equal(shot.rightsApproved,false)
    assert.equal(shot.visualQC,false)
    assert.equal(shot.verifiedDurationSeconds,null,'Never invent the actual duration of Runway clips')
    assert.equal(shot.inPointSeconds,null)
    assert.equal(shot.outPointSeconds,null)
    videos++
  }
  for (const locale of ['ru','en']) {
    assert.equal(scene.narration[locale].status,'UNRECORDED')
    assert.equal(scene.captionTracks[locale],null)
  }
  assert.equal(scene.masterVideo.status,'UNRECORDED')
  assert.equal(scene.educationalAccuracyQC,false)
}
for(const asset of [...edl.musicCandidates,...edl.voiceCandidates]) {
  const source=assets.get(asset.assetId)
  assert.ok(source,'Unknown candidate audio id: '+asset.assetId)
  assert.equal(source.kind,'audio')
  assert.equal(source.slug,asset.inventorySlug)
  assert.equal(source.rights_status,'unverified')
  assert.equal(source.publication_status,'blocked')
}
assert.ok(sceneComponent.includes("getOSACinemaMedia(index,locale,'video')"))
assert.ok(mediaCatalog.includes('src: null'),'The recorded film is not yet approved: keep media sources unpublished')
assert.ok(edl.scenes.every(x=>x.masterVideo.file===null && x.masterVideo.sha256===null))
assert.equal(edl.publicationGate.approvedPermanentLinks,0)
console.log('OSA_CINEMA_V15_EDL_PASS: 8 canonical scenes, '+videos+' tracked existing video candidates, 4 audio candidates, no signed URLs, no false published-media claims')
