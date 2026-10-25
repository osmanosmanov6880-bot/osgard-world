import { test } from 'node:test'
import assert from 'node:assert/strict'
import { Script } from 'node:vm'
import { request as httpRequest } from 'node:http'
import { startPrivateOwnerDesk, verifyV38Summary, parseDeskArgs } from './osa-cinema-v39-owner-desk.mjs'
import { EXTERNAL_GATES } from './osa-cinema-v27-release-board.mjs'

const password = 'OSA_v39_owner_private_test_only_123!'
const sleep=ms=>new Promise(ok=>setTimeout(ok,ms))
function validAudit() {
  return { schemaVersion:1, project:'OSA CINEMA', stage:'V38_OWNER_OFFLINE_RELEASE_DOSSIER',
    status:'TECHNICAL_EVIDENCE_VERIFIED_FOR_PRIVATE_REVIEW',
    evidence:{genuineHistoricalDocuments:3,checkedPrivateReceiptReports:4,
      checkedLocalMP4:4,checkedLocalWebVTT:4,signedClaimCount:0,signedClaimsStatus:'NOT_PROVIDED'},
    independentLegalHumanAndProductionGatesStillRequired:[...EXTERNAL_GATES],
    actualFinalFilmEditoriallyAccepted:false,legalRightsIndependentReviewComplete:false,
    publicHttpsAndDeviceQaComplete:false,publisherLegalAuthorityEstablishedBySoftware:false,
    releaseDecision:'NO_GO',publicationAuthorized:false,rightsCleared:false,
    paidCheckoutEnabled:false,publicCatalogueWriteAllowed:false,productionDeploymentPerformed:false }
}
const reportPathRx=/([A-Z]:\\|\/Users\/|\/home\/|\/mnt\/|\/tmp\/)/
async function login(url,{passwordValue=password,origin=url}={}) {
  const req=await fetch(url+'/')
  const page=await req.text()
  const csrf=page.match(/name="csrf" value="([a-f0-9]{64})"/)?.[1]
  assert.ok(csrf)
  const cookie=(req.headers.get('set-cookie')||'').split(';')[0]
  const response=await fetch(url+'/login',{method:'POST',redirect:'manual',
    headers:{Origin:origin,Cookie:cookie,'Content-Type':'application/x-www-form-urlencoded'},
    body:new URLSearchParams({csrf,password:passwordValue})})
  return {response,cookie,csrf,page}
}
async function auth(url) {
  const data=await login(url)
  assert.equal(data.response.status,303)
  const setCookie=data.response.headers.get('set-cookie')||''
  assert.match(setCookie,/HttpOnly/)
  assert.match(setCookie,/SameSite=Strict/)
  const cookie=setCookie.split(';')[0]
  assert.match(cookie,/^osa_v39_session=[a-f0-9]{64}$/)
  const page=await (await fetch(url+'/',{headers:{Cookie:cookie}})).text()
  const csrf=page.match(/const csrf='([a-f0-9]{64})'/)?.[1]
  assert.ok(csrf)
  return {cookie,csrf,page}
}
function http(url,authData,path,method='GET',headers={}) {
  return fetch(url+path,{method,redirect:'manual',headers:{Cookie:authData?.cookie||'',
    ...(method==='POST'?{Origin:url,'X-OSA-CSRF':authData?.csrf}:{}),...headers}})
}
async function state(url,a) {return (await (await http(url,a,'/api/status')).json())}
async function waitState(url,a,expected,attempts=70) {
  for(let i=0;i<attempts;i++){const s=await state(url,a);if(s.state===expected)return s;await sleep(50)}
  assert.fail('V39 status did not reach '+expected)
}

test('V39 summary: exact V38 allowlist and no invented legal approval', async t=>{
  await t.test('valid full technical proof reduces to no-GO counts only',()=>{
    const s=verifyV38Summary(validAudit())
    assert.equal(s.mp4Files,4);assert.equal(s.captions,4)
    assert.equal(s.releaseDecision,'NO_GO');assert.equal(s.paidCheckoutEnabled,false)
    assert.equal(s.publicationAuthorized,false);assert.equal(s.cryptographicClaimsStatus,'NOT_PROVIDED')
    assert.deepEqual(s.outstandingIndependentGates,EXTERNAL_GATES)
    assert.ok(!JSON.stringify(s).match(reportPathRx))
  })
  await t.test('real signed claims may be displayed but film still cannot release',()=>{
    const a=validAudit();a.evidence.checkedPrivateReceiptReports=6
    a.evidence.signedClaimCount=8
    a.evidence.signedClaimsStatus='CRYPTOGRAPHICALLY_VERIFIED_PRIVATE_ONLY'
    const result=verifyV38Summary(a)
    assert.equal(result.cryptographicClaims,8)
    assert.equal(result.legalClearanceConfirmedBySoftware,false)
    assert.equal(result.publicationAuthorized,false)
  })
  await t.test('forged GO, paid checkout and false legal clearance reject',()=>{
    for(const property of ['publicationAuthorized','rightsCleared','paidCheckoutEnabled',
      'publicCatalogueWriteAllowed','productionDeploymentPerformed',
      'actualFinalFilmEditoriallyAccepted','legalRightsIndependentReviewComplete',
      'publicHttpsAndDeviceQaComplete','publisherLegalAuthorityEstablishedBySoftware']) {
      const a=validAudit();a[property]=true
      assert.throws(()=>verifyV38Summary(a),/V39_DESK_HOLD/,property)
    }
  })
  await t.test('fake media counts, signer count and missing gate reject',()=>{
    const a=validAudit();a.evidence.checkedLocalMP4=3
    assert.throws(()=>verifyV38Summary(a),/counters/)
    const b=validAudit();b.evidence.signedClaimCount=8
    assert.throws(()=>verifyV38Summary(b),/counters/)
    const c=validAudit();c.independentLegalHumanAndProductionGatesStillRequired.pop()
    assert.throws(()=>verifyV38Summary(c),/external human/)
  })
  await t.test('malicious raw fields are NOT mirrored to browser summary',()=>{
    const a=validAudit();a.password='you-can-not-see-me';a.privateKeys='-----BEGIN PRIVATE KEY-----'
    a.realFile='/home/owner/film/private.mp4'
    assert.doesNotMatch(JSON.stringify(verifyV38Summary(a)),/PRIVATE KEY|private\.mp4|you-can-not/)
  })
})

test('V39 password-protected loopback desk: request protection, audit, report, logout',{timeout:40000},async t=>{
  const fake=validAudit()
  let result=fake,throwError=false,gate=null,calls=0
  const audit=async()=>{calls++;if(gate)await gate;if(throwError)throw Error('/home/secret/OWNER_REAL_FILM.mp4');return result}
  await assert.rejects(startPrivateOwnerDesk({password:'short'}),/password/)
  await assert.rejects(startPrivateOwnerDesk({password,port:65536}),/port/)
  const desk=await startPrivateOwnerDesk({password,audit})
  const url=desk.url
  try{
    await t.test('bound strictly to 127.0.0.1; strong CSP; no public media routes',async()=>{
      assert.match(url,/^http:\/\/127\.0\.0\.1:\d+$/)
      assert.equal(desk.binding,'127.0.0.1')
      const page=await fetch(url+'/')
      assert.equal(page.status,200)
      assert.match(page.headers.get('content-security-policy'),/media-src 'none'/)
      assert.match(page.headers.get('content-security-policy'),/form-action 'self'/)
      assert.equal(page.headers.get('cache-control'),'no-store, max-age=0')
      for(const path of ['/api/status','/api/report'])assert.equal((await fetch(url+path)).status,401)
      assert.equal((await fetch(url+'/movie.mp4')).status,404)
      assert.equal((await fetch(url+'/docs/OSA_CINEMA_V18_PRIVATE_FOUR_TRACK_QA.json')).status,404)
      const wrongHost=await new Promise((yes,no)=>{
        const req=httpRequest(url+'/',{headers:{Host:'attacker.example'}},res=>{res.resume();res.on('end',()=>yes(res.statusCode))})
        req.on('error',no);req.end()
      });assert.equal(wrongHost,403)
    })
    await t.test('CSRF, foreign Origin, wrong credentials and replay fail',async()=>{
      const miss=await fetch(url+'/login',{method:'POST',redirect:'manual',headers:{Origin:url},body:'password='+password})
      assert.equal(miss.status,403)
      const foreign=await login(url,{origin:'https://attacker.test'})
      assert.equal(foreign.response.status,403)
      const wrong=await login(url,{passwordValue:'wrong'})
      assert.equal(wrong.response.status,401)
      const replay=await fetch(url+'/login',{method:'POST',redirect:'manual',
        headers:{Origin:url,Cookie:wrong.cookie,'Content-Type':'application/x-www-form-urlencoded'},
        body:new URLSearchParams({csrf:wrong.csrf,password})})
      assert.equal(replay.status,403)
    })
    const session=await auth(url)
    await t.test('dashboard is actual interactive script and contains no private paths or publication action',async()=>{
      assert.match(session.page,/Премьера начинается/)
      assert.match(session.page,/id="run"/)
      const uiScript=session.page.match(/<script nonce="[^"]+">([\s\S]*?)<\/script>/)?.[1]
      assert.ok(uiScript);assert.doesNotThrow(()=>new Script(uiScript))
      assert.doesNotMatch(session.page,/ style="/)
      assert.match(session.page,/ПУБЛИЧНЫЙ ПОКАЗ И ОПЛАТА ЗАПРЕЩЕНЫ/)
      assert.doesNotMatch(session.page,reportPathRx)
      const s=await state(url,session)
      assert.equal(s.state,'idle')
      assert.equal(s.releaseDecision,'NO_GO')
    })
    await t.test('POST requires origin and valid per-session CSRF',async()=>{
      assert.equal((await http(url,session,'/api/run','POST',{'X-OSA-CSRF':'bad'})).status,403)
      assert.equal((await http(url,session,'/api/run','POST',{Origin:'https://attacker.test'})).status,403)
    })
    await t.test('successful private V38 audit only returns safe allowlisted report',async()=>{
      let unblock;gate=new Promise(ok=>{unblock=ok})
      const r=await http(url,session,'/api/run','POST');assert.equal(r.status,202)
      assert.equal((await http(url,session,'/api/run','POST')).status,409)
      assert.equal((await http(url,session,'/api/report')).status,409)
      assert.equal((await state(url,session)).state,'running')
      unblock();gate=null
      const s=await waitState(url,session,'completed')
      assert.equal(s.summary.mp4Files,4)
      assert.equal(s.summary.releaseDecision,'NO_GO')
      const report=await http(url,session,'/api/report')
      assert.equal(report.status,200)
      assert.match(report.headers.get('content-disposition'),/PRIVATE_NO_GO/)
      const content=await report.text()
      assert.doesNotMatch(content,/privateKeys|PRIVATE KEY|secret|pass(word)?=|\/home\/|\/tmp\//i)
      assert.equal(JSON.parse(content).paidCheckoutEnabled,false)
    })
    await t.test('forged publication or actual audit failure turns desk to HOLD and hides old report',async()=>{
      result={...fake,publicationAuthorized:true}
      assert.equal((await http(url,session,'/api/run','POST')).status,202)
      await waitState(url,session,'failed')
      assert.equal((await http(url,session,'/api/report')).status,409)
      result=fake;throwError=true
      assert.equal((await http(url,session,'/api/run','POST')).status,202)
      await waitState(url,session,'failed')
      assert.doesNotMatch(JSON.stringify(await state(url,session)),/OWNER_REAL_FILM|secret/)
      throwError=false
    })
    await t.test('logout revokes authenticated status and reports',async()=>{
      assert.equal((await http(url,session,'/api/logout','POST')).status,200)
      assert.equal((await http(url,session,'/api/status')).status,401)
      assert.equal((await http(url,session,'/api/report')).status,401)
      assert.ok(calls>=3)
    })
  }finally{await desk.close()}
})

test('V39 CLI argument parser never accepts passwords or unknown flags',()=>{
  const paths=['--repo-root','/source','--receipts-dir','/reports','--masters-dir','/masters','--captions-dir','/captions']
  assert.equal(parseDeskArgs(paths).port,0)
  assert.equal(parseDeskArgs([...paths,'--port','12345']).port,12345)
  assert.throws(()=>parseDeskArgs([...paths,'--password','danger']),/argument/)
  assert.throws(()=>parseDeskArgs([...paths,'--port','-1']),/port/)
  assert.throws(()=>parseDeskArgs([...paths,'--port','65536']),/port/)
  assert.throws(()=>parseDeskArgs([...paths,'--port','0','--port','1']),/duplicate/)
})
