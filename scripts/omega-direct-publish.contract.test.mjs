import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const direct=readFileSync('.github/workflows/omega-web-direct-deploy.yml','utf8')
const exporter=readFileSync('.github/workflows/omega-godot-web.yml','utf8')
const guard=readFileSync('scripts/omega-r138-manual-release-guard.py','utf8')
function triggers(workflow){
 const match=workflow.match(/\non:\n([\s\S]*?)\npermissions:/)
 assert.ok(match,'Expected explicit event trigger in release workflow')
 return match[1]
}

test('verified original Godot export requires independently reviewed MANUAL GO; never auto SSH',()=>{
 assert.match(exporter,/name: OSGARD Empire Omega native Godot Web/)
 for(const [name,workflow] of [['exporter',exporter],['direct SSH',direct]]){
  const event=triggers(workflow)
  assert.match(event,/^  workflow_dispatch:/m,name+' must be manual-only')
  assert.doesNotMatch(event,/^  (?:push|workflow_run):/m,name+' cannot publish from a push or successful other job')
  for(const field of ['approved_source_sha','release_ticket','production_confirmation']){
   assert.match(event,new RegExp('^      '+field+':','m'),name+' missing explicit operator review')
  }
  assert.match(workflow,/scripts\/omega-r138-manual-release-guard\.py/)
  assert.match(workflow,/R138 HARD/)
 }
 assert.ok(exporter.indexOf('R138 HARD')<exporter.indexOf('setup-godot'))
 assert.ok(direct.indexOf('R138 HARD')<direct.indexOf('Configure SSH'))
})

test('the deployment rejects untrusted/ref-mismatched requests and missing four reviews before SSH',()=>{
 for(const field of ['ART_APPROVAL','GAMEPLAY_APPROVAL','PHYSICAL_APPROVAL',
   'ROLLBACK_APPROVAL','ADMIN_SHA','ADMIN_TICKET','RELEASE_ENABLED',
   'REQUESTED_SHA','REQUESTED_TICKET','PRODUCTION_CONFIRM','BRANCH_REF','EVENT_NAME']){
  assert.match(exporter,new RegExp(field))
  assert.match(direct,new RegExp(field))
 }
 assert.match(direct,/permissions:\s*\n\s*contents: read/)
 assert.match(guard,/refs\/heads\/master/)
 assert.match(guard,/I_AUTHORIZE_OMEGA_PRODUCTION/)
 assert.match(guard,/APPROVED/)
 assert.match(guard,/workflow_dispatch/)
 assert.match(guard,/approved_sha/)
 assert.match(guard,/admin_ticket/)
 assert.match(guard,/production_authorized/)
})

test('original binary SHA, source-freshness and rollback are still mandatory once separately approved',()=>{
 assert.match(direct,/omega-live-integrity\.py --self-test/)
 assert.match(direct,/release\.json/)
 assert.match(direct,/sha256sum -c SHA256SUMS\.txt/)
 assert.match(direct,/deploy-omega-native-remote\.sh/)
 assert.match(direct,/--base https:\/\/osgard\.world\/games\/omega-3d-preview/)
 assert.match(direct,/--expected public\/games\/omega-3d-preview\/release\.json/)
 assert.match(direct,/omega-build-freshness\.py/)
 assert.match(exporter,/omega-build-freshness\.py/)
 assert.match(exporter,/gh workflow run deploy-frontend\.yml --ref master/)
})
