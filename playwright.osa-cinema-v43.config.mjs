import {defineConfig} from '@playwright/test'
import ecosystemConfig from './playwright.ecosystem.config.mjs'

// The ecosystem config intentionally has a static testMatch allowlist.
// Keep V43 isolated so that mobile acceptance actually runs in CI.
export default defineConfig({
  ...ecosystemConfig,
  testMatch: ['osa-cinema-v43-mobile-navigation.spec.mjs'],
  workers: 1,
})
