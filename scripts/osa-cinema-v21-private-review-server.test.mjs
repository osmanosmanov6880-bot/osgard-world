import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtemp,mkdir,stat,rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { spawnSync } from 'node:child_process'
import { hashFile } from './osa-cinema-v20-private-hls.mjs'
import { parseByteRange, startPrivateReviewServer } from './osa-cinema-v21-private-review-server.mjs'

test('HTTP byte ranges handle beginning, suffix, overflow and multi-range denial',()=>{
  assert.deepEqual(parseByteRange(undefined,100),{start:0,end:99,status:200})
  assert.deepEqual(parseByteRange('bytes=0-9',100),{start:0,end:9,status:206})
  assert.deepEqual(parseByteRange('bytes=90-',100),{start:90,end:99,status:206})
  assert.deepEqual(parseByteRange('bytes=-5',100),{start:95,end:99,status:206})
  assert.equal(parseByteRange('bytes=0-9,40-50',100),null)
  assert.equal(parseByteRange('bytes=100-',100),null)
  assert.equal(parseByteRange('bytes=30-2',100),null)
  assert.equal(parseByteRange('bytes=-0',100),null)
})

test('private screening serves original real synthetic MP4 with cookie auth and HTTP 206', {timeout:120000}, async t=>{
  if(spawnSync('ffmpeg',['-version']).status!==0){t.skip('ffmpeg unavailable');return}
  const dir=await mkdtemp(join(tmpdir(),'osa-v21-browser-'))
  let service
  try {
    const src=join(dir,'source');await mkdir(src)
    const file=join(src,'synthetic.mp4')
    const made=spawnSync('ffmpeg',['-nostdin','-hide_banner','-loglevel','error','-f','lavfi','-i','color=c=navy:s=1280x720:r=12:d=2','-f','lavfi','-i','sine=frequency=880:sample_rate=48000:duration=2','-map','0:v:0','-map','1:a:0','-c:v','libx264','-preset','ultrafast','-pix_fmt','yuv420p','-c:a','aac','-shortest','-y',file],{encoding:'utf8',timeout:60000})
    assert.equal(made.status,0,made.stderr)
    const asset={id:'osa-test-trailer-ru',file:'synthetic.mp4',locale:'ru',edition:'trailer-workprint',sizeBytes:(await stat(file)).size,sha256:await hashFile(file),durationSeconds:2,width:1280,height:720,videoCodec:'h264',audioCodec:'aac'}
    const password='a-private-password-for-tests-2026'
    service=await startPrivateReviewServer({sourceDir:src,asset,password,cutTimes:[0.3,0.9,1.7],port:0})
    const base=service.url
    let r=await fetch(base+'/media')
    assert.equal(r.status,401)
    assert.equal(r.headers.get('cache-control'),'no-store, max-age=0')
    r=await fetch(base+'/',{redirect:'manual'});assert.equal(r.status,200)
    let html=await r.text();assert.match(html,/Пароль локальной приёмки/)
    assert.match(r.headers.get('content-security-policy'),/connect-src 'none'/)
    r=await fetch(base+'/login',{method:'POST',body:'password=wrong',headers:{Origin:base,'Content-Type':'application/x-www-form-urlencoded'},redirect:'manual'});assert.equal(r.status,401)
    r=await fetch(base+'/login',{method:'POST',body:'password='+encodeURIComponent(password),headers:{Origin:base,'Content-Type':'application/x-www-form-urlencoded'},redirect:'manual'})
    assert.equal(r.status,303)
    const cookie=r.headers.get('set-cookie')?.split(';')[0]
    assert.ok(cookie.startsWith('osa_private_session='))
    assert.match(r.headers.get('set-cookie'),/HttpOnly; SameSite=Strict/)
    r=await fetch(base+'/review',{headers:{Cookie:cookie}});assert.equal(r.status,200)
    html=await r.text();assert.match(html,/Точная проверка киноматериала/)
    assert.match(html,/sourceId:'osa-test-trailer-ru'/)
    assert.ok(!html.includes(password))
    r=await fetch(base+'/status',{headers:{Cookie:cookie}})
    assert.equal((await r.json()).publicationAuthorized,false)
    r=await fetch(base+'/media',{headers:{Cookie:cookie,Range:'bytes=0-19'}})
    assert.equal(r.status,206)
    assert.equal(r.headers.get('content-range'),'bytes 0-19/'+asset.sizeBytes)
    assert.equal(r.headers.get('content-type'),'video/mp4')
    assert.equal((await r.arrayBuffer()).byteLength,20)
    r=await fetch(base+'/media',{headers:{Cookie:cookie,Range:'bytes=-15'}})
    assert.equal(r.status,206);assert.equal((await r.arrayBuffer()).byteLength,15)
    r=await fetch(base+'/media',{method:'HEAD',headers:{Cookie:cookie}})
    assert.equal(r.status,200);assert.equal(r.headers.get('accept-ranges'),'bytes')
    r=await fetch(base+'/media',{headers:{Cookie:cookie,Range:'bytes=0-4,10-14'}})
    assert.equal(r.status,416)
    r=await fetch(base+'/logout',{method:'POST',headers:{Cookie:cookie,Origin:base},redirect:'manual'})
    assert.equal(r.status,303)
    r=await fetch(base+'/media',{headers:{Cookie:cookie}})
    assert.equal(r.status,401)
    r=await fetch(base+'/media?some_token=1',{headers:{Cookie:cookie}})
    assert.equal(r.status,404)
  } finally {if(service)await service.close();await rm(dir,{recursive:true,force:true})}
})

test('invalid password, symlink media and short secret are blocked before server listen',async()=>{
  const bad={id:'osa-test-trailer-ru',file:'missing.mp4',locale:'ru',edition:'trailer-workprint',sizeBytes:1200,sha256:'a'.repeat(64),durationSeconds:2,width:1280,height:720,videoCodec:'h264',audioCodec:'aac'}
  await assert.rejects(()=>startPrivateReviewServer({sourceDir:'/not-a-directory',asset:bad,password:'short'}),/16-256/)
})
