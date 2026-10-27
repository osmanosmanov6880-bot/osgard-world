import { defineConfig } from '@playwright/test'

// R134 only: genuine Godot R87 (seven independently SHA-matched bytes)
// restored under local temporary runner directory. Desktop uses previously
// verified Mesa/Xvfb, not a synthetic image or Chromium host rAF shortcut.
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
  reporter:[['list'],['html',{outputFolder:'omega-r134-browser-report',open:'never'}]],
  outputDir:'omega-r134-browser-results',
  use:{
    baseURL:'http://127.0.0.1:4887',
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
