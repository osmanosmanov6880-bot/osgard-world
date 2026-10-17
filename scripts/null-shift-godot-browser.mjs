import assert from 'node:assert/strict'

const sleep = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds))
const distance = (a, b) => Math.hypot(a.x - b.x, a.z - b.z)
const hitPoints = state => state.guards.reduce((sum, guard) => sum + guard.hp, 0)
const labels = {
  'briefing-start': 'НАЧАТЬ РЕЙД', 'move-right': '→', fire: 'ОГОНЬ', pulse: 'ИМПУЛЬС',
  shift: 'СДВИГ', dash: 'РЫВОК', pause: 'ПАУЗА', resume: 'ПРОДОЛЖИТЬ', restart: 'ПЕРЕЗАПУСТИТЬ РЕЙД',
  modules: 'МОДУЛИ', 'close-modules': 'ЗАКРЫТЬ / U',
}

/** A real exported-engine scenario. The bridge supplies observations only. */
export async function acceptGodotNullShift(page, result, { timeout = 12000, screenshot } = {}) {
  const mobile = result.device === 'mobile'
  const read = () => page.evaluate(() => window.__NULL_SHIFT_GODOT_TEST__?.state() || null)
  const until = async (description, predicate, limit = timeout) => {
    const deadline = Date.now() + limit
    let state
    do {
      state = await read()
      if (state && predicate(state)) return state
      await sleep(45)
    } while (Date.now() < deadline)
    throw new Error(`Godot ${description}; last state: ${JSON.stringify(state && {
      instanceId: state.instanceId, player: state.player, paused: state.paused, briefing: state.briefing,
      finished: state.finished, guards: state.guards, pulseCooldown: state.pulseCooldown,
      dashCooldown: state.dashCooldown, nullShift: state.nullShift,
    })}`)
  }
  const record = (action, state) => {
    result.godot.checkpoints.push({ action, instanceId: state.instanceId, processFrames: state.processFrames,
      physicsFrames: state.physicsFrames, player: state.player, paused: state.paused, briefing: state.briefing,
      phaseClock: state.phaseClock, elapsed: state.elapsed, pulseCooldown: state.pulseCooldown,
      dashCooldown: state.dashCooldown, nullShift: state.nullShift, instability: state.instability,
      eliminations: state.eliminations, guardHitPoints: hitPoints(state), runCredits: state.runCredits })
  }
  const findControl = (state, id, requireEnabled = true) => {
    const candidates = state.controls.filter(control => control.visible && (control.id === id ||
      (labels[id] && (['move-right', 'fire', 'pulse', 'shift', 'pause', 'resume', 'restart'].includes(id)
        ? control.label === labels[id] : control.label.startsWith(labels[id])))))
    assert.equal(candidates.length, 1, `Godot must expose one visible ${id} control; got ${candidates.length}`)
    if (requireEnabled) assert.ok(candidates[0].enabled, `Godot ${id} is disabled`)
    return candidates[0]
  }
  const pointFor = async (control, state) => {
    const box = await page.locator('#canvas').boundingBox()
    assert.ok(box, 'Godot canvas must have a browser rectangle')
    const { rect, clip } = control
    const center = { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 }
    assert.ok(center.x >= clip.x && center.y >= clip.y && center.x < clip.x + clip.width && center.y < clip.y + clip.height,
      `Godot ${control.label} is clipped or outside its visible panel`)
    const size = { width: rect.width * box.width / state.viewport.width, height: rect.height * box.height / state.viewport.height }
    if (mobile) assert.ok(size.width >= 44 && size.height >= 44,
      `Godot ${control.label} touch target is too small in CSS pixels: ${size.width.toFixed(1)}×${size.height.toFixed(1)}`)
    return { x: box.x + center.x * box.width / state.viewport.width, y: box.y + center.y * box.height / state.viewport.height, size }
  }
  const tapControl = async id => {
    const state = await read()
    const control = findControl(state, id)
    const point = await pointFor(control, state)
    if (mobile) await page.touchscreen.tap(point.x, point.y)
    else await page.mouse.click(point.x, point.y)
    return point
  }
  const holdControl = async (id, milliseconds) => {
    const state = await read()
    const point = await pointFor(findControl(state, id), state)
    const session = await page.context().newCDPSession(page)
    try {
      await session.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: point.x, y: point.y, id: 0 }] })
      await sleep(milliseconds)
    } finally {
      await session.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] })
      await session.detach()
    }
  }
  const moveRightUntil = async (description, predicate) => {
    if (!mobile) {
      await page.keyboard.down('d')
      try { return await until(description, predicate) }
      finally { await page.keyboard.up('d') }
    }
    const state = await read()
    const point = await pointFor(findControl(state, 'move-right'), state)
    const session = await page.context().newCDPSession(page)
    try {
      await session.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: point.x, y: point.y, id: 0 }] })
      return await until(description, predicate)
    } finally {
      await session.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] })
      await session.detach()
    }
  }
  const swipeBriefing = async () => {
    const state = await read()
    const panel = state.panels.briefing_panel.rect
    const box = await page.locator('#canvas').boundingBox()
    const x = box.x + (panel.x + panel.width * .55) * box.width / state.viewport.width
    const start = box.y + (panel.y + panel.height * .8) * box.height / state.viewport.height
    const end = box.y + (panel.y + panel.height * .25) * box.height / state.viewport.height
    const session = await page.context().newCDPSession(page)
    try {
      await session.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y: start, id: 0 }] })
      for (let step = 1; step <= 7; step++) {
        await session.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x, y: start + (end - start) * step / 7, id: 0 }] })
        await sleep(25)
      }
    } finally {
      await session.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] })
      await session.detach()
    }
    await sleep(120)
  }

  result.godot = { checkpoints: [] }
  assert.equal(await page.locator('html').getAttribute('data-nullshift-shell'), 'premium-v1', 'Expected the real Godot export shell')
  const launch = page.locator('#launch')
  await launch.waitFor({ state: 'visible' })
  assert.ok(await launch.isEnabled(), 'Godot launcher requires WebGL 2')
  const launchStarted = Date.now()
  if (mobile) await launch.tap()
  else { await launch.focus(); await launch.press('Enter') }
  await page.locator('html.is-started').waitFor({ timeout: Math.max(timeout, 60000) })
  result.godot.engineBootMs = Date.now() - launchStarted
  const boot = await until('must publish its opt-in native state after engine startup', () => true)
  assert.equal(boot.schemaVersion, 1)
  assert.equal(boot.platform, 'Web')
  assert.ok(boot.engineVersion.startsWith('4.7.2'), `Expected pinned Godot 4.7.2, got ${boot.engineVersion}`)
  assert.equal(boot.renderer, 'gl_compatibility')
  assert.ok(await page.evaluate(() => Object.isFrozen(window.__NULL_SHIFT_GODOT_TEST__) && Object.isFrozen(window.__NULL_SHIFT_GODOT_TEST__.state().player)), 'Native browser observations must be immutable')
  const rendering = await until('must render native scene frames, not only instantiate a canvas', state => state.processFrames >= boot.processFrames + 2 && state.drawCalls > 0 && state.renderedObjects > 0)
  const canvasBox = await page.locator('#canvas').boundingBox()
  assert.ok(canvasBox && Math.abs(rendering.viewport.width - canvasBox.width) <= 1 && Math.abs(rendering.viewport.height - canvasBox.height) <= 1,
    `Godot must lay out controls in actual CSS pixels; logical ${JSON.stringify(rendering.viewport)}, canvas ${JSON.stringify(canvasBox)}`)
  result.renderer = { engine: 'Godot WASM', version: rendering.engineVersion, method: rendering.renderer,
    drawCalls: rendering.drawCalls, renderedObjects: rendering.renderedObjects, processFrames: rendering.processFrames }
  result.godot.initial = rendering
  result.godot.modalBounds = Object.fromEntries(Object.entries(rendering.panels).map(([name, panel]) => [name, panel.rect]))
  for (const [name, panel] of Object.entries(rendering.panels)) {
    assert.ok(panel.rect.x >= -1 && panel.rect.width <= rendering.viewport.width + 1,
      `Godot ${name} must fit the actual viewport: ${JSON.stringify(panel.rect)}`)
  }
  if (mobile) {
    result.godot.touchTargets = []
    for (const id of ['move-up', 'move-down', 'move-left', 'move-right', 'fire', 'use', 'pulse', 'shift', 'dash', 'pause']) {
      const control = findControl(rendering, id, false)
      const point = await pointFor(control, rendering)
      result.godot.touchTargets.push({ id, label: control.label, ...point.size })
    }
  }
  record('engine-started', rendering)
  result.checks.push('Official Godot WASM engine starts; native scene draws objects across multiple frames; bridge is read-only')

  assert.ok(rendering.briefing && rendering.paused, 'Fresh profile must show a briefing and pause gameplay')
  if (mobile) {
    assert.ok(rendering.touchAvailable && rendering.mobileControlsVisible, 'Phone must expose native touch controls')
    for (let attempt = 0; attempt < 5; attempt++) {
      const state = await read()
      const control = findControl(state, 'briefing-start')
      const centerY = control.rect.y + control.rect.height / 2
      if (centerY < control.clip.y + control.clip.height) break
      await swipeBriefing()
    }
    await tapControl('briefing-start')
  } else {
    await page.locator('#canvas').focus()
    await page.keyboard.press('Enter')
  }
  const started = await until('briefing must dismiss through user input', state => !state.briefing && !state.paused)
  record('briefing-dismissed', started)
  result.checks.push('First-run briefing is dismissed with keyboard/touch and starts native gameplay')

  const moved = await moveRightUntil('movement must reach a clear firing lane through native CharacterBody3D motion',
    state => state.player.position.x >= -13.5)
  assert.ok(moved.player.position.x > started.player.position.x + .5, 'Movement did not change the native player position')
  record('player-moved', moved)
  result.checks.push('WASD/touch movement changes the native player position')

  const combatBefore = await read()
  if (mobile) await holdControl('fire', 650)
  else {
    const target = combatBefore.guards.filter(guard => guard.clearPath && !guard.screen.behind).sort((a, b) => a.distance - b.distance)[0]
    assert.ok(target, 'A guard in the scene must provide a real, unobstructed combat target')
    const box = await page.locator('#canvas').boundingBox()
    await page.mouse.move(box.x + target.screen.x * box.width / combatBefore.viewport.width,
      box.y + target.screen.y * box.height / combatBefore.viewport.height)
    await page.mouse.down()
    try { await sleep(650) } finally { await page.mouse.up() }
  }
  const shot = await until('real weapon input must reduce hostile health or eliminate a guard', state => hitPoints(state) < hitPoints(combatBefore))
  record('hostile-damaged-by-weapon', shot)
  result.checks.push('Mouse/touch fire hits a real physics target and reduces hostile health')

  if (mobile) await tapControl('pulse')
  else await page.keyboard.press('q')
  const pulse = await until('pulse input must enter its actual cooldown', state => state.pulseCooldown > 0)
  record('pulse-used', pulse)
  const instabilityBefore = pulse.instability
  if (mobile) await tapControl('shift')
  else await page.keyboard.press('Shift')
  const shifted = await until('NULL Shift must activate and increase instability', state => state.nullShift > 0 && state.instability > instabilityBefore)
  record('null-shift-used', shifted)
  if (mobile) await tapControl('dash')
  else await page.keyboard.press('Space')
  const dashed = await until('dash must move the native body and enter cooldown', state => state.dashCooldown > 0 && distance(state.player.position, shifted.player.position) > .2)
  record('dash-used', dashed)
  result.checks.push('Pulse cooldown, NULL Shift instability and dash displacement respond to real controls')
  if (screenshot) await screenshot('godot-combat')

  if (mobile) await tapControl('pause')
  else await page.keyboard.press('Escape')
  const paused = await until('pause control must suspend the raid', state => state.paused && state.panels.pause_panel.visible)
  if (!mobile) await page.keyboard.down('d')
  try { await sleep(260) } finally { if (!mobile) await page.keyboard.up('d') }
  const stillPaused = await read()
  assert.equal(stillPaused.paused, true)
  assert.ok(distance(stillPaused.player.position, paused.player.position) < .001, 'Paused native body kept moving')
  assert.equal(stillPaused.phaseClock, paused.phaseClock, 'Paused hazards kept advancing')
  assert.equal(stillPaused.elapsed, paused.elapsed, 'Paused raid timer kept advancing')
  assert.equal(stillPaused.player.health, paused.player.health, 'Paused enemies kept dealing damage')
  assert.equal(stillPaused.pulseCooldown, paused.pulseCooldown, 'Paused ability cooldown kept advancing')
  record('paused-and-stable', stillPaused)
  if (mobile) await tapControl('resume')
  else {
    assert.ok(findControl(stillPaused, 'resume').focused, 'Pause menu must focus the keyboard-resume control')
    await page.keyboard.press('Enter')
  }
  await until('resume must return to gameplay', state => !state.paused)
  result.checks.push('Pause freezes movement, hazards, damage and cooldowns; resume works through keyboard/touch')

  if (mobile) await tapControl('pause')
  else await page.keyboard.press('Escape')
  await until('second pause must expose restart', state => state.paused)
  const previousInstance = (await read()).instanceId
  if (mobile) await tapControl('restart')
  else {
    await page.keyboard.press('Tab')
    const state = await read()
    assert.ok(findControl(state, 'restart').focused, 'Tab must reach restart without mouse assistance')
    await page.keyboard.press('Enter')
  }
  const reset = await until('restart must load a new native scene instance', state => state.instanceId !== previousInstance && !state.paused)
  assert.ok(distance(reset.player.position, started.player.position) < .1, 'Restart did not restore the initial player position')
  assert.equal(reset.player.health, reset.player.maxHealth)
  assert.equal(reset.runCredits, 0)
  assert.equal(reset.instability, 0)
  assert.equal(reset.dashCooldown, 0)
  assert.equal(reset.guards.length, started.guards.length)
  assert.equal(reset.terminalUnlocked, false)
  assert.equal(reset.coreSecured, false)
  assert.equal(reset.finished, false)
  record('raid-restarted', reset)
  result.checks.push('Native restart creates a fresh raid, restores health/position and clears combat progress')
  if (mobile) await tapControl('modules')
  else await page.keyboard.press('u')
  const loadout = await until('career modules must open from the actual control', state => state.panels.loadout_panel.visible)
  assert.ok(loadout.panels.loadout_panel.rect.x >= 0 && loadout.panels.loadout_panel.rect.width <= loadout.viewport.width,
    'Open career modules overflow the viewport')
  if (mobile) await tapControl('close-modules')
  else await page.keyboard.press('u')
  await until('career modules must close from the actual control', state => !state.panels.loadout_panel.visible)
  result.checks.push('Native modal bounds fit the viewport and career modules open/close with real keyboard/touch controls')
  result.scope = 'Real Godot 4.7.2 WebAssembly raid: boot, rendering, briefing, movement, target damage, abilities, pause/resume and scene restart; no injected state or claimed full-mission victory'
}
