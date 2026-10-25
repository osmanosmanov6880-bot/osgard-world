import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtemp, mkdir, stat, appendFile, writeFile, symlink, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { spawnSync } from 'node:child_process'
import { hashFile, parsePlaylist, validateAsset, verifyOriginal, renderPrivatePackage, verifyPackage } from './osa-cinema-v20-private-hls.mjs'

const example={ id:'osa-test-trailer-ru', locale:'ru', edition:'trailer-workprint', file:'sample.mp4', sizeBytes:2000, sha256:'a'.repeat(64), durationSeconds:2, width:1280,height:720,videoCodec:'h264',audioCodec:'aac' }

test('rejects path traversal, fake fingerprints and unsupported codecs',()=>{
  assert.throws(()=>validateAsset({...example,file:'../sample.mp4'}),/Unsafe/)
  assert.throws(()=>validateAsset({...example,file:'sample.mp4?token=abc'}),/Unsafe/)
  assert.throws(()=>validateAsset({...example,sha256:'wrong'}),/Unsafe/)
  assert.throws(()=>validateAsset({...example,videoCodec:'h265'}),/metadata/)
  assert.throws(()=>validateAsset({...example,id:'../bad'}),/identity/)
})
test('rejects remote, traversing, duplicate and malformed segment playlists',()=>{
  const valid='#EXTM3U\n#EXT-X-VERSION:3\n#EXTINF:2.000,\nseg_00000.ts\n#EXT-X-ENDLIST\n'
  assert.deepEqual(parsePlaylist(valid),{segmentNames:['seg_00000.ts'],durationSeconds:2})
  for(const bad of [valid.replace('seg_00000.ts','https://cdn.example/seg.ts'),valid.replace('seg_00000.ts','../seg_00000.ts'), valid.replace('seg_00000.ts','seg_00000.ts\nseg_00000.ts'), valid.replace('#EXT-X-ENDLIST','#EXT-X-KEY:METHOD=AES-128'),valid.replace('#EXTINF:2.000','#EXTINF:0.000')]) assert.throws(()=>parsePlaylist(bad))
})
test('correct original source hash is mandatory, symlinks rejected',async()=>{
  const dir=await mkdtemp(join(tmpdir(),'osa-v20-src-'))
  try {
    await writeFile(join(dir,'sample.mp4'),'not a film')
    await assert.rejects(()=>verifyOriginal(dir,example),/mismatch/)
    await symlink(join(dir,'sample.mp4'),join(dir,'link.mp4'))
    const hash=await hashFile(join(dir,'sample.mp4'))
    await assert.rejects(()=>verifyOriginal(dir,{...example,file:'link.mp4',sizeBytes:2000,sha256:hash}),/regular private file/)
  } finally{await rm(dir,{recursive:true,force:true})}
})

test('real FFmpeg private local 720p HLS render, verify and tamper rejection', {timeout:120000}, async(t)=>{
  if(spawnSync('ffmpeg',['-version'],{encoding:'utf8'}).status!==0 || spawnSync('ffprobe',['-version'],{encoding:'utf8'}).status!==0){t.skip('FFmpeg unavailable');return}
  const dir=await mkdtemp(join(tmpdir(),'osa-v20-real-'))
  try {
    const media=join(dir,'media'),output=join(dir,'private-output')
    await mkdir(media);await mkdir(output)
    const source=join(media,'sample.mp4')
    const cmd=spawnSync('ffmpeg',['-nostdin','-hide_banner','-loglevel','error','-f','lavfi','-i','color=c=black:s=1280x720:r=12:d=2','-f','lavfi','-i','sine=frequency=440:sample_rate=48000:duration=2','-map','0:v:0','-map','1:a:0','-c:v','libx264','-preset','ultrafast','-pix_fmt','yuv420p','-c:a','aac','-shortest','-y',source],{encoding:'utf8',timeout:60000})
    assert.equal(cmd.status,0,cmd.stderr)
    const s=await stat(source),asset={...example,sizeBytes:s.size,sha256:await hashFile(source)}
    const qc=await renderPrivatePackage({root:media,output,asset,maxRendition:'p720'})
    assert.equal(qc.publicationAuthorized,false)
    assert.equal(qc.checkoutEnabled,false)
    assert.equal(qc.variants.length,1)
    assert.ok(qc.variants[0].segments.length>=1)
    assert.deepEqual(await verifyPackage(join(output,asset.id),asset),{sourceId:asset.id,variants:1,verified:true,releaseAuthorized:false})
    await appendFile(join(output,asset.id,'p720',qc.variants[0].segments[0].name),'tampered')
    await assert.rejects(()=>verifyPackage(join(output,asset.id),asset),/integrity mismatch/)
    await assert.rejects(()=>renderPrivatePackage({root:media,output,asset}),/Refusing overwrite/)
  } finally { await rm(dir,{recursive:true,force:true}) }
})
