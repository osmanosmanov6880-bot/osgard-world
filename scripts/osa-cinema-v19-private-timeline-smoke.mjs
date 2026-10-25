import assert from 'node:assert/strict'
import { test } from 'node:test'
import { readFileSync } from 'node:fs'
import { Script } from 'node:vm'
const html = readFileSync(new URL('../tools/osa-cinema-v19-private-timeline.html',import.meta.url),'utf8')

test('V19 offline edit desk has actual original candidates and measured 64/10 cuts',()=>{
  const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)]
  assert.equal(scripts.length,1)
  new Script(scripts[0][1],{filename:'osa-v19-desk'})
  assert.ok(html.includes('osa-v15-directors-ru') && html.includes('osa-v15-directors-en'))
  assert.ok(html.includes('osa-v15-trailer-ru') && html.includes('osa-v15-trailer-en'))
  assert.match(html,/const LONG = \[5,8\.875.*233\]/)
  assert.match(html,/const SHORT = \[5,8\.875.*43\.5\]/)
  assert.ok(html.includes('connect-src \'none\''))
  assert.ok(html.includes('crypto.subtle.digest'))
  assert.ok(html.includes('publicationAuthorized:false'))
  assert.ok(html.includes('rightsCleared:false'))
  assert.ok(html.includes('aria-current'))
  assert.ok(html.includes('prefers-reduced-motion'))
  assert.ok(html.includes('URL.revokeObjectURL'))
  assert.ok(!/\bfetch\s*\(|\bXMLHttpRequest\b|\bWebSocket\b|\bnavigator\.sendBeacon\b/.test(scripts[0][1]))
  assert.ok(!/<script\s+src=/i.test(html))
})

test('V19 source hashes, sizes and locales exactly match V16 manifest if present',()=>{
  const mf = new URL('../docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json',import.meta.url)
  let original
  try{original = JSON.parse(readFileSync(mf,'utf8'))}catch(err){if(err.code==='ENOENT')return;throw err}
  const sources = new Map(original.assets.map(a=>[a.id,a]))
  for (const asset of original.assets) {
    assert.ok(html.includes("id:'"+asset.id+"'"))
    assert.ok(html.includes("file:'"+asset.file+"'"))
    assert.ok(html.includes("sha:'"+asset.sha256+"'"))
    assert.ok(html.includes('bytes:'+asset.sizeBytes))
    assert.ok(['en','ru'].includes(asset.locale))
  }
  assert.equal(sources.size,4)
})
