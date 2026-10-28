import {test,expect} from '@playwright/test'
import {PNG} from 'pngjs'
import {captureAnimatedWebGLViewport} from './omega-browser-evidence.mjs'

// Source-only fixture runs actual original Godot 4.4.1 WebAssembly / WebGL2
// with the same live HORIZON_BODY model and showroom UI as the playable city.
// The CI runner temporarily switches ONLY its private checkout entry scene.
const ROI = {x0:0.055,x1:0.445,y0:0.18,y1:0.505}

function sample(png,fx,fy){
  const x=Math.max(0,Math.min(png.width-1,Math.floor(fx*png.width)))
  const y=Math.max(0,Math.min(png.height-1,Math.floor(fy*png.height)))
  const off=(y*png.width+x)*4
  return [png.data[off],png.data[off+1],png.data[off+2]]
}
function originalCarEvidence(raw){
  const image=PNG.sync.read(raw)
  let bright=0,total=0
  const colors=new Set()
  for(let y=0;y<34;y++)for(let x=0;x<62;x++){
    const fx=ROI.x0+(ROI.x1-ROI.x0)*(x+0.5)/62
    const fy=ROI.y0+(ROI.y1-ROI.y0)*(y+0.5)/34
    const p=sample(image,fx,fy)
    if(Math.max(...p)>48)bright++
    colors.add(p.map(v=>Math.floor(v/16)).join(':'))
    total++
  }
  return {width:image.width,height:image.height,
    originalCarRoiBrightFraction:bright/total,
    colorBins:colors.size}
}
function actualPixelMovement(firstRaw,secondRaw){
  const a=PNG.sync.read(firstRaw),b=PNG.sync.read(secondRaw)
  let total=0,deltaSum=0,changed=0
  for(let y=0;y<38;y++)for(let x=0;x<65;x++){
    const fx=ROI.x0+(ROI.x1-ROI.x0)*(x+0.5)/65
    const fy=ROI.y0+(ROI.y1-ROI.y0)*(y+0.5)/38
    const p=sample(a,fx,fy),q=sample(b,fx,fy)
    const difference=Math.max(...p.map((v,k)=>Math.abs(v-q[k])))
    deltaSum+=difference
    if(difference>18)changed++
    total++
  }
  return {meanMaxRgbDelta:deltaSum/total,changedFraction:changed/total,
    first:[a.width,a.height],second:[b.width,b.height]}
}
test('CITY REIGN original Godot vehicle studio paints real 3D and reacts to body/rotation',async({page},info)=>{
  test.setTimeout(240000)
  const errors=[]
  page.on('pageerror',e=>errors.push(e.message))
  page.on('crash',()=>errors.push('real Godot game test crashed'))
  const source=await page.goto('/index.html',{waitUntil:'domcontentloaded',timeout:35000})
  expect(source?.status()).toBe(200)
  const canvas=page.locator('#canvas')
  await expect(canvas).toBeVisible()
  await page.waitForFunction(()=>document.querySelector('#status')===null,null,{timeout:125000})
  const context=await canvas.evaluate(el=>({
    webgl:!!el.getContext('webgl2'),
    lost:el.getContext('webgl2')?.isContextLost()??true,
    width:el.width,height:el.height
  }))
  expect(context.webgl,'actual Godot exported WebGL2 context, not HTML fake').toBe(true)
  expect(context.lost).toBe(false)
  let initial,initProof
  for(let attempt=0;attempt<6;attempt++){
    await page.waitForTimeout(attempt?1800:2500)
    initial=(await captureAnimatedWebGLViewport(page)).png
    initProof=originalCarEvidence(initial)
    if(initProof.originalCarRoiBrightFraction>0.16 && initProof.colorBins>24)break
  }
  await info.attach('original-godot-car-compact.png',{body:initial,contentType:'image/png'})
  expect(initProof.originalCarRoiBrightFraction,'real native Godot source 3D vehicle is visible').toBeGreaterThan(0.16)
  expect(initProof.colorBins,'source vehicle needs varied PBR-lit polygons, not blank slate').toBeGreaterThan(24)
  await canvas.focus()
  await page.keyboard.press('4')
  await page.waitForTimeout(1500)
  const suv=(await captureAnimatedWebGLViewport(page)).png
  const vehicleChange=actualPixelMovement(initial,suv)
  await info.attach('original-godot-car-utility.png',{body:suv,contentType:'image/png'})
  expect(vehicleChange.meanMaxRgbDelta,'actual original 3D shape/paint changes after key 4').toBeGreaterThan(1.0)
  expect(vehicleChange.changedFraction).toBeGreaterThan(0.025)
  await page.keyboard.press('e')
  await page.waitForTimeout(1200)
  const rotated=(await captureAnimatedWebGLViewport(page)).png
  const turn=actualPixelMovement(suv,rotated)
  await info.attach('original-godot-car-15-degree-rotation.png',{body:rotated,contentType:'image/png'})
  await info.attach('real-godot-showroom-chromium-evidence.json',{
    body:Buffer.from(JSON.stringify({qa_fixture:true,context,initProof,vehicleChange,turn,errors},null,2)),
    contentType:'application/json'
  })
  expect(turn.meanMaxRgbDelta,'interactive real 3D turntable must move rendered car pixels').toBeGreaterThan(0.65)
  expect(turn.changedFraction).toBeGreaterThan(0.018)
  // A different source-native LED/studio lighting state must alter actual
  // car pixels, not just a 2D text caption or an unstored UI setting.
  await page.keyboard.press('l')
  await page.waitForTimeout(1400)
  const night=(await captureAnimatedWebGLViewport(page)).png
  const lighting=actualPixelMovement(rotated,night)
  await info.attach('original-godot-car-night-studio.png',{body:night,contentType:'image/png'})
  await info.attach('original-godot-real-lighting-evidence.json',{
    body:Buffer.from(JSON.stringify({lighting,source:'actual standalone Godot World3D lights'},null,2)),
    contentType:'application/json'
  })
  expect(lighting.meanMaxRgbDelta,'night mode must actually change car and stage pixels').toBeGreaterThan(0.45)
  expect(lighting.changedFraction).toBeGreaterThan(0.017)
  expect(errors).toEqual([])
})
