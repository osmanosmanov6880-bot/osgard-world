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
// count a substantial JPEG as a visual capture. Never mark a blank as a pass.
async function captureWithFallback(page, destination, errors) {
  // Ask the live Godot viewport for the current frame. This avoids the
  // Chromium software compositor, which can stall while SwiftShader is busy.
  try {
    const requestId = await page.evaluate(() => {
      const next = Number(window.__nebulaR11CaptureRequestId || 0) + 1;
      window.__nebulaR11CaptureRequestId = next;
      return next;
    });
    await page.waitForFunction(
      id => Number(window.__nebulaR11CaptureCompletedId) === id,
      requestId, { timeout: 15000, polling: 100 });
    const engineImage = await page.evaluate(() => window.__nebulaR11CaptureData || '');
    if (engineImage.startsWith('data:image/jpeg;base64,')) {
      const raw = Buffer.from(engineImage.slice('data:image/jpeg;base64,'.length), 'base64');
      if (raw.length >= 12000) {
        fs.writeFileSync(destination, raw);
        return 'godot-viewport';
      }
      errors.push('Godot viewport JPEG too small (' + raw.length + ' bytes)');
    } else {
      const reason = await page.evaluate(() => window.__nebulaR11CaptureError || '');
      errors.push('Godot viewport did not return JPEG' + (reason ? ': ' + reason : ''));
    }
  } catch (e) {
    errors.push('Godot viewport capture unavailable: ' + String(e.message).slice(0, 180));
  }
  try {
    await page.screenshot({ path: destination, type: 'jpeg', quality: 70, timeout: 18000, animations: 'disabled' });
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
          format: 'jpeg', quality: 70, captureBeyondViewport: false, fromSurface: false
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
        return canvas ? canvas.toDataURL('image/jpeg', 0.72) : '';
      }),
      new Promise(resolve => setTimeout(() => resolve(''), 14000))
    ]);
    if (image.startsWith('data:image/jpeg;base64,')) {
      const raw = Buffer.from(image.slice('data:image/jpeg;base64,'.length), 'base64');
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
  for (const vp of [{ width: 1280, height: 720 }]) {
    const page = await browser.newPage({ viewport: vp, deviceScaleFactor: 1 });
    // This is a capture-only test context. Godot normally lets WebGL discard
    // the back buffer after presentation, so canvas.toDataURL() can only see
    // black after the compositor screenshot stalls under hosted SwiftShader.
    // Preserve the test renderer's buffer so the fallback captures the real
    // game frame. This does not change production export settings.
    await page.addInitScript(() => {
      const originalGetContext = HTMLCanvasElement.prototype.getContext;
      HTMLCanvasElement.prototype.getContext = function(type, attributes) {
        if (/^(webgl2?|experimental-webgl)$/i.test(String(type))) {
          attributes = { ...(attributes || {}), preserveDrawingBuffer: true };
        }
        return originalGetContext.call(this, type, attributes);
      };
    });
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
      page, path.join(output, 'r11-' + tag + '-max.jpg'), errors);
    if (screenshots.maximum === 'inconclusive') {
      result.scenes.push({ viewport: tag, ...detail,
        screenshot_status: screenshots, browser_console_errors: errors });
      result.errors.push(...errors);
      // Do not assert visual correctness or waste time testing 1080p when
      // the hosted software renderer couldn't produce a single 720p frame.
      throw new Error('Hosted SwiftShader cannot confirm visual frame at ' + tag);
    }
    // The hosted software renderer can produce a real frame but stalls when
    // receiving additional keyboard input after the expensive readback. The
    // separate browser flight gate covers controls; this gate records one
    // actual 720p game frame and exits while the page is still responsive.
    result.scenes.push({
      viewport: tag, init_ms: Date.now() - started,
      ...detail,
      browser_console_errors: errors,
      benchmark_event_reported: logs.length > 0,
      flight_controls_checked_by: 'browser_flight_r25.mjs',
      screenshot_status: screenshots,
      visual_capture_confirmed: screenshots.maximum !== 'inconclusive'
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
