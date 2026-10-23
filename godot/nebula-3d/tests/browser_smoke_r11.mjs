/* NEBULA R11 browser rendering smoke, hosted SwiftShader—not a physical GPU benchmark. */
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';

const output = path.resolve('r11-browser-qa');
fs.mkdirSync(output, { recursive: true });
const browser = await chromium.launch({
  headless: true,
  args: [
    '--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader',
    '--enable-webgl', '--enable-unsafe-swiftshader',
    '--disable-features=Vulkan'
  ]
});
const pages = [];
const result = {
  schema: 'NEBULA_R11_HOSTED_BROWSER_QA',
  disclaimer: 'Hosted Chromium with software SwiftShader; not a real GPU FPS measurement',
  started_at: new Date().toISOString(),
  scenes: [],
  errors: [],
  device_benchmark: null
};
try {
  for (const vp of [{ width: 1280, height: 720 }, { width: 1920, height: 1080 }]) {
    const page = await browser.newPage({ viewport: vp, deviceScaleFactor: 1 });
    pages.push(page);
    const errors = [];
    const logs = [];
    page.on('pageerror', e => errors.push(String(e.message).slice(0, 400)));
    page.on('console', m => {
      const text = m.text();
      if (m.type() === 'error') errors.push(text.slice(0, 400));
      if (text.includes('NEBULA_R11_BENCHMARK_JSON:')) logs.push(text);
    });
    const url = 'http://127.0.0.1:8765/games/remix/arena-v2/nebula-3d/?r11-qa=1';
    const started = Date.now();
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 45000 });
    await page.locator('canvas').first().waitFor({ state: 'visible', timeout: 65000 });
    await page.waitForTimeout(10000); // GL init, WebAssembly load, first scene draw
    const detail = await page.evaluate(() => {
      const canvas = document.querySelector('canvas');
      const probe = document.createElement('canvas');
      return {
        canvas_width: canvas?.width ?? 0,
        canvas_height: canvas?.height ?? 0,
        webgl_available: !!(probe.getContext('webgl2') || probe.getContext('webgl')),
        device_pixel_ratio: window.devicePixelRatio
      };
    });
    const tag = vp.width + 'x' + vp.height;
    await page.screenshot({ path: path.join(output, 'r11-' + tag + '-max.png') });
    if (!detail.webgl_available || detail.canvas_width < 300 || detail.canvas_height < 200) {
      throw new Error('Browser failed to initialize a usable WebGL canvas at ' + tag);
    }
    await page.locator('canvas').first().click({ position: { x: 100, y: 100 } });
    await page.keyboard.press('F3');
    await page.waitForTimeout(1500);
    await page.screenshot({ path: path.join(output, 'r11-' + tag + '-high.png') });
    await page.keyboard.press('F3');
    await page.waitForTimeout(1500);
    await page.screenshot({ path: path.join(output, 'r11-' + tag + '-eco.png') });
    if (vp.width === 1280) {
      await page.keyboard.press('F3');
      await page.keyboard.press('F7');
      await page.waitForTimeout(24000); // 2 sec warmup + 20 seconds capture + margin
      const jsonLine = logs.find(x => x.includes('NEBULA_R11_BENCHMARK_JSON:'));
      if (jsonLine) {
        try {
          result.device_benchmark = JSON.parse(jsonLine.slice(
            jsonLine.indexOf('NEBULA_R11_BENCHMARK_JSON:') +
            'NEBULA_R11_BENCHMARK_JSON:'.length));
        } catch (e) { errors.push('Bench JSON parsing: ' + String(e)); }
      }
      await page.screenshot({ path: path.join(output, 'r11-' + tag + '-profiler.png') });
    }
    result.scenes.push({
      viewport: tag, init_ms: Date.now() - started,
      ...detail,
      browser_console_errors: errors,
      benchmark_event_reported: logs.length > 0
    });
    result.errors.push(...errors);
  }
} catch (e) {
  result.errors.push('FATAL: ' + String(e));
  throw e;
} finally {
  result.finished_at = new Date().toISOString();
  fs.writeFileSync(path.join(output, 'report.json'), JSON.stringify(result, null, 2));
  await browser.close();
}
console.log('NEBULA_R11_BROWSER_QA: ' + JSON.stringify({
  scenes: result.scenes.map(x => x.viewport),
  errors: result.errors.length,
  benchmark_captured: !!result.device_benchmark,
  disclaimer: result.disclaimer
}));
