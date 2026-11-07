/* R25 actual WebAssembly flight E2E, not source-text assertions.
 * Runs hosted Chromium SwiftShader, which is NOT the user's physical GPU.
 * Requires live telemetry written by the Godot game's true physics loop.
 * Never count a visible canvas or JS keyboard mask alone as "ship moves".
 */
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';
import { cruiseClickAck } from './cruise_click_ack_r62.mjs';

const output = path.resolve('r25-browser-qa');
fs.mkdirSync(output, {recursive: true});
const log = {schema: 'NEBULA_R25_BROWSER_FLIGHT',renderer: 'headless Chromium SwiftShader software GL',passed: false,checks: [],errors: [],started_at: new Date().toISOString()};
const browser = await chromium.launch({
  headless: true,
  args: ['--no-sandbox','--use-gl=angle','--use-angle=swiftshader',
    '--enable-unsafe-swiftshader','--enable-webgl','--disable-features=Vulkan']
});
const page = await browser.newPage({viewport:{width:1280,height:720}});
page.on('pageerror', e => log.errors.push('pageerror: '+e.message.slice(0,320)));
page.on('console',m=>{
  if(m.type()==='error') log.errors.push('console: '+m.text().slice(0,320));
});
const snapshot = () => page.evaluate(() => window.__nebulaPilotTelemetry || null);
const waitFor = (condition, timeout=25000, arg=null) => page.waitForFunction(condition,arg,{timeout, polling:400});
const waitForTelemetry = async (condition, timeout=25000) => {
  const deadline = Date.now() + timeout;
  let latest = null;
  while (Date.now() < deadline) {
    latest = await snapshot();
    if (condition(latest)) return latest;
    await page.waitForTimeout(250);
  }
  throw new Error('telemetry condition timed out: '+JSON.stringify(latest));
};
async function checkpoint(name, condition) {
  const v=await snapshot();
  if(!condition(v))throw new Error(name+' failed with actual ship telemetry: '+JSON.stringify(v));
  log.checks.push({name,telemetry:v});
  return v;
}
// A successful DOM mouse click is never sufficient. Observe exactly one
// genuine Godot pressed event AND the desired craft state. Hosted SwiftShader
// may deliver telemetry AFTER a 10s wait expired; the final fresh snapshot
// must be classified, not automatically mislabeled as a rejected action.
async function pressRealCruise(desired, description) {
  let last = null;
  for (let attempt = 1; attempt <= 3; attempt++) {
    const before = await snapshot();
    if (!before?.cruise_button_visible ||
        !Number.isFinite(before.cruise_button_x) ||
        !Number.isFinite(before.cruise_button_y) ||
        before.cruise_view_w < 800 || before.cruise_view_h < 400) {
      throw new Error('Cruise UI is not visibly clickable: ' +
        JSON.stringify(before));
    }
    if (before.cruise === desired) {
      throw new Error('Cruise already at requested state BEFORE physical click: ' +
        JSON.stringify({desired, before}));
    }
    const bounds = await page.evaluate(() => {
      const r = document.querySelector('#canvas')?.getBoundingClientRect();
      return r ? {x:r.x, y:r.y, w:r.width, h:r.height} : null;
    });
    if (!bounds || bounds.w < 800 || bounds.h < 400)
      throw new Error('Cruise canvas geometry unavailable '+JSON.stringify(bounds));
    const click = {
      x: bounds.x + before.cruise_button_x * bounds.w / before.cruise_view_w,
      y: bounds.y + before.cruise_button_y * bounds.h / before.cruise_view_h
    };
    await page.mouse.move(click.x, click.y);
    await page.mouse.down();
    // Give the Godot physics loop a true down/up pair, even under WebGL stalls.
    await page.waitForTimeout(300);
    await page.mouse.up();

    let latest = null;
    let status = 'pending';
    const deadline = Date.now() + 26000;
    while (Date.now() < deadline && status === 'pending') {
      latest = await snapshot();
      status = cruiseClickAck(before, latest, desired);
      if (status === 'pending') await page.waitForTimeout(350);
    }
    // One final real read after the deadline handles an acknowledgement which
    // landed between the last timed poll and the timeout boundary. The R62
    // regression previously called this valid OFF click a "rejection".
    latest = await snapshot();
    status = cruiseClickAck(before, latest, desired);
    if (status === 'confirmed') {
      log.checks.push({name:description, attempt, click,
        before_events:before.cruise_button_events,
        after_events:latest.cruise_button_events, actual:latest,
        software_renderer_delayed_ack: Date.now() >= deadline});
      return latest;
    }
    last = {attempt, click, desired, before, latest, status};
    if (status !== 'pending') {
      throw new Error('Real cruise button did not reach the requested state: ' +
        JSON.stringify(last));
    }
    // Failed delivery is the ONLY legal case for another physical click.
    // Brief grace protects against a late Godot event before any retry.
    await page.waitForTimeout(1800);
    latest = await snapshot();
    status = cruiseClickAck(before, latest, desired);
    if (status === 'confirmed') {
      log.checks.push({name:description + ' delayed Godot frame', attempt,
        click, before_events:before.cruise_button_events,
        after_events:latest.cruise_button_events, actual:latest});
      return latest;
    }
    if (status !== 'pending')
      throw new Error('Late real cruise click rejected or duplicated: ' +
        JSON.stringify({attempt, click, before, latest, status}));
    log.checks.push({name:description+' undelivered real click', ...last});
  }
  throw new Error('Cruise button received no physical pressed event after ' +
    'three attempts: '+JSON.stringify(last));
}
try {
  await page.goto('http://127.0.0.1:8765/games/remix/arena-v2/nebula-3d/?r25-browser=1',
    {waitUntil:'domcontentloaded',timeout:45000});
  await page.locator('#canvas').waitFor({state:'visible',timeout:60000});
  // Creation of the HTML canvas is NOT evidence that Godot has started.
  await waitFor(()=>window.__nebulaPilotTelemetry?.ready === true,90000);
  const t0=await checkpoint('real Godot runtime initialized',s=>s?.version==='R25' && s.samples>=1 && Number.isFinite(s.flight_distance));
  if(!t0.locked) throw new Error('The R39 command hub did not lock the craft at startup');
  await checkpoint('R44 actual imported 3D ship viewport is mounted at desktop startup',
    s=>s?.locked === true && s.r44_preview_present === true &&
      s.r44_preview_width >= 320 && s.r44_preview_height >= 140);
  // Startup is the garage. Launch through the real in-game button before flight input.
  const garageBounds=await page.evaluate(() => { const r=document.querySelector('#canvas')?.getBoundingClientRect(); return r ? {x:r.x,y:r.y,width:r.width,height:r.height}:null; });
  if(!garageBounds) throw new Error('Game canvas bounds missing at garage startup');
  await page.mouse.click(
    garageBounds.x+t0.garage_sortie_x*garageBounds.width/t0.garage_view_w,
    garageBounds.y+t0.garage_sortie_y*garageBounds.height/t0.garage_view_h);
  await waitForTelemetry(s=>s && s.locked===false,18000);
  const launched=await checkpoint('garage sortie button unlocks real flight',s=>s?.locked===false);
  // R63: real 3D guide geometry and objective/course read from Godot
  // physics, not an overlay drawn in the web page or fake telemetry.
  await waitForTelemetry(s=>s?.r63_real_3d_gates>=1 &&
    s?.r63_navigation_distance_m>100 &&
    Number.isFinite(s.r63_navigation_bearing_deg),16000);
  await checkpoint('R63 real 3D flight corridor tracks true mission goal',
    s=>s?.r63_real_3d_gates>=1 &&
      s.r63_navigation_distance_m>100 &&
      Number.isFinite(s.r63_navigation_bearing_deg));

  // Software Chromium freezes locator.focus() even after the real Godot
  // runtime emits world positions. Do not block keyboard QA on compositor
  // focus: R26 registers global physical-code listeners before Godot loads.
  // Keyboard input targets the page itself, exactly as the fallback bridge.
  await page.keyboard.down('w');
  const keyInBrowser = await page.evaluate(() => ({
    mask:window.__nebulaPilotMask,
    debug:window.__nebulaKeyDebug,
    active:document.activeElement?.tagName || '',
    visible:document.visibilityState,
    focused:document.hasFocus()
  }));
  log.checks.push({name:'DOM keyboard capture before Godot',dom:keyInBrowser});
  if (!(keyInBrowser.mask & 1)) {
    throw new Error('R26 W did not reach browser capture bridge: '+JSON.stringify(keyInBrowser));
  }
  try {
    await waitForTelemetry(s=>s && (s.input_mask & 1),12000);
  } catch (error) {
    const telemetry = await snapshot();
    const dom = await page.evaluate(() => ({
      mask:window.__nebulaPilotMask,
      debug:window.__nebulaKeyDebug,
      active:document.activeElement?.tagName || '',
      focused:document.hasFocus()
    }));
    log.checks.push({name:'W-to-Godot bridge failure snapshot',telemetry,dom});
    throw new Error('W-to-Godot bridge failure snapshot: '+JSON.stringify({telemetry,dom})+'; '+error.message);
  }
  await waitForTelemetry(s=>s && s.flight_distance > 3.5,32000);
  const moving=await checkpoint('physical W drives real ship motion',
    s=>s?.speed_mps>1.0 && s.flight_distance>3.5 && (s.input_mask&1)!==0);
  await page.keyboard.up('w');
  await waitForTelemetry(s=>s && !(s.input_mask & 1),12000);
  log.checks.push({name:'keyboard keyup clears browser mask and does not stick',telemetry:await snapshot()});
  // Re-use game's real Godot button, not an external JS command.
  const bounds=await page.evaluate(() => {
    const rect=document.querySelector('#canvas')?.getBoundingClientRect();
    return rect ? {x:rect.x,y:rect.y,width:rect.width,height:rect.height} : null;
  });
  if(!bounds || bounds.width<=0 || bounds.height<=0)
    throw new Error('Game canvas was not interactable: '+JSON.stringify(bounds));
  const beforeCruise=await snapshot();
  const start=await pressRealCruise(true,
    'actual clickable cruise switch engaged');
  await waitForTelemetry(s=>s && s.cruise &&
    Math.abs(s.heading-beforeCruise.heading)>0.05,35000);
  const steered=await checkpoint('real autopilot rotates ship toward off-axis mission',
    s=>s?.cruise===true && Math.abs(s.heading-beforeCruise.heading)>0.05 && s.throttle>0.5);
  await waitForTelemetry(s=>s && s.mission_distance < start.mission_distance-2.0,45000);
  const approached=await checkpoint('real ship approaches mission objective in world units',
    s=>s?.mission_distance < start.mission_distance-2.0 && s.flight_distance>moving.flight_distance);
  // Stop and verify that the user can cancel guided flight.
  await pressRealCruise(false,'cruise can be disengaged');
  log.passed=true;
  log.summary={keyboard_metres:moving.flight_distance-t0.flight_distance,
    mission_closing_metres:start.mission_distance-approached.mission_distance,
    steering_degrees:Math.abs((steered.heading-start.heading)*180/Math.PI),
    test_is_real_browser_physics:true};
  console.log('NEBULA_R25_BROWSER_FLIGHT_SUCCESS '+JSON.stringify(log.summary));
} catch(e) {
  log.errors.push('R25 browser flight E2E: '+String(e.message));
  console.error('NEBULA_R25_BROWSER_FLIGHT_FAILURE '+String(e.stack || e.message));
  process.exitCode = 1;
} finally {
  // Hosted Chromium with a running WebGL Godot canvas can hang forever in
  // browser.close(), *after* every real telemetry check passed. Save proof
  // first, bound cleanup, and explicitly close the standalone CI process.
  // This must NEVER turn a failed flight check into a success.
  log.finished_at = new Date().toISOString();
  const reportPath = path.join(output,'flight.json');
  fs.writeFileSync(reportPath,JSON.stringify(log,null,2));
  let cleanupTimer;
  try {
    await Promise.race([
      browser.close(),
      new Promise((_,reject) => {
        cleanupTimer = setTimeout(() => reject(
          new Error('hosted SwiftShader browser.close() exceeded 6 seconds')),6000);
      })
    ]);
  } catch(error) {
    log.errors.push('Browser teardown warning: '+String(error.message));
    console.warn('NEBULA_R25_BROWSER_TEARDOWN_WARNING '+String(error.message));
    fs.writeFileSync(reportPath,JSON.stringify(log,null,2));
  } finally {
    clearTimeout(cleanupTimer);
  }
  const code = log.passed && process.exitCode !== 1 ? 0 : 1;
  // This is a single-purpose CLI verification script, not production code.
  process.exit(code);
}
