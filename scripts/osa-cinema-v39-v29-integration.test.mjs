import { test } from 'node:test'
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { mkdtemp, mkdir, writeFile, readFile, chmod, rm, realpath } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { runOwnerPreflight } from './osa-cinema-v29-owner-preflight.mjs'
import { startPrivateOwnerDesk } from './osa-cinema-v39-owner-desk.mjs'

const source=new URL('../docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json',import.meta.url)
const projectRoot=dirname(dirname(fileURLToPath(source)))
const password='V39-private-integration-password-long-and-hidden'
const sleep=ms=>new Promise(ok=>setTimeout(ok,ms))

async function enter(url) {
  const first=await fetch(url+'/'), html=await first.text()
  const challenge=html.match(/name="csrf" value="([a-f0-9]{64})"/)?.[1]
  assert.ok(challenge)
  const login=await fetch(url+'/login',{method:'POST',redirect:'manual',headers:{
    Origin:url,Cookie:(first.headers.get('set-cookie')||'').split(';')[0],
    'Content-Type':'application/x-www-form-urlencoded',
  },body:new URLSearchParams({csrf:challenge,password})})
  assert.equal(login.status,303)
  const cookie=(login.headers.get('set-cookie')||'').split(';')[0]
  const home=await (await fetch(url+'/',{headers:{Cookie:cookie}})).text()
  const csrf=home.match(/const csrf='([a-f0-9]{64})'/)?.[1]
  assert.ok(csrf)
  return {cookie,csrf}
}
async function request(url,a,path,method='GET') {
  return fetch(url+path,{method,headers:{Cookie:a.cookie,...(method==='POST'?{Origin:url,'X-OSA-CSRF':a.csrf}:{})}})
}
async function waitFor(url,a,goal) {
  for(let i=0;i<400;i++){
    const r=await request(url,a,'/api/status'),s=await r.json()
    if(s.state===goal)return s
    if(s.state==='failed'&&goal!=='failed')assert.fail('Real V38 failed its audit via V39 desk')
    await sleep(150)
  }
  assert.fail('V39 UI audit timed out')
}

test('V39 one-click authenticated web desk -> authentic V38/V29 synthetic eight media fixture, still NO_GO',
  {timeout:240000},async()=>{
    const root=await mkdtemp(join(await realpath(tmpdir()),'osa-v39-real-media-'))
    const film=join(root,'private-film'),masters=join(film,'masters'),captions=join(film,'captions'),receipts=join(root,'private-receipts')
    let desk=null
    try {
      await mkdir(masters,{recursive:true,mode:0o700})
      await mkdir(captions,{mode:0o700})
      const originals=JSON.parse(await readFile(source,'utf8'))
      for(const [i,asset] of originals.assets.entries()){
        const file=join(masters,asset.id+'.mp4')
        const ff=spawnSync('ffmpeg',['-nostdin','-hide_banner','-loglevel','error','-filter_threads','1',
          '-f','lavfi','-i','testsrc2=s=640x360:r=10:d=1.5',
          '-f','lavfi','-i',`sine=frequency=${440+i*50}:sample_rate=48000:duration=1.5`,
          '-map','0:v:0','-map','1:a:0','-c:v','libx264','-threads','1','-preset','ultrafast',
          '-pix_fmt','yuv420p','-c:a','aac','-shortest','-movflags','+faststart','-y',file],
          {encoding:'utf8',timeout:60000,maxBuffer:1_000_000})
        assert.equal(ff.status,0,ff.stderr)
        if(process.platform!=='win32')await chmod(file,0o600)
        await writeFile(join(captions,asset.id+'.vtt'),
          `WEBVTT\n\n00:00:00.000 --> 00:00:01.400\nSynthetic integration only ${i}\n`,{mode:0o600})
      }
      const preflight=await runOwnerPreflight({root:film,originals:source,outputDir:receipts})
      assert.equal(preflight.summary.result,'NO_GO')
      desk=await startPrivateOwnerDesk({password,auditOptions:{repoRoot:projectRoot,
        receiptsDir:receipts,mastersDir:masters,captionsDir:captions}})
      const url=desk.url,a=await enter(url)
      assert.equal((await request(url,a,'/api/run','POST')).status,202)
      const good=await waitFor(url,a,'completed')
      assert.deepEqual([good.summary.codeHistory,good.summary.privateReceipts,good.summary.mp4Files,
        good.summary.captions,good.summary.cryptographicClaims],[3,4,4,4,0])
      assert.equal(good.publicationAuthorized,false)
      assert.equal(good.summary.rightsCleared,false)
      assert.equal(good.summary.paidCheckoutEnabled,false)
      const report=await (await request(url,a,'/api/report')).text()
      assert.doesNotMatch(report,/\/tmp\/|\/Users\/|V28_CANDIDATE_MANIFEST.json|private-film|\.mp4"/)
      // Regression: local captions modified after V29 report must never revalidate.
      await writeFile(join(captions,originals.assets[0].id+'.vtt'),
        'WEBVTT\n\n00:00:00.000 --> 00:00:01.400\nATTACK / FILE TAMPERED\n',{mode:0o600})
      assert.equal((await request(url,a,'/api/run','POST')).status,202)
      const denied=await waitFor(url,a,'failed')
      assert.equal(denied.summary,null)
      assert.equal((await request(url,a,'/api/report')).status,409)
    } finally {await desk?.close();await rm(root,{recursive:true,force:true})}
  })
