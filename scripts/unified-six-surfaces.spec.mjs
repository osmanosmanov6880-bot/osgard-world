import { test, expect } from '@playwright/test'

test('World never boots heavy WebGL while reduced motion is requested', async ({ page }) => {
  test.setTimeout(75_000)
  await page.emulateMedia({ reducedMotion: 'reduce' })
  await page.goto('/')
  await expect(page.locator('.omega-command')).toBeVisible()
  await expect(page.locator('.omega-globe')).toHaveCount(1)
  await expect(page.locator('.omega-webgl-stage')).toHaveCount(0)
  await expect(page.locator('.omega-gate a')).toHaveCount(3)
  await page.locator('.omega-experience-panel summary').click()
  const quality = page.getByRole('combobox', { name: 'Качество 3D-глобуса' })
  await expect(quality).toBeDisabled()
  await expect(page.getByRole('status').filter({ hasText: 'Режим экономии ресурсов' })).toBeVisible()
  await page.emulateMedia({ reducedMotion: 'no-preference' })
  await expect(quality).toBeEnabled()
  await expect(page.locator('.omega-webgl-stage')).toHaveCount(1, { timeout: 25000 })
})

test('World honors Save-Data independently of motion, without loading the GPU scene', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'no-preference' })
  await page.addInitScript(() => {
    Object.defineProperty(navigator, 'connection', {
      configurable: true, value: { saveData: true },
    })
  })
  await page.goto('/')
  await expect(page.locator('.omega-command')).toBeVisible()
  await expect(page.locator('.omega-globe')).toHaveCount(1)
  await expect(page.locator('.omega-webgl-stage')).toHaveCount(0)
  await page.locator('.omega-experience-panel summary').click()
  await expect(page.getByRole('combobox', { name: 'Качество 3D-глобуса' })).toBeDisabled()
  expect(await page.evaluate(() => navigator.connection?.saveData)).toBe(true)
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true)
})

test('Unified OSGARD entry points remain usable in a single reduced-motion session', async ({ page }) => {
  test.setTimeout(75_000)
  const errors = []
  page.on('pageerror', error => errors.push(error.message))
  await page.emulateMedia({ reducedMotion: 'reduce' })
  await page.goto('/')
  await expect(page.locator('.omega-gate a')).toHaveCount(3)
  await page.locator('.omega-gate a[href="/intelligence"]').click()
  await expect(page.locator('#proof-card')).toBeVisible()
  await expect(page.locator('main.intelligence-command')).toBeVisible()
  await page.getByRole('navigation', { name: 'Продукты OSGARD' }).getByRole('link', { name: 'Play', exact: true }).click()
  await expect(page.locator('.play-universe')).toBeVisible()
  await page.getByRole('navigation', { name: 'Продукты OSGARD' }).getByRole('link', { name: 'Development', exact: true }).click()
  await expect(page.locator('.signature-showcase')).toBeVisible()
  await page.goto('/academy?project=evidence#project-studio')
  await expect(page.locator('.academy-learning-console')).toBeVisible()
  await expect(page.locator('#project-studio .academy-studio-projects button').first()).toHaveAttribute('aria-pressed', 'true')
  await page.goto('/entertainment/archive/')
  await expect(page.locator('body.entertainment-premium')).toBeVisible()
  await expect(page.locator('.grid .card')).toHaveCount(7)
  expect(errors).toEqual([])
})
