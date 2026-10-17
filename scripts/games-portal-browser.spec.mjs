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

test('catalog search retains Russian and ZION-9 matches without repeated hidden-attribute writes', async ({ page }) => {
  await openCatalog(page)
  await page.locator('#game-search').fill('теневой протокол')
  await expect(page.locator('#games-grid .card:not([hidden])')).toHaveCount(1)
  await expect(page.locator('#games-grid [data-game="zion-030"]')).toBeVisible()
  await expect(page.locator('#result-count')).toContainText('1 игровой проект')
  const redundantWrites = await page.evaluate(async () => {
    const grid = document.getElementById('games-grid')
    let writes = 0
    const observer = new MutationObserver(records => { writes += records.filter(record => record.attributeName === 'hidden').length })
    observer.observe(grid, { subtree: true, attributes: true, attributeFilter: ['hidden'] })
    document.getElementById('game-search').dispatchEvent(new Event('input', { bubbles: true }))
    await Promise.resolve()
    observer.disconnect()
    return writes
  })
  expect(redundantWrites).toBe(0)
})

test('two catalog tabs exchange favorites without echoing storage writes', async ({ page }) => {
  await openCatalog(page)
  const peer = await page.context().newPage()
  try {
    await openCatalog(peer)
    const spy = () => {
      const oldSet = Storage.prototype.setItem
      const writes = []
      Storage.prototype.setItem = function (key, value) {
        if (this === localStorage && key.startsWith('osgard')) writes.push(key)
        return oldSet.call(this, key, value)
      }
      window.__osgardCatalogWrites = writes
    }
    await page.evaluate(spy)
    await peer.evaluate(spy)
    const a = page.locator('#games-grid [data-favorite="remix"]').first()
    const b = peer.locator('#games-grid [data-favorite="remix"]').first()
    await a.click()
    await expect(b).toHaveAttribute('aria-pressed', 'true')
    await expect(peer.locator('#favorite-count')).toHaveText('1')
    expect(await peer.evaluate(() => window.__osgardCatalogWrites)).toEqual([])
    expect(await page.evaluate(() => window.__osgardCatalogWrites)).toEqual([
      'osgard.games.favorites.v1', 'osgard:play-collection:v1',
    ])
    await b.click()
    await expect(a).toHaveAttribute('aria-pressed', 'false')
    await expect(page.locator('#favorite-count')).toHaveText('0')
    expect(await page.evaluate(() => window.__osgardCatalogWrites)).toEqual([
      'osgard.games.favorites.v1', 'osgard:play-collection:v1',
    ])
    expect(await peer.evaluate(() => window.__osgardCatalogWrites)).toEqual([
      'osgard.games.favorites.v1', 'osgard:play-collection:v1',
    ])
  } finally {
    await peer.close()
  }
})

test('record catalog browser startup and filter costs without a synthetic Lighthouse pass', async ({ page }, testInfo) => {
  await page.addInitScript(() => {
    const evidence = { longTasks: [], layoutShifts: [], observerSupport: {} }
    for (const kind of ['longtask', 'layout-shift']) {
      const supported = PerformanceObserver.supportedEntryTypes?.includes(kind) === true
      evidence.observerSupport[kind] = supported
      if (!supported) continue
      const observer = new PerformanceObserver(list => {
        for (const entry of list.getEntries()) {
          if (kind === 'longtask') evidence.longTasks.push({
            startMs: Math.round(entry.startTime * 100) / 100,
            durationMs: Math.round(entry.duration * 100) / 100,
          })
          else if (!entry.hadRecentInput) evidence.layoutShifts.push({
            startMs: Math.round(entry.startTime * 100) / 100,
            value: entry.value,
          })
        }
      })
      observer.observe({ type: kind, buffered: true })
    }
    window.__osgardCatalogPerf = evidence
  })
  const errors = []
  page.on('pageerror', error => errors.push(error.message))
  await openCatalog(page)
  await page.waitForTimeout(250)
  const snapshot = await page.evaluate(() => {
    const durations = []
    const search = document.getElementById('game-search')
    // Measure actual synchronous input handlers on the same renderer clock,
    // not Playwright roundtrip/network latency.
    for (const value of ['swarm', 'север сна', 'remix', '', 'ZION-030', '']) {
      search.value = value
      const start = performance.now()
      search.dispatchEvent(new Event('input', { bubbles: true }))
      durations.push(Math.round((performance.now() - start) * 1000) / 1000)
    }
    const perf = window.__osgardCatalogPerf
    const nav = performance.getEntriesByType('navigation')[0]
    const paint = performance.getEntriesByType('paint')
    return {
      source: 'local static catalogue fixture on Vite preview, not public Lighthouse',
      urlPath: location.pathname,
      viewport: { width: innerWidth, height: innerHeight },
      navigation: nav ? {
        domInteractiveMs: Math.round(nav.domInteractive),
        domContentLoadedMs: Math.round(nav.domContentLoadedEventEnd),
        loadMs: Math.round(nav.loadEventEnd),
      } : null,
      firstContentfulPaintMs: paint.find(x => x.name === 'first-contentful-paint')?.startTime ?? null,
      resources: performance.getEntriesByType('resource').length,
      inputHandlerDurationsMs: durations,
      observerSupport: perf.observerSupport,
      longTasks: perf.longTasks,
      layoutShifts: perf.layoutShifts,
    }
  })
  await page.waitForTimeout(100)
  const result = await page.evaluate(original => {
    const p = window.__osgardCatalogPerf
    const tasks = p.longTasks
    return {
      ...original,
      longTasks: tasks,
      sumLongTaskExcessMs: Math.round(tasks.reduce((sum, task) => sum + Math.max(0, task.durationMs - 50), 0) * 100) / 100,
      observedCls: Math.round(p.layoutShifts.reduce((sum, entry) => sum + entry.value, 0) * 1000000) / 1000000,
      caveat: 'Long-task excess is descriptive only; it is NOT Lighthouse simulated TBT or a performance budget pass.',
    }
  }, snapshot)
  await expect(page.locator('#games-grid .card:not([hidden])')).toHaveCount(19)
  expect(errors).toEqual([])
  expect(result.inputHandlerDurationsMs).toHaveLength(6)
  expect(result.inputHandlerDurationsMs.every(x => Number.isFinite(x) && x >= 0)).toBe(true)
  const serialized = JSON.stringify(result, null, 2)
  await testInfo.attach('games-catalog-local-observation.json', { body: serialized, contentType: 'application/json' })
  console.log('GAMES_LOCAL_OBSERVATION ' + JSON.stringify({
    profile: testInfo.project.name,
    fcpMs: result.firstContentfulPaintMs,
    inputHandlerDurationsMs: result.inputHandlerDurationsMs,
    longTasks: result.longTasks.length,
    longTaskExcessMs: result.sumLongTaskExcessMs,
    observedCls: result.observedCls,
    longTaskSupported: result.observerSupport.longtask,
  }))
})
