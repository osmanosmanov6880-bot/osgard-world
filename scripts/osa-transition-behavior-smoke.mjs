import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { pathToFileURL } from 'node:url'
import vm from 'node:vm'

const source = readFileSync('public/brand/osa-transition.js', 'utf8')
const STORAGE_KEY = 'osgard:portal-navigation:v2'
const CLOCK = 100000

// Execute the shipped script, including its destination lifecycle. Minifier
// identifiers and whitespace are not part of the navigation contract.
class FakeElement {
  constructor({ href = '', target = '', download = false, rel = '', anchor = null, game = false, card = null } = {}) {
    Object.assign(this, { href, target, anchor, card, className: '', children: [], removed: false, textContent: '' })
    this.attributes = new Map([...(download ? [['download', '']] : []), ...(game ? [['data-game-launch', '']] : [])])
    this.queries = new Map()
    const relations = new Set(rel.split(/\s+/).filter(Boolean))
    this.relList = { contains: value => relations.has(value) }
    this.classList = { add: name => { this.className += ' ' + name } }
  }
  get childElementCount() { return this.children.filter(child => !child.removed).length }
  closest(selector) {
    if (selector === 'a[href]') return this.anchor || (this.href ? this : null)
    if (selector === '.play-card') return this.card || this.anchor?.card || null
    return null
  }
  querySelector(selector) { return this.queries.get(selector) || null }
  hasAttribute(name) { return this.attributes.has(name) }
  setAttribute(name, value) { this.attributes.set(name, String(value)) }
  getAttribute(name) { return this.attributes.get(name) ?? null }
  append(...children) { this.children.push(...children) }
  remove() { this.removed = true }
}

function harness(pathname, {
  reducedMotion = false, motionOff = false, storage = new Map(), intent,
  reactRoot = false, rootReady = true, readyState = 'complete', bodyReady = true,
  storageDenied = false, preview = null, title = ''
} = {}) {
  if (intent !== undefined) storage.set(STORAGE_KEY, typeof intent === 'string' ? intent : JSON.stringify(intent))
  let elapsed = 0
  const listeners = new Map(), timers = [], observers = [], frames = []
  const url = new URL(pathname, 'https://osgard.world')
  const body = new FakeElement(), root = reactRoot ? new FakeElement() : null
  if (rootReady && root) root.append(new FakeElement())
  const queries = new Map()
  if (preview) queries.set('.play-detail-art', { src: preview })
  if (title) queries.set('.play-detail h1', { textContent: title })
  const document = {
    documentElement: { dataset: {} }, body: bodyReady ? body : null, readyState,
    addEventListener(type, handler, options = {}) {
      const entries = listeners.get(type) || []
      entries.push({ handler, once: options.once === true })
      listeners.set(type, entries)
    },
    getElementById: id => id === 'root' ? root : null,
    querySelector: selector => queries.get(selector) || null,
    createElement: () => new FakeElement()
  }
  const sessionStorage = {
    getItem(key) { if (storageDenied) throw new Error('storage denied'); return storage.get(key) ?? null },
    setItem(key, value) { if (storageDenied) throw new Error('storage denied'); storage.set(key, String(value)) },
    removeItem(key) { if (storageDenied) throw new Error('storage denied'); storage.delete(key) }
  }
  const emit = (type, event = {}) => {
    for (const entry of [...(listeners.get(type) || [])]) {
      entry.handler(event)
      if (entry.once) listeners.set(type, listeners.get(type).filter(item => item !== entry))
    }
  }
  class MutationObserver {
    constructor(handler) { this.handler = handler; this.active = false; observers.push(this) }
    observe() { this.active = true }
    disconnect() { this.active = false }
  }
  vm.runInNewContext(source, {
    document, location: url, sessionStorage, URL, Element: FakeElement,
    Date: { now: () => CLOCK + elapsed },
    localStorage: { getItem() { if (storageDenied) throw new Error('storage denied'); return motionOff ? 'off' : 'on' } },
    matchMedia: () => ({ matches: reducedMotion }),
    requestAnimationFrame: handler => { frames.push(handler); return frames.length },
    setTimeout: (handler, delay) => { timers.push({ handler, at: elapsed + delay, done: false }); return timers.length },
    MutationObserver
  }, { filename: 'osa-transition.js' })
  assert.ok(listeners.get('click')?.length, 'transition click listener must register')
  return {
    storage, document, profile: document.documentElement.dataset.product,
    overlays: () => body.children.filter(child => !child.removed && child.className.split(/\s+/).includes('osgard-portal-transition')),
    activeObservers: () => observers.filter(observer => observer.active).length,
    ready() { document.body = body; document.readyState = 'complete'; emit('DOMContentLoaded') },
    mount() {
      root?.append(new FakeElement())
      for (const observer of observers) if (observer.active) observer.handler([])
    },
    frames() { for (let round = 0; frames.length && round < 10; round++) frames.splice(0).forEach(handler => handler()) },
    advance(ms) {
      const until = elapsed + ms
      for (;;) {
        const timer = timers.filter(item => !item.done && item.at <= until).sort((a, b) => a.at - b.at)[0]
        if (!timer) break
        elapsed = timer.at; timer.done = true; timer.handler()
      }
      elapsed = until
    },
    click(href, options = {}) {
      const anchor = new FakeElement(options.anchor || { href, ...options })
      const target = options.child ? new FakeElement({ anchor }) : anchor
      let intercepted = false
      const event = {
        defaultPrevented: false, button: 0, metaKey: false, ctrlKey: false, shiftKey: false, altKey: false, target,
        preventDefault() { intercepted = true }, stopPropagation() { intercepted = true }, ...options.event
      }
      const originalURL = url.href
      emit('click', event)
      assert.equal(intercepted, false, 'visual transition must never intercept native navigation')
      assert.equal(url.href, originalURL, 'visual transition must never replace the destination')
      const stored = storage.get(STORAGE_KEY)
      return stored ? JSON.parse(stored) : null
    }
  }
}

export function runTransitionBehaviorChecks() {
  const checks = []
  const check = (name, run) => { run(); checks.push(name) }
  const expectStore = (name, from, href, expectedPath, expectedTheme, options = {}) => {
    let value
    check(name, () => {
      value = harness(from, options).click(href, options)
      assert.ok(value, name + ': expected transition intent')
      assert.equal(value.path, expectedPath, name + ': unexpected destination')
      assert.equal(value.theme, expectedTheme, name + ': unexpected palette')
      assert.equal(value.at, CLOCK, name + ': intent must carry the current timestamp')
    })
    return value
  }
  const expectNoStore = (name, from, href, options = {}) => check(name, () => {
    assert.equal(harness(from, options).click(href, options), null, name + ': unexpected transition intent')
  })

  expectStore('world-to-intelligence', '/', '/intelligence', '/intelligence', 'intelligence')
  expectStore('nested icon resolves parent anchor', '/', '/intelligence', '/intelligence', 'intelligence', { child: true })
  expectStore('trailing slashes normalize', '/', '/intelligence///', '/intelligence', 'intelligence')
  expectStore('world-to-play', '/portal', '/games/', '/games', 'play')
  expectStore('play-to-intelligence', '/games/', '/lectures', '/lectures', 'intelligence')
  expectStore('explicit current browsing context', '/', '/play', '/play', 'play', { target: '_self' })
  const launch = expectStore('game launch carries world context', '/play/world/zion-030', '/games/zion-9/queue/ZION-030/', '/games/zion-9/queue/ZION-030', 'play', {
    game: true, preview: '/games/zion-9/covers/zion-030.svg', title: 'ОХЛАДИ ГОРОД'
  })
  assert.equal(launch.game, true)
  assert.equal(launch.preview, '/games/zion-9/covers/zion-030.svg')
  assert.equal(launch.title, 'ОХЛАДИ ГОРОД')
  const card = new FakeElement()
  card.queries.set('.play-card-art img', { currentSrc: 'https://osgard.world/brand/cover-time.svg' })
  card.queries.set('h3', { textContent: 'TIME' })
  const selected = expectStore('selected game card becomes its world portal', '/play', '/play/world/time', '/play/world/time', 'play', { card })
  assert.equal(selected.game, true); assert.equal(selected.preview, '/brand/cover-time.svg'); assert.equal(selected.title, 'TIME')
  const partner = expectStore('Play partner keeps product with a calm palette', '/intelligence', '/play/partners', '/play/partners', 'world')
  assert.equal(partner.product, 'play')

  for (const [path, palette] of [
    ['/', 'world'], ['/development/merakki/en/', 'world'], ['/tedes/catalog/', 'world'], ['/skillcred/', 'world'],
    ['/lectures/intelligence-and-imitation', 'intelligence'], ['/learning/campus', 'intelligence'], ['/osa-library/', 'intelligence'],
    ['/games/time', 'play'], ['/play/world/zion-030', 'play'], ['/entertainment/', 'play'], ['/play/partners', 'world'],
    ['/learning-other', 'world']
  ]) check('palette for ' + path, () => assert.equal(harness(path).profile, palette))

  expectNoStore('same studio product', '/portal', '/development/merakki/en/')
  expectNoStore('same OSA product', '/academy', '/lectures')
  expectNoStore('partner page keeps Play identity', '/play/partners', '/play')
  expectNoStore('same normalized path', '/portal', '/portal/')
  expectNoStore('same path with query', '/portal', '/portal?campaign=one')
  expectNoStore('same path with hash', '/play', '/play#catalog')
  expectNoStore('external origin', '/', 'https://example.com/intelligence')
  expectNoStore('download link', '/', '/intelligence', { download: true })
  expectNoStore('new browsing context', '/', '/intelligence', { target: '_blank' })
  expectNoStore('external rel token', '/', '/intelligence', { rel: 'external noopener' })
  for (const modifier of ['ctrlKey', 'metaKey', 'shiftKey', 'altKey']) {
    expectNoStore(modifier + ' click', '/', '/intelligence', { event: { [modifier]: true } })
  }
  expectNoStore('middle click', '/', '/intelligence', { event: { button: 1 } })
  expectNoStore('already cancelled event', '/', '/intelligence', { event: { defaultPrevented: true } })
  expectNoStore('non-element click target', '/', '/intelligence', { event: { target: null } })
  expectNoStore('system reduced motion', '/', '/intelligence', { reducedMotion: true })
  expectNoStore('saved motion preference', '/portal', '/games/', { motionOff: true })
  expectNoStore('script protocol', '/', 'javascript:alert(1)')
  expectNoStore('mail protocol', '/', 'mailto:hello@osgard.world')
  expectNoStore('unavailable storage keeps ordinary navigation', '/', '/play', { storageDenied: true })

  const intent = { path: '/play', theme: 'play', product: 'play', at: CLOCK }
  check('destination consumes intent once and removes overlay within 600ms', () => {
    const page = harness('/play', { intent })
    assert.equal(page.storage.has(STORAGE_KEY), false, 'destination consumes intent before rendering')
    assert.equal(page.overlays().length, 1, 'one overlay must appear')
    assert.equal(page.overlays()[0].getAttribute('aria-hidden'), 'true')
    page.frames()
    assert.ok(page.overlays()[0].className.includes('portal-reveal'), 'overlay reaches its reveal state')
    page.advance(600)
    assert.equal(page.overlays().length, 0, 'overlay has a short bounded lifetime')
    page.ready(); page.mount(); page.advance(2000)
    assert.equal(page.overlays().length, 0, 'ready/mutation/timer callbacks do not replay it')
    assert.equal(harness('/play', { storage: page.storage }).overlays().length, 0, 'reload does not replay it')
  })
  check('React destination waits for content and renders once', () => {
    const page = harness('/play', { intent, reactRoot: true, rootReady: false })
    assert.equal(page.overlays().length, 0); assert.equal(page.activeObservers(), 1)
    page.advance(100); page.mount(); page.mount()
    assert.equal(page.overlays().length, 1); assert.equal(page.activeObservers(), 0)
    page.advance(600); assert.equal(page.overlays().length, 0)
  })
  check('empty app has a bounded observer lifetime', () => {
    const page = harness('/play', { intent, reactRoot: true, rootReady: false })
    page.advance(2000)
    assert.equal(page.overlays().length, 0); assert.equal(page.activeObservers(), 0)
    page.mount(); assert.equal(page.overlays().length, 0)
  })
  check('static destination waits for DOM readiness', () => {
    const page = harness('/play', { intent, readyState: 'loading', bodyReady: false })
    assert.equal(page.overlays().length, 0)
    page.ready(); page.ready(); assert.equal(page.overlays().length, 1)
  })
  for (const options of [{ reducedMotion: true }, { motionOff: true }]) {
    check('destination consumes but skips motion: ' + JSON.stringify(options), () => {
      const page = harness('/play', { intent, ...options })
      assert.equal(page.storage.has(STORAGE_KEY), false); assert.equal(page.overlays().length, 0)
    })
  }
  for (const [name, invalid] of [
    ['expired intent', { ...intent, at: CLOCK - 5001 }],
    ['wrong destination', { ...intent, path: '/intelligence' }],
    ['unknown palette', { ...intent, theme: 'untrusted' }],
    ['invalid timestamp', { ...intent, at: 'now' }],
    ['malformed storage', '{']
  ]) check(name + ' cannot display a portal', () => assert.equal(harness('/play', { intent: invalid }).overlays().length, 0))
  check('game destination uses chosen image and literal title', () => {
    const [image, label] = harness(launch.path, { intent: launch }).overlays()[0].children
    assert.equal(image.src, launch.preview); assert.equal(image.alt, ''); assert.equal(label.textContent, 'ОХЛАДИ ГОРОД')
  })
  for (const preview of ['https://example.com/cover.svg', 'javascript:alert(1)', '/private/cover.svg', '/brand/script.js']) {
    check('unsafe preview falls back to the mark: ' + preview, () => {
      const [image, label] = harness('/play', { intent: { ...intent, game: true, preview, title: '<img src=x>' } }).overlays()[0].children
      assert.equal(image.src, '/brand/portal-play.svg'); assert.equal(label.textContent, '<img src=x>', 'title is text, not HTML')
    })
  }
  check('calm partner destination renders the Play mark', () => {
    const page = harness('/play/partners', { intent: partner })
    assert.ok(page.overlays()[0].className.includes('portal-world'))
    assert.equal(page.overlays()[0].children[0].src, '/brand/portal-play.svg')
    assert.equal(page.overlays()[0].children[1].textContent, 'OSGARD PLAY')
  })
  return { checks: checks.length }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const result = runTransitionBehaviorChecks()
  console.log('OSA_TRANSITION_BEHAVIOR_PASS: ' + result.checks + ' runtime checks; contextual, one-shot, bounded, motion-aware transitions preserve native navigation.')
}
