import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { Script } from 'node:vm'

const html=readFileSync('tools/osa-cinema-private-review.html','utf8')
assert.ok(html.startsWith('<!doctype html>'))
assert.ok(html.includes('<html lang="ru">'))
assert.ok(html.includes('prefers-reduced-motion'))
assert.ok(html.includes('aspect-ratio:16/9'))
assert.ok(html.includes('type="file" accept="video/mp4,.mp4"'))
assert.ok(html.includes('type="file" accept=".vtt,text/vtt"'))
for(const id of ['video','verify','load','mark','export','vtt','subtitleFile','source','rights','voice','edit','sub','host','notes','status']){
  assert.match(html,new RegExp('id="'+id+'"'),'Missing private review control '+id)
}
assert.ok(html.includes('crypto.subtle.digest'))
assert.ok(html.includes('URL.createObjectURL'))
assert.ok(html.includes('URL.revokeObjectURL'))
assert.ok(html.includes('releaseAuthorized:false'))
assert.ok(html.includes('file.arrayBuffer()'))
assert.ok(html.includes('confirmedHash===asset.sha'))
assert.ok(html.includes('locale==='))
assert.ok(html.includes("document.createElement('track')"))
assert.doesNotMatch(html,/<script\s+src=/i,'No remote scripts in the offline reviewer')
assert.doesNotMatch(html,/\bfetch\s*\(|XMLHttpRequest|navigator\.sendBeacon|WebSocket|<iframe|https?:\/\/[^" ]+\.js/i,'No network transfer channels or remote code')
const script=html.match(/<script>([\s\S]*?)<\/script>/)?.[1]
assert.ok(script && script.length>8000,'Private reviewer JS is missing')
new Script(script,{filename:'osa-cinema-private-review.html'})
console.log('OSA_CINEMA_V16_PRIVATE_ROOM_PASS: standalone RU/EN editor, local-only video, SHA-256, VTT and private report')
