import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { join, resolve } from 'node:path'
import ts from 'typescript'
const root=resolve(import.meta.dirname,'..')
const read=p=>readFileSync(join(root,p),'utf8')
const source=read('src/osaCinemaPremiereGate.ts')
const output=ts.transpileModule(source,{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ESNext},reportDiagnostics:true})
assert.equal(output.diagnostics?.filter(x=>x.category===ts.DiagnosticCategory.Error).length||0,0)
const gate=await import('data:text/javascript;base64,'+Buffer.from(output.outputText).toString('base64'))
const receipt={
 schemaVersion:1,project:'OSA CINEMA',status:'PUBLIC_BROWSER_QA_PASS',
 publicationAuthorized:true,paidCheckoutEnabled:false,
 publicPath:'/osa-cinema/premiere/',fullRuSha256:gate.FULL_RU_SHA256,
 assetCount:8,releaseId:'osa-v49-cinema-20261027',
}
test('V49 does not advertise a fake, incomplete or unpublished premiere',()=>{
 assert.equal(gate.isLivePremiereReceipt(null),false)
 assert.equal(gate.isLivePremiereReceipt({}),false)
 assert.equal(gate.isLivePremiereReceipt({...receipt,status:'STAGED_NOT_PUBLIC'}),false)
 assert.equal(gate.isLivePremiereReceipt({...receipt,publicationAuthorized:false}),false)
 assert.equal(gate.isLivePremiereReceipt({...receipt,fullRuSha256:'0'.repeat(64)}),false)
 assert.equal(gate.isLivePremiereReceipt({...receipt,paidCheckoutEnabled:true}),false)
 assert.equal(gate.isLivePremiereReceipt({...receipt,publicPath:'https://other.site/'}),false)
 assert.equal(gate.isLivePremiereReceipt({...receipt,releaseId:'../../etc'}),false)
 assert.equal(gate.isLivePremiereReceipt(receipt),true)
})
test('V49 gate checks real 87MB MP4 HEAD response, not HTML SPA 200',()=>{
 assert.equal(gate.isPlayableFullFilmResponse(200,'text/html',String(gate.FULL_RU_BYTES)),false)
 assert.equal(gate.isPlayableFullFilmResponse(404,'video/mp4',String(gate.FULL_RU_BYTES)),false)
 assert.equal(gate.isPlayableFullFilmResponse(200,'video/mp4','123'),false)
 assert.equal(gate.isPlayableFullFilmResponse(200,'video/mp4',null),false)
 assert.equal(gate.isPlayableFullFilmResponse(200,'video/mp4',String(gate.FULL_RU_BYTES)),true)
})
test('read-only durable media path survives root swap and missing media never SPA-falls back',()=>{
 const compose=read('docker-compose.production.yml'),nginx=read('nginx.conf')
 assert.match(compose,/OSA_CINEMA_MEDIA_ROOT/)
 assert.match(compose,/\/var\/lib\/osgard-cinema-media:ro/)
 assert.match(nginx,/location \^~ \/osa-cinema\/premiere\//)
 assert.match(nginx,/alias \/var\/lib\/osgard-cinema-media\/current\//)
 assert.match(nginx,/video\/mp4 mp4;/)
 assert.match(nginx,/text\/vtt vtt;/)
 assert.match(nginx,/try_files \$uri =404;/)
 assert.match(nginx,/rewrite \^ \/osa-cinema\/premiere\/index\.html last;/)
 const activation=read('scripts/activate-frontend-remote.sh')
 assert.match(activation,/mv \/usr\/share\/nginx\/html/)
 assert.doesNotMatch(activation,/rm -rf \/var\/lib\/osgard-cinema-media/)
})
test('existing cinema keeps its eight scenes and never shows link before the gate',()=>{
 const app=read('src/OSACinema.tsx'),component=read('src/OSACinemaPremiereLink.tsx')
 assert.match(app,/import OSACinemaPremiereLink from '\.\/OSACinemaPremiereLink'/)
 assert.match(app,/<OSACinemaPremiereLink locale=\{locale\}/)
 assert.match(app,/data-cinema-navigation='v46'/)
 assert.match(component,/if \(!available\) return null/)
 assert.match(component,/release\.json/)
 assert.match(component,/method: 'HEAD'/)
 assert.match(component,/isPlayableFullFilmResponse/)
 assert.doesNotMatch(component,/<video\b|checkout\.stripe|stripe\.com/i)
})
test('V20 private publication and commerce locks are preserved until separate film launch',()=>{
 const p=JSON.parse(read('docs/OSA_CINEMA_V20_PRIVATE_RELEASE_POLICY.json'))
 assert.equal(p.publicationAuthorized,false)
 assert.equal(p.rightsCleared,false)
 assert.equal(p.paidCheckoutEnabled,false)
})
