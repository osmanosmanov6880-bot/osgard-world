import { test, expect } from '@playwright/test'

const surfaces = [
  ['/', 'world', 'ТЕХНОЛОГИИ,'],
  ['/intelligence', 'intelligence', 'Понимать ИИ.'],
  ['/play', 'play', 'ДОБАВЬ ТЕНЬ.'],
]

for (const [path, product, heading] of surfaces) {
  test(product + ': real layout, navigation and reduced motion', async ({ page }, info) => {
    const failures = []
    page.on('pageerror', error => failures.push(error.message))
    await page.goto(path)
    await expect(page.locator('h1')).toHaveCount(1)
    await expect(page.locator('h1')).toContainText(heading)
    await expect(page.locator('html')).toHaveAttribute('data-product', product)
    await expect(page.getByRole('navigation', { name: 'Продукты OSGARD' }).getByRole('link')).toHaveCount(4)
    expect(await page.evaluate(() => matchMedia('(prefers-reduced-motion: reduce)').matches)).toBe(true)
    await expect(page.getByRole('button', { name: 'Меньше движения', exact: true })).toBeDisabled()
    await expect(page.locator('#product-main')).toBeVisible()
    await page.evaluate(() => document.fonts.ready)
    const interFonts = await page.evaluate(async () => (await document.fonts.load('400 16px Inter', 'OSGARD Интерфейс')).map(font => font.status))
    expect(interFonts.length).toBeGreaterThan(0)
    expect(interFonts.every(status => status === 'loaded')).toBe(true)
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
  await expect(page.locator('.omega-webgl-stage')).toHaveAttribute('data-globe-status', 'fallback', { timeout: 20000 })
  await expect(page.locator('.omega-globe')).toHaveCount(1)
  await page.getByRole('button', { name: 'Кино' }).click()
  await expect(page.locator('.omega-hero')).toHaveAttribute('data-omega-mode', 'cinema')
  await expect(page.getByRole('link', { name: /Исследовать экосистему/ })).toBeVisible()
})

test('OSGARD Earth GPU quality changes real texture detail with safe remount', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'no-preference' })
  await page.goto('/')
  const picker = page.getByRole('combobox', { name: 'Качество 3D-глобуса' })
  const stage = page.locator('.omega-webgl-stage')
  await expect(picker).toHaveValue('auto')
  await expect(stage).toHaveAttribute('data-earth-texture', 'adaptive')
  await picker.selectOption('ultra')
  await expect(stage).toHaveAttribute('data-globe-quality', 'ultra')
  await expect(stage).toHaveAttribute('data-earth-texture', '4096')
  await expect(stage).toHaveAttribute('data-globe-status', /^(webgl|fallback)$/, { timeout: 20000 })
  await picker.selectOption('eco')
  await expect(stage).toHaveAttribute('data-earth-texture', '512')
  await expect(page.locator('.omega-globe')).toHaveCount(1)
  await picker.selectOption('auto')
  await expect(stage).toHaveAttribute('data-globe-quality', 'auto')
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true)
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

test('OSGARD Omega cinematic scenes preserve working routes and images', async ({ page }) => {
  const pageErrors = []
  page.on('pageerror', error => pageErrors.push(error.message))
  await page.goto('/')
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
  await expect(page.locator('.omega-play-city img[src="/brand/omega-play.svg"]')).toBeVisible()
  await expect(page.locator('.omega-play-shortcuts a')).toHaveCount(3)
  await expect(page.locator('.omega-play-actions a[href^="/play/world/zion-030"]')).toHaveCount(1)
  expect(await page.locator('.omega-play-city img').evaluate(img => img.complete && img.naturalWidth > 0)).toBe(true)

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

test('catalog filters, return path and favorites survive reload', async ({ page }) => {
  await page.goto('/play')
  await expect(page.locator('.play-card')).toHaveCount(19)
  await page.getByRole('searchbox', { name: 'Поиск', exact: true }).fill('does-not-exist')
  await expect(page.locator('.play-card')).toHaveCount(0)
  await page.getByRole('button', { name: 'Показать все миры' }).click()
  await expect(page.getByRole('searchbox', { name: 'Поиск', exact: true })).toBeFocused()
  await expect(page.locator('.play-card')).toHaveCount(19)
  await page.getByRole('searchbox', { name: 'Поиск', exact: true }).fill('ZION-030')
  await expect(page.locator('.play-card')).toHaveCount(1)
  await page.locator('.play-card h3 a').click()
  await expect(page.locator('[data-game-launch="zion-030"]')).toHaveAttribute('href', '/games/zion-9/queue/ZION-030/index.html')
  await page.getByRole('button', { name: 'Добавить в избранное' }).click()
  await expect(page.getByRole('button', { name: 'Убрать из избранного' })).toHaveAttribute('aria-pressed', 'true')
  await page.reload()
  await expect(page.getByRole('button', { name: 'Убрать из избранного' })).toHaveAttribute('aria-pressed', 'true')
  await page.getByRole('link', { name: 'Каталог миров', exact: false }).click()
  await expect(page.getByRole('searchbox', { name: 'Поиск', exact: true })).toHaveValue('ZION-030')
  await expect(page.locator('.play-card')).toHaveCount(1)
  await page.getByLabel('Коллекция', { exact: false }).selectOption('favorites')
  await expect(page.locator('.play-card')).toHaveCount(1)
  await expect(page.getByRole('navigation', { name: 'Навигация раздела' }).getByRole('link', { name: 'Избранное', exact: true })).toHaveAttribute('aria-current', 'location')
  await page.locator('.play-card-actions button').click()
  await expect(page.locator('.play-card')).toHaveCount(0)
  await expect(page.getByRole('searchbox', { name: 'Поиск', exact: true })).toBeFocused()
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

test('ordinary Play entry keeps the featured world at the top', async ({ page }) => {
  await page.goto('/play')
  await expect(page.locator('.play-card')).toHaveCount(19)
  expect(new URL(page.url()).hash).toBe('')
  expect(await page.evaluate(() => scrollY)).toBe(0)
})

test('blocked optional storage keeps the game catalog usable', async ({ page }) => {
  await page.addInitScript(() => {
    Object.defineProperty(Storage.prototype, 'setItem', { value: () => { throw new DOMException('Storage blocked', 'SecurityError') } })
  })
  await page.goto('/play')
  await expect(page.locator('.play-card')).toHaveCount(19)
  await page.locator('.play-card-actions button').first().click()
  await expect(page.locator('#catalog [role="status"]')).toContainText('Не удалось сохранить коллекцию')
  await expect(page.locator('.play-card h3 a').first()).toBeEnabled()
})

test('motion choice persists independently from the system setting', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'no-preference' })
  await page.goto('/')
  await page.getByRole('button', { name: 'Меньше движения', exact: true }).click()
  await expect(page.locator('html')).toHaveAttribute('data-motion', 'off')
  await page.reload()
  await expect(page.locator('html')).toHaveAttribute('data-motion', 'off')
  await expect(page.getByRole('button', { name: 'Меньше движения', exact: true })).toHaveAttribute('aria-pressed', 'true')
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
      await expect(page.locator('#inherit-enter')).toBeInViewport()
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
 expect(await page.evaluate(()=>JSON.stringify(window.InheritGame.snapshot()))).toBe(before);
 const place=async choice=>{
  const p=await page.locator('#island').boundingBox();
  await page.mouse.click(p.x+p.width*choice.x/100,p.y+p.height*choice.y/100);
 };
 await place(starter.choices[0]);
 await expect.poll(()=>page.evaluate(()=>window.InheritGame.snapshot().objects.length)).toBe(1);
 await expect(page.locator('.inherit-compass-ghost')).toBeHidden();
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
