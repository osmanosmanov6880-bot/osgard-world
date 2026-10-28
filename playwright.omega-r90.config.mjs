import {defineConfig} from '@playwright/test'
const mesa=process.env.OMEGA_CI_GL_BACKEND==='mesa'
const args=mesa
  ? ['--enable-webgl','--ignore-gpu-blocklist','--use-gl=angle','--use-angle=gl']
  : ['--enable-webgl','--ignore-gpu-blocklist','--use-angle=swiftshader','--enable-unsafe-swiftshader']
export default defineConfig({
  testDir:'./scripts',
  testMatch:'omega-r90-live-cabinet.spec.mjs',
  timeout:210000,
  retries:0,
  workers:1,
  reporter:[['list'],['html',{outputFolder:'omega-r90-report',open:'never'}]],
  outputDir:'omega-r90-results',
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
    launchOptions:{args}
  }
})
