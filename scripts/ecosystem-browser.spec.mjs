import { test, expect } from '@playwright/test'

const surfaces = [
  ['/', 'world', 'Цифровые продукты,'],
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
    }
    for (const [language, label] of [['en', en], ['ru', ru]]) {
      await page.locator('[data-game-language="' + language + '"]').click()
      await expect(page.locator('html')).toHaveAttribute('lang', language)
      await expect(page.locator(action)).toContainText(label)
      await expect(page.locator('[data-game-language="' + language + '"]')).toHaveAttribute('aria-pressed', 'true')
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true)
    }
    expect(await page.evaluate(() => localStorage.getItem('osgard:game-language'))).toBe('ru')
    await page.screenshot({ path: info.outputPath(game + '-interface.png'), fullPage: true })
    expect(errors).toEqual([])
  })
}

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
