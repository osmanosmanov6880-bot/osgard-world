import {defineConfig} from '@playwright/test'
export default defineConfig({
  testDir:'./scripts',
  testMatch:'city-reign-camera-release.spec.mjs',
  timeout:220000,retries:0,workers:1,
  reporter:[['list'],['html',{outputFolder:'city-reign-camera-report',open:'never'}]],
  outputDir:'city-reign-camera-results',
  use:{
    baseURL:'http://127.0.0.1:4173',
    browserName:'chromium',locale:'en-US',
    trace:'retain-on-failure',screenshot:'only-on-failure',
    actionTimeout:25000,navigationTimeout:55000,
    viewport:{width:1366,height:768},deviceScaleFactor:1,
    launchOptions:{args:['--enable-webgl','--ignore-gpu-blocklist',
      '--use-gl=angle','--use-angle=gl']}
  }
})
