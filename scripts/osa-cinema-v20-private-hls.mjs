/**
 * OSA CINEMA V20: LOCAL-ONLY HLS workprint renderer and integrity verifier.
 * This tool cannot publish media, approve rights, or unlock payments.
 */
import { createHash } from 'node:crypto'
import { createReadStream } from 'node:fs'
import { lstat, readFile, writeFile, mkdir, mkdtemp, rename, rm, readdir } from 'node:fs/promises'
import { spawnSync } from 'node:child_process'
import { basename, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

export const DEFAULT_MANIFEST = 'docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json'
const HEX64 = /^[0-9a-f]{64}$/
const ID = /^osa-[a-z0-9-]{3,70}$/
const FILE = /^[a-zA-Z0-9_.-]+\.mp4$/
const SEG = /^seg_\d{5}\.ts$/
const VARIANTS = Object.freeze({ p720: { width:1280, height:720, bandwidth:1800000, crf:23 }, p1080: { width:1920, height:1080, bandwidth:3800000, crf:22 } })

export function validateAsset(asset) {
  if (!asset || !ID.test(asset.id || '') || !['ru','en'].includes(asset.locale) || !['directors-workprint','trailer-workprint'].includes(asset.edition)) throw Error('Invalid source identity')
  if (!FILE.test(asset.file || '') || basename(asset.file) !== asset.file || !HEX64.test(asset.sha256 || '')) throw Error('Unsafe source file or fingerprint')
  if (!Number.isSafeInteger(asset.sizeBytes) || asset.sizeBytes < 1000 || !(asset.durationSeconds > 0) || asset.durationSeconds > 3600) throw Error('Invalid media size or duration')
  if (!Number.isSafeInteger(asset.width) || !Number.isSafeInteger(asset.height) || !['h264'].includes(asset.videoCodec) || asset.audioCodec !== 'aac') throw Error('Invalid picture/sound metadata')
  return asset
}

export function parsePlaylist(text) {
  if (typeof text !== 'string' || !text.startsWith('#EXTM3U\n') || !text.includes('#EXT-X-ENDLIST')) throw Error('Missing finalized HLS playlist')
  if (text.includes('#EXT-X-KEY') || text.includes('#EXT-X-MAP') || text.includes('#EXT-X-DEFINE') || text.includes('#EXT-X-SESSION')) throw Error('Unexpected playlist key or remote map')
  const lines = text.split(/\r?\n/).map(x => x.trim()).filter(Boolean)
  const files = [], lengths = []
  for (const line of lines) {
    if (line.startsWith('#EXTINF:')) {
      const seconds = Number(/^#EXTINF:([0-9.]+)/.exec(line)?.[1])
      if (!Number.isFinite(seconds) || seconds <= 0 || seconds > 12) throw Error('Bad segment duration')
      lengths.push(seconds)
    } else if (!line.startsWith('#')) {
      if (!SEG.test(line) || files.includes(line)) throw Error('Unsafe or duplicate media segment URI')
      files.push(line)
    }
  }
  if (!files.length || files.length !== lengths.length || lines.at(-1) !== '#EXT-X-ENDLIST') throw Error('HLS segment list is incomplete')
  return { segmentNames:files, durationSeconds:Number(lengths.reduce((a,b)=>a+b,0).toFixed(3)) }
}

export async function hashFile(path) {
  const hash = createHash('sha256')
  for await (const chunk of createReadStream(path)) hash.update(chunk)
  return hash.digest('hex')
}
async function regular(path) {
  const stat = await lstat(path)
  if (!stat.isFile() || stat.isSymbolicLink()) throw Error('Not a regular private file: '+basename(path))
  return stat
}
async function realDirectory(path) {
  const stat = await lstat(path)
  if (!stat.isDirectory() || stat.isSymbolicLink()) throw Error('Unsafe directory')
}
function checked(args, maxBuffer=8*1024*1024, command='ffprobe') {
  const run = spawnSync(command,args,{encoding:'utf8',maxBuffer,timeout:900000,windowsHide:true})
  if (run.error || run.status!==0) throw Error(command+' failed: '+String(run.error?.message || run.stderr || run.status).slice(0,350))
  return run.stdout
}
export async function verifyOriginal(root, asset) {
  validateAsset(asset)
  await realDirectory(root)
  const file = join(root, asset.file)
  const stat = await regular(file)
  if (stat.size !== asset.sizeBytes || await hashFile(file) !== asset.sha256) throw Error('Original SHA-256 or byte size mismatch')
  const probe = JSON.parse(checked(['-v','error','-show_entries','format=duration:stream=codec_type,codec_name,width,height','-of','json',file]))
  const video = probe.streams?.find(s=>s.codec_type==='video'), audio = probe.streams?.find(s=>s.codec_type==='audio')
  if (!video || !audio || video.codec_name!==asset.videoCodec || audio.codec_name!==asset.audioCodec || video.width!==asset.width || video.height!==asset.height || Math.abs(Number(probe.format?.duration)-asset.durationSeconds)>.25) throw Error('Original codec, picture or duration mismatch')
  return { file, sha256:asset.sha256, sizeBytes:stat.size, durationSeconds:Number(probe.format.duration) }
}

export async function inspectVariant(folder) {
  await realDirectory(folder)
  const playlistFile = join(folder,'index.m3u8')
  const stat = await regular(playlistFile)
  if (stat.size > 1000000) throw Error('HLS playlist unexpectedly large')
  const playlist = await readFile(playlistFile,'utf8')
  const parsed = parsePlaylist(playlist)
  const expected = new Set(['index.m3u8',...parsed.segmentNames])
  const actual = await readdir(folder)
  if (actual.length !== expected.size || actual.some(x=>!expected.has(x))) throw Error('Unexpected files in HLS package')
  const segments = []
  for (const name of parsed.segmentNames) {
    const p = join(folder,name)
    const s = await regular(p)
    if (s.size===0) throw Error('Empty HLS segment')
    segments.push({ name, sizeBytes:s.size, sha256:await hashFile(p) })
  }
  return { playlistSha256:await hashFile(playlistFile), segments, durationSeconds:parsed.durationSeconds }
}
function hlsEncode(source, folder, variant) {
  const filter='scale='+variant.width+':'+variant.height+':force_original_aspect_ratio=decrease,pad='+variant.width+':'+variant.height+':(ow-iw)/2:(oh-ih)/2:color=black'
  checked(['-hide_banner','-nostdin','-y','-loglevel','error','-i',source,'-map','0:v:0','-map','0:a:0','-vf',filter,'-c:v','libx264','-preset','veryfast','-crf',String(variant.crf),'-pix_fmt','yuv420p','-force_key_frames','expr:gte(t,n_forced*6)','-sc_threshold','0','-c:a','aac','-b:a','160k','-ar','48000','-ac','2','-hls_time','6','-hls_list_size','0','-hls_playlist_type','vod','-hls_flags','independent_segments','-hls_segment_filename',join(folder,'seg_%05d.ts'),'-f','hls',join(folder,'index.m3u8')], 1024*1024,'ffmpeg')
}
export async function renderPrivatePackage({ root, output, asset, maxRendition='auto' }) {
  validateAsset(asset)
  if (!['auto','p720'].includes(maxRendition)) throw Error('Unsupported rendition profile')
  await realDirectory(output)
  const source = await verifyOriginal(root,asset)
  const finalDir = join(output,asset.id)
  try { await lstat(finalDir); throw Error('Refusing overwrite of an existing private package') } catch(e) { if (e.code!=='ENOENT') throw e }
  const temp = await mkdtemp(join(output,'.osa-v20-'))
  try {
    const names = ['p720']
    if (asset.height>=1080 && maxRendition!=='p720') names.push('p1080')
    const variants=[]
    for(const name of names) {
      const folder=join(temp,name)
      await mkdir(folder)
      hlsEncode(source.file,folder,VARIANTS[name])
      variants.push({name,width:VARIANTS[name].width,height:VARIANTS[name].height,bandwidth:VARIANTS[name].bandwidth,...await inspectVariant(folder)})
    }
    const master=['#EXTM3U','#EXT-X-VERSION:3']
    for (const v of variants) master.push('#EXT-X-STREAM-INF:BANDWIDTH='+v.bandwidth+',RESOLUTION='+v.width+'x'+v.height,v.name+'/index.m3u8')
    await writeFile(join(temp,'master.m3u8'),master.join('\n')+'\n')
    const report={schemaVersion:1,project:'OSA CINEMA',edition:'PRIVATE_V20_TECHNICAL_REVIEW',sourceId:asset.id,sourceFile:asset.file,localeCandidate:asset.locale,originalSha256:source.sha256,originalSizeBytes:source.sizeBytes,originalDurationSeconds:source.durationSeconds,variants,masterSha256:await hashFile(join(temp,'master.m3u8')),rightsCleared:false,spokenLanguageVerified:false,captionApproval:false,editorialApproval:false,publicationAuthorized:false,checkoutEnabled:false,notice:'PRIVATE TECHNICAL HLS REVIEW ONLY. MUST NOT BE PUBLICLY DISTRIBUTED.'}
    await writeFile(join(temp,'private-qa.json'),JSON.stringify(report,null,2)+'\n')
    await rename(temp,finalDir)
    return report
  } catch (error) { await rm(temp,{recursive:true,force:true}); throw error }
}

export async function verifyPackage(folder, expectedAsset) {
  await realDirectory(folder)
  validateAsset(expectedAsset)
  const qaFile=join(folder,'private-qa.json')
  await regular(qaFile)
  const qa=JSON.parse(await readFile(qaFile,'utf8'))
  if (qa.schemaVersion!==1 || qa.sourceId!==expectedAsset.id || qa.originalSha256!==expectedAsset.sha256 || qa.originalSizeBytes!==expectedAsset.sizeBytes || qa.publicationAuthorized!==false || qa.rightsCleared!==false || qa.checkoutEnabled!==false) throw Error('Unsafe or mismatched private package record')
  await regular(join(folder,'master.m3u8'))
  if (qa.masterSha256!==await hashFile(join(folder,'master.m3u8'))) throw Error('HLS master playlist tampered')
  const names=new Set(qa.variants?.map(v=>v.name))
  if (!names.has('p720') || names.size!==qa.variants.length || [...names].some(x=>!['p720','p1080'].includes(x))) throw Error('Invalid rendition set')
  const master=await readFile(join(folder,'master.m3u8'),'utf8')
  const expectedMaster=['#EXTM3U','#EXT-X-VERSION:3']
  for(const v of qa.variants) {
    if(!names.has(v.name) || v.width!==VARIANTS[v.name]?.width || v.height!==VARIANTS[v.name]?.height || v.bandwidth!==VARIANTS[v.name]?.bandwidth) throw Error('Incorrect HLS rendition metadata')
    expectedMaster.push('#EXT-X-STREAM-INF:BANDWIDTH='+v.bandwidth+',RESOLUTION='+v.width+'x'+v.height,v.name+'/index.m3u8')
  }
  if(master!==expectedMaster.join('\n')+'\n') throw Error('Unexpected or remote HLS master playlist entry')
  const expectedTop = new Set(['private-qa.json','master.m3u8',...names])
  const actualTop = await readdir(folder)
  if (actualTop.length!==expectedTop.size || actualTop.some(x=>!expectedTop.has(x))) throw Error('Unexpected top-level package bytes')
  for(const variant of qa.variants) {
    const measured=await inspectVariant(join(folder,variant.name))
    if (JSON.stringify(measured)!==JSON.stringify({playlistSha256:variant.playlistSha256,segments:variant.segments,durationSeconds:variant.durationSeconds})) throw Error('HLS segment integrity mismatch')
  }
  return {sourceId:qa.sourceId,variants:qa.variants.length,verified:true,releaseAuthorized:false}
}
async function main(args) {
  let mode, root, output, id, manifest=DEFAULT_MANIFEST, profile='auto'
  for(let i=0;i<args.length;i++){
    const key=args[i],val=args[++i]
    if(!val) throw Error('Missing option value '+key)
    if(key==='--mode') mode=val
    else if(key==='--private-source-dir') root=val
    else if(key==='--private-output-dir') output=val
    else if(key==='--source-id') id=val
    else if(key==='--manifest') manifest=val
    else if(key==='--max-rendition') profile=val
    else throw Error('Unknown option '+key)
  }
  if(!['check','render','verify'].includes(mode)||!output||!id)throw Error('Usage: --mode check|render|verify --source-id ID --private-output-dir PATH [--private-source-dir PATH] [--manifest PATH]')
  const reg=JSON.parse(await readFile(manifest,'utf8'))
  const a=reg.assets?.find(x=>x.id===id)
  if(!a || reg.assets?.filter(x=>x.id===id).length!==1)throw Error('Unknown V16 source id')
  const o=resolve(output)
  if(mode==='verify'){console.log(JSON.stringify(await verifyPackage(join(o,id),a)));return}
  if(!root)throw Error('Original private media directory required')
  if(mode==='check'){console.log(JSON.stringify({sourceId:id,integrity:await verifyOriginal(resolve(root),a),publicationAuthorized:false}));return}
  console.log(JSON.stringify(await renderPrivatePackage({root:resolve(root),output:o,asset:a,maxRendition:profile})))
}
if(process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url))main(process.argv.slice(2)).catch(e=>{console.error(e.stack||String(e));process.exitCode=1})
