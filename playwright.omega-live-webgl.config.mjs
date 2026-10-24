import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: './scripts',
  testMatch: 'omega-live-webgl.spec.mjs',
  fullyParallel: false,
  timeout: 180_000,
  expect: { timeout: 18_000 },
  retries: 0,
  workers: 1,
  reporter: [['list'], ['html', { outputFolder: 'omega-live-webgl-report', open: 'never' }]],
  outputDir: 'omega-live-webgl-results',
  use: {
    baseURL: process.env.OSGARD_GAME_ORIGIN || 'https://osgard.world',
    locale: 'ru-RU',
    actionTimeout: 25_000,
    navigationTimeout: 45_000,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    launchOptions: {
      args: ['--enable-webgl', '--ignore-gpu-blocklist', '--use-angle=swiftshader', '--enable-unsafe-swiftshader']
    }
  },
  projects: [
    { name: 'desktop-chromium', use: { browserName: 'chromium', viewport: { width: 1366, height: 768 }, deviceScaleFactor: 1 } },
    { name: 'touch-phone-chromium', use: { browserName: 'chromium', viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, deviceScaleFactor: 1 } }
  ]
})
