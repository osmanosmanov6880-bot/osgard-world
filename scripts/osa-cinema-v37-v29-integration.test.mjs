import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtemp, mkdir, readFile, writeFile, chmod, rm, realpath } from 'node:fs/promises'
import { spawnSync } from 'node:child_process'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { runOwnerPreflight } from './osa-cinema-v29-owner-preflight.mjs'
import { verifyPrivateMediaBytes } from './osa-cinema-v37-verify-private-media.mjs'

const originalManifest = new URL('../docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json',import.meta.url)
const ffmpeg=(args)=>spawnSync('ffmpeg',args,{encoding:'utf8',timeout:60000,maxBuffer:1_000_000})

test('V37 real V29 integration: 4 synthetic playable MP4+VTT are byte checked, never public',
  {timeout:240000},async()=>{
    const original=JSON.parse(await readFile(originalManifest,'utf8'))
    const root=await mkdtemp(join(await realpath(tmpdir()),'osa-v37-v29-byte-audit-'))
    const media=join(root,'media'),masters=join(media,'masters'),captions=join(media,'captions')
    const receipts=join(root,'receipts')
    try{
      await mkdir(masters,{recursive:true,mode:0o700});await mkdir(captions,{mode:0o700})
      for(const [i,asset] of original.assets.entries()){
        const encoded=ffmpeg(['-nostdin','-hide_banner','-loglevel','error','-filter_threads','1',
          '-f','lavfi','-i','testsrc2=s=640x360:r=10:d=1.5',
          '-f','lavfi','-i',`sine=frequency=${350+i*100}:sample_rate=48000:duration=1.5`,
          '-map','0:v:0','-map','1:a:0','-c:v','libx264','-threads','1','-preset','ultrafast',
          '-pix_fmt','yuv420p','-c:a','aac','-shortest','-movflags','+faststart','-y',
          join(masters,asset.id+'.mp4')])
        assert.equal(encoded.status,0,encoded.stderr || String(encoded.error))
        if(process.platform !== 'win32') await chmod(join(masters,asset.id+'.mp4'),0o600)
        await writeFile(join(captions,asset.id+'.vtt'),
          `WEBVTT\n\n00:00:00.000 --> 00:00:01.400\nSynthetic only ${i}\n`,{mode:0o600})
      }
      const preflight=await runOwnerPreflight({root:media,originals:originalManifest,outputDir:receipts})
      assert.equal(preflight.summary.result,'NO_GO')
      const report=await verifyPrivateMediaBytes({receiptsDir:receipts,mastersDir:masters,captionsDir:captions})
      assert.equal(report.bytesMatched,true)
      assert.equal(report.verifiedPrivateVideoFiles,4)
      assert.equal(report.verifiedPrivateCaptionFiles,4)
      assert.equal(report.decision,'NO_GO')
      assert.equal(report.paidCheckoutEnabled,false)
      assert.equal(report.publisherIdentityIndependentlyAuthenticated,false)
      // One-bit source edit after preflight must trigger V37 failure.
      const target=join(captions,original.assets[0].id+'.vtt')
      await writeFile(target,'WEBVTT\n\n00:00:00.000 --> 00:00:01.400\nTampered\n',{mode:0o600})
      await assert.rejects(verifyPrivateMediaBytes({receiptsDir:receipts,mastersDir:masters,captionsDir:captions}),
        /WebVTT bytes do not match/)
    }finally{await rm(root,{recursive:true,force:true})}
  })
