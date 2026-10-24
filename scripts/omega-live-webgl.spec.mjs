import { test, expect } from '@playwright/test'
import { readFileSync } from 'node:fs'
import { PNG } from 'pngjs'
import { browserTouchPoint } from './omega-mobile-touch-geometry.mjs'

// This exercises the REAL public Godot 4.4.1 WebAssembly and WebGL renderer,
// not just the marketing page or HTML canvas shell. Native v34 separately
// proves actual car displacement, steering and InputMap processing.
const RELEASE = JSON.parse(readFileSync('public/games/omega-3d-preview/release.json','utf8'))
const GAME = '/games/omega-3d-preview/'

// Compare ACTUAL rendered world pixels, excluding top HUD and bottom touch
// controls. Stationary idle traffic shifts 1-2% of these pixels; entering
// a vehicle and physically steering must change substantially more.
function centralSceneMotion(first, second) {
  const a=PNG.sync.read(first)
  const b=PNG.sync.read(second)
  if(a.width!==b.width||a.height!==b.height)throw Error('Screenshot viewport changed during driving')
  let changed=0,total=0
  for(let y=Math.floor(a.height*0.25);y<Math.floor(a.height*0.81);y+=3) {
    for(let x=Math.floor(a.width*0.20);x<Math.floor(a.width*0.80);x+=3) {
      const index=(y*a.width+x)*4
      total+=1
      const delta=Math.max(
        Math.abs(a.data[index]-b.data[index]),
        Math.abs(a.data[index+1]-b.data[index+1]),
        Math.abs(a.data[index+2]-b.data[index+2]))
      if(delta>35) changed+=1
    }
  }
  return total?changed/total:0
}

test('authentic released Godot runs WebGL2, paints scene, handles real keyboard/touch',async({page,request},testInfo)=>{
  test.setTimeout(180_000)
  const errors=[]
  const logs=[]
  page.on('pageerror',e=>errors.push(e.message))
  page.on('crash',()=>errors.push('Chromium game page crashed'))
  page.on('console',message=>{
    if(message.type()==='error'||message.type()==='warning')
      logs.push(`${message.type()}: ${message.text()}`)
  })
  const nonce=`omega_browser_${Date.now()}_${testInfo.project.name}`
  // Record the user-visible CDN version separately: a stale unversioned
  // manifest was ACTUALLY seen after the successful R10 SSH deployment.
  const ordinary=await request.get(GAME+'release.json',{timeout:30000})
  expect(ordinary.status()).toBe(200)
  const ordinaryManifest=await ordinary.json()
  const manifestResponse=await request.get(GAME+'release.json?omega_verify='+nonce,{
    timeout:30000,headers:{'Cache-Control':'no-cache','Pragma':'no-cache'}
  })
  expect(manifestResponse.status()).toBe(200)
  const live=await manifestResponse.json()
  await testInfo.attach('godot-public-cdn-version.json',{
    body:Buffer.from(JSON.stringify({
      normal_source:ordinaryManifest.source_commit,
      fresh_source:live.source_commit,
      expected:RELEASE.source_commit,
      normal_cache_control:ordinary.headers()['cache-control']||null,
      normal_cf_cache_status:ordinary.headers()['cf-cache-status']||null,
      normal_age:ordinary.headers().age||null,
      normal_stale:ordinaryManifest.source_commit!==live.source_commit
    },null,2)),contentType:'application/json'
  })
  expect(live.engine).toBe('Godot 4.4.1')
  expect(live.artifact_kind).toBe('native-Godot-HTML5-export')
  expect(live.native_tests).toBe('passed')
  expect(live.source_commit).toBe(RELEASE.source_commit)
  expect(live.files).toEqual(RELEASE.files)

  // Until mutable CDN caching is corrected, explicit cache-busted URLs
  // verify the EXACT release rather than silently running the older R9.
  await page.route('**/games/omega-3d-preview/*',async route=>{
    const asset=new URL(route.request().url())
    asset.searchParams.set('omega_verify',nonce)
    await route.continue({url:asset.toString()})
  })
  const response=await page.goto(GAME+'?omega_verify='+nonce,{
    waitUntil:'domcontentloaded',timeout:45000
  })
  expect(response?.status()).toBe(200)
  await expect(page.locator('#canvas')).toBeVisible()
  // Godot's original page removes #status ONLY after engine.startGame()
  // resolves. An HTTP-200 / a static canvas element is NOT enough.
  await page.waitForFunction(()=>document.querySelector('#status')===null,null,{timeout:135000})
  const engine=await page.locator('canvas#canvas').evaluate(canvas=>{
    const bounds=canvas.getBoundingClientRect()
    const context=canvas.getContext('webgl2')
    return {
      width:canvas.width,height:canvas.height,
      cssWidth:bounds.width,cssHeight:bounds.height,
      webgl2:!!context,contextLost:context?.isContextLost()??true,
      pageWidth:document.documentElement.scrollWidth,
      viewportWidth:window.innerWidth
    }
  })
  expect(engine.webgl2,'actual Godot WebGL 2 context').toBe(true)
  expect(engine.contextLost).toBe(false)
  expect(engine.width).toBeGreaterThan(290)
  expect(engine.height).toBeGreaterThan(390)
  expect(engine.cssWidth).toBeGreaterThan(280)
  expect(engine.cssHeight).toBeGreaterThan(390)
  expect(engine.pageWidth).toBeLessThanOrEqual(engine.viewportWidth+3)

  // A running Godot canvas continuously resizes/paints frames. Element
  // screenshots wait for "stable" bounds forever even when WebGL renders.
  // Capture the actual viewport instead; never wait for the animated canvas.
  const frame=await page.screenshot({animations:'disabled',timeout:45000})
  expect(frame.subarray(0,8).toString('hex')).toBe('89504e470d0a1a0a')
  expect(frame.length,'rendered world has meaningful nonblank pixels').toBeGreaterThan(9500)
  await testInfo.attach('godot-real-world-initial.png',{body:frame,contentType:'image/png'})
  // R12 screenshot regression: an authentic pre-fix mobile frame from R11
  // rendered ONLY rows 312..530 of 844: 74% of the phone stayed black.
  // Engine.startGame success and a nonempty screenshot were insufficient.
  if(testInfo.project.name.startsWith('touch')){
    const png=PNG.sync.read(frame)
    let alive=0
    let longest=0
    let contiguous=0
    for(let y=0;y<png.height;y++){
      let seen=0
      let samples=0
      for(let x=Math.floor(png.width/4);x<Math.floor(png.width*3/4);x+=7){
        const off=(y*png.width+x)*4
        samples+=1
        if(Math.max(png.data[off],png.data[off+1],png.data[off+2])>25) seen+=1
      }
      const filled=seen>=Math.max(2,Math.round(samples*0.15))
      if(filled){alive+=1;contiguous+=1;longest=Math.max(longest,contiguous)}
      else contiguous=0
    }
    const coverage=alive/png.height
    await testInfo.attach('omega-portrait-screen-coverage.json',{
      body:Buffer.from(JSON.stringify({
        resolution:[png.width,png.height],litRows:alive,coverage,
        maxContinuousLitFraction:longest/png.height,required:0.68
      },null,2)),contentType:'application/json'
    })
    expect(coverage,'real playable scene must occupy at least 68% of portrait viewport, not a narrow 16:9 strip').toBeGreaterThan(0.68)
    expect(longest/png.height,'Godot camera should paint an unbroken majority of phone height').toBeGreaterThan(0.62)
  }

  if(testInfo.project.name.startsWith('touch')){
    const bounds=await page.locator('#canvas').boundingBox()
    expect(bounds).toBeTruthy()
    // The actual R12 mobile screenshot shows CAR at (259,702), GAS at
    // (337,786) and LEFT at (53,786) at 390x844. A previous test tried
    // CAR at (304,750) — empty roadway, not a game control. Derive every
    // target from the same Godot _layout() geometry instead of guessing.
    const enter=browserTouchPoint(bounds,'enter_vehicle')
    await page.touchscreen.tap(enter.x,enter.y)
    await page.waitForTimeout(900)
    const entered=await page.screenshot({animations:'disabled',timeout:45000})
    const entryMotion=centralSceneMotion(frame,entered)
    await testInfo.attach('godot-mobile-after-enter-car.png',{body:entered,contentType:'image/png'})
    expect(entryMotion,'tapping the visible CAR button must actually change the world camera').toBeGreaterThan(0.08)
    const cdp=await page.context().newCDPSession(page)
    const accelerator={...browserTouchPoint(bounds,'move_forward'),id:0,radiusX:6,radiusY:6}
    const steering={...browserTouchPoint(bounds,'move_left'),id:1,radiusX:6,radiusY:6}
    await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[accelerator,steering]})
    await page.waitForTimeout(1900)
    await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]})
    const driven=await page.screenshot({animations:'disabled',timeout:45000})
    const driveMotion=centralSceneMotion(entered,driven)
    await testInfo.attach('godot-mobile-after-real-two-finger-drive.png',{body:driven,contentType:'image/png'})
    await testInfo.attach('godot-mobile-actual-control-evidence.json',{
      body:Buffer.from(JSON.stringify({entryTap:enter,gasTap:accelerator,steerTap:steering,entryMotion,driveMotion},null,2)),
      contentType:'application/json'
    })
    expect(driveMotion,'accelerating and steering with two real browser touchpoints must visibly move the city camera').toBeGreaterThan(0.08)
  } else {
    // Same actions as touch screen: enter car, accelerate, steer and release.
    await page.keyboard.press('e')
    await page.keyboard.down('w')
    await page.keyboard.down('a')
    await page.waitForTimeout(1500)
    await page.keyboard.up('a')
    await page.keyboard.up('w')
  }
  const after=await page.screenshot({animations:'disabled',timeout:45000})
  expect(after.length).toBeGreaterThan(9500)
  await testInfo.attach('godot-real-world-after-input.png',{body:after,contentType:'image/png'})
  await testInfo.attach('godot-browser-console.txt',{body:Buffer.from(logs.join('\n'))||Buffer.from(''),contentType:'text/plain'})
  expect(errors,'no uncaught Javascript errors or crashed game tab').toEqual([])
})
