import { defineConfig } from '@playwright/test'
import liveConfig from './playwright.osa-cinema-live.config.mjs'

// Never use the static ecosystem testMatch allowlist for live cinema evidence.
export default defineConfig({
  ...liveConfig,
  testMatch: ['osa-cinema-v44-production.spec.mjs', 'osa-cinema-v45-production.spec.mjs', 'osa-cinema-v46-history.spec.mjs'],
  retries: 1,
  workers: 1,
})
