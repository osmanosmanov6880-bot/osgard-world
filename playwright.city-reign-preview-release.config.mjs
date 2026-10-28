import {defineConfig} from '@playwright/test'
export default defineConfig({
  testDir:'./scripts',
  testMatch:'city-reign-preview-real-game.spec.mjs',
  workers:1,retries:0,timeout:285000,
  outputDir:'city-reign-preview-browser-results',
  reporter:[['list'],['html',{outputFolder:'city-reign-preview-browser-report',open:'never'}]],
  use:{
    baseURL:'http://127.0.0.1:4191',
    browserName:'chromium',
    locale:'en-US',
    actionTimeout:25000,
    navigationTimeout:60000,
    trace:'retain-on-failure',
    screenshot:'only-on-failure',
    viewport:{width:1366,height:768},
    deviceScaleFactor:1,
    launchOptions:{args:[
      '--enable-webgl','--ignore-gpu-blocklist','--use-gl=angle','--use-angle=gl'
    ]}
  }
})
