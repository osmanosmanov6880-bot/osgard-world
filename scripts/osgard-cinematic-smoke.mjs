import assert from 'node:assert/strict'
import { readFileSync, existsSync } from 'node:fs'
import path from 'node:path'
import vm from 'node:vm'
import ts from 'typescript'

// Execute the actual shipped routing/controller modules. The controlled host
// provides time, storage, history and React hook boundaries; it does not copy
// their routing or intro decisions. Layout, painting and native prompts are
// covered separately by the real-browser checks.
const SOURCE_ROOT = path.resolve('src')
const checks = []
const check = async (name, run) => { try { await run(); checks.push(name) } catch (error) { error.message = name + ': ' + error.message; throw error } }

class HostEvent {
  constructor(type, init = {}) { Object.assign(this, { type, cancelable: false, defaultPrevented: false, target: null, currentTarget: null }, init) }
  preventDefault() { if (this.cancelable) this.defaultPrevented = true }
  stopPropagation() {}
  get returnValue() { return !this.defaultPrevented }
  set returnValue(value) { if (value === false) this.preventDefault() }
}
class HostEvents {
  constructor() { this.events = new Map() }
  addEventListener(type, listener, options = {}) {
    const values = this.events.get(type) || []
    if (!values.some(item => item.listener === listener)) values.push({ listener, once: options?.once === true })
    this.events.set(type, values)
  }
  removeEventListener(type, listener) { this.events.set(type, (this.events.get(type) || []).filter(item => item.listener !== listener)) }
  dispatchEvent(event) {
    event.target ||= this; event.currentTarget = this
    for (const item of [...(this.events.get(event.type) || [])]) {
      if (item.once) this.removeEventListener(event.type, item.listener)
      item.listener.call(this, event)
    }
    return !event.defaultPrevented
  }
}

function environment(initial = '/', options = {}) {
  let url = new URL(initial, 'https://osgard.world'), elapsed = 0, timerId = 0
  const timers = new Map(), observers = [], moduleCache = new Map(), nodes = new Map()
  const local = options.local || new Map(), session = options.session || new Map()
  const writes = [], focus = [], scroll = [], loads = [], notices = [], titleWrites = []
  const window = new HostEvents(), document = new HostEvents(), media = new HostEvents()
  const privateSentinel = 'SESSION MUST NOT CHANGE'
  if (!session.has('qa:auth-session')) session.set('qa:auth-session', privateSentinel)
  class Element extends HostEvents {
    constructor(tagName = 'DIV', attributes = {}) {
      super(); this.tagName = tagName.toUpperCase(); this.attributes = new Map(Object.entries(attributes)); this.dataset = {}; this.style = { setProperty(name, value) { this[name] = value }, removeProperty(name) { delete this[name] } }; this.inert = false; this.isConnected = true; this.children = []; this.parentElement = null; this.tabIndex = -1
      const names = new Set(); this.classList = { add: (...values) => values.forEach(value => names.add(value)), remove: (...values) => values.forEach(value => names.delete(value)), contains: value => names.has(value), toggle: (value, force) => { const add = force ?? !names.has(value); if (add) names.add(value); else names.delete(value); return add } }
    }
    get href() { return new URL(this.attributes.get('href') || '', url).href }
    set href(value) { this.attributes.set('href', String(value)) }
    get target() { return this.attributes.get('target') || '' }
    get rel() { return this.attributes.get('rel') || '' }
    set rel(value) { this.attributes.set('rel', String(value)) }
    getAttribute(name) { return this.attributes.get(name) ?? null }
    setAttribute(name, value) { this.attributes.set(name, String(value)) }
    removeAttribute(name) { this.attributes.delete(name) }
    hasAttribute(name) { return this.attributes.has(name) }
    closest(selector) { if (selector === 'a[href]') return this.tagName === 'A' && this.hasAttribute('href') ? this : this.parentElement?.closest(selector) || null; return null }
    contains(target) { return target === this || this.children.some(child => child.contains?.(target)) }
    focus(options) { document.activeElement = this; focus.push({ id: this.id, node: this, options }) }
    scrollIntoView(options) { scroll.push({ id: this.id, options }) }
    querySelector(selector) {
      const attribute = /^(meta|link)\[(name|property|rel)="([^"]+)"\]$/.exec(selector)
      if (attribute) return this.children.find(child => child.tagName === attribute[1].toUpperCase() && child.getAttribute(attribute[2]) === attribute[3]) || null
      if (selector === 'script[data-route-seo]') return this.children.find(child => child.tagName === 'SCRIPT' && child.dataset.routeSeo != null) || null
      return null
    }
    querySelectorAll() { return [] }
    append(...children) { children.forEach(child => { child.parentElement = this }); this.children.push(...children) }
    appendChild(child) { this.append(child); return child }
    remove() { this.isConnected = false }
  }
  function addNode(id, tag = 'DIV') { const element = new Element(tag); element.id = id; nodes.set(id, element); return element }
  const root = addNode('root'), main = addNode('product-main', 'MAIN'), html = new Element('HTML'), body = new Element('BODY'), head = new Element('HEAD')
  html.dataset.motion = options.motionOff ? 'off' : 'on'; html.scrollHeight = 5000
  root.append(main); body.append(root); html.append(head, body)
  const canonical = options.canonical === undefined ? url.origin + url.pathname : options.canonical
  if (canonical) head.append(new Element('LINK', { rel: 'canonical', href: canonical }))
  Object.assign(document, { documentElement: html, body, head, activeElement: main, hidden: false, readyState: 'complete',
    getElementById: id => nodes.get(id) || null,
    querySelector: selector => selector === '#product-main' ? main : selector === '#root' ? root : selector.includes('osgard-cinematic') && hooks?.overlay ? addNode('qa-overlay') : null,
    querySelectorAll: () => [], createElement: tag => new Element(tag), contains: node => node?.isConnected === true,
  })
  let title = options.title || 'OSGARD'
  Object.defineProperty(document, 'title', { get: () => title, set: value => { title = value; titleWrites.push(value) } })
  const location = new Proxy({}, { get: (_, key) => key === 'assign' || key === 'replace' || key === 'reload' ? value => { loads.push({ key, value }) } : url[key], set: (_, key, value) => { loads.push({ key, value }); return true } })
  let historyIndex = 0; const historyEntries = [{ href: url.href, state: { existingApplicationState: 'preserve me' } }]
  const history = { scrollRestoration: 'auto', get state() { return historyEntries[historyIndex].state }, get length() { return historyEntries.length },
    replaceState(state, _title, href) { if (href != null) url = new URL(href, url); historyEntries[historyIndex] = { href: url.href, state } },
    pushState(state, _title, href) { url = new URL(href, url); historyEntries.splice(++historyIndex); historyEntries.push({ href: url.href, state }) },
    go(delta) { const next = historyIndex + delta; if (next < 0 || next >= historyEntries.length) return; historyIndex = next; url = new URL(historyEntries[next].href); window.dispatchEvent(new HostEvent('popstate', { state: history.state })) },
    back() { this.go(-1) }, forward() { this.go(1) },
  }
  const storage = (values, area) => ({
    getItem(key) { if (options.storageDenied) throw Error('Storage unavailable'); return values.get(key) ?? null },
    setItem(key, value) { if (options.storageDenied) throw Error('Storage unavailable'); values.set(key, String(value)); writes.push({ area, key, value: String(value) }) },
    removeItem(key) { if (options.storageDenied) throw Error('Storage unavailable'); values.delete(key); writes.push({ area, key, removed: true }) },
  })
  media.matches = Boolean(options.reduced); media.addListener = listener => media.addEventListener('change', listener); media.removeListener = listener => media.removeEventListener('change', listener)
  const schedule = (callback, delay = 0) => { const id = ++timerId; timers.set(id, { callback, at: elapsed + Math.max(0, delay) }); return id }
  const cancel = id => timers.delete(id)
  Object.assign(window, { document, location, history, innerWidth: options.width || 1440, innerHeight: 900, scrollX: 0, scrollY: 0,
    navigator: { hardwareConcurrency: options.cores ?? 8, deviceMemory: options.memory ?? 8, connection: { saveData: options.saveData ?? false } },
    matchMedia: () => media, setTimeout: schedule, clearTimeout: cancel,
    requestAnimationFrame: callback => schedule(() => callback(elapsed), 16), cancelAnimationFrame: cancel,
    scrollTo(value, y) { this.scrollX = typeof value === 'number' ? value : value.left || 0; this.scrollY = typeof value === 'number' ? y : value.top || 0; scroll.push({ x: this.scrollX, y: this.scrollY }) },
    confirm: message => { notices.push(message); return options.confirm ?? false },
  })
  window.self = window; window.top = options.embedded ? {} : window
  const localStorage = storage(local, 'local'), sessionStorage = storage(session, 'session')
  window.localStorage = localStorage; window.sessionStorage = sessionStorage
  class MutationObserver { constructor(callback) { this.callback = callback; this.active = false; observers.push(this) } observe() { this.active = true } disconnect() { this.active = false } }
  class Image { set src(value) { loads.push({ preload: value }) } }
  class ClockDate extends Date { constructor(...args) { super(...(args.length ? args : [1700000000000 + elapsed])) } static now() { return 1700000000000 + elapsed } }
  const globals = { window, document, location, history, localStorage, sessionStorage, navigator: window.navigator, Event: HostEvent, CustomEvent: HostEvent, Element, HTMLElement: Element, HTMLAnchorElement: Element,
    MutationObserver, Image, URL, URLSearchParams, Date: ClockDate, performance: { now: () => elapsed }, console, queueMicrotask,
    setTimeout: schedule, clearTimeout: cancel, requestAnimationFrame: window.requestAnimationFrame, cancelAnimationFrame: cancel,
    matchMedia: window.matchMedia, getComputedStyle: element => element.style,
  }
  let hooks
  const jsx = (type, props, key) => ({ type, props: props || {}, key })
  const Fragment = Symbol('Fragment'), Suspense = Symbol('Suspense')
  const react = { Fragment, Suspense, createElement: (type, props, ...children) => jsx(type, { ...props, ...(children.length ? { children: children.length === 1 ? children[0] : children } : {}) }),
    lazy: loader => ({ loader, status: 'new' }),
    createContext: initial => ({ current: initial, Provider: Symbol('ContextProvider') }),
    useContext: context => context.current,
    useState: initial => hooks.state(initial), useRef: initial => hooks.ref(initial),
    useEffect: (effect, deps) => hooks.effect(effect, deps), useLayoutEffect: (effect, deps) => hooks.effect(effect, deps),
    useMemo: (compute, deps) => hooks.memo(compute, deps), useCallback: (callback, deps) => hooks.memo(() => callback, deps),
    useSyncExternalStore: (subscribe, getSnapshot) => { const [, force] = hooks.state(0); hooks.effect(() => subscribe(() => force(value => value + 1)), [subscribe]); return getSnapshot() },
    startTransition: callback => callback(),
    Component: class { constructor(props) { this.props = props; this.state = {} } setState(value) { this.state = { ...this.state, ...value } } },
  }
  function load(name) {
    if (name === 'react') return { __esModule: true, default: react, ...react }
    if (name === 'react/jsx-runtime') return { jsx, jsxs: jsx, Fragment }
    if (name.endsWith('.css')) return {}
    const filename = path.resolve(SOURCE_ROOT, name.startsWith('./') ? name.slice(2) : name)
    const resolved = existsSync(filename) ? filename : ['.ts', '.tsx'].map(suffix => filename + suffix).find(existsSync)
    if (!resolved || !resolved.startsWith(SOURCE_ROOT + path.sep)) throw Error('Unexpected controller dependency: ' + name)
    if (resolved.endsWith('/OsgardCinematic.tsx')) { if (options.visualFailure) throw Error('Simulated optional visual chunk failure'); return { __esModule: true, default: 'CINEMATIC_VISUAL' } }
    if (moduleCache.has(resolved)) return moduleCache.get(resolved).exports
    const module = { exports: {} }; moduleCache.set(resolved, module)
    // Replace only the platform's import boundary, so its Promise can be slow
    // or unavailable. Every eligibility, state, timer and cleanup decision
    // remains the actual provider code, with no source-text substitution.
    const visualImportBoundary = context => root => {
      const visit = node => ts.isCallExpression(node) && node.expression.kind === ts.SyntaxKind.ImportKeyword && ts.isStringLiteral(node.arguments[0]) && node.arguments[0].text === './OsgardCinematic'
        ? ts.factory.createCallExpression(ts.factory.createIdentifier('__hostImport'), undefined, node.arguments)
        : ts.visitEachChild(node, visit, context)
      return ts.visitNode(root, visit)
    }
    const compiled = ts.transpileModule(readFileSync(resolved, 'utf8'), { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX, esModuleInterop: true }, transformers: { before: [visualImportBoundary] } }).outputText
    const importVisual = name => {
      assert.equal(name, './OsgardCinematic'); loads.push({ visualImport: true })
      return new Promise((resolve, reject) => {
        if (options.visualNeverResolves) return
        const finish = () => { try { resolve(load(name)) } catch (error) { reject(error) } }
        if (options.visualDelay) schedule(finish, options.visualDelay)
        else finish()
      })
    }
    vm.runInNewContext(compiled, { ...globals, module, exports: module.exports, require: load, __hostImport: importVisual }, { filename: resolved })
    return module.exports
  }
  function mountProvider() {
    assert.equal(hooks, undefined, 'mount a fresh provider in each controlled document')
    const Provider = load('OsgardTransitionProvider.tsx').default
    let cursor = 0, dirty = true, effects = [], cells = [], tree
    const same = (left, right) => left && right && left.length === right.length && left.every((value, index) => Object.is(value, right[index]))
    hooks = {
      overlay: null,
      state(initial) { const index = cursor++; if (!(index in cells)) cells[index] = { value: typeof initial === 'function' ? initial() : initial }; const cell = cells[index]; return [cell.value, value => { const next = typeof value === 'function' ? value(cell.value) : value; if (!Object.is(next, cell.value)) { cell.value = next; dirty = true } }] },
      ref(initial) { const index = cursor++; if (!(index in cells)) cells[index] = { ref: { current: initial } }; return cells[index].ref },
      memo(compute, deps) { const index = cursor++; const old = cells[index]; if (!old || !same(old.deps, deps)) cells[index] = { value: compute(), deps }; return cells[index].value },
      effect(effect, deps) { const index = cursor++; const old = cells[index]; if (!old || !same(old.deps, deps)) { cells[index] = { ...old, deps, effect }; effects.push(index) } },
      flush() {
        for (let round = 0; (dirty || effects.length) && round < 40; round++) {
          if (dirty) { dirty = false; cursor = 0; tree = Provider({ children: jsx('ROUTE_CONTENT', {}) }); this.overlay = null; inspect(tree) }
          const pending = effects; effects = []
          for (const index of pending) { const cell = cells[index]; cell.cleanup?.(); cell.cleanup = cell.effect() }
        }
        assert.equal(dirty, false, 'controller did not settle')
      },
      strictEffects() { for (const cell of cells) if (cell.effect) cell.cleanup?.(); for (const cell of cells) if (cell.effect) cell.cleanup = cell.effect(); this.flush() },
      unmount() { for (const cell of cells) if (cell.cleanup) cell.cleanup(); this.overlay = null },
      get tree() { return tree },
    }
    function inspect(node) {
      if (!node || typeof node !== 'object') return
      if (Array.isArray(node)) { node.forEach(inspect); return }
      if (node.props?.ref && typeof node.props.ref === 'object' && !node.props.ref.current) node.props.ref.current = new Element(typeof node.type === 'string' ? node.type : 'DIV')
      if (node.type?.loader) {
        hooks.overlay = node.props
        if (node.type.status === 'new') { node.type.status = 'pending'; Promise.resolve(node.type.loader()).then(() => { node.type.status = 'ready'; dirty = true }, () => { node.type.status = 'failed' }) }
      }
      if (node.type === 'CINEMATIC_VISUAL') hooks.overlay = node.props
      inspect(node.props?.children)
    }
    hooks.flush(); return hooks
  }
  async function settle() { for (let round = 0; round < 8; round++) { await Promise.resolve(); hooks?.flush() } }
  function mountSeo({ failImport = false } = {}) {
    const source = ts.createSourceFile('main.tsx', readFileSync(path.join(SOURCE_ROOT, 'main.tsx'), 'utf8'), ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX)
    const declaration = source.statements.find(node => ts.isFunctionDeclaration(node) && node.name?.text === 'Seo')
    assert.ok(declaration, 'the real Seo function must exist in main.tsx')
    const compiled = ts.transpileModule('import React from "react";\nexport ' + declaration.getText(source), { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX, esModuleInterop: true } }).outputText
    const module = { exports: {} }, effects = [], imports = []
    let cleanup
    const require = name => {
      if (name === 'react') return { __esModule: true, default: { useEffect: effect => effects.push(effect) } }
      if (name === './routeSeo') { imports.push(name); if (failImport) throw Error('Optional SEO chunk failure'); return load('routeSeo.ts') }
      throw Error('Unexpected Seo dependency: ' + name)
    }
    vm.runInNewContext(compiled, { ...globals, module, exports: module.exports, require }, { filename: 'actual-main-Seo.tsx' })
    return { imports, render(route) { cleanup?.(); const result = module.exports.Seo({ path: route }); cleanup = effects.shift()?.(); assert.equal(effects.length, 0); return result }, unmount() { cleanup?.() } }
  }
  return { load, window, document, history, location, local, session, writes, focus, scroll, loads, notices, titleWrites, timers, media, mountProvider, mountSeo, addNode,
    get now() { return elapsed }, get hooks() { return hooks }, get historyIndex() { return historyIndex },
    async settle() { await settle() },
    async advance(ms) {
      const until = elapsed + ms
      for (let count = 0; count < 2000; count++) {
        const next = [...timers].filter(([, value]) => value.at <= until).sort((a, b) => a[1].at - b[1].at)[0]
        if (!next) break
        timers.delete(next[0]); elapsed = next[1].at; next[1].callback(); await settle()
        assert.ok(count < 1999, 'unbounded controller timers')
      }
      elapsed = until; await settle()
    },
    click(href, options = {}) { const anchor = new Element('A', { href, ...options.attributes }); const event = new HostEvent('click', { cancelable: true, button: 0, target: anchor, ...options.event }); document.dispatchEvent(event); return event },
    emit(type, detail) { const event = new HostEvent(type, { detail }); window.dispatchEvent(event); return event },
    key(key, shiftKey = false) { const event = new HostEvent('keydown', { key, shiftKey, cancelable: true, target: document.activeElement }); window.dispatchEvent(event); document.dispatchEvent(event); return event },
    mutate() { for (const observer of observers) if (observer.active) observer.callback([]) },
    assertNoReload() { assert.equal(loads.filter(value => !value.visualImport && !value.preload).length, 0, 'SPA navigation must not assign/reload location') },
    assertAuthUntouched() { assert.equal(session.get('qa:auth-session'), privateSentinel); assert.ok(writes.every(value => /^(osgard:|qa:)/.test(value.key)), 'unexpected storage mutation') },
  }
}

const findNode = (tree, predicate) => {
  if (!tree || typeof tree !== 'object') return null
  if (Array.isArray(tree)) return tree.map(node => findNode(node, predicate)).find(Boolean) || null
  if (predicate(tree)) return tree
  return findNode(tree.props?.children, predicate)
}
const contentNode = tree => findNode(tree, node => 'data-osgard-content' in (node.props || {}))
const introKey = 'osgard:intro:v1'
const repeat = () => new Map([[introKey, 'seen']])
// useSyncExternalStore reads a snapshot during render before its subscription effect.
const watch = (navigation, listener) => { navigation.getBrowserSnapshot(); return navigation.subscribeBrowserNavigation(listener) }

await check('route eligibility includes real public/private React pages while preserving standalone and API boundaries', () => {
  const host = environment(), routing = host.load('osgardRouting.ts')
  for (const page of ['/', '/play/', '/development', '/intelligence', '/play/world/vector-zero', '/lectures/signal-and-noise', '/account/', '/workspace', '/workspace/overview', '/teams', '/deliveries', '/purchases', '/data', '/learning/campus', '/learning/organizer', '/learning/enrollment']) assert.equal(routing.isReactRoute(page), true, page)
  for (const page of ['/games/time', '/games/vector-zero/', '/games/time-empire/', '/games/null-shift-godot/', '/games/remix/player/', '/api/auth', '/api/auth/login', '/auth/callback']) assert.equal(routing.isReactRoute(page), false, page)
  for (const page of ['/account/', '/workspace', '/workspace/overview', '/teams', '/deliveries', '/purchases', '/data', '/learning/campus', '/learning/organizer', '/learning/enrollment']) assert.equal(routing.majorSectionForPath(page), 'account', page)
  for (const [page, section] of [['/', 'world'], ['/development', 'development'], ['/intelligence', 'intelligence'], ['/learning', 'intelligence'], ['/play', 'play']]) assert.equal(routing.majorSectionForPath(page), section)
  assert.equal(routing.INTRO_STORAGE_KEY, introKey)
})

await check('first visit renders its real route immediately, completes at 3.6 seconds and releases focus/inert state', async () => {
  const host = environment('/'), controller = host.mountProvider(); await host.settle()
  assert.equal(controller.overlay?.kind, 'intro')
  assert.equal(contentNode(controller.tree).props.children.type, 'ROUTE_CONTENT')
  assert.equal(contentNode(controller.tree).props.inert, true)
  assert.equal(host.local.get(introKey), 'seen')
  assert.equal(host.loads.filter(item => item.visualImport).length, 1)
  await host.advance(3599); assert.equal(controller.overlay?.kind, 'intro')
  await host.advance(1); assert.equal(controller.overlay, null)
  assert.equal(contentNode(controller.tree).props.inert, undefined)
  assert.equal(host.document.documentElement.dataset.osgardCinematic, undefined)
  assert.equal(host.document.activeElement.id, 'product-main')
  await host.advance(1000); assert.equal(host.timers.size, 0)
  host.assertNoReload(); host.assertAuthUntouched()
})

await check('repeat document skips intro and does not request optional visual or emblem', async () => {
  const host = environment('/play', { local: repeat() }), controller = host.mountProvider(); await host.settle()
  assert.equal(controller.overlay, null)
  assert.equal(contentNode(controller.tree).props.inert, undefined)
  assert.equal(host.loads.length, 0)
  assert.equal(host.timers.size, 0)
})

await check('a cold visual import preserves the full 3.6 second intro and 900 ms section animation after mounting', async () => {
  for (const [kind, duration] of [['intro', 3600], ['play', 900]]) {
    const delay = kind === 'intro' ? 500 : 200
    const host = environment('/', { visualDelay: delay, ...(kind === 'play' ? { local: repeat() } : {}) }), nav = host.load('browserNavigation.ts')
    const stop = watch(nav, () => {}), controller = host.mountProvider()
    if (kind === 'play') { host.click('/play'); await host.settle() }
    assert.ok(findNode(controller.tree, node => 'data-osgard-pending' in (node.props || {})))
    assert.equal(contentNode(controller.tree).props.children.type, 'ROUTE_CONTENT')
    await host.advance(delay - 1); assert.equal(controller.overlay, null)
    await host.advance(1); assert.equal(controller.overlay?.kind, kind)
    await host.advance(duration - 1); assert.equal(controller.overlay?.kind, kind)
    await host.advance(1); assert.equal(controller.overlay, null)
    assert.equal(contentNode(controller.tree).props.inert, undefined)
    stop()
  }
})

await check('unresolved imports release the page at intro 800 ms / short 300 ms watchdogs', async () => {
  for (const [kind, deadline] of [['intro', 800], ['play', 300]]) {
    const host = environment('/', { visualNeverResolves: true, ...(kind === 'play' ? { local: repeat() } : {}) }), nav = host.load('browserNavigation.ts')
    const stop = watch(nav, () => {}), controller = host.mountProvider(); await host.settle()
    if (kind === 'play') { host.click('/play'); await host.settle() }
    assert.equal(contentNode(controller.tree).props.inert, true)
    assert.ok(findNode(controller.tree, node => 'data-osgard-pending' in (node.props || {})))
    await host.advance(deadline - 1); assert.equal(contentNode(controller.tree).props.inert, true)
    await host.advance(1); assert.equal(contentNode(controller.tree).props.inert, undefined)
    assert.equal(findNode(controller.tree, node => 'data-osgard-pending' in (node.props || {})), null)
    assert.equal(host.document.activeElement.id, 'product-main')
    assert.equal(host.key('Escape').defaultPrevented, false)
    await host.advance(5000); assert.equal(host.timers.size, 0)
    stop()
  }
})

await check('pending-import Skip and Escape work immediately and late import resolution cannot reopen the intro', async () => {
  for (const action of ['skip', 'escape']) {
    const host = environment('/play', { visualDelay: 500 }), controller = host.mountProvider(); await host.settle()
    if (action === 'escape') assert.equal(host.key('Escape').defaultPrevented, true)
    else findNode(controller.tree, node => node.type === 'button' && node.props.onClick).props.onClick()
    await host.advance(0); assert.equal(contentNode(controller.tree).props.inert, undefined)
    await host.advance(1000); assert.equal(controller.overlay, null)
    assert.equal(findNode(controller.tree, node => 'data-osgard-pending' in (node.props || {})), null)
  }
})

await check('direct Play and mobile deep links retain destination, query and fragment during the first intro', async () => {
  for (const destination of ['/play', '/play/world/vector-zero?from=home#controls']) {
    const host = environment(destination, { width: 390 }), nav = host.load('browserNavigation.ts')
    const stop = watch(nav, () => {}), controller = host.mountProvider(); await host.settle()
    assert.equal(controller.overlay?.kind, 'intro')
    assert.equal(nav.getBrowserSnapshot().href, destination)
    controller.overlay.onSkip(); await host.advance(0)
    assert.equal(nav.getBrowserSnapshot().href, destination)
    assert.equal(host.history.length, 1)
    host.assertNoReload(); stop()
  }
})

await check('major-section clicks publish the route without reload and use finite 900 ms transitions', async () => {
  const host = environment('/', { local: repeat() }), nav = host.load('browserNavigation.ts')
  const notifications = []; const stop = watch(nav, () => notifications.push(nav.getBrowserSnapshot()))
  const controller = host.mountProvider(); await host.settle()
  let revision = 0
  for (const [destination, kind] of [['/intelligence?from=nav#method', 'transition'], ['/play', 'play'], ['/development', 'transition']]) {
    assert.equal(host.click(destination).defaultPrevented, true)
    assert.equal(nav.getBrowserSnapshot().href, destination, 'URL must update before waiting for the visual')
    assert.equal(nav.getBrowserSnapshot().revision, ++revision)
    await host.settle(); assert.equal(controller.overlay?.kind, kind)
    await host.advance(899); assert.equal(controller.overlay?.kind, kind)
    await host.advance(1); assert.equal(controller.overlay, null)
  }
  assert.equal(notifications.length, 3)
  assert.equal(host.history.state.existingApplicationState, 'preserve me')
  host.assertNoReload(); host.assertAuthUntouched(); stop()
})

await check('filter replaceState and same-page anchors preserve route revision and avoid cinematic transitions', async () => {
  const host = environment('/play', { local: repeat() }), nav = host.load('browserNavigation.ts')
  const stop = watch(nav, () => {}), controller = host.mountProvider(); await host.settle()
  const revision = nav.getBrowserSnapshot().revision
  nav.replaceBrowserUrl('/play?genre=arcade&available=now#catalog'); await host.settle()
  assert.equal(nav.getBrowserSnapshot().href, '/play?genre=arcade&available=now#catalog')
  assert.equal(nav.getBrowserSnapshot().revision, revision)
  assert.equal(controller.overlay, null)
  assert.equal(host.click('#experience').defaultPrevented, false)
  assert.equal(host.history.length, 1)
  stop()
})

await check('an alias replaced by a child mount effect is current when the root subscribes', () => {
  const host = environment('/games'), nav = host.load('browserNavigation.ts')
  assert.equal(nav.getBrowserSnapshot().href, '/games')
  nav.replaceBrowserUrl('/play')
  const stop = nav.subscribeBrowserNavigation(() => {})
  assert.equal(nav.getBrowserSnapshot().href, '/play')
  assert.equal(nav.getBrowserSnapshot().revision, 0)
  stop()
})

await check('short page reveal begins at 550 ms and is not restarted when the overlay finishes at 900 ms', async () => {
  const host = environment('/', { local: repeat() }), nav = host.load('browserNavigation.ts'), stop = watch(nav, () => {})
  const controller = host.mountProvider(); await host.settle(); host.click('/play'); await host.settle()
  await host.advance(549); assert.equal(host.document.documentElement.dataset.osgardReveal, undefined)
  await host.advance(1); assert.equal(host.document.documentElement.dataset.osgardReveal, 'true')
  await host.advance(350); assert.equal(controller.overlay, null); assert.equal(host.document.documentElement.dataset.osgardReveal, 'true')
  await host.advance(549); assert.equal(host.document.documentElement.dataset.osgardReveal, 'true')
  await host.advance(1); assert.equal(host.document.documentElement.dataset.osgardReveal, undefined)
  for (const action of ['skip', 'off']) {
    host.click(action === 'skip' ? '/intelligence' : '/play'); await host.settle(); await host.advance(550)
    assert.equal(host.document.documentElement.dataset.osgardReveal, 'true')
    if (action === 'skip') controller.overlay.onSkip()
    else { host.document.documentElement.dataset.motion = 'off'; host.emit('osgard:motionchange') }
    await host.advance(0); assert.equal(host.document.documentElement.dataset.osgardReveal, undefined)
  }
  stop()
})

await check('modified links, downloads, new tabs, external links and static games keep native navigation', () => {
  const host = environment('/play'), nav = host.load('browserNavigation.ts'), stop = watch(nav, () => {})
  const cases = [
    ['/intelligence', { event: { ctrlKey: true } }], ['/intelligence', { event: { metaKey: true } }],
    ['/intelligence', { event: { shiftKey: true } }], ['/intelligence', { event: { altKey: true } }],
    ['/intelligence', { event: { button: 1 } }], ['/intelligence', { attributes: { target: '_blank' } }],
    ['/intelligence', { attributes: { download: '' } }], ['/intelligence', { attributes: { rel: 'external' } }],
    ['/intelligence', { attributes: { 'data-native-navigation': '' } }], ['https://example.com/', {}],
    ['mailto:team@example.com', {}], ['/api/auth/login', {}], ['/auth/callback', {}], ['/games/time', {}],
    ['/games/vector-zero/', {}], ['/games/null-shift-godot/', {}], ['/games/remix/player/', {}],
  ]
  for (const [href, options] of cases) assert.equal(host.click(href, options).defaultPrevented, false, href + ' ' + JSON.stringify(options))
  assert.equal(nav.getBrowserSnapshot().href, '/play'); assert.equal(host.history.length, 1)
  host.assertNoReload(); stop()
})

for (const [label, options] of [
  ['reduced motion', { reduced: true }], ['Save-Data', { saveData: true }],
  ['manual motion off', { motionOff: true }], ['embedded game frame', { embedded: true }],
]) await check(label + ' renders immediately without intro imports or keyboard capture', async () => {
  const host = environment('/play', options), controller = host.mountProvider(); await host.settle()
  assert.equal(controller.overlay, null); assert.equal(host.loads.length, 0)
  assert.equal(contentNode(controller.tree).props.inert, undefined)
  assert.equal(host.key('Escape').defaultPrevented, false)
  host.assertAuthUntouched()
})

for (const [label, options] of [['two CPU cores', { cores: 2 }], ['2 GB memory', { memory: 2 }]]) {
  await check(label + ' receives the lightweight intro and lightweight section transitions', async () => {
    const host = environment('/play', options), nav = host.load('browserNavigation.ts'), stop = watch(nav, () => {})
    const controller = host.mountProvider(); await host.settle()
    assert.equal(host.load('osgardRouting.ts').isLowPowerDevice(), true)
    assert.equal(controller.overlay?.kind, 'intro'); assert.equal(controller.overlay.lowPower, true)
    await host.advance(3600); assert.equal(controller.overlay, null)
    host.click('/intelligence'); await host.settle()
    assert.equal(controller.overlay?.kind, 'transition'); assert.equal(controller.overlay.lowPower, true)
    await host.advance(900); assert.equal(controller.overlay, null)
    stop()
  })
}

await check('changing reduced-motion or manual motion during intro releases the page immediately', async () => {
  for (const mode of ['media', 'manual']) {
    const host = environment('/'), controller = host.mountProvider(); await host.settle()
    assert.equal(controller.overlay?.kind, 'intro')
    if (mode === 'media') { host.media.matches = true; host.media.dispatchEvent(new HostEvent('change')) }
    else { host.document.documentElement.dataset.motion = 'off'; host.emit('osgard:motionchange') }
    await host.advance(0)
    assert.equal(controller.overlay, null); assert.equal(contentNode(controller.tree).props.inert, undefined)
    assert.equal(host.document.documentElement.dataset.osgardReveal, undefined)
    assert.equal(host.key('Escape').defaultPrevented, false)
  }
})

await check('Skip and Escape end the intro, return focus and stop intercepting later game keys', async () => {
  for (const action of ['skip', 'escape']) {
    const host = environment('/play'), controller = host.mountProvider(); await host.settle()
    if (action === 'skip') controller.overlay.onSkip()
    else assert.equal(host.key('Escape').defaultPrevented, true)
    await host.advance(0)
    assert.equal(controller.overlay, null)
    assert.equal(host.document.activeElement.id, 'product-main')
    assert.equal(host.key('Escape').defaultPrevented, false)
    await host.advance(5000); assert.equal(controller.overlay, null); assert.equal(host.timers.size, 0)
  }
})

await check('manual replay restores its trigger and stale session callbacks cannot finish a newer transition', async () => {
  const host = environment('/', { local: repeat() }), nav = host.load('browserNavigation.ts'), stop = watch(nav, () => {})
  const controller = host.mountProvider(); await host.settle()
  const trigger = host.addNode('replay-intro', 'BUTTON'); trigger.focus()
  host.emit('osgard:replay-intro'); await host.settle()
  assert.equal(controller.overlay?.kind, 'intro'); controller.overlay.onSkip(); await host.advance(0)
  assert.equal(host.document.activeElement, trigger)
  host.click('/intelligence'); await host.settle(); const oldComplete = controller.overlay.onComplete
  host.click('/play'); await host.settle(); assert.equal(controller.overlay?.kind, 'play')
  oldComplete(); await host.settle(); assert.equal(controller.overlay?.kind, 'play')
  await host.advance(900); assert.equal(controller.overlay, null)
  stop()
})

await check('storage denial and React Strict Mode effect replay still leave a bounded usable page', async () => {
  const host = environment('/play', { storageDenied: true }), controller = host.mountProvider(); await host.settle()
  controller.strictEffects(); await host.settle()
  assert.equal(controller.overlay?.kind, 'intro')
  await host.advance(3600); assert.equal(controller.overlay, null)
  assert.equal(contentNode(controller.tree).props.inert, undefined)
  await host.advance(1000); assert.equal(host.timers.size, 0)
})

await check('optional visual import failure cannot leave the application inert or block its route', async () => {
  const host = environment('/play', { visualFailure: true }), controller = host.mountProvider(); await host.settle(); await host.advance(0)
  assert.equal(controller.overlay, null)
  assert.equal(contentNode(controller.tree).props.inert, undefined)
  assert.equal(host.location.pathname, '/play')
  assert.equal(host.document.documentElement.dataset.osgardCinematic, undefined)
})

await check('first account/private entry receives intro without changing its deep URL, auth storage or underlying route', async () => {
  const project = 'a'.repeat(32)
  for (const destination of ['/account', '/workspace', '/workspace/overview', '/teams', '/deliveries', '/purchases', '/data', '/learning/campus', '/learning/organizer', '/learning/enrollment', '/account?tab=history#security', '/workspace?project=' + project + '&tab=history#project', '/workspace?returnTo=%2Faccount']) {
    const host = environment(destination, { width: 390 }), nav = host.load('browserNavigation.ts')
    const controller = host.mountProvider(); await host.settle()
    assert.equal(controller.overlay?.kind, 'intro', destination)
    assert.equal(contentNode(controller.tree).props.children.type, 'ROUTE_CONTENT')
    assert.equal(nav.browserLocationKey(), destination)
    await host.advance(3600)
    assert.equal(controller.overlay, null, destination)
    assert.equal(nav.browserLocationKey(), destination)
    assert.equal(contentNode(controller.tree).props.inert, undefined)
    assert.equal(host.document.activeElement.id, 'product-main')
    host.assertAuthUntouched(); host.assertNoReload()
    controller.unmount()
  }
})

await check('clean public/account navigation stays SPA with 900 ms cross-section transitions and no intra-account animation', async () => {
  const host = environment('/play', { local: repeat() }), nav = host.load('browserNavigation.ts'), stop = watch(nav, () => {})
  const controller = host.mountProvider(); await host.settle()
  assert.equal(controller.overlay, null)
  for (const [destination, kind] of [['/account?tab=history#security', 'transition'], ['/workspace?tab=history', null], ['/workspace/overview', null], ['/learning/enrollment', null], ['/intelligence', 'transition'], ['/teams', 'transition'], ['/play#catalog', 'play']]) {
    const previousRevision = nav.getBrowserSnapshot().revision
    assert.equal(host.click(destination).defaultPrevented, true, destination)
    assert.equal(nav.getBrowserSnapshot().href, destination, 'real route publishes immediately')
    assert.equal(nav.getBrowserSnapshot().revision, previousRevision + 1)
    await host.settle()
    assert.equal(controller.overlay?.kind ?? null, kind, destination)
    assert.equal(contentNode(controller.tree).props.children.type, 'ROUTE_CONTENT')
    if (kind) {
      await host.advance(899); assert.equal(controller.overlay?.kind, kind)
      await host.advance(1); assert.equal(controller.overlay, null)
    }
    assert.equal(contentNode(controller.tree).props.inert, undefined)
  }
  host.assertAuthUntouched(); host.assertNoReload(); stop()
})

await check('actual core login/return helpers retain native auth entry and exit without a router substitute', async () => {
  const project = 'a'.repeat(32)
  for (const target of ['/account', '/workspace?project=' + project + '&tab=history', '/deliveries?delivery=' + project]) {
    const host = environment('/account', { local: repeat() }), nav = host.load('browserNavigation.ts')
    const access = host.load('accountAccess.ts'), login = access.coreLoginLink(target)
    const stop = watch(nav, () => {}), controller = host.mountProvider(); await host.settle()
    const url = new URL(login, host.location.origin)
    assert.equal(url.pathname, '/workspace')
    assert.equal(access.coreAuthReturn(url.pathname, url.search), target)
    assert.equal(host.click(login).defaultPrevented, false, 'actual login link remains a native navigation')
    assert.equal(nav.getBrowserSnapshot().href, '/account'); assert.equal(host.history.length, 1)
    assert.equal(controller.overlay, null)
    host.assertAuthUntouched(); stop()
    for (const entry of [login, login.replace('/workspace?', '/workspace/?')]) {
      const authHost = environment(entry, { local: repeat() }), authNav = authHost.load('browserNavigation.ts')
      const stopAuth = watch(authNav, () => {}), authController = authHost.mountProvider(); await authHost.settle()
      assert.equal(authHost.click(target).defaultPrevented, false, 'leaving the auth entry keeps native lifecycle')
      assert.equal(authNav.navigateBrowserUrl('/play'), false)
      assert.equal(authNav.getBrowserSnapshot().href, entry)
      assert.equal(authController.overlay, null)
      authHost.assertAuthUntouched(); stopAuth()
    }
  }
  const access = environment().load('accountAccess.ts')
  for (const requested of ['https://example.com/account', '//example.com/account', '/api/auth', '/account#security']) {
    assert.equal(access.coreAuthReturn('/workspace', '?returnTo=' + encodeURIComponent(requested)), '/workspace')
  }
})

await check('existing standalone game runtimes and embedded account pages bypass the React intro and navigation', async () => {
  for (const [destination, options] of [['/games/time', {}], ['/games/vector-zero/', {}], ['/games/null-shift-godot/', {}], ['/games/remix/player/', {}], ['/account', { embedded: true }]]) {
    const host = environment(destination, options), nav = host.load('browserNavigation.ts'), controller = host.mountProvider(); await host.settle()
    assert.equal(controller.overlay, null, destination); assert.equal(host.loads.length, 0, destination)
    assert.equal(nav.navigateBrowserUrl('/play'), false)
    host.assertAuthUntouched(); host.assertNoReload()
  }
})

await check('existing cancelable beforeunload guard leaves dirty-form links native without a synthetic confirmation dialog', () => {
  for (const [origin, destination] of [['/', '/play'], ['/play', '/account'], ['/account', '/workspace'], ['/workspace', '/play'], ['/learning/enrollment', '/account']]) {
    const host = environment(origin), nav = host.load('browserNavigation.ts'), stop = watch(nav, () => {})
    const dirty = event => { event.preventDefault(); event.returnValue = '' }
    host.window.addEventListener('beforeunload', dirty)
    assert.equal(host.click(destination).defaultPrevented, false)
    assert.equal(nav.getBrowserSnapshot().href, origin); assert.equal(host.history.length, 1)
    assert.equal(host.notices.length, 0, 'the actual native navigation owns its browser prompt')
    host.window.removeEventListener('beforeunload', dirty)
    assert.equal(host.click(destination).defaultPrevented, true)
    host.assertAuthUntouched(); stop()
  }
})

await check('back/forward preserves route history and cancelling dirty-pop restores the original entry', () => {
  for (const [origin, middle, destination] of [['/', '/intelligence', '/play?genre=arcade#catalog'], ['/play', '/account', '/workspace?tab=history#project'], ['/account', '/play', '/deliveries']]) {
    const options = { confirm: false }, host = environment(origin, options), nav = host.load('browserNavigation.ts'), stop = watch(nav, () => {})
    assert.equal(nav.navigateBrowserUrl(middle), true); assert.equal(nav.navigateBrowserUrl(destination), true)
    const before = nav.getBrowserSnapshot(), index = host.historyIndex
    const dirty = event => event.preventDefault(); host.window.addEventListener('beforeunload', dirty)
    host.history.back()
    assert.equal(nav.browserLocationKey(), destination); assert.equal(host.historyIndex, index)
    assert.equal(nav.getBrowserSnapshot(), before)
    assert.equal(host.notices.length, 1)
    options.confirm = true; host.history.back()
    assert.equal(nav.getBrowserSnapshot().href, middle); assert.equal(nav.getBrowserSnapshot().action, 'pop')
    host.window.removeEventListener('beforeunload', dirty); host.history.forward()
    assert.equal(nav.getBrowserSnapshot().href, destination)
    host.assertAuthUntouched(); host.assertNoReload(); stop()
  }
})

await check('deep-link scroll waits for a lazy destination target and cancels when the user takes control', async () => {
  const host = environment('/intelligence'), nav = host.load('browserNavigation.ts'), stop = watch(nav, () => {})
  nav.navigateBrowserUrl('/play#catalog'); nav.completeBrowserNavigation(nav.getBrowserSnapshot().revision)
  assert.equal(host.scroll.some(value => value.id === 'catalog'), false)
  host.addNode('catalog'); host.mutate()
  assert.equal(host.scroll.filter(value => value.id === 'catalog').length, 1)
  nav.navigateBrowserUrl('/intelligence#late-target'); nav.completeBrowserNavigation(nav.getBrowserSnapshot().revision)
  host.emit('wheel'); host.addNode('late-target'); host.mutate()
  assert.equal(host.scroll.some(value => value.id === 'late-target'), false)
  await host.advance(5000); stop()
})

await check('unmount cleans controller timers/listeners and React template has no competing legacy transition script', async () => {
  const host = environment('/'), controller = host.mountProvider(); await host.settle()
  controller.unmount()
  assert.equal(host.timers.size, 0)
  assert.equal(host.document.documentElement.dataset.osgardCinematic, undefined)
  assert.equal(host.key('Escape').defaultPrevented, false)
  const template = readFileSync('index.html', 'utf8')
  assert.doesNotMatch(template, /<script[^>]+src=["']\/brand\/osa-transition\.js["']/)
  assert.ok(existsSync('public/brand/osa-transition.js'), 'standalone games retain their existing transition implementation')
})

await check('prerendered canonical metadata avoids any initial SEO module request, including PLAY aliases', async () => {
  for (const destination of ['/', '/play', '/intelligence', '/games', '/entertainment']) {
    const canonical = 'https://osgard.world' + (['/games', '/entertainment'].includes(destination) ? '/play' : destination)
    const host = environment(destination, { canonical, title: 'Verified prerendered title' }), seo = host.mountSeo()
    assert.equal(seo.render(destination), null)
    await host.settle()
    assert.equal(seo.imports.length, 0, destination)
    assert.equal(host.document.title, 'Verified prerendered title')
    assert.equal(host.titleWrites.length, 0)
  }
})

await check('SPA destination requests real metadata only when needed and updates title/canonical/robots/Open Graph', async () => {
  const host = environment('/'), seo = host.mountSeo()
  assert.equal(seo.render('/play'), null, 'the route is never suspended by the metadata request')
  assert.equal(host.document.title, 'OSGARD', 'metadata is asynchronous')
  await host.settle()
  assert.equal(seo.imports.length, 1)
  assert.match(host.document.title, /OSGARD PLAY/)
  assert.equal(host.document.head.querySelector('link[rel="canonical"]').href, 'https://osgard.world/play')
  assert.equal(host.document.head.querySelector('meta[name="robots"]').getAttribute('content'), 'index,follow')
  assert.equal(host.document.head.querySelector('meta[property="og:image"]').getAttribute('content'), 'https://osgard.world/brand/preview-play.png')
  const jsonLd = JSON.parse(host.document.head.querySelector('script[data-route-seo]').textContent)
  assert.equal(jsonLd['@type'], 'WebPage'); assert.equal(jsonLd.url, 'https://osgard.world/play')
  seo.render('/workspace'); await host.settle()
  assert.equal(host.document.head.querySelector('meta[name="robots"]').getAttribute('content'), 'noindex,follow')
  assert.equal(host.document.head.querySelector('link[rel="canonical"]').href, 'https://osgard.world/workspace')
  host.assertAuthUntouched()
})

await check('stale metadata import completion cannot overwrite the newer SPA destination', async () => {
  const host = environment('/'), seo = host.mountSeo()
  seo.render('/play'); seo.render('/intelligence'); await host.settle()
  assert.match(host.document.title, /^OSA Intelligence/)
  assert.ok(host.titleWrites.every(title => !title.includes('OSGARD PLAY')), 'cancelled metadata effect must never write its older title')
  assert.equal(host.document.head.querySelector('link[rel="canonical"]').href, 'https://osgard.world/intelligence')
})

await check('optional metadata failure leaves route rendering available and supplies an honest fallback title', async () => {
  const host = environment('/'), seo = host.mountSeo({ failImport: true })
  assert.equal(seo.render('/development'), null)
  await host.settle()
  assert.equal(host.document.title, 'OSGARD — development')
  assert.equal(host.document.head.querySelector('link[rel="canonical"]').href, 'https://osgard.world/')
  host.assertNoReload()
})

console.log(JSON.stringify({ status: 'PASS', tests: checks.length, checks, scope: 'Actual routing and provider logic in a controlled host; browser rendering and native dialog appearance are separate QA.' }, null, 2))
