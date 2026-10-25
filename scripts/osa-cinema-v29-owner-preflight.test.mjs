import { test } from 'node:test'
import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { spawnSync } from 'node:child_process'
import { mkdtemp, mkdir, readFile, writeFile, readdir, rm, stat } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { buildPrivateCandidatePlan } from './osa-cinema-v28-final-intake.mjs'
import { runOwnerPreflight, assertPinnedCandidates } from './osa-cinema-v29-owner-preflight.mjs'

const sha = bytes => createHash('sha256').update(bytes).digest('hex')
const originalsPath = 'docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json'
const ffmpeg = (file, frequency) => {
  const r=spawnSync('ffmpeg',['-nostdin','-hide_banner','-loglevel','error',
    '-filter_threads','1','-f','lavfi','-i','testsrc2=s=640x360:r=10:d=1.5',
    '-f','lavfi','-i',`sine=frequency=${frequency}:sample_rate=48000:duration=1.5`,
    '-map','0:v:0','-map','1:a:0','-c:v','libx264','-threads','1',
    '-preset','ultrafast','-pix_fmt','yuv420p','-c:a','aac',
    '-shortest','-movflags','+faststart','-y',file],{encoding:'utf8',timeout:60000})
  assert.equal(r.status,0,r.error?.message||r.stderr)
}

test('V29 integrated owner-side real-byte QA, four MP4 + VTT, private auth and NO-GO', { timeout: 240000 }, async t => {
  const temp=await mkdtemp(join(tmpdir(),'osa-v29-owner-'))
  const root=join(temp,'private'),masters=join(root,'masters'),captions=join(root,'captions')
  const rightsDir=join(root,'rights')
  const originals=JSON.parse(await readFile(originalsPath,'utf8'))
  try {
    await mkdir(masters,{recursive:true});await mkdir(captions);await mkdir(rightsDir)
    for (const [i,a] of originals.assets.entries()) {
      ffmpeg(join(masters,a.id+'.mp4'),440+i*100)
      await writeFile(join(captions,a.id+'.vtt'),`WEBVTT\n\n00:00:00.000 --> 00:00:01.400\nPrivate candidate ${i+1}\n`)
    }

    const baseline=await buildPrivateCandidatePlan(root,originals)
    await t.test('first intake verifies 4 decoded movies and 4 full hashed HTTP streams; never publishes',async()=>{
      const out=join(temp,'reports','first')
      const r=await runOwnerPreflight({root,originals:originalsPath,outputDir:out})
      assert.equal(r.summary.result,'NO_GO')
      assert.equal(r.summary.technical.mastersPassed,4)
      assert.equal(r.summary.technical.privateHttpPassed,4)
      assert.equal(r.summary.technical.evidenceTechnicallyComplete,false)
      assert.equal(r.summary.publicationAuthorized,false)
      assert.equal(r.summary.paidCheckoutEnabled,false)
      assert.equal(r.summary.productionDeploymentPerformed,false)
      assert.equal(r.summary.independentExternalAuthorizationsOutstanding.length,8)
      assert.ok(r.summary.blockers.includes('rights_usage_manifest_and_real_document_ledger_missing'))
      assert.ok(r.summary.blockers.includes('frozen_exact_candidate_manifest_missing'))
      assert.deepEqual(r.files.sort(),['V24_MEDIA_QA.json','V26_PRIVATE_DELIVERY_QA.json','V28_CANDIDATE_MANIFEST.json','V29_OWNER_PREFLIGHT_NO_GO.json','CHECKSUMS.sha256'].sort())
      const receipts=JSON.parse(await readFile(join(out,'V26_PRIVATE_DELIVERY_QA.json'),'utf8'))
      assert.equal(receipts.length,4)
      assert.ok(receipts.every(x=>x.fullContentVerified&&x.tests.fullGet.status===200&&x.tests.invalidRange===416))
      assert.ok(receipts.every(x=>x.publicationAuthorized===false&&x.paidCheckoutEnabled===false))
      const checks=await readFile(join(out,'CHECKSUMS.sha256'),'utf8')
      assert.equal(checks.trim().split('\n').length,4)
      for(const line of checks.trim().split('\n')){
        const [,digest,filename]=/^(\w{64})  (.+)$/.exec(line)||[]
        assert.ok(filename&&digest,'Every report has an exact digest')
        assert.equal(sha(await readFile(join(out,filename))),digest)
      }
      const file=join(out,'V29_OWNER_PREFLIGHT_NO_GO.json'),data=await readFile(file,'utf8')
      assert.equal((await stat(file)).mode&0o777,0o600)
      assert.ok(!data.includes('osa_private_session='),'Never persist the private session')
      assert.ok(!data.includes('http://127.0.0.1:'),'Never persist local session address')
      await assert.rejects(runOwnerPreflight({root,originals:originalsPath,outputDir:join(root,'unsafe-inside')}),/outside private media folder/)
      await assert.rejects(readdir(join(root,'unsafe-inside')),/ENOENT/)
    })

    await t.test('with frozen hashes and four synthetic PDF receipts: all technical checks pass but legal GO still denied',async()=>{
      const frozen=join(temp,'frozen.json'),usagePath=join(temp,'usage.json')
      await writeFile(frozen,JSON.stringify(baseline))
      const usage={schemaVersion:1,project:'OSA CINEMA',releaseAuthorized:false,editions:[],sources:[]}
      for (const [i,asset] of baseline.assets.entries()) {
        const id='synthetic-source-'+(i+1),evidence=Buffer.from(`%PDF-1.7\nSYNTHETIC DOCUMENT ${i}; NOT A LICENSE OR RIGHT TO PUBLISH\n%%EOF`)
        const file=`synthetic_receipt_${i+1}.pdf`
        await writeFile(join(rightsDir,file),evidence)
        usage.editions.push({finalId:asset.id,finalSha256:asset.masterSha256,sourceIds:[id]})
        usage.sources.push({id,type:'video',sourceSha256:sha(`synthetic input ${i}`),evidenceFile:file,
          evidenceSha256:sha(evidence),commercialRightsApproved:false,evidenceHumanReviewed:false})
      }
      await writeFile(usagePath,JSON.stringify(usage))
      const out=join(temp,'reports','pinned')
      const r=await runOwnerPreflight({root,originals:originalsPath,outputDir:out,rightsUsage:usagePath,pinnedPlan:frozen})
      assert.equal(r.summary.result,'NO_GO')
      assert.equal(r.summary.candidatePinnedToPreviousHash,true)
      assert.equal(r.summary.technical.evidenceDocumentsVerified,4)
      assert.equal(r.summary.technical.evidenceTechnicallyComplete,true)
      const board=JSON.parse(await readFile(join(out,'V27_FINAL_NO_GO_BOARD.json'),'utf8'))
      assert.equal(board.technicalCandidateEvidenceComplete,true)
      assert.equal(board.result,'NO_GO')
      assert.equal(board.publicFilmPublicationAuthorized,false)
      assert.equal(board.paidCheckoutEnabled,false)
      const rights=JSON.parse(await readFile(join(out,'V25_RIGHTS_BYTES_QA.json'),'utf8'))
      assert.equal(rights.independentLegalSignoffPresent,false)
      assert.equal(rights.rightsCleared,false)
      assert.ok(r.summary.blockers.includes('publisher_signed_authorization_for_exact_release_hash'))
    })

    await t.test('frozen manifest rejects swapped WebVTT while preserving old evidence, no new output',async()=>{
      const expected=join(temp,'frozen-original.json'),out=join(temp,'reports','tampered')
      await writeFile(expected,JSON.stringify(baseline))
      const file=join(captions,originals.assets[0].id+'.vtt')
      await writeFile(file,'WEBVTT\n\n00:00:00.000 --> 00:00:01.400\nChanged but still valid\n')
      await assert.rejects(
        runOwnerPreflight({root,originals:originalsPath,outputDir:out,pinnedPlan:expected}),
        /Frozen release candidate differs/)
      await assert.rejects(readdir(out),/ENOENT/)
    })

    await t.test('tampered candidate identity cannot pass pinning in isolation',()=>{
      const forged=structuredClone(baseline)
      forged.assets[0].masterSha256='0'.repeat(64)
      assert.throws(()=>assertPinnedCandidates(baseline,forged),/Frozen release candidate differs/)
      const illegal=structuredClone(baseline);illegal.publicationAuthorized=true
      assert.throws(()=>assertPinnedCandidates(baseline,illegal),/falsely approved/)
    })
  } finally {await rm(temp,{recursive:true,force:true})}
})
