import { test, expect } from '@playwright/test'

const publishedSha = process.env.OSGARD_DEPLOY_SHA
const allowedOrigin = new URL(process.env.OSGARD_BASE_URL || 'https://osgard.world').origin

async function expectScene(page, app, sceneIndex, locale) {
  await expect(app).toHaveAttribute('lang', locale)
  await expect(app.locator('.osa42-chapter').nth(sceneIndex)).toHaveAttribute('aria-current', 'step')
  await expect(app.locator('.osa42-scene-heading')).toBeVisible()
  const url = new URL(page.url())
  expect(url.searchParams.get('scene')).toBe(String(sceneIndex))
  expect(url.searchParams.get('lang')).toBe(locale)
  expect(url.searchParams.get('ref')).toBe('v46')
  expect(url.hash).toBe('#osa42-story')
}

test('V46: browser Back/Forward restores chapters, language and live screening state', async ({ page }, info) => {
  const errors = []
  page.on('pageerror', error => errors.push(error.message))
  const response = await page.goto('/osa-cinema?lang=ru&scene=0&ref=v46#osa42-story', {waitUntil:'domcontentloaded'})
  expect(response?.status()).toBe(200)
  if (publishedSha) {
    expect(new URL(page.url()).origin).toBe(allowedOrigin)
    await expect(page.locator('meta[name="osa-cinema-deploy-sha"]')).toHaveAttribute('content', publishedSha)
  }
  const app = page.locator('main.osa-cinema[data-cinema-art="obsidian"][data-cinema-navigation="v46"]')
  await expect(app).toBeVisible()
  await expectScene(page, app, 0, 'ru')
  const initialHistoryLength = await page.evaluate(() => history.length)
  const navigate = async target => {
    const mobile = app.locator('.osa43-mobile-nav')
    if (await mobile.isVisible()) {
      await mobile.getByRole('combobox', {name:'Выбрать сцену истории'}).selectOption(String(target))
    } else {
      await app.locator('.osa42-chapter-list button').nth(target).click()
    }
    await expectScene(page, app, target, 'ru')
  }
  await navigate(2)
  await navigate(5)
  expect(await page.evaluate(() => history.length)).toBe(initialHistoryLength + 2)
  await page.goBack()
  await expectScene(page, app, 2, 'ru')
  await page.goForward()
  await expectScene(page, app, 5, 'ru')
  await app.getByRole('button', {name:'Switch to English'}).click()
  await expectScene(page, app, 5, 'en')
  await page.goBack()
  await expectScene(page, app, 5, 'ru')
  await page.goForward()
  await expectScene(page, app, 5, 'en')

  const launcher = app.getByTestId('cinema-screening-launch')
  await launcher.click()
  const screening = page.getByTestId('cinema-screening')
  await expect(screening.getByRole('dialog', {name:'OSA Cinema interactive screening'})).toBeVisible()
  await screening.getByRole('button', {name:'Next scene'}).click()
  await expectScene(page, app, 6, 'en')
  await page.goBack()
  await expectScene(page, app, 5, 'en')
  await expect(screening.getByRole('progressbar')).toHaveAttribute('aria-valuenow', '6')
  await page.keyboard.press('Escape')
  await expect(screening).toHaveCount(0)
  await expect(launcher).toBeFocused()
  await page.reload({waitUntil:'domcontentloaded'})
  await expectScene(page, app, 5, 'en')
  await expect(app.locator('video[src],audio[src],a[href*="checkout"],form[action*="payment"]')).toHaveCount(0)
  await page.screenshot({path:info.outputPath('osa-v46-history.png'),fullPage:true,animations:'disabled'})
  expect(errors).toEqual([])
})

test('V46: malformed and duplicate deep links are canonicalised without a crash', async ({ page }) => {
  const errors = []
  page.on('pageerror', error => errors.push(error.message))
  const response = await page.goto('/osa-cinema?scene=8&scene=3&lang=de&lang=en&ref=v46#osa42-story', {waitUntil:'domcontentloaded'})
  expect(response?.status()).toBe(200)
  const app = page.locator('main.osa-cinema[data-cinema-navigation="v46"]')
  await expect(app).toBeVisible()
  await expectScene(page, app, 0, 'ru')
  const canonical = new URL(page.url())
  expect(canonical.searchParams.getAll('scene')).toEqual(['0'])
  expect(canonical.searchParams.getAll('lang')).toEqual(['ru'])
  await page.goto('/osa-cinema?lang=en&scene=7&ref=v46#osa42-story', {waitUntil:'domcontentloaded'})
  await expectScene(page, app, 7, 'en')
  await page.reload({waitUntil:'domcontentloaded'})
  await expectScene(page, app, 7, 'en')
  expect(errors).toEqual([])
})
