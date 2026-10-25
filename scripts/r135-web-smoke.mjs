// Actual R135 gameplay smoke in Chromium (SwiftShader WebGL2, not physical GPU).
// Checks Godot scene boot + ordered maintenance mission with desktop keys
// and real mobile touchscreen presses, not only existence of a blank canvas.
import { chromium, devices } from 'playwright'
import { mkdir, writeFile } from 'node:fs/promises'
import { createHash } from 'node:crypto'
import { captureAnimatedWebGLViewport } from './omega-browser-evidence.mjs'
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
async function captureRealViewport(page, filename) {
  const { png, method } = await captureAnimatedWebGLViewport(page)
  if (png.length < 9500 || png.subarray(0, 8).toString('hex') !== '89504e470d0a1a0a') {
    throw new Error('Real R135 screenshot is not a valid PNG: ' + filename)
  }
  const width = png.readUInt32BE(16)
  const height = png.readUInt32BE(20)
  if (width < 300 || height < 300) throw new Error('Real R135 screenshot too small: ' + filename)
  await writeFile(resolve(output, filename), png)
  if (filename === 'w6-portrait-optical-active.png') {
    // Chromium CDP captures CSS viewport pixels, while the Godot WebGL
    // render target is denser (devicePixelRatio). Record both unmodified
    // dimensions; never upscale or manufacture screenshot evidence.
    const geometry = await page.evaluate(() => {
      const canvas = document.querySelector('canvas')
      const qa = window.__OSGARD_R135_QA
      if (!(canvas instanceof HTMLCanvasElement) || !qa?.scene_ready) {
        throw new Error('Genuine Godot scene state/canvas unavailable for release evidence')
      }
      const rect = canvas.getBoundingClientRect()
      return {
        css_viewport: [window.innerWidth, window.innerHeight],
        device_pixel_ratio: window.devicePixelRatio,
        canvas_pixels: [canvas.width, canvas.height],
        canvas_css: [rect.width, rect.height],
        scene_ready: qa.scene_ready,
        view: qa.view,
        camera_target_visible: qa.camera_target_visible,
        fault_label_visible_count: qa.fault_label_visible_count,
        active_caption_depth_override: qa.active_caption_depth_override,
        loading_failures: qa.loading_failures,
      }
    })
    const evidence = {
      source: 'live Playwright Chromium WebGL Godot canvas and real unscaled PNG',
      capture_method: method,
      screenshot_pixels: [width, height],
      screenshot_sha256: createHash('sha256').update(png).digest('hex'),
      ...geometry,
    }
    await writeFile(resolve(output, 'r135-portrait-capture-proof.json'), JSON.stringify(evidence, null, 2) + '\n')
  }
  console.log('R135 screenshot evidence:', filename, method, width + 'x' + height)
}

async function keyboardDiagnostics(page) {
  await page.keyboard.press('c')
  await expectState(page, x => x?.challenge_active && x?.challenge_step === 0
    && x?.fault_marker_count === 3 && x?.fault_marker_active_index === 0
    && x?.fault_marker_visible_count === 3 && x?.fault_label_visible_count === 1
    && x?.fault_visual_state === 'active'
    && x?.active_caption_depth_override,
    
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
  await captureRealViewport(page, 'w6-desktop-optical-active.png')
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
    && x?.camera_keep_width && x?.camera_fov >= 56 && x?.camera_fov <= 58
    && x?.camera_target_screen_x > .35 && x?.camera_target_screen_x < .70
    && x?.fault_label_visible_count === 1
    && x?.camera_target_screen_y > .24 && x?.camera_target_screen_y < .73
    && x?.machine_top_screen_y > .12 && x?.machine_top_screen_y < .37,
    'W6.1 portrait optics and physical upper rail must fit useful scene area')
  await captureRealViewport(page, 'w6-portrait-optical-active.png')
  await tapSceneButton(page, 3) // SCAN TARGET
  await expectState(page, x => x?.challenge_step === 3 && x?.fault_visual_state === 'inspected',
    'W5 touch scan did not clear fault light')
  await tapSceneButton(page, 6) // Close hatch
  await expectState(page, x => x?.challenge_step === 4, 'Touch challenge hatch close failed')
  await expectState(page, x => x?.lid_progress <= .05, 'Touch hatch did not close', 35_000)
  await tapSceneButton(page, 5) // Restart drive
  await expectState(page, x => x?.challenge_completed && x?.challenge_score > 0 &&
    x?.challenge_best_score > 0 && x?.motion_enabled
    && x?.fault_visual_state === 'cleared'
    && x?.cleared_case_count >= 1
    && String(x?.challenge_evidence || '').includes('(SIM)'),
    'Touch W9 simulated case did not record the learning result')
}

// W12: prove that every distinct fault is playable through the real Godot
// controls on BOTH Chromium desktop and emulated touch. Native Godot alone
// cannot catch an unreachable camera button or an incorrectly wired UI.
async function browserRemainingFaults(page, isMobile, deviceName) {
  const cases = []
  const press = async (key, button) => {
    if (isMobile) await tapSceneButton(page, button)
    else await page.keyboard.press(key)
  }
  for (const [index, targetView, faultName] of [
    [1, 3, 'COOLING AIRFLOW'],
    [2, 1, 'SERVICE INTERLOCK'],
  ]) {
    await press('c', 1)
    await expectState(page, state =>
      state?.challenge_active && state?.challenge_step === 0
      && state?.challenge_fault_index === index
      && state?.challenge_fault === faultName
      && state?.challenge_target_view === targetView
      && state?.fault_marker_active_index === index
      && state?.fault_marker_visible_count === 3
      && state?.fault_label_visible_count === 1
      && state?.active_caption_depth_override === true
      && state?.fault_visual_state === 'active'
      && String(state?.challenge_evidence || '').includes('(SIM)'),
      'W12 ' + deviceName + ' scenario not visibly active: ' + faultName)
    // A running machine may not open the hatch. The unsafe action must
    // increment the penalty without skipping a checkpoint.
    await press('f', 6)
    await expectState(page, state => state?.challenge_step === 0
      && state?.challenge_errors === 1 && state?.lid_target === 0
      && state?.motion_enabled === true,
      'W12 unsafe hatch was not rejected for ' + faultName)
    await press('Space', 5)
    await expectState(page, state => state?.challenge_step === 1
      && state?.motion_enabled === false,
      'W12 drive could not stop for ' + faultName)
    await press('f', 6)
    await expectState(page, state => state?.challenge_step === 2
      && state?.lid_target === 1,
      'W12 hatch could not open for ' + faultName)
    await expectState(page, state => state?.lid_progress >= .95,
      'W12 real hatch interpolation never fully opened for ' + faultName, 35_000)
    await press('r', 7)
    await expectState(page, state => state?.view === 0,
      'W12 RESET VIEW did not use the real overview camera')
    await press('e', 3)
    await expectState(page, state => state?.challenge_step === 2
      && state?.challenge_errors === 2 && state?.fault_visual_state === 'active',
      'W12 wrong-view scan was incorrectly accepted for ' + faultName)
    for (let view = 1; view <= targetView; view++) {
      await press('v', 2)
      await expectState(page, state => state?.view === view,
        'W12 actual camera button failed at view ' + view)
    }
    await expectState(page, state => state?.challenge_target_view === targetView
      && state?.fault_label_visible_count === 1
      && state?.fault_marker_active_index === index
      && state?.active_fault_caption_on_screen === true
      && state?.active_fault_caption_screen_x >= .10
      && state?.active_fault_caption_screen_x <= .90
      && state?.active_fault_caption_screen_y >= .10
      && state?.active_fault_caption_screen_y <= .85,
      'W12 world-space caption is missing or outside real camera view: ' + faultName)
    await captureRealViewport(page, 'w12-' + deviceName + '-fault-' + (index + 1) + '-active.png')
    await press('e', 3)
    await expectState(page, state => state?.challenge_step === 3
      && state?.fault_visual_state === 'inspected',
      'W12 correct simulated scan did not inspect ' + faultName)
    await press('f', 6)
    await expectState(page, state => state?.challenge_step === 4
      && state?.lid_target === 0,
      'W12 hatch did not start closing for ' + faultName)
    await press('Space', 5)
    await expectState(page, state => state?.challenge_step === 4
      && state?.motion_enabled === false && state?.challenge_errors === 3,
      'W12 drive bypassed closing-hatch interlock for ' + faultName)
    await expectState(page, state => state?.lid_progress <= .05,
      'W12 hatch did not seal for ' + faultName, 35_000)
    await press('Space', 5)
    const done = await expectState(page, state => state?.challenge_completed
      && state?.challenge_step === 5 && state?.motion_enabled === true
      && state?.fault_visual_state === 'cleared'
      && state?.fault_marker_active_index === index
      && state?.cleared_case_count === index + 1
      && typeof state?.challenge_score === 'number'
      && state?.challenge_score >= 0 && state?.challenge_score <= 150,
      'W12 successful diagnostic did not persist ' + faultName)
    cases.push({
      index, fault: faultName, targetView,
      errors: done.challenge_errors, score: done.challenge_score,
      elapsed: done.challenge_elapsed, cleared: done.cleared_case_count,
      result: 'PASS', simulated_only: true,
    })
  }
  if (cases.length !== 2) throw new Error('W12 must clear both additional cases')
  const report = {
    device: deviceName,
    software_browser_renderer: 'SwiftShader WebGL2; not physical phone GPU',
    first_case: 'OPTICAL ALIGNMENT: already passed original smoke',
    new_cases: cases,
    result: 'three distinct cases cleared in same Godot browser session',
  }
  await writeFile(resolve(output, 'w12-' + deviceName + '-three-case-evidence.json'),
    JSON.stringify(report, null, 2) + '\n')
  return cases
}

async function verifyAdaptiveHud(page) {
  const original = page.viewportSize()
  for (const [width, height, mode] of [
    [360, 780, 'portrait'],
    [430, 932, 'portrait'],
    [932, 430, 'landscape'],
  ]) {
    await page.setViewportSize({ width, height })
    const state = await expectState(page, x => x?.scene_ready && x?.hud_layout_mode === mode
      && Math.abs(x.viewport_w / x.viewport_h - width / height) < .012
      && x?.button_centers?.length === 8 && x?.hud_rect && x?.action_rect,
      'W8 Godot responsive layout update missing for ' + width + 'x' + height, 25_000)
    const visible = rect => rect.x >= 0 && rect.y >= 0 && rect.w > 0 && rect.h > 0
      && rect.x + rect.w <= state.viewport_w + 4
      && rect.y + rect.h <= state.viewport_h + 4
    if (!visible(state.hud_rect) || !visible(state.action_rect)) {
      throw new Error('W8 HUD escaped safe viewport ' + width + 'x' + height +
        ' : ' + JSON.stringify({ viewport: [state.viewport_w, state.viewport_h], hud: state.hud_rect, actions: state.action_rect }))
    }
    if (state.hud_rect.y + state.hud_rect.h >= state.action_rect.y - 6) {
      throw new Error('W8 status panel overlaps touch controls at ' + width + 'x' + height)
    }
    for (const position of state.button_centers) {
      if (position.x < state.action_rect.x || position.x > state.action_rect.x + state.action_rect.w
        || position.y < state.action_rect.y || position.y > state.action_rect.y + state.action_rect.h) {
        throw new Error('W8 button center outside control panel: ' + width + 'x' + height)
      }
    }
    await captureRealViewport(page, 'w8-hud-' + width + 'x' + height + '.png')
  }
  if (original) {
    await page.setViewportSize(original)
    await expectState(page, x => x?.scene_ready && x?.hud_layout_mode === 'portrait',
      'W8 failed to restore original mobile viewport', 25_000)
  }
}

let failed = false
try {
  for (const [name, opts, isMobile] of [
    ['desktop-1366', { viewport: { width: 1366, height: 768 }, deviceScaleFactor: 1, reducedMotion: 'no-preference' }, false],
    ['mobile-390', { ...devices['Pixel 7'], reducedMotion: 'reduce' }, true],
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
          && x?.fault_marker_visible_count === 0 && x?.fault_label_visible_count === 0
          && x?.studio_grid_draw_batches === 2 && x?.studio_grid_instances === 18
          && x?.studio_mesh_nodes <= 8 && x?.prefers_reduced_motion === isMobile
          && x?.inspection_fill_energy >= 3.5
          && x?.inspection_fill_shadow_enabled === false
          && x?.inspection_fill_range >= 12.0,
        'Real W5 Godot ECO rig, 3D markers and controls did not load', 90_000)
      if (boot.quality !== 0 || boot.studio_quality !== 0) throw new Error('Low-memory ECO mode not used on boot')
      if (!boot.hud_rect || !boot.action_rect || boot.hud_rect.h > boot.viewport_h * .28 ||
          boot.hud_rect.y + boot.hud_rect.h >= boot.action_rect.y - 20) {
        throw new Error('W11 initial HUD obscures scene: ' + JSON.stringify({
          viewport: [boot.viewport_w, boot.viewport_h], hud: boot.hud_rect, actions: boot.action_rect
        }))
      }
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
        const extraCases = await browserRemainingFaults(page, true, name)
        if (extraCases.length !== 2) throw new Error('Missing two mobile diagnostic cases')
        await verifyAdaptiveHud(page)
      } else {
        await keyboardMission(page)
        await keyboardDiagnostics(page)
        const extraCases = await browserRemainingFaults(page, false, name)
        if (extraCases.length !== 2) throw new Error('Missing two desktop diagnostic cases')
        await page.keyboard.press('q')
        await expectState(page, x => x?.quality === 2
          && x?.loaded?.endsWith('service_spine_hero.glb') && x?.studio_quality === 2
          && x?.loading_failures === 0,
          'Desktop HERO model switch failed', 45_000)
        await page.keyboard.press('q')
        await expectState(page, x => x?.quality === 0
          && x?.loaded?.endsWith('service_spine_eco.glb') && x?.studio_quality === 0
          && x?.loading_failures === 0,
          'Desktop ECO return failed', 45_000)
      }
      if (runtimeErrors.length || assetErrors.length) {
        throw new Error('Browser runtime errors: ' + JSON.stringify({ runtimeErrors, assetErrors }))
      }
      await captureRealViewport(page, name + '.png')
      const final = await readState(page)
      if (final.cleared_case_count !== 3) throw new Error('W12 only ' + final.cleared_case_count + ' diagnostic cases cleared')
      result.push({ device: name, status: 'PASS', verified: 'real mechanics and interaction',
        mission: final.mission_completed, challenge: final.challenge_completed,
        challengeScore: final.challenge_score, caseCount: final.cleared_case_count,
        diagnosticMatrix: 'optical, airflow, interlock', view: final.view, quality: final.quality,
        canvas: geometry,
        stageGridDrawBatches: final.studio_grid_draw_batches,
        stageGridInstances: final.studio_grid_instances,
        prefersReducedMotion: final.prefers_reduced_motion,
        softwareRendererFpsSample: final.render_fps_sample })
      console.log('R135 gameplay PASS:', name, JSON.stringify(result.at(-1)))
    } catch (error) {
      failed = true
      console.error('R135 gameplay FAIL:', name, String(error))
      try { await captureRealViewport(page, name + '-failure.png') } catch {}
    } finally {
      await context.close()
    }
  }
} finally {
  await browser.close()
}
console.log(JSON.stringify({ game: 'OSGARD R135', tests: result, failed }))
if (failed) process.exitCode = 1
