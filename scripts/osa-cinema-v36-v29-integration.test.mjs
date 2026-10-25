import { test } from 'node:test'
import { mkdtemp, mkdir, readFile, writeFile, rm, realpath } from 'node:fs/promises'
import { spawnSync } from 'node:child_process'
import { createHash } from 'node:crypto'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import assert from 'node:assert/strict'
import { buildPrivateCandidatePlan } from './osa-cinema-v28-final-intake.mjs'
import { runOwnerPreflight } from './osa-cinema-v29-owner-preflight.mjs'
import { verifyPrivateReceiptDirectory } from './osa-cinema-v36-verify-private-receipts.mjs'
const sha=b=>createHash('sha256').update(b).digest('hex')
const manifest=new URL('../docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json',import.meta.url)
test('V36 genuinely interoperates with V29 using synthetic files only, never licenses anything', {timeout:240000}, async()=>{
const originals=JSON.parse(await readFile(manifest,'utf8'))
const tmp=await mkdtemp(join(await realpath(tmpdir()),'osa-v36-v29-real-mp4-synthetic-'))
const root=join(tmp,'media'),masters=join(root,'masters'),captions=join(root,'captions'),rightsDir=join(root,'rights')
try{
  await mkdir(masters,{recursive:true,mode:0o700});await mkdir(captions,{mode:0o700});await mkdir(rightsDir,{mode:0o700})
  for(const [i,a] of originals.assets.entries()) {
    const file=join(masters,a.id+'.mp4')
    const p=spawnSync('ffmpeg',['-nostdin','-hide_banner','-loglevel','error','-filter_threads','1',
      '-f','lavfi','-i','testsrc2=s=640x360:r=10:d=1.5','-f','lavfi','-i',`sine=frequency=${440+i*100}:sample_rate=48000:duration=1.5`,
      '-map','0:v:0','-map','1:a:0','-c:v','libx264','-threads','1','-preset','ultrafast','-pix_fmt','yuv420p',
      '-c:a','aac','-shortest','-movflags','+faststart','-y',file],{encoding:'utf8',timeout:60000,maxBuffer:600000})
    assert.equal(p.status,0,p.stderr||String(p.error))
    await writeFile(join(captions,a.id+'.vtt'),`WEBVTT\n\n00:00:00.000 --> 00:00:01.400\nSynthetic only ${i+1}\n`,{mode:0o600})
  }
  const baseline=await buildPrivateCandidatePlan(root,originals)
  const out1=join(tmp,'reports','without-rights')
  const v29a=await runOwnerPreflight({root,originals:manifest,outputDir:out1})
  const verifiedA=await verifyPrivateReceiptDirectory({directory:out1})
  assert.equal(verifiedA.receiptRecordsValidated,4)
  assert.equal(verifiedA.decision,'NO_GO')
  assert.equal(v29a.summary.result,'NO_GO')
  const frozen=join(tmp,'pinned.json'),usage=join(tmp,'usage.json')
  await writeFile(frozen,JSON.stringify(baseline),{mode:0o600})
  const rightsManifest={schemaVersion:1,project:'OSA CINEMA',releaseAuthorized:false,editions:[],sources:[]}
  for(const [i,a] of baseline.assets.entries()) {
    const id='synthetic-source-'+(i+1),evidence=Buffer.from(`%PDF-1.7\nSYNTHETIC TEST ${i} NOT A LEGAL LICENSE\n%%EOF`),filename=`synthetic_receipt_${i+1}.pdf`
    await writeFile(join(rightsDir,filename),evidence,{mode:0o600})
    rightsManifest.editions.push({finalId:a.id,finalSha256:a.masterSha256,sourceIds:[id]})
    rightsManifest.sources.push({id,type:'video',sourceSha256:sha(`synthetic input ${i}`),evidenceFile:filename,
      evidenceSha256:sha(evidence),commercialRightsApproved:false,evidenceHumanReviewed:false})
  }
  await writeFile(usage,JSON.stringify(rightsManifest),{mode:0o600})
  const out2=join(tmp,'reports','with-test-evidence')
  const v29b=await runOwnerPreflight({root,originals:manifest,outputDir:out2,rightsUsage:usage,pinnedPlan:frozen})
  const verifiedB=await verifyPrivateReceiptDirectory({directory:out2})
  assert.equal(verifiedB.receiptRecordsValidated,6)
  assert.equal(verifiedB.decision,'NO_GO')
  assert.equal(v29b.summary.result,'NO_GO')
  console.log(JSON.stringify({syntheticOnly:true,realFFmpegAndFFprobeUsed:true,
    fourSyntheticMP4sFourSyntheticVTTs:true,withoutRights:verifiedA,
    withSyntheticPDFReceipts:verifiedB},null,2))
} finally { await rm(tmp,{recursive:true,force:true}) }
})