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
