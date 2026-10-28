import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// R138 production contract. Do NOT resurrect the historical automatic
// workflow_run -> SSH release when modernizing CI. A CI success is not a
// release authorization.
const direct = readFileSync('.github/workflows/omega-web-direct-deploy.yml','utf8')
const exporter = readFileSync('.github/workflows/omega-godot-web.yml','utf8')

function manualOnly(name, source) {
 const trigger = source.match(/^on:\s*\n([\s\S]*?)^permissions:/m)
 assert.ok(trigger, name + ' must declare explicit on: / permissions: block')
 assert.match(trigger[1],/^  workflow_dispatch:/m)
 assert.doesNotMatch(trigger[1],/^  (?:push|pull_request|workflow_run|schedule):/m,
   name + ' must never release in response to CI, merged code or a schedule')
}
test('native exporter and direct SSH release have manual-only triggers',()=>{
 manualOnly('Godot exporter',exporter)
 manualOnly('direct SSH publisher',direct)
 assert.match(exporter,/name: OSGARD Empire Omega native Godot Web/)
 assert.match(direct,/permissions:\s*\n\s*contents: read/)
})
test('independent exact-SHA ticket and four human approvals gate both stages',()=>{
 for (const [name,workflow,role] of [
   ['exporter',exporter,'build'], ['SSH',direct,'deploy']
 ]) {
   assert.match(workflow,/scripts\/omega-r138-manual-release-guard\.py/,name)
   assert.match(workflow,new RegExp('--role '+role),name)
   for (const option of ['--requested-sha','--approved-sha','--enabled',
      '--confirm','--ticket','--admin-ticket','--art','--gameplay',
      '--physical','--rollback']) {
     assert.ok(workflow.includes(option),name+' missing '+option)
   }
   for (const repoSetting of ['OMEGA_RELEASE_APPROVED_SHA',
     'OMEGA_RELEASE_APPROVED_TICKET','OMEGA_RELEASE_ENABLED',
     'OMEGA_RELEASE_ART_GO','OMEGA_RELEASE_GAMEPLAY_GO',
     'OMEGA_RELEASE_PHYSICAL_GO','OMEGA_RELEASE_ROLLBACK_GO']) {
     assert.ok(workflow.includes(repoSetting),name+' missing '+repoSetting)
   }
 }
 assert.match(direct,/github\.ref|BRANCH_REF/)
 assert.match(exporter,/github\.ref|BRANCH_REF/)
})
test('preflight and remote activation require original release, SHA and rollback',()=>{
 assert.match(direct,/omega-live-integrity\.py --self-test/)
 assert.match(direct,/release\.json/)
 assert.match(direct,/sha256sum -c SHA256SUMS\.txt/)
 assert.match(direct,/deploy-omega-native-remote\.sh/)
 assert.match(direct,/omega-build-freshness\.py/)
 assert.match(direct,/--base https:\/\/osgard\.world\/games\/omega-3d-preview/)
 assert.match(direct,/--expected public\/games\/omega-3d-preview\/release\.json/)
 assert.match(exporter,/public\/games\/omega-3d-preview/)
 assert.doesNotMatch(exporter,/^on:\s*\n\s*push:/m)
})
