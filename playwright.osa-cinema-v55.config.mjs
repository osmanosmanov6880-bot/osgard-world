import { defineConfig } from '@playwright/test'
import ecosystemConfig from './playwright.ecosystem.config.mjs'

// A dedicated isolated test allowlist ensures V55 is tested in a real browser.
export default defineConfig({
 ...ecosystemConfig,
 testMatch: ['osa-cinema-v55-studio.spec.mjs'],
 fullyParallel: false,
 workers: 1,
 retries: 0,
 timeout: 45000,
})
