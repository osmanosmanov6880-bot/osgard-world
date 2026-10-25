import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { Script } from 'node:vm'
const file='tools/osa-cinema-v27-private-release-board.html'
const html=readFileSync(file,'utf8')
test('V27 local HTML dashboard never performs network I/O or third-party asset loading',()=>{
 assert.ok(html.includes("connect-src 'none'"))
 assert.ok(html.includes("default-src 'none'"))
 assert.ok(!/<script\s+src=/i.test(html))
 const script=html.match(/<script>([\s\S]+)<\/script>/)?.[1]
 assert.ok(script)
 assert.ok(!/\bfetch\s*\(|XMLHttpRequest|navigator\.sendBeacon|WebSocket/.test(script))
 new Script(script,{filename:file})
 assert.ok(html.includes('publicFilmPublicationAuthorized!==false'))
 assert.ok(html.includes('paidCheckoutEnabled!==false'))
 assert.ok(html.includes("r.result!=='NO_GO'"))
})
