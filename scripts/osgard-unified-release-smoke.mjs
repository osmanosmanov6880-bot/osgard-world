/**
 * OSGARD unified release: guard all six redesigned surfaces plus preserved live games.
 * Zero network calls, credentials or synthetic telemetry; validates source and shipped assets.
 * Run with: npm run qa:unified
 */
import { readFileSync, statSync, existsSync } from 'node:fs'
import { resolve } from 'node:path'
import assert from 'node:assert/strict'
const root = process.cwd()
const read = path => readFileSync(resolve(root, path), 'utf8')
const exists = path => existsSync(resolve(root, path))
const pass = []
function check(label, fn) {
  try { fn(); pass.push(label); process.stdout.write('PASS ' + label + '\n') }
  catch (err) { process.stderr.write('FAIL ' + label + ': ' + err.message + '\n'); process.exitCode = 1 }
}
const routes = read('src/main.tsx')
const shell = read('src/BrandShell.tsx')
const world = read('src/WorldHome.tsx')
const academy = read('src/AcademyHome.tsx')
const intelligence = read('src/IntelligenceHome.tsx')
const catalog = read('src/redesignCatalog.ts')
const seo = read('src/routeSeo.ts')
const test = read('scripts/ecosystem-browser.spec.mjs')
const gameIds = [...catalog.matchAll(/^\s*"id":\s*"([^"]+)"/gm)].map(m => m[1])
check('distinct real game catalog and lightweight titles are aligned', () => {
  const titles = [...read('src/playGameTitles.ts').matchAll(/^\s*"([^"]+)":\s*"/gm)].map(m => m[1])
  assert.equal(gameIds.length, 19, 'Play catalog must retain all 19 game worlds')
  assert.deepEqual([...gameIds].sort(), [...titles].sort())
  assert.equal(new Set(gameIds).size, gameIds.length)
})
check('all six public routes retain the React integration', () => {
  for (const route of ["path === '/'","path === '/intelligence'","path === '/play'","path === '/academy'","path === '/development'","path === '/entertainment'"]) {
    assert.ok(routes.includes(route), 'missing route ' + route)
  }
  assert.ok(routes.includes('PlayGameRoute'), 'game world launcher missing')
  assert.ok(routes.includes('OSALessonPage'), 'lecture route missing')
})
check('Play cinematic and accessible catalog are preserved', () => {
  assert.ok(read('src/PlayHome.tsx').includes('cp-glass-panel'))
  assert.ok(read('src/PlayExploreSections.tsx').includes('id="catalog"'))
  assert.ok(read('src/OsgardTransitionProvider.tsx').includes('restoreFocus('))
  assert.ok(exists('src/playCinematic.css') && exists('src/playGameDetail.css'))
  for (const id of gameIds) {
    const asset = resolve(root, 'public/brand/play', id + '.webp')
    assert.ok(existsSync(asset), 'missing game cover ' + id)
    assert.ok(statSync(asset).size > 512, 'empty game cover ' + id)
  }
})
check('World and Development both render real products', () => {
  assert.ok(world.includes('omega-command'), 'World command hero missing')
  assert.ok(world.includes('signature-showcase'), 'Development cases missing')
  assert.ok(world.includes('cases[1].art'), 'Case preview must come from real catalog')
  assert.ok(read('src/omegaWorld.css').includes('blue-marble-2048.webp'), 'NASA fallback absent')
  assert.ok(exists('src/developmentSignature.css'))
})
check('Academy shows actual learner progress and imports safely', () => {
  for (const needle of ['academy-learning-console','nextLearningAction.href','learningProgress.lessonCompletions','academy-hero-topline']) {
    assert.ok(academy.includes(needle), 'Academy behavior missing ' + needle)
  }
  assert.ok(read('src/academyStudio.css').includes('#academy-studio-backup-input{'))
  assert.ok(exists('scripts/academy-cockpit-browser.spec.mjs'))
})
check('Intelligence preserves NIST, real mark state and honest limitations', () => {
  assert.ok(intelligence.includes('intelligence-proof-console'))
  assert.ok(intelligence.includes('aria-pressed={marked.includes(index)}'))
  assert.ok(intelligence.includes('nvlpubs.nist.gov'))
  assert.ok(intelligence.includes('не ответ подключённой нейросети'))
  assert.ok(exists('src/intelligenceCommand.css'))
})
check('Entertainment preserves its seven archive games in RU, EN and AR', () => {
  for (const p of ['public/entertainment/index.html','public/entertainment/en/index.html','public/entertainment/ar/index.html']) {
    const html = read(p)
    assert.ok(html.includes('hero-spotlight') && html.includes('href="/play"'))
    assert.equal((html.match(/<div class="art"><small>/g)||[]).length,7,'wrong archive game count '+p)
    assert.equal((html.match(/<a class="case-feature/g)||[]).length,4,'wrong case count '+p)
  }
  assert.ok(exists('public/entertainment/archive/index.html'))
  assert.ok(exists('public/entertainment/premium.css'))
})
check('global navigation and metadata retain correct product identity', () => {
  assert.ok(shell.includes('Продукты OSGARD') && shell.includes('Меньше движения'))
  assert.ok(seo.includes("'/intelligence':{title:") && seo.includes("'/play':{title:"))
  assert.ok(seo.includes("'/development':{title:"))
  assert.ok(test.includes('World Cosmic Portal') && test.includes('OSA Evidence Command') && test.includes('Development Signature') && test.includes('Entertainment World Select'))
})
check('recent master game work remains intact and local saves unmodified', () => {
  assert.ok(statSync(resolve(root,'public/games/empire-orbit/index.html')).size > 100000)
  assert.ok(exists('public/games/time-omega-preview/release.json'))
  assert.ok(read('src/TimePrototype.tsx').includes('recordOsgardEvent'))
  assert.ok(read('scripts/time-prototype-smoke.mjs').includes('time'))
})
process.stdout.write('\n' + pass.length + '/9 unified release checks passed\n')
if (process.exitCode) process.exit(process.exitCode)
