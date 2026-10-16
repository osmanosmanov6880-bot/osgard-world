import assert from 'node:assert/strict'
import { readFileSync,existsSync } from 'node:fs'
import { parsePlayCollection,emptyPlayCollection,toggleFavorite,visitGame } from '../src/playCollection.ts'
import { playGames,cases } from '../src/redesignCatalog.ts'
const ids=playGames.map(g=>g.id)
let p=toggleFavorite(emptyPlayCollection(),'time');assert.deepEqual(p.favorites,['time']);p=toggleFavorite(p,'time');assert.deepEqual(p.favorites,[])
p=visitGame(visitGame(visitGame(p,'time'),'swarm'),'time');assert.deepEqual(p.recent,['time','swarm'])
assert.deepEqual(parsePlayCollection('{"favorites":["time","time","unknown",12],"recent":["swarm"]}',ids),{favorites:['time'],recent:['swarm']})
assert.throws(()=>parsePlayCollection('{',ids));assert.throws(()=>parsePlayCollection(' '.repeat(10001),ids));assert.throws(()=>parsePlayCollection('{"favorites":42}',ids))
for(const game of playGames){assert.ok(existsSync('public'+game.asset));if(game.launchable&&game.id!=='time'){let path='public'+game.href; if(path.endsWith('/'))path+='index.html';assert.ok(existsSync(path),'Launch target missing: '+game.id)}assert.ok(game.warning&&game.save&&game.online&&game.controls)}
assert.equal(playGames.find(g=>g.id==='null-shift').launchable,false)
for(const item of cases){assert.ok(existsSync('public'+item.href+'index.html'));assert.ok(existsSync('public'+item.art))}
const main=readFileSync('src/main.tsx','utf8'),css=readFileSync('src/brandSystem.css','utf8'),transition=readFileSync('public/brand/osa-transition.js','utf8')
for(const route of ['/intelligence','/play','/play/partners','/learning/project','/learning/workspace','/learning/program','/learning/experiments','/learning/portfolio','/portal','/osa-cinema','/academy'])assert.ok(main.includes(route),route)
assert.ok(main.includes('React.lazy')&&main.includes('Suspense'))
assert.ok(!/^import .*from ['"]\.\/(App|LivingGlobe|TimePrototype)['"]/m.test(main),'Heavy surfaces must not be statically imported')
for(const color of ['#f3f4f1','#172027','#59656b','#315a62','#dce2e1','#101a27','#182330','#f3f0e8','#aab4bc','#83b9ae','#080b12','#111926','#5ce1e6'])assert.ok(css.toLowerCase().includes(color),color)
assert.ok(css.includes(':focus-visible')&&css.includes('prefers-reduced-motion')&&css.includes('max-width:760px'))
assert.ok(transition.includes('prefers-reduced-motion'))
assert.ok(!transition.includes('preventDefault('),'Animation must never delay navigation')
for(const file of ['favicon.svg','app-icon-192.png','app-icon-512.png',...['world','intelligence','play'].flatMap(t=>['portal-'+t+'.svg','lockup-'+t+'-primary.svg','preview-'+t+'.png'])])assert.ok(existsSync('public/brand/'+file),file)
console.log('Redesign source checks passed: collection persistence model, launch assets, cases, route preservation, tokens and motion policy')
