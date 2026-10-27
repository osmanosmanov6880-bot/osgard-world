import { defineConfig } from '@playwright/test'

/** This config tests actual osgard.world media, never a mock or the eight still scenes. */
export default defineConfig({
  testDir: './scripts',
  testMatch: ['osa-cinema-v49-live.spec.mjs'],
  timeout: 35_000,
  expect: { timeout: 15_000 },
  retries: 0,
  workers: 1,
  use: {
    browserName: 'chromium',
    baseURL: 'https://osgard.world',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
})
