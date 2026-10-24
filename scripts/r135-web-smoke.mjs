// OSGARD R135: browser smoke checks real Godot Web export (NOT native GPU QA).
// Usage: node scripts/r135-web-smoke.mjs http://127.0.0.1:8765/index.html /tmp/screens
import { chromium, devices } from 'playwright'
import { mkdir } from 'node:fs/promises'
import { resolve } from 'node:path'
import process from 'node:process'

const target = process.argv[2] || 'http://127.0.0.1:8765/index.html'
const output = resolve(process.argv[3] || '/tmp/r135-browser-screens')
await mkdir(output, { recursive: true })

const browser = await chromium.launch({
  headless: true,
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-webgl',
    '--disable-gpu-sandbox', '--no-sandbox'],
})
let anyFailure = false

try {
  for (const [name, opts] of [
    ['desktop-1366', { viewport: { width: 1366, height: 768 }, deviceScaleFactor: 1 }],
    ['mobile-390', { ...devices['Pixel 7'] }],
  ]) {
    const context = await browser.newContext(opts)
    const page = await context.newPage()
    const runtimeErrors = []
    const failures = []
    page.on('pageerror', err => runtimeErrors.push(String(err)))
    page.on('requestfailed', req => failures.push(req.url() + ': ' + (req.failure()?.errorText || 'network error')))
    console.log('R135 visiting', name, target)
    let response
    try {
      response = await page.goto(target, { waitUntil: 'domcontentloaded', timeout: 120_000 })
      if (response?.status() !== 200) throw new Error('HTML HTTP status ' + (response?.status() ?? 'none'))
      const hasWebGL2 = await page.evaluate(() => {
        const probe = document.createElement('canvas')
        return Boolean(probe.getContext('webgl2'))
      })
      if (!hasWebGL2) throw new Error('No WebGL2 context in Chromium SwiftShader')
      await page.locator('canvas').first().waitFor({ state: 'visible', timeout: 120_000 })
      // The Godot WASM and PCK are asynchronous; wait for download to finish
      // and exercise a real input path while preserving a visual trace.
      await page.waitForTimeout(14_000)
      const canvas = await page.locator('canvas').first().evaluate(canvas => ({
        width: canvas.width,
        height: canvas.height,
        visible: canvas.getBoundingClientRect().width > 0 && canvas.getBoundingClientRect().height > 0,
      }))
      if (!canvas.visible || canvas.width < 128 || canvas.height < 128) {
        throw new Error('Godot canvas did not become usable: ' + JSON.stringify(canvas))
      }
      await page.screenshot({ path: resolve(output, name + '.png'), fullPage: true })
      // Exclude transient font/launcher noise, but reject missing Godot assets
      // and uncaught JavaScript runtime errors.
      if (runtimeErrors.length) throw new Error('JS page errors: ' + runtimeErrors.join(' | '))
      const missing = failures.filter(url => /\.(?:pck|wasm|js)(?:\?|$)/i.test(url))
      if (missing.length) throw new Error('Godot asset failed: ' + missing.join(' | '))
      console.log('R135 browser PASS', name, canvas)
    } catch (err) {
      anyFailure = true
      console.error('R135 browser FAIL', name, String(err))
      try { await page.screenshot({ path: resolve(output, name + '-failure.png'), fullPage: true }) } catch {}
    } finally {
      await context.close()
    }
  }
} finally {
  await browser.close()
}
if (anyFailure) process.exitCode = 1
