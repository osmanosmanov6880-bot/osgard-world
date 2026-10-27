import { defineConfig } from '@playwright/test'

// R137: seven ORIGINAL live public HTTPS R87 bytes, SHA-locked, installed
// temporarily over actual Godot candidate then restored and served from a
// TRUE localhost nginx HTTPS endpoint, with a SELF-SIGNED EPHEMERAL cert.
// This cert is valid only for the private 127.0.0.1 test runner and ignored
// solely by this Playwright test. No public production authority is granted.
const mesa = process.env.OMEGA_CI_GL_BACKEND === 'mesa'
const flags = mesa
  ? ['--enable-webgl','--ignore-gpu-blocklist','--use-gl=angle','--use-angle=gl']
  : ['--enable-webgl','--ignore-gpu-blocklist','--use-angle=swiftshader','--enable-unsafe-swiftshader']

export default defineConfig({
  testDir:'./scripts',
  testMatch:'omega-r134-rollback-browser.spec.mjs',
  timeout:190000,
  expect:{timeout:20000},
  workers:1,
  retries:0,
  reporter:[['list'],['html',{outputFolder:'omega-r137-browser-report',open:'never'}]],
  outputDir:'omega-r137-browser-results',
  use:{
    baseURL:'https://127.0.0.1:4887',
    ignoreHTTPSErrors:true,
    locale:'ru-RU',
    navigationTimeout:30000,
    actionTimeout:22000,
    launchOptions:{args:flags},
    trace:'retain-on-failure',
    screenshot:'only-on-failure'
  },
  projects:[
    {name:'r87-portrait-390x844',use:{browserName:'chromium',
      viewport:{width:390,height:844},isMobile:true,hasTouch:true,deviceScaleFactor:1}},
    {name:'r87-desktop-1366x768',use:{browserName:'chromium',
      viewport:{width:1366,height:768},deviceScaleFactor:1}},
  ]
})
