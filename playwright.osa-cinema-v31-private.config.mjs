import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir:'./scripts',
  testMatch:'osa-cinema-v31-owner-console.spec.mjs',
  fullyParallel:false,
  workers:1,
  retries:1,
  timeout:60000,
  expect:{timeout:12000},
  reporter:[['list'],['html',{outputFolder:'osa-v31-private-browser-report',open:'never'}]],
  use:{
    locale:'ru-RU',
    acceptDownloads:true,
    trace:'retain-on-failure',
    screenshot:'only-on-failure',
    contextOptions:{reducedMotion:'reduce'},
  },
  projects:[
    {name:'desktop',use:{browserName:'chromium',viewport:{width:1440,height:900}}},
    {name:'mobile',use:{browserName:'chromium',viewport:{width:390,height:844},isMobile:true,hasTouch:true}},
  ],
})
