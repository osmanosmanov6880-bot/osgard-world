import { defineConfig } from '@playwright/test'
import previous from './playwright.osa-cinema-v61.config.mjs'
export default defineConfig({
 ...previous,testMatch:['osa-cinema-v62-evidence.spec.mjs'],
 fullyParallel:false,workers:1,retries:0,timeout:85000,
 use:{...previous.use,baseURL:'http://127.0.0.1:4179'},
 webServer:{
  command:'python3 server/core_server.py --root dist --database /tmp/osa-cinema-v62-evidence-test.sqlite3 --port 4179',
  url:'http://127.0.0.1:4179/api/core/health',
  reuseExistingServer:false,timeout:45000
 }
})
