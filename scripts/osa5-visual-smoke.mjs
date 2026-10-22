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
  { name: 'intelligence', path: '/intelligence', selector: '.intelligence-proof-console', heading: /Понимать ИИ/, product: 'Intelligence' },
  { name: 'development', path: '/development', selector: '.signature-showcase', heading: /СОЗДАЁМ/, product: 'Development' },
  { name: 'play', path: '/play', selector: '.play-universe', heading: /^OSGARD\s*Play$/, product: 'Play' },
  { name: 'portal', path: '/portal', selector: '.world-home', heading: /ТЕХНОЛОГИИ|Цифровые продукты/i, product: 'OSGARD' },
  { name: 'academy', path: '/academy', selector: '.academy-learning-console', heading: /Понимайте ИИ/, product: 'Intelligence' }
  { name: 'lectures', path: '/lectures', selector: '.lecture-library' },
  { name: 'lesson-detail', path: '/lectures/intelligence-and-imitation', selector: '.osa-lesson-page' },
  { name: 'media-library', path: '/osa-library/', selector: '.hero' },
  { name: 'cinema', path: '/osa-cinema', selector: '.osa-cinema' },
  { name: 'games', path: '/games/', selector: '#catalog' },
  { name: 'skillcred', path: '/skillcred/', selector: '.site-header' },
  { name: 'entertainment', path: '/entertainment/', selector: 'header' },
  { name: 'entertainment-archive', path: '/entertainment/archive/', selector: '.entertainment-premium .hero-spotlight' },
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

// Observe real mounts without changing animation clocks, navigation or product state.
// Short transitions may finish between Playwright round trips; retain their DOM evidence.
function observeCinematics() {
  window.__osa5CinematicTrace = []
  window.__osa5PendingSeen = false
  window.__osa5DocumentToken = Math.random().toString(36).slice(2)
  const mounted = new Map()
  new MutationObserver(() => {
    if (document.querySelector('[data-osgard-pending]')) window.__osa5PendingSeen = true
    for (const element of document.querySelectorAll('.osgard-cinematic')) {
      if (mounted.has(element)) continue
      const style = getComputedStyle(element)
      const content = document.querySelector('[data-osgard-content]')
      const record = {
        kind: element.dataset.kind, path: location.pathname,
        startedAt: performance.now(), endedAt: null,
        role: element.getAttribute('role'), modal: element.getAttribute('aria-modal'),
        inert: content?.inert === true, hidden: content?.getAttribute('aria-hidden'),
        animation: style.animationName, duration: parseFloat(style.animationDuration),
        portal: Boolean(element.querySelector('.oc-portal-depth'))
      }
      mounted.set(element, record)
      window.__osa5CinematicTrace.push(record)
    }
    for (const [element, record] of mounted) {
      if (!element.isConnected) {
        record.endedAt = performance.now()
        mounted.delete(element)
      }
    }
  }).observe(document, { childList: true, subtree: true })
}

async function waitForCinematicRelease(page, replay = false) {
  try {
    await page.waitForFunction(isReplay => {
      const content = document.querySelector('[data-osgard-content]')
      const focus = document.activeElement
      return !document.querySelector('.osgard-cinematic, [data-osgard-pending]') &&
        !document.documentElement.hasAttribute('data-osgard-cinematic') &&
        content?.inert === false && content.getAttribute('aria-hidden') !== 'true' &&
        (isReplay ? focus?.textContent?.trim() === 'Повторить заставку' : focus?.id === 'product-main')
    }, replay, { timeout: 2500 })
  } catch (error) {
    // Preserve meaningful evidence when the overlay is gone but keyboard focus
    // did not recover; an anonymous timeout hides genuine accessibility bugs.
    const state = await page.evaluate(() => {
      const active = document.activeElement
      const content = document.querySelector('[data-osgard-content]')
      const trigger = Array.from(document.querySelectorAll('button')).find(button => button.textContent?.trim() === 'Повторить заставку')
      return {
        path: location.pathname,
        focus: { tag: active?.tagName, id: active?.id, text: active?.textContent?.trim().slice(0, 80),
          disabled: active instanceof HTMLButtonElement && active.disabled },
        mainConnected: document.getElementById('product-main')?.isConnected,
        contentInert: content?.inert, contentHidden: content?.getAttribute('aria-hidden'),
        overlayCount: document.querySelectorAll('.osgard-cinematic, [data-osgard-pending]').length,
        htmlCinematic: document.documentElement.dataset.osgardCinematic ?? null,
        replayDisabled: trigger?.disabled, replayIsFocused: trigger === active,
        latestSession: window.__osa5CinematicTrace?.at(-1) ?? null,
      }
    }).catch(cause => ({ evaluateError: String(cause) }))
    throw new Error('Cinematic release/focus mismatch: ' + JSON.stringify({ replay, state, reason: String(error) }))
  }
}

async function assertNaturalCinematic(page, index, kind, path) {
  await page.waitForFunction(position => window.__osa5CinematicTrace[position]?.endedAt !== null &&
    window.__osa5CinematicTrace[position]?.endedAt !== undefined, index, { timeout: 6000 })
  const record = await page.evaluate(position => window.__osa5CinematicTrace[position], index)
  assert.equal(record.kind, kind, 'Cinematic kind must match the actual navigation')
  assert.equal(record.path, path, 'Cinematic must cover the destination route')
  assert.equal(record.role, 'dialog', 'Cinematic must expose a dialog')
  assert.equal(record.modal, 'true', 'Cinematic must expose modal state')
  assert.equal(record.inert, true, 'Background must be inert while the cinematic is mounted')
  assert.equal(record.hidden, 'true', 'Background must be hidden from the accessibility tree')
  assert.equal(record.portal, kind === 'play', 'Portal depth must appear only on entry to Play')
  assert.equal(record.animation, kind === 'intro' ? 'oc-intro-lifetime' : 'oc-transition-lifetime')
  const seconds = kind === 'intro' ? 3.6 : 0.9
  assert.equal(record.duration, seconds, 'Cinematic CSS must retain its finite timeline')
  assert.ok(record.endedAt - record.startedAt >= seconds * 1000 - 250, 'Cinematic ended before its visual timeline completed')
  assert.ok(record.endedAt - record.startedAt <= seconds * 1000 + 1500, 'Cinematic exceeded its completion deadline')
  await waitForCinematicRelease(page)
}

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
    await context.addInitScript(observeCinematics)

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
          assert.equal(await page.evaluate(() => window.__osa5CinematicTrace.length), 0, 'Reduced motion must bypass cinematic mounts')
          assert.equal(await page.evaluate(() => window.__osa5PendingSeen), false, 'Reduced motion must bypass the pending intro')
          assert.equal(await page.locator('[data-osgard-content]').evaluate(element => element.inert), false, 'Reduced motion must leave the page interactive')
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

        if (route.name === 'play') {
          await page.waitForFunction(() => {
            const image = document.querySelector('.cp-hero-art img')
            return image?.complete && image.naturalWidth > 0
          }, null, { timeout: 8000 })
          const heroSource = await page.locator('.cp-hero-art img').evaluate(image => new URL(image.currentSrc).pathname)
          assert.match(heroSource, viewport.width <= 600 ? /\/hero-mobile(?:-780)?\.webp$/ : /\/hero-megacity(?:-1280|-1920)?\.webp$/, 'Hero must load the appropriate desktop or mobile composition')
          assert.match(await page.locator('.cp-hero-slogan').innerText(), /ИГРЫ\. МИРЫ\.\s*ТЫ ВНУТРИ\./)
          assert.equal(await page.getByRole('link', { name: 'Исследовать миры', exact: true }).getAttribute('href'), '#featured')
          const trailer = page.getByRole('button', { name: 'Смотреть трейлер', exact: true })
          assert.equal(await trailer.isDisabled(), true, 'Unpublished trailer must not pretend to play')
          assert.equal(await trailer.getAttribute('aria-describedby'), 'trailer-status')
          assert.match(await page.locator('#trailer-status').innerText(), /Трейлер пока не опубликован/)
        }

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
        if (route.name === 'play') {
          // Request the real lazy catalogue through its visible link after capturing the hero.
          await page.locator('.cp-glass-panel a[href="#catalog"]').click()
          await page.locator('#catalog').waitFor({ state: 'visible', timeout: 8000 })
          await page.waitForFunction(() => document.querySelectorAll('#catalog .play-card[data-world-id]').length === 19, null, { timeout: 5000 })
          const ids = await page.locator('#catalog .play-card[data-world-id]').evaluateAll(cards => cards.map(card => card.dataset.worldId))
          assert.equal(new Set(ids).size, 19, 'Catalogue must expose 19 distinct real projects')
          for (const id of ['vector-zero', 'time', 'null-shift', 'zion-030']) assert.ok(ids.includes(id), 'Catalogue lost existing game ' + id)
          assert.equal(await page.locator('.play-universe iframe').count(), 0, 'Browsing the catalogue must not start an embedded game')
          assert.equal(await page.evaluate(() => window.__osa5CinematicTrace.length), 0, 'Reduced-motion catalogue navigation must not start a transition')
          const catalogFits = await page.evaluate(() => Math.max(document.documentElement.scrollWidth, document.body.scrollWidth) <= innerWidth + 2)
          assert.equal(catalogFits, true, 'The fully loaded catalogue must not overflow the viewport')
        }
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

  // First visit, finite intro, SPA transitions, replay and live reduced-motion changes.
  const transitionContext = await browser.newContext({
    viewport: { width: 1280, height: 800 },
    reducedMotion: 'no-preference'
  })
  await transitionContext.addInitScript(observeCinematics)
  const transitionPage = await transitionContext.newPage()
  const transitionErrors = []
  transitionPage.on('pageerror', error => transitionErrors.push(error.message))
  try {
    await transitionPage.goto(base + '/play', { waitUntil: 'domcontentloaded', timeout: 25000 })
    await transitionPage.locator('.osgard-cinematic[data-kind="intro"]').waitFor({ state: 'attached', timeout: 5000 })
    await transitionPage.waitForFunction(() => document.activeElement?.matches('.oc-skip') === true, null, { timeout: 2000 })
    for (const key of ['Tab', 'Shift+Tab']) {
      await transitionPage.keyboard.press(key)
      assert.equal(await transitionPage.evaluate(() => document.activeElement?.matches('.oc-skip')), true, 'Intro must trap keyboard focus in its skip control')
    }
    await transitionPage.waitForFunction(() => {
      const scene = document.querySelector('.osgard-cinematic[data-kind="intro"]')
      const letters = scene?.querySelectorAll('.oc-wordmark span')
      const images = scene?.querySelectorAll('img')
      return letters?.length === 6 && Array.from(letters).every(letter => Number(getComputedStyle(letter).opacity) > 0.9) &&
        images?.length === 2 && Array.from(images).every(image => image.complete && image.naturalWidth > 0)
    }, null, { timeout: 4000 })
    // Disabling finite CSS animations would emit animationend and falsify the lifecycle test.
    await transitionPage.screenshot({ path: resolve(output, 'desktop-osgard-intro.png'), animations: 'allow' })
    screenshots.push('desktop-osgard-intro.png')
    await assertNaturalCinematic(transitionPage, 0, 'intro', '/play')
    assert.equal(await transitionPage.evaluate(() => window.__osa5CinematicTrace.length), 1, 'A first visit must create exactly one intro')
    assert.equal(await transitionPage.evaluate(() => localStorage.getItem('osgard:intro:v1')), 'seen', 'First intro must persist the versioned once-only marker')
    assert.equal(await transitionPage.locator('.osgard-portal-transition').count(), 0, 'Legacy and global overlays must not compete')
    const documentToken = await transitionPage.evaluate(() => window.__osa5DocumentToken)

    for (const [name, path, kind] of [['OSGARD', '/', 'transition'], ['Play', '/play', 'play']]) {
      const index = await transitionPage.evaluate(() => window.__osa5CinematicTrace.length)
      const link = transitionPage.getByRole('navigation', { name: 'Продукты OSGARD', exact: true }).getByRole('link', { name, exact: true })
      await Promise.all([
        transitionPage.waitForURL(url => url.pathname === path, { timeout: 12000 }),
        link.click()
      ])
      assert.equal(await transitionPage.evaluate(() => window.__osa5DocumentToken), documentToken, 'Product navigation must preserve the SPA document')
      await assertNaturalCinematic(transitionPage, index, kind, path)
      assert.equal(await transitionPage.evaluate(() => window.__osa5CinematicTrace.length), index + 1, 'A product click must create exactly one transition')
      await transitionPage.getByRole('heading', { level: 1, name: path === '/play' ? /^OSGARD\s*Play$/ : /ТЕХНОЛОГИИ|Цифровые продукты/i }).waitFor({ state: 'visible', timeout: 5000 })
    }

    // A game detail is within Play: preserve the document without replaying the global portal.
    const beforeDetail = await transitionPage.evaluate(() => window.__osa5CinematicTrace.length)
    await Promise.all([
      transitionPage.waitForURL(url => url.pathname === '/play/world/vector-zero', { timeout: 12000 }),
      transitionPage.locator('#featured a[href^="/play/world/vector-zero"]').first().click()
    ])
    await transitionPage.getByRole('heading', { level: 1, name: 'VECTOR//ZERO', exact: true }).waitFor({ state: 'visible', timeout: 8000 })
    assert.equal(await transitionPage.evaluate(() => window.__osa5DocumentToken), documentToken, 'Opening a world must preserve the SPA document')
    assert.equal(await transitionPage.evaluate(() => window.__osa5CinematicTrace.length), beforeDetail, 'Same-section navigation must not replay the global portal')
    assert.equal(await transitionPage.locator('.play-game-detail iframe').count(), 0, 'A game must wait for an explicit launch')
    await Promise.all([
      transitionPage.waitForURL(url => url.pathname === '/play', { timeout: 12000 }),
      transitionPage.locator('.play-detail-back').first().click()
    ])
    await transitionPage.getByRole('heading', { level: 1, name: /^OSGARD\s*Play$/ }).waitFor({ state: 'visible', timeout: 8000 })
    assert.equal(await transitionPage.evaluate(() => window.__osa5CinematicTrace.length), beforeDetail, 'Returning to the catalogue must stay within Play')

    await transitionPage.reload({ waitUntil: 'domcontentloaded' })
    await transitionPage.getByRole('heading', { level: 1, name: /^OSGARD\s*Play$/ }).waitFor({ state: 'visible', timeout: 8000 })
    await transitionPage.waitForTimeout(180)
    assert.equal(await transitionPage.evaluate(() => window.__osa5CinematicTrace.length), 0, 'Reload must not repeat a seen intro')
    assert.equal(await transitionPage.evaluate(() => window.__osa5PendingSeen), false, 'Reload must not block content with a pending intro')
    assert.equal(await transitionPage.locator('[data-osgard-content]').evaluate(element => element.inert), false)

    const replay = transitionPage.getByRole('button', { name: 'Повторить заставку', exact: true })
    for (const action of ['escape', 'skip', 'reduce']) {
      await replay.click()
      await transitionPage.locator('.osgard-cinematic[data-kind="intro"]').waitFor({ state: 'attached', timeout: 5000 })
      if (action === 'escape') await transitionPage.keyboard.press('Escape')
      else if (action === 'skip') await transitionPage.getByRole('button', { name: 'Пропустить', exact: true }).click()
      else await transitionPage.emulateMedia({ reducedMotion: 'reduce' })
      await waitForCinematicRelease(transitionPage, action !== 'reduce')
    }
    const reducedCount = await transitionPage.evaluate(() => window.__osa5CinematicTrace.length)
    await Promise.all([
      transitionPage.waitForURL(url => url.pathname === '/', { timeout: 12000 }),
      transitionPage.getByRole('navigation', { name: 'Продукты OSGARD', exact: true }).getByRole('link', { name: 'OSGARD', exact: true }).click()
    ])
    await transitionPage.getByRole('heading', { level: 1, name: /ТЕХНОЛОГИИ|Цифровые продукты/i }).waitFor({ state: 'visible', timeout: 8000 })
    assert.equal(await transitionPage.evaluate(() => window.__osa5CinematicTrace.length), reducedCount, 'Reduced motion must bypass cross-product transitions')
    const motion = transitionPage.getByRole('button', { name: 'Меньше движения', exact: true })
    assert.equal(await motion.isDisabled(), true, 'Live system preference must disable the optional motion control')
    assert.equal(await motion.getAttribute('aria-pressed'), 'true')
  } catch (error) {
    problems.push('cinematic intro and SPA transition integration: ' + String(error?.message || error))
    try {
      await transitionPage.screenshot({ path: resolve(output, 'desktop-osgard-cinematic-failure.png'), animations: 'allow' })
      screenshots.push('desktop-osgard-cinematic-failure.png')
    } catch {}
  } finally {
    for (const message of transitionErrors) problems.push('cinematic integration: uncaught page error: ' + message)
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

  // Returning visitors start with the shell's skip link; first-visit focus is checked above.
  const accessibilityContext = await browser.newContext({
    viewport: { width: 1280, height: 800 },
    reducedMotion: 'no-preference'
  })
  await accessibilityContext.addInitScript(() => {
    localStorage.setItem('osgard:intro:v1', 'seen')
  })
  const accessibilityPage = await accessibilityContext.newPage()
  try {
    await accessibilityPage.goto(base + '/', { waitUntil: 'domcontentloaded', timeout: 25000 })
    await accessibilityPage.getByRole('heading', { level: 1, name: /ТЕХНОЛОГИИ|Цифровые продукты/i }).waitFor({ state: 'visible', timeout: 8000 })
    assert.equal(await accessibilityPage.locator('.osgard-cinematic, [data-osgard-pending]').count(), 0, 'A returning visitor must reach the keyboard navigation immediately')
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
