import {defineConfig} from '@playwright/test'
export default defineConfig({
  testDir:'./scripts',
  testMatch:'city-reign-public-works-webgl.spec.mjs',
  timeout:280000,retries:0,workers:1,
  reporter:[['list'],['html',{
    outputFolder:'city-reign-real-paid-public-works-report',open:'never'
  }]],
  outputDir:'city-reign-real-paid-public-works-results',
  use:{
    baseURL:'http://127.0.0.1:4188',
    browserName:'chromium',
    locale:'en-US',
    actionTimeout:25000,navigationTimeout:55000,
    trace:'retain-on-failure',screenshot:'only-on-failure',
    viewport:{width:1366,height:768},deviceScaleFactor:1,
    launchOptions:{args:[
      '--enable-webgl','--ignore-gpu-blocklist','--use-gl=angle','--use-angle=gl'
    ]}
  }
})
