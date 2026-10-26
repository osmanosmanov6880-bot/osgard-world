import {defineConfig} from '@playwright/test'
import original from './playwright.omega-r90.config.mjs'

// Preserve the audited real Godot exported-web launcher + Mesa/SwiftShader
// flags. R109 MUST cover both actual widescreen Tab governance and touch-capable
// 390x844 portrait gameplay, never substitute a static screenshot.
export default defineConfig({
  ...original,
  testMatch:['omega-r90-live-cabinet.spec.mjs','omega-r109-phone-webgl.spec.mjs','omega-r109-frame-telemetry.spec.mjs','omega-r117-city-focus-webgl.spec.mjs']
})
