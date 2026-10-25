import { defineConfig } from '@playwright/test'

// R74 acceptance: try the authentic software OpenGL/Mesa compositor under
// Xvfb when Chromium SwiftShader stalls on Godot's original 1366x768 world.
// Both paths are real WebGL renderers; neither is physical Android/iPhone QA.
const mesaWebGL = process.env.OMEGA_CI_GL_BACKEND === 'mesa'

export default defineConfig({
  testDir: './scripts',
  testMatch: 'omega-live-webgl.spec.mjs',
  fullyParallel: false,
  timeout: 180_000,
  expect: { timeout: 18_000 },
  // A fresh Chromium process is allowed one bounded retry for transient
  // Linux SwiftShader screenshot stalls. Both attempts still require
  // byte-exact public source SHA and authentic car/touch motion evidence.
  retries: 1,
  workers: 1,
  reporter: [['list'], ['html', { outputFolder: 'omega-live-webgl-report', open: 'never' }]],
  outputDir: 'omega-live-webgl-results',
  use: {
    baseURL: process.env.OSGARD_GAME_ORIGIN || 'https://osgard.world',
    locale: 'ru-RU',
    actionTimeout: 25_000,
    navigationTimeout: 45_000,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    launchOptions: {
      args: mesaWebGL ?
        ['--enable-webgl', '--ignore-gpu-blocklist', '--use-gl=angle', '--use-angle=gl'] :
        ['--enable-webgl', '--ignore-gpu-blocklist', '--use-angle=swiftshader', '--enable-unsafe-swiftshader']
    }
  },
  projects: [
    { name: 'desktop-chromium', use: { browserName: 'chromium', viewport: { width: 1366, height: 768 }, deviceScaleFactor: 1 } },
    { name: 'touch-phone-chromium', use: { browserName: 'chromium', viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, deviceScaleFactor: 1 } }
  ]
})
