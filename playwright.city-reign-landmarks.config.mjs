import {defineConfig} from '@playwright/test'
export default defineConfig({
  testDir:'./scripts',
  testMatch:'city-reign-aaa-real-landmarks.spec.mjs',
  workers:1,retries:0,timeout:240000,
  reporter:[['list'],['html',{outputFolder:'city-reign-hero-visual-report',open:'never'}]],
  outputDir:'city-reign-hero-visual-results',
  use:{
    baseURL:'http://127.0.0.1:4176',locale:'en-US',
    actionTimeout:25000,navigationTimeout:45000,
    trace:'retain-on-failure',screenshot:'only-on-failure',
    browserName:'chromium',viewport:{width:1366,height:768},
    deviceScaleFactor:1,
    launchOptions:{args:['--enable-webgl','--ignore-gpu-blocklist','--use-gl=angle','--use-angle=gl']}
  }
})
