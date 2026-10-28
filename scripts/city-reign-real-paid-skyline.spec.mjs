import {test,expect} from '@playwright/test'
import {PNG} from 'pngjs'
import {captureAnimatedWebGLViewport} from './omega-browser-evidence.mjs'

// Real screenshot pixels from Godot 4.4.1 export of original entire city,
// NOT fabricated SVG/HTML, generative artwork, 2D composite or showroom.
const ROI={x0:0.22,x1:0.79,y0:0.14,y1:0.87}
const get=(b)=>PNG.sync.read(b)
function pixel(im,x,y){
  const xx=Math.max(0,Math.min(im.width-1,Math.floor(im.width*x)))
  const yy=Math.max(0,Math.min(im.height-1,Math.floor(im.height*y)))
  const o=(yy*im.width+xx)*4
  return [im.data[o],im.data[o+1],im.data[o+2]]
}
function summary(buf){
  const a=get(buf);const bins=new Set()
  let lit=0,n=0
  for(let y=0;y<60;y++)for(let x=0;x<90;x++){
    const px=pixel(a,ROI.x0+(ROI.x1-ROI.x0)*(x+0.5)/90,ROI.y0+(ROI.y1-ROI.y0)*(y+0.5)/60)
    bins.add(px.map(v=>Math.floor(v/14)).join(':'))
    if(Math.max(...px)>50)lit++
    n++
  }
  return {size:[a.width,a.height],distinctBins:bins.size,litFraction:lit/n}
}
function pixelDelta(before,after){
  const a=get(before),b=get(after)
  expect([b.width,b.height]).toEqual([a.width,a.height])
  let changed=0,distance=0,n=0
  for(let y=0;y<90;y++)for(let x=0;x<140;x++){
    const sx=ROI.x0+(ROI.x1-ROI.x0)*(x+0.5)/140
    const sy=ROI.y0+(ROI.y1-ROI.y0)*(y+0.5)/90
    const p=pixel(a,sx,sy),q=pixel(b,sx,sy)
    const d=Math.max(...p.map((v,k)=>Math.abs(v-q[k])))
    if(d>18)changed++
    distance+=d
    n++
  }
  return {meanMaxRGB:distance/n,changedFraction:changed/n}
}
test('actual 3D council plot rises only after real saved treasury purchase; LOW keeps old city, removes purchased facade',async({page},info)=>{
  test.setTimeout(240000)
  const errors=[]
  page.on('pageerror',e=>errors.push(e.message))
  page.on('crash',()=>errors.push('original Godot WebGL engine crashed'))
  const res=await page.goto('/index.html',{waitUntil:'domcontentloaded',timeout:50000})
  expect(res?.status()).toBe(200)
  const canvas=page.locator('#canvas')
  await expect(canvas).toBeVisible()
  await page.waitForFunction(()=>document.querySelector('#status')===null,null,{timeout:135000})
  const context=await canvas.evaluate(e=>({ready:!!e.getContext('webgl2'),lost:e.getContext('webgl2')?.isContextLost()??true,w:e.width,h:e.height}))
  expect(context.ready,'Godot real original WebGL 2 game').toBe(true)
  expect(context.lost).toBe(false)
  let before,render
  for(let t=0;t<5;t++){
    await page.waitForTimeout(t?1400:1800)
    before=(await captureAnimatedWebGLViewport(page)).png
    render=summary(before)
    if(render.distinctBins>35)break
  }
  await info.attach('actual-source-unfunded-city-plot.png',{body:before,contentType:'image/png'})
  expect(render.distinctBins,'true source-rendered first-person city texture and daylight variety').toBeGreaterThan(35)
  expect(render.litFraction,'real city is not a black frame').toBeGreaterThan(0.10)
  await canvas.focus()
  await page.keyboard.press('2')
  await page.waitForTimeout(1800)
  const paid=(await captureAnimatedWebGLViewport(page)).png
  await info.attach('actual-source-funded-city-with-painted-3d-facade.png',{body:paid,contentType:'image/png'})
  const purchased=pixelDelta(before,paid)
  expect(purchased.meanMaxRGB,'real PAID GameState.build renders new physical 3D plot').toBeGreaterThan(0.65)
  expect(purchased.changedFraction).toBeGreaterThan(0.008)
  await page.keyboard.press('3')
  await page.waitForTimeout(1100)
  const low=(await captureAnimatedWebGLViewport(page)).png
  await info.attach('actual-source-paid-building-mobile-fallback.png',{body:low,contentType:'image/png'})
  const simplified=pixelDelta(paid,low)
  expect(simplified.meanMaxRGB,'real GPU LOW disables distinct purchased facade geometry').toBeGreaterThan(0.40)
  expect(simplified.changedFraction).toBeGreaterThan(0.005)
  await page.keyboard.press('4')
  await page.waitForTimeout(900)
  const restored=(await captureAnimatedWebGLViewport(page)).png
  const restoration=pixelDelta(low,restored)
  expect(restoration.meanMaxRGB,'original PBR 3D paid architecture returns without restart').toBeGreaterThan(0.40)
  await info.attach('actual-source-original-detail-restored.png',{body:restored,contentType:'image/png'})
  await info.attach('12-project-building-actual-chromium-RGB.json',{
    body:Buffer.from(JSON.stringify({context,render,purchased,simplified,restoration,errors},null,2)),
    contentType:'application/json'
  })
  expect(errors).toEqual([])
})
