import assert from 'node:assert/strict'
import { readFileSync, existsSync } from 'node:fs'
import { build } from 'esbuild'
import { createPublicCinemaCatalog } from './osa-cinema-public-catalog.mjs'
const bundle=await build({entryPoints:['src/osaCinemaStudioRegistry.ts'],bundle:true,write:false,format:'esm',platform:'node'})
const {studioWorks}=await import('data:text/javascript;base64,'+Buffer.from(bundle.outputFiles[0].text).toString('base64'))
const expected=createPublicCinemaCatalog(studioWorks)
const catalogPath='dist/osa-cinema/studio/catalog.v1.json'
const libraryPath='dist/osa-cinema/studio/library/index.html'
assert.ok(existsSync(catalogPath),'V58 public catalogue JSON not built')
assert.ok(existsSync(libraryPath),'V58 library deep-link HTML not built')
const actual=JSON.parse(readFileSync(catalogPath,'utf8'))
assert.deepEqual(actual,expected,'Public catalog must match canonical typed registry')
const html=readFileSync(libraryPath,'utf8')
assert.match(html,/<meta name="robots" content="noindex,follow"/)
assert.match(html,/<title>Моя коллекция — OSA CINEMA<\/title>/)
assert.match(html,/https:\/\/osgard.world\/osa-cinema\/studio\/library/)
assert.doesNotMatch(html,/"VideoObject"/)
const privateData=JSON.stringify(actual)
assert.doesNotMatch(privateData,/watchlist|favorites|account|\btoken\b|private_key|\.mp4|\.m3u8/i)
console.log(JSON.stringify({status:'PASS',publicProjects:actual.total,bilingual:actual.languages,videoPremiere:false,privateLibraryNoIndex:true,routeShell:true}))
