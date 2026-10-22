import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: './scripts',
  testMatch: ['academy-cockpit-browser.spec.mjs', 'unified-navigation-browser.spec.mjs', 'ecosystem-browser.spec.mjs', 'ecosystem-mobile-lab.spec.mjs', 'program-enrollment-browser.spec.mjs', 'remix-console-browser.spec.mjs', 'remix-owned-browser.spec.mjs', 'remix-invitations-browser.spec.mjs', 'inherit-account-browser.spec.mjs'],
  fullyParallel: true,
  workers: 2,
  retries: 1,
  timeout: 30000,
  expect: { timeout: 10000 },
  reporter: [['list'], ['html', { outputFolder: 'browser-report', open: 'never' }]],
  use: {
    baseURL: 'http://127.0.0.1:4175',
    channel: 'chromium', // Use the installed full browser in new headless mode.
    locale: 'ru-RU',
    contextOptions: { reducedMotion: 'reduce' },
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'desktop', use: { browserName: 'chromium', viewport: { width: 1440, height: 900 } } },
    { name: 'mobile', use: { browserName: 'chromium', viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true } },
  ],
  webServer: {
    command: 'npm run preview -- --port 4175 --strictPort',
    url: 'http://127.0.0.1:4175',
    reuseExistingServer: false,
    timeout: 30000,
  },
})
