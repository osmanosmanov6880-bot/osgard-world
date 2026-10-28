import assert from 'node:assert/strict'
import { existsSync,readFileSync } from 'node:fs'
import { build } from 'esbuild'
import { makePressKit,renderPressText } from './osa-cinema-v60-press-kit.mjs'
const read=p=>readFileSync(p,'utf8')
const pubPath='dist/osa-cinema/studio/press'
const privatePath='dist/osa-cinema/studio/distribution/index.html'
const publicHtml=pubPath+'/index.html'
assert.ok(existsSync(publicHtml),'World pressroom needs physical HTML shell')
assert.ok(existsSync(privatePath),'Distribution desk needs physical HTML shell')
const pressPage=read(publicHtml),desk=read(privatePath)
assert.match(pressPage,/<title>OSA CINEMA — Международный пресс-центр<\/title>/)
assert.match(pressPage,/<meta name="robots" content="index,follow"/)
assert.ok(pressPage.includes('https://osgard.world/osa-cinema/studio/press'))
assert.match(desk,/<meta name="robots" content="noindex,follow"/)
assert.match(desk,/<title>OSA CINEMA — Локальный контроль дистрибуции<\/title>/)
assert.doesNotMatch(pressPage+desk,/"VideoObject"|<video\b/)
const sitemap=read('public/sitemap.xml')
assert.ok(sitemap.includes('<loc>https://osgard.world/osa-cinema/studio/press</loc>'))
assert.ok(!sitemap.includes('<loc>https://osgard.world/osa-cinema/studio/distribution</loc>'))
const bundle=async p=>{
  const result=await build({entryPoints:[p],bundle:true,write:false,format:'esm',platform:'node'})
  return import('data:text/javascript;base64,'+Buffer.from(result.outputFiles[0].text).toString('base64'))
}
const [catalog,gateModule]=await Promise.all([bundle('src/osaCinemaStudioRegistry.ts'),bundle('src/osaCinemaDistribution.ts')])
const v53=JSON.parse(read('docs/OSA_CINEMA_V53_CONCEPT_EVIDENCE_20261028.json'))
const expected=makePressKit(catalog.studioWorks,v53,[gateModule.publicReleaseDecision('zero-window'),gateModule.publicReleaseDecision('threshold')])
const jsonFile=pubPath+'/press.v1.json'
const ruFile=pubPath+'/press.ru.txt',enFile=pubPath+'/press.en.txt'
for(const f of [jsonFile,ruFile,enFile])assert.ok(existsSync(f),'Missing static press delivery '+f)
assert.deepEqual(JSON.parse(read(jsonFile)),expected)
assert.equal(read(ruFile),renderPressText(expected,'ru'))
assert.equal(read(enFile),renderPressText(expected,'en'))
assert.ok(!read(jsonFile).includes('"VideoObject"'))
assert.ok(!read(jsonFile).includes('local_device_only'))
assert.equal(expected.publicPremiereAuthorized,false)
console.log(JSON.stringify({status:'PASS',publicPress:true,pressFiles:3,projects:3,privateDeskNoIndex:true,moviePremiere:'NO_GO',verifiedFilmedScenes:0}))
