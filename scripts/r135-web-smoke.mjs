// Actual R135 gameplay smoke in Chromium (SwiftShader WebGL2, not physical GPU).
// Checks Godot scene boot + ordered maintenance mission with desktop keys
// and real mobile touchscreen presses, not only existence of a blank canvas.
import { chromium, devices } from 'playwright'
import { mkdir } from 'node:fs/promises'
import { resolve } from 'node:path'
import process from 'node:process'

const target = process.argv[2] || 'http://127.0.0.1:8765/index.html'
const output = resolve(process.argv[3] || '/tmp/r135-browser-screens')
await mkdir(output, { recursive: true })

const browser = await chromium.launch({
  headless: true,
  args: ['--use-gl=angle', '--use-angle=swiftshader',
    '--enable-webgl', '--disable-gpu-sandbox', '--no-sandbox'],
})
const result = []

const sleep = (page, ms) => page.waitForTimeout(ms)
async function readState(page) {
  return page.evaluate(() => window.__OSGARD_R135_QA || null)
}
async function expectState(page, predicate, label, timeout = 18_000) {
  const started = Date.now()
  let state = null
  while (Date.now() - started < timeout) {
    state = await readState(page)
    if (predicate(state)) return state
    await sleep(page, 300)
  }
  throw new Error(label + '; last scene state: ' + JSON.stringify(state))
}
async function tapSceneButton(page, index) {
  const state = await expectState(page,
    x => x?.button_centers?.length === 8 && x.viewport_w > 0 && x.viewport_h > 0,
    'Eight rendered mobile Godot controls are required')
  const point = state.button_centers[index]
  const rect = await page.locator('canvas').first().boundingBox()
  if (!point || !rect) throw new Error('Godot button geometry missing: ' + index)
  const x = rect.x + point.x * rect.width / state.viewport_w
  const y = rect.y + point.y * rect.height / state.viewport_h
  if (x < rect.x || x > rect.x + rect.width || y < rect.y || y > rect.y + rect.height) {
    throw new Error('Button outside touchscreen viewport: ' + index + ', ' + JSON.stringify({ x, y, rect }))
  }
  await page.touchscreen.tap(x, y)
}
async function keyboardMission(page) {
  await page.locator('canvas').first().click({ position: { x: 400, y: 350 } })
  await page.keyboard.press('m')
  await expectState(page, x => x?.mission_active && x?.mission_step === 0, 'M must start mission')
  await page.keyboard.press('Space') // Deliberately incorrect action.
  await expectState(page, x => x?.mission_step === 0 && x?.motion_enabled === false, 'Wrong order must not advance')
  await page.keyboard.press('Space')
  await page.keyboard.press('f')
  await expectState(page, x => x?.mission_step === 1, 'Hatch should advance to task 2')
  await page.keyboard.press('Space')
  await expectState(page, x => x?.mission_step === 2, 'Pause should advance to task 3')
  await page.keyboard.press('f')
  await expectState(page, x => x?.mission_step === 3, 'Hatch close should advance to task 4')
  await page.keyboard.press('Space')
  await expectState(page, x => x?.mission_completed && x?.mission_step === 4
    && x?.motion_enabled && !x?.mission_active, 'Resume must complete playable mission')
  await page.keyboard.press('v')
  await expectState(page, x => x?.view === 1, 'V must select close-up inspection camera')
  await page.keyboard.press('r')
  await expectState(page, x => x?.view === 0, 'R must reset the camera')
}
async function touchMission(page) {
  await tapSceneButton(page, 0)  // START MISSION
  await expectState(page, x => x?.mission_active && x?.mission_step === 0, 'Mobile START tap failed')
  await tapSceneButton(page, 6)  // OPEN HATCH
  await expectState(page, x => x?.mission_step === 1, 'Mobile OPEN HATCH tap failed')
  await tapSceneButton(page, 5)  // PLAY/PAUSE
  await expectState(page, x => x?.mission_step === 2, 'Mobile PAUSE tap failed')
  await tapSceneButton(page, 6)  // CLOSE HATCH
  await expectState(page, x => x?.mission_step === 3, 'Mobile CLOSE HATCH tap failed')
  await tapSceneButton(page, 5)  // RESUME
  await expectState(page, x => x?.mission_completed && x?.mission_step === 4, 'Mobile MISSION completion failed')
  await tapSceneButton(page, 2)  // NEXT VIEW
  await expectState(page, x => x?.view === 1, 'Mobile camera preset tap failed')
  await tapSceneButton(page, 7)  // RESET VIEW
  await expectState(page, x => x?.view === 0, 'Mobile camera reset tap failed')
}
// Each scenario must be solved through actual controls, including the
// closing/opening hatch physics and a visible camera-based diagnostic target.
async function keyboardDiagnostics(page) {
  await page.keyboard.press('c')
  await expectState(page, x => x?.challenge_active && x?.challenge_step === 0
    && x?.fault_marker_count === 3 && x?.fault_marker_active_index === 0
    && x?.fault_marker_visible_count === 3 && x?.fault_visual_state === 'active',
    'W5 optical fault must appear in the 3D scene')
  await page.keyboard.press('f') // Safety violation, should be refused.
  await expectState(page, x => x?.challenge_step === 0 && x?.challenge_errors === 1 && x?.lid_target === 0,
    'Running machine must refuse hatch access')
  await page.keyboard.press('Space')
  await expectState(page, x => x?.challenge_step === 1 && !x?.motion_enabled, 'Diagnostic stop missed')
  await page.keyboard.press('f')
  await expectState(page, x => x?.challenge_step === 2 && x?.lid_target === 1, 'Diagnostic hatch opening missed')
  await expectState(page, x => x?.lid_progress >= .95, 'Hatch never opened completely', 35_000)
  await page.keyboard.press('v')
  await page.keyboard.press('e') // Wrong camera angle must not pass.
  await expectState(page, x => x?.challenge_step === 2 && x?.challenge_errors >= 2,
    'Wrong inspection camera was accepted')
  await page.keyboard.press('v')
  await expectState(page, x => x?.view === x?.challenge_target_view, 'Correct optical view not selected')
  await expectState(page, x => x?.camera_target_visible
    && !x?.camera_keep_width
    && x?.camera_target_screen_x > .25 && x?.camera_target_screen_x < .75
    && x?.camera_target_screen_y > .22 && x?.camera_target_screen_y < .78,
    'W6 desktop optical head must remain inside central 50% of viewport')
  await page.screenshot({ path: resolve(output, 'w6-desktop-optical-active.png'), fullPage: true })
  await page.keyboard.press('e')
  await expectState(page, x => x?.challenge_step === 3 && x?.fault_visual_state === 'inspected',
    'W5 optical scan must turn the in-world indicator green')
  await page.keyboard.press('f')
  await expectState(page, x => x?.challenge_step === 4 && x?.lid_target === 0, 'Diagnostic close missed')
  await page.keyboard.press('Space') // Premature restart must stay blocked.
  await expectState(page, x => !x?.motion_enabled && x?.challenge_step === 4 && x?.challenge_errors >= 3,
    'Unsafe restart was not blocked')
  await expectState(page, x => x?.lid_progress <= .05, 'Hatch never sealed', 35_000)
  await page.keyboard.press('Space')
  await expectState(page, x => x?.challenge_completed && x?.challenge_step === 5
    && x?.challenge_score > 0 && x?.challenge_best_score > 0 && x?.motion_enabled,
    'Advanced diagnosis did not complete and score')
  await expectState(page, x => x?.fault_visual_state === 'cleared'
    && x?.fault_marker_visible_count === 3, 'Completed W5 fault must be visible as cleared')
}
async function touchDiagnostics(page) {
  await tapSceneButton(page, 1) // DIAGNOSTICS, real Godot button
  await expectState(page, x => x?.challenge_active && x?.challenge_step === 0
    && x?.fault_marker_count === 3 && x?.fault_marker_active_index === 0
    && x?.fault_marker_visible_count === 3,
    'W5 touch diagnostics start or 3D target failed')
  await tapSceneButton(page, 6) // Unsafe hatch press
  await expectState(page, x => x?.challenge_errors === 1 && x?.lid_target === 0,
    'Touch safety interlock bypassed')
  await tapSceneButton(page, 5) // Pause drive
  await expectState(page, x => x?.challenge_step === 1, 'Touch challenge pause missed')
  await tapSceneButton(page, 6) // Open hatch
  await expectState(page, x => x?.challenge_step === 2, 'Touch challenge hatch missed')
  await expectState(page, x => x?.lid_progress >= .95, 'Touch challenge hatch not open', 35_000)
  await tapSceneButton(page, 2) // Camera 1
  await tapSceneButton(page, 3) // Wrong scan target
  await expectState(page, x => x?.challenge_errors >= 2 && x?.challenge_step === 2,
    'Touch challenge wrongly accepted scan')
  await tapSceneButton(page, 2) // Camera 2, optical defect
  await expectState(page, x => x?.view === x?.challenge_target_view
    && x?.optical_tracking && x?.camera_effective_distance > x?.distance * 1.1,
    'W5 portrait optical tracking did not widen the camera')
  await expectState(page, x => x?.camera_target_visible
    && x?.camera_keep_width && x?.camera_fov >= 60
    && x?.camera_target_screen_x > .25 && x?.camera_target_screen_x < .75
    && x?.camera_target_screen_y > .24 && x?.camera_target_screen_y < .73,
    'W6 portrait optical head must remain in safe playable zone')
  await page.screenshot({ path: resolve(output, 'w6-portrait-optical-active.png'), fullPage: true })
  await tapSceneButton(page, 3) // SCAN TARGET
  await expectState(page, x => x?.challenge_step === 3 && x?.fault_visual_state === 'inspected',
    'W5 touch scan did not clear fault light')
  await tapSceneButton(page, 6) // Close hatch
  await expectState(page, x => x?.challenge_step === 4, 'Touch challenge hatch close failed')
  await expectState(page, x => x?.lid_progress <= .05, 'Touch hatch did not close', 35_000)
  await tapSceneButton(page, 5) // Restart drive
  await expectState(page, x => x?.challenge_completed && x?.challenge_score > 0 &&
    x?.challenge_best_score > 0 && x?.motion_enabled
    && x?.fault_visual_state === 'cleared', 'Touch W5 diagnostic did not complete')
}

let failed = false
try {
  for (const [name, opts, isMobile] of [
    ['desktop-1366', { viewport: { width: 1366, height: 768 }, deviceScaleFactor: 1 }, false],
    ['mobile-390', { ...devices['Pixel 7'] }, true],
  ]) {
    const context = await browser.newContext(opts)
    const page = await context.newPage()
    const runtimeErrors = []
    const assetErrors = []
    page.on('pageerror', err => runtimeErrors.push(String(err)))
    page.on('requestfailed', req => {
      if (/\.(?:pck|wasm|js)(?:\?|$)/i.test(req.url())) assetErrors.push(req.url())
    })
    try {
      console.log('R135 WebGL2 gameplay smoke:', name)
      const response = await page.goto(target, { waitUntil: 'domcontentloaded', timeout: 120_000 })
      if (response?.status() !== 200) throw new Error('Game HTML HTTP ' + response?.status())
      const available = await page.evaluate(() => Boolean(document.createElement('canvas').getContext('webgl2')))
      if (!available) throw new Error('No WebGL2 context')
      await page.locator('canvas').first().waitFor({ state: 'visible', timeout: 120_000 })
      const boot = await expectState(page,
        x => x?.scene_ready && x?.loading_failures === 0
          && x?.loaded?.endsWith('service_spine_eco.glb')
          && x?.button_centers?.length === 8 && x?.fault_marker_count === 3
          && x?.fault_marker_visible_count === 0,
        'Real W5 Godot ECO rig, 3D markers and controls did not load', 90_000)
      if (boot.quality !== 0) throw new Error('Low-memory ECO mode not used on boot')
      const geometry = await page.locator('canvas').first().evaluate(canvas => ({
        width: canvas.width, height: canvas.height,
        visible: canvas.getBoundingClientRect().width > 0,
      }))
      if (!geometry.visible || geometry.width < 128 || geometry.height < 128) {
        throw new Error('Godot canvas not usable ' + JSON.stringify(geometry))
      }
      if (isMobile) {
        await touchMission(page)
        await touchDiagnostics(page)
      } else {
        await keyboardMission(page)
        await keyboardDiagnostics(page)
        await page.keyboard.press('q')
        await expectState(page, x => x?.quality === 2
          && x?.loaded?.endsWith('service_spine_hero.glb') && x?.loading_failures === 0,
          'Desktop HERO model switch failed', 45_000)
        await page.keyboard.press('q')
        await expectState(page, x => x?.quality === 0
          && x?.loaded?.endsWith('service_spine_eco.glb') && x?.loading_failures === 0,
          'Desktop ECO return failed', 45_000)
      }
      if (runtimeErrors.length || assetErrors.length) {
        throw new Error('Browser runtime errors: ' + JSON.stringify({ runtimeErrors, assetErrors }))
      }
      await page.screenshot({ path: resolve(output, name + '.png'), fullPage: true })
      const final = await readState(page)
      result.push({ device: name, status: 'PASS', verified: 'real mechanics and interaction',
        mission: final.mission_completed, challenge: final.challenge_completed,
        challengeScore: final.challenge_score, view: final.view, quality: final.quality,
        canvas: geometry })
      console.log('R135 gameplay PASS:', name, JSON.stringify(result.at(-1)))
    } catch (error) {
      failed = true
      console.error('R135 gameplay FAIL:', name, String(error))
      try { await page.screenshot({ path: resolve(output, name + '-failure.png'), fullPage: true }) } catch {}
    } finally {
      await context.close()
    }
  }
} finally {
  await browser.close()
}
console.log(JSON.stringify({ game: 'OSGARD R135', tests: result, failed }))
if (failed) process.exitCode = 1
