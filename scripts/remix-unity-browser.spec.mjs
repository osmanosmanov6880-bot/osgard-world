import { test, expect } from '@playwright/test'
import { PNG } from 'pngjs'
import { createHash } from 'node:crypto'

const playerPath = '/games/remix/player/'
const loaderPattern = '**/games/remix/player/Build/REMIX-webgl3.loader.js'
const evidence = new WeakMap()

test.beforeEach(async ({ page }) => {
  const observed = { console: [], pageErrors: [], responses: [], failedRequests: [] }
  evidence.set(page, observed)
  page.on('console', message => {
    if (observed.console.length < 300) observed.console.push({ type: message.type(), text: message.text().slice(0, 3000) })
  })
  page.on('pageerror', error => observed.pageErrors.push(error.message))
  page.on('response', response => {
    if (response.url().includes('/games/remix/player/Build/')) {
      const headers = response.headers()
      observed.responses.push({ file: new URL(response.url()).pathname.split('/').at(-1), status: response.status(), type: headers['content-type'], encoding: headers['content-encoding'] })
    }
  })
  page.on('requestfailed', request => {
    observed.failedRequests.push({ path: new URL(request.url()).pathname, error: request.failure()?.errorText })
  })
})

test.afterEach(async ({ page }, info) => {
  await info.attach('runtime-network-console.json', { body: JSON.stringify(evidence.get(page), null, 2), contentType: 'application/json' })
  if (!page.isClosed()) {
    const state = await page.evaluate(() => ({ state: document.querySelector('#unity-canvas')?.dataset.state, message: document.querySelector('#player-load-status')?.textContent })).catch(() => null)
    await info.attach('launcher-state.json', { body: JSON.stringify(state, null, 2), contentType: 'application/json' })
  }
})

async function waitForReady(page) {
  await page.waitForFunction(() => ['ready', 'error'].includes(document.querySelector('#unity-canvas')?.dataset.state), undefined, { timeout: 150000 })
  await expect(page.locator('#unity-canvas')).toHaveAttribute('data-state', 'ready')
  await expect(page.locator('#unity-canvas')).toHaveAttribute('aria-busy', 'false')
  await expect(page.locator('#unity-fullscreen-button')).toBeEnabled()
  await expect(page.locator('#unity-loading-container')).toBeHidden()
  await expect(page.locator('#player-retry')).toBeHidden()
}

async function expectRecovery(page) {
  await expect(page.locator('#unity-canvas')).toHaveAttribute('data-state', 'error')
  await expect(page.locator('#unity-canvas')).toHaveAttribute('aria-busy', 'false')
  await expect(page.locator('#unity-fullscreen-button')).toBeDisabled()
  await expect(page.locator('#player-retry')).toBeVisible()
  await expect(page.locator('#unity-loading-container')).toBeHidden()
  await expect(page.getByRole('link', { name: 'Каталог миров', exact: true })).toBeVisible()
}

function frameStats(buffer) {
  const frame = PNG.sync.read(buffer)
  const histogram = new Map()
  let min = 255, max = 0
  for (let index = 0; index < frame.data.length; index += 4) {
    const [r, g, b] = frame.data.subarray(index, index + 3)
    const bin = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4)
    histogram.set(bin, (histogram.get(bin) || 0) + 1)
    min = Math.min(min, r, g, b)
    max = Math.max(max, r, g, b)
  }
  const pixels = frame.width * frame.height
  return {
    width: frame.width, height: frame.height,
    sha256: createHash('sha256').update(frame.data).digest('hex'),
    colorBins: histogram.size,
    materialColorBins: [...histogram.values()].filter(count => count / pixels >= 0.002).length,
    largestColorFraction: Math.max(...histogram.values()) / pixels,
    channelRange: max - min,
  }
}

test('actual gzip build initializes, renders its scene, receives focused input and recovers from context loss', async ({ page }, info) => {
  // Observe calls on the real engine; no loader, runtime, network, render
  // output or game state is replaced in this test.
  await page.addInitScript(() => {
    window.__remixObserved = { drawCalls: 0, clears: 0, keys: [], contexts: [] }
    const getContext = HTMLCanvasElement.prototype.getContext
    HTMLCanvasElement.prototype.getContext = function(type, ...args) {
      const context = getContext.call(this, type, ...args)
      if (this.id === 'unity-canvas' && context && /^webgl/.test(type)) {
        window.__remixContext = context
        window.__remixObserved.contexts.push({ type, version: context.getParameter(context.VERSION), renderer: context.getParameter(context.RENDERER) })
      }
      return context
    }
    for (const constructor of [window.WebGLRenderingContext, window.WebGL2RenderingContext]) {
      if (!constructor) continue
      for (const name of ['drawArrays', 'drawElements', 'drawArraysInstanced', 'drawElementsInstanced', 'clear']) {
        const original = constructor.prototype[name]
        if (!original || original.__remixObserved) continue
        const wrapper = function(...args) {
          if (this.canvas?.id === 'unity-canvas') window.__remixObserved[name === 'clear' ? 'clears' : 'drawCalls']++
          return original.apply(this, args)
        }
        wrapper.__remixObserved = true
        constructor.prototype[name] = wrapper
      }
    }
    addEventListener('keydown', event => {
      if (event.target?.id === 'unity-canvas') window.__remixObserved.keys.push(event.key)
    }, true)
  })
  const startedAt = Date.now()
  await page.goto(playerPath)
  await waitForReady(page)
  const readyMs = Date.now() - startedAt
  // The engine promise can settle before the Unity splash is gone. Retain
  // post-startup samples so a splash-only or uniform canvas is not certified.
  await page.waitForTimeout(6000)
  const canvas = page.locator('#unity-canvas')
  await canvas.scrollIntoViewIfNeeded()
  const first = await canvas.screenshot({ path: info.outputPath('unity-scene-before-input.png') })
  const before = await page.evaluate(() => structuredClone(window.__remixObserved))
  await canvas.click()
  await expect(canvas).toBeFocused()
  await page.keyboard.down('ArrowRight')
  await page.waitForTimeout(700)
  await page.keyboard.up('ArrowRight')
  await page.keyboard.press('Space')
  await page.waitForTimeout(700)
  const after = await page.evaluate(() => structuredClone(window.__remixObserved))
  const second = await canvas.screenshot({ path: info.outputPath('unity-scene-after-input.png') })
  await page.screenshot({ path: info.outputPath('unity-player-desktop.png'), fullPage: true })
  const firstFrame = frameStats(first), secondFrame = frameStats(second)
  await info.attach('actual-unity-evidence.json', {
    body: JSON.stringify({
      verification: 'Real Unity loader and engine behind candidate production Nginx; software WebGL in CI',
      readyMs, before, after, firstFrame, secondFrame,
      inputScope: 'Keyboard events reached the focused canvas. Without a Unity gameplay bridge this alone does not prove movement, score, network play, or saved progress.',
      renderedAfterInput: after.drawCalls - before.drawCalls,
      imageChangedAfterInput: firstFrame.sha256 !== secondFrame.sha256,
    }, null, 2), contentType: 'application/json',
  })
  const observed = evidence.get(page)
  for (const [file, type] of [['REMIX-webgl3.data', 'application/octet-stream'], ['REMIX-webgl3.framework.js', 'application/javascript'], ['REMIX-webgl3.wasm', 'application/wasm']]) {
    const response = observed.responses.find(item => item.file === file)
    expect.soft(response, file).toBeDefined()
    expect.soft(response?.status, file).toBe(200)
    expect.soft(response?.encoding, file).toBe('gzip')
    expect.soft(response?.type, file).toContain(type)
  }
  expect.soft(observed.pageErrors).toEqual([])
  expect.soft(observed.failedRequests).toEqual([])
  expect.soft(after.contexts.some(context => context.type === 'webgl2')).toBe(true)
  expect.soft(after.keys).toEqual(expect.arrayContaining(['ArrowRight', ' ']))
  expect.soft(after.drawCalls - before.drawCalls, 'The scene continues drawing after startup').toBeGreaterThan(5)
  expect.soft(firstFrame.materialColorBins, 'A scene must contain visible content beyond a uniform canvas').toBeGreaterThanOrEqual(3)
  expect.soft(firstFrame.largestColorFraction, 'A uniform render is not a playable scene').toBeLessThan(0.98)

  const canLoseContext = await page.evaluate(() => Boolean(window.__remixContext?.getExtension('WEBGL_lose_context')))
  expect(canLoseContext).toBe(true)
  await page.evaluate(() => window.__remixContext.getExtension('WEBGL_lose_context').loseContext())
  await expectRecovery(page)
  await expect(page.locator('#player-load-status')).toContainText('графический контекст')
  await page.screenshot({ path: info.outputPath('unity-context-loss-recovery.png'), fullPage: true })
})

test('missing loader has an accessible retry that reloads the real engine', async ({ page }, info) => {
  await page.route(loaderPattern, route => route.fulfill({ status: 404, contentType: 'text/plain', body: 'Fixture: loader unavailable' }))
  await page.goto(playerPath)
  await expectRecovery(page)
  await page.screenshot({ path: info.outputPath('unity-loader-failure.png'), fullPage: true })
  await page.unroute(loaderPattern)
  await Promise.all([page.waitForEvent('load'), page.locator('#player-retry').click()])
  await waitForReady(page)
})

test('runtime download failure leaves navigation and recovery available', async ({ page }) => {
  await page.route('**/games/remix/player/Build/REMIX-webgl3.data', route => route.fulfill({ status: 503, contentType: 'text/plain', body: 'Fixture: runtime unavailable' }))
  await page.goto(playerPath)
  await expectRecovery(page)
  await expect(page.locator('#player-load-status')).toContainText('Не удалось')
})

test('a browser without WebGL receives an error instead of an endless spinner', async ({ page }, info) => {
  await page.addInitScript(() => {
    const original = HTMLCanvasElement.prototype.getContext
    HTMLCanvasElement.prototype.getContext = function(type, ...args) {
      return /webgl/i.test(type) ? null : original.call(this, type, ...args)
    }
  })
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto(playerPath)
  await expectRecovery(page)
  await expect(page.locator('#player-load-status')).toContainText('WebGL 2')
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true)
  await page.screenshot({ path: info.outputPath('unity-no-webgl-mobile.png'), fullPage: true })
})

test('a synchronous engine exception is caught by the launcher', async ({ page }) => {
  await page.route(loaderPattern, route => route.fulfill({ contentType: 'application/javascript', body: 'window.createUnityInstance=()=>{throw new Error("Fixture: initialization failed")}' }))
  await page.goto(playerPath)
  await expectRecovery(page)
  expect(evidence.get(page).pageErrors).toEqual([])
})

test('only stalled progress exposes retry and a slow successful load can still finish', async ({ page }) => {
  await page.clock.install()
  await page.route(loaderPattern, route => route.fulfill({ contentType: 'application/javascript', body: `
    window.createUnityInstance=(_canvas,_config,progress)=>new Promise(resolve=>{
      window.__fixtureProgress=progress;
      window.__fixtureResolve=()=>resolve({SetFullscreen(){},Quit(){return Promise.resolve()}});
      progress(.1);
    });
  ` }))
  await page.goto(playerPath)
  await expect(page.locator('#unity-progress-bar-empty')).toHaveAttribute('aria-valuenow', '10')
  await page.clock.runFor(60000)
  await page.evaluate(() => window.__fixtureProgress(.2))
  await page.clock.runFor(60000)
  await expect(page.locator('#player-retry')).toBeHidden()
  await expect(page.locator('#unity-canvas')).toHaveAttribute('data-state', 'loading')
  await page.clock.runFor(31000)
  await expect(page.locator('#unity-canvas')).toHaveAttribute('data-state', 'stalled')
  await expect(page.locator('#unity-canvas')).toHaveAttribute('aria-busy', 'true')
  await expect(page.locator('#player-retry')).toBeVisible()
  await page.evaluate(() => window.__fixtureProgress(.2))
  await expect(page.locator('#unity-canvas')).toHaveAttribute('data-state', 'stalled')
  await page.evaluate(() => window.__fixtureProgress(.5))
  await expect(page.locator('#player-retry')).toBeHidden()
  await page.evaluate(() => window.__fixtureResolve())
  await waitForReady(page)
  expect(evidence.get(page).pageErrors).toEqual([])
})

test('a late engine promise cannot erase an earlier fatal banner', async ({ page }) => {
  await page.route(loaderPattern, route => route.fulfill({ contentType: 'application/javascript', body: `
    window.__fixtureQuit=0;
    window.createUnityInstance=(_canvas,config)=>new Promise(resolve=>{
      config.showBanner('Fixture: fatal initialization error','error');
      window.__fixtureResolve=()=>resolve({SetFullscreen(){},Quit(){window.__fixtureQuit++;return Promise.resolve()}});
    });
  ` }))
  await page.goto(playerPath)
  await expectRecovery(page)
  await page.evaluate(() => window.__fixtureResolve())
  await expectRecovery(page)
  expect(await page.evaluate(() => window.__fixtureQuit)).toBe(1)
})
