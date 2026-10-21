import { test, expect } from '@playwright/test'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
const playwrightVersion = require('@playwright/test/package.json').version
const profile = {
  latencyMs: 150,
  downloadMbps: 1.6,
  uploadKbps: 750,
  // CDP uses bytes/second; these are decimal Mbps/kbps, not MiB/KiB.
  downloadBytesPerSecond: 1_600_000 / 8,
  uploadBytesPerSecond: 750_000 / 8,
  cpuSlowdownMultiplier: 4,
  httpCacheDisabled: true,
  bypassServiceWorker: true,
}
const surfaces = [
  { path: '/', product: 'world', heading: 'ТЕХНОЛОГИИ,', primary: '.omega-hero .brand-button.primary', href: /^#products$/ },
  { path: '/intelligence', product: 'intelligence', heading: 'Понимать ИИ.', primary: '.intelligence-hero .brand-button.primary', href: /^#proof-card$/ },
  { path: '/play', product: 'play', heading: /OSGARD\s*Play/i, primary: '.cp-hero-actions .cp-button-primary', href: /^#featured$/ },
]

// Keep these samples sequential within this file, even under fullyParallel.
// Other CI workers may still share the machine: this is not calibrated hardware.
test.describe('OSGARD slow mobile laboratory', () => {
  test.describe.configure({ mode: 'default' })

  for (const surface of surfaces) {
    test(surface.product + ': usable main action and measured initial load', async ({ page, context }, info) => {
      test.skip(info.project.name !== 'mobile', 'This laboratory profile applies only to the mobile project')
      test.setTimeout(120_000)
      info.annotations.push({ type: 'measurement', description: 'Single-run mobile lab evidence; no field p75 or Core Web Vitals threshold verdict' })

      const pageErrors = [], failedRequests = []
      page.on('pageerror', error => pageErrors.push(error.message))
      page.on('requestfailed', request => failedRequests.push({ url: request.url(), error: request.failure()?.errorText || 'unknown' }))
      const evidence = {
        format: 'osgard-mobile-lab-v1',
        kind: 'laboratory-initial-load',
        product: surface.product,
        path: surface.path,
        generatedAt: new Date().toISOString(),
        commit: process.env.GITHUB_SHA || null,
        project: info.project.name,
        retry: info.retry,
        workerIndex: info.workerIndex,
        configuredWorkers: info.config.workers,
        playwrightVersion,
        browserVersion: context.browser()?.version() || null,
        profile,
        throttleApplied: false,
        ready: false,
        primaryAction: null,
        catalogNavigation: null,
        metrics: null,
        fieldMeasurement: false,
        p75: null,
        coreWebVitalsVerdict: 'not-assessed',
        laboratoryBudgets: { initialLoadClsMax: 0.1 },
        limitations: [
          'One attempt on a CI Chromium mobile viewport; not a physical mobile device or field percentile.',
          'CPU slowdown is relative to the current CI machine; other workers may share its resources.',
          'CDP latency/throughput are an emulated request profile, not measured radio RTT or packet loss.',
          'HTTP cache is bypassed; DNS, connection establishment and browser process warmth are not standardized.',
          'LCP is the latest observed candidate and CLS is the largest session window before the first input, not the full visit.',
          'The observation ends after main, fonts, viewport images, load and two rendering frames; later content can change metrics.',
          'Primary-link actionability is checked after measurement. Play then opens featured worlds and the catalog; no course, game, form or payment is launched.',
          'INP, production origin latency, CDN behavior and real user p75 are not measured by this test.',
        ],
      }
      let cdp

      try {
        cdp = await context.newCDPSession(page)
        await cdp.send('Network.enable')
        await cdp.send('Network.setCacheDisabled', { cacheDisabled: true })
        await cdp.send('Network.setBypassServiceWorker', { bypass: true })
        await cdp.send('Network.emulateNetworkConditions', {
          offline: false,
          latency: profile.latencyMs,
          downloadThroughput: profile.downloadBytesPerSecond,
          uploadThroughput: profile.uploadBytesPerSecond,
          connectionType: 'cellular3g',
        })
        await cdp.send('Emulation.setCPUThrottlingRate', { rate: profile.cpuSlowdownMultiplier })
        evidence.throttleApplied = true

        // Installed before navigation; buffered observers also retain early paints.
        await page.addInitScript(() => {
          const observers = [], errors = [], supported = {}
          let lcp = null, cls = 0, clsWindow = 0, windowStart = null, previousShift = 0
          let eligibleShifts = 0, inputExcludedShifts = 0
          const shifts = []
          const domMilestones = {
            brandShellInsertedAtMs: null,
            initialLoadingInsertedAtMs: null,
            initialLoadingRemovedAtMs: null,
            productHeroInsertedAtMs: null,
            note: 'MutationObserver timestamps for DOM presence, not paint or layout completion; no geometry reads are used.',
          }

          // Distinguish the initial Suspense shell from the resolved product.
          // These checks do not force layout, poll frames or extend observation.
          function recordDomMilestones() {
            const atMs = performance.now()
            if (domMilestones.brandShellInsertedAtMs === null && document.querySelector('.brand-system')) domMilestones.brandShellInsertedAtMs = atMs
            const initialLoading = document.querySelector('#product-main .route-loading[role="status"]')
            if (initialLoading && domMilestones.initialLoadingInsertedAtMs === null) domMilestones.initialLoadingInsertedAtMs = atMs
            if (!initialLoading && domMilestones.initialLoadingInsertedAtMs !== null && domMilestones.initialLoadingRemovedAtMs === null) domMilestones.initialLoadingRemovedAtMs = atMs
            if (domMilestones.productHeroInsertedAtMs === null && document.querySelector('#product-main .world-hero, #product-main .intelligence-hero, #product-main .cp-hero')) domMilestones.productHeroInsertedAtMs = atMs
          }
          const domObserver = new MutationObserver(() => {
            recordDomMilestones()
            if (domMilestones.productHeroInsertedAtMs !== null && document.querySelector('#product-main .route-loading[role="status"]') === null) domObserver.disconnect()
          })
          domObserver.observe(document, { childList: true, subtree: true })
          recordDomMilestones()

          function rectSnapshot(rect) {
            return rect ? { x: rect.x, y: rect.y, width: rect.width, height: rect.height, top: rect.top, right: rect.right, bottom: rect.bottom, left: rect.left } : null
          }

          function shiftSourceSnapshot(source) {
            const node = source.node
            return {
              node: node ? { tag: node.nodeName, id: node.id || null, classes: node instanceof Element ? [...node.classList] : [], connected: node.isConnected } : null,
              previousRect: rectSnapshot(source.previousRect),
              currentRect: rectSnapshot(source.currentRect),
            }
          }

          function observe(type, receive) {
            supported[type] = typeof PerformanceObserver !== 'undefined' && PerformanceObserver.supportedEntryTypes.includes(type)
            if (!supported[type]) return
            try {
              const observer = new PerformanceObserver(list => receive(list.getEntries()))
              observer.observe({ type, buffered: true })
              observers.push({ observer, receive })
            } catch (error) {
              supported[type] = false
              errors.push({ type, error: String(error) })
            }
          }

          observe('largest-contentful-paint', entries => {
            for (const entry of entries) lcp = {
              startTimeMs: entry.startTime,
              renderTimeMs: entry.renderTime,
              loadTimeMs: entry.loadTime,
              size: entry.size,
              url: entry.url || null,
              element: entry.element ? { tag: entry.element.tagName, id: entry.element.id || null } : null,
            }
          })
          observe('layout-shift', entries => {
            for (const entry of entries) {
              if (entry.hadRecentInput) { inputExcludedShifts++; continue }
              eligibleShifts++
              // CLS: maximum window, with <1 s between shifts and <5 s total.
              if (windowStart !== null && entry.startTime - previousShift < 1000 && entry.startTime - windowStart < 5000) clsWindow += entry.value
              else { windowStart = entry.startTime; clsWindow = entry.value }
              previousShift = entry.startTime
              cls = Math.max(cls, clsWindow)
              if (shifts.length < 100) shifts.push({ atMs: entry.startTime, value: entry.value, sources: [...(entry.sources || [])].map(shiftSourceSnapshot) })
            }
          })

          window.__osgardMobileLab = {
            snapshot(stop = false) {
              recordDomMilestones()
              if (stop) domObserver.disconnect()
              for (const { observer, receive } of observers) {
                receive(observer.takeRecords())
                if (stop) observer.disconnect()
              }
              const navigation = performance.getEntriesByType('navigation')[0]
              const resources = performance.getEntriesByType('resource')
              return {
                observedAtMs: performance.now(), timeOrigin: performance.timeOrigin,
                documentURL: location.href, visibility: document.visibilityState,
                readyState: document.readyState, supported, observerErrors: errors,
                viewport: { width: innerWidth, height: innerHeight, devicePixelRatio },
                reducedMotion: matchMedia('(prefers-reduced-motion: reduce)').matches,
                fonts: { status: document.fonts.status, faces: [...document.fonts].map(font => ({ family: font.family, status: font.status })) },
                lcpMs: lcp?.startTimeMs ?? null, lcpCandidate: lcp,
                cls: supported['layout-shift'] ? cls : null,
                layoutShifts: { eligible: eligibleShifts, excludedAfterInput: inputExcludedShifts, first100: shifts },
                domMilestones,
                navigation: navigation?.toJSON() ?? null,
                paint: performance.getEntriesByType('paint').map(entry => ({ name: entry.name, atMs: entry.startTime })),
                resources: {
                  observedEntries: resources.length,
                  transferBytes: resources.reduce((sum, entry) => sum + entry.transferSize, 0),
                  encodedBodyBytes: resources.reduce((sum, entry) => sum + entry.encodedBodySize, 0),
                  note: 'PerformanceResourceTiming entries available at the snapshot; not a complete transfer audit.',
                },
              }
            },
          }
        })

        const response = await page.goto(surface.path, { waitUntil: 'domcontentloaded', timeout: 75_000 })
        evidence.httpStatus = response?.status() ?? null
        expect(evidence.httpStatus).toBe(200)
        await expect(page.locator('#product-main')).toBeVisible({ timeout: 60_000 })
        await expect(page.getByRole('heading', { level: 1 })).toContainText(surface.heading, { timeout: 60_000 })
        await expect(page.locator('html')).toHaveAttribute('data-product', surface.product)
        const primary = page.locator(surface.primary)
        await expect(primary).toBeVisible({ timeout: 60_000 })
        await expect(primary).toBeEnabled()
        await expect(primary).toHaveAttribute('href', surface.href)
        if (surface.product === 'play') await expect(primary).toContainText('Исследовать миры')
        evidence.mainAndActionVisibleAtMs = await page.evaluate(() => performance.now())

        // Readiness signals, not an arbitrary sleep or a networkidle heuristic.
        await page.waitForLoadState('load', { timeout: 45_000 })
        evidence.visualReadiness = await page.evaluate(async () => {
          await document.fonts.ready
          const visibleImages = [...document.images].filter(image => {
            const box = image.getBoundingClientRect()
            return box.width > 0 && box.height > 0 && box.bottom > 0 && box.right > 0 && box.top < innerHeight && box.left < innerWidth
          })
          const images = await Promise.all(visibleImages.map(async image => {
            let error = null
            try { await image.decode() } catch (cause) { error = String(cause) }
            return { url: image.currentSrc || image.src, loaded: image.complete && image.naturalWidth > 0, error }
          }))
          await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
          return { atMs: performance.now(), fontsStatus: document.fonts.status, viewportImages: images }
        })
        // Freeze before trial-click can scroll the viewport and stop LCP sampling.
        evidence.metrics = await page.evaluate(() => window.__osgardMobileLab.snapshot(true))
        evidence.observationBoundary = 'initial-load-readiness-before-first-input'
        expect(evidence.metrics.supported['largest-contentful-paint'], 'LCP observer must be available for valid evidence').toBe(true)
        expect(evidence.metrics.supported['layout-shift'], 'CLS observer must be available for valid evidence').toBe(true)
        expect(evidence.metrics.cls, 'Lab layout-stability budget: initial-load CLS must be <= 0.1; this is not a field p75 verdict').toBeLessThanOrEqual(evidence.laboratoryBudgets.initialLoadClsMax)
        expect(evidence.metrics.lcpMs, 'A paint candidate must be observed; this is not an LCP speed threshold').not.toBeNull()
        expect(evidence.visualReadiness.fontsStatus).toBe('loaded')
        expect(evidence.visualReadiness.viewportImages.every(image => image.loaded), 'Visible images must load under the profile').toBe(true)
        evidence.initialLayout = await page.evaluate(() => ({ width: innerWidth, documentWidth: document.documentElement.scrollWidth, bodyWidth: document.body.scrollWidth }))
        expect(evidence.initialLayout.documentWidth, 'The initial mobile document must not overflow horizontally').toBeLessThanOrEqual(evidence.initialLayout.width + 1)
        expect(evidence.initialLayout.bodyWidth, 'The initial mobile body must not overflow horizontally').toBeLessThanOrEqual(evidence.initialLayout.width + 1)

        // Trial performs hit-target/stability checks, but does not navigate or click.
        await primary.click({ trial: true, timeout: 20_000 })
        evidence.primaryAction = {
          text: (await primary.innerText()).trim(), href: await primary.getAttribute('href'),
          actionable: true, trialOnly: true,
          checkedAtMs: await page.evaluate(() => performance.now()),
        }
        if (surface.product === 'play') {
          // Exercise the real two-step journey only after the initial-load
          // observers have stopped and the original trial-click has passed.
          await primary.click({ timeout: 20_000 })
          await expect(page).toHaveURL(url => url.pathname === '/play' && url.hash === '#featured')
          const featured = page.locator('#featured')
          await expect(featured).toBeInViewport()
          await expect(featured.locator('.cp-featured-world')).toHaveCount(3)
          await expect(featured.getByRole('button', { name: 'Предыдущие избранные миры', exact: true })).toBeEnabled()
          await expect(featured.getByRole('button', { name: 'Следующие избранные миры', exact: true })).toBeEnabled()
          const catalogLink = page.locator('.cp-glass-panel a[href="#catalog"]')
          await expect(catalogLink).toHaveAttribute('href', '#catalog')
          await catalogLink.click({ timeout: 20_000 })
          await expect(page).toHaveURL(url => url.pathname === '/play' && url.hash === '#catalog')
          const catalog = page.locator('#catalog')
          await expect(catalog).toBeInViewport({ timeout: 60_000 })
          await expect(catalog.locator('.play-card')).toHaveCount(19, { timeout: 60_000 })
          const search = catalog.getByRole('searchbox', { name: 'Найти свой мир', exact: true })
          await expect(search).toBeEnabled()
          await expect(catalog.getByLabel('Жанр', { exact: true })).toBeEnabled()
          await expect(catalog.getByLabel('Доступность', { exact: true })).toBeEnabled()
          await expect(catalog.getByRole('group', { name: 'Моя коллекция', exact: true }).getByRole('button')).toHaveCount(3)
          await search.fill('ZION-030')
          await expect(catalog.locator('.play-card')).toHaveCount(1)
          await expect(catalog.locator('.play-card[data-world-id="zion-030"] h3 a')).toHaveAttribute('href', /^\/play\/world\/zion-030(?:\?|$)/)
          await search.fill('')
          await expect(catalog.locator('.play-card')).toHaveCount(19)
          const layout = await page.evaluate(() => ({ width: innerWidth, documentWidth: document.documentElement.scrollWidth, bodyWidth: document.body.scrollWidth }))
          expect(layout.documentWidth, 'The full mobile catalog must not overflow horizontally').toBeLessThanOrEqual(layout.width + 1)
          expect(layout.bodyWidth, 'The full mobile catalog body must not overflow horizontally').toBeLessThanOrEqual(layout.width + 1)
          evidence.catalogNavigation = {
            observationBoundary: 'after-initial-load-measurement-and-trial',
            primaryDestination: '#featured', href: page.url(),
            cards: await catalog.locator('.play-card').count(), searchVerified: true, layout,
            checkedAtMs: await page.evaluate(() => performance.now()),
          }
        }
        expect(pageErrors, 'The main page must remain usable under throttling').toEqual([])
        evidence.ready = true
      } catch (error) {
        evidence.failure = { name: error.name, message: error.message }
        throw error
      } finally {
        if (!evidence.metrics && !page.isClosed()) {
          evidence.metrics = await page.evaluate(() => window.__osgardMobileLab?.snapshot(true) ?? null).catch(() => null)
          evidence.observationBoundary = 'partial-failure-snapshot'
        }
        evidence.pageErrors = pageErrors
        evidence.failedRequests = failedRequests.slice(0, 100)
        await info.attach('mobile-lab-' + surface.product + '-attempt-' + info.retry + '.json', {
          body: Buffer.from(JSON.stringify(evidence, null, 2)), contentType: 'application/json',
        })
        if (cdp) {
          await cdp.send('Emulation.setCPUThrottlingRate', { rate: 1 }).catch(() => {})
          await cdp.detach().catch(() => {})
        }
      }
    })
  }
})
