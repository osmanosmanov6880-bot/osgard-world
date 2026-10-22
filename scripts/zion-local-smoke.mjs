import assert from 'node:assert/strict'
import { readFileSync, existsSync, readdirSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import vm from 'node:vm'

const root = resolve('public/games/zion-9')
const text = path => readFileSync(path, 'utf8')
const manifest = JSON.parse(text(resolve(root, 'worlds.json')))
const catalogSource = text('src/redesignCatalog.ts')
const games = JSON.parse(catalogSource.match(/export const playGames:PlayGame\[\] = ([\s\S]*?)\nexport const getPlayGame/)[1])
const hub = text('public/games/index.html')
const inlineScripts = html => [...html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/g)].map(m => m[1]).filter(s => s.trim() && !s.trim().startsWith('{'))
assert.equal(games.length, 19)
assert.equal(new Set(games.map(g => g.id)).size, 19)
assert.equal(manifest.games.length, 11)
assert.equal(manifest.games.filter(g => g.kind === 'Интерактивная история').length, 8)
assert.equal(manifest.games.filter(g => g.kind === 'Головоломка').length, 2)
assert.equal(manifest.games.filter(g => g.kind === '3D-головоломка').length, 1)
assert.ok(!hub.includes('zion-9-worlds/queue/'), 'The catalog must launch local ZION worlds')
assert.ok(hub.includes('root.querySelector(s)'), 'Catalog selectors must respect their scope; consent must not overwrite the contact CTA')
assert.ok(hub.includes('osgard:play-collection:v1'), 'Both catalogs must share the collection')
assert.ok(hub.includes('Array.isArray(v)'), 'Malformed optional storage must not block catalog initialization')
assert.equal(games.find(g => g.id === 'null-shift').launchable, true)
assert.equal(games.find(g => g.id === 'null-shift').alternate.href, '/games/null-shift/')
assert.equal(games.find(g => g.id === 'inherit').mode, 'solo')
assert.match(games.find(g => g.id === 'vector-zero').controls, /W\/↑ — прыжок; Space — запуск ядра/)

for (const item of manifest.games) {
  const path = resolve('public' + item.route)
  const html = text(path)
  const game = games.find(g => g.id === item.id)
  assert.equal(game.href, item.route)
  assert.equal(item.online, false)
  assert.equal(item.save, 'session-only')
  assert.ok(html.includes('href="/games/"'), item.id + ': return to catalog')
  assert.ok(html.includes('z9-entry') && html.includes('Сохранение: только текущая сессия'), item.id + ': pre-launch instructions and save notice')
  assert.ok(html.includes('rel="canonical"') && html.includes('property="og:image"'), item.id + ': page metadata')
  assert.ok(existsSync(resolve('public' + game.asset)), item.id + ': local cover')
  for (const match of html.matchAll(/<(?:script|link)[^>]+(?:src|href)=["']([^"']+)["']/g)) {
    const url = match[1].split('?')[0]
    if (/^(?:https?:|#|mailto:)/.test(url)) continue
    const dependency = url.startsWith('/') ? resolve('public' + url) : resolve(dirname(path), url)
    assert.ok(existsSync(dependency), item.id + ': missing local dependency ' + url)
  }
  for (const script of inlineScripts(html)) new vm.Script(script, { filename: item.id + '.js' })
}
new vm.Script(text(resolve(root, 'language.js')), { filename: 'language.js' })
assert.ok(text(resolve(root, 'language.js')).includes('return "ru";'), 'Russian is the default; saved English remains supported')
// A legacy INHERIT patch had been appended outside <script>, exposing source
// text in the game and skipping snapshot initialization. Parse every block and
// reject executable statements outside script/style elements.
const inherit = text('public/games/inherit/index.html')
const inheritVisible = inherit.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '').replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, '')
assert.ok(!/document\.head\.insertAdjacentHTML|S\.snapshots|let pastMode/.test(inheritVisible), 'INHERIT executable code must not leak into page text')
assert.equal((inherit.match(/<\/html>/g) || []).length, 1, 'INHERIT must have one complete document')
const inheritApi = inherit.match(/const apiWorld=['"]([^'"]+)['"]/)[1]
assert.ok(inheritApi.startsWith('/') && !inheritApi.startsWith('//'), 'INHERIT production API must be same-origin, never visitor localhost')
for (const script of inlineScripts(inherit)) new vm.Script(script, { filename: 'inherit.js' })
const shade = text(resolve(root, 'queue/ZION-030/index.html'))
assert.ok(!/https:\/\/(cdn\.jsdelivr\.net|unpkg\.com)/.test(shade), 'The game engine must be local')
assert.ok(shade.includes('motionPreference.matches'), 'Reduced motion must affect the renderer, not only CSS')
assert.ok(shade.includes('addEventListener("keydown"'), 'The placement puzzle needs a keyboard route')
assert.ok(shade.includes('renderingMode="canvas2d"'), 'A WebGL failure must still leave the same puzzle playable')

const premiumJS = text(resolve(root, 'queue/ZION-030/premium.js'))
const premiumCSS = text(resolve(root, 'queue/ZION-030/premium.css'))
assert.ok(shade.includes('premium.js?v=25') && shade.includes('premium.css?v=25'), 'The published game must load the implemented premium UI')
assert.ok(shade.includes('ZION030_GAME=Object.freeze'), 'The new view must use the real game mechanics')
assert.ok(premiumJS.includes("canvas.getContext('2d'") && premiumJS.includes("game()?.state?.()"), 'The isometric world must be a live canvas, not a static image')
assert.ok(premiumJS.includes('premiumPlace') && premiumJS.includes('premiumMap'), 'Placement and map view must be interactive')
assert.ok(premiumCSS.includes('.premium-mission') && premiumCSS.includes('.premium-how') && premiumCSS.includes('.premium-mode .layout'), 'The approved three-column layout must be styled')
assert.ok(!premiumCSS.includes('data:image/png;base64'), 'The premium interface must not disguise a screenshot as gameplay')
assert.ok(premiumJS.includes("element('button','premium-hot-marker'") && premiumJS.includes("marker.addEventListener('click'"), 'Hotspots are real accessible gameplay targets')
assert.ok(premiumJS.includes("root.dataset.premiumVersion='25'") && premiumCSS.includes('athens-skyline.svg'), 'V23 interactive redesign must be active')
assert.ok(premiumCSS.includes('PREMIUM V24') && premiumCSS.includes('.premium-extra-readable'), 'Large readable font mode should be available')
assert.ok(premiumJS.includes('hasSelectedPlace:false') && premiumJS.includes('state.hasSelectedPlace=true'), 'Explicit placement location must be selected')
assert.ok(premiumJS.includes('premiumSelectionTitle') && premiumJS.includes('how.querySelectorAll'), 'Live next-step guide is required')
assert.ok(premiumJS.includes("districtButtons") && premiumJS.includes("premiumShowHints"), "v25 interactive district objective cards")
assert.ok(premiumJS.includes("state.mode==='map'") && premiumJS.includes("const pos=S(p.x,p.z,state.mode==="), "v25 true overhead map markers")
assert.ok(premiumJS.includes("futureCoverage") && premiumJS.includes("showHints:false"), "v25 live cooling preview and opt-in site highlights")
assert.ok(premiumCSS.includes("v25 THERMAL RESCUE") && premiumCSS.includes(".premium-district.is-cooled"), "v25 accessibility and task states")
new vm.Script(premiumJS, { filename: 'zion-premium.js' })


// Execute actual game scripts with a small DOM/Canvas harness. This proves game
// state and input behavior; it deliberately does not claim GPU or visual QA.
class Element {
  constructor(tag = 'div') { this.tagName = tag.toUpperCase(); this.children = []; this.dataset = {}; this.attrs = {}; this.listeners = {}; this.style = {}; this.disabled = false; this._text = ''; this.classes = new Set() }
  get classList() { return { add: (...v) => v.forEach(x => this.classes.add(x)), remove: (...v) => v.forEach(x => this.classes.delete(x)), contains: x => this.classes.has(x), toggle: (x, yes) => { if (yes ?? !this.classes.has(x)) this.classes.add(x); else this.classes.delete(x) } } }
  set className(v) { this.classes = new Set(v.split(/\s+/).filter(Boolean)) }
  get className() { return [...this.classes].join(' ') }
  set innerHTML(v) { this.children = []; this._text = v }
  set textContent(v) { this._text = String(v) }
  get textContent() { return this._text + this.children.map(c => c.textContent).join('') }
  append(...children) { this.children.push(...children) }
  appendChild(child) { this.children.push(child); return child }
  replaceChildren(...children) { this.children = children }
  setAttribute(k, v) { this.attrs[k] = String(v) }
  getAttribute(k) { return this.attrs[k] ?? null }
  addEventListener(k, fn) { (this.listeners[k] ||= []).push(fn) }
  dispatch(k, event = {}) { for (const fn of this.listeners[k] || []) fn({ preventDefault() {}, ...event }) }
  click() { if (!this.disabled) this.dispatch('click') }
  querySelectorAll(selector) { return this.children.filter(x => selector === 'button' ? x.tagName === 'BUTTON' : false) }
  getBoundingClientRect() { return { left: 0, top: 0, width: 390, height: 490 } }
  get clientWidth() { return 390 }
  get clientHeight() { return 490 }
  getContext(kind) { return kind === '2d' ? { setTransform() {}, fillRect() {}, beginPath() {}, arc() {}, fill() {}, strokeRect() {} } : null }
}
function harness() {
  const elements = new Map(), pips = [new Element(), new Element(), new Element()], modules = ['tree', 'shade', 'water'].map(type => { const b = new Element('button'); b.dataset.type = type; return b }), arrows = ['left', 'right', 'up', 'down'].map(dir => { const b = new Element('button'); b.dataset.cursor = dir; return b })
  const get = id => { if (!elements.has(id)) elements.set(id, new Element()); return elements.get(id) }
  const timers = new Map(); let timerId = 0
  const events = new Map()
  const document = { hidden: false, getElementById: get, createElement: tag => new Element(tag), querySelectorAll: selector => selector === '.pip' || selector === '#meter i' ? pips : selector === '.module' ? modules : selector === '[data-cursor]' ? arrows : [] }
  const context = { document, navigator: {}, location: { search: '?test=1' }, URLSearchParams, console, matchMedia: () => ({ matches: true }), devicePixelRatio: 1, ResizeObserver: class { observe() {} }, setTimeout(fn) { const id = ++timerId; timers.set(id, fn); return id }, clearTimeout: id => timers.delete(id), addEventListener(name, fn) { (events.get(name) || (events.set(name, []), events.get(name))).push(fn) } }
  context.window = context
  vm.createContext(context)
  return { context, get, pips, timers, modules, arrows, emit(name) { for (const fn of events.get(name) || []) fn() }, flush() { const pending = [...timers.values()]; timers.clear(); for (const fn of pending) fn() } }
}
// INHERIT's history Done action must leave both existing past modes, without
// advancing the generation or changing the saved world. Run the real handlers.
{
  const history = harness(), document = history.context.document
  document.querySelector = selector => history.get(selector.replace(/^#/, ''))
  document.head = { insertAdjacentHTML() {} }
  document.body = new Element()
  const world = { generation: 173, budget: 99, changes: [], objects: [{ tool: 'tree', x: 60, y: 40 }], history: [], snapshots: [{ generation: 172, objects: [{ tool: 'stone', x: 20, y: 35 }] }] }
  const savedWorld = JSON.stringify(world), storage = new Map([['inherit-world-v1', savedWorld]])
  let writes = 0
  history.context.localStorage = { getItem: key => storage.get(key) ?? null, setItem(key, value) { writes++; storage.set(key, value) } }
  const modal = history.get('modal')
  modal.showModal = () => { modal.open = true }
  modal.close = () => { modal.open = false }
  for (const id of ['showHistory', 'past', 'done']) {
    const button = history.get(id)
    button.click = () => { button.onclick?.(); button.dispatch('click') }
  }
  const scripts = inlineScripts(inherit)
  for (const script of [scripts[0], scripts.find(s => s.includes('let pastMode=')), scripts.find(s => s.includes('function returnToToday()'))]) {
    assert.ok(script, 'INHERIT history and replay handlers must exist')
    vm.runInContext(script, history.context, { filename: 'inherit-history.js' })
  }
  history.get('showHistory').click()
  assert.equal(modal.open, true)
  history.get('past').click()
  assert.equal(document.body.classList.contains('past'), true)
  history.get('done').click()
  assert.equal(document.body.classList.contains('past'), false, 'INHERIT Return to today must exit past traces')
  assert.equal(history.get('past').textContent, 'Show past traces')
  assert.equal(modal.open, false)
  history.get('showHistory').click()
  history.get('done').click()
  assert.equal(document.body.classList.contains('past'), false, 'Returning while already present must not toggle into the past')
  vm.runInContext('drawReplay(snapshotFor(172))', history.context)
  assert.equal(document.body.classList.contains('replay-mode'), true)
  assert.equal(history.get('objects').children[0].className, 'placed stone')
  history.get('showHistory').click()
  history.get('past').click()
  history.get('done').click()
  assert.equal(document.body.classList.contains('past'), false)
  assert.equal(document.body.classList.contains('replay-mode'), false, 'Return to today must leave preserved-generation replay')
  assert.equal(vm.runInContext('replayGeneration', history.context), null)
  assert.equal(history.get('objects').children[0].className, 'placed tree', 'Return must redraw the current generation')
  assert.equal(modal.open, false)
  assert.equal(vm.runInContext('JSON.stringify(S)', history.context), savedWorld)
  assert.equal(storage.get('inherit-world-v1'), savedWorld)
  assert.equal(writes, 0, 'Returning from history must not mutate persistent world data')
}
for (const id of ['020', '021']) {
  const h = harness()
  vm.runInContext(inlineScripts(text(resolve(root, `queue/ZION-${id}/index.html`)))[0], h.context)
  const nodes = () => h.get('nodes').children
  const order = id === '020' ? [0, 1, 2] : [0, 2, 1]
  nodes()[order[2]].click()
  nodes()[order[0]].click()
  assert.equal(nodes().some(b => b.classList.contains('done')), false, id + ': input during reset must be ignored')
  h.get('reset').click()
  assert.equal(h.timers.size, 0, id + ': manual reset cancels a pending error reset')
  for (const n of order) nodes()[n].click()
  assert.equal(h.get('reveal').classList.contains('on'), true, id + ': correct sequence must reveal the ending')
  h.get('reset').click()
  assert.equal(h.get('reveal').classList.contains('on'), false, id + ': reset clears the ending')
  assert.equal(nodes().every(b => !b.disabled), true, id + ': reset enables all nodes')
}
const h = harness()
vm.runInContext(inlineScripts(shade)[1], h.context)
h.emit('zion-three-failed')
const api = h.context.__ZION9_TEST__
assert.ok(api, 'The fallback must expose the same opt-in test contract')
assert.equal(api.state().renderingMode, 'canvas2d')
assert.equal(api.state().webgl, false, 'The fallback must not claim to be WebGL')
for (let n = 0; n < 4; n++) h.get('scene').dispatch('keydown', { key: 'ArrowLeft' })
for (let n = 0; n < 3; n++) h.get('scene').dispatch('keydown', { key: 'ArrowUp' })
h.get('scene').dispatch('keydown', { key: 'Enter' })
assert.equal(api.state().score, 1, 'Keyboard placement must cover the selected hotspot')
assert.equal(api.placeAt(-4, -3, 'tree').ok, false, 'An occupied tile cannot consume another module')
assert.equal(api.state().placed, 1)
assert.equal(api.placeAt(2, 2, 'shade').ok, true)
assert.equal(api.placeAt(4, -2, 'water').ok, true)
assert.equal(api.state().won, true, 'Three covered hotspots win')
assert.equal(api.state().score, 3)
assert.equal(api.placeAt(0, 0, 'tree').ok, false, 'A completed mission cannot spend a fourth module')
api.reset()
assert.equal(api.state().won, false)
assert.equal(api.state().placed, 0)
for (const [x, z] of [[0, 0], [1, 0], [0, 1]]) assert.equal(api.placeAt(x, z, 'tree').ok, true)
assert.equal(api.state().lost, true, 'Three off-target placements exhaust the budget')
api.reset()
assert.equal(api.state().lost, false)
assert.equal(api.placeAt(0, 0, 'tree').ok, true, 'Reset must free cells placed in the previous round')

// Optional post-deployment check: use a deliberately selected URL, never a guessed API.
if (process.env.ZION_BASE_URL) {
  const base = new URL(process.env.ZION_BASE_URL)
  for (const item of manifest.games) {
    const response = await fetch(new URL(item.route, base))
    assert.equal(response.status, 200, item.route)
    const body = await response.text()
    assert.ok(body.includes('z9-entry') && body.includes('world-play'), item.route + ': served the imported world, not SPA fallback')
  }
}
console.log('PASS local ZION release: 19 unique catalog entries; 11 complete local worlds; RU default/EN choice; dependency closure; exact format and persistence disclosures; reset-race fixes; INHERIT history returns to the present without changing saved world data; actual keyboard, win/loss/reset behavior in the lightweight renderer. GPU rendering and visual layout require browser QA.')
