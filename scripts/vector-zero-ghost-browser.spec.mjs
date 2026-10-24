import { test, expect } from '@playwright/test'

// Real Chromium smoke on desktop and mobile; VM smoke separately exercises
// private success/storage branch in the unchanged shipped inline game.
const game = '/games/vector-zero/index.html'
test('VECTOR ZERO Ghost Race loads and stays playable on desktop and mobile', async ({ page }, info) => {
  const pageErrors = []
  page.on('pageerror', error => pageErrors.push(error.message))
  await page.addInitScript(() => {
    localStorage.setItem('osgard-vector-zero-best-v1', '3')
    localStorage.setItem('osgard-vector-zero-ghost-v1',
      JSON.stringify({ version: 1, duration: 3, samples: [
        [150,564],[169,564],[185,555],[201,534],[220,516],[241,500],
      ] }))
  })
  const response = await page.goto(game)
  expect(response?.status()).toBe(200)
  await expect(page.locator('#field')).toBeVisible()
  const ghost = page.locator('#ghost')
  await expect(ghost).toBeEnabled()
  await expect(ghost).toHaveText('GHOST / ON')
  await expect(ghost).toHaveAttribute('aria-pressed', 'true')
  await expect(page.locator('#best')).toHaveText('3.0 S')
  await ghost.click()
  await expect(ghost).toHaveText('GHOST / OFF')
  await expect(ghost).toHaveAttribute('aria-pressed', 'false')
  await ghost.click()
  await expect(ghost).toHaveText('GHOST / ON')

  await page.locator('#start').click()
  await expect(page.locator('#overlay')).toBeHidden()
  await expect(page.locator('#objective-status')).toHaveText('FIELD ACTIVE')
  await expect(page.locator('#diag')).toContainText('FPS')
  const polarity = info.project.name === 'mobile' ? page.locator('[data-tap="pol"]') : page.locator('#pol')
  await polarity.click()
  await expect(page.locator('#charge')).toContainText('NEGATIVE')
  await page.keyboard.press('Escape')
  await expect(page.locator('#objective-status')).toHaveText('PAUSED')
  await page.locator('#start').click()
  await expect(page.locator('#objective-status')).toHaveText('FIELD ACTIVE')
  await page.locator('#restart').click()
  await expect(page.locator('#objective-status')).toHaveText('SYSTEM READY')
  expect(pageErrors).toEqual([])
})

test('VECTOR ZERO ignores corrupt saved ghost without a page error', async ({ page }) => {
  const errors = []
  page.on('pageerror', error => errors.push(error.message))
  await page.addInitScript(() => {
    localStorage.setItem('osgard-vector-zero-best-v1', '3')
    localStorage.setItem('osgard-vector-zero-ghost-v1', '{"version":1,"duration":3,"samples":[[1,"BAD"]]}')
  })
  await page.goto(game)
  await expect(page.locator('#ghost')).toBeDisabled()
  await expect(page.locator('#ghost')).toHaveText('GHOST / EMPTY')
  await page.locator('#start').click()
  await expect(page.locator('#objective-status')).toHaveText('FIELD ACTIVE')
  expect(errors).toEqual([])
})
