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
  { path: '/', product: 'world', heading: 'Цифровые продукты,', primary: '.world-hero .brand-button.primary', href: /^#cases$/ },
  { path: '/intelligence', product: 'intelligence', heading: 'Понимать ИИ.', primary: '.intelligence-hero .brand-button.primary', href: /^\/learning\/program$/ },
  { path: '/play', product: 'play', heading: 'ДОБАВЬ ТЕНЬ.', primary: '.play-hero .brand-button.primary', href: /^\/play\/world\/zion-030(?:\?|$)/ },
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
        metrics: null,
        fieldMeasurement: false,
        p75: null,
        coreWebVitalsVerdict: 'not-assessed',
        limitations: [
          'One attempt on a CI Chromium mobile viewport; not a physical mobile device or field percentile.',
          'CPU slowdown is relative to the current CI machine; other workers may share its resources.',
          'CDP latency/throughput are an emulated request profile, not measured radio RTT or packet loss.',
          'HTTP cache is bypassed; DNS, connection establishment and browser process warmth are not standardized.',
          'LCP is the latest observed candidate and CLS is the largest session window before the first input, not the full visit.',
          'The observation ends after main, fonts, viewport images, load and two rendering frames; later content can change metrics.',
          'The primary link is checked for actionability and destination; no course, game, form or payment is launched.',
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
              if (shifts.length < 100) shifts.push({ atMs: entry.startTime, value: entry.value })
            }
          })

          window.__osgardMobileLab = {
            snapshot(stop = false) {
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
        expect(evidence.metrics.lcpMs, 'A paint candidate must be observed; this is not an LCP speed threshold').not.toBeNull()
        expect(evidence.visualReadiness.fontsStatus).toBe('loaded')
        expect(evidence.visualReadiness.viewportImages.every(image => image.loaded), 'Visible images must load under the profile').toBe(true)

        // Trial performs hit-target/stability checks, but does not navigate or click.
        await primary.click({ trial: true, timeout: 20_000 })
        evidence.primaryAction = {
          text: (await primary.innerText()).trim(), href: await primary.getAttribute('href'),
          actionable: true, trialOnly: true,
          checkedAtMs: await page.evaluate(() => performance.now()),
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
