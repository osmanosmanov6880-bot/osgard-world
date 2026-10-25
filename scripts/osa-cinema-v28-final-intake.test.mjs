import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtemp,mkdir,readdir,readFile,writeFile,rm,rename,symlink,copyFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { spawnSync } from 'node:child_process'
import { buildPrivateCandidatePlan, makePlanFromFiles, validateCanonical } from './osa-cinema-v28-final-intake.mjs'
import { inspectFinalMasters } from './osa-cinema-v24-final-master-qc.mjs'

const V16='docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json'
const ffmpeg=(file,frequency)=>{
  const r=spawnSync('ffmpeg',['-nostdin','-hide_banner','-loglevel','error','-filter_threads','1',
    '-f','lavfi','-i','testsrc2=s=640x360:r=10:d=1.5',
    '-f','lavfi','-i',`sine=frequency=${frequency}:sample_rate=48000:duration=1.5`,
    '-map','0:v:0','-map','1:a:0','-c:v','libx264','-threads','1',
    '-preset','ultrafast','-pix_fmt','yuv420p','-c:a','aac','-shortest','-movflags','+faststart','-y',file],
  {encoding:'utf8',timeout:60000,maxBuffer:500000})
  assert.equal(r.status,0,r.error?.message||r.stderr)
}

test('V28 exact-four owner-side MP4/WebVTT technical intake, NO publication',async t=>{
  const root=await mkdtemp(join(tmpdir(),'osa-v28-intake-'))
  const source=join(root,'private'), masters=join(source,'masters'), captions=join(source,'captions')
  const originals=JSON.parse(await readFile(V16,'utf8'))
  await mkdir(masters,{recursive:true});await mkdir(captions)
  try{
    assert.equal(validateCanonical(originals).length,4)
    for(const [i,a] of originals.assets.entries()){
      ffmpeg(join(masters,a.id+'.mp4'),330+i*130)
      await writeFile(join(captions,a.id+'.vtt'),`WEBVTT\n\n00:00:00.000 --> 00:00:01.400\nSample ${i+1}\n`)
    }
    const plan=await buildPrivateCandidatePlan(source,originals)
    await t.test('real FFprobe derives four correct source-bound candidates without approval',()=>{
      assert.equal(plan.assets.length,4)
      assert.equal(plan.publicationAuthorized,false)
      assert.equal(plan.commercialRightsCleared,false)
      assert.ok(plan.assets.every(a=>a.width===640&&a.height===360&&a.masterBytes>1000&&a.sourceSha256.length===64))
      assert.equal(new Set(plan.assets.map(a=>a.masterSha256)).size,4)
    })
    await t.test('V24 reads the generated manifest and actually decodes all four MP4s',async()=>{
      const qc=await inspectFinalMasters(source,plan,originals)
      assert.equal(qc.technical.passed,4)
      assert.equal(qc.recordedFilmReleaseAuthorized,false)
      assert.equal(qc.paidCheckoutAllowed,false)
    })
    await t.test('writes a private manifest outside media directory with exclusive creation',async()=>{
      const target=join(root,'report','candidate.json')
      const result=await makePlanFromFiles({root:source,originals:V16,out:target})
      const saved=JSON.parse(await readFile(target,'utf8'))
      assert.deepEqual(saved,result)
      await assert.rejects(makePlanFromFiles({root:source,originals:V16,out:target}),/EEXIST/)
      await assert.rejects(makePlanFromFiles({root:source,originals:V16,out:join(source,'inside.json')}),/outside/)
    })
    await t.test('rejects a swapped symbolic-link MP4',async()=>{
      const x=join(masters,originals.assets[0].id+'.mp4'),renamed=join(root,'backed-original.mp4')
      await rename(x,renamed);await symlink(renamed,x)
      try{await assert.rejects(buildPrivateCandidatePlan(source,originals),/symlinked/)}finally{await rm(x);await rename(renamed,x)}
    })
    await t.test('rejects altered real VTT timing and then recovers',async()=>{
      const x=join(captions,originals.assets[0].id+'.vtt'),original=await readFile(x)
      await writeFile(x,'WEBVTT\n\n00:00:00.000 --> 00:00:55.000\nInvalid\n')
      try{await assert.rejects(buildPrivateCandidatePlan(source,originals),/Caption syntax/)}finally{await writeFile(x,original)}
    })
    await t.test('rejects extra and missing input files rather than silently ignoring material',async()=>{
      const unexpected=join(masters,'unregistered.mp4')
      await writeFile(unexpected,'UNAPPROVED')
      try{await assert.rejects(buildPrivateCandidatePlan(source,originals),/exactly the four/)}finally{await rm(unexpected)}
      const x=join(captions,originals.assets[1].id+'.vtt'),moved=x+'.bak'
      await rename(x,moved)
      try{await assert.rejects(buildPrivateCandidatePlan(source,originals),/exactly the four/)}finally{await rename(moved,x)}
    })
    await t.test('rejects forged source identity or false canonical coverage',async()=>{
      const forged=structuredClone(originals)
      forged.assets[0].sha256='not-a-sha256'
      assert.throws(()=>validateCanonical(forged),/Invalid or duplicate/)
      forged.assets[0].sha256=originals.assets[0].sha256
      forged.assets[0].id=forged.assets[1].id
      assert.throws(()=>validateCanonical(forged),/Invalid or duplicate/)
    })
  } finally {await rm(root,{recursive:true,force:true})}
})
