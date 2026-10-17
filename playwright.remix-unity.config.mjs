import { defineConfig } from '@playwright/test'

// Run through scripts/check-nginx-unity-browser.sh in CI. Vite's preview
// server does not serve the production export's .gz-only runtime contract.
if (!process.env.OSGARD_UNITY_BASE_URL) throw new Error('OSGARD_UNITY_BASE_URL must point to candidate Nginx')

export default defineConfig({
  testDir: './scripts',
  testMatch: 'remix-unity-browser.spec.mjs',
  outputDir: 'unity-test-results',
  fullyParallel: false,
  workers: 1,
  retries: 0,
  timeout: 180000,
  globalTimeout: 600000,
  expect: { timeout: 15000 },
  reporter: [['list'], ['html', { outputFolder: 'unity-browser-report', open: 'never' }]],
  use: {
    baseURL: process.env.OSGARD_UNITY_BASE_URL,
    browserName: 'chromium',
    viewport: { width: 1280, height: 1000 },
    locale: 'ru-RU',
    reducedMotion: 'reduce',
    actionTimeout: 15000,
    navigationTimeout: 30000,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    launchOptions: {
      // Software rendering is confined to the disposable CI browser. Do not
      // recommend these flags to visitors or treat its speed as a device KPI.
      args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
    },
  },
})
