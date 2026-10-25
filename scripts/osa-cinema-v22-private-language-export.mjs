/**
 * OSA CINEMA V22: extract two language-CANDIDATE review files from the
 * 4-track V18 private MP4, without re-encoding picture or selected audio.
 * This tool NEVER approves speech, rights, subtitles or publication.
 */
import { createHash } from 'node:crypto'
import { createReadStream } from 'node:fs'
import { lstat, readFile, writeFile, mkdir, mkdtemp, rename, rm, readdir } from 'node:fs/promises'
import { spawn } from 'node:child_process'
import { basename, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const HEX = /^[a-f0-9]{64}$/
const MP4 = /^[A-Za-z0-9][A-Za-z0-9_.-]{1,120}\.mp4$/
const REVIEW = /^OSA_CINEMA_V22_PRIVATE_(RU|EN)_(ORIGINAL|DRAFT)\.mp4$/
const ROLES = {
  original: [ ['ru', 0, 'original_ru_candidate'], ['en', 1, 'original_en_candidate'] ],
  draft: [ ['ru', 2, 'draft_ru_narration_plus_bed'], ['en', 3, 'draft_en_narration_plus_bed'] ]
}

export function validateV18Baseline(data) {
  if(data?.schemaVersion!==1 || data?.publicationAuthorized!==false || data?.rightsCleared!==false ||
    data?.finalMixApproved!==false || data?.actualVoiceLanguagesApproved!==false ||
    data?.syncedCaptionsApproved!==false || data?.durablePublicUrlsPresent!==false ||
    !data?.originalPictureAndBothOriginalSoundtracksBitstreamSha256Match ||
    !data?.verifiedOutputDecodedAllFiveStreamsWithoutErrors ||
    !MP4.test(data.file||'') || basename(data.file)!==data.file ||
    !HEX.test(data.sha256||'') || !Number.isSafeInteger(data.sizeBytes) || data.sizeBytes<10000 ||
    !(data.durationSeconds>0) || data.durationSeconds>3600 ||
    data.picture?.codec!=='h264' || !(data.picture?.width>0) || !(data.picture?.height>0) ||
    !Array.isArray(data.audioTracks) || data.audioTracks.length!==4) throw Error('V18 baseline is not a verified unapproved private master')
  for(let i=0;i<4;i++) {
    const track=data.audioTracks[i]
    if(track?.index!==i || track?.codec!=='aac' || track?.role!==[...ROLES.original,...ROLES.draft].find(x=>x[1]===i)?.[2])
      throw Error('Four-track audio identity or order differs from V18')
    if(track.spokenLanguageVerified!==false)throw Error('Voice language is not independently approved')
  }
  return data
}
async function regular(path,kind='file'){
  const st=await lstat(path)
  if(st.isSymbolicLink() || (kind==='file' ? !st.isFile():!st.isDirectory())) throw Error('Unsafe private '+kind+' path')
  return st
}
export async function hashFile(path) {
  const h=createHash('sha256')
  for await (const chunk of createReadStream(path))h.update(chunk)
  return h.digest('hex')
}
async function run(program,args,limit=32768){
  return new Promise((ok,fail)=>{
    const child=spawn(program,args,{stdio:['ignore','pipe','pipe'],windowsHide:true})
    let stdout='',stderr='',finished=false
    const timer=setTimeout(()=>{child.kill('SIGKILL')},240000)
    const error=e=>{if(!finished){finished=true;clearTimeout(timer);fail(Error(program+': '+e.message))}}
    child.once('error',error)
    child.stdout.on('data',c=>{stdout+=c.toString();if(stdout.length>limit)child.kill('SIGKILL')})
    child.stderr.on('data',c=>{stderr+=c.toString();if(stderr.length>limit)stderr=stderr.slice(-limit)})
    child.once('close',(code,signal)=>{clearTimeout(timer);if(finished)return;finished=true;
      if(code===0)ok({stdout,stderr});else fail(Error(program+' failed (exit='+code+', signal='+signal+'): '+stderr.slice(-800)))})
  })
}
async function probe(file) {
  const {stdout}=await run('ffprobe',['-v','error','-show_entries','format=duration:stream=index,codec_type,codec_name,width,height,channels','-of','json',file])
  const p=JSON.parse(stdout)
  return {duration:Number(p.format?.duration),video:p.streams?.filter(x=>x.codec_type==='video')||[],audio:p.streams?.filter(x=>x.codec_type==='audio')||[],total:p.streams?.length||0}
}
export async function streamHash(path,map) {
  const {stdout}=await run('ffmpeg',['-nostdin','-hide_banner','-loglevel','error','-i',path,'-map',map,'-c','copy','-f','hash','-hash','sha256','-'],512)
  const sha=/SHA256=([a-f0-9]{64})/.exec(stdout)?.[1]
  if(!sha)throw Error('Could not fingerprint a selected media elementary stream')
  return sha
}
async function fullDecode(file) {
  await run('ffmpeg',['-nostdin','-hide_banner','-loglevel','error','-threads','2','-i',file,'-map','0:v:0','-map','0:a:0','-f','null','-'],2000)
}
async function inspectLoudness(file){
  const {stderr}=await run('ffmpeg',['-nostdin','-hide_banner','-loglevel','info','-i',file,'-map','0:a:0','-af','ebur128=peak=true','-f','null','-'],16384)
  const summary=stderr.split('Summary:').at(-1)
  if(summary===stderr)throw Error('Missing FFmpeg EBU-R128 loudness summary')
  const integrated=/I:\s*(-?[0-9.]+)\s*LUFS/.exec(summary)?.[1]
  const truePeak=/Peak:\s*(-?[0-9.]+)\s*dBFS/.exec(summary)?.[1]
  if(integrated===undefined || truePeak===undefined)throw Error('Invalid measured EBU-R128 loudness/true peak')
  return {integratedLufs:Number(integrated), truePeakDbtp:Number(truePeak), measuredNotApproved:true}
}

export async function inspectV18Source(sourceDir,baseline){
  validateV18Baseline(baseline)
  const root=resolve(sourceDir)
  await regular(root,'dir')
  const file=join(root,baseline.file)
  const info=await regular(file)
  if(info.size!==baseline.sizeBytes || await hashFile(file)!==baseline.sha256)throw Error('V18 private source hash/size mismatch')
  const p=await probe(file)
  if(!Number.isFinite(p.duration) || Math.abs(p.duration-baseline.durationSeconds)>.12 || p.total!==5 || p.video.length!==1 || p.audio.length!==4 ||
     p.video[0].codec_name!=='h264' || p.video[0].width!==baseline.picture.width || p.video[0].height!==baseline.picture.height || p.audio.some(x=>x.codec_name!=='aac'))
    throw Error('V18 input MP4 has unexpected codec, track count or runtime')
  const originalVideoHash=await streamHash(file,'0:v:0')
  if(originalVideoHash!==baseline.picture.packetSha256) throw Error('V18 picture stream changed')
  if(await streamHash(file,'0:a:0')!==baseline.audioTracks[0].packetSha256 ||
     await streamHash(file,'0:a:1')!==baseline.audioTracks[1].packetSha256)throw Error('V18 original soundtrack stream changed')
  return {file, duration:p.duration, pictureSha256:originalVideoHash}
}
export async function makePrivateExports({sourceDir,outputDir,baseline,edition='draft'}){
  validateV18Baseline(baseline)
  if(!ROLES[edition])throw Error('Invalid audio edition')
  const root=resolve(outputDir)
  await regular(root,'dir')
  const source=await inspectV18Source(sourceDir,baseline)
  const destination=join(root,'osa-v22-'+edition)
  try {await lstat(destination);throw Error('Refusing to overwrite private review exports')}catch(e){if(e.code!=='ENOENT')throw e}
  const scratch=await mkdtemp(join(root,'.osa-v22-'))
  try{
    const chosen=[]
    for(const [lang,track,role] of ROLES[edition]){
      const name='OSA_CINEMA_V22_PRIVATE_'+lang.toUpperCase()+'_'+edition.toUpperCase()+'.mp4'
      const out=join(scratch,name)
      await run('ffmpeg',['-y','-nostdin','-hide_banner','-loglevel','error','-i',source.file,
        '-map','0:v:0','-map','0:a:'+track,'-c','copy','-movflags','+faststart',
        '-metadata','title=OSA CINEMA PRIVATE EDITORIAL - NOT RELEASED',
        '-metadata:s:a:0','language=und','-disposition:a:0','default',out],2000)
      const p=await probe(out)
      if(p.total!==2 || p.video.length!==1 || p.audio.length!==1 || p.video[0].codec_name!=='h264' || p.audio[0].codec_name!=='aac' ||
         p.video[0].width!==baseline.picture.width || p.video[0].height!==baseline.picture.height || Math.abs(p.duration-source.duration)>.15)
        throw Error('Review export media metadata mismatch')
      const vHash=await streamHash(out,'0:v:0')
      const sourceAudioHash=await streamHash(source.file,'0:a:'+track)
      const exportedAudioHash=await streamHash(out,'0:a:0')
      if(vHash!==source.pictureSha256 || sourceAudioHash!==exportedAudioHash)throw Error('Remux changed original video or chosen audio packets')
      await fullDecode(out)
      const loudness=await inspectLoudness(out)
      const bytes=(await regular(out)).size
      chosen.push({file:name,intendedLocale:lang,selectedV18AudioIndex:track,sourceRole:role,
        fileSha256:await hashFile(out),bytes,videoStreamSha256:vHash,audioStreamSha256:exportedAudioHash,
        durationSeconds:p.duration,audioMeasurements:loudness,spokenLanguageVerified:false,
        rightsCleared:false,finalMixApproved:false,captionApproval:false,publicationAuthorized:false})
    }
    const report={schemaVersion:1,status:'V22_PRIVATE_BILINGUAL_REVIEW_NOT_APPROVED',sourceV18File:baseline.file,
      sourceV18Sha256:baseline.sha256,edition,createdAt:new Date().toISOString(),exports:chosen,
      independentHumanAudioReviewRequired:true,rightsCleared:false,spokenLanguageVerified:false,
      syncedCaptionsApproved:false,publicationAuthorized:false,publicDistributionAllowed:false,
      warning:'LANGUAGE CANDIDATES ONLY. NO FINISHED RECORDED FILM, COPYRIGHT, APPROVED DUBBING OR PUBLIC DELIVERY.'}
    await writeFile(join(scratch,'private-v22-qa.json'),JSON.stringify(report,null,2)+'\n')
    await rename(scratch,destination)
    return report
  }catch(e){await rm(scratch,{recursive:true,force:true});throw e}
}
export async function verifyPrivateExports({folder,baseline,edition,sourceDir}){
  validateV18Baseline(baseline)
  if(!ROLES[edition])throw Error('Invalid review edition')
  if(!sourceDir)throw Error('Original V18 source is required to verify track identity independently')
  const source=await inspectV18Source(sourceDir,baseline)
  await regular(folder,'dir')
  const reportPath=join(folder,'private-v22-qa.json')
  await regular(reportPath)
  const report=JSON.parse(await readFile(reportPath,'utf8'))
  if(report.schemaVersion!==1 || report.sourceV18Sha256!==baseline.sha256 || report.sourceV18File!==baseline.file || report.edition!==edition || report.publicationAuthorized!==false || report.rightsCleared!==false || report.publicDistributionAllowed!==false || report.spokenLanguageVerified!==false || report.syncedCaptionsApproved!==false || report.independentHumanAudioReviewRequired!==true || !Array.isArray(report.exports) || report.exports.length!==2)throw Error('Private release policy or report identity mismatch')
  const expectedNames=['private-v22-qa.json',...ROLES[edition].map(([lang])=>'OSA_CINEMA_V22_PRIVATE_'+lang.toUpperCase()+'_'+edition.toUpperCase()+'.mp4')]
  const actual=await readdir(folder)
  if(actual.length!==expectedNames.length || actual.some(x=>!expectedNames.includes(x)))throw Error('Unexpected private package file')
  for(const [idx,[lang,track,role]] of ROLES[edition].entries()){
    const row=report.exports[idx]
    if(row.file!==expectedNames[idx+1] || !REVIEW.test(row.file) || row.intendedLocale!==lang || row.selectedV18AudioIndex!==track || row.sourceRole!==role || row.publicationAuthorized!==false || row.spokenLanguageVerified!==false || row.rightsCleared!==false || row.finalMixApproved!==false || row.captionApproval!==false)throw Error('Untrusted localized export report')
    const path=join(folder,row.file)
    const info=await regular(path)
    if(info.size!==row.bytes || await hashFile(path)!==row.fileSha256)throw Error('Private exported file was modified')
    if(await streamHash(path,'0:v:0')!==source.pictureSha256 || await streamHash(path,'0:a:0')!==row.audioStreamSha256 ||
       row.audioStreamSha256!==await streamHash(source.file,'0:a:'+track))throw Error('Private output stream mismatch')
  }
  return {verified:true,assets:2,releaseAuthorized:false,edition}
}
async function main(argv){
  let mode='',sourceDir='',outputDir='',baselinePath='docs/OSA_CINEMA_V18_PRIVATE_FOUR_TRACK_QA.json',edition='draft'
  for(let i=0;i<argv.length;i++){
    const a=argv[i],v=argv[++i];if(!v)throw Error('Option requires a value: '+a)
    if(a==='--mode')mode=v
    else if(a==='--private-source-dir')sourceDir=v
    else if(a==='--private-output-dir')outputDir=v
    else if(a==='--baseline')baselinePath=v
    else if(a==='--edition')edition=v
    else throw Error('Unrecognized parameter '+a)
  }
  const baseline=JSON.parse(await readFile(baselinePath,'utf8'))
  if(!outputDir || !['check','render','verify'].includes(mode) || !ROLES[edition])throw Error('Usage: --mode check|render|verify --private-output-dir PATH --private-source-dir PATH [--edition original|draft] [--baseline V18_QA.json]')
  if(mode==='check'){if(!sourceDir)throw Error('Input directory required');console.log(JSON.stringify({verified:await inspectV18Source(sourceDir,baseline),publicationAuthorized:false}));return}
  if(mode==='render'){if(!sourceDir)throw Error('Input directory required');console.log(JSON.stringify(await makePrivateExports({sourceDir,outputDir,baseline,edition})));return}
  if(!sourceDir)throw Error('Verification requires the original V18 private source directory')
  console.log(JSON.stringify(await verifyPrivateExports({folder:join(resolve(outputDir),'osa-v22-'+edition),baseline,edition,sourceDir})))
}
if(process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url))main(process.argv.slice(2)).catch(e=>{console.error(e.stack||String(e));process.exitCode=1})
