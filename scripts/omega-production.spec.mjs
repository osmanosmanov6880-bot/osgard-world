import { test, expect } from '@playwright/test'

const URL = process.env.OSGARD_PROD_BASE_URL || 'https://osgard.world'
const getResponse = async (page, path = '/') => {
  const response = await page.goto(URL + path, { waitUntil: 'domcontentloaded', timeout: 30000 })
  expect(response?.status(), path + ' status').toBe(200)
}

test('public OSGARD Earth and three-mode controller are deployed', async ({ page, request }, testInfo) => {
  const resp = await request.get(URL + '/brand/omega-earth-land.json', { timeout: 30000 })
  expect(resp.status()).toBe(200)
  const world = await resp.json()
  expect(world.type).toBe('land-polygons')
  expect(world.polygons.length).toBeGreaterThan(100)

  await page.emulateMedia({ reducedMotion: 'no-preference' })
  await getResponse(page)
  const hero = page.locator('.omega-hero')
  const controls = page.getByRole('group', { name: 'Выберите режим 3D-сцены' })
  await expect(hero).toBeVisible()
  await expect(controls).toBeVisible()
  await expect(controls.getByRole('button')).toHaveCount(3)
  await expect(page.locator('h1')).toContainText('ТЕХНОЛОГИИ')
  await expect(page.getByRole('navigation', { name: 'Три направления экосистемы' }).getByRole('link')).toHaveCount(3)

  await expect(page.locator('.omega-webgl-stage')).toHaveAttribute('data-globe-status', /^(webgl|fallback)$/, { timeout: 20000 })
  const globeStatus = await page.locator('.omega-webgl-stage').getAttribute('data-globe-status')
  if (globeStatus === 'webgl') {
    await expect(page.locator('.omega-webgl-stage')).toHaveAttribute('data-cloud-layers', '2')
  } else {
    await expect(page.locator('.omega-globe')).toHaveCount(1)
  }
  await page.screenshot({ path: testInfo.outputPath('omega-production-first-screen.png') })
})

test('public cinema, 3D-world and hybrid modes work and persist', async ({ page }, testInfo) => {
  await page.emulateMedia({ reducedMotion: 'no-preference' })
  await getResponse(page)
  const hero = page.locator('.omega-hero')
  const switcher = page.getByRole('group', { name: 'Выберите режим 3D-сцены' })
  await switcher.getByRole('button', { name: 'Кино' }).click()
  await expect(hero).toHaveAttribute('data-omega-mode', 'cinema')
  const chapter = page.getByRole('group', { name: 'Кинематографические главы' })
  await expect(chapter.getByRole('button')).toHaveCount(3)
  await chapter.getByRole('button', { name: '03 / Миры' }).click()
  await expect(chapter.getByRole('button', { name: '03 / Миры' })).toHaveAttribute('aria-pressed', 'true')

  await switcher.getByRole('button', { name: '3D-мир' }).click()
  await expect(hero).toHaveAttribute('data-omega-mode', 'world')
  const original = Number(await hero.getAttribute('data-omega-distance'))
  await page.getByRole('button', { name: 'Приблизить глобус' }).click()
  expect(Number(await hero.getAttribute('data-omega-distance'))).toBeLessThan(original)
  const originalYaw = Number(await hero.getAttribute('data-omega-yaw'))
  await page.getByRole('button', { name: 'Повернуть Землю вправо' }).click()
  expect(Number(await hero.getAttribute('data-omega-yaw'))).toBeGreaterThan(originalYaw + 0.35)
  await page.getByRole('button', { name: 'Сбросить' }).click()
  await expect(hero).toHaveAttribute('data-omega-distance', '5.70')

  await page.reload({ waitUntil: 'domcontentloaded' })
  await expect(hero).toHaveAttribute('data-omega-mode', 'world')
  await switcher.getByRole('button', { name: 'Гибрид' }).click()
  await expect(hero).toHaveAttribute('data-omega-mode', 'hybrid')
  await expect(page.getByRole('navigation', { name: 'Три направления экосистемы' }).getByRole('link')).toHaveCount(3)
  await page.screenshot({ path: testInfo.outputPath('omega-production-interactive.png') })
})

test('public website provides non-WebGL low-motion fallback and product routes', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' })
  await getResponse(page)
  await expect(page.locator('.omega-globe')).toHaveCount(1)
  await expect(page.locator('.omega-hero h1')).toBeVisible()
  await expect(page.locator('.omega-mode-tabs')).toBeVisible()
  await expect(page.getByRole('link', { name: /Исследовать экосистему/ })).toBeVisible()
  await page.getByRole('button', { name: 'Кино' }).click()
  await expect(page.locator('.omega-hero')).toHaveAttribute('data-omega-mode', 'cinema')
  for (const path of ['/intelligence', '/play', '/development']) {
    await getResponse(page, path)
    await expect(page.locator('h1')).toHaveCount(1)
    await expect(page.locator('main')).toHaveCount(1)
  }
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1)).toBe(true)
})
