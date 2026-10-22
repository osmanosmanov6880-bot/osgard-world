import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'
import { osgardCommands, getOsgardContextSuggestions, searchOsgardCommands, readQuickNavRecent, rememberQuickNav, clearQuickNavRecent } from '../src/osgardQuickNavData.ts'

const repo = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const read = path => readFileSync(resolve(repo, path), 'utf8')

assert.equal(osgardCommands.length, 43, 'Twelve core routes, four portfolio pages, 19 games and eight lessons must be indexed')
assert.equal(osgardCommands.filter(item => item.id.startsWith('game-')).length, 19)
assert.equal(osgardCommands.filter(item => item.id.startsWith('lesson-')).length, 8)
for (const item of osgardCommands.filter(item => item.id.startsWith('game-'))) {
  assert.match(item.href, /^\/play\/world\/[a-z0-9-]+$/, 'Direct game route must use the real Play detail page')
  assert.ok(item.label && !/undefined|null/.test(item.label), 'No missing game title')
}
for (const item of osgardCommands.filter(item => item.id.startsWith('lesson-'))) {
  assert.match(item.href, /^\/lectures\/[a-z0-9-]+$/, 'Direct OSA lesson route must exist in the registry')
  assert.ok(item.label && !/undefined|null/.test(item.label), 'No missing lesson title')
}
assert.equal(new Set(osgardCommands.map(item => item.id)).size, osgardCommands.length, 'Command ids must be unique')
assert.equal(new Set(osgardCommands.map(item => item.href)).size, osgardCommands.length, 'Route destinations must not duplicate')
for (const item of osgardCommands) {
  assert.match(item.href, /^\/(?!\/)/, 'Only local first-party routes are allowed: ' + item.id)
  assert.ok(item.label.length > 2 && item.description.length > 10 && item.group, 'Honest descriptive labels required')
}
assert.deepEqual(searchOsgardCommands('аКаДеМиЯ').map(x => x.id), ['academy'])
assert.deepEqual(searchOsgardCommands('несуществующий-раздел').map(x => x.id), [], 'Unknown routes must never be fabricated')
assert.deepEqual(searchOsgardCommands('TEDES').map(x => x.id), ['case-tedes', 'cases'])
assert.equal(searchOsgardCommands('frfltvbz')[0]?.id, 'academy', 'Recover English keyboard layout for academy')
assert.ok(searchOsgardCommands('buhs').some(item => item.id === 'play'), 'English layout can find game catalog')
assert.equal(searchOsgardCommands('добавь тень')[0]?.id, 'game-zion-030', 'Mechanic alias finds genuine shadow game')
assert.equal(searchOsgardCommands('империя времени')[0]?.id, 'game-time', 'Exact game title outranks sequel')
assert.equal(searchOsgardCommands('проверьте ответ ии')[0]?.id, 'lesson-verify-an-ai-answer', 'Find direct evidence lesson')
for (const id of ['phantom','tedes','merakki','essentia']) {
  const result = osgardCommands.find(command => command.id === 'case-' + id)
  assert.equal(result?.href, '/development/' + id + '/')
}
assert.deepEqual(searchOsgardCommands('Портфолио проектов').map(x => x.id), ['cases'])
assert.equal(osgardCommands.filter(item => item.art?.startsWith('/brand/play/')).length, 19)
assert.ok(osgardCommands.filter(item => item.id.startsWith('case-')).every(item => item.art?.startsWith('/')), 'Real portfolio art is self-hosted')
assert.deepEqual(getOsgardContextSuggestions('/play/world/zion-030').map(x => x.id), ['play','favorites','recent-games'])
assert.deepEqual(getOsgardContextSuggestions('/lectures/verify-an-ai-answer').map(x => x.id), ['academy','lectures','progress'])
assert.deepEqual(getOsgardContextSuggestions('/development/tedes/').map(x => x.id), ['development','cases','case-tedes'])
assert.deepEqual(getOsgardContextSuggestions('/').map(x => x.id), ['intelligence','play','development'])
assert.ok(searchOsgardCommands('игры').some(item => item.id === 'play'))
assert.deepEqual(searchOsgardCommands('ё'), searchOsgardCommands('е'), 'Russian ё and е must search identically')
assert.deepEqual(searchOsgardCommands('', ['cases', 'academy']).slice(0, 2).map(x => x.id), ['cases', 'academy'])

const oldSession = globalThis.sessionStorage
const store = new Map()
globalThis.sessionStorage = {
  getItem: key => store.has(key) ? store.get(key) : null,
  setItem: (key, value) => store.set(key, value),
  removeItem: key => store.delete(key),
}
try {
  assert.deepEqual(readQuickNavRecent(), [])
  rememberQuickNav('world'); rememberQuickNav('play'); rememberQuickNav('world')
  assert.deepEqual(readQuickNavRecent(), ['world', 'play'])
  // Failed or untrusted saved data can never become a dynamic route.
  store.set('osgard:quick-nav:session', JSON.stringify(['world', 'unknown', 'world', 15]))
  assert.deepEqual(readQuickNavRecent(), ['world'])
  clearQuickNavRecent()
  assert.deepEqual(readQuickNavRecent(), [])
} finally {
  if (oldSession === undefined) delete globalThis.sessionStorage
  else globalThis.sessionStorage = oldSession
}

const shell = read('src/BrandShell.tsx')
const palette = read('src/OsgardQuickNav.tsx')
const page = read('src/main.tsx')
const loading = read('src/OsgardRouteSkeleton.tsx')
const navCss = read('src/osgardQuickNav.css')
const loadCss = read('src/osgardRouteSkeleton.css')
assert.ok(shell.includes("lazy(() => import('./OsgardQuickNav'))"), 'Navigator must not enter the eager app shell')
assert.ok(shell.includes("lazy(() => import('./OsgardFooter'))") && read('src/OsgardFooter.tsx').includes('Повторить заставку'), 'Footer must be deferred without losing core navigation or replay')
assert.ok(shell.includes('Control+K Meta+K') && shell.includes("event.key.toLowerCase() === 'k'") &&
  shell.includes("event.key === '/'") && shell.includes('!inputTarget && !inGame'),
  'Ctrl/Meta+K and slash shortcuts must skip editable inputs, games and cinematic overlays')
assert.ok(shell.includes('aria-expanded={quickOpen}') && shell.includes('onClose={closeQuickNav}'), 'Trigger and modal state must be accessible')
assert.ok(palette.includes('role="dialog" aria-modal="true"') && palette.includes("onKeyDown={handleInputKey}"), 'Dialog and keyboard search contract required')
assert.ok(palette.includes("if (event.key === 'Home')") && palette.includes("if (event.key === 'End')") &&
  palette.includes("scrollIntoView({ block: 'nearest'") && palette.includes('selectedIndex'),
  'Keyboard list selection must stay visible, bounded and screen-reader discoverable')
assert.ok(palette.includes('aria-label="Фильтр по направлениям"') &&
  palette.includes('aria-pressed={group === value}') &&
  palette.includes('getOsgardContextSuggestions(location.pathname)') &&
  palette.includes('command.art &&'), 'Navigator must have real group filters, context actions and image previews')
assert.ok(palette.includes('navigateBrowserUrl(command.href)') && palette.includes('hasUnsavedChanges()'), 'Navigator must preserve SPA and dirty-form guards')
assert.ok(palette.includes("document.body.style.overflow = before") && palette.includes("document.removeEventListener('keydown'") &&
  palette.includes('previousInert') && palette.includes('observer?.disconnect()') &&
  palette.includes('element.inert = inert'), 'Modal must release scroll, listeners and previous background inert state')
assert.ok(page.includes("<OsgardRouteSkeleton theme={theme} path={path} />") &&
  loading.includes("data-skeleton-area={area}") &&
  ['academy', 'development', 'lectures', 'entertainment'].every(route => loading.includes(route)),
  'Lazy routes must show honest product-specific loading without invented data')
assert.ok(loading.includes('aria-busy="true"') && loading.includes('role="status"') && loading.includes('min-height') === false, 'Loading state must be semantic and CSS-driven')
assert.ok(navCss.includes('@media(max-width:720px)') && navCss.includes('max-height:100dvh'), 'Navigator must fit the mobile viewport')
assert.ok(loadCss.includes('min-height:clamp') && loadCss.includes('prefers-reduced-motion:reduce'), 'Loading state must reserve layout and respect reduced motion')
console.log('PASS: 43 first-party commands, safe session history, keyboard dialog, SPA guard, mobile shell and honest route loading')
