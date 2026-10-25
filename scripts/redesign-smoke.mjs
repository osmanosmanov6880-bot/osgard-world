import assert from 'node:assert/strict'
import { readFileSync,existsSync } from 'node:fs'
import { parsePlayCollection,emptyPlayCollection,toggleFavorite,visitGame } from '../src/playCollection.ts'
import { playGames,cases } from '../src/redesignCatalog.ts'
import { PLAY_GAME_IDS, PLAY_GENRES, FEATURED_PLAY_WORLDS } from '../src/playCatalogIndex.ts'
// Do not hardcode the historical W6 step title as the only secure release path.
// W11 uses a verified GitHub Release; W14 uses a SHA-verified Actions artifact.
function r135VerifiedDeployment() {
  const deploy = readFileSync('.github/workflows/deploy-frontend.yml', 'utf8')
  if (deploy.includes('Stage verified native R135 Godot Web export') &&
      deploy.includes('scripts/r135-release-stage.py')) return true
  // W14 uses a reviewed immutable Actions artifact, while W11 uses a reviewed Release.
  // Both require independent hash verification; never accept floating "latest".
  const w14PinPath = 'scripts/r135-w14-release-pin.json'
  const w14GatePath = '.github/workflows/r135-w14-promotion-gate.yml'
  if (deploy.includes('Stage exact reviewed W14 Godot Web archive, fail-closed on any mismatch')) {
    if (![w14PinPath, w14GatePath, 'scripts/r135-w14-promotion-qa.py',
          'scripts/r135-release-stage.py', 'scripts/r135-verified-live-recover.py'].every(existsSync)) return false
    const pin = JSON.parse(readFileSync(w14PinPath, 'utf8'))
    const gate = readFileSync(w14GatePath, 'utf8')
    return deploy.includes('gh run download "$RUN_ID"') &&
      deploy.includes('scripts/r135-release-stage.py') &&
      deploy.includes('scripts/r135-verified-live-recover.py') &&
      deploy.includes('sha256sum -c -') &&
      gate.includes('scripts/r135-w14-promotion-qa.py') &&
      gate.includes('scripts/r135-nginx-wasm-smoke.sh') &&
      pin.version === 'r135-case-progress-w14-20261025' &&
      /^[0-9a-f]{40}$/.test(pin.source_commit) &&
      /^[0-9a-f]{64}$/.test(pin.manifest_sha256) &&
      /^[0-9a-f]{64}$/.test(pin.archive_sha256) &&
      pin.artifact_run_id === 40175524463 &&
      pin.artifact_id === 12592898463 &&
      pin.artifact_name === 'osgard-r135-optimized-web-qa' &&
      pin.reviewed_portrait === true && pin.reviewed_desktop === true &&
      pin.browser_three_fault_cases === true &&
      pin.physical_phone_fps_verified === false &&
      pin.rollback_release_tag === 'r135-web-legibility-w11-20261025'
  }
  if (!deploy.includes('Stage exact immutable W11 Godot Web release') ||
      !deploy.includes('gh release download "$TAG"') ||
      !deploy.includes('scripts/r135-w11-release-pin.json') ||
      !deploy.includes('scripts/r135-release-stage.py')) return false
  const pinPath = 'scripts/r135-w11-release-pin.json'
  if (!existsSync(pinPath)) return false
  const pin = JSON.parse(readFileSync(pinPath, 'utf8'))
  return pin.version === 'r135-web-legibility-w11-20261024' &&
    pin.release_tag === 'r135-web-legibility-w11-20261025' &&
    /^[0-9a-f]{40}$/.test(pin.source_commit) &&
    /^[0-9a-f]{64}$/.test(pin.manifest_sha256) &&
    /^[0-9a-f]{64}$/.test(pin.archive_sha256) &&
    Number.isSafeInteger(pin.artifact_run_id) &&
    pin.reviewed_portrait === true && pin.reviewed_desktop === true &&
    pin.software_only === true
}
const ids=playGames.map(g=>g.id)
assert.deepEqual(PLAY_GAME_IDS,ids,'Compact home index must stay aligned with the full game catalog')
assert.deepEqual(PLAY_GENRES,[...new Set(playGames.map(g=>g.genre))],'Compact home filters must match game genres')
assert.ok(FEATURED_PLAY_WORLDS.every(g=>ids.includes(g.id)),'Featured worlds must remain in the game catalog')
let p=toggleFavorite(emptyPlayCollection(),'time');assert.deepEqual(p.favorites,['time']);p=toggleFavorite(p,'time');assert.deepEqual(p.favorites,[])
p=visitGame(visitGame(visitGame(p,'time'),'swarm'),'time');assert.deepEqual(p.recent,['time','swarm'])
assert.deepEqual(parsePlayCollection('{"favorites":["time","time","unknown",12],"recent":["swarm"]}',ids),{favorites:['time'],recent:['swarm']})
assert.throws(()=>parsePlayCollection('{',ids));assert.throws(()=>parsePlayCollection(' '.repeat(10001),ids));assert.throws(()=>parsePlayCollection('{"favorites":42}',ids))
for(const game of playGames){assert.ok(existsSync('public'+game.asset));if(game.launchable&&!['time','null-shift'].includes(game.id)){let path='public'+game.href; if(path.endsWith('/'))path+='index.html';if(game.id==='r136-precision'&&!existsSync(path)){assert.ok(existsSync('.github/workflows/r136-godot-web.yml'),'R136 release workflow missing')}else if(game.id==='r135-service'&&!existsSync(path)){assert.ok(existsSync('scripts/r135-release-stage.py') && r135VerifiedDeployment(),'R135 runtime must be SHA-verified and staged by deploy')}else assert.ok(existsSync(path),'Launch target missing: '+game.id)}assert.ok(game.warning&&game.save&&game.online&&game.controls)}
assert.equal(playGames.length,23)
assert.equal(new Set(ids).size,23)
const godot=playGames.find(g=>g.id==='null-shift')
assert.equal(godot.launchable,true)
assert.equal(godot.href,'/games/null-shift-godot/')
assert.ok(existsSync('public'+godot.alternate.href+'index.html'))
assert.ok(readFileSync('.github/workflows/deploy-frontend.yml','utf8').includes('Preserve Godot Web export'))
for(const id of ['020','021','022','023','024','025','026','027','028','029','030'])assert.ok(playGames.some(g=>g.id==='zion-'+id&&g.href.startsWith('/games/zion-9/')))
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
