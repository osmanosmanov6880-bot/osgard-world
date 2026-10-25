import { defineConfig } from '@playwright/test'
export default defineConfig({
  testDir:'./scripts',
  testMatch:'osa-cinema-v23-ab-desk.spec.mjs',
  fullyParallel:false,workers:1,retries:1,timeout:60000,
  expect:{timeout:12000},
  reporter:[['list'],['html',{outputFolder:'osa-v23-browser-report',open:'never'}]],
  use:{browserName:'chromium',locale:'ru-RU',acceptDownloads:true,trace:'retain-on-failure',screenshot:'only-on-failure',contextOptions:{reducedMotion:'reduce'}},
  projects:[
    {name:'desktop',use:{viewport:{width:1440,height:900}}},
    {name:'mobile',use:{viewport:{width:390,height:844},isMobile:true,hasTouch:true}}
  ]
})
