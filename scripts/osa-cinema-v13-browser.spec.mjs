import { test, expect } from '@playwright/test'

test('OSA Cinema V13 renders all cinematic learning controls and preserves progress', async ({ page }, info) => {
  const errors = []
  page.on('pageerror', err => errors.push(err.message))

  // Check each real media response before route transitions can abort in-flight images.
  for (const name of ['library', 'understand', 'verify', 'decide']) {
    const response = await page.request.get('/osa-cinema/reference/' + name + '.webp')
    expect(response.ok(), name + ' must be served from the same origin').toBe(true)
    expect(response.headers()['content-type'], name + ' should use image/webp').toContain('image/webp')
    const bytes = await response.body()
    expect(bytes.subarray(0, 4).toString()).toBe('RIFF')
    expect(bytes.subarray(8, 12).toString()).toBe('WEBP')
  }

  await page.goto('/osa-cinema?lang=ru')
  const cinema = page.locator('main.osa-cinema[data-cinema-design="v13"]')
  await expect(cinema).toBeVisible()
  await expect(cinema).toHaveAttribute('lang', 'ru')
  await expect(cinema.locator('.cinema-rail button')).toHaveCount(3)
  await expect(cinema.locator('.cinema-choice-grid button')).toHaveCount(3)
  await expect(cinema.locator('.cinema-progress')).toContainText('0%')
  const art = await cinema.locator('.scene-art').evaluate(node => getComputedStyle(node).backgroundImage)
  expect(art).toContain('/osa-cinema/reference/understand.webp')
  const decoded = await cinema.locator('.scene-art').evaluate(async node => {
    const css = getComputedStyle(node).backgroundImage
    const match = css.match(/url\(["']?([^"')]+)/)
    if (!match) return false
    const image = new Image()
    image.src = match[1]
    try { await image.decode() } catch { return false }
    return image.naturalWidth >= 360 && image.naturalHeight >= 200
  })
  expect(decoded).toBe(true)
  const title = cinema.locator('.scene-content h1')
  await expect(title).toBeVisible()
  expect((await title.boundingBox())?.height).toBeGreaterThan(48)

  await expect(cinema.locator('.cinema-practice-link')).toHaveAttribute('href', '/academy?project=decision#project-studio')
  await expect(cinema.getByRole('progressbar', {name: /ПРОГРЕСС ПУТЕШЕСТВИЯ/i})).toHaveAttribute('aria-valuenow', '0')
  await cinema.locator('.cinema-choice-grid button').nth(1).click()
  await expect(cinema.locator('.cinema-choice-grid button').nth(1)).toHaveAttribute('aria-pressed', 'true')
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
