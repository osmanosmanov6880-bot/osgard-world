import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The game exporter rewrites index.* in place. Revalidating names is a
// correctness requirement, not just a speed preference: otherwise cached
// R9 JS/WASM can silently load after R10 has passed SSH binary attestation.
const nginx=readFileSync('nginx.conf','utf8')
const pages=readFileSync('public/_headers','utf8')
const block=(file,label)=>{
  const at=file.indexOf(label)
  assert.ok(at>=0,'Missing '+label)
  return file.slice(at,file.indexOf('\n  location ',at+label.length)<0?undefined:file.indexOf('\n  location ',at+label.length))
}
test('Godot user-facing entry and release manifest refuse stale CDN versions',()=>{
  for(const location of ['location = /games/omega-3d-preview/ {',
      'location = /games/omega-3d-preview/index.html {',
      'location = /games/omega-3d-preview/release.json {']){
    const chunk=block(nginx,location)
    assert.match(chunk,/Cache-Control "no-store, max-age=0, must-revalidate" always;/)
    assert.match(chunk,/X-Content-Type-Options nosniff always;/)
    assert.match(chunk,/try_files /)
  }
})
test('every stable Godot binary URL is revalidated, not cached as immutable',()=>{
  const area=block(nginx,'location ^~ /games/omega-3d-preview/ {')
  assert.match(area,/Cache-Control "no-cache, max-age=0, must-revalidate, proxy-revalidate" always;/)
  assert.match(area,/try_files \$uri =404;/)
  assert.doesNotMatch(area,/immutable/)
})
test('Pages route does not cache stale Godot index, WASM, JavaScript or PCK',()=>{
  const parts=['/games/omega-3d-preview/','/games/omega-3d-preview/index.html',
  '/games/omega-3d-preview/release.json',
  '/games/omega-3d-preview/*.js',
  '/games/omega-3d-preview/*.pck',
  '/games/omega-3d-preview/*.wasm']
  for(const path of parts){
    const start=pages.indexOf('\n'+path+'\n')
    assert.ok(start>=0,'missing Cloudflare headers '+path)
    const segment=pages.slice(start,pages.indexOf('\n\n',start+2)<0?undefined:pages.indexOf('\n\n',start+2))
    assert.match(segment,/Cache-Control: (no-store|no-cache)/,'mutable cache response '+path)
    assert.doesNotMatch(segment,/stale-while-revalidate|immutable|max-age=86400/)
  }
})
