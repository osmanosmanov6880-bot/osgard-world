import assert from 'node:assert/strict'
import {readFileSync} from 'node:fs'
import {Script} from 'node:vm'
const html=readFileSync('tools/osa-cinema-v19-caption-studio.html','utf8')
const original=JSON.parse(readFileSync('docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json','utf8')).assets
const shots=JSON.parse(readFileSync('docs/OSA_CINEMA_V18_PRIVATE_SCENE_CUT_QC.json','utf8')).assets
assert.ok(html.startsWith('<!doctype html>'),'Must be self-contained HTML')
assert.ok(html.includes("connect-src 'none'")&&html.includes("default-src 'none'"),'CSP must prevent uploads')
assert.ok(html.includes('lang="ru"')&&html.includes('prefers-reduced-motion'))
assert.ok(!/<script\s+src=|<link\s+href=/i.test(html),'Offline interface cannot load external scripts/styles')
assert.ok(!/\bfetch\s*\(|\bXMLHttpRequest\b|\bnavigator\.sendBeacon\b|\bWebSocket\b/.test(html),'No network transfer channels')
assert.ok(html.includes("crypto.subtle.digest('SHA-256'"),'Must check actual original file SHA')
assert.ok(html.includes('releaseAuthorized:false')&&html.includes('rightsCleared:false'),'Exports are private drafts')
assert.ok(html.includes('No caption cues in WebVTT'),'Empty imports must not claim subtitle success')
assert.ok(html.includes('WebVTT cue editor')&&html.includes('Export WebVTT before closing'),'English UI and session-only warning are required')
for(const id of ['source','mp4','vtt','video','openMedia','hash','switchLanguage','start','end','cueText','addCue','updateCue','deleteCue','loadVtt','exportVtt','exportJson','cueList','actMarkers','cutMarkers','status'])assert.ok(html.includes('id="'+id+'"'),'Missing control '+id)
const script=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)]
assert.equal(script.length,1)
new Script(script[0][1],{filename:'osa-cinema-v19-caption-studio.html'})
const match=script[0][1].match(/const SOURCES=(\[[^\n]+\]);\nconst \$=/)
assert.ok(match,'Embedded four-source manifest is missing')
const sources=JSON.parse(match[1])
assert.equal(sources.length,4)
for(const s of sources){
 const o=original.find(x=>x.id===s.id)
 const c=shots.find(x=>x.id===s.id)
 assert.ok(o&&c)
 assert.equal(s.sha256,o.sha256)
 assert.equal(s.sizeBytes,o.sizeBytes)
 assert.equal(s.locale,o.locale)
 assert.equal(s.durationSeconds,o.durationSeconds)
 assert.deepEqual(s.cutTimes,c.sceneCutTimecodes)
 assert.deepEqual(s.actStarts,s.durationSeconds>200?[5,79,157]:[5])
}
console.log('OSA_CINEMA_V19_PRIVATE_CAPTION_STUDIO_PASS: four source SHA originals, timed RU/EN cues, offline WebVTT, no upload, no release')
