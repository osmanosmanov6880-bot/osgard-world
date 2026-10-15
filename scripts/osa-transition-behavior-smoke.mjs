import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import vm from 'node:vm'

const source = readFileSync('public/brand/osa-transition.js', 'utf8')
const STORAGE_KEY = 'osgard.osa5.transition.v1'

class FakeElement {
  constructor({ href = '', target = '', download = false, rel = '', anchor = null } = {}) {
    this.href = href
    this.target = target
    this.anchor = anchor
    this.attributes = new Set(download ? ['download'] : [])
    const relations = new Set(rel.split(/\s+/).filter(Boolean))
    this.relList = { contains: value => relations.has(value) }
  }
  closest(selector) {
    if (selector !== 'a[href]') return null
    return this.anchor || (this.href ? this : null)
  }
  hasAttribute(name) { return this.attributes.has(name) }
}

function harness(pathname) {
  const writes = new Map()
  let clickHandler
  const url = new URL(pathname, 'https://osgard.world')
  const document = {
    documentElement: { dataset: {} },
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
    console
  }, { filename: 'osa-transition.js' })

  assert.equal(typeof clickHandler, 'function', 'transition click listener must register')
  return {
    profile: document.documentElement.dataset.osaProfile,
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
        preventDefault() { this.defaultPrevented = true },
        ...options.event
      }
      clickHandler(event)
      const stored = writes.get(STORAGE_KEY)
      return stored ? JSON.parse(stored) : null
    }
  }
}

const expectStore = (name, from, href, expectedTo, options = {}) => {
  const h = harness(from)
  const value = h.click(href, options)
  assert.ok(value, name + ': expected transition intent to be stored')
  assert.equal(value.to, expectedTo, name + ': unexpected destination path')
}
const expectNoStore = (name, from, href, options = {}) => {
  const h = harness(from)
  assert.equal(h.click(href, options), null, name + ': transition must not be stored')
}

expectStore('root-to-portal', '/', '/portal', '/portal')
expectStore('nested icon click resolves parent anchor', '/', '/portal', '/portal', { child: true })
expectStore('trailing slash is normalized', '/', '/portal///', '/portal')
expectStore('immersive time route has its own profile', '/games/', '/games/time', '/games/time')
assert.equal(harness('/games/time').profile, 'immersive', 'specific immersive routes must win over the broad /games/* matcher')
expectStore('ordinary game-to-portal transition', '/games/', '/portal', '/portal')

expectNoStore('same product profile', '/portal', '/development/merakki/en/')
expectNoStore('same normalized path', '/portal', '/portal/')
expectNoStore('same path with query', '/portal', '/portal?campaign=one')
expectNoStore('external origin', '/', 'https://example.com/portal')
expectNoStore('download link', '/', '/portal', { download: true })
expectNoStore('new browsing context', '/', '/portal', { target: '_blank' })
expectNoStore('external rel token', '/', '/portal', { rel: 'external noopener' })
expectNoStore('Ctrl-click', '/', '/portal', { event: { ctrlKey: true } })
expectNoStore('Meta-click', '/', '/portal', { event: { metaKey: true } })
expectNoStore('Shift-click', '/', '/portal', { event: { shiftKey: true } })
expectNoStore('middle click', '/', '/portal', { event: { button: 1 } })
expectNoStore('already cancelled event', '/', '/portal', { event: { defaultPrevented: true } })
expectNoStore('unknown route source', '/not-a-product', '/portal')
expectNoStore('unknown route destination', '/', '/not-a-product')
expectNoStore('script protocol', '/', 'javascript:alert(1)')

console.log('OSA_TRANSITION_BEHAVIOR_PASS: 20 navigation contracts checked; external, modified, download and same-profile links are not hijacked.')
