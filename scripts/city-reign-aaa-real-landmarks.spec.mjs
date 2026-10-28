import {test,expect} from '@playwright/test'
import {PNG} from 'pngjs'
import {captureAnimatedWebGLViewport} from './omega-browser-evidence.mjs'

// Same real original native WorldBuilder, original city hall building
// and the ACTUAL treasury-paid GameState.build("council") transaction.
// Absolutely no staged HTML, fake asset or generated engine screenshot.
const ROI={x0:0.18,x1:0.81,y0:0.12,y1:0.84}
const get=(buf)=>PNG.sync.read(buf)
function pixel(img,fx,fy){
  const xx=Math.max(0,Math.min(img.width-1,Math.floor(fx*img.width)))
  const yy=Math.max(0,Math.min(img.height-1,Math.floor(fy*img.height)))
  const k=(yy*img.width+xx)*4
  return [img.data[k],img.data[k+1],img.data[k+2]]
}
function actualWorldEvidence(raw){
  const img=get(raw)
  const bins=new Set()
  let nonDark=0,count=0
  for(let y=0;y<46;y++)for(let x=0;x<75;x++){
    const fx=ROI.x0+(ROI.x1-ROI.x0)*(x+0.5)/75
    const fy=ROI.y0+(ROI.y1-ROI.y0)*(y+0.5)/46
    const p=pixel(img,fx,fy)
    bins.add(p.map(v=>Math.floor(v/14)).join(':'))
    if(Math.max(...p)>45)nonDark++
    count++
  }
  return {width:img.width,height:img.height,visualColorBins:bins.size,
    nonDarkFraction:nonDark/count}
}
function realPixelChange(first,second){
  const a=get(first),b=get(second)
  expect([a.width,a.height]).toEqual([b.width,b.height])
  let changed=0,sum=0,n=0
  for(let y=0;y<120;y++)for(let x=0;x<180;x++){
    const fx=ROI.x0+(ROI.x1-ROI.x0)*(x+0.5)/180
    const fy=ROI.y0+(ROI.y1-ROI.y0)*(y+0.5)/120
    const p=pixel(a,fx,fy),q=pixel(b,fx,fy)
    const d=Math.max(...p.map((v,i)=>Math.abs(v-q[i])))
    if(d>17)changed++
    sum+=d
    n++
  }
  return {meanMaxRgbDelta:sum/n,changedFraction:changed/n}
}
test('CITY REIGN real treasury-built city hall adds physical 3D architecture in actual Godot WebGL',async({page},info)=>{
  test.setTimeout(240000)
  const errors=[]
  page.on('pageerror',e=>errors.push(e.message))
  page.on('crash',()=>errors.push('actual exported original city crashed'))
  const response=await page.goto('/index.html',{waitUntil:'domcontentloaded',timeout:45000})
  expect(response?.status()).toBe(200)
  const canvas=page.locator('#canvas')
  await expect(canvas).toBeVisible()
  await page.waitForFunction(()=>document.querySelector('#status')===null,null,{timeout:135000})
  const gl=await canvas.evaluate(e=>({
    sourceWebGL2:!!e.getContext('webgl2'),lost:e.getContext('webgl2')?.isContextLost()??true,
    size:[e.width,e.height]
  }))
  expect(gl.sourceWebGL2,'authentic native Godot engine WebGL2, no HTML mock').toBe(true)
  expect(gl.lost).toBe(false)
  let unbuilt,baseline
  for(let i=0;i<6;i++){
    await page.waitForTimeout(i?1500:2300)
    unbuilt=(await captureAnimatedWebGLViewport(page)).png
    baseline=actualWorldEvidence(unbuilt)
    if(baseline.visualColorBins>30)break
  }
  await info.attach('source-original-city-hall-before-real-investment.png',{
    body:unbuilt,contentType:'image/png'
  })
  expect(baseline.visualColorBins,'original real city must be rendered in 3D').toBeGreaterThan(30)
  expect(baseline.nonDarkFraction,'real physical building and street are visible').toBeGreaterThan(0.14)
  await canvas.focus()
  await page.keyboard.press('2')
  await page.waitForTimeout(1800)
  const funded=(await captureAnimatedWebGLViewport(page)).png
  const builtDelta=realPixelChange(unbuilt,funded)
  await info.attach('source-original-city-hall-after-paid-council.png',{
    body:funded,contentType:'image/png'
  })
  expect(builtDelta.meanMaxRgbDelta,'REAL paid civic build changes physical architectural pixels').toBeGreaterThan(0.04)
  expect(builtDelta.changedFraction).toBeGreaterThan(0.0006)
  // Photograph actual original 3D city at NIGHT separately from daytime.
  await page.keyboard.press('3')
  await page.waitForTimeout(1500)
  const night=(await captureAnimatedWebGLViewport(page)).png
  const nightDelta=realPixelChange(funded,night)
  await info.attach('source-real-funded-city-hall-night-cinematic.png',{
    body:night,contentType:'image/png'
  })
  expect(nightDelta.meanMaxRgbDelta,'actual engine night lighting changes real source pixels').toBeGreaterThan(1.0)
  expect(nightDelta.changedFraction).toBeGreaterThan(0.03)
  await page.keyboard.press('4')
  await page.waitForTimeout(1450)
  const low=(await captureAnimatedWebGLViewport(page)).png
  const lowDelta=realPixelChange(night,low)
  await info.attach('source-original-city-hall-low-gpu-original-collider.png',{
    body:low,contentType:'image/png'
  })
  expect(lowDelta.meanMaxRgbDelta,'LOW physically removes new detailed architecture from original road').toBeGreaterThan(1.0)
  expect(lowDelta.changedFraction).toBeGreaterThan(0.03)
  await info.attach('real-city-civic-investment-pixels.json',{
    body:Buffer.from(JSON.stringify({gl,baseline,builtDelta,nightDelta,lowDelta,errors},null,2)),
    contentType:'application/json'
  })
  expect(errors).toEqual([])
})
