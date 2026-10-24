import { test, expect } from '@playwright/test'

test('OSA Cinema V13 renders all cinematic learning controls and preserves progress', async ({ page }, info) => {
  const errors = []
  const missingImages = []
  page.on('pageerror', err => errors.push(err.message))
  page.on('requestfailed', req => {
    if (req.url().includes('/media/reference/')) missingImages.push(req.url() + ': ' + req.failure()?.errorText)
  })
  page.on('response', response => {
    if (response.url().includes('/media/reference/') && response.status() >= 400) {
      missingImages.push(response.url() + ': HTTP ' + response.status())
    }
  })

  await page.goto('/osa-cinema?lang=ru')
  const cinema = page.locator('main.osa-cinema[data-cinema-design="v13"]')
  await expect(cinema).toBeVisible()
  await expect(cinema).toHaveAttribute('lang', 'ru')
  await expect(cinema.locator('.cinema-rail button')).toHaveCount(3)
  await expect(cinema.locator('.cinema-choice-grid button')).toHaveCount(3)
  await expect(cinema.locator('.cinema-progress')).toContainText('0%')
  const art = await cinema.locator('.scene-art').evaluate(node => getComputedStyle(node).backgroundImage)
  expect(art).toContain('understand.webp')
  const title = cinema.locator('.scene-content h1')
  await expect(title).toBeVisible()
  expect((await title.boundingBox())?.height).toBeGreaterThan(48)

  await cinema.locator('.cinema-choice-grid button').nth(1).click()
  await expect(cinema.locator('.cinema-choice-result')).toBeVisible()
  await cinema.locator('.cinema-next').click()
  await expect(cinema.locator('.cinema-scene')).toHaveClass(/cinema-scene-network/)
  await expect(cinema.locator('.cinema-progress')).not.toContainText('0%')
  await page.reload()
  await expect(cinema).toHaveAttribute('lang', 'ru')
  await expect(cinema.locator('.cinema-scene')).toHaveClass(/cinema-scene-network/)
  await page.screenshot({ path: info.outputPath('osa-cinema-v13-progress.png'), fullPage: true })

  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 2)).toBe(true)
  expect(errors).toEqual([])
  expect(missingImages).toEqual([])
})

test('OSA Cinema V13 keeps RU/EN deep links, focus and source notes usable', async ({ page }, info) => {
  const errors = []
  page.on('pageerror', error => errors.push(error.message))
  await page.goto('/osa-cinema?lang=en')
  const cinema = page.locator('main.osa-cinema[data-cinema-design="v13"]')
  await expect(cinema).toBeVisible()
  await expect(cinema).toHaveAttribute('lang', 'en')
  await expect(cinema.locator('.scene-content h1')).toContainText('Can you tell')
  const lang = cinema.getByRole('button', { name: 'Переключить на русский' })
  await lang.click()
  await expect(cinema).toHaveAttribute('lang', 'ru')
  await expect(page).toHaveURL(/lang=ru/)
  await cinema.locator('.cinema-top-actions button').first().press('ArrowRight')
  await expect(cinema.locator('.cinema-scene')).toHaveClass(/cinema-scene-signal/)
  await page.reload()
  await expect(cinema).toHaveAttribute('lang', 'ru')
  await cinema.locator('.cinema-top-actions button').nth(1).click()
  await expect(cinema.locator('.cinema-notes')).toBeVisible()
  await expect(cinema.locator('.cinema-notes a')).toHaveCount(4)
  await page.screenshot({ path: info.outputPath('osa-cinema-v13-notes.png'), fullPage: true })
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 2)).toBe(true)
  expect(errors).toEqual([])
})
