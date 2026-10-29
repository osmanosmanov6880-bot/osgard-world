import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { build } from 'esbuild'
const compiled=await build({entryPoints:['src/osaCinemaProductionPlan.ts'],platform:'node',format:'esm',bundle:true,write:false})
const m=await import('data:text/javascript;base64,'+Buffer.from(compiled.outputFiles[0].text).toString('base64'))
const evidence=JSON.parse(readFileSync('docs/OSA_CINEMA_V53_CONCEPT_EVIDENCE_20261028.json','utf8'))
const now='2026-10-28T19:00:00.000Z'
const id='t-v59unit-test-0001'
const base={sceneId:'S02',title:'Audit location agreement',category:'rights',owner:'Producer',dueDate:'2026-11-12',notes:'Owner-local task; not a rights receipt.'}
const good=m.createProductionTask(base,now,id)

test('V59 immutable production facts match primary V53 evidence, with public film NO_GO',()=>{
 assert.ok(good)
 assert.equal(m.PRODUCTION_PROJECT_ID,'zero-window')
 assert.equal(m.PLANNED_SCENES,evidence.actorSceneProduction.scenesPlanned)
 assert.equal(m.PROPOSED_SHOTS,evidence.actorSceneProduction.shotsProposed)
 assert.equal(m.VERIFIED_ACTOR_SCENES_FILMED,evidence.actorSceneProduction.scenesFilmed)
 assert.equal(m.TARGET_FILM_SECONDS,evidence.actorSceneProduction.shortTargetSeconds)
 assert.deepEqual(m.PRODUCTION_SCENE_IDS,Array.from({length:13},(_,i)=>'S'+String(i+1).padStart(2,'0')))
 assert.equal(evidence.actorSceneProduction.shotsFilmed,0)
 assert.equal(evidence.publicReleaseAuthorized,false)
 assert.equal(evidence.premiereUrl,null)
 assert.equal(m.productionStatistics(Array(13).fill(good)).publicReleaseApproved,false)
 assert.equal(m.productionStatistics([good]).verifiedActorScenesFilmed,0)
})
test('Strict model supports validated user drafts only, never scene filming receipts',()=>{
 assert.deepEqual(m.validateProductionPlan([good]),[good])
 assert.equal(m.validateProductionPlan([{...good,sceneId:'S14'}]),null)
 assert.equal(m.validateProductionPlan([{...good,sceneId:'../../admin'}]),null)
 assert.equal(m.validateProductionPlan([{...good,id:'malicious'}]),null)
 assert.equal(m.validateProductionPlan([{...good,title:''}]),null)
 assert.equal(m.validateProductionPlan([{...good,title:'A'.repeat(121)}]),null)
 assert.equal(m.validateProductionPlan([{...good,owner:'X'.repeat(81)}]),null)
 assert.equal(m.validateProductionPlan([{...good,notes:'X'.repeat(601)}]),null)
 assert.equal(m.validateProductionPlan([{...good,dueDate:'2026-02-31'}]),null)
 assert.equal(m.validateProductionPlan([{...good,status:'filmed'}]),null)
 assert.equal(m.validateProductionPlan([{...good,status:'published'}]),null)
 assert.equal(m.validateProductionPlan([good,good]),null)
 assert.equal(m.validateProductionPlan(Array(101).fill(good)),null)
 assert.equal(m.createProductionTask({...base,title:'   '},now,id),null)
 assert.deepEqual(m.validateProductionPlan([]),[])
})
test('Planning task state transitions are real but cannot approve cinema release',()=>{
 const progressed=m.updateProductionTask([good],id,'in_progress','2026-10-28T20:00:00.000Z')
 assert.ok(progressed)
 assert.equal(progressed[0].status,'in_progress')
 const review=m.updateProductionTask(progressed,id,'ready_for_review','2026-10-28T21:00:00.000Z')
 assert.equal(review[0].status,'ready_for_review')
 const stats=m.productionStatistics(review)
 assert.equal(stats.readyForReview,1)
 assert.equal(stats.inProgress,0)
 assert.equal(stats.publicReleaseApproved,false)
 assert.equal(stats.verifiedActorScenesFilmed,0)
 assert.equal(m.updateProductionTask([good],id,'published'),null)
 assert.equal(m.updateProductionTask([good],'not-an-id','planned'),null)
})
test('Portable JSON is versioned, bounded and fails closed under tampering',()=>{
 const backup=m.exportProductionBackup([good],now)
 const parsed=JSON.parse(backup)
 assert.equal(parsed.schema,'OSA_CINEMA_PRODUCTION_DRAFT_V1')
 assert.equal(parsed.project,'zero-window')
 assert.equal(parsed.storage,'local_device_only')
 assert.equal(parsed.dataIsNotFilmingEvidence,true)
 assert.equal(parsed.publicReleaseAuthorized,false)
 assert.deepEqual(m.parseProductionBackup(backup),[good])
 const mutate=data=>JSON.stringify({...parsed,...data})
 for(const invalid of ['','{','invalid','X'.repeat(66000),mutate({schema:'MODIFIED'}),
  mutate({version:2}),mutate({project:'threshold'}),mutate({storage:'server'}),
  mutate({dataIsNotFilmingEvidence:false}),mutate({publicReleaseAuthorized:true}),
  mutate({generatedAt:'bad'}),mutate({tasks:'not an array'}),
  mutate({tasks:[{...good,status:'filmed'}]}),mutate({tasks:[good,good]})]){
  assert.equal(m.parseProductionBackup(invalid),null)
 }
 assert.throws(()=>m.exportProductionBackup([good,good],now))
})
test('CSV escapes spreadsheet formulas and embedded commas, quotes and newlines',()=>{
 const dangerous={
  ...good,title:'=HYPERLINK("https://example.invalid")',owner:'+SUM(1,1)',
  notes:'@danger\nunsafe, "quotes" and newlines'
 }
 const csv=m.exportProductionCsv([dangerous])
 assert.ok(csv.startsWith('\uFEFF"scene_id"'))
 assert.ok(csv.includes('"\'=HYPERLINK(""https://example.invalid"")"'))
 assert.ok(csv.includes('"\'+SUM(1,1)"'))
 assert.ok(csv.includes('"\'@danger\nunsafe, ""quotes"" and newlines"'))
 assert.ok(csv.endsWith('\r\n'))
 assert.doesNotMatch(csv,/[,\r\n]=HYPERLINK/)
})
test('Local-only operations fail safely without a browser storage context',()=>{
 assert.deepEqual(m.readProductionPlan(),[])
 assert.equal(m.saveProductionPlan([good]),false)
 assert.equal(m.saveProductionPlan([{...good,status:'filmed'}]),false)
})
test('Production desk uses private SPA route, no-index shell and real user-state controls',()=>{
 const read=path=>readFileSync(path,'utf8')
 const app=read('src/main.tsx')
 const routing=read('src/osgardRouting.ts')
 const builder=read('scripts/build-brand-routes.mjs')
 const seo=read('src/routeSeo.ts')
 const ui=read('src/OSACinemaProductionDesk.tsx')
 assert.match(app,/import\('\.\/OSACinemaProductionDesk'\)/)
 assert.match(app,/path === '\/osa-cinema\/studio\/production'/)
 assert.match(routing,/\/osa-cinema\/studio\/production/)
 assert.match(builder,/osa-cinema\/studio\/production/)
 assert.match(builder,/osa-cinema\/studio\/production'\]\.includes\(path\)/)
 assert.match(seo,/\/osa-cinema\/studio\/production/)
 assert.match(ui,/data-studio-release="no-go"/)
 assert.match(ui,/saveProductionPlan/)
 assert.match(ui,/subscribeProductionPlan/)
 assert.match(ui,/parseProductionBackup/)
 assert.match(ui,/exportProductionCsv/)
 assert.doesNotMatch(ui,/<video|\.mp4|checkout|publicationAuthorized:true/i)
 assert.match(read('src/osaCinemaProductionDesk.css'),/@media\(max-width:600px\)/)
})

test('V59 portable backups enforce real UTF-8 byte budgets and ISO timestamps',()=>{
 assert.equal(m.MAX_PRODUCTION_IMPORT_BYTES,65536)
 assert.ok(m.MAX_PRODUCTION_STORE_BYTES<m.MAX_PRODUCTION_IMPORT_BYTES)
 const tooLarge=Array.from({length:100},(_,i)=>({
  ...good,id:'t-v59unit-multibyte-'+String(i).padStart(4,'0'),
  notes:'Ж'.repeat(600)
 }))
 assert.ok(m.validateProductionPlan(tooLarge))
 assert.throws(()=>m.exportProductionBackup(tooLarge,now),/size/)
 assert.equal(m.parseProductionBackup(m.exportProductionBackup([good],now).replace('"generatedAt": "2026-10-28T19:00:00.000Z"','"generatedAt": "2026-10-28T19:00:00"')),null)
 assert.equal(m.validateProductionPlan([{...good,updatedAt:'2026-10-28T19:00:00'}]),null)
 const note='🚀'.repeat(600)
 assert.equal(m.validateProductionPlan([{...good,notes:note}]),null)
})
