/**
 * V27 end-to-end release rehearsal. ALL media/rights are SYNTHETIC fixtures.
 * No public deploy, owner media, rights approval or payment activation.
 */
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { createServer } from 'node:http'
import { spawnSync } from 'node:child_process'
import { readFile, writeFile, mkdir, mkdtemp, rm, stat } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { inspectFinalMasters } from './osa-cinema-v24-final-master-qc.mjs'
import { auditRightsEvidence } from './osa-cinema-v25-rights-evidence.mjs'
import { checkLoopbackDelivery, verifyLoopbackURL } from './osa-cinema-v26-loopback-delivery-qc.mjs'
import { buildGoNoGoBoard, EXTERNAL_GATES } from './osa-cinema-v27-release-board.mjs'

const hash=value=>createHash('sha256').update(value).digest('hex')
const pdf=(i)=>Buffer.from(`%PDF-1.7\nSYNTHETIC RECEIPT ${i}; NOT A LICENSE OR SIGNED PERMISSION\n%%EOF`)
const V16='docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json'
const ffmpeg=(file,frequency)=>{
  const args=['-nostdin','-hide_banner','-loglevel','error','-filter_threads','1',
    '-f','lavfi','-i','testsrc2=s=640x360:r=10:d=1.5',
    '-f','lavfi','-i',`sine=frequency=${frequency}:sample_rate=48000:duration=1.5`,
    '-map','0:v:0','-map','1:a:0','-c:v','libx264','-threads','1',
    '-preset','ultrafast','-pix_fmt','yuv420p','-c:a','aac',
    '-shortest','-movflags','+faststart','-y',file]
  const proc=spawnSync('ffmpeg',args,{encoding:'utf8',timeout:60000,maxBuffer:1000000})
  assert.equal(proc.status,0,`Actual FFmpeg fixture failed: ${proc.error?.message||proc.stderr}`)
}

async function localMediaServer(file,{corruptRange=false,corruptMime=false}={}){
  const bytes=await readFile(file)
  const server=createServer((req,res)=>{
    if(req.url!=='/media'){res.writeHead(404);res.end();return}
    if(req.headers.cookie!=='private=synthetic'){res.writeHead(401,{'Cache-Control':'no-store'});res.end('Not authorized');return}
    const type=corruptMime?'application/octet-stream':'video/mp4'
    const base={'Content-Type':type,'Accept-Ranges':'bytes','Cache-Control':'no-store'}
    if(req.method==='HEAD'){res.writeHead(200,{...base,'Content-Length':bytes.length});res.end();return}
    const match=/^bytes=(\d+)-(\d*)$/.exec(req.headers.range||'')
    if(!match){res.writeHead(400);res.end();return}
    const start=Number(match[1]),end=match[2]?Number(match[2]):bytes.length-1
    if(start>=bytes.length||end<start||end>=bytes.length){res.writeHead(416,{'Content-Range':`bytes */${bytes.length}`});res.end();return}
    const chunk=Buffer.from(bytes.subarray(start,end+1))
    if(corruptRange&&chunk.length)chunk[0]^=1
    res.writeHead(206,{...base,'Content-Length':chunk.length,'Content-Range':`bytes ${start}-${end}/${bytes.length}`})
    res.end(chunk)
  })
  await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve)})
  return {url:`http://127.0.0.1:${server.address().port}/media`,close:()=>new Promise(resolve=>server.close(resolve))}
}

test('V27 FULL SYNTHETIC CHAIN: four real MP4s + four VTTs + PDF receipts + HTTP 206 + NO-GO',async t=>{
  const root=await mkdtemp(join(tmpdir(),'osa-v27-integrated-'))
  const originals=JSON.parse(await readFile(V16,'utf8'))
  assert.equal(originals.assets.length,4,'Canonical V16 provenance must contain four editions')
  const plan={schemaVersion:1,project:'OSA CINEMA',publicationAuthorized:false,commercialRightsCleared:false,assets:[]}
  const usage={schemaVersion:1,project:'OSA CINEMA',releaseAuthorized:false,editions:[],sources:[]}
  const services=[]
  try{
    for(const folder of ['masters','captions','rights'])await mkdir(join(root,folder))
    for(const [i,source] of originals.assets.entries()){
      const masterName=`synthetic_${source.id}.mp4`,captionName=`synthetic_${source.id}.vtt`
      const mediaPath=join(root,'masters',masterName)
      ffmpeg(mediaPath,350+i*100)
      const bytes=await readFile(mediaPath)
      const captions=Buffer.from(`WEBVTT\n\n00:00:00.000 --> 00:00:01.400\nTest ${i+1}\n`)
      await writeFile(join(root,'captions',captionName),captions)
      const row={id:source.id,locale:source.locale,edition:source.edition,sourceSha256:source.sha256,
        masterName,captionName,masterSha256:hash(bytes),captionSha256:hash(captions),masterBytes:bytes.length,
        width:640,height:360,durationSeconds:1.5,audioLanguageClaim:source.locale}
      plan.assets.push(row)
      const evidence=pdf(i),sourceId=`synthetic-origin-${i+1}`, evidenceFile=`synthetic_receipt_${i+1}.pdf`
      await writeFile(join(root,'rights',evidenceFile),evidence)
      usage.editions.push({finalId:row.id,finalSha256:row.masterSha256,sourceIds:[sourceId]})
      usage.sources.push({id:sourceId,type:'ai-generated',sourceSha256:hash(`SYNTHETIC_SOURCE_${i+1}`),
        evidenceFile,evidenceSha256:hash(evidence),commercialRightsApproved:false,evidenceHumanReviewed:false})
      assert.ok((await stat(mediaPath)).size>1000)
    }
    assert.equal(new Set(plan.assets.map(x=>x.masterSha256)).size,4,'Each edition must have unique exact media identity')

    await t.test('all four synthetic MP4s are actually probed and decoded; WebVTT is only a candidate',async()=>{
      const q=await inspectFinalMasters(root,plan,originals)
      assert.equal(q.technical.passed,4)
      assert.ok(q.assets.every(a=>a.technicalCandidatePassed))
      assert.equal(q.recordedFilmReleaseAuthorized,false)
      assert.equal(q.paidCheckoutAllowed,false)
    })
    const v24=await inspectFinalMasters(root,plan,originals)
    const v25=await auditRightsEvidence(root,usage,plan)
    await t.test('all four synthetic PDFs exist and hash correctly but provide NO legal permission',()=>{
      assert.equal(v25.coverage.documentBytesVerified,4)
      assert.equal(v25.status,'DOCUMENT_BYTES_COMPLETE_LEGAL_HOLD')
      assert.equal(v25.rightsCleared,false)
    })

    const delivery=[]
    for(const row of plan.assets){
      const svc=await localMediaServer(join(root,'masters',row.masterName));services.push(svc)
      delivery.push(await checkLoopbackDelivery({url:svc.url,source:join(root,'masters',row.masterName),sha256:row.masterSha256,cookie:'private=synthetic'}))
    }
    await t.test('four local servers deny anonymous bytes and confirm exact HTTP 200/206/416',()=>{
      assert.ok(delivery.every(x=>x.status==='LOOPBACK_RANGE_QA_PASS_NOT_PUBLIC'&&x.errors.length===0))
      assert.ok(delivery.every(x=>x.tests.unauthorizedDenied&&x.tests.head===200&&x.tests.invalidRange===416))
      assert.throws(()=>verifyLoopbackURL('https://public.example/media'),/Private QA/)
    })
    await t.test('complete synthetic technical evidence is never a movie license or GO decision',()=>{
      const board=buildGoNoGoBoard(v24,v25,delivery)
      assert.equal(board.result,'NO_GO')
      assert.equal(board.technicalCandidateEvidenceComplete,true)
      assert.equal(board.externalAuthorizationsNotProvided.length,8)
      assert.deepEqual(board.externalAuthorizationsNotProvided,EXTERNAL_GATES)
      assert.equal(board.publicFilmPublicationAuthorized,false)
      assert.equal(board.paidCheckoutEnabled,false)
      assert.equal(board.productionDeploymentPerformed,false)
    })
    await t.test('mutating any signed movie blocks the exact V24 digest',async()=>{
      const file=join(root,'masters',plan.assets[0].masterName)
      const original=await readFile(file),changed=Buffer.from(original);changed[changed.length-1]^=1
      await writeFile(file,changed)
      const result=await inspectFinalMasters(root,plan,originals,{decode:false})
      assert.equal(result.technical.passed,3)
      assert.ok(result.assets[0].blockers.includes('master_sha256_mismatch'))
      assert.equal(buildGoNoGoBoard(result,v25,delivery).technicalCandidateEvidenceComplete,false)
      await writeFile(file,original)
    })
    await t.test('mutating any PDF revokes the synthetic document digest and V27 technical completeness',async()=>{
      const file=join(root,'rights',usage.sources[0].evidenceFile)
      await writeFile(file,Buffer.from('%PDF-1.7\nCHANGED SYNTHETIC RECORD\n%%EOF'))
      const failed=await auditRightsEvidence(root,usage,plan)
      assert.equal(failed.coverage.missing,1)
      assert.equal(buildGoNoGoBoard(v24,failed,delivery).technicalCandidateEvidenceComplete,false)
    })
    await t.test('forged HTTP bytes or publication flags are always blocked',async()=>{
      const row=plan.assets[0],svc=await localMediaServer(join(root,'masters',row.masterName),{corruptRange:true});services.push(svc)
      const bad=await checkLoopbackDelivery({url:svc.url,source:join(root,'masters',row.masterName),sha256:row.masterSha256,cookie:'private=synthetic'})
      assert.equal(bad.status,'STAGING_DELIVERY_HOLD')
      assert.ok(bad.errors.includes('range_bytes_differ_from_verified_master'))
      const wrong=structuredClone(delivery);wrong[0]=bad
      assert.equal(buildGoNoGoBoard(v24,v25,wrong).technicalCandidateEvidenceComplete,false)
      const forged=structuredClone(v24);forged.recordedFilmReleaseAuthorized=true
      assert.throws(()=>buildGoNoGoBoard(forged,v25,delivery),/fraudulently released/)
    })
  }finally{
    for(const service of services)await service.close()
    await rm(root,{recursive:true,force:true})
  }
})
