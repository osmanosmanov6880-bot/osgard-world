import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtemp, mkdir, readFile, writeFile, rm, readdir } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { spawnSync } from 'node:child_process'
import { createHash, generateKeyPairSync } from 'node:crypto'
import { Script } from 'node:vm'
import { request as rawHttpRequest } from 'node:http'
import { startPrivateOwnerConsole } from './osa-cinema-v31-owner-console.mjs'
import { buildPrivateCandidatePlan } from './osa-cinema-v28-final-intake.mjs'
import { runOwnerPreflight } from './osa-cinema-v29-owner-preflight.mjs'
import { EXTERNAL_GATES } from './osa-cinema-v27-release-board.mjs'
import { releaseFingerprint } from './osa-cinema-v30-external-attestations.mjs'
import { makeSignedApproval } from './osa-cinema-v30-sign-approval.mjs'

const V16='docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json'
const pass='private-v31-integration-password-24-characters'
const sleep=ms=>new Promise(r=>setTimeout(r,ms))
const sha=bytes=>createHash('sha256').update(bytes).digest('hex')
async function setup({withMedia=false}={}){
  const temp=await mkdtemp(join(tmpdir(),'osa-v31-ui-'))
  const root=join(temp,'film'),reports=join(temp,'reports'),masters=join(root,'masters'),captions=join(root,'captions')
  await mkdir(masters,{recursive:true});await mkdir(captions);await mkdir(reports)
  const originals=JSON.parse(await readFile(V16,'utf8'))
  if(withMedia){for(const [i,a] of originals.assets.entries()){
    const path=join(masters,a.id+'.mp4')
    const p=spawnSync('ffmpeg',['-nostdin','-hide_banner','-loglevel','error','-filter_threads','1',
      '-f','lavfi','-i','testsrc2=s=640x360:r=10:d=1.5',
      '-f','lavfi','-i',`sine=frequency=${390+i*113}:sample_rate=48000:duration=1.5`,
      '-map','0:v:0','-map','1:a:0','-c:v','libx264','-threads','1','-preset','ultrafast',
      '-pix_fmt','yuv420p','-c:a','aac','-shortest','-movflags','+faststart','-y',path],
      {encoding:'utf8',timeout:60000})
    assert.equal(p.status,0,p.stderr)
    await writeFile(join(captions,a.id+'.vtt'),`WEBVTT\n\n00:00:00.000 --> 00:00:01.400\nПриватный тест ${i+1}\n`)
  }}
  return {temp,root,reports,originals}
}
async function login(url){
  const first=await fetch(url+'/'); assert.equal(first.status,200)
  const page=await first.text()
  const token=page.match(/name="csrf" value="([a-f0-9]{64})"/)?.[1]
  assert.ok(token)
  const res=await fetch(url+'/login',{method:'POST',redirect:'manual',headers:{Origin:url,'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({csrf:token,password:pass})})
  assert.equal(res.status,303)
  const full=res.headers.get('set-cookie')||''
  assert.match(full,/HttpOnly/);assert.match(full,/SameSite=Strict/)
  const cookie=full.split(';')[0]
  assert.match(cookie,/^osa_owner_session=[a-f0-9]{64}$/)
  const ready=await fetch(url+'/',{headers:{Cookie:cookie}})
  const dashboard=await ready.text()
  const csrf=dashboard.match(/const csrf='([a-f0-9]{64})'/)?.[1]
  assert.ok(csrf)
  return {cookie,csrf,dashboard}
}
const request=(url,cookie,route,method='GET',csrf=null,origin=null)=>fetch(url+route,{method,redirect:'manual',headers:{Cookie:cookie,...(csrf?{'X-OSA-CSRF':csrf}:{}),...(origin?{Origin:origin}:{})}})

test('V31 localhost owner dashboard rejects stolen sessions and external origins', {timeout:40000},async t=>{
  const f=await setup()
  let service=null
  try{
    await t.test('startup refuses short passwords and nested report directories',async()=>{
      await assert.rejects(startPrivateOwnerConsole({root:f.root,reportsRoot:f.reports,password:'123'}),/16-256/)
      await assert.rejects(startPrivateOwnerConsole({root:f.root,reportsRoot:f.root,password:pass}),/separate/)
    })
    service=await startPrivateOwnerConsole({root:f.root,reportsRoot:f.reports,password:pass,originals:V16})
    const url=service.url
    await t.test('exact 127.0.0.1 binding, security headers, no login bypass',async()=>{
      assert.match(url,/^http:\/\/127\.0\.0\.1:\d+$/)
      const r=await fetch(url+'/api/status')
      assert.equal(r.status,401)
      const g=await fetch(url+'/api/report/V29_OWNER_PREFLIGHT_NO_GO.json')
      assert.equal(g.status,401)
      const code=await new Promise((resolve,reject)=>{const q=rawHttpRequest(url+'/',{headers:{Host:'example.net'}},res=>{res.resume();res.on('end',()=>resolve(res.statusCode))});q.on('error',reject);q.end()})
      assert.equal(code,403)
      const a=await fetch(url+'/')
      assert.match(a.headers.get('content-security-policy'),/connect-src 'self'/)
      assert.match(a.headers.get('content-security-policy'),/media-src 'none'/)
      assert.equal(a.headers.get('cache-control'),'no-store, max-age=0')
    })
    await t.test('challenge required; wrong password and foreign Origin cannot authenticate',async()=>{
      const missing=await fetch(url+'/login',{method:'POST',redirect:'manual',body:'password='+encodeURIComponent(pass)})
      assert.equal(missing.status,403)
      const p=await (await fetch(url+'/')).text(),token=p.match(/name="csrf" value="([a-f0-9]{64})"/)?.[1]
      const wrong=await fetch(url+'/login',{method:'POST',redirect:'manual',headers:{Origin:url},body:new URLSearchParams({csrf:token,password:'wrong-password'})})
      assert.equal(wrong.status,401)
      const retry=await fetch(url+'/login',{method:'POST',redirect:'manual',headers:{Origin:url},body:new URLSearchParams({csrf:token,password:pass})})
      assert.equal(retry.status,403,'CSRF challenge cannot be replayed')
      const p2=await (await fetch(url+'/')).text(),token2=p2.match(/name="csrf" value="([a-f0-9]{64})"/)?.[1]
      const foreign=await fetch(url+'/login',{method:'POST',redirect:'manual',headers:{Origin:'https://evil.example'},body:new URLSearchParams({csrf:token2,password:pass})})
      assert.equal(foreign.status,403)
    })
    const a=await login(url)
    await t.test('authenticated dashboard includes working script and honest NO-GO release state',async()=>{
      const script=a.dashboard.match(/<script nonce="[^"]+">([\s\S]*?)<\/script>/)?.[1]
      assert.ok(script);assert.doesNotThrow(()=>new Script(script))
      assert.match(a.dashboard,/ПУБЛИКАЦИЯ ЗАПРЕЩЕНА/)
      assert.match(a.dashboard,/run-preflight/)
      assert.doesNotMatch(a.dashboard,new RegExp(f.temp.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')))
      const r=await request(url,a.cookie,'/api/status'),s=await r.json()
      assert.equal(s.releaseDecision,'NO_GO');assert.equal(s.publicationAuthorized,false)
      assert.equal(s.signatureConfigured,false)
      assert.equal(s.preflight.status,'idle')
    })
    await t.test('POST is CSRF-protected; V30 signing unavailable without trusted owner docs',async()=>{
      const missing=await request(url,a.cookie,'/api/run-preflight','POST')
      assert.equal(missing.status,403)
      const foreign=await request(url,a.cookie,'/api/run-preflight','POST',a.csrf,'https://evil.example')
      assert.equal(foreign.status,403)
      const signatures=await request(url,a.cookie,'/api/check-signatures','POST',a.csrf)
      assert.equal(signatures.status,409)
      const path=await request(url,a.cookie,'/api/report/../../etc/passwd')
      assert.equal(path.status,404)
    })
    await t.test('logout revokes cookie and all private evidence immediately',async()=>{
      const r=await request(url,a.cookie,'/api/logout','POST',a.csrf)
      assert.equal(r.status,200)
      const denied=await request(url,a.cookie,'/api/status')
      assert.equal(denied.status,401)
    })
  }finally{await service?.close();await rm(f.temp,{recursive:true,force:true})}
})

test('V31 one-click UI executes real 4x H264/AAC V29 preflight and locks report checksums', {timeout:240000},async t=>{
  const f=await setup({withMedia:true})
  let service=null
  try{
    service=await startPrivateOwnerConsole({root:f.root,reportsRoot:f.reports,password:pass,originals:V16})
    const url=service.url,a=await login(url)
    const run=await request(url,a.cookie,'/api/run-preflight','POST',a.csrf)
    assert.equal(run.status,202)
    const started=await run.json();assert.equal(started.publicationAuthorized,false)
    const parallel=await request(url,a.cookie,'/api/run-preflight','POST',a.csrf)
    assert.equal(parallel.status,409)
    let status=null
    for(let i=0;i<100;i++){
      await sleep(450)
      const r=await request(url,a.cookie,'/api/status');status=await r.json()
      if(status.preflight.status==='completed'||status.preflight.status==='failed')break
    }
    assert.equal(status.preflight.status,'completed','Actual local V29 command did not complete')
    assert.equal(status.preflight.mastersPassed,4)
    assert.equal(status.preflight.privateHttpPassed,4)
    assert.equal(status.releaseDecision,'NO_GO')
    assert.equal(status.publicationAuthorized,false)
    assert.equal(status.paidCheckoutEnabled,false)
    assert.ok(status.preflight.files.includes('V29_OWNER_PREFLIGHT_NO_GO.json'))
    await t.test('actual private report can be downloaded; media and approval are absent',async()=>{
      const response=await request(url,a.cookie,'/api/report/V29_OWNER_PREFLIGHT_NO_GO.json')
      assert.equal(response.status,200)
      const report=await response.json()
      assert.equal(report.result,'NO_GO')
      assert.equal(report.technical.mastersPassed,4)
      assert.equal(report.technical.privateHttpPassed,4)
      assert.equal(report.publicationAuthorized,false)
      assert.ok(report.blockers.includes('rights_usage_manifest_and_real_document_ledger_missing'))
      const whole=JSON.stringify(report)
      assert.ok(!whole.includes('osa_owner_session'))
      const noPdf=await request(url,a.cookie,'/api/report/SECRET.pdf')
      assert.equal(noPdf.status,404)
      const signatures=await request(url,a.cookie,'/api/check-signatures','POST',a.csrf)
      assert.equal(signatures.status,409)
    })
    await t.test('changed report bytes are detected and refused',async()=>{
      const folders=await readdir(f.reports)
      assert.equal(folders.length,1)
      const path=join(f.reports,folders[0],'V29_OWNER_PREFLIGHT_NO_GO.json')
      const old=await readFile(path,'utf8')
      await writeFile(path,old.replace('NO_GO','YES_GO'))
      const download=await request(url,a.cookie,'/api/report/V29_OWNER_PREFLIGHT_NO_GO.json')
      assert.equal(download.status,409)
    })
  }finally{await service?.close();await rm(f.temp,{recursive:true,force:true})}
})


test('V31 V30 button checks eight independently signed SHA-bound documents without granting film release', {timeout:240000},async t=>{
  const f=await setup({withMedia:true})
  let service=null
  try{
    const rights=join(f.root,'rights'),signEvidence=join(f.temp,'signer-evidence')
    await mkdir(rights);await mkdir(signEvidence)
    const originals=JSON.parse(await readFile(V16,'utf8'))
    const frozen=await buildPrivateCandidatePlan(f.root,originals)
    const pinnedPlan=join(f.temp,'pinned.json'),rightsUsage=join(f.temp,'rights.json')
    await writeFile(pinnedPlan,JSON.stringify(frozen))
    const usage={schemaVersion:1,project:'OSA CINEMA',releaseAuthorized:false,editions:[],sources:[]}
    for(const [i,a] of frozen.assets.entries()){
      const id='source-proof-'+(i+1),evidenceFile='test_rights_'+(i+1)+'.pdf'
      const pdf=Buffer.from(`%PDF-1.7\nSYNTHETIC TEST PAPER ${i}, NOT LICENSE\n%%EOF\n`)
      await writeFile(join(rights,evidenceFile),pdf)
      usage.editions.push({finalId:a.id,finalSha256:a.masterSha256,sourceIds:[id]})
      usage.sources.push({id,type:'video',sourceSha256:sha('synthetic-'+i),evidenceFile,evidenceSha256:sha(pdf),commercialRightsApproved:false,evidenceHumanReviewed:false})
    }
    await writeFile(rightsUsage,JSON.stringify(usage))
    const baseline=await runOwnerPreflight({root:f.root,originals:V16,outputDir:join(f.reports,'frozen-baseline'),rightsUsage,pinnedPlan})
    assert.equal(baseline.summary.technical.evidenceTechnicallyComplete,true)
    const fingerprint=releaseFingerprint(baseline.summary),signers=[],approvals=[]
    const signedAt=new Date(Date.now()-60000).toISOString(),expiresAt=new Date(Date.now()+20*86400000).toISOString()
    for(const [i,gate] of EXTERNAL_GATES.entries()){
      const {publicKey,privateKey}=generateKeyPairSync('ed25519')
      const name='signer_pdf_'+(i+1)+'.pdf',pdf=Buffer.from(`%PDF-1.7\nSYNTHETIC ROLE ATTESTATION ${i}. NOT LEGALLY VALID.\n%%EOF\n`),keyId='signer-role-'+(i+1)
      await writeFile(join(signEvidence,name),pdf)
      signers.push({gate,keyId,publicKeyPem:publicKey.export({type:'spki',format:'pem'})})
      const statement={schemaVersion:1,project:'OSA CINEMA',releaseFingerprint:fingerprint,gate,keyId,evidenceFile:name,evidenceSha256:sha(pdf),decision:'approved',signedAt,expiresAt}
      approvals.push(makeSignedApproval(statement,privateKey.export({type:'pkcs8',format:'pem'})))
    }
    const registry={schemaVersion:1,project:'OSA CINEMA',signers}
    const registryPath=join(f.temp,'trusted-signer-registry.json'),attestationsPath=join(f.temp,'owner-approvals.json')
    const registryBytes=Buffer.from(JSON.stringify(registry))
    await writeFile(registryPath,registryBytes);await writeFile(attestationsPath,JSON.stringify({schemaVersion:1,project:'OSA CINEMA',approvals}))
    service=await startPrivateOwnerConsole({root:f.root,reportsRoot:f.reports,password:pass,originals:V16,pinnedPlan,rightsUsage,signoff:{registry:registryPath,registrySha256:sha(registryBytes),attestations:attestationsPath,evidenceDir:signEvidence}})
    const a=await login(service.url)
    let requestPre=await request(service.url,a.cookie,'/api/run-preflight','POST',a.csrf)
    assert.equal(requestPre.status,202)
    let status=null
    for(let i=0;i<150;i++){
      await sleep(300)
      status=await (await request(service.url,a.cookie,'/api/status')).json()
      if(status.preflight.status!=='running')break
    }
    assert.equal(status.preflight.status,'completed')
    assert.equal(status.preflight.mastersPassed,4)
    assert.equal(status.signatureConfigured,true)
    await t.test('a complete separately pinned eight-key signer package verifies through browser API',async()=>{
      const r=await request(service.url,a.cookie,'/api/check-signatures','POST',a.csrf)
      assert.equal(r.status,202)
      let s=null
      for(let i=0;i<100;i++){
        await sleep(180)
        s=await (await request(service.url,a.cookie,'/api/status')).json()
        if(s.signatures.status!=='running')break
      }
      assert.equal(s.signatures.status,'completed')
      assert.equal(s.signatures.verified,8)
      assert.equal(s.publicationAuthorized,false)
      const receipt=await request(service.url,a.cookie,'/api/signature-report')
      assert.equal(receipt.status,200)
      const report=await receipt.json()
      assert.equal(report.verifiedSignatures,8)
      assert.equal(report.publicFilmPublicationAuthorized,false)
      assert.match(report.decision,/^NO_GO/)
    })
    await t.test('altered signer evidence later produces HOLD and refuses a silent release',async()=>{
      await writeFile(join(signEvidence,'signer_pdf_1.pdf'),'%PDF-1.7\nALTERED\n%%EOF\n')
      const r=await request(service.url,a.cookie,'/api/check-signatures','POST',a.csrf)
      assert.equal(r.status,202)
      let s=null
      for(let i=0;i<100;i++){
        await sleep(180)
        s=await (await request(service.url,a.cookie,'/api/status')).json()
        if(s.signatures.status!=='running')break
      }
      assert.equal(s.signatures.status,'hold')
      assert.equal(s.signatures.verified,7)
      assert.equal(s.releaseDecision,'NO_GO')
    })
  }finally{await service?.close();await rm(f.temp,{recursive:true,force:true})}
})
