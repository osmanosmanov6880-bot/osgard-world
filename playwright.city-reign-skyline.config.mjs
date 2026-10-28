import {defineConfig} from '@playwright/test'
export default defineConfig({
  testDir:'./scripts',
  testMatch:'city-reign-real-paid-skyline.spec.mjs',
  workers:1,retries:0,timeout:240000,
  reporter:[['list'],['html',{outputFolder:'city-reign-invested-skyline-report',open:'never'}]],
  outputDir:'city-reign-invested-skyline-results',
  use:{
    baseURL:'http://127.0.0.1:4177',locale:'en-US',
    actionTimeout:25000,navigationTimeout:50000,
    browserName:'chromium',viewport:{width:1366,height:768},deviceScaleFactor:1,
    trace:'retain-on-failure',screenshot:'only-on-failure',
    launchOptions:{args:['--enable-webgl','--ignore-gpu-blocklist','--use-gl=angle','--use-angle=gl']}
  }
})
