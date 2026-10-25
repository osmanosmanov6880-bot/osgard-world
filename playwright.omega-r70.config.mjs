import {defineConfig} from '@playwright/test'

const mesaDesktop=process.env.OMEGA_CI_GL_BACKEND==='mesa'
export default defineConfig({
  testDir:'./scripts',testMatch:'omega-r70-binary-driving.spec.mjs',
  timeout:210000,expect:{timeout:20000},
  retries:0,workers:1,
  reporter:[['list'],['html',{outputFolder:'omega-r70-browser-report',open:'never'}]],
  outputDir:'omega-r70-browser-results',
  use:{
    baseURL:'http://127.0.0.1:4173',
    locale:'ru-RU',actionTimeout:25000,navigationTimeout:40000,
    launchOptions:{
      args:mesaDesktop?
        ['--enable-webgl','--ignore-gpu-blocklist','--use-gl=angle','--use-angle=gl']:
        ['--enable-webgl','--ignore-gpu-blocklist','--use-angle=swiftshader','--enable-unsafe-swiftshader']
    },
    trace:'retain-on-failure',screenshot:'only-on-failure'
  },
  projects:[
    {name:'desktop-chromium',use:{browserName:'chromium',viewport:{width:1366,height:768},deviceScaleFactor:1}},
    {name:'touch-phone-chromium',use:{browserName:'chromium',viewport:{width:390,height:844},isMobile:true,hasTouch:true,deviceScaleFactor:1}}
  ]
})
