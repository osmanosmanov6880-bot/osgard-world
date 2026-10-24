import assert from 'node:assert/strict'
import { existsSync, readFileSync, statSync } from 'node:fs'
import { createHash } from 'node:crypto'

const data=JSON.parse(readFileSync('public/games/aaa-roadmap.v1.json','utf8'))
const html=readFileSync('public/games/index.html','utf8')
const styles=readFileSync('public/games/world-artwork.css','utf8')
const dashboard=readFileSync('public/games/roadmap/roadmap.js','utf8')
const dashboardHtml=readFileSync('public/games/roadmap/index.html','utf8')
assert.equal(data.schemaVersion,1)
assert.equal(data.games.length,22)
assert.equal(data.games.filter(game=>game.coverKind==='concept-art').length,22)
assert.equal(new Set(data.games.map(game=>game.cover)).size,22)
assert.equal(new Set(data.games.map(game=>game.icon)).size,22)
const blocks=[...html.matchAll(/<article\b[^>]*data-game="([^"]+)"[^>]*>[\s\S]*?<\/article>/g)]
assert.equal(blocks.length,22,'Expected exactly 22 catalog article cards')
const hashes=[]
for(const game of data.games){
  const card=blocks.find(match=>match[1]===game.id)?.[0]
  assert.ok(card,'Missing HTML card for '+game.id)
  const fsIcon='public'+game.icon
  assert.ok(existsSync(fsIcon),'Missing custom icon '+fsIcon)
  const icon=readFileSync(fsIcon,'utf8')
  assert.ok(icon.startsWith('<svg xmlns="http://www.w3.org/2000/svg"'),'Expected valid self-hosted SVG '+game.id)
  assert.ok(icon.includes('viewBox="0 0 128 128"')&&icon.includes('<g ')&&icon.includes('</svg>'),'Missing emblem geometry for '+game.id)
  assert.ok(!/<(?:script|foreignObject|image)\b/i.test(icon),'No executable or external content in emblem '+game.id)
  hashes.push(createHash('sha256').update(icon).digest('hex'))
  assert.ok(card.includes('class="world-emblem" src="'+game.icon+'"'),'Game emblem not rendered in card '+game.id)
  assert.ok(card.includes('class="game-cover-image"'),'No cover layer in card '+game.id)
  assert.ok(card.includes('loading="lazy"')&&card.includes('decoding="async"'),'Cover must avoid blocking initial portal load '+game.id)
  assert.ok(card.includes('КОНЦЕПТ-АРТ'),'Cover must be transparently labeled as illustration '+game.id)
  assert.ok(card.includes('src="'+game.coverSmall+'"'),'Wrong preview for '+game.id)
  assert.ok(existsSync('public'+game.cover),'Missing production cover '+game.id)
  assert.ok(statSync('public'+game.cover).size>300,'Empty production cover '+game.id)
  assert.ok(existsSync('public'+game.coverSmall),'Missing lightweight cover '+game.id)
  if(game.cover.endsWith('.webp')){
    assert.ok(card.includes(game.coverSmall+' 640w, '+game.cover+' 1536w'),'Missing full responsive WebP srcset '+game.id)
    assert.ok(statSync('public'+game.coverSmall).size>1000,'Preview too small '+game.id)
  } else assert.ok(game.cover.endsWith('.svg'),'Expected SVG exception for three 3D worlds '+game.id)
}
assert.equal(new Set(hashes).size,22,'All 22 emblems must be individually drawn, not duplicate templates')
assert.equal(data.waves.find(w=>w.id==='02').state,'in_review','Do not mark an unpublished visual wave complete')
assert.ok(html.includes('href="./world-artwork.css"'),'Portal must load new premium gallery styles')
assert.ok(styles.includes('.game-cover-image')&&styles.includes('.world-emblem'),'Missing actual artwork and icon styles')
assert.ok(styles.includes('@media(max-width:760px)')&&styles.includes('prefers-reduced-motion'),'Responsive/motion accessibility missing')
assert.ok(dashboard.includes("game.coverSmall")&&dashboard.includes("game.icon")&&dashboard.includes("game-visual"),'Tracker gallery should show the same 22 creative assets')
assert.ok(dashboardHtml.includes('.game .game-visual'),'Tracker gallery styles missing')
console.log('PASS OSGARD PLAY WAVE 02: 22 unique vector emblems, 22 published candidate covers, responsive lazy-load image sources, visible concept-art labels and roadmap gallery.')
