import { test, expect } from '@playwright/test'

for (const [path, surface] of [
  ['/', 'World'], ['/intelligence', 'Intelligence'], ['/academy', 'Academy'],
  ['/play', 'Play'], ['/development', 'Development'], ['/entertainment', 'Entertainment']
]) {
  test('Unified quick navigation opens accessibly in ' + surface + ' on desktop and mobile', async ({ page }) => {
    const errors = []
    page.on('pageerror', error => errors.push(error.message))
    await page.goto(path)
    const trigger = page.getByRole('button', { name: 'Быстрый переход по OSGARD' })
    await expect(trigger).toBeVisible()
    await expect(trigger).toHaveAttribute('aria-expanded', 'false')
    await trigger.click()
    // Opening the palette must never rewrite a Play alias to /play and silently
    // unmount the lazy dialog while keyboard users are interacting with it.
    if (path === '/entertainment') {
      await expect(page).toHaveURL(/\/entertainment\/?$/)
    }
    const dialog = page.getByRole('dialog', { name: 'Куда отправимся?' })
    await expect(dialog).toBeVisible()
    await expect(page.locator('.brand-system .osgard-command-trigger')).toHaveAttribute('aria-expanded', 'true')
    await expect(page.locator('#root')).toHaveAttribute('inert', '')
    const search = dialog.getByRole('searchbox', { name: 'Поиск по OSGARD' })
    await expect(search).toBeFocused()
    await expect(dialog.getByRole('navigation', { name: 'Результаты быстрого перехода' }).getByRole('link')).toHaveCount(9)
    await search.fill('теневой протокол')
    const result = dialog.getByRole('link', { name: /Теневой протокол/ })
    await expect(result).toHaveCount(1)
    await expect(result).toHaveAttribute('href', '/play/world/zion-030')
    await search.press('ArrowDown')
    await expect(result).toBeFocused()
    await search.focus()
    await search.fill('адрес которого нет')
    await expect(dialog.getByRole('status')).toContainText('Ничего не найдено')
    await search.press('Escape')
    await expect(dialog).toHaveCount(0)
    await expect(page.locator('#root')).not.toHaveAttribute('inert', '')
    await expect(trigger).toBeFocused()
    await expect(trigger).toHaveAttribute('aria-expanded', 'false')
    expect(await page.evaluate(() => document.body.style.overflow)).toBe('')
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true)
    expect(errors).toEqual([])
  })
}

test('Unified command shortcut, keyboard game navigation and browser history work', async ({ page }) => {
  await page.goto('/intelligence')
  await page.keyboard.press('Control+k')
  const dialog = page.getByRole('dialog', { name: 'Куда отправимся?' })
  await expect(dialog).toBeVisible()
  const search = dialog.getByRole('searchbox', { name: 'Поиск по OSGARD' })
  await search.fill('vector')
  await expect(dialog.getByRole('link', { name: /VECTOR\/\/ZERO/ })).toHaveAttribute('href', '/play/world/vector-zero')
  await search.press('Enter')
  await expect(page).toHaveURL(/\/play\/world\/vector-zero$/)
  await expect(page.locator('#product-main')).toBeVisible()
  await page.goBack()
  await expect(page).toHaveURL(/\/intelligence$/)
  await page.getByRole('button', { name: 'Быстрый переход по OSGARD' }).click()
  await dialog.getByRole('searchbox', { name: 'Поиск по OSGARD' }).fill('академия')
  await expect(dialog.getByRole('link', { name: /OSA Academy/ })).toHaveAttribute('href', '/academy')
  await dialog.getByRole('button', { name: 'Закрыть поиск' }).click()
  await expect(dialog).toHaveCount(0)
})
