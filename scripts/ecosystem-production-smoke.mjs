import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { readFile, readdir } from 'node:fs/promises'
import { build } from 'esbuild'

const origin = new URL(process.env.OSGARD_BASE_URL || 'https://osgard.world')
assert.ok(['https:', 'http:'].includes(origin.protocol))
const bundle = await build({ entryPoints: ['src/redesignCatalog.ts'], bundle: true, write: false, format: 'esm', platform: 'node' })
const { playGames } = await import('data:text/javascript;base64,' + Buffer.from(bundle.outputFiles[0].text).toString('base64'))
const hash = bytes => createHash('sha256').update(bytes).digest('hex')
const checked = []

async function fetchPath(path) {
  const url = new URL(path, origin)
  url.searchParams.set('release_check', process.env.GITHUB_SHA?.slice(0, 12) || Date.now().toString())
  const response = await fetch(url, { headers: { 'Cache-Control': 'no-cache' }, signal: AbortSignal.timeout(20000) })
  assert.equal(response.status, 200, path + ': HTTP ' + response.status)
  return Buffer.from(await response.arrayBuffer())
}
for (const [path, title] of [['/', 'OSGARD WORLD'], ['/intelligence', 'OSA Intelligence'], ['/play', 'OSGARD PLAY'], ['/purchases', 'OSGARD — мои покупки'], ['/learning/enrollment', 'OSA — приобретённая практическая программа']]) {
  const html = (await fetchPath(path)).toString('utf8')
  assert.ok(html.includes('<title>' + title), path + ': title')
  assert.ok(html.includes('name="description"') && html.includes('property="og:image"'), path + ': SEO')
  assert.ok(html.includes('https://osgard.world' + path), path + ': canonical')
  if (path === '/purchases' || path === '/learning/enrollment') assert.ok(html.includes('noindex,follow'), path + ': personal page indexing')
  checked.push(path)
}
for (const game of playGames) {
  const path = '/play/world/' + game.id
  const html = (await fetchPath(path)).toString('utf8')
  assert.ok(html.includes('<title>' + game.title), path + ': actual world title')
  assert.ok(html.includes('href="https://osgard.world' + path + '"'), path + ': canonical')
  checked.push(path)
}
const covers = playGames.map(game => game.asset)
assert.equal(new Set(covers).size, playGames.length, 'Every game has a distinct illustration')
for (const path of covers.filter(path => path.startsWith('/brand/'))) {
  assert.equal(hash(await fetchPath(path)), hash(await readFile('public' + path)), path + ': published game cover differs from release')
  checked.push(path)
}
async function filesAt(directory, relative = '') {
  const found = []
  for (const item of await readdir(directory, { withFileTypes: true })) {
    const path = relative + item.name
    if (item.isDirectory()) found.push(...await filesAt(directory + '/' + item.name, path + '/'))
    else found.push(path)
  }
  return found
}
for (const relative of await filesAt('public/games/zion-9')) {
  const path = '/games/zion-9/' + relative
  assert.equal(hash(await fetchPath(path)), hash(await readFile('public' + path)), path + ': published bytes differ from release')
  checked.push(path)
}
const inherit = (await fetchPath('/games/inherit/')).toString('utf8')
assert.ok(inherit.includes("'/api/world/quiet-reach'"), 'INHERIT same-origin world endpoint')
assert.equal((inherit.match(/<\/html>/gi) || []).length, 1, 'INHERIT document integrity')
const pilotReleaseAssets = [
 '/games/inherit/pilot/index.html',
 '/games/inherit/pilot/landing.js',
 '/games/inherit/pilot/pilot.css',
 '/games/inherit/pilot/report.html',
 '/games/inherit/pilot/report.js',
 '/games/inherit/pilot-metrics.js',
 '/games/inherit/research-ui.js',
 '/games/inherit/sw.js',
 '/games/inherit/generation-atlas-core.js',
 '/games/inherit/generation-atlas.js',
 '/games/inherit/generation-atlas.css',
 '/games/inherit/handoff-moment-core.js',
 '/games/inherit/handoff-moment.js',
 '/games/inherit/handoff-moment.css',
 '/games/inherit/generation-timelapse-core.js',
 '/games/inherit/generation-timelapse.js',
 '/games/inherit/generation-timelapse.css',
 '/games/inherit/trace-inspector-core.js',
 '/games/inherit/trace-inspector.js',
 '/games/inherit/trace-inspector.css',
 '/games/inherit/trace-compass-core.js',
 '/games/inherit/trace-compass.js',
 '/games/inherit/trace-compass.css',
 '/games/inherit/legacy-network-core.js',
 '/games/inherit/legacy-network.js',
 '/games/inherit/legacy-network.css',
 '/games/inherit/memory-expeditions-core.js',
 '/games/inherit/memory-expeditions.js',
 '/games/inherit/memory-expeditions.css',
 '/games/inherit/guided-journey-core.js',
 '/games/inherit/guided-journey.js',
 '/games/inherit/guided-journey.css'
];
for (const path of pilotReleaseAssets) {
  assert.equal(hash(await fetchPath(path)), hash(await readFile('public' + path)),
    path + ': published INHERIT pilot bytes differ from this release');
  checked.push(path);
}

const health = JSON.parse((await fetchPath('/api/core/health')).toString('utf8'))
assert.equal(health.status, 'ok', 'Core health')
const privateProgram = new URL('/api/core/learning/programs', origin)
privateProgram.searchParams.set('release_check', process.env.GITHUB_SHA?.slice(0, 12) || Date.now().toString())
const privateResponse = await fetch(privateProgram, { headers: { 'Cache-Control': 'no-cache' }, signal: AbortSignal.timeout(20000) })
assert.equal(privateResponse.status, 401, 'Program API requires authentication')
console.log(JSON.stringify({ status: 'PASS', origin: origin.origin, checkedRoutesAndAssets: checked.length + 3, worlds: playGames.length, localZionWorlds: 11, verification: 'HTTP, metadata, exact local archive and cover bytes, Core health and program authentication; browser interaction is a separate CI check' }, null, 2))
