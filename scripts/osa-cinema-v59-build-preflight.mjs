import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'
const htmlPath='dist/osa-cinema/studio/production/index.html'
assert.ok(existsSync(htmlPath),'Production planner needs a physical direct-load HTML shell')
const html=readFileSync(htmlPath,'utf8')
const canonical='https://osgard.world/osa-cinema/studio/production'
assert.match(html,/<title>Производственный кабинет — OSA CINEMA<\/title>/)
assert.match(html,/<meta name="robots" content="noindex,follow"/)
assert.ok(html.includes('<link rel="canonical" href="'+canonical+'"'),'Direct-link canonical missing')
assert.ok(html.includes('property="og:url" content="'+canonical+'"'),'OpenGraph deep link missing')
assert.doesNotMatch(html,/<video|<source|VideoObject/)
const app=readFileSync('src/OSACinemaProductionDesk.tsx','utf8')
const gates=readFileSync('src/osaCinemaProductionPlan.ts','utf8')
const record=JSON.parse(readFileSync('docs/OSA_CINEMA_V53_CONCEPT_EVIDENCE_20261028.json','utf8'))
assert.match(app,/data-studio-release="no-go"/)
assert.match(gates,/publicReleaseApproved:false/)
assert.equal(record.actorSceneProduction.scenesFilmed,0)
assert.equal(record.publicReleaseAuthorized,false)
console.log(JSON.stringify({status:'PASS',privateProductionShell:true,noindex:true,release:'NO_GO',verifiedScenesFilmed:0}))
