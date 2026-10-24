import { defineConfig } from '@playwright/test'
export default defineConfig({
  testDir:'./scripts',
  testMatch:'omega-r33-cabinet.spec.mjs',
  timeout:200000,
  expect:{timeout:18000},
  retries:0,
  workers:1,
  reporter:[['list'],['html',{outputFolder:'omega-r33-cabinet-report',open:'never'}]],
  outputDir:'omega-r33-cabinet-results',
  use:{
    baseURL:'http://127.0.0.1:4173',
    locale:'ru-RU',
    actionTimeout:25000,
    navigationTimeout:30000,
    trace:'retain-on-failure',
    screenshot:'only-on-failure',
    browserName:'chromium',
    viewport:{width:1366,height:768},
    deviceScaleFactor:1,
    launchOptions:{args:['--enable-webgl','--ignore-gpu-blocklist','--use-angle=swiftshader','--enable-unsafe-swiftshader']}
  }
})
