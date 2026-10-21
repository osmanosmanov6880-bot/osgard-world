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
  { name: 'world', path: '/', selector: '.world-home', heading: /ТЕХНОЛОГИИ|Цифровые продукты/i, product: 'OSGARD' },
  { name: 'intelligence', path: '/intelligence', selector: '.intelligence-home', heading: /Понимать ИИ/, product: 'Intelligence' },
  { name: 'play', path: '/play', selector: '.play-home', heading: /ДОБАВЬ ТЕНЬ/, product: 'Play' },
  { name: 'portal', path: '/portal', selector: '.world-home', heading: /ТЕХНОЛОГИИ|Цифровые продукты/i, product: 'OSGARD' },
  { name: 'academy', path: '/academy', selector: '.academy-learning-console', heading: /Понимайте ИИ/, product: 'Intelligence' },
  { name: 'lectures', path: '/lectures', selector: '.lecture-library' },
  { name: 'lesson-detail', path: '/lectures/intelligence-and-imitation', selector: '.osa-lesson-page' },
  { name: 'media-library', path: '/osa-library/', selector: '.hero' },
  { name: 'cinema', path: '/osa-cinema', selector: '.osa-cinema' },
  { name: 'games', path: '/games/', selector: '#catalog' },
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
      const stylesheetRequests = []
      if (route.name === 'skillcred') {
        page.on('request', request => {
          if (request.resourceType() === 'stylesheet') stylesheetRequests.push(new URL(request.url()).pathname)
        })
      }
      let response = null
      try {
        response = await page.goto(base + route.path, { waitUntil: 'domcontentloaded', timeout: 25000 })
        if (!response || response.status() >= 400) {
          problems.push(route.name + ' @ ' + viewport.name + ': HTTP ' + (response?.status() ?? 'no response'))
        }

        await page.locator(route.selector).first().waitFor({ state: 'attached', timeout: 12000 })
        await page.waitForTimeout(180)
        if (route.heading) {
          await page.getByRole('heading', { level: 1, name: route.heading }).waitFor({ state: 'visible', timeout: 5000 })
          const products = page.getByRole('navigation', { name: 'Продукты OSGARD', exact: true })
          for (const [name, href] of [['OSGARD', '/'], ['Intelligence', '/intelligence'], ['Play', '/play'], ['Development', '/development']]) {
            const link = products.getByRole('link', { name, exact: true })
            if (await link.getAttribute('href') !== href) problems.push(route.name + ': missing product route ' + name)
          }
          const current = await products.getByRole('link', { name: route.product, exact: true }).getAttribute('aria-current')
          if (!['page', 'location'].includes(current)) problems.push(route.name + ': active product is not exposed in navigation')
        }
        const title = await page.title()
        if (!title.trim()) problems.push(route.name + ' @ ' + viewport.name + ': empty document title')

        if (route.name === 'skillcred') {
          const stylesheets = await page.evaluate(() => Array.from(document.styleSheets)
            .filter(sheet => sheet.href)
            .map(sheet => ({ path: new URL(sheet.href).pathname, rules: sheet.cssRules.length })))
          assert.deepEqual(stylesheetRequests, ['/skillcred/styles.css'], 'SkillCred must request one bundled stylesheet without a separate portal stylesheet')
          assert.deepEqual(stylesheets.map(sheet => sheet.path), ['/skillcred/styles.css'], 'SkillCred must apply only the main stylesheet bundle')
          assert.ok(stylesheets[0].rules > 0, 'SkillCred stylesheet bundle must load and expose parsed CSS rules')

          if (viewport.name === 'mobile') {
            const menu = page.locator('#menuToggle')
            const navigation = page.locator('#primaryNav')
            await navigation.waitFor({ state: 'hidden', timeout: 3000 })
            assert.equal(await menu.getAttribute('aria-expanded'), 'false', 'SkillCred mobile menu must start collapsed')
            await menu.click()
            await navigation.waitFor({ state: 'visible', timeout: 3000 })
            assert.equal(await menu.getAttribute('aria-expanded'), 'true', 'SkillCred mobile menu must expose its open state')
            await menu.click()
            await navigation.waitFor({ state: 'hidden', timeout: 3000 })
            assert.equal(await menu.getAttribute('aria-expanded'), 'false', 'SkillCred mobile menu must collapse again')
            await menu.evaluate(element => element.blur())
          }
        }

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
          const motion = page.getByRole('button', { name: 'Меньше движения', exact: true })
          if (!(await motion.isDisabled()) || (await motion.getAttribute('aria-pressed')) !== 'true') {
            problems.push('portal @ mobile: system reduced-motion preference did not disable optional motion')
          }
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
    await search.fill('первоисточник')
    const sourceRows = await rows.count()
    const sourceTexts = await rows.locator('.lecture-row-copy').allTextContents()
    if (sourceRows === 0 || sourceRows >= 8 || sourceTexts.some(text => !text.toLocaleLowerCase().includes('первоисточник'))) {
      problems.push('lectures search: keyword search did not restrict rows to matching lesson content')
    }
    await lecturePage.getByRole('button', { name: 'Очистить поиск' }).click()

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
    reducedMotion: 'no-preference'
  })
  await transitionContext.addInitScript(() => {
    try { sessionStorage.setItem('osgard-preloader-seen-v3', '1') } catch {}
    const observer = new MutationObserver(() => {
      if (document.querySelector('.osgard-portal-transition')) {
        window.__osa5TransitionSeen = true
        observer.disconnect()
      }
    })
    observer.observe(document, { childList: true, subtree: true })
  })
  const transitionPage = await transitionContext.newPage()
  try {
    await transitionPage.goto(base + '/play', { waitUntil: 'domcontentloaded', timeout: 25000 })
    const brandLink = transitionPage.getByRole('navigation', { name: 'Продукты OSGARD', exact: true }).getByRole('link', { name: 'OSGARD', exact: true })
    await brandLink.waitFor({ state: 'visible', timeout: 5000 })
    await Promise.all([
      transitionPage.waitForURL(url => url.pathname === '/', { timeout: 12000 }),
      brandLink.click()
    ])
    await transitionPage.waitForFunction(() => window.__osa5TransitionSeen === true, null, { timeout: 5000 })
    const intentConsumed = await transitionPage.evaluate(() => sessionStorage.getItem('osgard:portal-navigation:v2') === null)
    if (!intentConsumed) problems.push('transition: one-shot navigation intent was not consumed on the destination')
    await transitionPage.locator('.osgard-portal-transition').waitFor({ state: 'detached', timeout: 3000 })
    await transitionPage.reload({ waitUntil: 'domcontentloaded' })
    await transitionPage.waitForTimeout(180)
    const replayCount = await transitionPage.locator('.osgard-portal-transition').count()
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

  // Keyboard and motion controls for the current shared product shell.
  const accessibilityContext = await browser.newContext({
    viewport: { width: 1280, height: 800 },
    reducedMotion: 'no-preference'
  })
  const accessibilityPage = await accessibilityContext.newPage()
  try {
    await accessibilityPage.goto(base + '/', { waitUntil: 'domcontentloaded', timeout: 25000 })
    await accessibilityPage.getByRole('heading', { level: 1, name: /ТЕХНОЛОГИИ|Цифровые продукты/i }).waitFor({ state: 'visible', timeout: 8000 })
    await accessibilityPage.keyboard.press('Tab')
    const skipFocused = await accessibilityPage.evaluate(() => document.activeElement?.matches('.brand-skip') === true)
    if (!skipFocused) problems.push('keyboard: first Tab did not focus the skip link')
    const skipVisible = await accessibilityPage.locator('.brand-skip').evaluate(element => element.getBoundingClientRect().top >= 0)
    if (!skipVisible) problems.push('keyboard: focused skip link is not visible in the viewport')
    await accessibilityPage.keyboard.press('Enter')
    await accessibilityPage.waitForFunction(() => location.hash === '#product-main', null, { timeout: 5000 })
    const motion = accessibilityPage.getByRole('button', { name: 'Меньше движения', exact: true })
    await motion.click()
    await accessibilityPage.waitForFunction(() => document.documentElement.dataset.motion === 'off')
    if ((await motion.getAttribute('aria-pressed')) !== 'true' ||
        await accessibilityPage.evaluate(() => localStorage.getItem('osgard:motion')) !== 'off') {
      problems.push('motion: user control did not turn optional animation off')
    }
    await accessibilityPage.reload({ waitUntil: 'domcontentloaded' })
    await motion.waitFor({ state: 'visible', timeout: 8000 })
    if ((await motion.getAttribute('aria-pressed')) !== 'true') problems.push('motion: preference did not survive reload')
    await motion.click()
    await accessibilityPage.waitForFunction(() => document.documentElement.dataset.motion === 'on')
    if ((await motion.getAttribute('aria-pressed')) !== 'false' ||
        await accessibilityPage.evaluate(() => localStorage.getItem('osgard:motion')) !== 'on') {
      problems.push('motion: user control did not restore optional animation')
    }
  } catch (error) {
    problems.push('product shell keyboard and motion controls: ' + String(error?.message || error))
  } finally {
    await accessibilityContext.close()
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
