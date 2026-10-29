import { defineConfig } from '@playwright/test'
import previous from './playwright.osa-cinema-v63.config.mjs'
export default defineConfig({
 ...previous,testMatch:['osa-cinema-v64-integrity.spec.mjs'],
 fullyParallel:false,workers:1,retries:0,timeout:90000,
 use:{...previous.use,baseURL:'http://127.0.0.1:4181'},
 webServer:{
  command:'python3 server/core_server.py --root dist --database /tmp/osa-cinema-v64-integrity-browser.sqlite3 --port 4181',
  url:'http://127.0.0.1:4181/api/core/health',
  reuseExistingServer:false,timeout:45000
 }
})
