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
// Playwright's compositor screenshots may stall under software WebGL, even
// when the Godot canvas exists. Fall back to direct canvas readback, but only
// count a substantial PNG as a visual capture. Never mark a blank as a pass.
async function captureWithFallback(page, destination, errors) {
  try {
    await page.screenshot({ path: destination, timeout: 18000, animations: 'disabled' });
    if (fs.statSync(destination).size >= 12000) return 'compositor';
    errors.push('Compositor screenshot was too small to confirm a rendered frame');
  } catch (e) {
    errors.push('Compositor screenshot unavailable: ' + String(e.message).slice(0, 180));
  }
  // Chrome DevTools can capture the software compositor without forcing a
  // Playwright DOM screenshot, which is known to stall under SwiftShader.
  try {
    const cdp = await page.context().newCDPSession(page);
    try {
      const response = await Promise.race([
        cdp.send('Page.captureScreenshot', {
          format: 'png', captureBeyondViewport: false, fromSurface: false
        }),
        new Promise(resolve => setTimeout(() => resolve(null), 12000))
      ]);
      if (response?.data) {
        const raw = Buffer.from(response.data, 'base64');
        if (raw.length >= 12000) {
          fs.writeFileSync(destination, raw);
          return 'cdp-compositor';
        }
        errors.push('Chrome DevTools screenshot too small (' + raw.length + ' bytes)');
      } else {
        errors.push('Chrome DevTools screenshot timed out (software compositor)');
      }
    } finally {
      await cdp.detach().catch(() => {});
    }
  } catch (e) {
    errors.push('Chrome DevTools capture unavailable: ' + String(e.message).slice(0, 180));
  }
  try {
    const image = await Promise.race([
      page.evaluate(() => {
        const canvas = document.querySelector('canvas');
        return canvas ? canvas.toDataURL('image/png') : '';
      }),
      new Promise(resolve => setTimeout(() => resolve(''), 14000))
    ]);
    if (image.startsWith('data:image/png;base64,')) {
      const raw = Buffer.from(image.slice('data:image/png;base64,'.length), 'base64');
      if (raw.length >= 12000) {
        fs.writeFileSync(destination, raw);
        return 'canvas-readback';
      }
      errors.push('Canvas readback was black/empty or too small (' + raw.length + ' bytes)');
    }
  } catch (e) {
    errors.push('Canvas readback unavailable: ' + String(e.message).slice(0, 180));
  }
  return 'inconclusive';
}

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
    page.on('pageerror', e => errors.push('JS exception: ' + String(e.message).slice(0, 400)));
    page.on('requestfailed', req =>
      errors.push('Request failure: ' + req.url().slice(0, 220) +
        ' (' + (req.failure()?.errorText || 'unknown') + ')'));
    page.on('response', response => {
      if (response.status() >= 400) {
        errors.push('HTTP ' + response.status() + ': ' + response.url().slice(0, 200));
      }
    });
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
        device_pixel_ratio: window.devicePixelRatio,
        document_state: document.readyState,
        gpu_reported: (() => {
          const gl = probe.getContext('webgl2') || probe.getContext('webgl');
          const ext = gl?.getExtension('WEBGL_debug_renderer_info');
          return ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : 'masked-or-missing';
        })(),
        page_title: document.title,
        visible_canvas: !!canvas && canvas.getBoundingClientRect().width > 100,
      };
    });
    const tag = vp.width + 'x' + vp.height;
    if (!detail.webgl_available || detail.canvas_width < 300 || detail.canvas_height < 200) {
      throw new Error('Browser failed to initialize a usable WebGL canvas at ' + tag);
    }
    const screenshots = {};
    screenshots.maximum = await captureWithFallback(
      page, path.join(output, 'r11-' + tag + '-max.png'), errors);
    if (screenshots.maximum === 'inconclusive') {
      result.scenes.push({ viewport: tag, ...detail,
        screenshot_status: screenshots, browser_console_errors: errors });
      result.errors.push(...errors);
      // Do not assert visual correctness or waste time testing 1080p when
      // the hosted software renderer couldn't produce a single 720p frame.
      throw new Error('Hosted SwiftShader cannot confirm visual frame at ' + tag);
    }
    await page.locator('canvas').first().click({ position: { x: 100, y: 100 } });
    await page.keyboard.press('F3');
    await page.waitForTimeout(1500);
    screenshots.high = await captureWithFallback(
      page, path.join(output, 'r11-' + tag + '-high.png'), errors);
    await page.keyboard.press('F3');
    await page.waitForTimeout(1500);
    screenshots.eco = await captureWithFallback(
      page, path.join(output, 'r11-' + tag + '-eco.png'), errors);
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
      screenshots.profiler = await captureWithFallback(page,
        path.join(output, 'r11-' + tag + '-profiler.png'), errors);
    }
    result.scenes.push({
      viewport: tag, init_ms: Date.now() - started,
      ...detail,
      browser_console_errors: errors,
      benchmark_event_reported: logs.length > 0,
      screenshot_status: screenshots,
      visual_capture_confirmed: Object.values(screenshots).every(x => x !== 'inconclusive')
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
