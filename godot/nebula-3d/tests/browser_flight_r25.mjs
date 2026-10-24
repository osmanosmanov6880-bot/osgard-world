/* R25 actual WebAssembly flight E2E, not source-text assertions.
 * Runs hosted Chromium SwiftShader, which is NOT the user's physical GPU.
 * Requires live telemetry written by the Godot game's true physics loop.
 * Never count a visible canvas or JS keyboard mask alone as "ship moves".
 */
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

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
try {
  await page.goto('http://127.0.0.1:8765/games/remix/arena-v2/nebula-3d/?r25-browser=1',
    {waitUntil:'domcontentloaded',timeout:45000});
  await page.locator('#canvas').waitFor({state:'visible',timeout:60000});
  // Creation of the HTML canvas is NOT evidence that Godot has started.
  await waitFor(()=>window.__nebulaPilotTelemetry?.ready === true,90000);
  const t0=await checkpoint('real Godot runtime initialized',s=>s?.version==='R25' && s.samples>=1 && Number.isFinite(s.flight_distance));
  if(t0.locked) throw new Error('Player controls are locked at startup');
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
  const bounds=await page.locator('#canvas').boundingBox();
  if(!bounds)throw new Error('Game canvas was not interactable');
  await page.mouse.click(bounds.x+bounds.width/2,bounds.y+bounds.height-70);
  await waitForTelemetry(s=>s && s.cruise === true,15000);
  const start=await checkpoint('actual clickable cruise switch engaged',s=>s?.cruise===true);
  await waitForTelemetry(s=>s && s.samples>start.samples+5 &&
    Math.abs(s.heading-start.heading)>0.05,35000);
  const steered=await checkpoint('real autopilot rotates ship toward off-axis mission',
    s=>s?.cruise===true && Math.abs(s.heading-start.heading)>0.05 && s.throttle>0.5);
  await waitForTelemetry(s=>s && s.mission_distance < start.mission_distance-2.0,45000);
  const approached=await checkpoint('real ship approaches mission objective in world units',
    s=>s?.mission_distance < start.mission_distance-2.0 && s.flight_distance>moving.flight_distance);
  // Stop and verify that the user can cancel guided flight.
  await page.mouse.click(bounds.x+bounds.width/2,bounds.y+bounds.height-70);
  await waitForTelemetry(s=>s && s.cruise===false,12000);
  await checkpoint('cruise can be disengaged',s=>s?.cruise===false);
  log.passed=true;
  log.summary={keyboard_metres:moving.flight_distance-t0.flight_distance,
    mission_closing_metres:start.mission_distance-approached.mission_distance,
    steering_degrees:Math.abs((steered.heading-start.heading)*180/Math.PI),
    test_is_real_browser_physics:true};
  console.log('NEBULA_R25_BROWSER_FLIGHT_SUCCESS '+JSON.stringify(log.summary));
} catch(e) {
  log.errors.push('R25 browser flight E2E: '+String(e.message));
  console.error('NEBULA_R25_BROWSER_FLIGHT_FAILURE '+String(e.message));
  throw e;
} finally {
  log.finished_at=new Date().toISOString();
  fs.writeFileSync(path.join(output,'flight.json'),JSON.stringify(log,null,2));
  await browser.close();
}
