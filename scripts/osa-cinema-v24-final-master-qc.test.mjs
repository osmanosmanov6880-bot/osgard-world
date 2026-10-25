import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtemp, mkdir, writeFile, copyFile, readFile, rm, symlink } from 'node:fs/promises'
import { createHash } from 'node:crypto'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { spawnSync } from 'node:child_process'
import { validateCandidatePlan, inspectFinalMasters } from './osa-cinema-v24-final-master-qc.mjs'

const sha=bytes=>createHash('sha256').update(bytes).digest('hex')
const originals={schemaVersion:1,assets:[
  {id:'osa-v15-trailer-ru',locale:'ru',edition:'trailer-workprint',sha256:'a'.repeat(64)},
  {id:'osa-v15-trailer-en',locale:'en',edition:'trailer-workprint',sha256:'b'.repeat(64)},
  {id:'osa-v15-directors-ru',locale:'ru',edition:'directors-workprint',sha256:'c'.repeat(64)},
  {id:'osa-v15-directors-en',locale:'en',edition:'directors-workprint',sha256:'d'.repeat(64)}]}
let root,plan
async function arrange(){
  root=await mkdtemp(join(tmpdir(),'osa-v24-private-'))
  await mkdir(join(root,'masters'));await mkdir(join(root,'captions'))
  const p=spawnSync('ffmpeg',['-nostdin','-hide_banner','-loglevel','error','-threads','1',
    '-f','lavfi','-i','testsrc2=s=640x360:r=10:d=1.5',
    '-f','lavfi','-i','sine=frequency=400:sample_rate=48000:duration=1.5',
    '-map','0:v:0','-map','1:a:0','-c:v','libx264','-threads','1','-preset','ultrafast','-pix_fmt','yuv420p',
    '-c:a','aac','-shortest','-movflags','+faststart','-y',join(root,'seed.mp4')],{encoding:'utf8',timeout:45000})
  assert.equal(p.status,0,p.stderr||String(p.error))
  const video=await readFile(join(root,'seed.mp4'))
  const captions=Buffer.from('WEBVTT\n\n00:00:00.000 --> 00:00:01.400\nExample caption\n','utf8')
  plan={schemaVersion:1,project:'OSA CINEMA',publicationAuthorized:false,commercialRightsCleared:false,assets:[]}
  for(const a of originals.assets){
    const masterName=a.id+'.mp4',captionName=a.id+'.vtt'
    await copyFile(join(root,'seed.mp4'),join(root,'masters',masterName))
    await writeFile(join(root,'captions',captionName),captions)
    plan.assets.push({id:a.id,locale:a.locale,edition:a.edition,sourceSha256:a.sha256,
      masterName,captionName,masterSha256:sha(video),captionSha256:sha(captions),masterBytes:video.length,
      width:640,height:360,durationSeconds:1.5,audioLanguageClaim:a.locale})
  }
}
test.before(async()=>{await arrange()})
test.after(async()=>{if(root)await rm(root,{recursive:true,force:true})})

test('V24 real FFprobe, full decode, SHA and WebVTT: four synthetic masters pass technical ONLY',async()=>{
  const r=await inspectFinalMasters(root,plan,originals)
  assert.equal(r.technical.passed,4)
  assert.equal(r.status,'TECHNICAL_CANDIDATE_READY_NOT_LICENSED')
  assert.equal(r.recordedFilmReleaseAuthorized,false)
  assert.equal(r.paidCheckoutAllowed,false)
  assert.equal(r.remainingExternalGates.length,7)
  assert.ok(r.assets.every(a=>a.mediaVerified&&a.captionVerified&&!a.humanAudioLanguageApproved))
})
test('V24 unknown source hash and repeated edition IDs fail before inspection',()=>{
  const altered=structuredClone(plan);altered.assets[0].sourceSha256='f'.repeat(64)
  assert.throws(()=>validateCandidatePlan(altered,originals),/does not match/)
  const dup=structuredClone(plan);dup.assets[1].id=dup.assets[0].id
  assert.throws(()=>validateCandidatePlan(dup,originals),/repeated/)
})
test('V24 path traversal, duplicate files and forged publish flag fail closed',()=>{
  const a=structuredClone(plan);a.assets[0].masterName='../unsafe.mp4'
  assert.throws(()=>validateCandidatePlan(a,originals),/Unsafe/)
  const b=structuredClone(plan);b.assets[0].captionName=b.assets[1].captionName
  assert.throws(()=>validateCandidatePlan(b,originals),/same private file/)
  const c=structuredClone(plan);c.publicationAuthorized=true
  assert.throws(()=>validateCandidatePlan(c,originals),/Unlicensed/)
})
test('V24 tampered MP4 bytes always fail the exact master digest',async()=>{
  const p=join(root,'masters',plan.assets[0].masterName)
  await writeFile(p,Buffer.from('This is not the original video'))
  const r=await inspectFinalMasters(root,plan,originals,{decode:false})
  assert.equal(r.technical.passed,3)
  assert.ok(r.assets[0].blockers.includes('master_byte_size_mismatch'))
  await copyFile(join(root,'seed.mp4'),p)
})
test('V24 timed WebVTT overlap is rejected even if the declared hash matches',async()=>{
  const p=join(root,'captions',plan.assets[0].captionName)
  const bad='WEBVTT\n\n00:00:00.000 --> 00:00:00.800\nFirst\n\n00:00:00.700 --> 00:00:01.200\nSecond\n'
  const x=structuredClone(plan);x.assets[0].captionSha256=sha(Buffer.from(bad))
  await writeFile(p,bad)
  const r=await inspectFinalMasters(root,x,originals,{decode:false})
  assert.ok(r.assets[0].blockers.includes('caption_webvtt_syntax_timing_or_readability_failed'))
  await writeFile(p,'WEBVTT\n\n00:00:00.000 --> 00:00:01.400\nExample caption\n')
})
test('V24 symlinked media or captions are refused, even when target SHA matches',async()=>{
  const p=join(root,'masters',plan.assets[0].masterName)
  await rm(p);await symlink(join(root,'seed.mp4'),p)
  const r=await inspectFinalMasters(root,plan,originals,{decode:false})
  assert.ok(r.assets[0].blockers.includes('master_missing_unsafe_or_oversized'))
  await rm(p);await copyFile(join(root,'seed.mp4'),p)
})
test('V24 fake human clearance fields never authorize publication',async()=>{
  const forged=structuredClone(plan)
  forged.humanRightsApproved=true;forged.publisherSigned=true
  forged.assets.forEach(a=>{a.rightsApproved=true;a.voiceApproved=true;a.captionsApproved=true})
  const r=await inspectFinalMasters(root,forged,originals,{decode:false})
  assert.equal(r.technical.passed,4)
  assert.equal(r.recordedFilmReleaseAuthorized,false)
  assert.ok(r.assets.every(a=>a.commercialRightsCleared===false&&a.publisherAuthorized===false))
})
