import { test, expect } from '@playwright/test'

test('ZION-030 thermal rescue: three real districts, preview, and full win', async ({page}, testInfo) => {
  const errors = []
  page.on('pageerror', error => errors.push(error.message))
  await page.goto('/games/zion-9/queue/ZION-030/index.html?test=1')
  await page.waitForFunction(() => window.ZION030_GAME?.state().ready === true, null, { timeout: 15000 })
  await expect(page.locator('#world-play')).toHaveAttribute('data-premium-version', '26')
  const districts = page.locator('.premium-district')
  const control = page.locator(testInfo.project.name === 'mobile' ? '#premiumMobilePlace' : '#premiumPlace')
  await expect(districts).toHaveCount(3)
  await expect(control).toBeDisabled()
  await page.locator('#premiumShowHints').click()
  await expect(page.locator('#premiumShowHints')).toHaveAttribute('aria-pressed', 'true')
  await districts.nth(0).click()
  await expect(control).toBeEnabled()
  await expect(page.locator('#premiumSelectionText')).toContainText('Охладит зон: 1')
  await control.click()
  await expect.poll(() => page.evaluate(() => ZION030_GAME.state().score)).toBe(1)
  await expect(districts.nth(0)).toHaveClass(/is-cooled/)
  await expect(control).toBeDisabled()
  await page.locator('#premiumMap').click()
  await expect(page.locator('#premiumMap')).toHaveAttribute('aria-pressed', 'true')
  await districts.nth(1).click()
  await expect(control).toBeEnabled()
  await control.click()
  await expect.poll(() => page.evaluate(() => ZION030_GAME.state().score)).toBe(2)
  await districts.nth(2).click()
  await control.click()
  await expect.poll(() => page.evaluate(() => ZION030_GAME.state().won)).toBe(true)
  await expect(page.locator('#premiumProgress')).toHaveText('3 / 3')
  await expect(page.locator('.premium-district.is-cooled')).toHaveCount(3)
  await expect(page.locator('#premiumResultTitle')).toHaveText('ГОРОД ОХЛАЖДЁН!')
  await page.screenshot({ path: testInfo.outputPath('zion-v26-win.png'), fullPage: true })
  await page.locator('#premiumReplay').click()
  await expect.poll(() => page.evaluate(() => ZION030_GAME.state().score)).toBe(0)
  await expect(page.locator('.premium-district.is-cooled')).toHaveCount(0)
  await expect(control).toBeDisabled()
  expect(errors).toEqual([])
})

test('ZION-030: real overhead map and readable control on phone', async ({ page }, testInfo) => {
  await page.goto('/games/zion-9/queue/ZION-030/index.html?test=1')
  await page.waitForFunction(() => window.ZION030_GAME?.state().ready === true, null, { timeout: 15000 })
  if(testInfo.project.name === 'mobile'){
    const offsets = await page.evaluate(() => {
      const box = selector => document.querySelector(selector).getBoundingClientRect().top + window.scrollY
      return { city: box('.premium-mode .stage'), mission: box('.premium-mission') }
    })
    expect(offsets.city).toBeLessThan(offsets.mission)
    await expect(page.locator('#premiumMobilePlace')).toBeVisible()
    await expect(page.locator('#premiumMobilePlace')).toBeDisabled()
  }
  await page.locator('#premiumMap').click()
  await expect(page.locator('#premiumMap')).toHaveAttribute('aria-pressed', 'true')
  await page.locator('.premium-district').first().click()
  await expect(page.locator('#premiumPlace')).toBeEnabled()
  await page.locator('.premium-font-toggle').click()
  await expect(page.locator('#world-play')).toHaveClass(/premium-extra-readable/)
  await expect.poll(() => page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(2)
  await page.screenshot({ path: testInfo.outputPath('zion-v26-map-readable.png'), fullPage: true })
  if(testInfo.project.name === 'mobile'){
    await page.locator('#premiumMobilePlace').click()
    await expect(page.locator('#premiumMobileScore')).toHaveText('◎ 1 / 3 ЗОН')
  }
})
