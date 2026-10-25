import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: './scripts',
  testMatch: 'omega-portrait-preview.spec.mjs',
  timeout: 210_000,
  expect: { timeout: 18_000 },
  retries: 1,
  workers: 1,
  reporter: [['list'], ['html', { outputFolder: 'omega-portrait-preview-report', open: 'never' }]],
  outputDir: 'omega-portrait-preview-results',
  use: {
    baseURL: 'http://127.0.0.1:4173',
    locale: 'ru-RU',
    actionTimeout: 22_000,
    navigationTimeout: 30_000,
    launchOptions: {
      args: ['--enable-webgl', '--ignore-gpu-blocklist', '--use-angle=swiftshader', '--enable-unsafe-swiftshader']
    },
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure'
  },
  projects: [
    { name: 'portrait-390x844', use: { browserName:'chromium', viewport: {width:390,height:844},isMobile:true,hasTouch:true,deviceScaleFactor:1 } },
    { name: 'small-phone-320x568', use: { browserName:'chromium',viewport:{width:320,height:568},isMobile:true,hasTouch:true,deviceScaleFactor:1 } },
    { name: 'landscape-phone-844x390', use:{browserName:'chromium',viewport:{width:844,height:390},isMobile:true,hasTouch:true,deviceScaleFactor:1 } },
    { name: 'desktop-1366x768', use:{browserName:'chromium',viewport:{width:1366,height:768},deviceScaleFactor:1 } }
  ]
})
