import test from 'node:test'
import assert from 'node:assert/strict'
import {readFileSync} from 'node:fs'
import {join,resolve} from 'node:path'
import ts from 'typescript'

const root=resolve(import.meta.dirname,'..')
const helperSource=readFileSync(join(root,'src/osaCinemaCompanionText.ts'),'utf8')
const compiled=ts.transpileModule(helperSource,{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ESNext},reportDiagnostics:true})
assert.equal(compiled.diagnostics?.filter(d=>d.category===ts.DiagnosticCategory.Error).length||0,0)
const {readCinemaRoute,getCinemaScenePath}=await import('data:text/javascript;base64,'+Buffer.from(compiled.outputText).toString('base64'))
const app=readFileSync(join(root,'src/OSACinema.tsx'),'utf8')
const workflow=readFileSync(join(root,'.github/workflows/osa-cinema-v44-live-acceptance.yml'),'utf8')
const local=readFileSync(join(root,'playwright.ecosystem.config.mjs'),'utf8')
const live=readFileSync(join(root,'playwright.osa-cinema-v44-live.config.mjs'),'utf8')
const spec=readFileSync(join(root,'scripts/osa-cinema-v46-history.spec.mjs'),'utf8')
const rights=JSON.parse(readFileSync(join(root,'docs/OSA_CINEMA_V20_PRIVATE_RELEASE_POLICY.json'),'utf8'))

test('V46 route parser accepts all eight chapters in either language',()=>{
  for(let i=0;i<8;i++)for(const lang of ['ru','en'])
    assert.deepEqual(readCinemaRoute('?scene='+i+'&lang='+lang,8),{sceneIndex:i,locale:lang})
})
test('V46 refuses duplicate, malformed and out-of-range scene and language query parameters',()=>{
  for(const s of ['-1','8','08','1e0','2.5','NaN','9999999999999999999999999999'])
    assert.equal(readCinemaRoute('?scene='+s,8).sceneIndex,null,s)
  assert.equal(readCinemaRoute('?scene=2&scene=4',8).sceneIndex,null)
  for(const q of ['?lang=de','?lang=ru&lang=en','?lang=Ru'])
    assert.equal(readCinemaRoute(q,8).locale,null,q)
  assert.deepEqual(readCinemaRoute('?ref=archive',8),{sceneIndex:null,locale:null})
})
test('V46 same-document history keeps unrelated query parameters and page anchors',()=>{
  assert.equal(getCinemaScenePath('/osa-cinema','?lang=ru&scene=1&ref=archive','#osa42-story','en',6,8),
    '/osa-cinema?lang=en&scene=6&ref=archive#osa42-story')
  assert.throws(()=>getCinemaScenePath('/osa-cinema','','','ru',8,8),RangeError)
})
test('V46 React history, popstate recovery and accessible headings are connected',()=>{
  assert.match(app,/window\.history\.pushState\(/)
  assert.match(app,/addEventListener\('popstate',onHistory\)/)
  assert.match(app,/readCinemaRoute\(window\.location\.search,scenes\.ru\.length\)/)
  assert.match(app,/data-cinema-release='v44' data-cinema-navigation='v46'/)
  assert.match(app,/osa42-scene-heading' aria-live='polite' aria-atomic='true'/)
  assert.match(spec,/page\.goBack\(\)/)
  assert.match(spec,/page\.goForward\(\)/)
  assert.match(spec,/page\.reload/)
})
test('V46 premerge and live suites remain gated; films, rights and checkout remain NO-GO',()=>{
  assert.match(local,/osa-cinema-v46-history\.spec\.mjs/)
  assert.match(live,/osa-cinema-v46-history\.spec\.mjs/)
  assert.match(workflow,/scripts\/osa-cinema-v46-route-contract\.test\.mjs/)
  assert.match(workflow,/src\/osaCinemaCompanionText\.ts/)
  assert.match(workflow,/github.event.workflow_run.conclusion == 'success'/)
  assert.match(workflow,/github.event.workflow_run.head_branch == 'master'/)
  assert.match(spec,/OSGARD_DEPLOY_SHA/)
  assert.equal(rights.publicationAuthorized,false)
  assert.equal(rights.rightsCleared,false)
  assert.equal(rights.paidCheckoutEnabled,false)
})
