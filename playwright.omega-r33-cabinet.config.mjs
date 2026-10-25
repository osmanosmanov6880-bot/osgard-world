import { defineConfig } from '@playwright/test'
// R79: Mesa/Xvfb real OpenGL on CI avoids SwiftShader compositor deadlocks.
// This is still actual Godot WebGL, not generated artwork or a fixture.
const mesaWebGL=process.env.OMEGA_CI_GL_BACKEND==='mesa'
const realWebGLArgs=mesaWebGL
  ? ['--enable-webgl','--ignore-gpu-blocklist','--use-gl=angle','--use-angle=gl']
  : ['--enable-webgl','--ignore-gpu-blocklist','--use-angle=swiftshader','--enable-unsafe-swiftshader']
export default defineConfig({
  testDir:'./scripts',
  testMatch:'omega-r33-cabinet.spec.mjs',
  timeout:200000,
  expect:{timeout:18000},
  retries: 1,
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
    launchOptions:{args:realWebGLArgs}
  }
})
