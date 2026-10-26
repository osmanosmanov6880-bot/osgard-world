import { test, expect } from '@playwright/test'

// V45 checks actual public still-image screening, never a local or commercial film.
const originalArt = [
  'library.webp', 'understand.webp', 'library.webp', 'verify.webp',
  'verify.webp', 'library.webp', 'decide.webp', 'decide.webp',
]

test('V45 live: isolated modal, keyboard focus, eight original images and NO-GO', async ({ page }, info) => {
  const errors = []
  page.on('pageerror', error => errors.push(error.message))
  const response = await page.goto('/osa-cinema?lang=ru&scene=0', { waitUntil: 'domcontentloaded' })
  expect(response?.status()).toBe(200)
  expect(new URL(page.url()).origin).toBe('https://osgard.world')
  const expectedSha = process.env.OSGARD_DEPLOY_SHA
  expect(expectedSha).toMatch(/^[0-9a-f]{40}$/)
  await expect(page.locator('meta[name="osa-cinema-deploy-sha"]')).toHaveAttribute('content', expectedSha)
  const viewer = page.locator('main.osa-cinema[data-cinema-art="obsidian"][data-cinema-release="v44"]')
  await expect(viewer).toBeVisible()
  const initialBackground = await page.evaluate(() => [...document.body.children]
    .filter(element => element instanceof HTMLElement).map(element => element.inert))
  const launcher = viewer.getByTestId('cinema-screening-launch')
  await launcher.click()
  const screening = page.getByTestId('cinema-screening')
  const dialog = screening.getByRole('dialog', { name: 'Интерактивный показ OSA Cinema' })
  await expect(dialog).toHaveAttribute('aria-modal', 'true')
  await expect(dialog).toBeVisible()
  const isolation = await page.evaluate(() => {
    const portal = document.querySelector('[data-testid="cinema-screening"]')
    return {
      portalNotInert: portal instanceof HTMLElement && !portal.inert,
      background: [...document.body.children]
        .filter(node => node instanceof HTMLElement && node !== portal)
        .map(node => node.inert),
    }
  })
  expect(isolation.portalNotInert).toBe(true)
  expect(isolation.background.length).toBeGreaterThan(0)
  expect(isolation.background.every(Boolean)).toBe(true)
  const close = dialog.getByRole('button', { name: 'Вернуться к уроку' })
  await expect(close).toBeFocused()
  await page.keyboard.press('Shift+Tab')
  await expect(dialog.getByRole('button', { name: 'Следующая сцена' })).toBeFocused()
  await page.keyboard.press('Tab')
  await expect(close).toBeFocused()

  const art = screening.locator('.osa-cinema-screening__art img')
  for (let scene = 0; scene < originalArt.length; scene += 1) {
    await expect(screening.getByRole('progressbar')).toHaveAttribute('aria-valuenow', String(scene + 1))
    await expect(art).toHaveAttribute('src', '/osa-cinema/reference/' + originalArt[scene])
    await expect(art).toHaveAttribute('alt', /.+/)
    const image = await art.evaluate(async element => {
      await element.decode()
      return {
        width: element.naturalWidth,
        height: element.naturalHeight,
        sameOrigin: new URL(element.currentSrc).origin === location.origin,
      }
    })
    expect(image.sameOrigin).toBe(true)
    expect(image.width * image.height).toBeGreaterThan(1000)
    const overflow = await screening.locator('.osa-cinema-screening__stage')
      .evaluate(stage => stage.scrollWidth - stage.clientWidth)
    expect(overflow, 'Scene ' + scene + ' must not clip horizontally').toBeLessThanOrEqual(2)
    await expect(screening.locator('video[src], audio[src], a[href*="checkout"], form[action*="payment"]')).toHaveCount(0)
    if (scene < originalArt.length - 1) {
      await dialog.getByRole('button', { name: 'Следующая сцена' }).click()
      await expect(page).toHaveURL(new RegExp('(?:\\?|&)scene=' + (scene + 1) + '(?:&|$)'))
    }
  }
  await page.screenshot({ path: info.outputPath('osa-cinema-v45-eight-scenes.png'), fullPage: true, animations: 'disabled' })
  await page.keyboard.press('Escape')
  await expect(screening).toHaveCount(0)
  await expect(launcher).toBeFocused()
  const restoredBackground = await page.evaluate(() => [...document.body.children]
    .filter(element => element instanceof HTMLElement).map(element => element.inert))
  expect(restoredBackground, 'Background inert state must be restored after dismissal').toEqual(initialBackground)
  expect(errors).toEqual([])
})
