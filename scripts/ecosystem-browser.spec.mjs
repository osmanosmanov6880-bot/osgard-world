import { test, expect } from '@playwright/test'

const cinematicOverlay = '.osgard-cinematic, [data-osgard-pending]'

async function expectOsgardContentReady(page) {
  await expect(page.locator('[data-osgard-content]')).toHaveCount(1)
  await expect(page.locator(cinematicOverlay)).toHaveCount(0)
  await expect(page.locator('[data-osgard-content]')).not.toHaveAttribute('inert', '')
  await expect(page.locator('[data-osgard-content]')).not.toHaveAttribute('aria-hidden', 'true')
  await expect(page.locator('html')).not.toHaveAttribute('data-osgard-cinematic', /.+/)
}

async function openPlayCatalog(page) {
  // Use the actual catalogue destination; the primary hero action goes to featured worlds.
  await page.locator('.cp-glass-panel a[href="#catalog"]').click()
  await expect(page.locator('.cp-explore')).toHaveAttribute('data-explore-state', 'ready')
  await expect(page.locator('#catalog .play-card')).toHaveCount(19)
}

async function recordOsgardTransitions(page, returning = false) {
  await page.addInitScript(({ returning }) => {
    if (returning) localStorage.setItem('osgard:intro:v1', 'seen')
    const trace = { documentId: Math.random().toString(36), started: [], visuals: [] }
    window.__osgardBrowserTrace = trace
    let previous = null
    const observedVisuals = new WeakSet()
    // Observe real DOM lifecycle; do not replace the visual, its timers or route modules.
    new MutationObserver(records => {
      const kind = document.documentElement?.getAttribute('data-osgard-cinematic') || null
      if (kind && kind !== previous) trace.started.push(kind)
      previous = kind
      for (const record of records) for (const node of record.addedNodes) {
        if (!(node instanceof Element)) continue
        const visuals = [...node.querySelectorAll('.osgard-cinematic')]
        if (node.matches('.osgard-cinematic')) visuals.push(node)
        for (const visual of visuals) if (!observedVisuals.has(visual)) {
          observedVisuals.add(visual)
          trace.visuals.push(visual.getAttribute('data-kind'))
        }
      }
    }).observe(document, { childList: true, subtree: true, attributes: true, attributeFilter: ['data-osgard-cinematic'] })
  }, { returning })
}

const surfaces = [
  ['/', 'world', 'ТЕХНОЛОГИИ,'],
  ['/intelligence', 'intelligence', 'Понимать ИИ.'],
  ['/play', 'play', /OSGARD\s*Play/],
]

for (const [path, product, heading] of surfaces) {
  test(product + ': real layout, navigation and reduced motion', async ({ page }, info) => {
    if (product === 'play') test.slow() // Visit the real artwork before the full-page capture on mobile CI.
    const failures = []
    page.on('pageerror', error => failures.push(error.message))
    await page.goto(path)
    await expect(page.locator('h1')).toHaveCount(1)
    await expect(page.locator('h1')).toContainText(heading)
    await expect(page.locator('html')).toHaveAttribute('data-product', product)
    await expect(page.getByRole('navigation', { name: 'Продукты OSGARD' }).getByRole('link')).toHaveCount(4)
    expect(await page.evaluate(() => matchMedia('(prefers-reduced-motion: reduce)').matches)).toBe(true)
    await expect(page.getByRole('button', { name: 'Меньше движения', exact: true })).toBeDisabled()
    await expectOsgardContentReady(page)
    await expect(page.locator('#product-main')).toBeVisible()
    await page.evaluate(() => document.fonts.ready)
    const interFonts = await page.evaluate(async () => (await document.fonts.load('400 16px Inter', 'OSGARD Интерфейс')).map(font => font.status))
    expect(interFonts.length).toBeGreaterThan(0)
    expect(interFonts.every(status => status === 'loaded')).toBe(true)
    if (product === 'play') {
      await openPlayCatalog(page)
      // A full-page capture must contain the real sections and loaded artwork,
      // rather than the intentionally deferred below-fold placeholder.
      for (const img of await page.locator('.play-universe img').all()) {
        if (!await img.isVisible()) continue
        await img.scrollIntoViewIfNeeded()
        await expect.poll(() => img.evaluate(image => image.complete && image.naturalWidth > 0)).toBe(true)
      }
      await page.evaluate(() => scrollTo(0, 0))
    }
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true)
    await page.screenshot({ path: info.outputPath(product + '.png'), fullPage: true })
    expect(failures).toEqual([])
  })
}

test('OSGARD cinema, 3D world and hybrid controls are functional and keyboard-accessible', async ({ page }) => {
  // Multiple WebGL scene transitions and a full reload cost >30 seconds on
  // saturated mobile CI runners. Keep every real pointer and keyboard assertion.
  test.slow()
  const errors = []
  page.on('pageerror', error => errors.push(error.message))
  await page.emulateMedia({ reducedMotion: 'no-preference' })
  await page.goto('/')
  await expectOsgardContentReady(page)
  await page.locator('.omega-experience-panel summary').click()
  const hero = page.locator('.omega-hero')
  const mode = page.getByRole('group', { name: 'Выберите режим 3D-сцены' })

  await expect(hero).toHaveAttribute('data-omega-mode', 'hybrid')
  await expect(mode.getByRole('button', { name: 'Гибрид' })).toHaveAttribute('aria-pressed', 'true')
  await mode.getByRole('button', { name: 'Кино' }).click()
  await expect(hero).toHaveAttribute('data-omega-mode', 'cinema')
  await expect(page.getByRole('group', { name: 'Кинематографические главы' }).getByRole('button')).toHaveCount(3)
  await page.getByRole('button', { name: '03 / Миры' }).click()
  await expect(page.getByRole('button', { name: '03 / Миры' })).toHaveAttribute('aria-pressed', 'true')

  await mode.getByRole('button', { name: '3D-мир' }).click()
  await expect(hero).toHaveAttribute('data-omega-mode', 'world')
  await expect(hero).toHaveAttribute('data-omega-distance', '5.70')
  await page.getByRole('button', { name: 'Приблизить глобус' }).click()
  await expect(hero).toHaveAttribute('data-omega-distance', '5.28')
  const initialYaw = Number(await hero.getAttribute('data-omega-yaw'))
  await page.getByRole('button', { name: 'Повернуть Землю вправо' }).click()
  expect(Number(await hero.getAttribute('data-omega-yaw'))).toBeGreaterThan(initialYaw + 0.35)
  await hero.focus()
  await page.keyboard.press('ArrowLeft')
  expect(Number(await hero.getAttribute('data-omega-yaw'))).toBeCloseTo(initialYaw, 1)
  await page.getByRole('button', { name: 'Сбросить' }).click()
  await expect(hero).toHaveAttribute('data-omega-distance', '5.70')

  await page.reload()
  await page.locator('.omega-experience-panel summary').click()
  await expect(hero).toHaveAttribute('data-omega-mode', 'world')
  await mode.getByRole('button', { name: 'Гибрид' }).click()
  await expect(hero).toHaveAttribute('data-omega-mode', 'hybrid')
  await expect(page.getByRole('navigation', { name: 'Три направления экосистемы' }).getByRole('link')).toHaveCount(3)
  await page.getByRole('button', { name: 'Меньше движения', exact: true }).click()
  await expect(page.locator('html')).toHaveAttribute('data-motion', 'off')
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true)
  expect(errors).toEqual([])
})

test('OSGARD globe fails gracefully without WebGL2 and keeps the experience switcher', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'no-preference' })
  await page.addInitScript(() => {
    const base = HTMLCanvasElement.prototype.getContext
    HTMLCanvasElement.prototype.getContext = function(type, ...args) {
      if (type === 'webgl2') return null
      return base.call(this, type, ...args)
    }
  })
  await page.goto('/')
  await expectOsgardContentReady(page)
  await page.locator('.omega-experience-panel summary').click()
  await expect(page.locator('.omega-webgl-stage')).toHaveAttribute('data-globe-status', 'fallback', { timeout: 20000 })
  await expect(page.locator('.omega-globe')).toHaveCount(1)
  await page.getByRole('button', { name: 'Кино' }).click()
  await expect(page.locator('.omega-hero')).toHaveAttribute('data-omega-mode', 'cinema')
  await expect(page.getByRole('link', { name: /Исследовать экосистему/ })).toBeVisible()
})

test('OSGARD Earth GPU quality changes real texture detail with safe remount', async ({ page }) => {
  // Three GPU remounts include 4K textures and heavy mobile CI compositing.
  // Keep all quality assertions; only extend the test's wall-clock allowance.
  test.setTimeout(90_000)
  await page.emulateMedia({ reducedMotion: 'no-preference' })
  await page.goto('/')
  await expectOsgardContentReady(page)
  await page.locator('.omega-experience-panel summary').click()
  const picker = page.getByRole('combobox', { name: 'Качество 3D-глобуса' })
  const stage = page.locator('.omega-webgl-stage')
  await expect(picker).toHaveValue('auto')
  await expect(stage).toHaveAttribute('data-earth-texture', 'adaptive')
  await picker.selectOption('ultra')
  await expect(stage).toHaveAttribute('data-globe-quality', 'ultra')
  await expect(stage).toHaveAttribute('data-earth-texture', '4096')
  await expect(stage).toHaveAttribute('data-globe-status', /^(webgl|fallback)$/, { timeout: 25000 })
  if (await stage.getAttribute('data-globe-status') === 'webgl') {
    await expect(stage).toHaveAttribute('data-earth-cloud-mode', 'raymarched')
    await expect(stage).toHaveAttribute('data-earth-cloud-samples', /^(7|12)$/)
    await expect(stage).toHaveAttribute('data-earth-source', 'nasa')
  }
  await picker.selectOption('eco')
  await expect(stage).toHaveAttribute('data-earth-texture', '512')
  await expect(stage).toHaveAttribute('data-globe-status', /^(webgl|fallback)$/, { timeout: 25000 })
  if (await stage.getAttribute('data-globe-status') === 'webgl') {
    await expect(stage).toHaveAttribute('data-earth-cloud-mode', 'layered')
    await expect(stage).toHaveAttribute('data-earth-cloud-samples', '0')
  }
  await expect(page.locator('.omega-globe')).toHaveCount(1)
  await picker.selectOption('auto')
  await expect(stage).toHaveAttribute('data-globe-quality', 'auto')
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true)
})

test('OSGARD raymarched cloud scene retains navigation, motion fallback and on-screen actions', async ({ page }) => {
  // Software WebGL on shared CI can render the raymarched scene slowly.
  // Keep all visual/status assertions but allow its GPU work to complete.
  test.setTimeout(90_000)
  const errors = []
  page.on('pageerror', error => errors.push(error.message))
  await page.emulateMedia({ reducedMotion: 'no-preference' })
  await page.goto('/')
  await expectOsgardContentReady(page)
  await page.locator('.omega-experience-panel summary').click()
  const stage = page.locator('.omega-webgl-stage')
  await expect(stage).toHaveAttribute('data-globe-status', /^(webgl|fallback)$/, { timeout: 25000 })
  const hasWebGL2 = await page.evaluate(() => {
    const probe = document.createElement('canvas')
    return Boolean(probe.getContext('webgl2'))
  })
  if (hasWebGL2) {
    await expect(stage).toHaveAttribute('data-globe-status', 'webgl')
    const mobile = await page.evaluate(() => window.matchMedia('(max-width: 760px)').matches)
    await expect(stage).toHaveAttribute('data-earth-cloud-mode', mobile ? 'layered' : 'raymarched')
    if (!mobile) await expect(stage).toHaveAttribute('data-earth-cloud-samples', /^(4|7)$/)
  }
  await page.getByRole('button', { name: 'Кино', exact: true }).click()
  await page.getByRole('button', { name: '03 / Миры' }).click()
  await expect(page.getByRole('button', { name: '03 / Миры' })).toHaveAttribute('aria-pressed', 'true')
  await page.getByRole('button', { name: 'Меньше движения', exact: true }).click()
  await expect(page.locator('html')).toHaveAttribute('data-motion', 'off')
  await expect(page.locator('.omega-globe')).toHaveCount(1)
  await expect(page.locator('.omega-gate a')).toHaveCount(3)
  expect(errors).toEqual([])
})

test('World mobile navigation keeps one stable row after fonts load without hiding any destination', async ({ page }, info) => {
  test.skip(info.project.name !== 'mobile', 'The mobile navigation and its CLS risk are viewport-specific')
  await page.goto('/')
  const nav = page.getByRole('navigation', { name: 'Навигация раздела' })
  const links = nav.getByRole('link')
  await expect(links).toHaveCount(5)
  await page.evaluate(async () => { await document.fonts.ready })
  const layout = await nav.evaluate(node => {
    const boxes = [...node.querySelectorAll('a')].map(link => link.getBoundingClientRect())
    const style = getComputedStyle(node)
    return {
      flexWrap: style.flexWrap,
      overflowX: style.overflowX,
      tops: boxes.map(box => Math.round(box.top)),
      clientWidth: node.clientWidth,
      scrollWidth: node.scrollWidth,
      viewport: innerWidth,
      documentWidth: document.documentElement.scrollWidth,
    }
  })
  expect(layout.flexWrap).toBe('nowrap')
  expect(layout.overflowX).toBe('auto')
  expect(new Set(layout.tops).size, 'Font loading cannot wrap a World link onto a second navigation row').toBe(1)
  expect(layout.documentWidth).toBeLessThanOrEqual(layout.viewport + 1)
  const finalLink = nav.getByRole('link', { name: 'Контакт' })
  await finalLink.focus()
  await expect(finalLink).toBeFocused()
  await expect(finalLink).toHaveAttribute('href', '/#contact')
})

test('World Cosmic Portal makes real product routes obvious and keeps Earth settings accessible', async ({ page }) => {
  await page.goto('/')
  const hero = page.locator('.omega-command')
  await expect(hero).toBeVisible()
  await expect(hero.getByRole('heading', { level: 1, name: /ТЕХНОЛОГИИ,/ })).toBeVisible()
  const gateways = page.getByRole('navigation', { name: 'Три направления экосистемы' }).getByRole('link')
  await expect(gateways).toHaveCount(3)
  for (const [index, href] of ['/intelligence', '/play', '/development'].entries()) {
    await expect(gateways.nth(index)).toHaveAttribute('href', href)
  }
  const settings = page.locator('.omega-experience-panel')
  await expect(settings).not.toHaveAttribute('open', '')
  await settings.locator('summary').focus()
  await page.keyboard.press('Enter')
  await expect(settings).toHaveAttribute('open', '')
  await expect(page.getByRole('combobox', { name: 'Качество 3D-глобуса' })).toBeVisible()
  await settings.locator('summary').click()
  await expect(settings).not.toHaveAttribute('open', '')
  const fallback = page.locator('.omega-globe')
  await expect(fallback).toHaveCount(1)
  const photographicBackground = await fallback.evaluate(element => getComputedStyle(element).backgroundImage)
  expect(photographicBackground).toContain('blue-marble-2048.webp')
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true)
})

test('NASA globe assets are self-hosted, historically credited and hash-verified', async ({ request }) => {
  const { createHash } = await import('node:crypto')
  const response = await request.get('/brand/earth/manifest.json')
  expect(response.status()).toBe(200)
  const manifest = await response.json()
  expect(manifest.mode).toBe('self-hosted')
  expect(manifest.not_live_data).toBe(true)
  expect(manifest.generated).toHaveLength(6)
  expect(manifest.bundle_bytes).toBeLessThan(7 * 1024 * 1024)
  for (const resource of manifest.generated) {
    const img = await request.get('/brand/earth/' + resource.file)
    expect(img.status(), resource.file).toBe(200)
    const bytes = await img.body()
    expect(bytes.length, resource.file).toBe(resource.bytes)
    expect(bytes.subarray(0, 4).toString('ascii'), resource.file).toBe('RIFF')
    expect(bytes.subarray(8, 12).toString('ascii'), resource.file).toBe('WEBP')
    expect(createHash('sha256').update(bytes).digest('hex'), resource.file).toBe(resource.sha256)
  }
})

test('OSGARD Earth uses bundled NASA satellite data with fallback if blocked', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'no-preference' })
  await page.goto('/')
  await expectOsgardContentReady(page)
  const stage = page.locator('.omega-webgl-stage')
  await expect(stage).toHaveAttribute('data-globe-status', /^(webgl|fallback)$/, { timeout: 25000 })
  const state = await stage.getAttribute('data-globe-status')
  if (state === 'webgl') {
    await expect(stage).toHaveAttribute('data-earth-source', 'nasa')
    await expect(stage).toHaveAttribute('data-cloud-layers', '2')
    await expect(stage).toHaveAttribute('data-earth-resolution', /^(512|1024|2048|4096)$/)
  }
  // Satellite source and historical night-light date live in a real disclosure.
  // The closed control is intentional; expand it before testing provenance.
  const settings = page.locator('.omega-experience-panel')
  await settings.locator('summary').click()
  await expect(settings).toHaveAttribute('open', '')
  await expect(settings.getByText(/ночные огни 2016/)).toBeVisible()
  await expect(settings.getByRole('link', { name: 'NASA Blue Marble ↗' })).toHaveAttribute('href', /science\.nasa\.gov/)
})

test('OSGARD Earth falls back to coastlines if NASA texture assets cannot load', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'no-preference' })
  await page.route('**/brand/earth/*.webp', route => route.abort())
  await page.goto('/')
  await expectOsgardContentReady(page)
  const stage = page.locator('.omega-webgl-stage')
  await expect(stage).toHaveAttribute('data-globe-status', /^(webgl|fallback)$/, { timeout: 25000 })
  if (await stage.getAttribute('data-globe-status') === 'webgl') {
    await expect(stage).toHaveAttribute('data-earth-source', 'procedural')
  }
  await expect(page.locator('.omega-globe')).toHaveCount(1)
  await expect(page.locator('.omega-mode-tabs button')).toHaveCount(3)
})

test('OSGARD Earth uses real bundled coastlines and WebGL or safe fallback', async ({ page, request }) => {
  const earth = await request.get('/brand/omega-earth-land.json')
  expect(earth.status()).toBe(200)
  const data = await earth.json()
  expect(data.type).toBe('land-polygons')
  expect(data.polygons.length).toBeGreaterThan(100)

  const errors = []
  page.on('pageerror', error => errors.push(error.message))
  await page.emulateMedia({ reducedMotion: 'no-preference' })
  await page.goto('/')
  await expectOsgardContentReady(page)
  const stage = page.locator('.omega-webgl-stage')
  await expect(stage).toHaveCount(1)
  await expect(stage).toHaveAttribute('data-globe-status', /^(webgl|fallback)$/, { timeout: 20000 })
  await expect(page.locator('.omega-globe')).toHaveCount(1)
  await expect(page.locator('.omega-hero h1')).toContainText('ТЕХНОЛОГИИ')
  if (await stage.getAttribute('data-globe-status') === 'webgl') {
    await expect(page.locator('.omega-sky')).toHaveClass(/omega-webgl-ready/)
    await expect(stage.locator('canvas')).toHaveCount(1)
  }

  await page.getByRole('button', { name: 'Меньше движения', exact: true }).click()
  await expect(page.locator('html')).toHaveAttribute('data-motion', 'off')
  await expect(page.locator('.omega-gate a')).toHaveCount(3)
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true)
  expect(errors).toEqual([])
})

test('OSGARD cinematic scenes preserve working routes and real responsive artwork', async ({ page }) => {
  const pageErrors = []
  page.on('pageerror', error => pageErrors.push(error.message))
  await page.goto('/')
  await expectOsgardContentReady(page)
  await expect(page.locator('.omega-hero .omega-globe')).toHaveCount(1)
  await expect(page.locator('.omega-cards .omega-card')).toHaveCount(3)
  for (const path of ['/intelligence', '/play', '/development']) {
    await expect(page.locator('.omega-gate a[href="' + path + '"]')).toHaveCount(1)
  }

  await page.goto('/intelligence')
  await expect(page.locator('.omega-intelligence-scene img[src="/brand/omega-osa.svg"]')).toBeVisible()
  await expect(page.locator('.omega-osa-trails a')).toHaveCount(3)
  expect(await page.locator('.omega-intelligence-scene img').evaluate(img => img.complete && img.naturalWidth > 0)).toBe(true)

  await page.goto('/play')
  await expect(page.locator('.play-universe')).toHaveAttribute('data-art-state', 'loaded')
  const playArt = page.locator('.cp-hero-art img')
  await expect(playArt).toBeVisible()
  expect(await playArt.evaluate(img => img.complete && img.naturalWidth > 0)).toBe(true)
  const artPath = await playArt.evaluate(img => new URL(img.currentSrc).pathname)
  expect(artPath).toMatch(await page.evaluate(() => innerWidth <= 600)
    ? /^\/brand\/play\/hero-mobile(?:-780)?\.webp$/
    : /^\/brand\/play\/hero-megacity(?:-(?:1280|1920))?\.webp$/)
  await expect(page.locator('.cp-glass-panel a')).toHaveCount(3)
  await expect(page.getByRole('link', { name: 'Исследовать миры', exact: true })).toHaveAttribute('href', '#featured')
  await expect(page.getByRole('button', { name: 'Смотреть трейлер', exact: true })).toBeDisabled()
  await expect(page.locator('#trailer-status')).toContainText('Трейлер пока не опубликован')
  await expect(page.locator('#featured .cp-world')).toHaveCount(3)
  await page.getByRole('button', { name: 'Следующие избранные миры', exact: true }).click()
  await page.getByRole('button', { name: 'Следующие избранные миры', exact: true }).click()
  const shadow = page.locator('#featured [data-world-id="zion-030"]')
  await expect(shadow).toBeVisible()
  await expect(shadow.getByRole('heading', { level: 3 })).toHaveText('Теневой протокол')
  await expect(shadow.locator('h3 a')).toHaveAttribute('href', /^\/play\/world\/zion-030\?back=/)
  await shadow.locator('img').scrollIntoViewIfNeeded()
  await expect.poll(() => shadow.locator('img').evaluate(img => img.complete && img.naturalWidth > 0)).toBe(true)

  await page.goto('/development')
  await expect(page.locator('.omega-dev-hero h1')).toContainText('ЦИФРОВЫЕ')
  await expect(page.locator('.omega-dev-capability-grid a')).toHaveCount(3)
  await expect(page.locator('.omega-dev-hero-art img[src="/brand/omega-development.svg"]')).toBeVisible()
  expect(await page.locator('.omega-dev-hero-art img').evaluate(img => img.complete && img.naturalWidth > 0)).toBe(true)
  await expect(page.locator('#cases')).toHaveCount(1)
  await expect(page.locator('#contact')).toHaveCount(1)
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true)
  expect(pageErrors).toEqual([])
})

for (const slug of ['phantom', 'tedes', 'merakki']) {
  test('capture actual case interface: ' + slug, async ({ page }, info) => {
    test.skip(info.project.name !== 'desktop', 'The published case evidence uses a fixed desktop viewport')
    await page.setViewportSize({ width: 1200, height: 800 })
    await page.goto('/development/' + slug + '/')
    await expect(page.locator('h1').first()).toBeVisible()
    await page.evaluate(async () => {
      await document.fonts.ready
      await Promise.all([...document.images].filter(image => image.loading !== 'lazy').map(image => image.decode().catch(() => {})))
    })
    await page.screenshot({ path: info.outputPath('case-' + slug + '.jpg'), type: 'jpeg', quality: 85 })
  })
}

test('keyboard can skip the shared navigation', async ({ page }) => {
  await page.goto('/')
  await expectOsgardContentReady(page)
  await page.keyboard.press('Tab')
  await expect(page.getByRole('link', { name: 'Перейти к содержанию' })).toBeFocused()
  await page.keyboard.press('Enter')
  await expect(page.locator('#product-main')).toBeFocused()
})

test('OSA sources, marked claims and reset are functional', async ({ page }) => {
  await page.goto('/intelligence')
  const sourceToggle = page.getByRole('button', { name: 'Раскрыть источники и границы' })
  await expect(page.locator('#demo-sources')).toBeHidden()
  await page.getByRole('checkbox').nth(1).check()
  await expect(page.getByRole('status')).toContainText('1 из 3')
  await sourceToggle.click()
  await expect(page.locator('#demo-sources')).toBeVisible()
  await expect(page.getByRole('button', { name: 'Скрыть источники и границы' })).toHaveAttribute('aria-expanded', 'true')
  await page.getByRole('button', { name: 'Начать заново', exact: true }).click()
  await expect(page.getByRole('checkbox').nth(1)).not.toBeChecked()
  await expect(page.locator('#demo-sources')).toBeHidden()
})

test('contact form reports errors and exports a brief without submitting', async ({ page }) => {
  await page.goto('/')
  await expectOsgardContentReady(page)
  const field = page.getByLabel('Что хотите создать?', { exact: true })
  await page.getByRole('button', { name: 'Скачать бриф' }).click()
  await expect(page.locator('#brief-feedback')).toHaveAttribute('role', 'alert')
  await expect(field).toBeFocused()
  await field.fill('Учебный пример: создать расписание занятий для небольшого клуба.')
  const downloaded = page.waitForEvent('download')
  await page.getByRole('button', { name: 'Скачать бриф' }).click()
  expect((await downloaded).suggestedFilename()).toBe('OSGARD-project-brief.txt')
  await expect(page.locator('#brief-feedback')).toContainText('Заявка не отправлена')
})

test('unknown Play worlds cannot spoof inherited object keys or crash navigation', async ({ page }) => {
  const runtimeErrors = []
  page.on('pageerror', error => runtimeErrors.push(error.message))
  for (const slug of ['__proto__', 'constructor', 'toString']) {
    await page.goto('/play/world/' + slug)
    await expect(page.getByRole('heading', { level: 1, name: 'Мир не найден.' })).toBeVisible()
    await expect(page.getByRole('link', { name: 'Вернуться в каталог' })).toHaveAttribute('href', /play/)
  }
  expect(runtimeErrors).toEqual([])
})

test('catalog filters, return path and favorites survive reload', async ({ page }) => {
  test.slow() // Includes a real iframe runtime, stop/focus recovery and a full persistence reload.
  await page.goto('/play')
  await openPlayCatalog(page)
  const catalog = page.locator('#catalog')
  const cards = catalog.locator('.play-card')
  const search = catalog.getByRole('searchbox', { name: 'Найти свой мир', exact: true })
  expect(new Set(await cards.evaluateAll(items => items.map(item => item.dataset.worldId))).size).toBe(19)
  await catalog.getByRole('combobox', { name: 'Жанр', exact: true }).selectOption('Стратегия')
  await expect(cards).toHaveCount(2)
  expect(await cards.evaluateAll(items => items.map(item => item.dataset.worldId).sort())).toEqual(['empire-orbit', 'time'])
  await catalog.getByRole('button', { name: 'Сбросить фильтры', exact: true }).click()
  await catalog.getByRole('combobox', { name: 'Доступность', exact: true }).selectOption('service')
  await expect(cards).toHaveCount(1)
  await expect(cards).toHaveAttribute('data-world-id', 'remix')
  await expect(page).toHaveURL(/mode=service/)
  await catalog.getByRole('button', { name: 'Сбросить фильтры', exact: true }).click()
  await search.fill('does-not-exist')
  await expect(cards).toHaveCount(0)
  await catalog.getByRole('button', { name: 'Показать все миры', exact: true }).click()
  await expect(search).toBeFocused()
  await expect(cards).toHaveCount(19)
  await search.fill('Добавь тень')
  await expect(cards).toHaveCount(1)
  await expect(cards).toHaveAttribute('data-world-id', 'zion-030')
  await search.fill('ZION-030')
  await expect(page).toHaveURL(/q=ZION-030/)
  await cards.locator('h3 a').click()
  await expect(page.locator('#play-game-title')).toHaveText('Теневой протокол')
  expect(new URL(page.url()).searchParams.get('back')).toBe('/play?q=ZION-030#catalog')
  const launch = page.locator('.play-game-hero button[data-game-launch="zion-030"]')
  const separate = page.locator('.play-game-hero a[data-game-launch="zion-030"]')
  await expect(launch).toBeEnabled()
  await expect(launch).toHaveAttribute('aria-controls', 'play-session')
  await expect(separate).toHaveAttribute('href', '/games/zion-9/queue/ZION-030/index.html')
  await expect(separate).toHaveAttribute('target', '_blank')
  await expect(separate).toHaveAttribute('rel', /noopener/)
  await expect(page.locator('#play-session iframe')).toHaveCount(0)
  await launch.click()
  const frame = page.locator('#play-session iframe')
  await expect(frame).toHaveAttribute('src', /\/games\/zion-9\/queue\/ZION-030\/index\.html$/)
  await expect(frame).toHaveAttribute('title', 'Теневой протокол — игровое окно')
  const scene = page.frameLocator('#play-session iframe').locator('#scene')
  await expect(scene).toBeVisible()
  await expect(scene).toHaveAttribute('data-renderer', /.+/)
  await expect(page.locator('#play-session')).toHaveAttribute('data-session-phase', /^(loaded|ready|playing|completed)$/)
  await page.getByRole('button', { name: 'Остановить', exact: true }).click()
  await expect(frame).toHaveCount(0)
  await expect(page.locator('#play-session')).toHaveAttribute('data-session-phase', 'idle')
  await expect(launch).toBeFocused()
  await page.getByRole('button', { name: 'Добавить в избранное: Теневой протокол', exact: true }).click()
  await expect(page.getByRole('button', { name: 'Убрать из избранного: Теневой протокол', exact: true })).toHaveAttribute('aria-pressed', 'true')
  await page.reload()
  await expect(page.getByRole('button', { name: 'Убрать из избранного: Теневой протокол', exact: true })).toHaveAttribute('aria-pressed', 'true')
  await expect(page.locator('#play-session iframe')).toHaveCount(0)
  await page.getByRole('link', { name: 'Каталог миров', exact: true }).click()
  await expect(page.locator('.cp-explore')).toHaveAttribute('data-explore-state', 'ready')
  await expect(search).toHaveValue('ZION-030')
  await expect(cards).toHaveCount(1)
  const favorites = catalog.getByRole('group', { name: 'Моя коллекция', exact: true }).getByRole('button', { name: /^Избранное/ })
  await favorites.click()
  await expect(favorites).toHaveAttribute('aria-pressed', 'true')
  await expect(page).toHaveURL(/view=favorites/)
  await expect(cards).toHaveCount(1)
  await expect(page.locator('.brand-local-bar nav[aria-label="Навигация раздела"] a[href="/play?view=favorites#catalog"]')).toHaveAttribute('aria-current', 'location')
  await cards.getByRole('button', { name: 'Убрать из избранного: Теневой протокол', exact: true }).click()
  await expect(cards).toHaveCount(0)
  await expect(search).toBeFocused()
})

test('a cold contact fragment waits for the actual lazy page', async ({ page }) => {
  await page.route('**/assets/WorldHome-*.js', async route => {
    await new Promise(resolve => setTimeout(resolve, 700))
    await route.continue()
  })
  await page.goto('/#contact')
  await expect(page.locator('#contact')).toBeInViewport()
  expect(new URL(page.url()).hash).toBe('#contact')
})

test('ordinary Play entry stays at the hero and loads the real catalog only on approach', async ({ page }) => {
  await page.goto('/play')
  await expect(page.locator('#play-title')).toBeInViewport()
  await expect(page.locator('#featured .cp-world')).toHaveCount(3)
  await expect(page.locator('.cp-explore')).toHaveAttribute('data-explore-state', 'deferred')
  await expect(page.locator('#catalog')).toHaveCount(0)
  expect(new URL(page.url()).hash).toBe('')
  expect(await page.evaluate(() => scrollY)).toBe(0)
  await page.locator('.cp-explore').scrollIntoViewIfNeeded()
  await expect(page.locator('.cp-explore')).toHaveAttribute('data-explore-state', 'ready')
  await expect(page.locator('#catalog .play-card')).toHaveCount(19)
  expect(new URL(page.url()).hash).toBe('')
})

test('blocked optional storage keeps the game catalog usable', async ({ page }) => {
  await page.addInitScript(() => {
    Object.defineProperty(Storage.prototype, 'setItem', { value: () => { throw new DOMException('Storage blocked', 'SecurityError') } })
  })
  await page.goto('/play')
  await openPlayCatalog(page)
  const first = page.locator('#catalog .play-card').first()
  const favorite = first.getByRole('button', { name: /^В избранное:/ })
  await favorite.click()
  await expect(page.locator('#catalog .cp-collection-feedback')).toContainText('Не удалось сохранить коллекцию')
  await expect(favorite).toHaveAttribute('aria-pressed', 'false')
  await expect(first.locator('h3 a')).toBeEnabled()
  await first.locator('h3 a').click()
  await expect(page.locator('.play-game-hero button[data-game-launch]')).toBeEnabled()
})

test('motion choice persists independently from the system setting', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'no-preference' })
  await page.goto('/')
  await expectOsgardContentReady(page)
  await page.getByRole('button', { name: 'Меньше движения', exact: true }).click()
  await expect(page.locator('html')).toHaveAttribute('data-motion', 'off')
  await page.reload()
  await expect(page.locator('html')).toHaveAttribute('data-motion', 'off')
  await expect(page.getByRole('button', { name: 'Меньше движения', exact: true })).toHaveAttribute('aria-pressed', 'true')
})

test('first OSGARD intro retains a real deep link, supports replay and Escape, and stays dismissed on reload', async ({ page }) => {
  const errors = []
  page.on('pageerror', error => errors.push(error.message))
  await page.emulateMedia({ reducedMotion: 'no-preference' })
  await recordOsgardTransitions(page)
  const destination = '/play?q=ZION-030#catalog'
  const [, visualResponse] = await Promise.all([
    page.goto(destination, { waitUntil: 'domcontentloaded' }),
    page.waitForResponse(response => /\/assets\/OsgardCinematic-[^/]+\.js$/.test(new URL(response.url()).pathname)),
  ])
  expect(visualResponse.status()).toBe(200)
  await visualResponse.finished()
  // A cold chunk may legitimately hit the 800 ms watchdog. Either path must
  // release input; the downloaded visual is then exercised by an explicit replay.
  await expectOsgardContentReady(page)
  expect(await page.evaluate(() => window.__osgardBrowserTrace.started)).toEqual(['intro'])
  expect(await page.evaluate(() => localStorage.getItem('osgard:intro:v1'))).toBe('seen')
  expect(new URL(page.url()).pathname + new URL(page.url()).search + new URL(page.url()).hash).toBe(destination)
  await expect(page.locator('.cp-explore')).toHaveAttribute('data-explore-state', 'ready')
  await expect(page.locator('#catalog .play-card')).toHaveCount(1)
  const replay = page.getByRole('button', { name: 'Повторить заставку', exact: true })
  await replay.click()
  await expect(page.locator('.osgard-cinematic[data-kind="intro"]')).toBeVisible()
  await expect(page.locator('[data-osgard-content]')).toHaveAttribute('inert', '')
  await expect(page.getByRole('button', { name: 'Пропустить', exact: true })).toBeFocused()
  await page.keyboard.press('Escape')
  await expectOsgardContentReady(page)
  await expect(replay).toBeFocused()
  expect(await page.evaluate(() => window.__osgardBrowserTrace.visuals)).toContain('intro')
  expect(new URL(page.url()).pathname + new URL(page.url()).search + new URL(page.url()).hash).toBe(destination)
  await page.reload()
  await expect(page.locator('#catalog .play-card')).toHaveCount(1)
  await expectOsgardContentReady(page)
  expect(await page.evaluate(() => window.__osgardBrowserTrace.started)).toEqual([])
  expect(errors).toEqual([])
})

test('major-section transitions keep one SPA document across Play and account, with no animation for account pages or filters', async ({ page }) => {
  const errors = []
  page.on('pageerror', error => errors.push(error.message))
  await page.emulateMedia({ reducedMotion: 'no-preference' })
  await recordOsgardTransitions(page, true)
  await page.goto('/account')
  await expect(page.locator('h1')).toContainText('Доступ под')
  await expectOsgardContentReady(page)
  const documentId = await page.evaluate(() => window.__osgardBrowserTrace.documentId)
  const playLink = page.getByRole('navigation', { name: 'Продукты OSGARD', exact: true }).getByRole('link', { name: 'Play', exact: true })
  const [, visualResponse] = await Promise.all([
    playLink.click(),
    page.waitForResponse(response => /\/assets\/OsgardCinematic-[^/]+\.js$/.test(new URL(response.url()).pathname)),
  ])
  expect(visualResponse.status()).toBe(200)
  await visualResponse.finished()
  await expect(page.locator('#play-title')).toContainText(/OSGARD\s*Play/)
  await expectOsgardContentReady(page)
  expect(await page.evaluate(() => window.__osgardBrowserTrace.documentId)).toBe(documentId)
  expect(await page.evaluate(() => window.__osgardBrowserTrace.started)).toEqual(['play'])

  await page.goBack()
  await expect(page).toHaveURL(/\/account$/)
  await expect(page.locator('h1')).toContainText('Доступ под')
  await expectOsgardContentReady(page)
  expect(await page.evaluate(() => window.__osgardBrowserTrace.started)).toEqual(['play', 'transition'])
  expect(await page.evaluate(() => window.__osgardBrowserTrace.visuals)).toContain('transition')
  await expect(page.locator('link[rel="canonical"]')).toHaveAttribute('href', 'https://osgard.world/account')

  await page.getByRole('link', { name: 'Рабочее пространство', exact: true }).click()
  await expect(page).toHaveURL(/\/workspace$/)
  await expect(page.locator('h1')).toContainText('к проверенному результату')
  await expectOsgardContentReady(page)
  await page.goBack()
  await expect(page).toHaveURL(/\/account$/)
  await expect(page.locator('h1')).toContainText('Доступ под')
  await page.goForward()
  await expect(page).toHaveURL(/\/workspace$/)
  await expect(page.locator('h1')).toContainText('к проверенному результату')
  await expectOsgardContentReady(page)
  expect(await page.evaluate(() => window.__osgardBrowserTrace.started)).toEqual(['play', 'transition'])
  expect(await page.evaluate(() => window.__osgardBrowserTrace.documentId)).toBe(documentId)

  await playLink.click()
  await expect(page.locator('#play-title')).toContainText(/OSGARD\s*Play/)
  await expectOsgardContentReady(page)
  expect(await page.evaluate(() => window.__osgardBrowserTrace.started)).toEqual(['play', 'transition', 'play'])
  await openPlayCatalog(page)
  await page.getByRole('searchbox', { name: 'Найти свой мир', exact: true }).fill('ZION-030')
  await expect(page.locator('#catalog .play-card')).toHaveCount(1)
  await expect(page).toHaveURL(/q=ZION-030.*#catalog$/)
  await expectOsgardContentReady(page)
  expect(await page.evaluate(() => window.__osgardBrowserTrace.started)).toEqual(['play', 'transition', 'play'])
  expect(await page.evaluate(() => window.__osgardBrowserTrace.documentId)).toBe(documentId)
  expect(errors).toEqual([])
})

test('ZION-030 remains playable without WebGL using accessible controls', async ({ page }, info) => {
  await page.addInitScript(() => {
    const getContext = HTMLCanvasElement.prototype.getContext
    HTMLCanvasElement.prototype.getContext = function (kind, ...args) {
      return /webgl/.test(kind) ? null : getContext.call(this, kind, ...args)
    }
  })
  await page.goto('/games/zion-9/queue/ZION-030/index.html?lang=ru')
  await expect(page.locator('#scene')).toHaveAttribute('data-renderer', 'canvas2d')
  const move = async (direction, count) => {
    for (let i = 0; i < count; i++) {
      if (info.project.name === 'mobile') await page.locator('[data-cursor="' + direction + '"]').click()
      else await page.locator('#scene').press('Arrow' + direction[0].toUpperCase() + direction.slice(1))
    }
  }
  const place = async () => {
    if (info.project.name === 'mobile') await page.locator('#place-keyboard').click()
    else await page.locator('#scene').press('Enter')
  }
  await move('left', 4); await move('up', 3); await place()
  await move('right', 6); await move('down', 5); await place()
  await move('right', 2); await move('up', 4); await place()
  await expect(page.locator('#statusTitle')).toContainText('Миссия выполнена')
  await page.locator('#reset').click()
  await expect(page.locator('#placedPill')).toContainText('0 / 3')
})

async function prepareStandaloneGame(page) {
  const errors = []
  page.on('pageerror', error => errors.push(error.message))
  // These interface regressions use local play, without a backend or remote fonts.
  await page.route('https://fonts.googleapis.com/**', route => route.fulfill({ contentType: 'text/css', body: '' }))
  await page.route('**/api/world/quiet-reach**', route => route.fulfill({ status: 503, contentType: 'application/json', body: '{"error":"offline test"}' }))
  await page.route('**/api/analytics', route => route.fulfill({ status: 204, body: '' }))
  return errors
}

async function expectInheritPanelsClosed(page) {
  for (const selector of ['#panel', '.catalog', '.chronicle', '.return-card', '.replay-banner', '#toast']) {
    const panel = page.locator(selector)
    await expect(panel).toHaveCount(1)
    await expect(panel).toBeHidden()
    await expect(panel).toHaveJSProperty('hidden', true)
    await expect(panel).toHaveAttribute('aria-hidden', 'true')
    // Moving a fixed panel beyond the viewport still paints it in full-page screenshots.
    expect(await panel.evaluate(node => getComputedStyle(node).display)).toBe('none')
  }
  await expect(page.locator('dialog[open]')).toHaveCount(0)
}

for (const [game, action, ru, en] of [
  ['inherit', '#pass', 'Завершить поколение', 'Pass this world on'],
  ['remix', '#start-match', 'Создать испытание дня', 'Create daily challenge'],
]) {
  test(game + ': RU/EN interface and responsive page without a live match', async ({ page }, info) => {
    const errors = await prepareStandaloneGame(page)
    await page.goto('/games/' + game + '/', { waitUntil: 'domcontentloaded' })
    await expect(page.locator('html')).toHaveAttribute('lang', 'ru')
    await expect(page.locator(action)).toContainText(ru)
    await expect(page.locator('[data-game-language="ru"]')).toHaveAttribute('aria-pressed', 'true')
    if (game === 'remix') {
      await expect(page.locator('#api-url')).toBeHidden()
      await expect(page.locator('.remix-guide')).toContainText('Сохранение и онлайн')
      expect(await page.locator('#live-growth-console').evaluate(node => getComputedStyle(node).position)).toBe('relative')
    } else {
      await expectInheritPanelsClosed(page)
      await expect(page.locator('#inherit-enter')).toBeVisible()
      if (info.project.name === 'mobile') await expect(page.locator('#world')).toBeInViewport()
      else await expect(page.locator('#inherit-enter')).toBeInViewport()
      expect(await page.locator('.journey').evaluate(node => node.parentElement.classList.contains('inherit-guide') && getComputedStyle(node).position === 'static')).toBe(true)
    }
    for (const [language, label] of [['en', en], ['ru', ru]]) {
      await page.locator('[data-game-language="' + language + '"]').click()
      await expect(page.locator('html')).toHaveAttribute('lang', language)
      await expect(page.locator(action)).toContainText(label)
      await expect(page.locator('[data-game-language="' + language + '"]')).toHaveAttribute('aria-pressed', 'true')
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true)
      if (game === 'inherit') {
        await expectInheritPanelsClosed(page)
        if (info.project.name === 'mobile') {
          expect(await page.evaluate(() => {
            const bounds = selector => document.querySelector(selector).getBoundingClientRect()
            return bounds('.objective').bottom <= bounds('.community-signal').top && bounds('.community-signal').bottom <= bounds('.hero').top
          })).toBe(true)
        }
      }
    }
    expect(await page.evaluate(() => localStorage.getItem('osgard:game-language'))).toBe('ru')
    await page.screenshot({ path: info.outputPath(game + '-interface.png'), fullPage: true })
    if (game === 'inherit') {
      await expectInheritPanelsClosed(page)
      await page.screenshot({ path: info.outputPath('inherit-entry-viewport.png') })
    }
    expect(errors).toEqual([])
  })
}

test('INHERIT catalog and chronicle open on request and close without ghost panels', async ({ page }, info) => {
  const errors = await prepareStandaloneGame(page)
  await page.goto('/games/inherit/', { waitUntil: 'domcontentloaded' })
  await expect(page.locator('#pass')).toContainText('Завершить поколение')
  await expectInheritPanelsClosed(page)
  await page.locator('.catalog-button').click()
  await expect(page.locator('.catalog')).toBeVisible()
  await expect(page.locator('.catalog')).toHaveJSProperty('inert', false)
  await expect(page.locator('.catalog [data-extra]')).toHaveCount(6)
  await expect(page.locator('.catalog-button')).toHaveAttribute('aria-expanded', 'true')
  await page.keyboard.press('Escape')
  await expect(page.locator('.catalog-button')).toHaveAttribute('aria-expanded', 'false')
  await expectInheritPanelsClosed(page)
  await page.locator('.chronicle-button').click()
  await expect(page.locator('.chronicle')).toBeVisible()
  await expect(page.locator('.chronicle')).toHaveJSProperty('inert', false)
  await expect(page.locator('.chronicle-button')).toHaveAttribute('aria-expanded', 'true')
  await expect(page.locator('#chronicle-list li')).toHaveCount(4)
  await page.locator('.chronicle .close').click()
  await expect(page.locator('.chronicle-button')).toHaveAttribute('aria-expanded', 'false')
  await expectInheritPanelsClosed(page)
  await page.evaluate(() => scrollTo(0, 0))
  await page.screenshot({ path: info.outputPath('inherit-panels-closed.png'), fullPage: true })
  expect(errors).toEqual([])
})

test('INHERIT keyboard placement keeps the selected trace through ordinary keys and language changes', async ({ page }) => {
  const errors = await prepareStandaloneGame(page)
  await page.goto('/games/inherit/', { waitUntil: 'domcontentloaded' })
  await page.locator('#inherit-enter').click()
  const world = page.locator('#world')
  await expect(world).toBeFocused()
  await expect(page.locator('#objects > .placed')).toHaveCount(0)
  await world.press('3')
  for (const key of ['Tab', 'Escape', 'ArrowRight']) await world.press(key)
  await expect(page.locator('.tool[data-tool="light"]')).toHaveClass(/active/)
  await world.press('Enter')
  await expect(page.locator('#objects > .placed.light')).toHaveCount(1)
  await expect(page.locator('#budget')).toHaveText('99')
  expect(await page.evaluate(() => JSON.parse(localStorage.getItem('inherit-world-v1')).objects[0].tool)).toBe('light')
  for (const language of ['en', 'ru']) {
    await page.locator('[data-game-language="' + language + '"]').click()
    await expect(page.locator('html')).toHaveAttribute('lang', language)
    await expect(page.locator('#objects > .placed.light')).toHaveCount(1)
    await expect(page.locator('#budget')).toHaveText('99')
  }
  expect(errors).toEqual([])
})

test('INHERIT recovers a malformed local save and offers the unchanged original for download', async ({ page }) => {
  const errors = await prepareStandaloneGame(page)
  const broken = '{"generation":173,'
  await page.addInitScript(value => localStorage.setItem('inherit-world-v1', value), broken)
  await page.goto('/games/inherit/', { waitUntil: 'domcontentloaded' })
  await expect(page.locator('#inherit-recovery')).toBeVisible()
  await expect(page.locator('#inherit-recovery')).toContainText('исходные данные можно скачать')
  await expect(page.locator('#budget')).toHaveText('100')
  expect(await page.evaluate(() => localStorage.getItem('inherit-world-recovery-v1'))).toBe(broken)
  const download = page.waitForEvent('download')
  await page.locator('#inherit-recovery-download').click()
  expect((await download).suggestedFilename()).toBe('inherit-original-save.json')
  await page.locator('#world').press('Enter')
  await expect(page.locator('#objects > .placed.tree')).toHaveCount(1)
  expect(errors).toEqual([])
})

test('INHERIT denied storage retains playable session state with an explicit warning', async ({ page }) => {
  const errors = await prepareStandaloneGame(page)
  await page.addInitScript(() => {
    for (const method of ['getItem', 'setItem', 'removeItem']) Object.defineProperty(Storage.prototype, method, {
      configurable: true,
      value() { throw new DOMException('Storage blocked', 'SecurityError') },
    })
  })
  await page.goto('/games/inherit/', { waitUntil: 'domcontentloaded' })
  await expect(page.locator('#inherit-save-state')).toContainText('Сохранение недоступно')
  await page.locator('#world').press('Enter')
  await expect(page.locator('#objects > .placed.tree')).toHaveCount(1)
  await expect(page.locator('#budget')).toHaveText('99')
  expect(await page.evaluate(() => JSON.parse(window.InheritPersistence.getItem('inherit-world-v1')).objects.length)).toBe(1)
  await expect(page.locator('#inherit-save-state')).toContainText('только на открытой странице')
  expect(errors).toEqual([])
})

test('INHERIT delayed local handoff locks mutation, commits once and keeps the next generation playable', async ({ page }) => {
  const errors = await prepareStandaloneGame(page)
  const submissions = []
  let settle
  const pending = new Promise(resolve => { settle = resolve })
  await page.route('**/api/world/quiet-reach/generations', async route => {
    submissions.push(route.request().postDataJSON())
    await pending
    await route.fulfill({ status: 503, contentType: 'application/json', body: '{"error":"offline fixture"}' })
  })
  try {
    await page.goto('/games/inherit/', { waitUntil: 'domcontentloaded' })
    const world = page.locator('#world')
    await world.press('3')
    await world.press('Enter')
    const before = await page.evaluate(() => JSON.parse(window.InheritPersistence.getItem('inherit-world-v1')))
    await page.locator('#pass').click()
    await expect.poll(() => submissions.length).toBe(1)
    for (const selector of ['#pass', '#reset', '#inherit-import', '#inherit-import-file']) await expect(page.locator(selector)).toBeDisabled()
    await expect(page.locator('#pass')).toHaveAttribute('aria-busy', 'true')
    await expect(page.locator('#pass')).toContainText('Сохраняем поколение')
    await world.press('Enter')
    await world.press('Control+z')
    // Even a direct second activation through the DOM cannot dispatch a second POST.
    await page.evaluate(() => document.querySelector('#pass').click())
    await expect(page.locator('#objects > .placed.light')).toHaveCount(1)
    await expect(page.locator('#budget')).toHaveText('99')
    await page.locator('[data-game-language="en"]').click()
    await expect(page.locator('#pass')).toContainText('Passing generation')
    expect(submissions).toHaveLength(1)
    expect(submissions[0].expectedGeneration).toBe(before.generation)
    expect(submissions[0].delta).toHaveLength(1)
    settle()
    await expect(page.locator('#pass')).toBeEnabled()
    await expect(page.locator('#pass')).toHaveAttribute('aria-busy', 'false')
    await expect(page.locator('#caption')).toContainText('The server has not confirmed')
    const saved = await page.evaluate(() => JSON.parse(window.InheritPersistence.getItem('inherit-world-v1')))
    expect(saved.generation).toBe(before.generation + 1)
    expect(saved.history).toHaveLength(before.history.length + 1)
    expect(saved.snapshots).toHaveLength((before.snapshots || []).length + 1)
    expect(saved.snapshots.at(-1).generation).toBe(before.generation)
    expect(saved.snapshots.at(-1).objects).toEqual(before.objects)
    expect(saved.pending).toEqual([])
    await world.press('Enter')
    await expect(page.locator('#objects > .placed.light')).toHaveCount(2)
    await expect(page.locator('#budget')).toHaveText('99')
    const next = await page.evaluate(() => JSON.parse(window.InheritPersistence.getItem('inherit-world-v1')))
    expect(next.pending).toHaveLength(1)
    expect(next.snapshots).toHaveLength(saved.snapshots.length)
    expect(submissions).toHaveLength(1)
    expect(errors).toEqual([])
  } finally { settle() }
})

test('INHERIT conflict leaves the exact pending generation available for export and further play', async ({ page }) => {
  const errors = await prepareStandaloneGame(page)
  let submissions = 0
  await page.route('**/api/world/quiet-reach/generations', route => {
    submissions++
    return route.fulfill({ status: 409, contentType: 'application/json', body: '{"error":"generation conflict fixture"}' })
  })
  await page.goto('/games/inherit/', { waitUntil: 'domcontentloaded' })
  await page.locator('#world').press('Enter')
  const before = await page.evaluate(() => window.InheritPersistence.getItem('inherit-world-v1'))
  await page.locator('#pass').click()
  await expect(page.locator('#caption')).toContainText('Ваши незавершённые следы сохранены')
  await expect(page.locator('#pass')).toBeEnabled()
  await expect(page.locator('#reset')).toBeEnabled()
  expect(await page.evaluate(() => window.InheritPersistence.getItem('inherit-world-v1'))).toBe(before)
  expect(submissions).toBe(1)
  await page.locator('#world').press('Enter')
  await expect(page.locator('#objects > .placed.tree')).toHaveCount(2)
  await expect(page.locator('#budget')).toHaveText('98')
  expect(errors).toEqual([])
})

test('INHERIT RU/EN/ZH switches in place without losing placed traces or breaking mobile layout',async({page})=>{
  const errors=await prepareStandaloneGame(page);
  await page.goto('/games/inherit/?lang=zh',{waitUntil:'domcontentloaded'});
  await expect(page.locator('html')).toHaveAttribute('lang','zh-CN');
  await expect(page.locator('[data-game-language="zh"]')).toHaveAttribute('aria-pressed','true');
  await expect(page.locator('#pass')).toContainText('传承这个世界');
  await expect(page.locator('.hero h1')).toContainText('有人修了一条路');
  const world=page.locator('#world');
  await world.focus();
  await world.press('Enter');
  await expect(page.locator('#budget')).toHaveText('99');
  await expect(page.locator('#objects > .placed')).toHaveCount(1);
  const original=await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()));
  await page.locator('[data-game-language="en"]').click();
  await expect(page.locator('html')).toHaveAttribute('lang','en');
  await expect(page.locator('#pass')).toContainText('Pass this world on');
  await page.locator('[data-game-language="ru"]').click();
  await expect(page.locator('html')).toHaveAttribute('lang','ru');
  await expect(page.locator('#pass')).toContainText('Завершить поколение');
  await page.locator('[data-game-language="zh"]').click();
  await expect(page.locator('html')).toHaveAttribute('lang','zh-CN');
  await expect(page.locator('#pass')).toContainText('传承这个世界');
  expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(original);
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);
  expect(await page.evaluate(()=>localStorage.getItem('osgard:game-language'))).toBe('zh');
  expect(errors).toEqual([]);
});

test('INHERIT touch undo reuses guarded pending-trace logic and keeps committed history',async({page})=>{
  const errors=await prepareStandaloneGame(page);
  await page.goto('/games/inherit/?lang=ru',{waitUntil:'domcontentloaded'});
  const world=page.locator('#world');
  await world.focus();
  await world.press('Enter');
  await expect(page.locator('#budget')).toHaveText('99');
  await expect(page.locator('#objects > .placed')).toHaveCount(1);
  await expect(page.locator('.cine-undo')).toBeVisible();
  await page.locator('.cine-undo').click();
  await expect(page.locator('#budget')).toHaveText('100');
  await expect(page.locator('#objects > .placed')).toHaveCount(0);
  const state=await page.evaluate(()=>window.InheritGame.snapshot());
  expect(state.pending).toEqual([]);
  expect(state.changes).toEqual([]);
  await page.locator('[data-game-language="zh"]').click();
  await expect(page.locator('.cine-undo')).toContainText('撤销痕迹');
  await page.locator('.cine-undo').click();
  expect((await page.evaluate(()=>window.InheritGame.snapshot())).budget).toBe(100);
  expect(errors).toEqual([]);
});


test('INHERIT living legacy: six-rule engine animates inherited places, survives translation and never mutates the save',async({page},info)=>{
  const errors=await prepareStandaloneGame(page);
  await page.goto('/games/inherit/?lang=ru',{waitUntil:'domcontentloaded'});
  await expect(page.locator('.inherit-legacy-trigger')).toBeVisible();
  await expect(page.locator('.inherit-legacy-trigger')).toBeInViewport();
  expect(await page.evaluate(()=>{
    const a=document.querySelector('.inherit-legacy-trigger').getBoundingClientRect();
    const b=document.querySelector('.cine-scene-mode').getBoundingClientRect();
    return a.top>=b.bottom && a.right<=innerWidth+1 && a.left>=0;
  })).toBe(true);
  const original=await page.evaluate(()=>{
    const state=window.InheritGame.snapshot();
    const additions=[
      {tool:'tree',x:35,y:44},{tool:'moss',x:41,y:47},
      {tool:'path',x:66,y:41},{tool:'light',x:67,y:43}
    ];
    window.InheritGame.apply({...state,generation:176,objects:additions,snapshots:[{generation:171,objects:additions}],pending:[],changes:[],budget:100});
    return JSON.stringify(window.InheritGame.snapshot());
  });
  await expect(page.locator('.inherit-legacy-aura--grove')).toHaveCount(1);
  await expect(page.locator('.inherit-legacy-aura--waylight')).toHaveCount(1);
  await expect(page.locator('.inherit-legacy-aura--heritage')).toHaveCount(2);
  await page.locator('.inherit-legacy-trigger').click();
  await expect(page.locator('.inherit-legacy-dialog')).toBeVisible();
  await expect(page.locator('.inherit-legacy-dialog')).toContainText('Тихая роща');
  await expect(page.locator('.inherit-legacy-dialog')).toContainText('Освещённая тропа');
  await expect(page.locator('.inherit-legacy-dialog')).toContainText('Память поколений');
  await expect(page.locator('.inherit-legacy-memories')).toContainText('Дерево');
  await expect(page.locator('.inherit-legacy-memories')).toContainText('Тропа');
  await page.screenshot({path:info.outputPath('inherit-legacy-journal.png')});
  await page.locator('.inherit-legacy-close').click();
  await page.locator('[data-game-language="zh"]').click();
  await expect(page.locator('.inherit-legacy-trigger')).toContainText('传承');
  await page.locator('.inherit-legacy-trigger').click();
  await expect(page.locator('.inherit-legacy-dialog')).toContainText('宁静树林');
  await page.locator('.inherit-legacy-close').click();
  expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(original);
  expect(errors).toEqual([]);
});

test('INHERIT mobile primary action stays clickable while passing a generation with the compact tool dock',async({page},info)=>{
  const errors=await prepareStandaloneGame(page);
  await page.goto('/games/inherit/?lang=ru',{waitUntil:'domcontentloaded'});
  const pass=page.locator('#pass');
  if(info.project.name==='mobile'){
    await expect(pass).toBeInViewport();
    const bounds=await pass.boundingBox();
    expect(bounds).not.toBeNull();
    expect(bounds.y).toBeGreaterThanOrEqual(0);
    expect(bounds.y+bounds.height).toBeLessThanOrEqual(info.project.use.viewport.height+1);
  }
  await page.locator('#world').focus();
  await page.locator('#world').press('Enter');
  await expect(page.locator('#budget')).toHaveText('99');
  await pass.click();
  await expect(page.locator('#budget')).toHaveText('100');
  const state=await page.evaluate(()=>window.InheritGame.snapshot());
  expect(state.generation).toBe(174);
  expect(state.pending).toEqual([]);
  expect(state.objects).toHaveLength(1);
  if(info.project.name==='mobile')await expect(pass).toBeInViewport();
  expect(errors).toEqual([]);
});

test('INHERIT generation chapters: select real traces, complete three quests, pass and preserve world',async({page},info)=>{
  const errors=await prepareStandaloneGame(page);
  await page.goto('/games/inherit/?lang=ru',{waitUntil:'domcontentloaded'});
  await expect(page.locator('.inherit-legacy-trigger')).toBeVisible();
  await page.locator('.inherit-legacy-trigger').click();
  await expect(page.locator('.inherit-chapter-title')).toContainText('Огонь на берегу');
  await expect(page.locator('.inherit-chapter-progress')).toHaveJSProperty('value',0);
  await page.locator('.inherit-chapter-goal').nth(0).locator('.inherit-chapter-tool').click();
  await expect(page.locator('.inherit-legacy-dialog')).toBeHidden();
  await page.locator('#world').press('Enter');
  await expect(page.locator('#budget')).toHaveText('99');
  await expect.poll(()=>page.evaluate(()=>window.InheritStoryUI.getState().done)).toBe(1);
  await page.locator('.inherit-legacy-trigger').click();
  await page.locator('.inherit-chapter-goal').nth(1).locator('.inherit-chapter-tool').click();
  await page.locator('#world').press('Enter');
  await expect(page.locator('#budget')).toHaveText('98');
  await expect.poll(()=>page.evaluate(()=>window.InheritStoryUI.getState().done)).toBe(3);
  await page.locator('.inherit-legacy-trigger').click();
  await expect(page.locator('.inherit-chapter-panel')).toHaveAttribute('data-complete','true');
  await expect(page.locator('.inherit-chapter-goal--done')).toHaveCount(3);
  await expect(page.locator('.inherit-chapter-outcome')).toContainText('Мир дорог');
  await page.screenshot({path:info.outputPath('inherit-chapters-ru.png')});
  await page.locator('.inherit-legacy-close').click();
  await page.locator('[data-game-language="zh"]').click();
  await page.locator('.inherit-legacy-trigger').click();
  await expect(page.locator('.inherit-chapter-title')).toContainText('海岸之火');
  await expect(page.locator('.inherit-chapter-panel')).toHaveAttribute('data-complete','true');
  await page.locator('.inherit-legacy-close').click();
  const before=await page.evaluate(()=>window.InheritGame.snapshot().objects.length);
  expect(before).toBe(2);
  await page.locator('#pass').click();
  await expect.poll(()=>page.evaluate(()=>window.InheritGame.snapshot().generation)).toBe(174);
  await expect.poll(()=>page.evaluate(()=>window.InheritStoryUI.getState().done)).toBe(0);
  await expect(page.locator('#objects > .placed')).toHaveCount(2);
  await expect(page.locator('body')).toHaveAttribute('data-inherit-mood','routes');
  expect(errors).toEqual([]);
});

test('INHERIT chapter suggestions do not mutate protected account mode without custody',async({page})=>{
  const errors=await prepareStandaloneGame(page);
  await page.goto('/games/inherit/?mode=account&lang=en',{waitUntil:'domcontentloaded'});
  await expect(page.locator('.inherit-legacy-trigger')).toBeVisible();
  await page.locator('.inherit-legacy-trigger').click();
  await expect(page.locator('.inherit-chapter-title')).not.toBeEmpty();
  await expect(page.locator('.inherit-chapter-tool').first()).toBeDisabled();
  await expect(page.locator('.inherit-chapter-caution')).toContainText('World editing is unavailable');
  expect(await page.evaluate(()=>window.InheritGame.snapshot().pending?.length||0)).toBe(0);
  expect(errors).toEqual([]);
});


test('INHERIT sixteen-episode cycle: genuine placement resolves incident, persists on reload, rotates on handoff',async({page},info)=>{
  const errors=await prepareStandaloneGame(page);
  await page.goto('/games/inherit/?lang=ru',{waitUntil:'domcontentloaded'});
  await expect(page.locator('.inherit-cycle-entry')).toBeVisible();
  await expect(page.locator('.inherit-cycle-entry-name')).toContainText('Сигнал в тумане');
  await expect(page.locator('body')).toHaveAttribute('data-inherit-season','sun');
  await page.locator('.inherit-cycle-entry-open').click();
  await expect(page.locator('.inherit-legacy-dialog')).toBeVisible();
  await expect(page.locator('.inherit-cycle-choice')).toHaveCount(2);
  await expect(page.locator('.inherit-cycle-nav-button')).toHaveCount(6);
  await page.locator('.inherit-cycle-nav-button').filter({hasText:'Событие'}).click();
  await expect(page.locator('.inherit-cycle-journal')).toBeFocused();
  await page.locator('.inherit-cycle-choice').first().click();
  await expect(page.locator('.inherit-legacy-dialog')).toBeHidden();
  await page.locator('#world').press('Enter');
  await expect(page.locator('#budget')).toHaveText('99');
  await expect.poll(()=>page.evaluate(()=>window.InheritWorldUI.getState().event.resolved)).toBe(true);
  await expect(page.locator('body')).toHaveAttribute('data-inherit-incident','glow');
  await expect(page.locator('.inherit-cycle-imprint--glow')).toHaveCount(1);
  await page.locator('.inherit-cycle-entry-open').click();
  await expect(page.locator('.inherit-cycle-consequence')).toContainText('тёплый свет');
  const snapshot=await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()));
  await page.screenshot({path:info.outputPath('inherit-world-episode-ru.png')});
  await page.locator('.inherit-legacy-close').click();
  await page.reload({waitUntil:'domcontentloaded'});
  await expect.poll(()=>page.evaluate(()=>window.InheritWorldUI.getState().event.resolved)).toBe(true);
  expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(snapshot);
  await page.locator('[data-game-language="zh"]').click();
  await expect(page.locator('.inherit-cycle-entry-name')).toContainText('雾中信号');
  await page.locator('.inherit-cycle-entry-open').click();
  await expect(page.locator('.inherit-cycle-consequence')).toContainText('迷雾中出现了温暖的光');
  await page.locator('.inherit-legacy-close').click();
  await page.locator('#pass').click();
  await expect.poll(()=>page.evaluate(()=>window.InheritGame.snapshot().generation)).toBe(174);
  await expect.poll(()=>page.evaluate(()=>window.InheritWorldUI.getState().event.resolved)).toBe(false);
  await expect(page.locator('body')).toHaveAttribute('data-inherit-season','wind');
  await expect(page.locator('.inherit-cycle-imprint')).toHaveCount(0);
  await expect(page.locator('#objects > .placed')).toHaveCount(1);
  expect(errors).toEqual([]);
});

test('INHERIT world growth: 12 discoveries and ancient island are derived from verified snapshots without save changes',async({page},info)=>{
  const errors=await prepareStandaloneGame(page);
  await page.goto('/games/inherit/?lang=ru',{waitUntil:'domcontentloaded'});
  const before=await page.evaluate(()=>{
    const base=window.InheritGame.snapshot();
    const placed=[
     {tool:'tree',x:30,y:30},{tool:'moss',x:31,y:31},
     {tool:'light',x:43,y:43},{tool:'path',x:45,y:44},
     {tool:'arch',x:60,y:60},{tool:'stone',x:61,y:61},
     {tool:'flower',x:72,y:72},{tool:'chime',x:73,y:73},{tool:'cairn',x:82,y:62}
    ];
    window.InheritGame.apply({...base,generation:177,objects:placed,snapshots:[{generation:167,objects:placed}],pending:[],changes:[],budget:100});
    return JSON.stringify(window.InheritGame.snapshot());
  });
  await expect(page.locator('body')).toHaveAttribute('data-inherit-stage','ancient');
  await expect(page.locator('.inherit-cycle-entry')).toBeVisible();
  await page.locator('.inherit-cycle-entry-open').click();
  await expect(page.locator('.inherit-cycle-phase-description')).toContainText('Старое наследие');
  await expect(page.locator('.inherit-cycle-milestone')).toHaveCount(12);
  await expect(page.locator('.inherit-cycle-milestone.is-unlocked').first()).toBeVisible();
  await expect(page.locator('.inherit-cycle-fact')).toHaveCount(4);
  await expect(page.locator('.inherit-cosmetic-tile')).toHaveCount(4);
  for(const name of ['fern','aurora','copper'])await expect(page.locator('.inherit-cosmetic-tile--'+name)).toBeEnabled();
  await page.locator('.inherit-cosmetic-tile--copper').click();
  await expect(page.locator('body')).toHaveAttribute('data-inherit-skin','copper');
  await expect(page.locator('.inherit-cosmetic-tile--copper')).toHaveAttribute('aria-pressed','true');
  await page.screenshot({path:info.outputPath('inherit-world-ancient.png')});
  expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(before);
  await page.evaluate(()=>window.InheritPersistence.setItem('inherit-world-v1',JSON.stringify(window.InheritGame.snapshot())));
  await page.reload({waitUntil:'domcontentloaded'});
  await expect(page.locator('body')).toHaveAttribute('data-inherit-skin','copper');
  expect(errors).toEqual([]);
});

test('INHERIT private return notebook: explicit opt-in, truthful delta, no streaks and reversible deletion',async({page})=>{
  const errors=await prepareStandaloneGame(page);
  await page.goto('/games/inherit/?lang=en',{waitUntil:'domcontentloaded'});
  const key='inherit:return-notebook:v2:local';
  expect(await page.evaluate(k=>localStorage.getItem(k),key)).toBeNull();
  await page.locator('.inherit-cycle-entry-open').click();
  await expect(page.locator('.inherit-return-enable')).toBeVisible();
  await page.locator('.inherit-return-enable').click();
  await expect(page.locator('.inherit-return-stats')).toContainText('Days visited: 1');
  const local=await page.evaluate(k=>JSON.parse(localStorage.getItem(k)),key);
  expect(local.enabled).toBe(true);
  expect(Object.keys(local.last).sort()).toEqual(['day','discoveries','generation','links','objects']);
  await page.locator('.inherit-legacy-close').click();
  await page.locator('#world').focus();
  await page.locator('#world').press('Enter');
  await expect(page.locator('#budget')).toHaveText('99');
  await page.evaluate(k=>{
    const x=JSON.parse(localStorage.getItem(k));
    x.last.day='2020-01-01';x.days=['2020-01-01'];
    localStorage.setItem(k,JSON.stringify(x));
  },key);
  await page.reload({waitUntil:'domcontentloaded'});
  await page.locator('.inherit-cycle-entry-open').click();
  await expect(page.locator('.inherit-return-stats')).toContainText('Days visited: 2');
  await expect(page.locator('.inherit-return-changes')).toContainText('traces 1');
  await page.locator('.inherit-return-erase').click();
  await expect(page.locator('.inherit-return-enable')).toBeVisible();
  expect(await page.evaluate(k=>localStorage.getItem(k),key)).toBeNull();
  await page.reload({waitUntil:'domcontentloaded'});
  expect(await page.evaluate(k=>localStorage.getItem(k),key)).toBeNull();
  expect(errors).toEqual([]);
});

test('INHERIT account read-only cannot use episode choices or private return notebook',async({page})=>{
  const errors=await prepareStandaloneGame(page);
  await page.goto('/games/inherit/?mode=account&lang=zh',{waitUntil:'domcontentloaded'});
  await page.locator('.inherit-cycle-entry-open').click();
  await expect(page.locator('.inherit-cycle-title')).not.toBeEmpty();
  await expect(page.locator('.inherit-cycle-choice').first()).toBeDisabled();
  await expect(page.locator('.inherit-return-actions')).toBeHidden();
  await expect(page.locator('.inherit-return-status')).toContainText('仅用于本地世界');
  expect(await page.evaluate(()=>window.InheritGame.snapshot().pending||[])).toEqual([]);
  expect(errors).toEqual([]);
});


test('INHERIT first-time guide teaches actual placing and passing without fake world writes',async({page},info)=>{
 const errors=await prepareStandaloneGame(page);
 await page.goto('/games/inherit/?lang=ru',{waitUntil:'domcontentloaded'});
 const guide=page.locator('.inherit-first-steps');
 await expect(guide).toBeVisible();
 await expect(guide).toHaveAttribute('data-step','1');
 await guide.locator('.inherit-first-steps-primary').click();
 await expect(guide).toHaveAttribute('data-step','2');
 await guide.locator('.inherit-first-steps-primary').click();
 await expect(page.locator('#world')).toBeFocused();
 await page.locator('#world').press('Enter');
 await expect(page.locator('#budget')).toHaveText('99');
 await expect(guide).toHaveAttribute('data-step','3');
 await guide.locator('.inherit-first-steps-primary').click();
 await expect(page.locator('#pass')).toBeFocused();
 await page.locator('#pass').click();
 await expect.poll(()=>page.evaluate(()=>window.InheritGame.snapshot().generation)).toBe(174);
 await expect(guide).toBeHidden();
 expect(await page.evaluate(()=>localStorage.getItem('inherit:welcome-completed:v2'))).toBe('yes');
 await page.reload({waitUntil:'domcontentloaded'});
 await expect(guide).toBeHidden();
 expect(errors).toEqual([]);
});

test('INHERIT voluntary research requires consent and supports real offline survey, export and deletion',async({page})=>{
 const errors=await prepareStandaloneGame(page);
 await page.goto('/games/inherit/?lang=ru',{waitUntil:'domcontentloaded'});
 const key='inherit:pilot-research:v1';
 expect(await page.evaluate(k=>localStorage.getItem(k),key)).toBeNull();
 await page.locator('#world').focus();
 await page.locator('#world').press('Enter');
 expect(await page.evaluate(k=>localStorage.getItem(k),key)).toBeNull();
 await page.locator('.inherit-legacy-trigger').click();
 const panel=page.locator('.inherit-research-panel');
 await expect(panel).toBeVisible();
 await expect(panel.locator('.inherit-research-primary').first()).toBeDisabled();
 await panel.locator('.inherit-research-consent input').check();
 await panel.locator('.inherit-research-consent button').click();
 await expect(panel.locator('.inherit-research-active')).toBeVisible();
 expect(await page.evaluate(k=>JSON.parse(localStorage.getItem(k)).events.length,key)).toBe(1);
 await page.locator('.inherit-legacy-close').click();
 await page.locator('#world').focus();
 await page.locator('#world').press('Enter');
 await expect.poll(()=>page.evaluate(()=>window.InheritResearchUI.getSummary().counts.trace_placed)).toBe(1);
 await page.locator('#pass').click();
 await expect.poll(()=>page.evaluate(()=>window.InheritResearchUI.getSummary().counts.generation_advanced_observed)).toBe(1);
 await page.locator('.inherit-legacy-trigger').click();
 const answers={clarity:'5',returnIntent:'4',meaning:'5',reason:'story',priceCents:'499'};
 for(const [name,value] of Object.entries(answers))await panel.locator('select[name="'+name+'"]').selectOption(value);
 await panel.locator('.inherit-research-survey button[type="submit"]').click();
 await expect(panel.locator('.inherit-research-survey .inherit-research-status')).toContainText('сохранены');
 const exported=await page.evaluate(()=>window.InheritResearchUI.getExport());
 expect(exported.kind).toBe('voluntary-pilot-export');
 expect(exported.events.some(e=>e.type==='survey_submitted'&&e.data.priceCents===499)).toBe(true);
 expect(JSON.stringify(exported)).not.toContain('username');
 const download=page.waitForEvent('download');
 await panel.locator('.inherit-research-export').click();
 expect((await download).suggestedFilename()).toMatch(/inherit-pilot-.*\.json/);
 await page.locator('.inherit-legacy-close').click();
 await page.locator('[data-game-language="zh"]').click();
 await page.locator('.inherit-legacy-trigger').click();
 await expect(panel.locator('.inherit-research-title')).toContainText('帮助改进');
 await panel.locator('.inherit-research-erase').click();
 expect(await page.evaluate(k=>localStorage.getItem(k),key)).toBeNull();
 await page.reload({waitUntil:'domcontentloaded'});
 expect(await page.evaluate(()=>window.InheritResearchUI.enabled())).toBe(false);
 expect(errors).toEqual([]);
});

test('INHERIT account read-only keeps voluntary study disabled and gameplay rights unchanged',async({page})=>{
 const errors=await prepareStandaloneGame(page);
 await page.goto('/games/inherit/?mode=account&lang=en',{waitUntil:'domcontentloaded'});
 await page.locator('.inherit-legacy-trigger').click();
 const research=page.locator('.inherit-research-panel');
 await expect(research).toContainText('Research is limited to local worlds');
 await expect(research.locator('.inherit-research-consent')).toBeHidden();
 expect(await page.evaluate(()=>window.InheritGame.snapshot().pending||[])).toEqual([]);
 expect(await page.evaluate(()=>localStorage.getItem('inherit:pilot-research:v1'))).toBeNull();
 await expect(page.locator('.inherit-first-steps')).toBeHidden();
 expect(errors).toEqual([]);
});


test('INHERIT pilot invitation: RU EN ZH, direct opt-in panel, zero research events before consent',async({page})=>{
 const errors=await prepareStandaloneGame(page);
 await page.goto('/games/inherit/pilot/index.html?lang=ru',{waitUntil:'domcontentloaded'});
 await expect(page.locator('html')).toHaveAttribute('lang','ru');
 await expect(page.locator('#join')).toHaveAttribute('href','/games/inherit/?lang=ru&pilot=1');
 await page.locator('[data-lang="en"]').click();
 await expect(page.locator('html')).toHaveAttribute('lang','en');
 await expect(page.locator('#heading')).toContainText('Leave a trace');
 await expect(page.locator('#join')).toHaveAttribute('href','/games/inherit/?lang=en&pilot=1');
 await page.locator('[data-lang="zh"]').click();
 await expect(page.locator('html')).toHaveAttribute('lang','zh');
 await expect(page.locator('#heading')).toContainText('留下痕迹');
 await page.locator('[data-lang="ru"]').click();
 await page.locator('#join').click();
 await expect(page).toHaveURL(/\/games\/inherit\/\?lang=ru&pilot=1/);
 await expect(page.locator('.inherit-legacy-dialog')).toBeVisible();
 await expect(page.locator('#inherit-research-section')).toBeVisible();
 await expect(page.locator('.inherit-research-consent input')).not.toBeChecked();
 await expect(page.locator('.inherit-research-consent button')).toBeDisabled();
 expect(await page.evaluate(()=>localStorage.getItem('inherit:pilot-research:v1'))).toBeNull();
 await expect(page.locator('.inherit-research-about')).toHaveAttribute('href','/games/inherit/pilot/index.html?lang=ru');
 expect(errors).toEqual([]);
});

test('INHERIT pilot console analyzes voluntary files locally, censors future events and exports only aggregates',async({page})=>{
 const errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 const posted=[];page.on('request',req=>{if(req.method()!=='GET')posted.push(req.url())});
 await page.goto('/games/inherit/pilot/report.html',{waitUntil:'domcontentloaded'});
 await expect(page.locator('#results')).toBeHidden();
 await expect(page.locator('#as-of')).not.toHaveValue('');
 await page.waitForFunction(()=>Boolean(window.InheritResearchCore));
 const id='volunteer-aaaaaaaaaaaaaaaaaaaa';
 const voluntary=await page.evaluate(code=>{
  const c=window.InheritResearchCore,iso=d=>d+'T12:00:00.000Z';
  let s=c.create(code,iso('2026-10-01'));
  s=c.record(s,'session_opened',iso('2026-10-01'));
  s=c.record(s,'session_opened',iso('2026-10-02'));
  s=c.record(s,'session_opened',iso('2026-10-08'));
  s=c.record(s,'trace_placed',iso('2026-10-08'),{pendingCount:1});
  s=c.record(s,'survey_submitted',iso('2026-10-09'),{clarity:5,returnIntent:4,meaning:5,reason:'creation',priceCents:499});
  return c.exportConsent(s,iso('2026-10-20'));
 },id);
 await page.locator('#files').setInputFiles([
  {name:'participant-one.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify(voluntary))},
  {name:'participant-duplicate.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify(voluntary))}
 ]);
 await page.locator('#as-of').fill('2026-10-03');
 await page.locator('#calculate').click();
 await expect(page.locator('#results')).toBeVisible();
 await expect(page.locator('#basis')).toContainText('Учтено 1 добровольных участников');
 await expect(page.locator('#basis')).toContainText('Повторных экспортов: 1');
 await expect(page.locator('#survey-summary')).toContainText('Ответов: 0');
 await expect(page.locator('#retention-body')).toContainText('100%');
 await expect(page.locator('#retention-body')).toContainText('н/д');
 expect(await page.locator('#results').textContent()).not.toContain(id);
 await page.locator('#as-of').fill('2026-10-10');
 await page.locator('#calculate').click();
 await expect(page.locator('#survey-summary')).toContainText('Ответов: 1');
 const download=page.waitForEvent('download');
 await page.locator('#save-json').click();
 expect((await download).suggestedFilename()).toBe('inherit-pilot-summary-2026-10-10.json');
 const secondDownload=page.waitForEvent('download');
 await page.locator('#save-md').click();
 expect((await secondDownload).suggestedFilename()).toBe('inherit-pilot-summary-2026-10-10.md');
 await page.locator('#clear-data').click();
 await expect(page.locator('#results')).toBeHidden();
 await expect(page.locator('#files')).toHaveJSProperty('value','');
 await expect(page.locator('#status')).toContainText('убраны из этой вкладки');
 expect(posted).toEqual([]);
 expect(errors).toEqual([]);
});


test('INHERIT pilot console distinguishes stale D1 D7 D30 evidence from confirmed nonreturns',async({page})=>{
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 const posts=[];page.on('request',req=>{if(req.method()!=='GET')posts.push(req.url())});
 await page.goto('/games/inherit/pilot/report.html',{waitUntil:'domcontentloaded'});
 await page.waitForFunction(()=>Boolean(window.InheritResearchCore));
 const file=await page.evaluate(()=>{
  const c=window.InheritResearchCore,at=d=>d+'T12:00:00.000Z';
  let s=c.create('r5-test-participant-00000000000000',at('2026-09-01'));
  s=c.record(s,'session_opened',at('2026-09-01'));
  return c.exportConsent(s,at('2026-09-01'));
 });
 await page.locator('#files').setInputFiles({name:'stale-voluntary-export.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify(file))});
 await page.locator('#as-of').fill('2026-10-20');
 await page.locator('#calculate').click();
 await expect(page.locator('#results')).toBeVisible();
 await expect(page.locator('#evidence-status')).toContainText('без полного наблюдения');
 await expect(page.locator('#retention-body tr')).toHaveCount(3);
 for(const row of await page.locator('#retention-body tr').all()){
  await expect(row.locator('td').nth(4)).toHaveText('1'); // unknown
  await expect(row.locator('td').nth(6)).toHaveText('н/д'); // no defensible rate
 }
 await expect(page.locator('#retention-body')).toContainText('D30');
 expect(await page.locator('#results').textContent()).not.toContain('r5-test-participant-00000000000000');
 const revised={...file,generatedAt:'2026-10-20T12:00:00.000Z'};
 await page.locator('#files').setInputFiles({name:'full-voluntary-export.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify(revised))});
 await page.locator('#calculate').click();
 await expect(page.locator('#evidence-status')).toContainText('невелико');
 for(const row of await page.locator('#retention-body tr').all()){
  await expect(row.locator('td').nth(3)).toHaveText('1'); // documented no-session
  await expect(row.locator('td').nth(4)).toHaveText('0'); // no unresolved
  await expect(row.locator('td').nth(6)).toHaveText('0%');
 }
 expect(posts).toEqual([]);
 expect(errors).toEqual([]);
});


test('INHERIT generation atlas compares two real local generations without editing the world',async({page})=>{
 const errors=await prepareStandaloneGame(page);
 await page.goto('/games/inherit/?lang=ru',{waitUntil:'domcontentloaded'});
 await expect(page.locator('.inherit-atlas-trigger')).toBeVisible();
 const before=await page.evaluate(()=>window.InheritGame.snapshot());
 await page.locator('.inherit-atlas-trigger').click();
 const dialog=page.locator('.inherit-atlas-dialog');
 await expect(dialog).toBeVisible();
 await expect(dialog.locator('.inherit-atlas-title')).toHaveText('Атлас поколений');
 await expect(dialog.locator('.inherit-atlas-disclosure')).toContainText('Нет записи в историю');
 await dialog.locator('.inherit-atlas-close').click();
 // A placement is a real game action. The atlas does not simulate it.
 await page.locator('#world').focus();
 await page.locator('#world').press('Enter');
 await expect(page.locator('#budget')).toHaveText('99');
 await page.locator('#pass').click();
 await expect.poll(()=>page.evaluate(()=>window.InheritGame.snapshot().generation)).toBe(before.generation+1);
 const committed=await page.evaluate(()=>window.InheritGame.snapshot());
 await page.locator('.inherit-atlas-trigger').click();
 await expect(dialog).toBeVisible();
 await expect(dialog.locator('.inherit-atlas-main')).toBeVisible();
 await expect(dialog.locator('.inherit-atlas-field select').first()).not.toBeDisabled();
 const model=await page.evaluate(()=>window.InheritAtlasUI.getModel());
 expect(model.status).toBe('ok');
 expect(model.totals.added).toBeGreaterThanOrEqual(1);
 expect(model.source).toBe('saved-frames-only');
 await expect(dialog.locator('.inherit-atlas-stat').first()).toContainText('+');
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(JSON.stringify(committed));
 await dialog.locator('.inherit-atlas-close').click();
 await page.locator('[data-game-language="zh"]').click();
 await page.locator('.inherit-atlas-trigger').click();
 await expect(dialog.locator('.inherit-atlas-title')).toHaveText('世代图鉴');
 await expect(dialog.locator('.inherit-atlas-disclosure')).toContainText('不会连接服务器');
 expect(errors).toEqual([]);
});

test('INHERIT generation atlas exposes insufficient evidence rather than fabricated earlier history',async({page})=>{
 const errors=await prepareStandaloneGame(page);
 await page.goto('/games/inherit/?lang=en',{waitUntil:'domcontentloaded'});
 await page.evaluate(()=>{
   const game=window.InheritGame,s=game.snapshot();
   s.snapshots=[];s.objects=[];s.pending=[];s.changes=[];
   game.apply(s);
 });
 const start=await page.evaluate(()=>window.InheritGame.snapshot());
 await page.locator('.inherit-atlas-trigger').click();
 const dialog=page.locator('.inherit-atlas-dialog');
 await expect(dialog).toBeVisible();
 await expect(dialog.locator('.inherit-atlas-main')).toBeHidden();
 await expect(dialog.locator('.inherit-atlas-status')).toContainText('You need two different saved states');
 await expect(dialog.locator('.inherit-atlas-field select').first()).toBeDisabled();
 await expect.poll(()=>page.evaluate(()=>window.InheritGame.snapshot().generation)).toBe(start.generation);
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(JSON.stringify(start));
 await page.keyboard.press('Escape');
 await expect(dialog).toBeHidden();
 expect(errors).toEqual([]);
});


test('INHERIT R7: only a real server-confirmed generation opens the star-lit handoff receipt',async({page})=>{
 const errors=await prepareStandaloneGame(page);
 const requests=[];
 await page.route('**/api/world/quiet-reach/generations',route=>{
  const body=route.request().postDataJSON();requests.push(body);
  return route.fulfill({status:201,contentType:'application/json',
   body:JSON.stringify({currentGeneration:body.expectedGeneration+1,
    generation:{number:body.expectedGeneration,author:body.author,message:body.message}})});
 });
 await page.goto('/games/inherit/?lang=ru',{waitUntil:'domcontentloaded'});
 const moment=page.locator('.inherit-handoff-moment');
 await expect(moment).toBeHidden();
 await page.locator('#pass').click(); // no placed trace, so no completion
 await expect(moment).toBeHidden();
 await expect.poll(()=>requests.length).toBe(0);
 await page.locator('#world').press('Enter');
 await expect(page.locator('#budget')).toHaveText('99');
 await page.locator('#pass').click();
 await expect(moment).toBeVisible();
 await expect(moment).toHaveAttribute('data-verification','shared-server-confirmed');
 // A post-generation receipt must not intercept the existing legacy entry
 // on a touch viewport; this was discovered by the full mobile CI suite.
 await page.locator('.inherit-legacy-trigger').click();
 await expect(page.locator('.inherit-legacy-dialog')).toBeVisible();
 await page.locator('.inherit-legacy-close').click();
 await expect(moment.locator('.inherit-handoff-route')).toContainText('173 → 174');
 await expect(moment.locator('.inherit-handoff-source')).toContainText('Сервер подтвердил');
 await expect(moment.locator('.inherit-handoff-stat').first()).toContainText('1');
 await expect.poll(()=>requests.length).toBe(1);
 const committed=await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()));
 const model=await page.evaluate(()=>window.InheritHandoffMomentUI.peek());
 expect(model.source).toBe('explicit-commit-only');
 expect(model.verification).toBe('shared-server-confirmed');
 await moment.locator('.inherit-handoff-details-trigger').click();
 await expect(moment.locator('.inherit-handoff-count')).toHaveCount(1);
 await expect(moment.locator('.inherit-handoff-pin')).toHaveCount(1);
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(committed);
 await page.locator('[data-game-language="zh"]').click();
 await expect(moment.locator('.inherit-handoff-title')).toContainText('痕迹已留下');
 await expect(moment.locator('.inherit-handoff-source')).toContainText('服务器');
 await moment.locator('.inherit-handoff-next').click();
 await expect(moment).toBeHidden();
 await expect(page.locator('.inherit-atlas-dialog')).toBeVisible();
 await page.keyboard.press('Escape');
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(committed);
 expect(errors).toEqual([]);
});

test('INHERIT R7: offline preservation is clearly unverified, and conflict never grants a receipt',async({page})=>{
 const errors=await prepareStandaloneGame(page);
 await page.goto('/games/inherit/?lang=en',{waitUntil:'domcontentloaded'});
 const moment=page.locator('.inherit-handoff-moment');
 await page.locator('#world').press('Enter');
 await page.locator('#pass').click(); // offline fixture returns 503
 await expect(moment).toBeVisible();
 await expect(moment).toHaveAttribute('data-verification','local-saved-server-unverified');
 await expect(moment.locator('.inherit-handoff-source')).toContainText('Server confirmation is unknown');
 const first=await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()));
 await moment.locator('.inherit-handoff-continue').click();
 await expect(moment).toBeHidden();
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(first);
 // A 409 from the shared server must leave pending work intact with NO new receipt.
 await page.route('**/api/world/quiet-reach/generations',route=>route.fulfill({
  status:409,contentType:'application/json',body:'{"error":"generation conflict fixture"}'
 }));
 await page.locator('#world').press('Enter');
 const before=await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()));
 await page.locator('#pass').click();
 await expect(page.locator('#caption')).toContainText('Your pending traces');
 await expect(moment).toBeHidden();
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(before);
 expect(errors).toEqual([]);
});


test('INHERIT R8 real time-lapse plays only saved island frames without changing world state',async({page})=>{
 const errors=await prepareStandaloneGame(page);
 // CI normally emulates reduced motion; explicit opt-in playback must be
 // tested with ordinary motion, while the separate accessibility case
 // preserves and asserts reduced-motion behavior.
 await page.emulateMedia({reducedMotion:'no-preference'});
 await page.goto('/games/inherit/?lang=ru',{waitUntil:'domcontentloaded'});
 const original=await page.evaluate(()=>window.InheritGame.snapshot());
 await page.locator('.inherit-atlas-trigger').click();
 const dialog=page.locator('.inherit-atlas-dialog'),timeline=dialog.locator('.inherit-timelapse');
 await expect(dialog).toBeVisible();
 await expect(timeline.locator('.inherit-timelapse-title')).toContainText('Остров сквозь поколения');
 await expect(timeline.locator('.inherit-timelapse-intro')).toContainText('нет выдуманных');
 await expect(timeline.locator('.inherit-timelapse-frame')).toContainText('Поколение');
 await dialog.locator('.inherit-atlas-close').click();
 await page.locator('#world').press('Enter');
 await expect(page.locator('#budget')).toHaveText('99');
 await page.locator('#pass').click();
 await expect.poll(()=>page.evaluate(()=>window.InheritGame.snapshot().generation)).toBe(original.generation+1);
 await page.locator('.inherit-handoff-continue').click();
 const committed=await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()));
 await page.locator('.inherit-atlas-trigger').click();
 await expect(dialog).toBeVisible();
 await expect(timeline.locator('.inherit-timelapse-play')).toBeEnabled();
 const initial=await page.evaluate(()=>window.InheritTimeLapseUI.getModel());
 expect(initial.status).toBe('ok');
 expect(initial.frameCount).toBeGreaterThanOrEqual(2);
 expect(initial.source).toBe('local-or-account-saved-frame');
 expect(initial.transition).toBe('first-available');
 await timeline.locator('.inherit-timelapse-next').click();
 const later=await page.evaluate(()=>window.InheritTimeLapseUI.getModel());
 expect(later.index).toBe(1);
 expect(later.transition).toBe('adjacent-saved-frames');
 expect(later.changes.added).toBeGreaterThanOrEqual(1);
 await expect(timeline.locator('.inherit-timelapse-pin--added')).not.toHaveCount(0);
 await timeline.locator('.inherit-timelapse-prev').click();
 await timeline.locator('.inherit-timelapse-play').click();
 await expect.poll(()=>page.evaluate(()=>window.InheritTimeLapseUI.getState().playing),{timeout:5000}).toBe(false);
 await expect.poll(()=>page.evaluate(()=>window.InheritTimeLapseUI.getState().index)).toBe(1);
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(committed);
 await dialog.locator('.inherit-atlas-close').click();
 await page.locator('[data-game-language="zh"]').click();
 await page.locator('.inherit-atlas-trigger').click();
 await expect(timeline.locator('.inherit-timelapse-title')).toHaveText('世代中的岛屿');
 await expect(timeline.locator('.inherit-timelapse-disclosure')).toContainText('不是他人操作的录像');
 await page.keyboard.press('Escape');
 expect(await page.evaluate(()=>window.InheritTimeLapseUI.getState().playing)).toBe(false);
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(committed);
 expect(errors).toEqual([]);
});

test('INHERIT R8 honors reduced-motion and discloses missing generations, without replay mutation',async({page})=>{
 const errors=await prepareStandaloneGame(page);
 await page.emulateMedia({reducedMotion:'reduce'});
 await page.goto('/games/inherit/?lang=en',{waitUntil:'domcontentloaded'});
 const generation=await page.evaluate(()=>{
  const game=window.InheritGame,state=game.snapshot(),oldGen=state.generation;
  state.generation+=5;
  state.snapshots=[{generation:oldGen,objects:[]}];
  state.objects=[{tool:'tree',x:32,y:43}];state.pending=[];state.changes=[];state.budget=100;
  game.apply(state);
  return state.generation;
 });
 const before=await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()));
 await page.locator('.inherit-atlas-trigger').click();
 const tl=page.locator('.inherit-timelapse');
 await expect(tl).toBeVisible();
 await expect(tl.locator('.inherit-timelapse-play')).toBeDisabled();
 await expect(tl.locator('.inherit-timelapse-warning')).toContainText('Autoplay is disabled');
 await tl.locator('.inherit-timelapse-scrubber input').focus();
 await tl.locator('.inherit-timelapse-scrubber input').press('End');
 await expect(tl.locator('.inherit-timelapse-warning')).toContainText('Saved frames are missing');
 await expect(tl.locator('.inherit-timelapse-warning')).toContainText('Intermediate history is unknown');
 await expect(tl.locator('.inherit-timelapse-frame')).toContainText(String(generation));
 await expect(tl.locator('.inherit-timelapse-pin--added')).toHaveCount(1);
 expect(await page.evaluate(()=>window.InheritTimeLapseUI.getState().playing)).toBe(false);
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(before);
 await page.keyboard.press('Escape');
 expect(errors).toEqual([]);
});


test('INHERIT R9 inspects an actual placed trace without spending a second move',async({page},info)=>{
 const errors=await prepareStandaloneGame(page);
 await page.goto('/games/inherit/?lang=ru',{waitUntil:'domcontentloaded'});
 await page.locator('#world').focus();
 await page.locator('#world').press('Enter');
 await expect(page.locator('#objects button.placed')).toHaveCount(1);
 const before=await page.evaluate(()=>window.InheritGame.snapshot());
 expect(before.budget).toBe(99);
 const trace=page.locator('#objects button.placed').first();
 await expect(trace).toHaveAttribute('aria-label',/Исследовать след: Дерево/);
 const launch=async()=>info.project.name==='mobile'?
  page.locator('.inherit-trace-launcher').click():trace.click();
 await expect(page.locator('.inherit-trace-launcher')).toBeEnabled();
 if(info.project.name==='mobile'){
  await expect(page.locator('.inherit-guide-actions .inherit-trace-launcher')).toHaveCount(1);
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);
 }
 await launch();
 const dialog=page.locator('.inherit-trace-inspector');
 await expect(dialog).toBeVisible();
 await expect(dialog.locator('.inherit-trace-title')).toContainText('Дерево');
 await expect(dialog.locator('.inherit-trace-status')).toContainText('ожидает завершения');
 await expect(dialog.locator('.inherit-trace-pin--selected')).toHaveCount(1);
 await expect(dialog.locator('.inherit-trace-counter')).toContainText('1 из 1');
 await expect(dialog.locator('.inherit-trace-prev')).toBeDisabled();
 await expect(dialog.locator('.inherit-trace-next')).toBeDisabled();
 await expect(page.locator('#panel')).not.toHaveClass(/show/);
 const model=await page.evaluate(()=>window.InheritTraceInspectorUI.getModel());
 expect(model.status).toBe('ok');
 expect(model.draft).toBe(true);
 expect(model.selected.type).toBe('tree');
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(JSON.stringify(before));
 await page.keyboard.press('Escape');
 await expect(dialog).toBeHidden();
 await expect(info.project.name==='mobile'?page.locator('.inherit-trace-launcher'):trace).toBeFocused();
 await page.locator('[data-game-language="en"]').click();
 await launch();
 await expect(dialog.locator('.inherit-trace-title')).toContainText('Tree');
 await expect(dialog.locator('.inherit-trace-disclosure')).toContainText('does not prove');
 await dialog.locator('.inherit-trace-atlas').click();
 await expect(dialog).toBeHidden();
 await expect(page.locator('.inherit-atlas-dialog')).toBeVisible();
 await page.locator('.inherit-atlas-close').click();
 await page.locator('[data-game-language="zh"]').click();
 await launch();
 await expect(dialog.locator('.inherit-trace-title')).toContainText('树木');
 await expect(dialog.locator('.inherit-trace-disclosure')).toContainText('不会修改世界');
 await dialog.locator('.inherit-trace-close').click();
 await expect(dialog).toBeHidden();
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(JSON.stringify(before));
 expect(errors).toEqual([]);
});

test('INHERIT R9 shows real archived matching generations and existing legacy grove pairing',async({page})=>{
 const errors=await prepareStandaloneGame(page);
 await page.goto('/games/inherit/?lang=ru',{waitUntil:'domcontentloaded'});
 await page.evaluate(()=>{
  const game=window.InheritGame,s=game.snapshot();
  s.generation=174;s.budget=100;s.pending=[];s.changes=[];
  s.objects=[{tool:'tree',x:34,y:42},{tool:'moss',x:37,y:43},{tool:'stone',x:85,y:77}];
  s.snapshots=[
   {generation:170,objects:[{tool:'tree',x:34,y:42}]},
   {generation:172,objects:[{tool:'tree',x:34,y:42},{tool:'stone',x:85,y:77}]},
   {generation:173,objects:[{tool:'tree',x:60,y:63}]}
  ];
  game.apply(s);
 });
 await expect(page.locator('#objects button.placed')).toHaveCount(3);
 const before=await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()));
 await page.locator('.inherit-trace-launcher').click();
 const dialog=page.locator('.inherit-trace-inspector');
 await expect(dialog.locator('.inherit-trace-counter')).toContainText('3 из 3');
 await dialog.locator('.inherit-trace-prev').click();
 await dialog.locator('.inherit-trace-prev').click();
 await expect(dialog.locator('.inherit-trace-counter')).toContainText('1 из 3');
 await expect(dialog).toBeVisible();
 await expect(dialog.locator('.inherit-trace-connection')).toContainText('Роща');
 await expect(dialog.locator('.inherit-trace-connection')).toContainText('Мох');
 const details=await page.evaluate(()=>window.InheritTraceInspectorUI.getModel());
 expect(details.evidence.firstMatch).toBe(170);
 expect(details.evidence.latestMatch).toBe(172);
 expect(details.evidence.matchedFrames).toBe(2);
 expect(details.connectionTotal).toBe(1);
 expect(details.connections[0].id).toBe('grove');
 expect(details.draft).toBe(false);
 await expect(dialog.locator('.inherit-trace-history')).toContainText('170');
 await expect(dialog.locator('.inherit-trace-map .inherit-trace-pin--compatible')).toHaveCount(1);
 await expect(page.locator('#budget')).toHaveText('100');
 await dialog.locator('.inherit-trace-back').click();
 await expect(dialog).toBeHidden();
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(before);
 expect(errors).toEqual([]);
});


test('INHERIT trace compass: starter guidance and an actual two-tool Legacy connection without invented moves',async({page})=>{
 const errors=await prepareStandaloneGame(page);
 await page.goto('/games/inherit/?lang=ru',{waitUntil:'domcontentloaded'});
 const before=await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()));
 const trigger=page.locator('.inherit-compass-trigger'),dialog=page.locator('.inherit-compass-dialog');
 await expect(trigger).toBeVisible();
 await trigger.click();
 await expect(dialog).toBeVisible();
 await expect(dialog.locator('.inherit-compass-title')).toHaveText('Компас следов');
 await expect(dialog.locator('.inherit-compass-status')).toContainText('Начни с дерева');
 const starter=await page.evaluate(()=>window.InheritTraceCompassUI.getPlan());
 expect(starter.status).toBe('first-trace');
 expect(starter.choices[0].newLinks).toBe(0);
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(before);
 await dialog.locator('.inherit-compass-use').click();
 await expect(dialog).toBeHidden();
 await expect(page.locator('.inherit-compass-ghost')).toBeVisible();
 await expect(page.locator('.inherit-first-steps')).toBeHidden();
 expect(await page.evaluate(()=>document.body.classList.contains('inherit-compass-armed'))).toBe(true);
 // On a 390px-wide screen the old island placement put the hint BELOW the
 // visible stage, inside the tool dock. A visible CSS node is not enough:
 // the physical point must hit the island, not a button/overlay.
 const locateHit=()=>page.evaluate(()=>{
  const dot=document.querySelector('.inherit-compass-ghost').getBoundingClientRect();
  const x=dot.left+dot.width/2,y=dot.top+dot.height/2;
  const target=document.elementFromPoint(x,y);
  return {insideViewport:x>=0&&x<innerWidth&&y>=0&&y<innerHeight,
   hitWorld:!!target?.closest('#world'),
   blockedByButton:!!target?.closest('button,.dock,[data-memory]'),
   target:target?.className||target?.tagName};
 });
 // Allow the browser one paint after the dialog's focus restoration and
 // require an actual hit on the island, not merely a visible CSS dot.
 await expect.poll(async()=>{const hit=await locateHit();
  return hit.insideViewport&&hit.hitWorld&&!hit.blockedByButton;
 },{timeout:6000}).toBe(true);
 const hit=await locateHit();
 expect(hit.insideViewport).toBe(true);
 expect(hit.hitWorld).toBe(true);
 expect(hit.blockedByButton).toBe(false);
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(before);
 const place=async choice=>{
  const p=await page.locator('#island').boundingBox();
  await page.mouse.click(p.x+p.width*choice.x/100,p.y+p.height*choice.y/100);
 };
 await place(starter.choices[0]);
 await expect.poll(()=>page.evaluate(()=>window.InheritGame.snapshot().objects.length)).toBe(1);
 await expect(page.locator('.inherit-compass-ghost')).toBeHidden();
 await expect(page.locator('.inherit-first-steps')).toBeVisible();
 expect(await page.evaluate(()=>document.body.classList.contains('inherit-compass-armed'))).toBe(false);
 await trigger.click();
 const option=await page.evaluate(()=>window.InheritTraceCompassUI.getPlan());
 expect(option.status).toBe('opportunities');
 const moss=option.choices.find(x=>x.tool==='moss'&&x.rules.some(r=>r.id==='grove'));
 expect(moss).toBeTruthy();
 expect(moss.newLinks).toBe(1);
 const buttons=dialog.locator('.inherit-compass-option');
 await buttons.nth(option.choices.findIndex(x=>x.tool==='moss')).click();
 const unchanged=await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()));
 await dialog.locator('.inherit-compass-use').click();
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(unchanged);
 await expect.poll(async()=>{const hit=await locateHit();
  return hit.insideViewport&&hit.hitWorld&&!hit.blockedByButton;
 },{timeout:6000}).toBe(true);
 await place(moss);
 await expect.poll(()=>page.evaluate(()=>window.InheritGame.snapshot().objects.length)).toBe(2);
 await expect.poll(()=>page.evaluate(()=>window.InheritLegacyUI.getState().totals.grove)).toBe(1);
 const after=await page.evaluate(()=>window.InheritGame.snapshot());
 expect(after.budget).toBe(98);
 expect(after.generation).toBe(173);
 await expect(page.locator('.inherit-compass-ghost')).toBeHidden();
 expect(errors).toEqual([]);
});

test('INHERIT trace compass: multilingual, keyboard-dismissable and read-only on account worlds',async({page})=>{
 const errors=await prepareStandaloneGame(page);
 await page.goto('/games/inherit/?mode=account&lang=en',{waitUntil:'domcontentloaded'});
 const before=await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()));
 const dialog=page.locator('.inherit-compass-dialog'),trigger=page.locator('.inherit-compass-trigger');
 await trigger.click();
 await expect(dialog).toBeVisible();
 await expect(dialog.locator('.inherit-compass-title')).toHaveText('Trace compass');
 await expect(dialog.locator('.inherit-compass-note')).toContainText('server permissions');
 await expect(dialog.locator('.inherit-compass-status')).toContainText('Start with a tree');
 await page.keyboard.press('Escape');
 await expect(dialog).toBeHidden();
 await expect(page.locator('.inherit-compass-ghost')).toBeHidden();
 await page.locator('[data-game-language="zh"]').click();
 await trigger.click();
 await expect(dialog.locator('.inherit-compass-title')).toHaveText('痕迹罗盘');
 await expect(dialog.locator('.inherit-compass-intro')).toContainText('真实存档');
 await dialog.locator('.inherit-compass-close').click();
 await expect(dialog).toBeHidden();
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(before);
 expect(errors).toEqual([]);
});

test('INHERIT trace compass: exhausted turn blocks misleading placements and does not modify budget',async({page})=>{
 const errors=await prepareStandaloneGame(page);
 await page.goto('/games/inherit/?lang=ru',{waitUntil:'domcontentloaded'});
 await page.evaluate(()=>{
  const s=window.InheritGame.snapshot();
  window.InheritGame.apply({...s,budget:0,objects:[{tool:'tree',x:45,y:45}],pending:[],changes:[]});
 });
 const before=await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()));
 await page.locator('.inherit-compass-trigger').click();
 const panel=page.locator('.inherit-compass-dialog');
 await expect(panel.locator('.inherit-compass-status')).toContainText('исчерпан');
 await expect(panel.locator('.inherit-compass-use')).toBeDisabled();
 await expect(panel.locator('.inherit-compass-candidates button')).toHaveCount(0);
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(before);
 await page.keyboard.press('Escape');
 expect(errors).toEqual([]);
});



test('INHERIT R9 saved-trace inspector opens R10 compass without spending a move',async({page})=>{
 const errors=await prepareStandaloneGame(page);
 await page.goto('/games/inherit/?lang=ru',{waitUntil:'domcontentloaded'});
 await page.locator('#world').focus();
 await page.locator('#world').press('Enter');
 await expect.poll(()=>page.evaluate(()=>window.InheritGame.snapshot().objects.length)).toBe(1);
 const before=await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()));
 await page.locator('.inherit-trace-launcher').click();
 const inspector=page.locator('.inherit-trace-inspector'),compass=page.locator('.inherit-compass-dialog');
 await expect(inspector).toBeVisible();
 const plan=inspector.locator('.inherit-trace-compass-plan');
 await expect(plan).toHaveText('Спланировать следующий след');
 await expect(plan).toBeEnabled();
 await plan.click();
 await expect(inspector).toBeHidden();
 await expect(compass).toBeVisible();
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(before);
 await compass.locator('.inherit-compass-close').click();
 await expect(compass).toBeHidden();
 expect(errors).toEqual([]);
});


test('INHERIT R11 network shows a real two-link saved chain and preserves the world',async({page})=>{
 const errors=await prepareStandaloneGame(page);
 await page.goto('/games/inherit/?lang=ru',{waitUntil:'domcontentloaded'});
 await page.evaluate(()=>{
  const s=window.InheritGame.snapshot();
  window.InheritGame.apply({...s,generation:173,budget:97,
    objects:[{tool:'path',x:30,y:40},{tool:'light',x:40,y:40},{tool:'cairn',x:51,y:40}],
    pending:[],changes:[],snapshots:[]});
 });
 const original=await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()));
 const trigger=page.locator('.inherit-network-trigger'),dialog=page.locator('.inherit-network-dialog');
 await expect(trigger).toBeVisible();await trigger.click();
 await expect(dialog).toBeVisible();
 await expect(dialog.locator('.inherit-network-title')).toHaveText('Сеть наследия');
 const graph=await page.evaluate(()=>window.InheritLegacyNetworkUI.getGraph());
 expect(graph.status).toBe('ok');expect(graph.links).toBe(2);expect(graph.components).toHaveLength(1);
 await dialog.locator('select[name="inherit-network-end"]').selectOption('2');
 await expect(dialog.locator('.inherit-network-status')).toContainText('цепочкой из 2');
 const route=await page.evaluate(()=>window.InheritLegacyNetworkUI.getRoute());
 expect(route.status).toBe('connected');expect(route.path).toEqual([0,1,2]);
 await expect(dialog.locator('.inherit-network-svg .inherit-network-edge--route')).toHaveCount(2);
 await expect(dialog.locator('.inherit-network-chain li')).toHaveCount(3);
 await expect(dialog.locator('.inherit-network-bridge')).toBeHidden();
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(original);
 await page.keyboard.press('Escape');
 await expect(dialog).toBeHidden();
 expect(errors).toEqual([]);
});

test('INHERIT R11 optional bridge requires a genuine second island click and creates real legacy rules',async({page})=>{
 const errors=await prepareStandaloneGame(page);
 await page.goto('/games/inherit/?lang=ru',{waitUntil:'domcontentloaded'});
 await page.evaluate(()=>{
  const s=window.InheritGame.snapshot();
  window.InheritGame.apply({...s,generation:173,budget:98,
    objects:[{tool:'path',x:30,y:40},{tool:'cairn',x:49,y:40}],
    pending:[],changes:[],snapshots:[]});
 });
 const before=await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()));
 const trigger=page.locator('.inherit-network-trigger'),dialog=page.locator('.inherit-network-dialog');
 await trigger.click();
 await expect(dialog.locator('.inherit-network-status')).toContainText('нет цепочки');
 const hint=await page.evaluate(()=>window.InheritLegacyNetworkUI.getSuggestion());
 expect(hint.status).toBe('suggested');expect(hint.tool).toBe('light');
 await expect(dialog.locator('.inherit-network-choose')).toBeEnabled();
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(before);
 await dialog.locator('.inherit-network-choose').click();
 await expect(dialog).toBeHidden();
 await expect(page.locator('.inherit-network-ghost')).toBeVisible();
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(before);
 const markerHit=()=>page.evaluate(()=>{
  const dot=document.querySelector('.inherit-network-ghost').getBoundingClientRect();
  const x=dot.left+dot.width/2,y=dot.top+dot.height/2;
  const target=document.elementFromPoint(x,y);
  return {inside:x>=0&&x<innerWidth&&y>=0&&y<innerHeight,
    hit:!!target?.closest('#world'),blocked:!!target?.closest('button,.dock,[data-memory]')};
 });
 await expect.poll(async()=>{
  const hit=await markerHit();return hit.inside&&hit.hit&&!hit.blocked;
 },{timeout:6000}).toBe(true);
 const bounds=await page.locator('#island').boundingBox();
 await page.mouse.click(bounds.x+bounds.width*hint.x/100,bounds.y+bounds.height*hint.y/100);
 await expect.poll(()=>page.evaluate(()=>window.InheritGame.snapshot().objects.length)).toBe(3);
 await expect.poll(()=>page.evaluate(()=>window.InheritLegacyUI.getState().total)).toBe(2);
 await expect(page.locator('.inherit-network-ghost')).toBeHidden();
 const next=await page.evaluate(()=>window.InheritGame.snapshot());
 expect(next.generation).toBe(173);expect(next.budget).toBe(97);
 expect(next.pending).toHaveLength(1);
 await trigger.click();
 await expect(dialog.locator('.inherit-network-status')).toContainText('цепочкой из 2');
 expect((await page.evaluate(()=>window.InheritLegacyNetworkUI.getGraph())).components).toHaveLength(1);
 await dialog.locator('.inherit-network-close').click();
 expect(errors).toEqual([]);
});

test('INHERIT R11 respects account read-only, language changes and exhausted budgets',async({page})=>{
 const errors=await prepareStandaloneGame(page);
 await page.goto('/games/inherit/?mode=account&lang=en',{waitUntil:'domcontentloaded'});
 await page.evaluate(()=>{
  const s=window.InheritGame.snapshot();
  window.InheritGame.apply({...s,objects:[{tool:'path',x:31,y:40},{tool:'cairn',x:50,y:40}],
    generation:173,budget:0,pending:[],changes:[]});
 });
 const original=await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()));
 const trigger=page.locator('.inherit-network-trigger'),dialog=page.locator('.inherit-network-dialog');
 await trigger.click();
 await expect(dialog.locator('.inherit-network-title')).toHaveText('Legacy network');
 await expect(dialog.locator('.inherit-network-source')).toContainText('nearest neighbours');
 await expect(dialog.locator('.inherit-network-bridge')).toContainText('budget exhausted');
 await expect(dialog.locator('.inherit-network-choose')).toBeDisabled();
 await page.keyboard.press('Escape');
 await expect(dialog).toBeHidden();
 await expect(page.locator('.inherit-network-ghost')).toBeHidden();
 await page.locator('[data-game-language="zh"]').click();
 await trigger.click();
 await expect(dialog.locator('.inherit-network-title')).toHaveText('传承网络');
 await expect(dialog.locator('.inherit-network-intro')).toContainText('真实保存');
 await dialog.locator('.inherit-network-close').click();
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(original);
 expect(errors).toEqual([]);
});


test('INHERIT R9 inspector opens R11 network anchored to the selected real trace',async({page})=>{
 const errors=await prepareStandaloneGame(page);
 await page.goto('/games/inherit/?lang=ru',{waitUntil:'domcontentloaded'});
 await page.evaluate(()=>{
  const s=window.InheritGame.snapshot();
  window.InheritGame.apply({...s,objects:[
   {tool:'path',x:30,y:40},{tool:'light',x:40,y:40},{tool:'cairn',x:51,y:40}
  ],generation:173,budget:97,pending:[],changes:[]});
 });
 const original=await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()));
 await page.locator('.inherit-trace-launcher').click();
 const inspector=page.locator('.inherit-trace-inspector');
 await expect(inspector).toBeVisible();
 await expect(inspector.locator('.inherit-trace-counter')).toContainText('3 из 3');
 const forward=inspector.locator('.inherit-trace-network-link');
 await expect(forward).toHaveText('Просмотреть сеть связей');
 await expect(forward).toBeEnabled();
 await forward.click();
 await expect(inspector).toBeHidden();
 const network=page.locator('.inherit-network-dialog');
 await expect(network).toBeVisible();
 await expect(network.locator('select[name="inherit-network-start"]')).toHaveValue('2');
 await network.locator('select[name="inherit-network-end"]').selectOption('0');
 await expect(network.locator('.inherit-network-status')).toContainText('цепочкой из 2');
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(original);
 await page.keyboard.press('Escape');
 await expect(network).toBeHidden();
 expect(errors).toEqual([]);
});


test('INHERIT R12 memory expedition requires an actual island click to honor archived legacy',async({page})=>{
 const errors=await prepareStandaloneGame(page);
 await page.goto('/games/inherit/?lang=ru',{waitUntil:'domcontentloaded'});
 await page.evaluate(()=>{
  const s=window.InheritGame.snapshot(),tree={tool:'tree',x:56,y:46};
  window.InheritGame.apply({...s,generation:173,budget:99,objects:[tree],
   pending:[],changes:[],snapshots:[{generation:171,objects:[tree]}]});
 });
 const original=await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()));
 const trigger=page.locator('.inherit-expedition-trigger'),dialog=page.locator('.inherit-expedition-dialog');
 await expect(trigger).toBeVisible();await trigger.click();
 await expect(dialog).toBeVisible();
 await expect(dialog.locator('.inherit-expedition-title')).toHaveText('Экспедиции памяти');
 const goal=await page.evaluate(()=>window.InheritMemoryExpeditionsUI.getPlan().goals[0]);
 expect(goal.kind).toBe('honor');expect(goal.tool).toBe('moss');
 await expect(dialog.locator('.inherit-expedition-goal-text')).toContainText('Тихая роща');
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(original);
 await dialog.locator('.inherit-expedition-use').click();
 await expect(dialog).toBeHidden();
 await expect(page.locator('.inherit-expedition-ghost')).toBeVisible();
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(original);
 const island=page.locator('#island');
 await expect.poll(()=>page.evaluate(()=>{
  const dot=document.querySelector('.inherit-expedition-ghost').getBoundingClientRect();
  const x=dot.left+dot.width/2,y=dot.top+dot.height/2,node=document.elementFromPoint(x,y);
  return x>=0&&x<innerWidth&&y>=0&&y<innerHeight &&
    Boolean(node?.closest('#world'))&&!node?.closest('button,.dock,[data-memory]');
 }),{timeout:9000}).toBe(true);
 const rect=await island.boundingBox();
 await page.mouse.click(rect.x+rect.width*goal.x/100,rect.y+rect.height*goal.y/100);
 await expect.poll(()=>page.evaluate(()=>window.InheritGame.snapshot().objects.length)).toBe(2);
 await expect.poll(()=>page.evaluate(()=>window.InheritLegacyUI.getState().totals.grove)).toBe(1);
 await expect(page.locator('.inherit-expedition-ghost')).toBeHidden();
 await expect(page.locator('.inherit-expedition-confirm')).toBeVisible();
 const recorded=await page.evaluate(()=>window.InheritMemoryExpeditionsUI.getResult());
 expect(recorded.status).toBe('observed-placement');
 const after=await page.evaluate(()=>window.InheritGame.snapshot());
 expect(after.generation).toBe(173);
 expect(after.budget).toBe(98);
 expect(after.pending).toHaveLength(1);
 await page.locator('.inherit-expedition-confirm-actions button').first().click();
 await expect(page.locator('#pass')).toBeFocused();
 await page.locator('.inherit-expedition-confirm-actions button').last().click();
 await expect(page.locator('.inherit-expedition-confirm')).toBeHidden();
 expect(errors).toEqual([]);
});

test('INHERIT R12 restores only a real past location and never invents an owner or completion',async({page})=>{
 const errors=await prepareStandaloneGame(page);
 await page.goto('/games/inherit/?lang=en',{waitUntil:'domcontentloaded'});
 await page.evaluate(()=>{
  const s=window.InheritGame.snapshot();
  window.InheritGame.apply({...s,generation:175,budget:100,objects:[],pending:[],changes:[],
   snapshots:[{generation:173,objects:[{tool:'stone',x:55,y:58}]}]});
 });
 const original=await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()));
 await page.locator('.inherit-expedition-trigger').click();
 const dialog=page.locator('.inherit-expedition-dialog');
 await expect(dialog).toContainText('RECOVER THE PAST');
 const goal=await page.evaluate(()=>window.InheritMemoryExpeditionsUI.getPlan().goals[0]);
 expect(goal.kind).toBe('restore');expect(goal.tool).toBe('stone');
 await expect(dialog.locator('.inherit-expedition-goal-text')).toContainText('A Stone was recorded');
 await dialog.locator('.inherit-expedition-use').click();
 await expect(page.locator('.inherit-expedition-ghost')).toBeVisible();
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(original);
 await expect.poll(()=>page.evaluate(()=>{
  const dot=document.querySelector('.inherit-expedition-ghost').getBoundingClientRect();
  const x=dot.left+dot.width/2,y=dot.top+dot.height/2,node=document.elementFromPoint(x,y);
  return x>=0&&x<innerWidth&&y>=0&&y<innerHeight&&
    Boolean(node?.closest('#world'))&&!node?.closest('button,.dock,[data-memory]');
 }),{timeout:9000}).toBe(true);
 const rect=await page.locator('#island').boundingBox();
 await page.mouse.click(rect.x+rect.width*goal.x/100,rect.y+rect.height*goal.y/100);
 await expect.poll(()=>page.evaluate(()=>window.InheritGame.snapshot().objects.length)).toBe(1);
 const verified=await page.evaluate(()=>window.InheritMemoryExpeditionsUI.getResult());
 expect(verified.status).toBe('observed-placement');expect(verified.kind).toBe('restore');
 await expect(page.locator('.inherit-expedition-confirm')).toContainText('not a confirmed generation handoff');
 expect((await page.evaluate(()=>window.InheritGame.snapshot())).generation).toBe(175);
 expect(errors).toEqual([]);
});

test('INHERIT R12 has honest no-archive and zero-budget states in account mode across languages',async({page})=>{
 const errors=await prepareStandaloneGame(page);
 await page.goto('/games/inherit/?mode=account&lang=en',{waitUntil:'domcontentloaded'});
 await page.evaluate(()=>{
  const s=window.InheritGame.snapshot();
  window.InheritGame.apply({...s,generation:175,budget:100,objects:[],pending:[],changes:[],snapshots:[]});
 });
 const before=await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()));
 const trigger=page.locator('.inherit-expedition-trigger'),dialog=page.locator('.inherit-expedition-dialog');
 await trigger.click();
 await expect(dialog.locator('.inherit-expedition-status')).toContainText('No genuine snapshot');
 await expect(dialog.locator('.inherit-expedition-layout')).toBeHidden();
 await page.keyboard.press('Escape');await expect(dialog).toBeHidden();
 await page.evaluate(()=>{
  const s=window.InheritGame.snapshot(),tree={tool:'tree',x:56,y:46};
  window.InheritGame.apply({...s,generation:175,budget:0,objects:[tree],pending:[],changes:[],
   snapshots:[{generation:172,objects:[tree]}]});
 });
 const readonly=await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()));
 await trigger.click();
 await expect(dialog.locator('.inherit-expedition-status')).toContainText('no budget left');
 await expect(dialog.locator('.inherit-expedition-use')).toBeDisabled();
 await page.keyboard.press('Escape');await expect(dialog).toBeHidden();
 await expect(page.locator('.inherit-expedition-ghost')).toBeHidden();
 await page.locator('[data-game-language="zh"]').click();
 await trigger.click();
 await expect(dialog.locator('.inherit-expedition-title')).toHaveText('记忆远征');
 await expect(dialog.locator('.inherit-expedition-provenance')).toContainText('账号世界');
 await expect(dialog.locator('.inherit-expedition-use')).toBeDisabled();
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(readonly);
 expect(JSON.parse(before).objects).toHaveLength(0);
 expect(errors).toEqual([]);
});

for (const [locale, path] of [['ru','/entertainment/archive/'], ['en','/entertainment/en/'], ['ar','/entertainment/ar/']]) {
  test('Entertainment World Select shows seven real illustrated archived worlds in ' + locale, async ({ page }) => {
    const errors = []
    page.on('pageerror', error => errors.push(error.message))
    await page.goto(path)
    await expect(page.locator('body.entertainment-premium')).toBeVisible()
    if (locale !== 'ru') await expect(page.locator('.lang-switch a[lang="ru"]')).toHaveAttribute('href', '/entertainment/archive/')
    await expect(page.locator('link[href="/entertainment/premium.css"]')).toHaveCount(1)
    await expect(page.locator('.hero-cta')).toHaveAttribute('href', '/play')
    await expect(page.locator('.hero-spotlight')).toHaveAttribute('href', '/play')
    const heroImage = page.locator('.hero-spotlight img')
    await expect(heroImage).toHaveAttribute('src', '/brand/omega-play.svg')
    expect(await heroImage.evaluate(img => img.complete && img.naturalWidth > 0)).toBe(true)
    await expect(page.locator('.grid .card')).toHaveCount(7)
    await expect(page.locator('.grid .art img')).toHaveCount(7)
    const imageStatus = await page.locator('.grid .art img').evaluateAll(async images => {
      // Archive artwork is lazy in production. Explicitly decode each cover
      // before checking the asset, independent of which card is in the viewport.
      await Promise.all(images.map(async img => { img.loading = 'eager'; await img.decode().catch(() => {}) }))
      return images.map(img => ({
        src: new URL(img.src).pathname,
        loaded: img.complete && img.naturalWidth > 0
      }))
    })
    expect(imageStatus.every(image => image.loaded)).toBe(true)
    expect(new Set(imageStatus.map(image => image.src)).size).toBe(7)
    await expect(page.locator('.grid .card[href="/games/time-empire/"]')).toHaveCount(1)
    await expect(page.locator('.case-shelf .case-feature')).toHaveCount(4)
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true)
    expect(errors).toEqual([])
  })
}

test('Development Signature opens real case screens, preserves status disclosure and is responsive', async ({ page }) => {
  const errors = []
  page.on('pageerror', error => errors.push(error.message))
  await page.goto('/development')
  const surface = page.locator('.development-signature')
  const showcase = surface.locator('.signature-showcase')
  await expect(showcase).toBeVisible()
  await expect(surface.locator('h1')).toContainText('ЦИФРОВЫЕ')
  await expect(showcase.locator('a.signature-featured-case')).toHaveAttribute('href', '/development/tedes/')
  await expect(showcase.locator('.signature-featured-image>span')).toContainText('Демо')
  const featureImg = showcase.locator('.signature-featured-image img')
  await expect(featureImg).toBeVisible()
  expect(await featureImg.evaluate(img => img.complete && img.naturalWidth > 0)).toBe(true)
  await expect(showcase.locator('.signature-case-pair>a')).toHaveCount(2)
  await expect(showcase.locator('.signature-case-pair>a').nth(0)).toHaveAttribute('href', '/development/phantom/')
  await expect(showcase.locator('.signature-case-pair>a').nth(1)).toHaveAttribute('href', '/development/merakki/')
  await expect(surface.locator('#cases .world-case')).toHaveCount(4)
  await expect(surface.locator('#cases .world-case .brand-status')).toHaveText(['Прототип','Демо','Концепт','Демо'])
  await expect(surface.locator('#contact form')).toBeVisible()
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true)
  await page.goto('/')
  await expect(page.locator('.development-signature')).toHaveCount(0)
  await expect(page.locator('.omega-hero')).toHaveCount(1)
  expect(errors).toEqual([])
})

test('OSA Evidence Command previews real claim checks and synchronises the full NIST source exercise', async ({ page }) => {
  const pageErrors = []
  page.on('pageerror', error => pageErrors.push(error.message))
  await page.goto('/intelligence')
  const console = page.locator('#proof-card')
  const claims = console.getByRole('button')
  await expect(console).toBeVisible()
  await expect(console.getByRole('heading', { name: 'Какие утверждения стоит проверить?' })).toBeVisible()
  await expect(claims).toHaveCount(3)
  await expect(console.locator('.intelligence-proof-summary')).toContainText('0 / 3')
  await expect(page.getByRole('navigation', { name: 'Быстрый старт обучения' }).getByRole('link')).toHaveCount(3)
  const localNav = page.getByRole('navigation', { name: 'Навигация раздела' })
  await expect(localNav.getByRole('link')).toHaveCount(3)
  await expect(localNav.getByRole('link').first()).toHaveAttribute('href', '/intelligence#proof-card')
  await expect(page.locator('#proof-card')).toHaveCount(1)
  await expect(page.locator('.intelligence-progress-rail')).toHaveAttribute('aria-valuenow', '0')
  await claims.nth(1).click()
  await expect(claims.nth(1)).toHaveAttribute('aria-pressed', 'true')
  await expect(page.locator('#demo .answer-claim').nth(1).getByRole('checkbox')).toBeChecked()
  await expect(console.locator('.intelligence-proof-summary')).toContainText('1 / 3')
  await page.locator('#demo .answer-claim').nth(1).getByRole('checkbox').uncheck()
  await expect(claims.nth(1)).toHaveAttribute('aria-pressed', 'false')
  await claims.nth(0).focus()
  await page.keyboard.press('Space')
  await expect(claims.nth(0)).toHaveAttribute('aria-pressed', 'true')
  await console.getByRole('link', { name: 'Посмотреть доказательства' }).click()
  await expect(page.locator('#demo-sources')).toBeVisible()
  await expect(page.locator('#demo-sources').getByRole('link', { name: /NIST AI 600-1/ })).toHaveAttribute('href', /nvlpubs\.nist\.gov\/nistpubs\/ai\/NIST\.AI\.600-1\.pdf/)
  await page.getByRole('button', { name: 'Начать заново', exact: true }).click()
  await expect(claims.nth(0)).toHaveAttribute('aria-pressed', 'false')
  await expect(page.locator('#demo-sources')).toBeHidden()
  await expect(console.locator('.intelligence-proof-summary')).toContainText('0 / 3')
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true)
  expect(pageErrors).toEqual([])
})

test('INHERIT R14 keeps native history and inspector reachable with readable gameplay', async ({page}) => {
  const errors=await prepareStandaloneGame(page);
  await page.goto('/games/inherit/?lang=ru',{waitUntil:'domcontentloaded'});
  await expect(page.locator('.living-journey')).toBeVisible();
  await expect(page.locator('.living-actions-strip .chronicle-button')).toBeVisible();
  // Native launcher mounts in the visible guide-actions row on mobile, not in the header rail.
  await expect(page.locator('.inherit-trace-launcher')).toBeVisible();
  await expect(page.locator('.living-library-toggle')).toBeVisible();
  await expect(page.locator('.hero h1')).toContainText('Кто-то проложил путь');
  const original=await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()));
  await page.locator('.living-font-toggle').click();
  await expect(page.locator('body')).toHaveAttribute('data-living-text','large');
  expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(original);
  await page.locator('.tool[data-tool=tree]').click();
  await expect(page.locator('.living-step.is-current .living-step-name')).toContainText('Оставь след');
  await page.locator('#world').focus();
  await page.locator('#world').press('Enter');
  await expect(page.locator('#objects > .placed.tree .living-object-art')).toHaveCount(1);
  await expect(page.locator('.living-step.is-current .living-step-name')).toContainText('Передай мир');
  await page.locator('.chronicle-button').click();
  await expect(page.locator('.chronicle')).toBeVisible();
  await page.locator('.chronicle .close').click();
  await expect(page.locator('.chronicle')).toBeHidden();
  expect(errors).toEqual([]);
});


test('INHERIT R15 World Alive chapter progress comes only from genuine placements',async({page})=>{
 const errors=await prepareStandaloneGame(page);
 await page.goto('/games/inherit/?lang=ru',{waitUntil:'domcontentloaded'});
 const hub=page.locator('.world-alive-hub');
 await expect(hub).toBeVisible();
 await expect(page.locator('.inherit-first-steps')).toBeVisible();
 // The real first-play coach must not paint over the narrative headline.
 await expect(page.locator('.world > .hero')).toHaveCSS('opacity','0');
 await expect(page.locator('.world-alive-goal')).toHaveCount(3);
 await expect(page.locator('.world-alive-metric')).toHaveCount(3);
 await expect(page.locator('.world-alive-ocean')).toHaveCount(1);
 await expect(page.locator('.world-alive-setting').last()).toHaveAttribute('aria-pressed','false');
 const before=await page.evaluate(()=>window.InheritGame.snapshot());
 const actual=await page.evaluate(()=>window.InheritWorldAliveUI.getState());
 expect(actual.objects).toBe(before.objects.length);
 expect(actual.connections).toBeGreaterThanOrEqual(0);
 await expect(page.locator('.world-alive-goal-action').first()).toBeEnabled();
 await page.locator('.world-alive-goal-action').first().click();
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(JSON.stringify(before));
 await page.locator('#world').focus();
 await page.locator('#world').press('Enter');
 await expect.poll(()=>page.evaluate(()=>window.InheritGame.snapshot().objects.length)).toBe(before.objects.length+1);
 const after=await page.evaluate(()=>window.InheritGame.snapshot());
 expect(after.budget).toBe(before.budget-1);
 expect(after.pending.length).toBe(before.pending.length+1);
 await expect(page.locator('.world-alive-metric').first()).toContainText(String(after.objects.length));
 expect(await page.evaluate(()=>window.InheritWorldAliveUI.getState().completed)).toBeGreaterThanOrEqual(1);
 expect(errors).toEqual([]);
});

test('INHERIT R15 never grants account editing rights or autoplay audio',async({page})=>{
 const errors=await prepareStandaloneGame(page);
 await page.goto('/games/inherit/?mode=account&lang=ru',{waitUntil:'domcontentloaded'});
 await expect(page.locator('.world-alive-hub')).toBeVisible();
 await expect(page.locator('.world-alive-goal-action').first()).toBeDisabled();
 const before=await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()));
 expect(await page.evaluate(()=>window.InheritWorldAliveUI.getSoundEnabled())).toBe(false);
 await expect(page.locator('.world-alive-setting').last()).toHaveAttribute('aria-pressed','false');
 await expect(page.locator('.world-alive-truth')).toContainText('художественные эффекты');
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(before);
 expect(errors).toEqual([]);
});


test('INHERIT R15 mobile action rail stays tappable without a viewport-fixed overlay',async({page},info)=>{
 if(info.project.name!=='mobile')test.skip();
 const errors=await prepareStandaloneGame(page);
 await page.goto('/games/inherit/?lang=ru',{waitUntil:'domcontentloaded'});
 const dock=page.locator('.dock.cine-dock');
 await expect(dock).toBeVisible();
 expect(await dock.evaluate(el=>getComputedStyle(el).position)).toBe('relative');
 const pass=page.locator('#pass');
 await expect(pass).toBeInViewport();
 const world=page.locator('#world');
 await expect(world).toBeInViewport();
 // An action below the island must accept a genuine pointer click, even
 // after the browser scrolls the element into view.
 const enter=page.locator('#inherit-enter');
 await enter.click({timeout:10000});
 await expect(world).toBeFocused();
 await world.press('Enter');
 await expect(page.locator('#objects>.placed')).toHaveCount(1);
 const inspector=page.locator('.inherit-trace-launcher');
 await expect(inspector).toBeEnabled();
 await inspector.click({timeout:10000});
 await expect(page.locator('.inherit-trace-inspector')).toBeVisible();
 expect(errors).toEqual([]);
});
