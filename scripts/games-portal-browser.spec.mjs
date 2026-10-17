import { test, expect } from '@playwright/test'
import { resolve } from 'node:path'

// Exercise the retained static catalog source without replacing the built /games
// SPA route. Only the document and its two owned modules use source fixtures;
// games and other assets are served by the real production preview server.
async function openCatalog(page) {
  await page.route('**/games/catalog-qa.html', route => route.fulfill({
    path: resolve('public/games/index.html'), contentType: 'text/html; charset=utf-8',
  }))
  for (const file of ['player-lifecycle.js', 'ecosystem-intermission.js']) {
    await page.route('**/games/' + file, route => route.fulfill({
      path: resolve('public/games', file), contentType: 'text/javascript; charset=utf-8',
    }))
  }
  await page.goto('/games/catalog-qa.html')
  await expect(page.locator('#games-grid .card')).toHaveCount(19)
}

test('embedded launch records history exactly once and closes the client', async ({ page }) => {
  await openCatalog(page)
  let navigations = 0
  page.on('framenavigated', frame => {
    if (frame.parentFrame() && new URL(frame.url()).pathname === '/games/vector-zero/') navigations++
  })
  const launch = page.locator('#games-grid a[data-play="vector-zero"]').first()
  await launch.click()
  await expect(page.locator('#player-dialog')).toBeVisible()
  await expect(page.locator('#player-retry')).toHaveCount(1)
  await expect.poll(() => page.evaluate(() => JSON.parse(localStorage.getItem('osgard:play-collection:v1'))?.recent)).toEqual(['vector-zero'])
  await expect(page.locator('#recent-content [data-play="vector-zero"]')).toHaveCount(1)
  await expect(page.frameLocator('#player-frame').locator('#start')).toBeVisible()
  expect(navigations).toBe(1)
  await page.locator('#player-close').click()
  await expect(page.locator('#player-dialog')).not.toBeVisible()
  await expect(page.locator('#player-frame')).toHaveAttribute('src', 'about:blank')
  await page.reload()
  await expect(page.locator('#recent-content [data-play="vector-zero"]')).toHaveCount(1)
})

test('a cold modified click retains browser tab and window semantics', async ({ page }) => {
  await openCatalog(page)
  // Dispatch immediately without hovering/focusing first, so the optional
  // modules have not been warmed. Do not actually navigate a second tab.
  const prevented = await page.evaluate(() => {
    const link = document.querySelector('#games-grid a[data-play="vector-zero"]')
    const outcomes = []
    const stopNavigation = event => event.preventDefault()
    for (const modifier of ['ctrlKey', 'metaKey', 'shiftKey', 'altKey']) {
      let intercepted = true
      const observe = event => { intercepted = event.defaultPrevented; stopNavigation(event) }
      // Observe after the catalog's capture AND bubble handlers. Prevent the
      // browser's default action only after measuring whether they intercepted.
      window.addEventListener('click', observe, { once: true })
      link.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, button: 0, [modifier]: true }))
      window.removeEventListener('click', observe)
      outcomes.push(intercepted)
    }
    return outcomes
  })
  expect(prevented).toEqual([false, false, false, false])
  await expect(page.locator('#player-dialog')).not.toBeVisible()
})

test('fatal engine error stays visible until the user retries', async ({ page }) => {
  await openCatalog(page)
  await page.locator('#games-grid a[data-play="inherit"]').first().click()
  const frame = page.frameLocator('#player-frame')
  await expect(frame.locator('#world')).toBeVisible()
  await expect(page.locator('#player-status')).toHaveAttribute('data-state', 'ready')
  await frame.locator('body').evaluate(() => {
    parent.postMessage({ type: 'osgard:game-lifecycle', game: 'inherit', state: 'error', message: 'Проверка: ошибка игрового движка' }, location.origin)
  })
  await expect(page.locator('#player-status')).toHaveAttribute('data-state', 'error')
  await frame.locator('body').evaluate(() => {
    parent.postMessage({ type: 'osgard:game-lifecycle', game: 'inherit', state: 'started' }, location.origin)
  })
  await expect(page.locator('#player-status')).toContainText('Проверка: ошибка игрового движка')
  await expect(page.locator('#player-session-clock')).toBeHidden()
  await page.locator('#player-retry').click()
  await expect(page.locator('#player-status')).toHaveAttribute('data-state', 'ready')
  await expect(page.locator('#player-retry')).toBeHidden()
  await expect.poll(() => page.evaluate(() => JSON.parse(localStorage.getItem('osgard:play-collection:v1'))?.recent)).toEqual(['inherit'])
})

test('catalog launch works when the optional lifecycle download fails', async ({ page }) => {
  await openCatalog(page)
  await page.route('**/games/player-lifecycle.js', route => route.abort('failed'))
  await page.locator('#games-grid a[data-play="inherit"]').first().click()
  await expect(page.locator('#player-dialog')).toBeVisible()
  await expect(page.frameLocator('#player-frame').locator('#world')).toBeVisible()
  await expect.poll(() => page.evaluate(() => JSON.parse(localStorage.getItem('osgard:play-collection:v1'))?.recent)).toEqual(['inherit'])
  await page.locator('#player-close').click()
  await expect(page.locator('#player-frame')).toHaveAttribute('src', 'about:blank')
})

test('Time route loads its real game with external font services unavailable', async ({ page }) => {
  const fontRequests = []
  for (const host of ['fonts.googleapis.com', 'fonts.gstatic.com']) {
    await page.route('https://' + host + '/**', route => {
      fontRequests.push(route.request().url())
      return route.abort('failed')
    })
  }
  await page.goto('/games/time')
  await expect(page.locator('.tg-map-viewport')).toBeVisible()
  await expect(page.getByText('Страница не загрузилась.', { exact: true })).toHaveCount(0)
  const faces = await page.evaluate(async () => Promise.all(
    ['Playfair Display', 'Fraunces', 'Inter Tight'].map(async family =>
      (await document.fonts.load('400 16px "' + family + '"', 'Time')).map(font => font.status))))
  for (const family of faces) {
    expect(family.length).toBeGreaterThan(0)
    expect(family.every(status => status === 'loaded')).toBe(true)
  }
  expect(fontRequests).toEqual([])
})
