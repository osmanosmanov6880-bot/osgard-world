import test from 'node:test'
import assert from 'node:assert/strict'
import { build } from 'esbuild'
import { createPublicCinemaCatalog, PUBLIC_CATALOG_SCHEMA } from './osa-cinema-public-catalog.mjs'
const b=await build({entryPoints:['src/osaCinemaStudioRegistry.ts'],bundle:true,write:false,format:'esm',platform:'node'})
const {studioWorks}=await import('data:text/javascript;base64,'+Buffer.from(b.outputFiles[0].text).toString('base64'))
const catalogue=createPublicCinemaCatalog(studioWorks)

test('Public international catalogue is source-derived, deterministic and bilingual',()=>{
 assert.equal(catalogue.schema,PUBLIC_CATALOG_SCHEMA)
 assert.equal(catalogue.version,1)
 assert.equal(catalogue.publisher,'OSA CINEMA')
 assert.deepEqual(catalogue.languages,['ru','en'])
 assert.equal(catalogue.total,3)
 assert.deepEqual(catalogue.projects.map(x=>x.id),['the-next-human','zero-window','threshold'])
 assert.deepEqual(catalogue.projects.map(x=>x.releaseState),['interactive_public','not_filmed','owner_local'])
 assert.ok(catalogue.projects.every(x=>x.title.ru&&x.title.en&&x.description.ru&&x.description.en))
 assert.equal(JSON.stringify(createPublicCinemaCatalog(studioWorks)),JSON.stringify(catalogue))
})
test('Catalogue is metadata, never a payment entitlement or fabricated streaming API',()=>{
 assert.equal(catalogue.publicPremiereClaimed,false)
 assert.ok(catalogue.catalogueIsNotStreamingAuthorization)
 assert.equal(catalogue.projects.filter(x=>x.interactiveUrl!==null).length,1)
 assert.equal(catalogue.projects[0].interactiveUrl,'https://osgard.world/osa-cinema')
 for(const item of catalogue.projects){
  assert.equal(item.publicVideoAvailable,false)
  assert.equal(item.publicVideoUrl,null)
  assert.ok(item.dossierUrl.startsWith('https://osgard.world/osa-cinema/studio/films/'))
  assert.ok(item.artworkUrl.startsWith('https://osgard.world/osa-cinema/reference/'))
  assert.ok(item.production.total>=item.production.verified)
 }
 const raw=JSON.stringify(catalogue)
 assert.doesNotMatch(raw,/private_key|token|\bcheckout\b|signed_url|\.mp4|\.m3u8|VideoObject/)
})
test('Malformed or forged editorial records are rejected before publication',()=>{
 assert.throws(()=>createPublicCinemaCatalog([]))
 assert.throws(()=>createPublicCinemaCatalog([...studioWorks,studioWorks[0]]),/duplicate/)
 assert.throws(()=>createPublicCinemaCatalog([{...studioWorks[0],artwork:'https://attacker.example/evil.jpg'}]),/Invalid/)
 assert.throws(()=>createPublicCinemaCatalog([{...studioWorks[0],category:'paid-premiere'}]),/Invalid/)
 assert.throws(()=>createPublicCinemaCatalog([{...studioWorks[0],gates:[{state:'published'}]}]),/Invalid/)
})
