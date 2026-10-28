import {test,expect} from '@playwright/test'
import {PNG} from 'pngjs'
import {captureAnimatedWebGLViewport} from './omega-browser-evidence.mjs'

// 100% actual original Godot 4.4.1 game source engine and first-chapter
// project assets; no HTML/canvas/SVG rendered substitute or stock screenshot.
const ROI={x0:0.12,x1:0.85,y0:0.11,y1:0.88}
const decode=b=>PNG.sync.read(b)
function pixel(img,fx,fy){
  const x=Math.max(0,Math.min(img.width-1,Math.floor(fx*img.width)))
  const y=Math.max(0,Math.min(img.height-1,Math.floor(fy*img.height)))
  const q=(y*img.width+x)*4
  return [img.data[q],img.data[q+1],img.data[q+2]]
}
function inspect(raw){
  const img=decode(raw)
  let colour=0,n=0
  const bins=new Set()
  for(let y=0;y<48;y++)for(let x=0;x<78;x++){
    const v=pixel(img,ROI.x0+(ROI.x1-ROI.x0)*(x+0.5)/78,
      ROI.y0+(ROI.y1-ROI.y0)*(y+0.5)/48)
    bins.add(v.map(t=>Math.floor(t/12)).join(':'))
    if(Math.max(...v)>50)colour++
    n++
  }
  return {width:img.width,height:img.height,nonDarkFraction:colour/n,colourBins:bins.size}
}
function changed(first,last){
  const a=decode(first),b=decode(last)
  expect([b.width,b.height]).toEqual([a.width,a.height])
  let moving=0,sum=0,n=0
  for(let y=0;y<120;y++)for(let x=0;x<180;x++){
    const fx=ROI.x0+(ROI.x1-ROI.x0)*(x+0.5)/180
    const fy=ROI.y0+(ROI.y1-ROI.y0)*(y+0.5)/120
    const p=pixel(a,fx,fy),q=pixel(b,fx,fy)
    const delta=Math.max(...p.map((v,i)=>Math.abs(v-q[i])))
    if(delta>17)moving++
    sum+=delta
    n++
  }
  return {meanMaxRgbDelta:sum/n,changedFraction:moving/n}
}
test('CITY REIGN first promise really transforms the original 3D street after saved public investment',async({page},info)=>{
  test.setTimeout(240000)
  const errors=[]
  page.on('pageerror',e=>errors.push(e.message))
  page.on('crash',()=>errors.push('actual Godot WebGL renderer crash'))
  const response=await page.goto('/index.html',{waitUntil:'domcontentloaded',timeout:45000})
  expect(response?.status()).toBe(200)
  const canvas=page.locator('#canvas')
  await expect(canvas).toBeVisible()
  await page.waitForFunction(()=>document.querySelector('#status')===null,null,{timeout:135000})
  const engine=await canvas.evaluate(el=>({
    sourceWebGL2:!!el.getContext('webgl2'),
    lost:el.getContext('webgl2')?.isContextLost()??true,
    size:[el.width,el.height]
  }))
  expect(engine.sourceWebGL2,'real game source WASM/WebGL2, no browser-only mock').toBe(true)
  expect(engine.lost).toBe(false)
  let start,visual
  for(let retry=0;retry<5;retry++){
    await page.waitForTimeout(retry?1600:2200)
    start=(await captureAnimatedWebGLViewport(page)).png
    visual=inspect(start)
    if(visual.colourBins>36)break
  }
  await info.attach('real-original-city-two-proposals-before-funding.png',{
    body:start,contentType:'image/png'
  })
  expect(visual.colourBins,'true 3D city must not be a black/unrendered screen').toBeGreaterThan(36)
  expect(visual.nonDarkFraction).toBeGreaterThan(0.12)
  await canvas.focus()
  await page.keyboard.press('2')
  await page.waitForTimeout(1700)
  const paid=(await captureAnimatedWebGLViewport(page)).png
  const works=changed(start,paid)
  await info.attach('actual-game-funded-worksite-after-380-treasury-spent.png',{
    body:paid,contentType:'image/png'
  })
  expect(works.meanMaxRgbDelta,'REAL funded civic site replaces the proposal board').toBeGreaterThan(0.20)
  expect(works.changedFraction).toBeGreaterThan(0.003)
  await page.keyboard.press('3')
  await page.waitForTimeout(1150)
  const advanced=(await captureAnimatedWebGLViewport(page)).png
  const growing=changed(paid,advanced)
  await info.attach('real-city-first-paid-construction-turn.png',{
    body:advanced,contentType:'image/png'
  })
  expect(growing.meanMaxRgbDelta,'construction 1st real turn modifies actual Godot 3D').toBeGreaterThan(0.12)
  expect(growing.changedFraction).toBeGreaterThan(0.001)
  await page.keyboard.press('4')
  await page.waitForTimeout(1550)
  const built=(await captureAnimatedWebGLViewport(page)).png
  const delivered=changed(advanced,built)
  await info.attach('real-city-first-promise-original-completed-public-archive.png',{
    body:built,contentType:'image/png'
  })
  expect(delivered.meanMaxRgbDelta,'real 2nd city turn finishes physical original 3D service').toBeGreaterThan(0.5)
  expect(delivered.changedFraction).toBeGreaterThan(0.008)
  await page.keyboard.press('5')
  await page.waitForTimeout(1050)
  const low=(await captureAnimatedWebGLViewport(page)).png
  const mobile=changed(built,low)
  await info.attach('real-city-low-quality-gate-hidden-completed-building-still-stands.png',{
    body:low,contentType:'image/png'
  })
  expect(mobile.meanMaxRgbDelta,'LOW hides only extra native guidance, not real paid building').toBeGreaterThan(0.06)
  expect(mobile.changedFraction).toBeGreaterThan(0.0008)
  await info.attach('source-real-city-episode01-chapter-pixels.json',{
    body:Buffer.from(JSON.stringify({engine,visual,works,growing,delivered,mobile,errors},null,2)),
    contentType:'application/json'
  })
  expect(errors).toEqual([])
})
