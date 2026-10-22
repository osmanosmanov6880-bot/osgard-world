import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'
import { osgardCommands, searchOsgardCommands, readQuickNavRecent, rememberQuickNav, clearQuickNavRecent } from '../src/osgardQuickNavData.ts'

const repo = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const read = path => readFileSync(resolve(repo, path), 'utf8')

assert.equal(osgardCommands.length, 12, 'All real top-level and secondary destinations must be indexed')
assert.equal(new Set(osgardCommands.map(item => item.id)).size, osgardCommands.length, 'Command ids must be unique')
assert.equal(new Set(osgardCommands.map(item => item.href)).size, osgardCommands.length, 'Route destinations must not duplicate')
for (const item of osgardCommands) {
  assert.match(item.href, /^\/(?!\/)/, 'Only local first-party routes are allowed: ' + item.id)
  assert.ok(item.label.length > 2 && item.description.length > 10 && item.group, 'Honest descriptive labels required')
}
assert.deepEqual(searchOsgardCommands('аКаДеМиЯ').map(x => x.id), ['academy'])
assert.deepEqual(searchOsgardCommands('несуществующий-раздел').map(x => x.id), [], 'Unknown routes must never be fabricated')
assert.deepEqual(searchOsgardCommands('TEDES').map(x => x.id), ['cases'])
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
assert.ok(shell.includes('Control+K Meta+K') && shell.includes("event.key.toLowerCase() !== 'k'"), 'Keyboard shortcut must be exposed and functional')
assert.ok(shell.includes('aria-expanded={quickOpen}') && shell.includes('onClose={closeQuickNav}'), 'Trigger and modal state must be accessible')
assert.ok(palette.includes('role="dialog" aria-modal="true"') && palette.includes("onKeyDown={handleInputKey}"), 'Dialog and keyboard search contract required')
assert.ok(palette.includes('navigateBrowserUrl(command.href)') && palette.includes('hasUnsavedChanges()'), 'Navigator must preserve SPA and dirty-form guards')
assert.ok(palette.includes("document.body.style.overflow = before") && palette.includes("document.removeEventListener('keydown'"), 'Scroll lock and key listeners must clean up')
assert.ok(page.includes("<OsgardRouteSkeleton theme={theme} />"), 'Deferred sections must render the honest loading shell')
assert.ok(loading.includes('aria-busy="true"') && loading.includes('role="status"') && loading.includes('min-height') === false, 'Loading state must be semantic and CSS-driven')
assert.ok(navCss.includes('@media(max-width:720px)') && navCss.includes('max-height:100dvh'), 'Navigator must fit the mobile viewport')
assert.ok(loadCss.includes('min-height:clamp') && loadCss.includes('prefers-reduced-motion:reduce'), 'Loading state must reserve layout and respect reduced motion')
console.log('PASS: twelve first-party commands, safe session history, keyboard dialog, SPA guard, mobile shell and honest route loading')
