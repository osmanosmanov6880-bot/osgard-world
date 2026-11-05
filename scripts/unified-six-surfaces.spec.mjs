import { test, expect } from '@playwright/test'

// The 2026 World route uses self-hosted portal artwork instead of the
// retired GPU globe. These are real browser checks, not source-string asserts.
test('World remains usable without WebGL or animation', async ({ page }) => {
  test.setTimeout(75_000)
  await page.emulateMedia({ reducedMotion: 'reduce' })
  await page.addInitScript(() => {
    const getContext = HTMLCanvasElement.prototype.getContext
    HTMLCanvasElement.prototype.getContext = function(kind, ...args) {
      if (kind === 'webgl2') return null
      return getContext.call(this, kind, ...args)
    }
  })
  await page.goto('/')
  const hero = page.locator('.omega-portals-hero')
  await expect(hero).toBeVisible()
  await expect(hero.locator('#world-title')).toContainText('МИРЫ')
  await expect(hero.locator('.omega-portal-stage a')).toHaveCount(3)
  await expect(page.locator('.omega-cards a[href]')).toHaveCount(3)
  await expect(page.locator('.omega-webgl-stage')).toHaveCount(0)
  await expect(page.getByRole('button', { name: 'Меньше движения', exact: true })).toBeDisabled()
  await page.emulateMedia({ reducedMotion: 'no-preference' })
  await expect(page.getByRole('button', { name: 'Меньше движения', exact: true })).toBeEnabled()
  await expect(page.locator('.omega-portals-reference img')).toHaveCount(1)
})

test('World honors Save-Data without requiring a GPU and preserves product routes', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'no-preference' })
  await page.addInitScript(() => {
    Object.defineProperty(navigator, 'connection', {
      configurable: true, value: { saveData: true },
    })
  })
  await page.goto('/')
  await expect(page.locator('.omega-portals-hero')).toBeVisible()
  await expect(page.locator('.omega-webgl-stage')).toHaveCount(0)
  await expect(page.locator('.omega-portals-live-cta')).toHaveAttribute('href', '#products')
  await expect(page.locator('.omega-cards a[href="/intelligence"]')).toHaveCount(1)
  await expect(page.locator('.omega-cards a[href="/play"]')).toHaveCount(1)
  await expect(page.locator('.omega-cards a[href="/development"]')).toHaveCount(1)
  expect(await page.evaluate(() => navigator.connection?.saveData)).toBe(true)
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true)
})

test('Unified OSGARD entry points work across actual product and academy routes', async ({ page }) => {
  test.setTimeout(75_000)
  const errors = []
  page.on('pageerror', error => errors.push(error.message))
  await page.emulateMedia({ reducedMotion: 'reduce' })
  await page.goto('/')
  await expect(page.locator('.omega-cards .omega-card')).toHaveCount(3)
  await page.locator('.omega-cards .omega-card[href="/intelligence"]').click()
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
