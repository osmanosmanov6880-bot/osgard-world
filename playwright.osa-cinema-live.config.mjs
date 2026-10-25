import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: './scripts',
  testMatch: ['osa-cinema-v13-production.spec.mjs'],
  fullyParallel: false,
  workers: 1,
  retries: 1,
  timeout: 35000,
  expect: { timeout: 15000 },
  reporter: [['list'], ['html', { outputFolder: 'osa-cinema-live-report', open: 'never' }]],
  use: {
    baseURL: process.env.OSGARD_BASE_URL || 'https://osgard.world',
    channel: process.env.OSGARD_BROWSER_CHANNEL === 'chrome' ? 'chrome' : 'chromium',
    locale: 'ru-RU',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    contextOptions: { reducedMotion: 'reduce' }
  },
  projects: [
    { name: 'desktop', use: { browserName: 'chromium', viewport: { width: 1440, height: 900 } } },
    { name: 'mobile', use: { browserName: 'chromium', viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true } }
  ]
})
