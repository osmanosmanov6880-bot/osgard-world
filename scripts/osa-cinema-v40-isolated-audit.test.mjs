import { test } from 'node:test'
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { mkdtemp, writeFile, rm, readFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { realpath } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { runIsolatedPrivateAudit } from './osa-cinema-v40-isolated-audit.mjs'
import { validateWorkerConfiguration } from './osa-cinema-v40-audit-worker.mjs'

const options={repoRoot:'/repo',receiptsDir:'/receipts',mastersDir:'/masters',captionsDir:'/captions'}
const sleep = ms => new Promise(ok=>setTimeout(ok,ms))
async function fixture(fn) {
  const dir=await mkdtemp(join(await realpath(tmpdir()),'osa-v40-worker-test-'))
  try { return await fn(dir) } finally { await rm(dir,{recursive:true,force:true}) }
}
const source=path=>`import { writeFile } from 'node:fs/promises'\n${path}`

test('V40 worker strictly validates schema, required local roots and all-or-none signer settings',()=>{
  assert.deepEqual(validateWorkerConfiguration(options),options)
  for (const bad of [null,[],{...options, injected:'file'}, {...options,repoRoot:''},
    {...options, registryPath:'/keys'}, {...options,registrySha256:'x'.repeat(64)},
    {repoRoot:'/repo'}, {...options, mastersDir:1234}]) {
    assert.throws(()=>validateWorkerConfiguration(bad))
  }
  const withSigner={...options,registryPath:'/registry',registrySha256:'a'.repeat(64),
    attestationsPath:'/signed',evidenceDir:'/pdf'}
  assert.deepEqual(validateWorkerConfiguration(withSigner),withSigner)
})

test('V40 parent subprocess drops owner password, NODE_OPTIONS, tokens and argv file locations',
  {timeout:10000},()=>fixture(async dir=>{
    const worker=join(dir,'isolated-env-worker.mjs')
    await writeFile(worker,source(`const input = await new Promise(resolve=>{let s='';process.stdin.on('data',c=>s+=c);process.stdin.on('end',()=>resolve(JSON.parse(s)))})
      process.stdout.write(JSON.stringify({passwordPresent:!!process.env.OSA_CINEMA_OWNER_PASSWORD,
        optionsPresent:!!process.env.NODE_OPTIONS,
        fakeTokenPresent:!!process.env.SECRET_UNIT_TEST_TOKEN,
        argv:process.argv.slice(2),receivedConfig:input.repoRoot}));`))
    const oldPwd=process.env.OSA_CINEMA_OWNER_PASSWORD
    const oldToken=process.env.SECRET_UNIT_TEST_TOKEN
    try{
      process.env.OSA_CINEMA_OWNER_PASSWORD='test-owner-password-not-a-real-secret'
      process.env.SECRET_UNIT_TEST_TOKEN='should-not-cross-to-worker'
      const report=await runIsolatedPrivateAudit(options,{workerPath:worker})
      assert.equal(report.passwordPresent,false)
      assert.equal(report.fakeTokenPresent,false)
      assert.equal(report.optionsPresent,false)
      assert.deepEqual(report.argv,[])
      assert.equal(report.receivedConfig,'/repo')
    }finally{
      if(oldPwd===undefined)delete process.env.OSA_CINEMA_OWNER_PASSWORD
      else process.env.OSA_CINEMA_OWNER_PASSWORD=oldPwd
      if(oldToken===undefined)delete process.env.SECRET_UNIT_TEST_TOKEN
      else process.env.SECRET_UNIT_TEST_TOKEN=oldToken
    }
  }))

test('V40 cancels running subprocess promptly (no timeout-only UI fiction)',
  {timeout:10000},()=>fixture(async dir=>{
    const worker=join(dir,'isolated-hanging-worker.mjs')
    const indicator=join(dir,'worker-running.txt')
    await writeFile(worker,source(`await writeFile(${JSON.stringify(indicator)},String(process.pid));
      setInterval(()=>{},1000)`))
    const controller=new AbortController()
    const pending=runIsolatedPrivateAudit(options,{workerPath:worker,signal:controller.signal})
    for(let i=0;i<100;i++){
      try { if((await readFile(indicator,'utf8')).length>0) break }catch{}
      await sleep(20)
    }
    assert.ok((await readFile(indicator,'utf8')).length>0,'subprocess must actually start')
    controller.abort()
    await assert.rejects(pending,/OSA_V40_ISOLATED_HOLD/)
    assert.equal(controller.signal.aborted,true)
  }))

test('V40 rejects empty, malformed, oversized and nonzero worker output without exposing details',
  {timeout:15000},()=>fixture(async dir=>{
    const bad={
      empty:'process.exit(0)',
      invalid:"process.stdout.write('not-json')",
      oversized:"process.stdout.write('x'.repeat(25000))",
      exit:"console.error('/private/real/movie.mp4');process.exit(17)",
    }
    for(const [name,code] of Object.entries(bad)){
      const path=join(dir,name+'.mjs')
      await writeFile(path,code)
      await assert.rejects(runIsolatedPrivateAudit(options,{workerPath:path}),err=>{
        assert.equal(err.message,'OSA_V40_ISOLATED_HOLD: private audit was cancelled or rejected')
        return true
      },name)
    }
  }))

test('V40 already aborted, unknown options and overlong config fail before child runs',async()=>{
  const controller=new AbortController();controller.abort()
  await assert.rejects(runIsolatedPrivateAudit(options,{signal:controller.signal}),/ISOLATED_HOLD/)
  await assert.rejects(runIsolatedPrivateAudit({...options,password:'do-not-send'}),/ISOLATED_HOLD/)
  await assert.rejects(runIsolatedPrivateAudit({...options,repoRoot:'x'.repeat(8500)}),/ISOLATED_HOLD/)
})

test('V40 real worker rejects a leaked password and never prints sensitive system paths',()=>{
  const worker=new URL('./osa-cinema-v40-audit-worker.mjs',import.meta.url)
  const run=spawnSync(process.execPath,[fileURLToPath(worker)],{
    input:JSON.stringify(options),encoding:'utf8',timeout:3000,
    env:{PATH:process.env.PATH,OSA_CINEMA_OWNER_PASSWORD:'forbidden-owner-credential'}})
  assert.equal(run.status,1)
  assert.equal(run.stdout,'')
  assert.doesNotMatch(run.stderr,/forbidden-owner-credential|\/repo|\/masters|\/receipts/)
})

// Integration of the new cancellation contract with the actual password/CSRF desk.
import { startPrivateOwnerDesk } from './osa-cinema-v39-owner-desk.mjs'

async function ownerSession(url) {
  const initial=await fetch(url+'/')
  const html=await initial.text()
  const challenge=html.match(/name="csrf" value="([a-f0-9]{64})"/)?.[1]
  assert.ok(challenge)
  const password='v40-owner-test-only-password-secret'
  const signed=await fetch(url+'/login',{method:'POST',redirect:'manual',headers:{
    Origin:url,Cookie:(initial.headers.get('set-cookie')||'').split(';')[0],
    'Content-Type':'application/x-www-form-urlencoded',
  },body:new URLSearchParams({csrf:challenge,password})})
  assert.equal(signed.status,303)
  const cookie=(signed.headers.get('set-cookie')||'').split(';')[0]
  const dashboard=await (await fetch(url+'/',{headers:{Cookie:cookie}})).text()
  const csrf=dashboard.match(/const csrf='([a-f0-9]{64})'/)?.[1]
  assert.ok(csrf)
  const post=path=>fetch(url+path,{method:'POST',headers:{Cookie:cookie,Origin:url,'X-OSA-CSRF':csrf}})
  const get=path=>fetch(url+path,{headers:{Cookie:cookie}})
  return {post,get}
}

test('V40 owner logout revokes report and aborts the active isolated-audit contract',
  {timeout:10000},async()=>{
    let captured=null
    const desk=await startPrivateOwnerDesk({password:'v40-owner-test-only-password-secret',
      audit:(_,{signal})=>{captured=signal;return new Promise(()=>{})}})
    try {
      const user=await ownerSession(desk.url)
      assert.equal((await user.post('/api/run')).status,202)
      for(let i=0;i<25 && !captured;i++)await sleep(10)
      assert.ok(captured)
      assert.equal(captured.aborted,false)
      assert.equal((await user.post('/api/logout')).status,200)
      assert.equal(captured.aborted,true)
      assert.equal((await user.get('/api/status')).status,401)
      assert.equal((await user.get('/api/report')).status,401)
    } finally {await desk.close()}
  })

test('V40 timeout and application shutdown signal cancellation, with permanent HOLD',
  {timeout:10000},async()=>{
    let captured=null
    const desk=await startPrivateOwnerDesk({password:'v40-owner-test-only-password-secret',
      auditTimeoutMs:35,audit:(_,{signal})=>{captured=signal;return new Promise(()=>{})}})
    const user=await ownerSession(desk.url)
    assert.equal((await user.post('/api/run')).status,202)
    await sleep(120)
    assert.equal(captured?.aborted,true)
    const status=await (await user.get('/api/status')).json()
    assert.equal(status.state,'failed')
    assert.equal(status.summary,null)
    await desk.close()
  })
