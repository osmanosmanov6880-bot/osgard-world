import { test } from 'node:test'
import { strict as assert } from 'node:assert'
import { checkNewerLiveRelease, isStrictlyNewerCompare } from './omega-live-release-supersession.mjs'
const OLD = 'a'.repeat(40)
const NEW = 'b'.repeat(40)
const reply = (payload, status=200) =>
  async()=>({ok:status===200,status,json:async()=>payload})
const cfg={repository:'osmanosmanov6880-bot/osgard-world',token:'test-readonly-token'}

test('exact version always requires authentic Chromium gameplay test',async()=>{
  const a=await checkNewerLiveRelease(OLD,OLD,cfg)
  assert.equal(a.superseded,false)
  assert.equal(a.reason,'exact_match')
})

test('GitHub-proven strict descendant is superseded, not failed release',async()=>{
  const a=await checkNewerLiveRelease(OLD,NEW,{
    ...cfg,fetchImpl:reply({status:'ahead',ahead_by:3,behind_by:0})
  })
  assert.deepEqual(a,{superseded:true,reason:'verified_newer_deployed_source',commits_ahead:3})
})

test('older published source must not skip a stale deployment failure',async()=>{
  const a=await checkNewerLiveRelease(OLD,NEW,{
    ...cfg,fetchImpl:reply({status:'behind',ahead_by:0,behind_by:3})
  })
  assert.equal(a.superseded,false)
})

test('diverged game histories and different forks never skip verification',async()=>{
  const a=await checkNewerLiveRelease(OLD,NEW,{
    ...cfg,fetchImpl:reply({status:'diverged',ahead_by:5,behind_by:3})
  })
  assert.equal(a.superseded,false)
})

test('trivial same-commit response and invalid SHA cannot supersede',async()=>{
  assert.equal(isStrictlyNewerCompare(OLD,NEW,{status:'ahead',ahead_by:0,behind_by:0}),false)
  assert.equal(isStrictlyNewerCompare(OLD,NEW,{status:'ahead',ahead_by:2,behind_by:1}),false)
  assert.equal((await checkNewerLiveRelease(OLD,'not-a-commit',cfg)).superseded,false)
})

test('GitHub 404, API outage or credentials unavailable fail closed',async()=>{
  const missing=await checkNewerLiveRelease(OLD,NEW,{...cfg,fetchImpl:reply({},404)})
  assert.equal(missing.superseded,false)
  const down=await checkNewerLiveRelease(OLD,NEW,{
    ...cfg,fetchImpl:async()=>{throw Error('offline')}
  })
  assert.equal(down.superseded,false)
  const token=await checkNewerLiveRelease(OLD,NEW,{...cfg,token:''})
  assert.equal(token.superseded,false)
})

test('validated GitHub destination prevents untrusted manifest URL injection',async()=>{
  let called=false
  const proof=await checkNewerLiveRelease(OLD,NEW,{
    ...cfg,repository:'evil.com/../api',fetchImpl:async()=>{called=true;return {}}
  })
  assert.equal(proof.superseded,false)
  assert.equal(called,false)
})

test('release check never skips if GitHub returns success-shaped non-data',async()=>{
  const proof=await checkNewerLiveRelease(OLD,NEW,{
    ...cfg,fetchImpl:reply({ahead_by:3,behind_by:0})
  })
  assert.equal(proof.superseded,false)
})
