import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: './scripts',
  testMatch: 'omega-production.spec.mjs',
  timeout: 45000,
  expect: { timeout: 12000 },
  retries: 1,
  workers: 2,
  reporter: [['list'], ['html', { outputFolder: 'omega-acceptance-report', open: 'never' }]],
  outputDir: 'omega-acceptance-results',
  use: {
    baseURL: 'https://osgard.world',
    locale: 'ru-RU',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'desktop', use: { browserName: 'chromium', viewport: { width: 1440, height: 900 } } },
    { name: 'mobile', use: { browserName: 'chromium', viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true } },
  ],
})
