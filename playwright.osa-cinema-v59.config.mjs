import { defineConfig } from '@playwright/test'
import base from './playwright.osa-cinema-v58.config.mjs'

export default defineConfig({
  ...base,
  testMatch:['osa-cinema-v59-production.spec.mjs'],
  fullyParallel:false,
  workers:1,
  retries:0,
  timeout:55000,
})
