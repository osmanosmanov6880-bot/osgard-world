import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync, existsSync } from 'node:fs'
import { createLastWorld, parseLastWorld, gameRouteFromCard, LAST_WORLD_MAX_AGE_MS } from '../public/games/player-session-core.mjs'

const allowed=new Set(['null-shift','time','zion-024'])
const now=1_900_000_000_000

test('last world record is minimal and has no game-state or credential fields',()=>{
 const record=createLastWorld('time',allowed,now)
 assert.deepEqual(record,{version:1,id:'time',openedAt:now})
 assert.equal(Object.keys(record).length,3)
 assert.equal(parseLastWorld(JSON.stringify(record),allowed,now).id,'time')
})

test('deny unknown world ids and malformed/corrupted storage',()=>{
 assert.equal(createLastWorld('evil-site',allowed,now),null)
 for(const value of [null,'','{broken}','[]','null','{}','{"version":1,"id":"unknown","openedAt":1900000000000}','{"version":2,"id":"time","openedAt":1900000000000}']){
   assert.equal(parseLastWorld(value,allowed,now),null,String(value))
 }
})

test('records expire safely, reject forged times, tolerate one minute of local clock drift',()=>{
 const value=openedAt=>JSON.stringify({version:1,id:'zion-024',openedAt})
 assert.equal(parseLastWorld(value(now-LAST_WORLD_MAX_AGE_MS),allowed,now)?.id,'zion-024')
 assert.equal(parseLastWorld(value(now-LAST_WORLD_MAX_AGE_MS-1),allowed,now),null)
 assert.equal(parseLastWorld(value(now+60001),allowed,now),null)
 assert.equal(parseLastWorld(value(now+59999),allowed,now)?.id,'zion-024')
 assert.equal(parseLastWorld(value('yesterday'),allowed,now),null)
})

test('resume route is resolved from current real catalog card, never persisted URL',()=>{
 const card=href=>({querySelector:()=>href?{href}:null})
 const origin='https://osgard.world/games/'
 assert.equal(gameRouteFromCard(card('/games/time'),origin),'https://osgard.world/games/time')
 assert.equal(gameRouteFromCard(card('https://osgard.world/play/world/null-shift'),origin),'https://osgard.world/play/world/null-shift')
 assert.equal(gameRouteFromCard(card('https://evil.example/games/'),origin),null)
 assert.equal(gameRouteFromCard(card('javascript:alert(1)'),origin),null)
 assert.equal(gameRouteFromCard(card('/admin'),origin),null)
 assert.equal(gameRouteFromCard(null,origin),null)
})

test('all 22 worlds have truthful runtime instructions and WAVE 03 stays in-review',()=>{
 const html=readFileSync('public/games/index.html','utf8')
 const data=JSON.parse(readFileSync('public/games/aaa-roadmap.v1.json','utf8'))
 const source=readFileSync('public/games/player-experience.mjs','utf8')
 const css=readFileSync('public/games/player-experience.css','utf8')
 assert.equal(data.games.length,22)
 assert.equal(data.waves.find(w=>w.id==='03')?.state,'in_review')
 const clean=s=>s.replace(/<[^>]*>/g,' ').replace(/\s+/g,' ').trim()
 for(const game of data.games){
  const article=html.match(new RegExp('<article\\b[^>]*data-game="'+game.id+'"[^>]*>([\\s\\S]*?)<\\/article>'))?.[1]
  assert.ok(article,'No card for '+game.id)
  const facts=article.match(/<dl class="launch-facts">([\s\S]*?)<\/dl>/)?.[1]
  assert.ok(facts,'No authentic instructions for '+game.id)
  const labels={}
  for(const entry of facts.matchAll(/<dt>([\s\S]*?)<\/dt>\s*<dd>([\s\S]*?)<\/dd>/g))labels[clean(entry[1])]=clean(entry[2])
  assert.equal(game.controls,labels['Управление'],game.id+' control hints must match real card')
  assert.equal(game.saveBehavior,labels['Сохранение'],game.id+' saves must be reported accurately')
  assert.equal(game.networkBehavior,labels['Онлайн'],game.id+' online availability must match real card')
 }
 for(const id of ['last-session','last-session-game','last-session-link','last-session-clear','player-help-toggle','player-help-panel','player-help-content','player-connection-status']){
   assert.ok(html.includes('id="'+id+'"'),'Missing portal control '+id)
 }
 assert.ok(html.includes('type="module" src="./player-experience.mjs"'))
 assert.ok(html.includes('href="./player-experience.css"'))
 assert.ok(source.includes("new MutationObserver")&&source.includes("document.addEventListener('click'")&&source.includes("event.button !== 0"))
 assert.ok(source.includes("location.origin")&&source.includes("dialog?.addEventListener('close'"))
 assert.ok(source.includes("navigator.onLine === false"))
 assert.ok(css.includes('@media(max-width:760px)')&&css.includes('prefers-reduced-motion'))
 assert.ok(existsSync('public/games/player-session-core.mjs'))
 const tracker=readFileSync('public/games/roadmap/roadmap.js','utf8')
 assert.ok(tracker.includes('game.controls')&&tracker.includes('game.saveBehavior'))
})
