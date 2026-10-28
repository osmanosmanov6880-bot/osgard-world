import { defineConfig } from '@playwright/test'
import previous from './playwright.osa-cinema-v59.config.mjs'
export default defineConfig({
 ...previous,testMatch:['osa-cinema-v60-world.spec.mjs'],
 fullyParallel:false,workers:1,retries:0,timeout:70000
})
