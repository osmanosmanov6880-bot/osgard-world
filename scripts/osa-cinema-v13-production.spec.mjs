import { test, expect } from '@playwright/test'

test('published OSA CINEMA V13 preserves cinematic art, decisions and progress', async ({ page }, info) => {
  const pageErrors = []
  page.on('pageerror', error => pageErrors.push(error.message))
  await page.goto('/osa-cinema?lang=ru', { waitUntil: 'domcontentloaded' })
  const app = page.locator('main.osa-cinema[data-cinema-design="v13"]')
  await expect(app).toBeVisible()
  await expect(app).toHaveAttribute('lang', 'ru')
  await expect(app.locator('.cinema-rail button')).toHaveCount(3)
  await expect(app.locator('.cinema-choice-grid button')).toHaveCount(3)
  await expect(app.locator('.scene-content h1')).toBeVisible()

  const art = await app.locator('.scene-art').evaluate(async node => {
    const computed = getComputedStyle(node).backgroundImage
    const match = computed.match(/url\(["']?([^"')]+)/)
    if (!match) return { status: 'missing-css-image' }
    const resource = new URL(match[1], document.baseURI)
    const image = new Image()
    image.src = resource.href
    try { await image.decode() } catch { return { status: 'image-decoding-failed', url: resource.href } }
    return {
      status: 'decoded', path: resource.pathname, sameOrigin: resource.origin === location.origin,
      width: image.naturalWidth, height: image.naturalHeight
    }
  })
  expect(art.status).toBe('decoded')
  expect(art.sameOrigin).toBe(true)
  expect(art.path).toBe('/osa-cinema/reference/understand.webp')
  expect(art.width).toBeGreaterThanOrEqual(360)
  expect(art.height).toBeGreaterThanOrEqual(200)

  await expect(app.locator('.cinema-practice-link')).toHaveAttribute('href', '/academy?project=decision#project-studio')
  await expect(app.getByRole('progressbar')).toHaveAttribute('aria-valuenow', '0')
  await app.locator('.cinema-choice-grid button').nth(1).click()
  await expect(app.locator('.cinema-choice-grid button').nth(1)).toHaveAttribute('aria-pressed', 'true')
  await expect(app.locator('.cinema-choice-result')).toBeVisible()
  await app.locator('.cinema-next').click()
  await expect(app.locator('.cinema-progress')).not.toContainText('0%')
  await page.reload({ waitUntil: 'domcontentloaded' })
  await expect(app).toHaveAttribute('lang', 'ru')
  await expect(app.locator('.cinema-scene')).toHaveClass(/cinema-scene-network/)
  await page.screenshot({ path: info.outputPath('osa-v13-live-progress.png'), fullPage: true, animations: 'disabled' })

  const noHorizontalOverflow = await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 2)
  expect(noHorizontalOverflow).toBe(true)
  expect(pageErrors).toEqual([])
})

test('published OSA CINEMA V13 bilingual navigation and evidence notes work', async ({ page }, info) => {
  const pageErrors = []
  page.on('pageerror', error => pageErrors.push(error.message))
  await page.goto('/osa-cinema?lang=en', { waitUntil: 'domcontentloaded' })
  const app = page.locator('main.osa-cinema[data-cinema-design="v13"]')
  await expect(app).toHaveAttribute('lang', 'en')
  await expect(app.locator('.scene-content h1')).toContainText('Can you tell')
  await app.getByRole('button', { name: 'Переключить на русский' }).click()
  await expect(app).toHaveAttribute('lang', 'ru')
  await expect(page).toHaveURL(/lang=ru/)
  await page.reload({ waitUntil: 'domcontentloaded' })
  await expect(app).toHaveAttribute('lang', 'ru')
  await app.locator('.cinema-top-actions button').nth(1).click()
  await expect(app.locator('.cinema-notes')).toBeVisible()
  await expect(app.locator('.cinema-notes a')).toHaveCount(4)
  await page.screenshot({ path: info.outputPath('osa-v13-live-notes.png'), fullPage: true, animations: 'disabled' })
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 2)).toBe(true)
  expect(pageErrors).toEqual([])
})
