#!/usr/bin/env node
/** Execute the shipped inline game, not a copied implementation of its physics.
 * A deliberately small DOM/Canvas adapter catches runtime errors and observes
 * rendered HUD, player position, lifecycle events and actual input handlers.
 * This is a Node smoke test; browser rendering/performance need browser QA.
 */
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import vm from 'node:vm'

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const sourcePath = path.resolve(process.argv[2] ?? path.join(repo, 'public/games/vector-zero/index.html'))
const html = readFileSync(sourcePath, 'utf8')
const scripts = [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script\s*>/gi)]
  .filter(([, attributes, code]) => !/\bsrc\s*=|\btype\s*=\s*["']application\/ld\+json/i.test(attributes) && code.trim())
assert.equal(scripts.length, 1, 'Read exactly one actual inline VECTOR//ZERO runtime')

class EventTargetAdapter {
  listeners = new Map()
  addEventListener(type, listener) {
    const listeners = this.listeners.get(type) ?? []
    listeners.push(listener)
    this.listeners.set(type, listeners)
  }
  removeEventListener(type, listener) {
    this.listeners.set(type, (this.listeners.get(type) ?? []).filter(candidate => candidate !== listener))
  }
  dispatch(type, values = {}) {
    const event = { type, target: this, currentTarget: this, defaultPrevented: false, repeat: false,
      preventDefault() { this.defaultPrevented = true }, ...values }
    const propertyListener = this[`on${type}`]
    for (const listener of [...(this.listeners.get(type) ?? [])]) listener.call(this, event)
    if (typeof propertyListener === 'function') propertyListener.call(this, event)
    return event
  }
}

class ElementAdapter extends EventTargetAdapter {
  style = {}
  dataset = {}
  hidden = false
  textContent = ''
  capturedPointers = []
  constructor(tagName, attributes) {
    super()
    this.tagName = tagName.toUpperCase()
    this.attributes = attributes
    this.id = attributes.id ?? ''
    this.hidden = Object.hasOwn(attributes, 'hidden')
    for (const [name, value] of Object.entries(attributes)) {
      if (name.startsWith('data-')) this.dataset[name.slice(5)] = value
    }
  }
  setPointerCapture(pointerId) { this.capturedPointers.push(pointerId) }
  setAttribute(name, value) { this.attributes[name] = String(value) }
  click() { return this.dispatch('click') }
}

const nodes = []
const ids = new Map()
const markup = html.replace(/<script\b[\s\S]*?<\/script\s*>/gi, '')
for (const match of markup.matchAll(/<([a-z][\w:-]*)(\s[^<>]*?)?\s*\/?>/gi)) {
  const attributes = {}
  for (const attribute of (match[2] ?? '').matchAll(/([^\s=/]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?/g)) {
    attributes[attribute[1].toLowerCase()] = attribute[2] ?? attribute[3] ?? attribute[4] ?? ''
  }
  const node = new ElementAdapter(match[1], attributes)
  node.textContent = markup.slice(match.index + match[0].length).split('<', 1)[0]
  nodes.push(node)
  if (node.id) {
    assert.ok(!ids.has(node.id), `Duplicate actual DOM id: ${node.id}`)
    ids.set(node.id, node)
  }
}

const numeric = (values, operation) => {
  assert.ok(values.every(value => typeof value === 'number' && Number.isFinite(value)), `${operation} received non-finite Canvas coordinates`)
}
const canvasState = { calls: 0, labels: new Set(), transforms: [], player: null }
const canvasContext = {}
for (const method of ['beginPath', 'save', 'restore', 'fill', 'stroke']) {
  canvasContext[method] = () => { canvasState.calls++ }
}
for (const method of ['fillRect', 'strokeRect', 'translate', 'moveTo', 'lineTo', 'arc', 'ellipse', 'setTransform']) {
  canvasContext[method] = (...values) => {
    canvasState.calls++
    numeric(values, method)
    if (method === 'setTransform') canvasState.transforms.push([...values])
    if (method === 'strokeRect' && values[2] === 24 && values[3] === 20) {
      canvasState.player = { x: values[0] + 12, y: values[1] + 9 }
    }
  }
}
for (const method of ['createLinearGradient', 'createRadialGradient']) {
  canvasContext[method] = (...values) => {
    numeric(values, method)
    return { addColorStop(offset, color) {
      numeric([offset], 'addColorStop')
      assert.ok(offset >= 0 && offset <= 1 && typeof color === 'string')
    } }
  }
}
canvasContext.fillText = (text, ...values) => {
  canvasState.calls++
  assert.ok(typeof text === 'string' && text.length > 0 && !/undefined|NaN/.test(text), 'Canvas labels must be defined text')
  numeric(values, 'fillText')
  canvasState.labels.add(text)
}
canvasContext.setLineDash = values => numeric([...values], 'setLineDash')

const canvas = ids.get('field')
assert.equal(canvas?.tagName, 'CANVAS', 'The real #field canvas must exist')
let rectangle = { width: 960, height: 540 }
canvas.getBoundingClientRect = () => ({ ...rectangle })
canvas.getContext = (kind, options) => {
  assert.equal(kind, '2d')
  assert.equal(options?.alpha, false)
  return canvasContext
}

const document = new EventTargetAdapter()
document.hidden = false
document.fullscreenElement = null
document.documentElement = nodes.find(node => node.tagName === 'HTML')
document.documentElement.requestFullscreen = () => {
  document.fullscreenElement = document.documentElement
  return Promise.resolve()
}
document.exitFullscreen = () => { document.fullscreenElement = null; return Promise.resolve() }
document.getElementById = id => ids.get(id) ?? null // Never fabricate a missing HUD element.
document.querySelectorAll = selector => {
  assert.ok(selector === '[data-hold]' || selector === '[data-tap]', `Unsupported actual selector: ${selector}`)
  const attribute = selector.slice(1, -1)
  return nodes.filter(node => Object.hasOwn(node.attributes, attribute))
}

const window = new EventTargetAdapter()
const lifecycle = []
window.parent = { postMessage(message, origin) { lifecycle.push({ message, origin }) } }
const animationFrames = new Map()
let frameId = 0
let now = 0
let framesRun = 0
const sandbox = { window, document, location: { origin: 'https://osgard.test' }, devicePixelRatio: 2,
  performance: { now: () => now }, console,
  requestAnimationFrame(callback) { const id = ++frameId; animationFrames.set(id, callback); return id },
  cancelAnimationFrame(id) { animationFrames.delete(id) } }
const context = vm.createContext(sandbox, { codeGeneration: { strings: false, wasm: false } })
new vm.Script(scripts[0][2], { filename: sourcePath }).runInContext(context, { timeout: 1500 })

const checks = []
const node = id => { assert.ok(ids.has(id), `Missing actual element #${id}`); return ids.get(id) }
const key = (value, type = 'keydown') => window.dispatch(type, { key: value })
const click = id => node(id).click()
const pump = (count = 1) => {
  for (let index = 0; index < count; index++) {
    assert.equal(animationFrames.size, 1, 'The runtime must schedule one ongoing RAF loop')
    const [id, callback] = animationFrames.entries().next().value
    animationFrames.delete(id)
    now += 1000 / 60
    callback(now)
    framesRun++
  }
}
const snapshot = () => {
  const telemetry = /PLAYER X (-?\d+) · CORE (ACTIVE|IDLE) · SPEED (\d+)/.exec(node('diag').textContent)
  assert.ok(telemetry, 'Actual telemetry must expose finite player and core values')
  return { time: node('time').textContent, x: Number(telemetry[1]), core: telemetry[2],
    speed: Number(telemetry[3]), polarity: node('charge').textContent }
}
const startedCount = () => lifecycle.filter(({ message }) => message.state === 'started').length

assert.equal(node('objective-status').textContent, 'SYSTEM READY')
assert.equal(node('overlay').hidden, false)
assert.equal(snapshot().x, 150)
assert.equal(snapshot().core, 'IDLE')
assert.equal(snapshot().time, '00:00.0')
assert.ok(lifecycle.some(({ message, origin }) => message.state === 'ready' && message.game === 'vector-zero' && origin === sandbox.location.origin))
assert.deepEqual(canvasState.transforms.at(-1), [1.5, 0, 0, 1.5, 0, 0])
assert.ok(canvasState.labels.has('PLATE A / +') && canvasState.labels.has('PLATE B / −'))
pump()
assert.ok(canvasState.calls > 50 && canvasState.player, 'Initialization and one real RAF must render the scene')
checks.push('real DOM initialization, reset HUD, defined magnet labels, initial Canvas transform and RAF')

rectangle = { width: 390, height: 292.5 }
sandbox.devicePixelRatio = 3
window.dispatch('resize')
assert.equal(canvas.width, 780)
assert.equal(canvas.height, 585)
const mobileScale = 780 / 1280
assert.deepEqual(canvasState.transforms.at(-1), [mobileScale, 0, 0, mobileScale, 0, (585 - 720 * mobileScale) / 2])
assert.equal(canvasState.transforms.at(-1)[0], canvasState.transforms.at(-1)[3], 'Mobile geometry must not stretch magnetic circles')
const transformCount = canvasState.transforms.length
rectangle = { width: 0, height: 0 }
window.dispatch('resize')
assert.equal(canvasState.transforms.length, transformCount, 'A hidden canvas must not install an invalid transform')
rectangle = { width: 960, height: 540 }
window.dispatch('resize')
checks.push('mobile uniform letterboxing, un-stretched circles, DPR cap and zero-size guard')

click('help')
assert.equal(node('title').textContent, 'Управление')
click('start')
assert.equal(node('overlay').hidden, true)
assert.equal(node('objective-status').textContent, 'FIELD ACTIVE')
assert.equal(snapshot().core, 'ACTIVE')
assert.ok(snapshot().speed > 0)
assert.equal(startedCount(), 1)
key('q')
assert.match(snapshot().polarity, /NEGATIVE/)
click('pol')
assert.match(snapshot().polarity, /POSITIVE/)
const tapPolarity = nodes.find(element => element.dataset.tap === 'pol')
assert.ok(tapPolarity, 'The actual mobile polarity control must exist')
tapPolarity.click()
assert.match(snapshot().polarity, /NEGATIVE/)
const assist = node('assist')
assert.equal(assist.attributes['aria-pressed'], 'true')
assist.click()
assert.equal(assist.attributes['aria-pressed'], 'false')
assert.equal(assist.textContent, 'AIM / OFF')
assist.click()
assert.equal(assist.attributes['aria-pressed'], 'true')
const beforeRepeat = snapshot().polarity
window.dispatch('keydown', { key: 'q', repeat: true })
assert.equal(snapshot().polarity, beforeRepeat, 'Holding Q must not flip polarity on auto-repeat')
checks.push('help before start, real launch, polarity input de-bounce and trajectory-assist toggle')

key('ArrowRight')
pump(16)
key('ArrowRight', 'keyup')
assert.ok(snapshot().x > 150, 'Held movement must advance the actual player')
const groundedY = canvasState.player.y
key('w')
pump(3)
key('w', 'keyup')
assert.ok(canvasState.player.y < groundedY, 'The real jump input must move the rendered player upward')
checks.push('held keyboard movement and jump reach the actual physics/render loop')

const beforePause = snapshot()
const escape = key('Escape')
assert.equal(escape.defaultPrevented, true)
assert.equal(node('objective-status').textContent, 'PAUSED')
assert.equal(node('overlay').hidden, false, 'Pause must expose controls and a reachable resume action')
assert.equal(node('title').textContent, 'Пауза')
window.dispatch('keydown', { key: 'Escape', repeat: true })
assert.equal(node('objective-status').textContent, 'PAUSED', 'Holding Escape must not repeatedly toggle pause')
pump(8)
key('q')
click('pulse')
assert.deepEqual(snapshot(), beforePause, 'Paused frames and action buttons must preserve the current attempt')
click('help')
assert.equal(node('title').textContent, 'Управление')
assert.match(node('start').textContent, /ВЕРНУТЬСЯ В ИГРУ/)
click('help')
assert.equal(node('overlay').hidden, false, 'Repeated help clicks must not install competing onclick handlers')
assert.equal(node('objective-status').textContent, 'PAUSED')
click('start')
assert.equal(node('overlay').hidden, true)
assert.equal(node('objective-status').textContent, 'FIELD ACTIVE')
assert.deepEqual(snapshot(), beforePause, 'Resume must preserve time, player, polarity and core instead of reset/launch')
assert.equal(startedCount(), 1, 'Resume must not report another game start')
pump(8)
assert.notEqual(snapshot().time, beforePause.time, 'The simulation must advance again after resume')
key('Escape')
assert.equal(node('objective-status').textContent, 'PAUSED')
key('Escape')
assert.equal(node('objective-status').textContent, 'FIELD ACTIVE')
assert.equal(node('overlay').hidden, true)
checks.push('Escape pause, frozen simulation, stable help, resume without reset or duplicate lifecycle start')

click('full')
assert.equal(document.fullscreenElement, document.documentElement)
click('full')
assert.equal(document.fullscreenElement, null)
click('restart')
assert.equal(node('overlay').hidden, false)
assert.equal(node('objective-status').textContent, 'SYSTEM READY')
assert.deepEqual(snapshot(), { time: '00:00.0', x: 150, core: 'IDLE', speed: 0, polarity: '+ POSITIVE' })
pump()
assert.equal(canvasState.player.y, 564)
assert.equal(key(' ').defaultPrevented, true)
assert.equal(startedCount(), 2)
click('pulse')
pump(2)
assert.ok(canvasState.player.y < 564, 'Pulse must affect the actual player body')
key('r')
assert.equal(node('objective-status').textContent, 'SYSTEM READY')
checks.push('fullscreen API controls, button/keyboard reset, Space start and actual pulse effect')

const touchLaunch = nodes.find(element => element.dataset.tap === 'launch')
const touchRight = nodes.find(element => element.dataset.hold === 'right')
assert.ok(touchLaunch && touchRight, 'Actual mobile launch and movement controls must exist')
touchLaunch.click()
const pointer = touchRight.dispatch('pointerdown', { pointerId: 17 })
assert.equal(pointer.defaultPrevented, true)
assert.deepEqual(touchRight.capturedPointers, [17])
pump(10)
assert.ok(snapshot().x > 150)
touchRight.dispatch('pointercancel', { pointerId: 17 })
pump(18)
const afterRelease = snapshot().x
pump(8)
assert.ok(snapshot().x - afterRelease < 8, 'Pointer cancellation must release movement and allow friction to settle')
key('ArrowRight')
window.dispatch('blur')
pump(8)
const afterBlur = snapshot().x
pump(8)
assert.ok(snapshot().x - afterBlur < 5, 'Window blur must clear held keyboard input')
key('ArrowRight')
document.hidden = true
document.dispatch('visibilitychange')
assert.equal(node('objective-status').textContent, 'PAUSED', 'Switching tabs must automatically pause the attempt')
pump(8)
const afterHidden = snapshot().x
pump(8)
assert.ok(snapshot().x - afterHidden < 5, 'Hidden document must clear held keyboard input')
checks.push('mobile launch/hold/cancel, pointer capture, blur and visibility input cleanup')

window.dispatch('error', { message: 'fixture diagnostic' })
assert.ok(lifecycle.some(({ message }) => message.state === 'error' && message.message === 'fixture diagnostic'))
assert.ok([...ids.values()].every(element => !/undefined|NaN/.test(String(element.textContent))), 'HUD must not expose undefined/NaN values')
assert.equal(animationFrames.size, 1)
checks.push('error lifecycle forwarding, finite HUD values and a single ongoing animation loop')

document.hidden = false
click('restart')
click('start')
key('w')
pump(54)
assert.ok(canvasState.player.y > 500 && canvasState.player.y < 564, 'First jump must be descending toward the platform')
key('w', 'keyup')
key('w')
pump(13)
assert.ok(canvasState.player.y < 530, 'A jump pressed shortly before landing must be buffered and executed')
checks.push('buffered jump executes on landing instead of being lost')

click('restart')
click('start')
key('ArrowRight')
let edgeFrames = 0
while (snapshot().x < 944 && edgeFrames++ < 350 && node('objective-status').textContent === 'FIELD ACTIVE') pump()
assert.ok(snapshot().x >= 944, 'Player must reach the first platform gap during the actual run')
const edgeY = canvasState.player.y
key('w')
pump(4)
assert.ok(canvasState.player.y < edgeY - 2, 'Coyote-time jump must work immediately after leaving a ledge')
key('ArrowRight', 'keyup')
checks.push('coyote-time jump at the first platform edge')

console.log(JSON.stringify({ status: 'PASS', source: path.relative(repo, sourcePath), checks,
  frames: framesRun, canvasCalls: canvasState.calls, lifecycleStarts: startedCount(),
  scope: 'Actual inline runtime in Node VM; no browser rendering or production claim.' }, null, 2))
