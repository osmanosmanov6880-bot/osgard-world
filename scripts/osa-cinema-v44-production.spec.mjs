import { test, expect } from '@playwright/test'

const allowedOrigin = new URL(process.env.OSGARD_BASE_URL || 'https://osgard.world').origin

function watchErrors(page) {
  const errors = []
  page.on('pageerror', error => errors.push(error.message))
  return errors
}
async function assertLiveCinema(page, path) {
  const response = await page.goto(path, { waitUntil: 'domcontentloaded' })
  expect(response, 'The production cinema route must respond').toBeTruthy()
  expect(response.status(), 'The production cinema route must return HTTP 200').toBe(200)
  expect(new URL(page.url()).origin, 'Viewer must remain on the approved origin').toBe(allowedOrigin)
  const app = page.locator('main.osa-cinema[data-cinema-art="obsidian"][data-cinema-release="v44"]')
  await expect(app, 'Live deployment must contain V44, not a stale V42/V43 build').toBeVisible()
  const deploySha = process.env.OSGARD_DEPLOY_SHA
  expect(deploySha, 'The exact successful master deployment SHA must be provided').toMatch(/^[0-9a-f]{40}$/)
  await expect(page.locator('meta[name="osa-cinema-deploy-sha"]')).toHaveAttribute('content', deploySha)
  return app
}
test('V44 live mobile: eight scenes, reload, language and accessible navigation', async ({ page }, info) => {
  const errors = watchErrors(page)
  await page.setViewportSize({ width: 390, height: 844 })
  const app = await assertLiveCinema(page, '/osa-cinema?lang=ru&scene=0')
  const nav = app.getByRole('navigation', { name: 'Быстрый переход между сценами' })
  await expect(nav).toBeVisible()
  const select = nav.getByRole('combobox', { name: 'Выбрать сцену истории' })
  await expect(select.locator('option')).toHaveCount(8)
  await expect(select).toHaveValue('0')
  await expect(nav.getByRole('button', { name: 'Предыдущая глава' })).toBeDisabled()
  for (let sceneIndex = 1; sceneIndex < 8; sceneIndex++) {
    await select.selectOption(String(sceneIndex))
    await expect(select).toHaveValue(String(sceneIndex))
    await expect(page).toHaveURL(new RegExp(`(?:\\?|&)scene=${sceneIndex}(?:&|$)`))
  }
  await expect(nav.getByRole('button', { name: 'Следующая глава' })).toBeDisabled()
  await select.selectOption('4')
  await expect(select).toHaveValue('4')
  await expect(page).toHaveURL(/(?:\?|&)scene=4(?:&|$)/)
  await expect(app.locator('.osa42-scene-heading')).toBeVisible()
  await page.reload({ waitUntil: 'domcontentloaded' })
  await expect(select).toHaveValue('4')
  await nav.getByRole('button', { name: 'Следующая глава' }).click()
  await expect(select).toHaveValue('5')
  await app.getByRole('button', { name: 'Switch to English' }).click()
  await expect(app).toHaveAttribute('lang', 'en')
  const english = app.getByRole('navigation', { name: 'Quick scene navigation' })
  await expect(english.getByRole('combobox', { name: 'Choose a story scene' })).toHaveValue('5')
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 2)).toBe(true)
  expect(errors).toEqual([])
  await page.screenshot({ path: info.outputPath('osa-cinema-v44-live-mobile.png'), fullPage: true, animations: 'disabled' })
})
test('V44 live desktop: approved archive, scene deep links, full-screen viewer', async ({ page }, info) => {
  const errors = watchErrors(page)
  await page.setViewportSize({ width: 1536, height: 960 })
  const app = await assertLiveCinema(page, '/osa-cinema?lang=en&scene=2')
  await expect(app.locator('.osa43-mobile-nav')).toBeHidden()
  await expect(app.locator('.osa42-chapter')).toHaveCount(8)
  await expect(app.locator('.osa42-chapter[aria-current="step"]')).toHaveCount(1)
  await expect(app.locator('.osa42-scene-heading')).toBeVisible()
  const launch = app.getByTestId('cinema-screening-launch')
  await expect(launch).toBeVisible()
  await launch.click()
  const modal = page.getByTestId('cinema-screening')
  await expect(modal.getByRole('dialog', { name: 'OSA Cinema interactive screening' })).toBeVisible()
  await expect(modal.getByRole('dialog')).toHaveAttribute('aria-modal', 'true')
  await page.keyboard.press('Escape')
  await expect(modal).toBeHidden()
  await expect(launch).toBeFocused()
  await app.locator('.osa42-chapter').nth(6).click()
  await expect(page).toHaveURL(/(?:\?|&)scene=6(?:&|$)/)
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 2)).toBe(true)
  expect(errors).toEqual([])
  await page.screenshot({ path: info.outputPath('osa-cinema-v44-live-desktop.png'), fullPage: true, animations: 'disabled' })
})
test('V44 live boundary: original bundled art and no private playback or checkout', async ({ page }) => {
  const app = await assertLiveCinema(page, '/osa-cinema?lang=ru&scene=0')
  const response = await page.request.get('/osa-cinema/obsidian/portal-640.webp')
  expect(response.status()).toBe(200)
  expect(new URL(response.url()).origin).toBe(allowedOrigin)
  expect(response.headers()['content-type'] || '').toMatch(/image\/webp/i)
  const bytes = await response.body()
  expect(bytes.subarray(0, 4).toString('ascii')).toBe('RIFF')
  expect(bytes.subarray(8, 12).toString('ascii')).toBe('WEBP')
  expect(bytes.length).toBeGreaterThan(2048)
  const exposed = await app.evaluate(node => ({
    playable: node.querySelectorAll('video[src],audio[src],video source[src],audio source[src]').length,
    checkout: node.querySelectorAll('a[href*="checkout"],a[href*="stripe"],form[action*="payment"]').length,
  }))
  expect(exposed).toEqual({ playable: 0, checkout: 0 })
})
