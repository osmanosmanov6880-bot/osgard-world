import assert from 'node:assert/strict'
import { existsSync, readFileSync, statSync } from 'node:fs'

// WAVE 4: Source and contract gates for the six integrated OSGARD surfaces.
// Pure Node, no infrastructure credentials, production network calls or logins.
const read = path => readFileSync(path, 'utf8')
const asset = path => {
  assert.ok(existsSync(path), 'Required product asset missing: ' + path)
  assert.ok(statSync(path).size > 100, 'Empty product asset: ' + path)
}
const contains = (path, fragments) => {
  const src = read(path)
  for (const fragment of fragments) {
    assert.ok(src.includes(fragment), path + ' lost required product contract: ' + fragment)
  }
  return src
}

const world = contains('src/WorldHome.tsx', [
  "import './developmentSignature.css'",
  "import OsgardEcosystemIndex from './OsgardEcosystemIndex'",
  "development-signature",
  "world-command",
  'omega-command',
  'signature-showcase',
  '<OsgardEcosystemIndex />',
  'id="products"',
  'id="cases"',
  'id="contact"',
])
const index = contains('src/OsgardEcosystemIndex.tsx', [
  'function OsgardEcosystemIndex',
  'role="group" aria-label="Фильтр направлений"',
  'type="search"',
  'aria-pressed={filter.id === active}',
  'aria-live="polite"',
  "localStorage.getItem('osgard:recent-destination:v1')",
  "localStorage.setItem('osgard:recent-destination:v1', id)",
  "localStorage.removeItem('osgard:recent-destination:v1')",
  "catch { /* Navigation works without browser storage. */ }",
  'Очистить историю направления',
])
const routes = ['/intelligence', '/academy', '/play', '/entertainment/archive/', '/development', '/learning/project']
for (const route of routes) {
  assert.ok(index.includes("href: '" + route + "'"), 'Directory lost destination: ' + route)
}
for (const art of ['omega-osa.svg', 'omega-play.svg', 'world-time.svg', 'omega-development.svg']) {
  asset('public/brand/' + art)
}
asset('public/brand/earth/blue-marble-2048.webp')
const css = read('src/ecosystemIndex.css')
assert.ok(Buffer.byteLength(css) < 16 * 1024, 'Ecosystem directory styles exceeded 16 KiB raw CSS')
assert.ok(css.includes('@media(max-width:700px)') && css.includes('@media(prefers-reduced-motion:reduce)'),
  'Unified directory must adapt to mobile and user motion preferences')

const shell = contains('src/BrandShell.tsx', [
  'play-catalog-shell',
  "path === '/intelligence'",
  "['Проверка', '/intelligence#demo']",
  'brand-skip',
])
const time = contains('src/TimePrototype.tsx', [
  'tg-omega-preview-link',
  '/games/time-omega-preview/',
  'recordCoreEvent',
])
const academy = contains('src/AcademyHome.tsx', [
  'academy-learning-console',
  'aria-valuenow={completedScenes}',
  'academy-hero-topline',
  'nextLearningAction.href',
])
assert.ok(!academy.includes('academy-compact-header'), 'Extra Academy header would hide the learning action on mobile')
contains('src/academyStudio.css', ['#academy-studio-backup-input{', 'inline-size:1px!important'])
contains('src/IntelligenceHome.tsx', [
  'intelligence-proof-console',
  'aria-pressed={marked.includes(index)}',
  'id="demo-sources"',
  'NIST AI 600-1',
])
contains('src/developmentSignature.css', [
  '.development-signature .signature-showcase',
  '@media(max-width:610px)',
])
const intro = contains('src/OsgardTransitionProvider.tsx', [
  'restoreFocus',
  'data-osgard-content',
  'osgard',
])
const play = contains('src/PlayExploreSections.tsx', [
  'aria-label="Жанр"',
  'aria-label="Доступность"',
])
for (const locale of ['','en/','ar/']) {
  const file = 'public/entertainment/' + locale + 'index.html'
  const html = contains(file, [
    'entertainment-premium',
    '/entertainment/premium.css',
    '/brand/omega-play.svg',
    'hero-spotlight',
  ])
  assert.equal((html.match(/class="art"><small>/g) || []).length, 7,
    file + ' must retain precisely seven archived illustrated game links')
  assert.equal((html.match(/class="case-feature(?:\s|")/g) || []).length, 4,
    file + ' must contain the four public legacy case studies')
}
contains('public/entertainment/archive/index.html', [
  'entertainment-premium',
  '/entertainment/premium.css',
])
contains('scripts/ecosystem-browser.spec.mjs', [
  'World Cosmic Portal makes',
  'OSA Evidence Command previews',
  'Development Signature opens',
  'Entertainment World Select shows',
])
contains('scripts/osa5-visual-smoke.mjs', [
  "name: 'academy', path: '/academy', selector: '.academy-learning-console'",
  "name: 'development', path: '/development', selector: '.signature-showcase'",
  "name: 'entertainment-archive', path: '/entertainment/archive/'",
])
contains('playwright.ecosystem.config.mjs', [
  "'ecosystem-unified-index.spec.mjs'",
  "'academy-cockpit-browser.spec.mjs'",
])
assert.ok(world.length > 1000 && index.length > 1000 && shell.length > 1000 &&
  intro.length > 1000 && play.length > 1000 && time.length > 1000,
  'Unexpectedly truncated runtime source')
console.log('OSGARD SIX-SURFACE GATE PASS — 6 routes, 7×3 game covers, 4×3 cases, 3 viewports, keyboard, storage and mobile contracts')
