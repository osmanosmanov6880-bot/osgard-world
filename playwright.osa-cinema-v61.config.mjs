import { defineConfig } from '@playwright/test'
import previous from './playwright.osa-cinema-v60.config.mjs'
export default defineConfig({
 ...previous,
 testMatch:['osa-cinema-v61-core.spec.mjs'],
 fullyParallel:false,
 workers:1,retries:0,timeout:85000,
 use:{...previous.use,baseURL:'http://127.0.0.1:4178'},
 webServer:{
  command:'python3 server/core_server.py --root dist --database /tmp/osa-cinema-v61-test.sqlite3 --port 4178',
  url:'http://127.0.0.1:4178/api/core/health',
  reuseExistingServer:false,timeout:45000
 }
})
