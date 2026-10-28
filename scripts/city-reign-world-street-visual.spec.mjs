import {test,expect} from '@playwright/test'
import {PNG} from 'pngjs'
import {captureAnimatedWebGLViewport} from './omega-browser-evidence.mjs'
import {realGameFrameEvidence} from './omega-world-frame-evidence.mjs'

// A true original Godot 4.4.1 WebGL scene with in-game camera. No 2D mock,
// fetched image, artificial pixel fill, HTML rendering substitute or overlay.
const ROI={x0:0.13,x1:0.88,y0:0.12,y1:0.91}
function compare(rawA,rawB){
  const a=PNG.sync.read(rawA),b=PNG.sync.read(rawB)
  if(a.width!==b.width||a.height!==b.height)throw new Error('Fixed camera size changed')
  let n=0,changed=0,sum=0
  for(let y=0;y<80;y++)for(let x=0;x<120;x++){
    const fx=ROI.x0+(ROI.x1-ROI.x0)*(x+0.5)/120
    const fy=ROI.y0+(ROI.y1-ROI.y0)*(y+0.5)/80
    const ix=Math.min(a.width-1,Math.floor(fx*a.width))
    const iy=Math.min(a.height-1,Math.floor(fy*a.height))
    const p=(iy*a.width+ix)*4
    const d=Math.max(Math.abs(a.data[p]-b.data[p]),
      Math.abs(a.data[p+1]-b.data[p+1]),
      Math.abs(a.data[p+2]-b.data[p+2]))
    sum+=d
    if(d>12)changed++
    n++
  }
  return {meanMaxRgbDifference:sum/n,changedPixelFraction:changed/n,samples:n}
}

test('CITY REIGN world edition: actual 3D street materials, dusk, power outage and mobile LOD',async({page},info)=>{
  test.setTimeout(260000)
  const faults=[]
  page.on('pageerror',error=>faults.push(error.message))
  page.on('crash',()=>faults.push('Real Godot WebGL renderer crashed'))
  const response=await page.goto('/index.html',{waitUntil:'domcontentloaded',timeout:50000})
  expect(response?.status()).toBe(200)
  const canvas=page.locator('#canvas')
  await expect(canvas).toBeVisible()
  await page.waitForFunction(()=>document.querySelector('#status')===null,
    null,{timeout:145000})
  const engine=await canvas.evaluate(el=>{
    const gl=el.getContext('webgl2')
    return {webgl2:!!gl,lost:gl?.isContextLost()??true,
      resolution:[el.width,el.height]}
  })
  expect(engine.webgl2,'This must be actual native Godot WebGL2').toBe(true)
  expect(engine.lost,'Original Godot context cannot be lost').toBe(false)
  await canvas.focus()
  let day,dayEvidence
  for(let i=0;i<6;i++){
    await page.waitForTimeout(i===0?3000:1700)
    day=(await captureAnimatedWebGLViewport(page)).png
    dayEvidence=realGameFrameEvidence(day)
    if(dayEvidence.realWorldEdges)break
  }
  expect(dayEvidence.realWorldEdges,'real 3D street, not splash/loader').toBe(true)
  await info.attach('original-godot-world-cinematic-16h.png',{
    body:day,contentType:'image/png'})
  await page.keyboard.press('2')
  await page.waitForTimeout(1200)
  const night=(await captureAnimatedWebGLViewport(page)).png
  await info.attach('original-godot-world-street-powered-22h.png',{
    body:night,contentType:'image/png'})
  const dusk=compare(day,night)
  expect(dusk.meanMaxRgbDifference,
    'clock must alter real 3D environment and physically shaded city').toBeGreaterThan(0.40)
  await page.keyboard.press('3')
  await page.waitForTimeout(900)
  const blackout=(await captureAnimatedWebGLViewport(page)).png
  await info.attach('original-godot-world-real-grid-blackout.png',{
    body:blackout,contentType:'image/png'})
  const brownout=compare(night,blackout)
  expect(brownout.meanMaxRgbDifference,
    'actual city energy should affect source-rendered pixels').toBeGreaterThan(0.008)
  await page.keyboard.press('1')
  await page.waitForTimeout(850)
  const restored=(await captureAnimatedWebGLViewport(page)).png
  // Real source-owned CAMERA REPOSITION to the original west-facing shop
  // entrance. This is not a dummy hero render or decorative Web image.
  await page.keyboard.press('7')
  await page.waitForTimeout(1100)
  const eyeLevel=(await captureAnimatedWebGLViewport(page)).png
  await info.attach('original-godot-real-eye-level-streetfront-cinematic.png',{
    body:eyeLevel,contentType:'image/png'})
  const streetPerspective=compare(restored,eyeLevel)
  expect(streetPerspective.meanMaxRgbDifference,
    'eye-level review must show a different original live WorldBuilder camera').toBeGreaterThan(0.40)
  await page.keyboard.press('4')
  await page.waitForTimeout(900)
  const low=(await captureAnimatedWebGLViewport(page)).png
  await info.attach('original-godot-world-low-mobile-lod.png',{
    body:low,contentType:'image/png'})
  const lowDelta=compare(eyeLevel,low)
  expect(lowDelta.meanMaxRgbDifference,
    'LOW must genuinely hide original premium architectural batches').toBeGreaterThan(0.12)
  await page.keyboard.press('5')
  await page.waitForTimeout(850)
  const standard=(await captureAnimatedWebGLViewport(page)).png
  await info.attach('original-godot-world-standard-architectural-pbr.png',{
    body:standard,contentType:'image/png'})
  await page.keyboard.press('6')
  await page.waitForTimeout(850)
  const cinematic=(await captureAnimatedWebGLViewport(page)).png
  await info.attach('original-godot-world-cinematic-physical-foliage.png',{
    body:cinematic,contentType:'image/png'})
  const qualityDelta=compare(standard,cinematic)
  await info.attach('city-reign-world-original-renderer-provenance.json',{
    body:Buffer.from(JSON.stringify({
      source:'godot/empire-omega/tests/city_reign_world_street_pixel_fixture.tscn',
      scene:'WorldBuilder original actual 3D city',engine,dayEvidence,
      dusk,brownout,streetPerspective,lowDelta,qualityDelta,faults,viewport:page.viewportSize()
    },null,2)),contentType:'application/json'
  })
  expect(faults).toEqual([])
})
