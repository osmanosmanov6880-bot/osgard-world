import { defineConfig } from '@playwright/test'
import studio from './playwright.osa-cinema-v55.config.mjs'

export default defineConfig({
 ...studio,
 testMatch: ['osa-cinema-v58-library.spec.mjs'],
 fullyParallel: false,
 workers: 1,
 retries: 0,
 timeout: 50000,
})
