import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import vm from 'node:vm'

const source = readFileSync('public/brand/osa-transition.js', 'utf8')
const STORAGE_KEY = 'osgard:portal-navigation:v2'

class FakeElement {
  constructor({ href = '', target = '', download = false, rel = '', anchor = null, game = false } = {}) {
    this.href = href
    this.target = target
    this.anchor = anchor
    this.attributes = new Set([...(download ? ['download'] : []), ...(game ? ['data-game-launch'] : [])])
    const relations = new Set(rel.split(/\s+/).filter(Boolean))
    this.relList = { contains: value => relations.has(value) }
  }
  closest(selector) {
    if (selector !== 'a[href]') return null
    return this.anchor || (this.href ? this : null)
  }
  hasAttribute(name) { return this.attributes.has(name) }
}

function harness(pathname, { reducedMotion = false, motionOff = false } = {}) {
  const writes = new Map()
  let clickHandler
  const url = new URL(pathname, 'https://osgard.world')
  const document = {
    documentElement: { dataset: { motion: motionOff ? 'off' : 'on' } },
    addEventListener(type, handler) {
      if (type === 'click') clickHandler = handler
    },
    getElementById() { return null },
    readyState: 'complete'
  }
  const sessionStorage = {
    getItem: key => writes.has(key) ? writes.get(key) : null,
    setItem: (key, value) => writes.set(key, String(value)),
    removeItem: key => writes.delete(key)
  }

  vm.runInNewContext(source, {
    document,
    location: url,
    sessionStorage,
    URL,
    Element: FakeElement,
    Date,
    console,
    matchMedia: () => ({ matches: reducedMotion })
  }, { filename: 'osa-transition.js' })

  assert.equal(typeof clickHandler, 'function', 'transition click listener must register')
  return {
    profile: document.documentElement.dataset.product,
    click(href, options = {}) {
      const anchor = new FakeElement(options.anchor || { href, ...options })
      const target = options.child ? new FakeElement({ anchor }) : anchor
      const event = {
        defaultPrevented: false,
        button: 0,
        metaKey: false,
        ctrlKey: false,
        shiftKey: false,
        altKey: false,
        target,
        ...options.event
      }
      clickHandler(event)
      const stored = writes.get(STORAGE_KEY)
      return stored ? JSON.parse(stored) : null
    }
  }
}

const expectStore = (name, from, href, expectedPath, expectedTheme, options = {}) => {
  const h = harness(from)
  const value = h.click(href, options)
  assert.ok(value, name + ': expected transition intent to be stored')
  assert.equal(value.path, expectedPath, name + ': unexpected destination path')
  assert.equal(value.theme, expectedTheme, name + ': unexpected product identity')
}
const expectNoStore = (name, from, href, options = {}) => {
  const h = harness(from, options)
  assert.equal(h.click(href, options), null, name + ': transition must not be stored')
}

expectStore('world-to-intelligence', '/', '/intelligence', '/intelligence', 'intelligence')
expectStore('nested icon click resolves parent anchor', '/', '/intelligence', '/intelligence', 'intelligence', { child: true })
expectStore('trailing slash is normalized', '/', '/intelligence///', '/intelligence', 'intelligence')
expectStore('world-to-play', '/portal', '/games/', '/games', 'play')
expectStore('play-to-intelligence', '/games/', '/lectures', '/lectures', 'intelligence')
expectStore('game launch marks the transition', '/games/', '/games/null-shift-godot/', '/games/null-shift-godot', 'play', { game: true })
assert.equal(harness('/lectures').profile, 'intelligence', 'Lecture library must share OSA product identity')
assert.equal(harness('/games/time').profile, 'play', 'Game routes must share OSGARD PLAY identity')

expectNoStore('same product profile', '/portal', '/development/merakki/en/')
expectNoStore('academy-to-lectures same profile', '/academy', '/lectures')
expectNoStore('same normalized path', '/portal', '/portal/')
expectNoStore('same path with query', '/portal', '/portal?campaign=one')
expectNoStore('external origin', '/', 'https://example.com/intelligence')
expectNoStore('download link', '/', '/intelligence', { download: true })
expectNoStore('new browsing context', '/', '/intelligence', { target: '_blank' })
expectNoStore('external rel token', '/', '/intelligence', { rel: 'external noopener' })
expectNoStore('Ctrl-click', '/', '/intelligence', { event: { ctrlKey: true } })
expectNoStore('Meta-click', '/', '/intelligence', { event: { metaKey: true } })
expectNoStore('Shift-click', '/', '/intelligence', { event: { shiftKey: true } })
expectNoStore('middle click', '/', '/intelligence', { event: { button: 1 } })
expectNoStore('already cancelled event', '/', '/intelligence', { event: { defaultPrevented: true } })
expectNoStore('reduced motion', '/', '/intelligence', { reducedMotion: true })
expectNoStore('motion disabled by preference', '/portal', '/games/', { motionOff: true })
expectNoStore('script protocol', '/', 'javascript:alert(1)')

console.log('OSA_TRANSITION_BEHAVIOR_PASS: product transitions are contextual, accessible and never hijack external, modified, download or same-profile navigation.')
