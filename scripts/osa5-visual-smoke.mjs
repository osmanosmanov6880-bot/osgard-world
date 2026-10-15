import assert from 'node:assert/strict'
import { mkdir } from 'node:fs/promises'
import { resolve } from 'node:path'
import { chromium } from 'playwright'

const base = (process.env.OSA5_BASE_URL || 'http://127.0.0.1:4173').replace(/\/+$/, '')
const output = resolve('artifacts/osa5-responsive')
await mkdir(output, { recursive: true })

const viewports = [
  { name: 'desktop', width: 1440, height: 900 },
  { name: 'tablet', width: 768, height: 1024 },
  { name: 'mobile', width: 390, height: 844 }
]
const routes = [
  { name: 'intelligence', path: '/', selector: '.osa-home' },
  { name: 'portal', path: '/portal', selector: '.osgard-world-app' },
  { name: 'academy', path: '/academy', selector: 'body' },
  { name: 'lectures', path: '/lectures', selector: '.lecture-library' },
  { name: 'lesson-detail', path: '/lectures/intelligence-and-imitation', selector: '.osa-lesson-page' },
  { name: 'media-library', path: '/osa-library/', selector: '.hero' },
  { name: 'cinema', path: '/osa-cinema', selector: '.osa-cinema' },
  { name: 'games', path: '/games/', selector: 'header' },
  { name: 'skillcred', path: '/skillcred/', selector: '.site-header' },
  { name: 'entertainment', path: '/entertainment/', selector: 'header' },
  { name: 'elbrus', path: '/entertainment/elbrus/', selector: 'main' },
  { name: 'elbrus-en', path: '/entertainment/elbrus/en/', selector: 'main' },
  { name: 'elbrus-ar', path: '/entertainment/elbrus/ar/', selector: 'main' },
  { name: 'tedes-studio', path: '/tedes/', selector: 'body' },
  { name: 'tedes-catalog', path: '/tedes/catalog/', selector: 'body' },
  { name: 'tedes-collections', path: '/tedes/collections/', selector: 'body' },
  { name: 'tedes-product', path: '/tedes/product/', selector: 'body' },
  { name: 'tedes-materials', path: '/tedes/materials/', selector: 'body' },
  { name: 'tedes-project', path: '/tedes/project/', selector: 'body' },
  { name: 'tedes-print', path: '/tedes/print/', selector: 'body' },
  { name: 'tedes-case', path: '/development/tedes/', selector: 'body' },
  { name: 'merakki-case', path: '/development/merakki/', selector: 'body' },
  { name: 'merakki-en', path: '/development/merakki/en/', selector: 'body' },
  { name: 'merakki-ar', path: '/development/merakki/ar/', selector: 'body' }
]

const problems = []
const screenshots = []
const browser = await chromium.launch({ headless: true })
try {
  for (const viewport of viewports) {
    const context = await browser.newContext({
      viewport: { width: viewport.width, height: viewport.height },
      reducedMotion: 'reduce'
    })
    await context.addInitScript(() => {
      try { sessionStorage.setItem('osgard-preloader-seen-v3', '1') } catch {}
    })

    for (const route of routes) {
      const page = await context.newPage()
      const pageErrors = []
      page.on('pageerror', error => pageErrors.push(error.message))
      let response = null
      try {
        response = await page.goto(base + route.path, { waitUntil: 'domcontentloaded', timeout: 25000 })
        if (!response || response.status() >= 400) {
          problems.push(route.name + ' @ ' + viewport.name + ': HTTP ' + (response?.status() ?? 'no response'))
        }

        await page.locator(route.selector).first().waitFor({ state: 'attached', timeout: 12000 })
        await page.waitForTimeout(180)
        const title = await page.title()
        if (!title.trim()) problems.push(route.name + ' @ ' + viewport.name + ': empty document title')

        const dimensions = await page.evaluate(() => ({
          viewport: window.innerWidth,
          document: document.documentElement.scrollWidth,
          body: document.body?.scrollWidth ?? 0
        }))
        if (dimensions.document > dimensions.viewport + 2 || dimensions.body > dimensions.viewport + 2) {
          const offenders = await page.evaluate(() => Array.from(document.querySelectorAll('body *')).map(element => {
            const rect = element.getBoundingClientRect()
            const style = getComputedStyle(element)
            return {
              tag: element.tagName.toLowerCase(),
              id: element.id || '',
              className: typeof element.className === 'string' ? element.className.slice(0, 100) : '',
              left: Math.round(rect.left * 10) / 10,
              right: Math.round(rect.right * 10) / 10,
              width: Math.round(rect.width * 10) / 10,
              scrollWidth: element.scrollWidth,
              clientWidth: element.clientWidth,
              position: style.position,
              whiteSpace: style.whiteSpace,
              overflowX: style.overflowX
            }
          }).filter(item => item.width > 0 && (item.right > window.innerWidth + 2 || item.left < -2 || item.scrollWidth > item.clientWidth + 2))
            .sort((a, b) => Math.max(b.right - window.innerWidth, b.scrollWidth - b.clientWidth) - Math.max(a.right - window.innerWidth, a.scrollWidth - a.clientWidth))
            .slice(0, 40))
          problems.push(route.name + ' @ ' + viewport.name + ': horizontal overflow ' + JSON.stringify({ ...dimensions, offenders }))
        }
        if (route.name === 'elbrus-ar' || route.name === 'merakki-ar') {
          const arabic = await page.evaluate(() => ({ lang: document.documentElement.lang, dir: document.documentElement.dir }))
          if (arabic.lang !== 'ar' || arabic.dir !== 'rtl') problems.push(route.name + ' @ ' + viewport.name + ': expected lang=ar and dir=rtl')
        }
        if (route.name === 'merakki-en') {
          const english = await page.evaluate(() => document.documentElement.lang)
          if (english !== 'en') problems.push('MERAKKI English @ ' + viewport.name + ': expected lang=en')
        }
        if (viewport.name === 'mobile' && route.name === 'portal') {
          const introCount = await page.locator('.osa5-intro').count()
          if (introCount !== 0) problems.push('portal @ mobile: reduced-motion preference did not skip intro')
        }

        const screenshot = resolve(output, viewport.name + '-' + route.name + '.png')
        await page.screenshot({ path: screenshot, animations: 'disabled' })
        screenshots.push(viewport.name + '-' + route.name + '.png')
        for (const message of pageErrors) problems.push(route.name + ' @ ' + viewport.name + ': uncaught page error: ' + message)
      } catch (error) {
        problems.push(route.name + ' @ ' + viewport.name + ': ' + String(error?.message || error))
        try {
          const screenshot = resolve(output, viewport.name + '-' + route.name + '-failure.png')
          await page.screenshot({ path: screenshot, animations: 'disabled' })
          screenshots.push(viewport.name + '-' + route.name + '-failure.png')
        } catch {}
      } finally {
        await page.close()
      }
    }
    await context.close()
  }

  // Real browser interaction: lecture search and act filters must compose, preserve lesson links, and expose empty results.
  const lectureContext = await browser.newContext({
    viewport: { width: 390, height: 844 },
    reducedMotion: 'reduce'
  })
  await lectureContext.addInitScript(() => {
    try { sessionStorage.setItem('osgard-preloader-seen-v3', '1') } catch {}
  })
  const lecturePage = await lectureContext.newPage()
  try {
    const pageErrors = []
    lecturePage.on('pageerror', error => pageErrors.push(error.message))
    await lecturePage.goto(base + '/lectures', { waitUntil: 'domcontentloaded', timeout: 25000 })
    const rows = lecturePage.locator('.lecture-row')
    await rows.first().waitFor({ state: 'visible', timeout: 8000 })
    if (await rows.count() !== 8) problems.push('lectures search: expected eight lesson rows before filtering')

    const search = lecturePage.locator('.lecture-search input')
    await search.fill('privacy')
    const privacyRows = await rows.count()
    const privacyTexts = await rows.locator('.lecture-row-copy').allTextContents()
    if (privacyRows === 0 || privacyRows >= 8 || privacyTexts.some(text => !text.toLocaleLowerCase().includes('privacy'))) {
      problems.push('lectures search: keyword search did not restrict rows to matching lesson content')
    }

    await lecturePage.getByRole('button', { name: 'Все акты' }).click()
    if (await lecturePage.getByRole('button', { name: 'Все акты' }).getAttribute('aria-pressed') !== 'true') {
      problems.push('lectures search: selecting all acts did not update aria-pressed')
    }
    await lecturePage.getByRole('button', { name: 'Акт III' }).click()
    const actThreeCount = await rows.count()
    if (await lecturePage.getByRole('button', { name: 'Акт III' }).getAttribute('aria-pressed') !== 'true' || actThreeCount === 0 || actThreeCount >= 8) {
      problems.push('lectures search: act filter did not narrow results or expose its selected state')
    }

    await search.fill('no-result-token-qz')
    await lecturePage.locator('.lecture-empty-state').waitFor({ state: 'visible', timeout: 3000 })
    await lecturePage.getByRole('button', { name: 'Очистить поиск' }).click()
    await lecturePage.getByRole('button', { name: 'Все акты' }).click()
    if (await rows.count() !== 8) problems.push('lectures search: clearing search and act filter did not restore the full catalogue')
    for (const message of pageErrors) problems.push('lectures search @ mobile: uncaught page error: ' + message)
    await lecturePage.screenshot({ path: resolve(output, 'mobile-lectures-search-filtered.png'), animations: 'disabled' })
    screenshots.push('mobile-lectures-search-filtered.png')
  } catch (error) {
    problems.push('lecture catalogue search/filter browser interaction: ' + String(error?.message || error))
    try {
      await lecturePage.screenshot({ path: resolve(output, 'mobile-lectures-search-failure.png'), animations: 'disabled' })
      screenshots.push('mobile-lectures-search-failure.png')
    } catch {}
  } finally {
    await lectureContext.close()
  }

  // Real browser navigation: a cross-profile click shows the one-shot overlay, then consumes its intent.
  const transitionContext = await browser.newContext({
    viewport: { width: 1280, height: 800 },
    reducedMotion: 'reduce'
  })
  await transitionContext.addInitScript(() => {
    try { sessionStorage.setItem('osgard-preloader-seen-v3', '1') } catch {}
    const observer = new MutationObserver(() => {
      if (document.querySelector('.osa5-transition-overlay')) {
        window.__osa5TransitionSeen = true
        observer.disconnect()
      }
    })
    observer.observe(document, { childList: true, subtree: true })
  })
  const transitionPage = await transitionContext.newPage()
  try {
    await transitionPage.goto(base + '/games/', { waitUntil: 'domcontentloaded', timeout: 25000 })
    const brandLink = transitionPage.locator('header a.brand[href="/"]').first()
    await brandLink.waitFor({ state: 'visible', timeout: 5000 })
    await Promise.all([
      transitionPage.waitForURL(url => url.pathname === '/', { timeout: 12000 }),
      brandLink.click()
    ])
    await transitionPage.waitForFunction(() => window.__osa5TransitionSeen === true, null, { timeout: 5000 })
    const intentConsumed = await transitionPage.evaluate(() => sessionStorage.getItem('osgard.osa5.transition.v1') === null)
    if (!intentConsumed) problems.push('transition: one-shot navigation intent was not consumed on the destination')
    await transitionPage.locator('.osa5-transition-overlay').waitFor({ state: 'detached', timeout: 3000 })
    await transitionPage.reload({ waitUntil: 'domcontentloaded' })
    await transitionPage.waitForTimeout(180)
    const replayCount = await transitionPage.locator('.osa5-transition-overlay').count()
    if (replayCount !== 0) problems.push('transition: overlay replayed after its one-shot intent was consumed')
  } catch (error) {
    problems.push('cross-portal transition integration: ' + String(error?.message || error))
  } finally {
    await transitionContext.close()
  }

  // Browser-level check for the current ELBRUS TABLE OS concept: bounded local state and reset.
  const tableContext = await browser.newContext({
    viewport: { width: 1280, height: 800 },
    reducedMotion: 'reduce'
  })
  await tableContext.addInitScript(() => {
    try { sessionStorage.setItem('osgard-preloader-seen-v3', '1') } catch {}
  })
  const tablePage = await tableContext.newPage()
  try {
    await tablePage.goto(base + '/entertainment/elbrus/en/', { waitUntil: 'domcontentloaded', timeout: 25000 })
    await tablePage.locator('#table-session-demo').waitFor({ state: 'visible', timeout: 8000 })
    const guests = tablePage.locator('#table-guest-count')
    const plus = tablePage.locator('[data-guest-step="1"]')
    const initial = Number((await guests.textContent() || '').trim())
    if (initial !== 4) problems.push('ELBRUS TABLE OS: expected four initial demo guests; got ' + initial)
    await plus.click()
    await tablePage.locator('[data-guest-join]').click()
    const afterJoin = Number((await guests.textContent() || '').trim())
    if (afterJoin !== 6) problems.push('ELBRUS TABLE OS: guest controls did not update local count')
    await tablePage.locator('[data-table-budget="500"]').click()
    await tablePage.locator('[data-table-occasion="celebration"]').click()
    if (await tablePage.locator('[data-table-budget="500"]').getAttribute('aria-pressed') !== 'true') {
      problems.push('ELBRUS TABLE OS: budget selection did not update its accessible state')
    }
    if (await tablePage.locator('[data-table-occasion="celebration"]').getAttribute('aria-pressed') !== 'true') {
      problems.push('ELBRUS TABLE OS: occasion selection did not update its accessible state')
    }
    await plus.click()
    await plus.click()
    if (Number((await guests.textContent() || '').trim()) !== 8 || !(await plus.isDisabled())) {
      problems.push('ELBRUS TABLE OS: guest count must remain bounded at eight')
    }
    await tablePage.locator('[data-guest-join]').click()
    if (Number((await guests.textContent() || '').trim()) !== 8) {
      problems.push('ELBRUS TABLE OS: simulated join exceeded the eight-guest ceiling')
    }
    await tablePage.locator('[data-table-reset]').click()
    if (Number((await guests.textContent() || '').trim()) !== 4) problems.push('ELBRUS TABLE OS: reset did not restore four guests')
    if (await tablePage.locator('[data-table-budget="800"]').getAttribute('aria-pressed') !== 'true') {
      problems.push('ELBRUS TABLE OS: reset did not restore the default budget')
    }
    if (await tablePage.locator('[data-table-occasion="family"]').getAttribute('aria-pressed') !== 'true') {
      problems.push('ELBRUS TABLE OS: reset did not restore the default occasion')
    }
    const disclosure = await tablePage.locator('#table-session-notice').textContent() || ''
    if (!/not send|does not|doesn't|no real|не отправ|не брониру/i.test(disclosure)) {
      problems.push('ELBRUS TABLE OS: demo-only disclosure is missing from the rendered page')
    }

    await tablePage.locator('#table-session-demo').scrollIntoViewIfNeeded()
    let tableDimensions = await tablePage.evaluate(() => ({
      viewport: window.innerWidth,
      document: document.documentElement.scrollWidth,
      body: document.body?.scrollWidth ?? 0
    }))
    if (tableDimensions.document > tableDimensions.viewport + 2 || tableDimensions.body > tableDimensions.viewport + 2) {
      problems.push('ELBRUS TABLE OS @ desktop: horizontal overflow ' + JSON.stringify(tableDimensions))
    }
    await tablePage.screenshot({ path: resolve(output, 'desktop-elbrus-table-session-interactive.png'), animations: 'disabled' })
    screenshots.push('desktop-elbrus-table-session-interactive.png')

    await tablePage.setViewportSize({ width: 390, height: 844 })
    await tablePage.locator('#table-session-demo').scrollIntoViewIfNeeded()
    await tablePage.waitForTimeout(100)
    tableDimensions = await tablePage.evaluate(() => ({
      viewport: window.innerWidth,
      document: document.documentElement.scrollWidth,
      body: document.body?.scrollWidth ?? 0
    }))
    if (tableDimensions.document > tableDimensions.viewport + 2 || tableDimensions.body > tableDimensions.viewport + 2) {
      problems.push('ELBRUS TABLE OS @ mobile: horizontal overflow ' + JSON.stringify(tableDimensions))
    }
    await tablePage.screenshot({ path: resolve(output, 'mobile-elbrus-table-session-interactive.png'), animations: 'disabled' })
    screenshots.push('mobile-elbrus-table-session-interactive.png')
  } catch (error) {
    problems.push('ELBRUS TABLE OS browser interaction: ' + String(error?.message || error))
  } finally {
    await tableContext.close()
  }

  // Keyboard contract for the normal-motion intro: focus starts on Skip, Tab stays within the modal, Escape dismisses it.
  const modalContext = await browser.newContext({
    viewport: { width: 1280, height: 800 },
    reducedMotion: 'no-preference'
  })
  const modalPage = await modalContext.newPage()
  try {
    await modalPage.goto(base + '/portal', { waitUntil: 'domcontentloaded', timeout: 25000 })
    const dialog = modalPage.locator('.osa5-intro')
    await dialog.waitFor({ state: 'visible', timeout: 5000 })
    const initiallyFocused = await modalPage.evaluate(() => Boolean(document.activeElement?.matches('.osa5-intro-controls button')))
    if (!initiallyFocused) problems.push('intro: initial keyboard focus is not on Skip')
    await modalPage.keyboard.press('Tab')
    const focusContained = await modalPage.evaluate(() => Boolean(document.activeElement?.closest('.osa5-intro')))
    if (!focusContained) problems.push('intro: Tab escaped the modal')
    await modalPage.keyboard.press('Escape')
    await dialog.waitFor({ state: 'hidden', timeout: 5000 })
  } catch (error) {
    problems.push('intro keyboard contract: ' + String(error?.message || error))
  } finally {
    await modalContext.close()
  }
} finally {
  await browser.close()
}

console.log(JSON.stringify({
  status: problems.length ? 'FAIL' : 'PASS',
  base,
  viewports: viewports.map(item => item.name),
  routeCount: routes.length,
  screenshotCount: screenshots.length,
  screenshots,
  problems
}, null, 2))
assert.equal(problems.length, 0, 'Responsive visual QA found regressions; review the OSA screenshot artifact')
