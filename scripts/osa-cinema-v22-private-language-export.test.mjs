import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtemp, mkdir, readFile, writeFile, rename, rm, stat, symlink } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { spawn } from 'node:child_process'
import { hashFile, streamHash, validateV18Baseline, inspectV18Source, makePrivateExports, verifyPrivateExports } from './osa-cinema-v22-private-language-export.mjs'

async function renderSyntheticFourTrack(path) {
  const args=['-y','-nostdin','-hide_banner','-loglevel','error',
    '-filter_threads','1','-f','lavfi','-i','testsrc2=s=320x180:r=12:d=2']
  for(const hz of [330,440,550,660])args.push('-f','lavfi','-i',`sine=frequency=${hz}:sample_rate=48000:duration=2`)
  args.push('-map','0:v:0','-map','1:a:0','-map','2:a:0','-map','3:a:0','-map','4:a:0',
    '-c:v','libx264','-threads','1','-preset','ultrafast','-pix_fmt','yuv420p',
    '-c:a','aac','-b:a','96k','-ac','2','-movflags','+faststart','-shortest',path)
  await new Promise((resolve,reject)=>{
    const c=spawn('ffmpeg',args,{stdio:['ignore','ignore','pipe']})
    let stderr=''
    const timer=setTimeout(()=>c.kill('SIGKILL'),90000)
    c.stderr.on('data',b=>{stderr+=b.toString().slice(-2048)})
    c.once('error',e=>{clearTimeout(timer);reject(e)})
    c.once('close',(code,signal)=>{clearTimeout(timer);code===0?resolve():reject(Error(`FFmpeg source failed ${code}/${signal}: ${stderr}`))})
  })
}
function baseline(file,hash,bytes,videoHash,au0,au1){
  return {schemaVersion:1,publicationAuthorized:false,rightsCleared:false,finalMixApproved:false,actualVoiceLanguagesApproved:false,syncedCaptionsApproved:false,durablePublicUrlsPresent:false,
    originalPictureAndBothOriginalSoundtracksBitstreamSha256Match:true,verifiedOutputDecodedAllFiveStreamsWithoutErrors:true,file,sha256:hash,sizeBytes:bytes,durationSeconds:2,
    picture:{codec:'h264',width:320,height:180,packetSha256:videoHash},
    audioTracks:['original_ru_candidate','original_en_candidate','draft_ru_narration_plus_bed','draft_en_narration_plus_bed'].map((role,index)=>({index,codec:'aac',role,spokenLanguageVerified:false,packetSha256:index===0?au0:index===1?au1:undefined}))}
}
test('V22 real 5-stream 4-audio → two original and two draft MP4s, bitstream QA, and fail-closed release',async()=>{
  const dir=await mkdtemp(join(tmpdir(),'osa-v22-'))
  try{
    const sources=join(dir,'sources'),outputs=join(dir,'outputs')
    await mkdir(sources);await mkdir(outputs)
    const name='OSA_CINEMA_V18_PRIVATE_TEST.mp4'
    const input=join(sources,name)
    await renderSyntheticFourTrack(input)
    const v18=baseline(name,await hashFile(input),(await stat(input)).size,await streamHash(input,'0:v:0'),await streamHash(input,'0:a:0'),await streamHash(input,'0:a:1'))
    assert.equal(validateV18Baseline(v18).audioTracks.length,4)
    assert.equal((await inspectV18Source(sources,v18)).pictureSha256,v18.picture.packetSha256)
    for(const mode of ['original','draft']){
      const result=await makePrivateExports({sourceDir:sources,outputDir:outputs,baseline:v18,edition:mode})
      assert.equal(result.publicationAuthorized,false)
      assert.equal(result.exports.length,2)
      assert.deepEqual(result.exports.map(x=>x.selectedV18AudioIndex),mode==='original'?[0,1]:[2,3])
      assert.ok(result.exports.every(x=>x.audioMeasurements.measuredNotApproved && Number.isFinite(x.audioMeasurements.truePeakDbtp)))
      assert.equal((await verifyPrivateExports({folder:join(outputs,'osa-v22-'+mode),baseline:v18,edition:mode,sourceDir:sources})).assets,2)
      await assert.rejects(makePrivateExports({sourceDir:sources,outputDir:outputs,baseline:v18,edition:mode}),/Refusing to overwrite/)
    }
    const dirDraft=join(outputs,'osa-v22-draft')
    const qa=JSON.parse(await readFile(join(dirDraft,'private-v22-qa.json'),'utf8'))
    qa.exports[0].selectedV18AudioIndex=0
    await writeFile(join(dirDraft,'private-v22-qa.json'),JSON.stringify(qa))
    await assert.rejects(verifyPrivateExports({folder:dirDraft,baseline:v18,edition:'draft',sourceDir:sources}),/Untrusted localized/)
    qa.exports[0].selectedV18AudioIndex=2
    await writeFile(join(dirDraft,'private-v22-qa.json'),JSON.stringify(qa))
    const target=join(dirDraft,qa.exports[0].file)
    await rename(target,join(dir,'shadow-file.mp4'))
    await symlink(join(dir,'shadow-file.mp4'),target)
    await assert.rejects(verifyPrivateExports({folder:dirDraft,baseline:v18,edition:'draft',sourceDir:sources}),/Unsafe private file path/)
    assert.throws(()=>validateV18Baseline({...v18,rightsCleared:true}),/verified unapproved/)
    assert.throws(()=>validateV18Baseline({...v18,audioTracks:[...v18.audioTracks].reverse()}),/track audio identity/)
    await assert.rejects(inspectV18Source(sources,{...v18,sha256:'0'.repeat(64)}),/hash\/size mismatch/)
  }finally{await rm(dir,{recursive:true,force:true})}
})

test('V22 rejects fake public-release claims and incorrect audio role order before opening any media',()=>{
  const h='0'.repeat(64)
  const v=baseline('PRIVATE_TEST.mp4',h,10001,h,h,h)
  for(const field of ['publicationAuthorized','rightsCleared','finalMixApproved','actualVoiceLanguagesApproved','syncedCaptionsApproved','durablePublicUrlsPresent'])
    assert.throws(()=>validateV18Baseline({...v,[field]:true}),/verified unapproved/)
  assert.throws(()=>validateV18Baseline({...v,file:'../../public.mp4'}),/verified unapproved/)
  assert.throws(()=>validateV18Baseline({...v,audioTracks:[...v.audioTracks].reverse()}),/track audio identity/)
  assert.equal(validateV18Baseline(v).publicationAuthorized,false)
})

test('V22 refuses invalid output editions without access to source or approvals',async()=>{
  const h='0'.repeat(64),v=baseline('PRIVATE_TEST.mp4',h,10001,h,h,h)
  await assert.rejects(makePrivateExports({sourceDir:'/none',outputDir:'/none',baseline:v,edition:'released'}),/Invalid audio edition/)
  await assert.rejects(verifyPrivateExports({folder:'/none',baseline:v,edition:'draft'}),/Original V18 source is required/)
})
