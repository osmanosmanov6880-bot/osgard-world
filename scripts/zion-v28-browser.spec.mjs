import { test, expect } from '@playwright/test'

async function enterStreetMode(page) {
  const errors = []
  page.on('pageerror', err => errors.push(err.message))
  await page.goto('/games/zion-9/queue/ZION-030/index.html?test=1')
  await page.waitForFunction(() => window.ZION030_GAME?.state().ready, null, { timeout: 18000 })
  await page.waitForFunction(() => window.__ZION030_OPEN_CITY__?.state().ready, null, { timeout: 18000 })
  await page.locator('#oc-entry').click()
  await expect(page.locator('#oc-shell')).toBeVisible()
  await page.locator('#oc-start-play').click()
  await expect(page.locator('#oc-start')).toBeHidden()
  return errors
}

test('ZION-030 v28: real third-person street mode, electric vehicle, weather and quality', async ({ page }, testInfo) => {
  test.setTimeout(75000);
  const errors = await enterStreetMode(page)
  const snapshot = () => page.evaluate(() => window.__ZION030_OPEN_CITY__.state())
  await expect.poll(async () => (await snapshot()).mission.score).toBe(0)
  await expect(page.locator('#oc-contract-count')).toHaveText('0 / 3')
  const gps = page.locator(testInfo.project.name === 'mobile' ? '#oc-nav-mobile' : '#oc-nav-mode')
  await expect(gps).toBeVisible()
  await gps.click()
  await expect(gps).toContainText('КОНТРАКТЫ')
  await gps.click()
  await expect(page.locator('#oc-minimap')).toBeVisible()
  if (testInfo.project.name === 'mobile') {
    await expect(page.locator('#oc-joystick')).toBeVisible()
    await page.evaluate(() => window.__ZION030_OPEN_CITY__.teleport(.7, -1.0))
    await expect(page.locator('#oc-drive-action')).toBeVisible()
    await page.locator('#oc-drive-action').click()
  } else {
    const before = (await snapshot()).player
    await page.keyboard.down('w')
    await page.waitForTimeout(380)
    await page.keyboard.up('w')
    const after = (await snapshot()).player
    expect(Math.hypot(after.x - before.x, after.z - before.z)).toBeGreaterThan(.09)
    await page.keyboard.press('f')
  }
  await expect.poll(async () => (await snapshot()).driving).toBe(true)
  const vehicleBefore = (await snapshot()).vehicle
  if (testInfo.project.name === 'desktop') {
    await page.keyboard.down('w')
    await page.waitForTimeout(500)
    await page.keyboard.up('w')
    const vehicleAfter = (await snapshot()).vehicle
    expect(Math.hypot(vehicleAfter.x - vehicleBefore.x, vehicleAfter.z - vehicleBefore.z)).toBeGreaterThan(.08)
  }
  await expect(page.locator('#oc-drive-hud')).toBeVisible()
  await page.locator('#oc-time').click()
  await expect(page.locator('#oc-time')).toContainText('НОЧЬ')
  await page.locator('#oc-rain').click()
  await expect(page.locator('#oc-rain')).toHaveAttribute('aria-pressed', 'true')
  await page.locator('#oc-quality').click()
  await expect(page.locator('#oc-quality')).toContainText('ECO')
  await page.screenshot({ path: testInfo.outputPath('zion-v28-driving.png') })
  if (testInfo.project.name === 'mobile') await page.locator('#oc-drive-action').click()
  else await page.keyboard.press('f')
  await expect.poll(async () => (await snapshot()).driving).toBe(false)
  await page.locator('#oc-exit').click()
  await expect(page.locator('#oc-shell')).toBeHidden()
  await expect(page.locator('#premiumPlace')).toBeAttached()
  expect(errors).toEqual([])
})

test('ZION-030 v28: complete service contracts, earn and persist city credits', async ({ page }, testInfo) => {
  test.setTimeout(75000);
  const errors = await enterStreetMode(page)
  for (const { x, z } of [{ x: -15, z: -15 }, { x: 15, z: -10 }, { x: -10, z: 15 }]) {
    await page.evaluate(({ x, z }) => window.__ZION030_OPEN_CITY__.teleport(x, z), { x, z })
    if (testInfo.project.name === 'mobile') await page.locator('#oc-action').click()
    else await page.keyboard.press('e')
  }
  await expect(page.locator('#oc-contract-count')).toHaveText('3 / 3')
  await expect(page.locator('#oc-credit')).toHaveText('450')
  await expect(page.locator('#oc-reputation')).toHaveText('300')
  if (testInfo.project.name === 'mobile') {
    await page.locator('#oc-journal-button').click()
    await expect(page.locator('#oc-journal')).toBeVisible()
    await expect(page.locator('#oc-garage-balance')).toContainText('450')
    await page.locator('#oc-upgrade-speed').click()
    await expect(page.locator('#oc-upgrade-speed')).toBeDisabled()
    await page.locator('#oc-journal-resume').click()
  } else {
    await page.locator('#oc-upgrade').click()
    await expect(page.locator('#oc-upgrade')).toBeDisabled()
  }
  await expect(page.locator('#oc-credit')).toHaveText('150')
  await page.reload()
  await page.waitForFunction(() => window.__ZION030_OPEN_CITY__?.state().ready, null, { timeout: 18000 })
  await page.locator('#oc-entry').click()
  await expect(page.locator('#oc-contract-count')).toHaveText('3 / 3')
  await expect(page.locator('#oc-credit')).toHaveText('150')
  await expect.poll(() => page.evaluate(() => window.__ZION030_OPEN_CITY__.state().mission.placed.length)).toBe(0)
  expect(errors).toEqual([])
})