import { defineConfig } from '@playwright/test'
import previous from './playwright.osa-cinema-v62.config.mjs'
export default defineConfig({
 ...previous,testMatch:['osa-cinema-v63-vault.spec.mjs'],
 fullyParallel:false,workers:1,retries:0,timeout:95000,
 use:{...previous.use,baseURL:'http://127.0.0.1:4180'},
 webServer:{
  command:'python3 server/core_server.py --root dist --database /tmp/osa-cinema-v63-vault-browser.sqlite3 --port 4180',
  url:'http://127.0.0.1:4180/api/core/health',
  reuseExistingServer:false,timeout:45000
 }
})
