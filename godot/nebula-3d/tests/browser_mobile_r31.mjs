/* NEBULA R31: actual WebAssembly mobile touch QA, not mocked engine input.
 * Chrome DevTools sends touch events at real on-screen controls. The test
 * accepts only movement measured by Godot's genuine physics loop.
 * Hosted Chromium uses SwiftShader; this is NOT a physical phone FPS test.
 */
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const output = path.resolve('r31-mobile-browser-qa');
fs.mkdirSync(output, { recursive: true });
const report = {
  schema: 'NEBULA_R31_ACTUAL_MOBILE_TOUCH_QA',
  renderer: 'Chromium SwiftShader mobile emulation (not phone GPU)',
  passed: false, checks: [], errors: [], started_at: new Date().toISOString()
};
const browser = await chromium.launch({
  headless: true,
  args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader',
    '--enable-webgl', '--enable-unsafe-swiftshader', '--disable-features=Vulkan']
});
let page;
let cdp;
try {
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 1, isMobile: true, hasTouch: true
  });
  page = await context.newPage();
  page.on('pageerror', e => report.errors.push('JS: ' + e.message.slice(0, 250)));
  await page.goto(
    'http://127.0.0.1:8765/games/remix/arena-v2/nebula-3d/?r31-mobile-qa=1',
    { waitUntil: 'domcontentloaded', timeout: 45000 }
  );
  await page.locator('#canvas').waitFor({ state: 'visible', timeout: 70000 });
  const snapshot = () => page.evaluate(() => window.__nebulaPilotTelemetry || null);
  async function expectTelemetry(label, test, timeout = 35000) {
    const deadline = Date.now() + timeout;
    let latest = null;
    while (Date.now() < deadline) {
      latest = await snapshot();
      if (test(latest)) {
        report.checks.push({ label, telemetry: latest });
        return latest;
      }
      await page.waitForTimeout(300);
    }
    throw new Error(label + ': timed out; last physics telemetry=' + JSON.stringify(latest));
  }
  const ready = await expectTelemetry(
    'mobile Godot game, QA diagnostics and real touch controls initialized',
    s => s?.ready && s?.touch_enabled === true &&
      s.touch_view_w > 200 && s.touch_view_h > 200 &&
      s.touch_thrust_x > 0 && s.touch_boost_x > 0,
    100000
  );
  if (ready.locked || ready.cruise) {
    throw new Error('Mobile test began with controls locked or cruise auto-enabled');
  }
  const rect = await page.evaluate(() => {
    const c = document.querySelector('#canvas');
    const r = c?.getBoundingClientRect();
    return r ? { x:r.x, y:r.y, width:r.width, height:r.height } : null;
  });
  if (!rect || rect.width < 200 || rect.height < 200) {
    throw new Error('Mobile canvas is missing or off-screen: ' + JSON.stringify(rect));
  }
  // Coordinates originate in the real Godot responsive layout.
  const point = (x, y, id) => ({
    x: rect.x + x * rect.width / ready.touch_view_w,
    y: rect.y + y * rect.height / ready.touch_view_h,
    id, force: 1
  });
  const thrust = point(ready.touch_thrust_x, ready.touch_thrust_y, 1);
  const boost = point(ready.touch_boost_x, ready.touch_boost_y, 2);
  for (const p of [thrust, boost]) {
    if (p.x < rect.x || p.y < rect.y ||
        p.x > rect.x + rect.width || p.y > rect.y + rect.height) {
      throw new Error('Touch target falls outside screen: ' + JSON.stringify({rect,p}));
    }
  }
  cdp = await context.newCDPSession(page);
  const send = (type, touchPoints) => cdp.send('Input.dispatchTouchEvent',
    {type, touchPoints});
  try {
    await send('touchStart', [thrust]);
    await expectTelemetry('real browser touch activates throttle',
      s => s?.touch_count >= 1 && s.touch_throttle >= 0.9, 25000);
    const moved = await expectTelemetry('mobile throttle moves actual ship',
      s => s?.flight_distance > ready.flight_distance + 3.0 &&
        s.speed_mps > 1.0, 45000);
    await send('touchEnd', []);
    await expectTelemetry('finger release clears throttle and counters',
      s => s?.touch_count === 0 && s.touch_throttle <= 0.01, 20000);
    await send('touchStart', [thrust]);
    await send('touchStart', [thrust, boost]);
    await expectTelemetry('real two-finger throttle and boost',
      s => s?.touch_count >= 2 && s.touch_boost === true &&
        s.touch_throttle >= 0.9, 25000);
    await expectTelemetry('two-finger flight advances world physics',
      s => s?.flight_distance > moved.flight_distance + 2.0, 40000);
    await send('touchEnd', []);
    await expectTelemetry('multitouch release never sticks boost',
      s => s?.touch_count === 0 && s.touch_boost === false &&
        s.touch_throttle <= 0.01, 20000);
  } finally {
    await send('touchEnd', []).catch(() => {});
  }
  report.passed = true;
  report.summary = {
    actual_browser_touch: true, actual_godot_physics: true,
    canvas_css: {width:rect.width, height:rect.height},
    input_method: 'Chrome DevTools Input.dispatchTouchEvent'
  };
  console.log('NEBULA_R31_MOBILE_TOUCH_SUCCESS ' + JSON.stringify(report.summary));
} catch (error) {
  report.errors.push('R31 mobile E2E: ' + String(error.message));
  console.error('NEBULA_R31_MOBILE_TOUCH_FAILURE ' + String(error.message));
  throw error;
} finally {
  report.finished_at = new Date().toISOString();
  fs.writeFileSync(path.join(output, 'mobile.json'), JSON.stringify(report, null, 2));
  await cdp?.detach().catch(() => {});
  await browser.close();
}
