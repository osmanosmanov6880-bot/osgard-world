import {test,expect} from '@playwright/test'
import {PNG} from 'pngjs'
import {captureAnimatedWebGLViewport} from './omega-browser-evidence.mjs'

// All frames are genuine exported Godot WebGL from the original game
// TrafficSignalGrid and nine authored GPU batches. NO image generation.
const ROI={x0:0.26,x1:0.76,y0:0.13,y1:0.83}
const read=(buf)=>PNG.sync.read(buf)
function pixel(img,fx,fy){
  const x=Math.max(0,Math.min(img.width-1,Math.floor(img.width*fx)))
  const y=Math.max(0,Math.min(img.height-1,Math.floor(img.height*fy)))
  const i=(y*img.width+x)*4
  return [img.data[i],img.data[i+1],img.data[i+2]]
}
function exposure(raw){
  const img=read(raw)
  let bright=0,rich=new Set(),n=0
  for(let y=0;y<42;y++)for(let x=0;x<64;x++){
    const rgb=pixel(img,ROI.x0+(ROI.x1-ROI.x0)*(x+0.5)/64,
      ROI.y0+(ROI.y1-ROI.y0)*(y+0.5)/42)
    if(Math.max(...rgb)>50)bright++
    rich.add(rgb.map(v=>Math.floor(v/12)).join(':'))
    n++
  }
  return {width:img.width,height:img.height,
    brightFraction:bright/n,colorBins:rich.size}
}
function compare(rawA,rawB){
  const a=read(rawA),b=read(rawB)
  expect([b.width,b.height]).toEqual([a.width,a.height])
  let moved=0,delta=0,n=0
  for(let y=0;y<70;y++)for(let x=0;x<110;x++){
    const fx=ROI.x0+(ROI.x1-ROI.x0)*(x+0.5)/110
    const fy=ROI.y0+(ROI.y1-ROI.y0)*(y+0.5)/70
    const p=pixel(a,fx,fy),q=pixel(b,fx,fy)
    const d=Math.max(...p.map((v,i)=>Math.abs(v-q[i])))
    if(d>=18)moved++
    delta+=d
    n++
  }
  return {meanMaxRgbDelta:delta/n,changedFraction:moved/n}
}
test('CITY REIGN physical red amber green traffic signs are real law-synced WebGL geometry',async({page},info)=>{
  test.setTimeout(240000)
  const errors=[]
  page.on('pageerror',e=>errors.push(e.message))
  page.on('crash',()=>errors.push('real Godot renderer crashed'))
  const response=await page.goto('/index.html',{waitUntil:'domcontentloaded',timeout:35000})
  expect(response?.status()).toBe(200)
  const canvas=page.locator('#canvas')
  await expect(canvas).toBeVisible()
  await page.waitForFunction(()=>document.querySelector('#status')===null,null,{timeout:125000})
  const gl=await canvas.evaluate(e=>({webgl2:!!e.getContext('webgl2'),
    lost:e.getContext('webgl2')?.isContextLost()??true,
    w:e.width,h:e.height}))
  expect(gl.webgl2,'actual original Godot WASM WebGL2, not DOM signal fake').toBe(true)
  expect(gl.lost).toBe(false)
  let xGreen
  for(let retry=0;retry<5;retry++){
    await page.waitForTimeout(1300)
    xGreen=(await captureAnimatedWebGLViewport(page)).png
    if(exposure(xGreen).colorBins>35)break
  }
  const proof=exposure(xGreen)
  await info.attach('genuine-3d-x-green-z-red.png',{body:xGreen,contentType:'image/png'})
  expect(proof.colorBins,'not a static blank fake or unrendered sign surface').toBeGreaterThan(35)
  expect(proof.brightFraction,'real metallic 3D scene illumination').toBeGreaterThan(0.10)
  await canvas.focus()
  await page.keyboard.press('2')
  await page.waitForTimeout(1100)
  const zGreen=(await captureAnimatedWebGLViewport(page)).png
  const swap=compare(xGreen,zGreen)
  await info.attach('genuine-3d-z-green-x-red.png',{body:zGreen,contentType:'image/png'})
  expect(swap.meanMaxRgbDelta,'genuine source red-green traffic phase changes rendered optical LEDs').toBeGreaterThan(0.25)
  expect(swap.changedFraction).toBeGreaterThan(0.006)
  await page.keyboard.press('3')
  await page.waitForTimeout(1000)
  const amber=(await captureAnimatedWebGLViewport(page)).png
  const yellow=compare(zGreen,amber)
  await info.attach('genuine-3d-amber-warning.png',{body:amber,contentType:'image/png'})
  expect(yellow.meanMaxRgbDelta,'same Godot real 3D optical lens enters yellow warning').toBeGreaterThan(0.20)
  expect(yellow.changedFraction).toBeGreaterThan(0.006)
  await page.keyboard.press('4')
  await page.waitForTimeout(850)
  const low=(await captureAnimatedWebGLViewport(page)).png
  const quality=compare(amber,low)
  await info.attach('genuine-3d-low-original-signal-fallback.png',{body:low,contentType:'image/png'})
  expect(quality.meanMaxRgbDelta,'LOW quality really restores original physical boxes').toBeGreaterThan(1.0)
  expect(quality.changedFraction).toBeGreaterThan(0.03)
  await info.attach('source-native-signal-webgl-pixels.json',{
    body:Buffer.from(JSON.stringify({gl,proof,swap,yellow,quality,errors},null,2)),
    contentType:'application/json'
  })
  expect(errors).toEqual([])
})
