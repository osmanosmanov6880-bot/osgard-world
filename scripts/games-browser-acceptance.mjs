/**
 * Real Chromium acceptance for the 19 catalog entries.
 *
 * npm run build
 * npx playwright install chromium
 * node scripts/games-browser-acceptance.mjs --root dist
 *
 * --only zion-030,swarm  --devices desktop,mobile  --out test-results/games-browser
 * --base-url http://127.0.0.1:4173 (uses an existing server)
 * --allow-api-mutations explicitly permits non-read-only requests to the selected
 * base origin. Other origins always remain blocked and recorded.
 * --expected-blocked null-shift,remix permits only named external dependencies;
 * blocked integrations stay blocked
 * in JSON and totalAccepted remains false. No responses or game state are mocked.
 */
import assert from 'node:assert/strict'
import { createServer } from 'node:http'
import { readFile, mkdir, stat, writeFile } from 'node:fs/promises'
import { existsSync } from 'node:fs'
import { dirname, extname, resolve, sep } from 'node:path'
import { fileURLToPath } from 'node:url'
import { chromium } from 'playwright'
import { acceptGodotNullShift } from './null-shift-godot-browser.mjs'
import { acceptRemix } from './remix-browser-acceptance.mjs'

const projectRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const args = process.argv.slice(2)
function option(name, fallback) {
  const index = args.indexOf(name)
  if (index < 0) return fallback
  assert.ok(args[index + 1] && !args[index + 1].startsWith('--'), `${name} needs a value`)
  return args[index + 1]
}
const root = resolve(projectRoot, option('--root', 'dist'))
const out = resolve(projectRoot, option('--out', process.env.GAMES_BROWSER_OUTPUT || 'test-results/games-browser'))
const selected = new Set(option('--only', '').split(',').filter(Boolean))
const devices = option('--devices', 'desktop,mobile').split(',')
assert.ok(devices.every(value => ['desktop', 'mobile'].includes(value)), 'Devices must be desktop,mobile')
assert.ok(!args.includes('--allow-blocked'), 'Use --expected-blocked with explicit game IDs; broad blocker bypass is not supported')
const expectedBlocked = new Set(option('--expected-blocked', '').split(',').filter(Boolean))
const timeout = Number(option('--timeout', '12000'))
assert.ok(Number.isFinite(timeout) && timeout >= 1000, '--timeout must be milliseconds >= 1000')
const catalogSource = await readFile(resolve(projectRoot, 'src/redesignCatalog.ts'), 'utf8')
const catalogMatch = catalogSource.match(/export const playGames:PlayGame\[\] = ([\s\S]*?)\nexport const getPlayGame/)
assert.ok(catalogMatch, 'Unable to read the authoritative catalog')
const catalog = JSON.parse(catalogMatch[1])
assert.equal(catalog.length, 19, 'Acceptance matrix must account for all 19 catalog entries')
assert.equal(new Set(catalog.map(item => item.id)).size, 19)
for (const id of selected) assert.ok(catalog.some(item => item.id === id), `Unknown catalog game: ${id}`)
for (const id of expectedBlocked) assert.ok(catalog.some(item => item.id === id), `Unknown expected blocker: ${id}`)

const contentTypes = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8', '.json': 'application/json', '.svg': 'image/svg+xml', '.png': 'image/png',
  '.webp': 'image/webp', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.woff': 'font/woff', '.woff2': 'font/woff2', '.ttf': 'font/ttf',
  '.wasm': 'application/wasm', '.webmanifest': 'application/manifest+json',
}
async function startStaticServer() {
  assert.ok(existsSync(root), `Missing ${root}. Run npm run build or select --root public for static-only diagnostics.`)
  const server = createServer(async (request, response) => {
    try {
      if (!['GET', 'HEAD'].includes(request.method)) {
        response.writeHead(404, { 'content-type': 'application/json' })
        response.end(JSON.stringify({ error: 'No API service is supplied by this static acceptance server.' }))
        return
      }
      const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname)
      let path = resolve(root, '.' + pathname)
      if (path !== root && !path.startsWith(root + sep)) { response.writeHead(403); response.end(); return }
      try { if ((await stat(path)).isDirectory()) path = resolve(path, 'index.html') } catch {}
      // These are actual SPA routes. Missing game bundles/assets never receive SPA HTML.
      if (!existsSync(path) && ['/games/time', '/games/time/', '/play', '/play/'].includes(pathname)) path = resolve(root, 'index.html')
      if (!existsSync(path)) { response.writeHead(404, { 'content-type': 'text/plain' }); response.end('Not found'); return }
      const compressed = path.endsWith('.gz')
      response.writeHead(200, {
        'content-type': contentTypes[extname(compressed ? path.slice(0, -3) : path)] || 'application/octet-stream',
        'cache-control': 'no-store', ...(compressed ? { 'content-encoding': 'gzip' } : {}),
      })
      response.end(request.method === 'HEAD' ? undefined : await readFile(path))
    } catch (error) { response.writeHead(500, { 'content-type': 'text/plain' }); response.end(String(error)) }
  })
  await new Promise((resolveListen, reject) => {
    server.once('error', reject)
    server.listen(0, '127.0.0.1', resolveListen)
  })
  return { server, url: `http://127.0.0.1:${server.address().port}` }
}

const externalBase = option('--base-url', process.env.GAMES_BROWSER_BASE_URL)
const local = externalBase ? null : await startStaticServer()
const base = new URL(externalBase || local.url)
assert.ok(['http:', 'https:'].includes(base.protocol), 'Expected an HTTP(S) base URL')
const allowApiMutations = args.includes('--allow-api-mutations')
const safeApiActions = Boolean(local) || allowApiMutations
await mkdir(out, { recursive: true })

function integrationFor(url) {
  const path = new URL(url, base).pathname
  if (path.startsWith('/api/remix/')) return 'remix-match-service'
  if (path.startsWith('/api/world/')) return 'inherit-shared-world'
  if (/^\/(rooms|players)\//.test(path)) return 'swarm-room-service'
  if (path.startsWith('/api/') || /\/api\//.test(path)) return 'optional-platform-api'
  return null
}
const errorMessage = error => String(error?.message || error).slice(0, 2500)
const sleep = milliseconds => new Promise(done => setTimeout(done, milliseconds))
class Blocked extends Error {}

async function activate(locator, mobile, keyboard = true) {
  await locator.waitFor({ state: 'visible' })
  assert.ok(await locator.isEnabled(), 'Required control is disabled')
  await locator.scrollIntoViewIfNeeded()
  const control = await locator.evaluate(element => {
    const box = element.getBoundingClientRect()
    return { name: element.getAttribute('aria-label') || element.textContent?.trim() || element.getAttribute('title'),
      width: box.width, height: box.height, tabIndex: element.tabIndex }
  })
  assert.ok(control.name, 'Required control has no accessible label')
  assert.ok(control.width >= 10 && control.height >= 10, 'Required control has no usable hit area')
  if (mobile) await locator.tap()
  else if (keyboard) { assert.ok(control.tabIndex >= 0, 'Required control is not keyboard focusable'); await locator.focus(); await locator.press('Enter') }
  else await locator.click()
}

async function holdTouch(page, locator, milliseconds, offset = null) {
  await locator.scrollIntoViewIfNeeded()
  const box = await locator.boundingBox()
  assert.ok(box, 'Touch target has no rectangle')
  const x = box.x + box.width * (offset?.x ?? 0.5)
  const y = box.y + box.height * (offset?.y ?? 0.5)
  const session = await page.context().newCDPSession(page)
  try {
    await session.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] })
    await sleep(milliseconds)
    await session.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] })
  } finally { await session.detach() }
}

async function zionPuzzle(page, result) {
  const mobile = result.device === 'mobile'
  const order = result.id === 'zion-020' ? [0, 1, 2] : [0, 2, 1]
  await page.locator('#nodes button').first().waitFor()
  assert.equal(await page.locator('#nodes button').count(), 3)
  // An incorrect first signal must recover before the correct sequence.
  await activate(page.locator('#nodes button').nth(order[2]), mobile)
  await page.waitForFunction(() => document.querySelectorAll('#nodes .wrong').length === 0)
  assert.equal(await page.locator('#nodes .done').count(), 0)
  for (const index of order) await activate(page.locator('#nodes button').nth(index), mobile)
  assert.ok(await page.locator('#reveal').evaluate(element => element.classList.contains('on')))
  assert.equal(await page.locator('#nodes .done').count(), 3)
  result.checks.push('Incorrect signal resets; three ordered user activations reveal the ending')
  await activate(page.locator('#reset'), mobile)
  assert.equal(await page.locator('#nodes .done').count(), 0)
  assert.ok(!await page.locator('#reveal').evaluate(element => element.classList.contains('on')))
  result.checks.push('Reset removes the ending and restores all three controls')
}

async function zionStory(page, result) {
  const fragments = page.locator('#world-play details')
  const count = await fragments.count()
  assert.equal(count, result.id === 'zion-022' ? 3 : 4, 'Story must expose all fragments and its final disclosure')
  result.fragments = []
  for (let index = 0; index < count; index++) {
    const fragment = fragments.nth(index)
    assert.equal(await fragment.getAttribute('open'), null)
    await activate(fragment.locator('summary'), result.device === 'mobile')
    assert.ok(await fragment.evaluate(element => element.open), 'Native disclosure did not open')
    assert.ok(await fragment.locator('p').isVisible(), 'Story text remains hidden after activation')
    result.fragments.push(await fragment.locator('summary').innerText())
  }
  await activate(fragments.first().locator('summary'), result.device === 'mobile')
  assert.ok(!await fragments.first().evaluate(element => element.open), 'Native disclosure did not close')
  result.checks.push(`All ${count} narrative disclosures open with keyboard/touch; first closes again`)
  result.scope = 'Interactive reading; this entry has no branching score or win condition'
}

async function zionBoard(page, result) {
  await page.waitForFunction(() => window.__ZION9_TEST__?.state().renderingMode !== 'pending' && Boolean(window.__ZION9_TEST__))
  const state = () => page.evaluate(() => window.__ZION9_TEST__.state())
  result.renderer = await state()
  assert.ok(['webgl', 'canvas2d'].includes(result.renderer.renderingMode))
  if (result.renderer.webgl) {
    await page.waitForFunction(() => window.__ZION9_TEST__.state().frameCounter >= 2)
    assert.ok((await state()).rendererCalls > 0, 'WebGL started but drew no scene')
  }
  const mobile = result.device === 'mobile'
  for (const [index, target] of [[-4, -3], [2, 2], [4, -2]].entries()) {
    await activate(page.locator('.module').nth(index), mobile)
    const cursor = (await state()).cursor
    if (!mobile) {
      await page.locator('#scene').scrollIntoViewIfNeeded()
      await page.locator('#scene').focus()
      for (let n = 0; n < Math.abs(target[0] - cursor.x); n++) await page.keyboard.press(target[0] < cursor.x ? 'ArrowLeft' : 'ArrowRight')
      for (let n = 0; n < Math.abs(target[1] - cursor.z); n++) await page.keyboard.press(target[1] < cursor.z ? 'ArrowUp' : 'ArrowDown')
      await page.keyboard.press('Enter')
    } else {
      for (let n = 0; n < Math.abs(target[0] - cursor.x); n++) await activate(page.locator(`[data-cursor="${target[0] < cursor.x ? 'left' : 'right'}"]`), true)
      for (let n = 0; n < Math.abs(target[1] - cursor.z); n++) await activate(page.locator(`[data-cursor="${target[1] < cursor.z ? 'up' : 'down'}"]`), true)
      await activate(page.locator('#place-keyboard'), true)
    }
    assert.equal((await state()).score, index + 1, 'User placement did not cool its target')
  }
  assert.ok((await state()).won)
  result.checks.push('Three real keyboard/touch placements cool distinct hotspots and complete the puzzle')
  await activate(page.locator('#reset'), mobile)
  assert.equal((await state()).placed, 0)
  assert.ok(!(await state()).won)
  result.checks.push('Reset frees the board and clears victory')
}

async function nullShift(page, result) {
  if (result.variant === 'catalog' && result.route.includes('godot')) {
    await acceptGodotNullShift(page, result, { timeout, screenshot: async label => {
      const file = `${result.id}-${result.device}-${label}.png`
      await page.screenshot({ path: resolve(out, file), animations: 'disabled', timeout })
      result.screenshots.push(file)
    } })
    return
  }
  assert.ok(await page.locator('#game-frame').count(), result.variant === 'lightweight'
    ? 'The lightweight game document is missing its required game frame'
    : 'The game document loaded but exposes no supported gameplay state contract; a rendered Godot export requires its own interaction adapter')
  await page.waitForFunction(() => Boolean(window.NULL_SHIFT_GET_SCENE_STATE?.()))
  const state = () => page.evaluate(() => window.NULL_SHIFT_GET_SCENE_STATE())
  const before = await state()
  if (result.device === 'mobile') await holdTouch(page, page.locator('#move-stick'), 380, { x: 0.84, y: 0.5 })
  else { await page.locator('#game').focus(); await page.keyboard.down('d'); await sleep(380); await page.keyboard.up('d') }
  const moved = await state()
  assert.ok(moved.player.x > before.player.x + 8, 'Movement input did not move the player')
  result.checks.push('Movement changes actual player X using keyboard/touch joystick')
  if (result.device === 'mobile') await activate(page.locator('#touch-shift'), true)
  else await page.keyboard.press('Shift')
  const shifted = await state()
  assert.ok(shifted.nullMode > 0 && shifted.instability > moved.instability, 'Shift did not change game mechanics')
  result.checks.push('Shift enters NULL mode, consumes stability and creates the echo')
  result.observed = { beforeX: before.player.x, afterX: moved.player.x, nullMode: shifted.nullMode, instability: shifted.instability }
  result.renderer = await page.evaluate(() => ({ mode: document.documentElement.classList.contains('webgl-active') ? 'webgl' : 'canvas2d',
    badge: document.querySelector('.engine-render-badge')?.textContent || null }))
  result.scope = 'Lightweight local raid; Godot export and completion of the entire raid are separate checks'
}

async function timeGame(page, result) {
  const board = page.locator('.tg-map-viewport')
  await board.waitFor()
  const initialTick = Number(await board.getAttribute('data-city-tick'))
  const district = page.locator('.tg-map-district').first()
  await activate(district, result.device === 'mobile')
  assert.equal(await district.getAttribute('aria-pressed'), 'true')
  const policy = page.locator('.tg-policy-option').nth(1)
  await activate(policy, result.device === 'mobile')
  assert.equal(await policy.getAttribute('aria-pressed'), 'true')
  const turn = result.device === 'mobile' ? page.locator('.tg-mobile-command-dock button').last() : page.locator('.tg-resolve-button').first()
  await activate(turn, result.device === 'mobile')
  await page.waitForFunction(tick => Number(document.querySelector('.tg-map-viewport')?.dataset.cityTick) > tick, initialTick)
  const saved = await page.evaluate(() => JSON.parse(localStorage.getItem('osgard.time.empire.save.v1')))
  assert.equal(saved.tick, initialTick + 1)
  assert.ok(saved.archive.length > 0)
  result.checks.push('Select district and policy; resolve a turn; tick and stored chronicle advance')
  await page.reload({ waitUntil: 'domcontentloaded' })
  await page.waitForFunction(tick => Number(document.querySelector('.tg-map-viewport')?.dataset.cityTick) === tick, saved.tick)
  result.checks.push('Reload restores the resolved turn from local storage')
  result.scope = 'Local city simulation; account/session APIs are recorded separately'
}

async function empireOrbit(page, result) {
  await page.locator('.orrery-enter').waitFor()
  await activate(page.locator('.orrery-node[data-world="time"]'), result.device === 'mobile')
  await activate(page.locator('.orrery-enter'), result.device === 'mobile')
  await page.locator('.orrery-gate').waitFor({ state: 'detached' })
  await activate(page.locator('.empire-map-open'), result.device === 'mobile')
  await page.locator('.empire-map').waitFor()
  const resources = page.locator('.empire-resources')
  const before = await resources.innerText()
  const choice = page.locator('[data-choice="city"]')
  await activate(choice, result.device === 'mobile')
  assert.notEqual(await resources.innerText(), before, 'The city decision did not change resources')
  assert.ok(await choice.isDisabled())
  const saved = await page.evaluate(() => JSON.parse(localStorage.getItem('osgard-empire-world-v1') || 'null'))
  assert.ok(saved?.choices?.includes('city'), 'The city decision was not saved')
  result.checks.push('Open the time world; a city decision changes resources and cannot be reapplied')
  result.observed = { resourcesBefore: before, resourcesAfter: await resources.innerText(), campaignStored: Boolean(saved) }
  result.scope = 'Local orbital city prototype; no real-money balance or remote state'
}

async function swarm(page, result) {
  await page.locator('#role-panel .role').first().waitFor()
  assert.equal(await page.locator('#role-panel .role').count(), 8)
  await activate(page.locator('#start'), result.device === 'mobile')
  assert.ok(await page.locator('#overlay').evaluate(element => element.classList.contains('is-hidden')))
  await page.waitForFunction(() => Boolean(window.__SWARM_TEST__?.state().active))
  const before = await page.evaluate(() => window.__SWARM_TEST__.state())
  if (result.device === 'mobile') await holdTouch(page, page.locator('[data-key="KeyD"]'), 350)
  else { await page.keyboard.down('d'); await sleep(350); await page.keyboard.up('d') }
  const after = await page.evaluate(() => window.__SWARM_TEST__.state())
  assert.ok(after.player.x > before.player.x + 5, 'Locomotion input did not move the body')
  await activate(page.locator('[data-role="4"]'), result.device === 'mobile')
  assert.ok(await page.locator('[data-role="4"]').evaluate(element => element.classList.contains('active')))
  result.checks.push('Start a real local round; move body; select a distinct role')
  result.observed = { beforeX: before.player.x, afterX: after.player.x, role: await page.locator('#role-name').innerText() }
  await activate(page.locator('[data-role="7"]'), result.device === 'mobile')
  if (result.device === 'mobile') await holdTouch(page, page.locator('[data-key="KeyQ"]'), 90)
  else await page.keyboard.press('q', { delay: 90 })
  assert.ok(await page.evaluate(() => window.__SWARM_TEST__.state().overdrive > 0), 'The special role cannot activate overdrive')
  result.checks.push('The special role activates real overdrive from keyboard/touch controls')
  await activate(page.locator('#reset'), result.device === 'mobile')
  assert.ok(await page.locator('#overlay').isVisible())
  assert.ok(!await page.evaluate(() => window.__SWARM_TEST__.state().active))
  result.checks.push('Reset ends the round and restores the reachable lobby')
  result.scope = 'Local training only; no room was hosted or joined'
}

async function inherit(page, result) {
  await page.locator('#budget').waitFor({ state: 'attached' })
  const before = Number(await page.locator('#budget').textContent())
  await activate(page.locator('[data-tool="stone"]'), result.device === 'mobile')
  if (result.device === 'mobile') {
    await page.locator('#island').scrollIntoViewIfNeeded()
    const box = await page.locator('#island').boundingBox()
    assert.ok(box)
    await page.touchscreen.tap(box.x + box.width * 0.63, box.y + box.height * 0.61)
  } else {
    // Ordinary navigation must not clear the selected tool through digit shortcuts.
    await page.keyboard.press('Tab')
    await page.locator('#world').focus()
    await page.keyboard.press('ArrowRight')
    await page.keyboard.press('ArrowDown')
    await page.keyboard.press('Enter')
  }
  assert.equal(Number(await page.locator('#budget').textContent()), before - 1, 'Placing a trace did not consume budget')
  const saved = await page.evaluate(() => JSON.parse(localStorage.getItem('inherit-world-v1')))
  assert.equal(saved.objects.at(-1).tool, 'stone')
  result.checks.push('Selecting stone and keyboard/touch placement consumes budget and persists a real trace')
  await activate(page.locator('#showHistory'), result.device === 'mobile')
  assert.ok(await page.locator('#modal').evaluate(element => element.open))
  await activate(page.locator('#past'), result.device === 'mobile')
  assert.ok(await page.locator('body').evaluate(element => element.classList.contains('past')))
  await activate(page.locator('#done'), result.device === 'mobile')
  assert.ok(!await page.locator('body').evaluate(element => element.classList.contains('past')))
  assert.deepEqual(await page.evaluate(() => JSON.parse(localStorage.getItem('inherit-world-v1'))), saved)
  assert.ok(await page.locator('.replay-banner').isHidden(), 'Closed replay controls remain exposed')
  assert.ok(await page.locator('.catalog').isHidden(), 'Closed trace catalog remains exposed')
  result.checks.push('History/past mode returns to today without changing stored world data')
  result.scope = 'Local lineage editing/history; shared-world service is reported independently'
}

async function remix(page, result) {
  await acceptRemix(page, result, { timeout, Blocked, safeApiActions, screenshot: async label => {
    const path = `${result.id}-${result.device}-${label}.png`
    await page.screenshot({ path: resolve(out, path), fullPage: true, animations: 'disabled', timeout })
    result.screenshots.push(path)
  } })
  result.integrations.push({ name: 'remix-match-service', status: 'verified', ruleset: result.remix.ruleset,
    scope: 'Authenticated input, result, creator proof/publication and independently reproduced replay for this server only' })
}

async function vectorZero(page, result) {
  await activate(page.locator('#start'), result.device === 'mobile')
  await page.waitForFunction(() => document.querySelector('#objective-status')?.textContent === 'FIELD ACTIVE')
  const position = async () => Number((await page.locator('#diag').innerText()).match(/PLAYER X (\d+)/)?.[1])
  const before = await position()
  if (result.device === 'mobile') await holdTouch(page, page.locator('[data-hold="right"]'), 320)
  else { await page.keyboard.down('d'); await sleep(320); await page.keyboard.up('d') }
  assert.ok(await position() > before + 5, 'Player position did not respond to movement')
  if (result.device === 'mobile') await activate(page.locator('[data-tap="pol"]'), true)
  else await page.keyboard.press('q')
  assert.ok((await page.locator('#charge').innerText()).includes('NEGATIVE'))
  result.checks.push('Start launches the moving core; user movement changes player X; polarity flips negative')
  await activate(page.locator('#restart'), result.device === 'mobile')
  assert.equal(await page.locator('#objective-status').innerText(), 'SYSTEM READY')
  assert.equal(await position(), 150)
  result.checks.push('Restart restores the player and ready state')
}

async function afterimageRun(page, result) {
  await activate(page.locator('#run-start'), result.device === 'mobile')
  await page.waitForFunction(() => parseInt(document.querySelector('#distance-score')?.textContent, 10) > 0)
  if (result.device === 'mobile') await activate(page.locator('#phase-dash'), true)
  else await page.keyboard.press('Shift')
  await page.waitForFunction(() => /\d\.\d+s/.test(document.querySelector('#phase-dash')?.textContent || ''))
  assert.ok(await page.locator('#phase-dash').isDisabled(), 'Dash cooldown must prevent repeat activation')
  result.checks.push('Start advances distance; dash changes its cooldown and disables repeat activation')
  await activate(page.locator('#run-pause'), result.device === 'mobile')
  assert.equal(await page.locator('#run-state').innerText(), 'PAUSED')
  const distance = await page.locator('#distance-score').innerText()
  await sleep(160)
  assert.equal(await page.locator('#distance-score').innerText(), distance, 'Paused run kept advancing')
  await activate(page.locator('#run-reset'), result.device === 'mobile')
  assert.equal(await page.locator('#distance-score').innerText(), '0000m')
  assert.equal(await page.locator('#run-state').innerText(), 'SYSTEM READY')
  assert.ok(await page.locator('#run-start').isEnabled(), 'Reset must enable starting another run')
  result.checks.push('Pause freezes distance; reset restores zero distance and an enabled start')
}

const handlers = { 'null-shift': nullShift, time: timeGame, 'empire-orbit': empireOrbit, swarm, inherit, remix, 'vector-zero': vectorZero, 'afterimage-run': afterimageRun }
let browser
const startedAt = new Date().toISOString()
const results = []
async function runCase(game, device, route = game.href, variant = 'catalog') {
  const profile = device === 'mobile' ? { width: 390, height: 844 } : { width: 1440, height: 1000 }
  const result = { id: game.id, title: game.name || game.title, device, variant, catalogRoute: game.href, route,
    status: 'pending', checks: [], pageErrors: [], failedResources: [], integrations: [], blockedRequests: [], consoleErrors: [], consoleWarnings: [], engineMessages: [], screenshots: [] }
  const context = await browser.newContext({ viewport: profile,
    deviceScaleFactor: device === 'mobile' ? 2 : 1, isMobile: device === 'mobile', hasTouch: device === 'mobile',
    locale: 'ru-RU', reducedMotion: 'reduce', serviceWorkers: 'block' })
  // The local Core wrapper creates this real, disposable session over HTTP.
  // Keep the raw token out of URLs, reports and traces, and bind it to this origin.
  if (game.id === 'remix' && process.env.OSGARD_REMIX_ACCEPTANCE_TOKEN) {
    await context.addInitScript(({ origin, token }) => {
      if (location.origin === origin) sessionStorage.setItem('osgard:core-session:v1', token)
    }, { origin: base.origin, token: process.env.OSGARD_REMIX_ACCEPTANCE_TOKEN })
  }
  const page = await context.newPage()
  page.setDefaultTimeout(timeout)
  const blockedRequestUrls = new Set()
  // A page can emit mutations during startup, before any explicit test action.
  // Never turn those into fabricated successful responses or let a loopback URL
  // bypass authorization for a separately running service.
  await context.route('**/*', async route => {
    const request = route.request()
    const readOnly = ['GET', 'HEAD', 'OPTIONS'].includes(request.method())
    const ownStaticServer = Boolean(local) && new URL(request.url()).origin === base.origin
    const approvedBaseOrigin = allowApiMutations && new URL(request.url()).origin === base.origin
    if (readOnly || approvedBaseOrigin || ownStaticServer) return route.continue()
    blockedRequestUrls.add(request.url())
    result.blockedRequests.push({ url: request.url(), method: request.method(), reason: 'API mutation is not authorized for this origin; --allow-api-mutations permits only the selected base origin' })
    result.integrations.push({ name: integrationFor(request.url()) || 'external-mutation', status: 'not-tested', url: request.url(), reason: 'Request blocked before transmission by acceptance policy' })
    await route.abort('blockedbyclient')
  })
  const url = new URL(route, base)
  url.searchParams.set('test', '1')
  result.url = url.href
  page.on('pageerror', error => result.pageErrors.push(errorMessage(error)))
  page.on('console', message => {
    const value = message.text().slice(0, 1000)
    if (game.id === 'null-shift' && route.includes('godot') && message.type() === 'log' && result.engineMessages.length < 100) result.engineMessages.push(value)
    if (message.type() === 'error') result.consoleErrors.push(value)
    else if (message.type() === 'warning') {
      result.consoleWarnings.push(value)
      // The Godot export shell forwards native stderr through console.warn.
      // A GDScript failure must still fail the browser gate.
      if (value.includes('[NULL SHIFT]') && /(?:SCRIPT ERROR:|ERROR:|Parse Error:)/.test(value)) result.consoleErrors.push(value)
    }
  })
  function failedResource(resource) {
    if (blockedRequestUrls.has(resource.url)) return
    const integration = integrationFor(resource.url)
    if (integration) {
      const { status: httpStatus, ...details } = resource
      result.integrations.push({ ...details, name: integration, status: 'unavailable', ...(httpStatus === undefined ? {} : { httpStatus }) })
    }
    else result.failedResources.push({ ...resource, required: new URL(resource.url).origin === base.origin })
  }
  page.on('response', response => { if (response.status() >= 400) failedResource({ url: response.url(), status: response.status(), type: response.request().resourceType() }) })
  page.on('requestfailed', request => {
    if (request.failure()?.errorText === 'net::ERR_ABORTED') return
    failedResource({ url: request.url(), error: request.failure()?.errorText, type: request.resourceType() })
  })
  try {
    const response = await page.goto(url.href, { waitUntil: 'domcontentloaded', timeout: timeout * 2 })
    result.httpStatus = response?.status()
    if (response?.status() !== 200) {
      if (game.id === 'null-shift' && variant === 'catalog' && route.includes('godot') && response?.status() === 404) throw new Blocked('Godot export is absent: primary catalog route returned HTTP 404')
      throw new Error('Game document returned HTTP ' + response?.status())
    }
    await page.locator('body').waitFor()
    const started = Date.now()
    await sleep(180)
    result.checks.push('Document loads in Chromium')
    if (/^zion-02[01]$/.test(game.id)) await zionPuzzle(page, result)
    else if (/^zion-02[2-9]$/.test(game.id)) await zionStory(page, result)
    else if (game.id === 'zion-030') await zionBoard(page, result)
    else await handlers[game.id](page, result)
    result.actionDurationMs = Date.now() - started
    result.status = 'passed'
  } catch (error) { result.status = error instanceof Blocked ? 'blocked' : 'failed'; result.reason = errorMessage(error) }
  try {
    result.layout = await page.evaluate(() => ({ viewport: { width: innerWidth, height: innerHeight }, visualScale: visualViewport?.scale,
      documentWidth: document.documentElement.scrollWidth, language: document.documentElement.lang,
      title: document.title, canvasCount: document.querySelectorAll('canvas').length }))
    result.layout.expectedViewport = profile
    if (result.layout.documentWidth > profile.width + 4) {
      result.layout.horizontalOverflow = true
      result.layout.warning = 'Document exceeds the requested viewport or forces mobile shrink-to-fit; inspect screenshot.'
    }
    const screenshot = `${game.id}-${device}${variant === 'catalog' ? '' : '-' + variant}.png`
    await page.screenshot({ path: resolve(out, screenshot), fullPage: true, animations: 'disabled', timeout })
    result.screenshots.push(screenshot)
    const viewportScreenshot = screenshot.replace('.png', '-viewport.png')
    await page.screenshot({ path: resolve(out, viewportScreenshot), fullPage: false, animations: 'disabled', timeout })
    result.screenshots.push(viewportScreenshot)
  } catch (error) { result.screenshotError = errorMessage(error) }
  result.criticalConsoleErrors = result.consoleErrors.filter(message => !message.startsWith('Failed to load resource:') && !message.includes('blocked by CORS policy'))
  if (result.pageErrors.length || result.criticalConsoleErrors.length || result.failedResources.some(resource => resource.required && resource.type !== 'document') || result.screenshotError) {
    result.status = 'failed'
    result.reason ||= 'Runtime exception, captured console error, required local resource failure or missing screenshot'
  }
  const service = { time: 'optional-platform-api', swarm: 'swarm-room-service', inherit: 'inherit-shared-world', remix: 'remix-match-service' }[game.id]
  if (service && !result.integrations.some(item => item.name === service)) result.integrations.push({ name: service, status: 'not-tested' })
  result.integrations = [...new Map(result.integrations.map(item => [item.url + ':' + item.status, item])).values()]
  result.failedResources = [...new Map(result.failedResources.map(item => [item.url + ':' + item.status + ':' + item.error, item])).values()]
  await writeFile(resolve(out, `${game.id}-${device}-${variant}.json`), JSON.stringify(result, null, 2) + '\n')
  results.push(result)
  console.log(`${result.status.toUpperCase()} ${game.id} ${device} ${variant}: ${result.reason || result.checks.join('; ')}`)
  await context.close()
}

let launchError
try {
  browser = await chromium.launch({ headless: true, args: ['--enable-unsafe-swiftshader'] })
  for (const game of catalog.filter(item => !selected.size || selected.has(item.id))) {
    for (const device of devices) {
      await runCase(game, device)
      if (game.id === 'null-shift' && game.href !== '/games/null-shift/' && game.alternate?.href === '/games/null-shift/') {
        await runCase(game, device, game.alternate.href, 'lightweight')
      }
    }
  }
} catch (error) { launchError = errorMessage(error); console.error(launchError) }
finally {
  if (browser) await browser.close()
  if (local) await new Promise(done => local.server.close(done))
}
const primary = results.filter(item => item.variant === 'catalog')
const report = { schemaVersion: 1, startedAt, completedAt: new Date().toISOString(), browser: 'Chromium', headless: true,
  engine: 'Playwright', localStaticServer: Boolean(local), sourceRoot: externalBase ? null : root, baseUrl: base.href,
  viewportProfiles: { desktop: '1440×1000, keyboard', mobile: '390×844, Chromium touch emulation' },
  methodology: 'Real document/resource loading and actual user inputs. Read-only state probes only; no API response mocks or state injection.',
  apiMutationPolicy: allowApiMutations ? 'Explicit --allow-api-mutations permits only the selected base origin; all other origins are blocked and recorded' : 'Only the runner-owned static server may receive non-read-only requests; all other origins are blocked and recorded',
  limitations: ['Mobile emulation is not a physical-device Safari/Android test.', 'Smoke acceptance is not a whole-game completion or performance audit.',
    'External APIs, accounts, live rooms, payments, AR and production publication are not certified by this runner.'],
  launchError, expectedCatalogEntries: selected.size || 19, primaryCases: primary.length,
  passed: results.filter(item => item.status === 'passed').length, failed: results.filter(item => item.status === 'failed').length,
  blocked: results.filter(item => item.status === 'blocked').length,
  expectedBlocked: [...expectedBlocked],
  primaryPassed: primary.filter(item => item.status === 'passed').length,
  primaryFailed: primary.filter(item => item.status === 'failed').length,
  primaryBlocked: primary.filter(item => item.status === 'blocked').length,
  totalAccepted: !launchError && primary.length === (selected.size || 19) * devices.length && results.every(item => item.status === 'passed'), results }
await writeFile(resolve(out, 'report.json'), JSON.stringify(report, null, 2) + '\n')
console.log(`REPORT ${resolve(out, 'report.json')}: ${report.passed} passed, ${report.failed} failed, ${report.blocked} blocked; totalAccepted=${report.totalAccepted}`)
if (launchError || report.failed || results.some(item => item.status === 'blocked' && !expectedBlocked.has(item.id))) process.exitCode = 1
