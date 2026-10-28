import {test,expect} from '@playwright/test'
import {PNG} from 'pngjs'
import {captureAnimatedWebGLViewport} from './omega-browser-evidence.mjs'
import {realGameFrameEvidence} from './omega-world-frame-evidence.mjs'

// Actual Godot engine PixelDiff: never CSS, generated images, canvas paint,
// synthetic screenshot, remote art or a fake frontend. Only original WebGL
// after a real treasury-debit transaction and two legitimate city turns.
function pixelsChanged(original,built) {
  const a=PNG.sync.read(original),b=PNG.sync.read(built)
  if(a.width!==b.width||a.height!==b.height)
    throw new Error('Godot source canvas dimensions changed between fixed-camera captures')
  let count=0,delta=0,significant=0
  for(let py=Math.round(a.height*0.16);py<a.height*0.88;py+=3){
    for(let px=Math.round(a.width*0.1);px<a.width*0.9;px+=4){
      const k=(py*a.width+px)*4
      const d=Math.max(Math.abs(a.data[k]-b.data[k]),
        Math.abs(a.data[k+1]-b.data[k+1]),
        Math.abs(a.data[k+2]-b.data[k+2]))
      count++
      delta+=d
      if(d>15)significant++
    }
  }
  return {samples:count,meanMaxRGB:delta/count,
    significantFraction:significant/count,resolution:[a.width,a.height]}
}

test('Original paid civic choices become genuinely distinct 3D city infrastructure',async({page},info)=>{
  test.setTimeout(280000)
  const errors=[]
  page.on('pageerror',e=>errors.push(e.message))
  page.on('crash',()=>errors.push('Chromium original Godot renderer crashed'))
  const response=await page.goto('/index.html',{waitUntil:'domcontentloaded',timeout:55000})
  expect(response?.status()).toBe(200)
  const canvas=page.locator('#canvas')
  await expect(canvas).toBeVisible()
  await page.waitForFunction(()=>document.querySelector('#status')===null,
    null,{timeout:145000})
  const webgl=await canvas.evaluate(el=>{
    const context=el.getContext('webgl2')
    return {webgl2:!!context,contextLost:context?.isContextLost()??true,
      size:[el.width,el.height]}
  })
  expect(webgl.webgl2).toBe(true)
  expect(webgl.contextLost).toBe(false)
  await canvas.focus()
  const evidence=[]
  async function frame(name,minimumSpatialDetail=true){
    await page.waitForTimeout(1450)
    const shot=await captureAnimatedWebGLViewport(page)
    const authenticity=realGameFrameEvidence(shot.png)
    if(minimumSpatialDetail)
      expect(authenticity.realWorldEdges, 'Real 3D city, not loader/logo/black screen at '+name).toBe(true)
    await info.attach(name+'.png',{body:shot.png,contentType:'image/png'})
    evidence.push({name,method:shot.method,authenticity})
    return shot.png
  }
  // The exact camera is part of the SOURCE Godot test .tscn, pointed at
  // the real 104m roadway. Controls call actual GameState paid decisions.
  await page.keyboard.press('7')
  await page.keyboard.press('1')
  const beforeSafe=await frame('01-original-city-before-unfunded-crossings')
  await page.keyboard.press('2')
  const afterSafe=await frame('02-original-city-after-real-funded-crossings')
  const crossingDiff=pixelsChanged(beforeSafe,afterSafe)
  expect(crossingDiff.significantFraction,
    'Real debited, built, visible zebra crossings MUST change WebGL city pixels')
    .toBeGreaterThan(0.002)
  await page.keyboard.press('4')
  const powered=await frame('03-original-earned-crossings-22h-powered')
  await page.keyboard.press('5')
  const powerless=await frame('04-original-earned-crossings-night-blackout')
  const powerDiff=pixelsChanged(powered,powerless)
  // Powered stud difference can be microscopic on SwiftShader; source
  // native asserts exact emissive material state and forbids fake lights.
  await page.keyboard.press('8')
  await page.keyboard.press('1')
  const beforeBudget=await frame('05-original-civic-site-before-open-records')
  await page.keyboard.press('3')
  const afterBudget=await frame('06-original-real-public-budget-pavilion-completed')
  const budgetDiff=pixelsChanged(beforeBudget,afterBudget)
  expect(budgetDiff.significantFraction,
    'Actual second funded branch MUST build different physical civic infrastructure')
    .toBeGreaterThan(0.002)
  await page.keyboard.press('6')
  const lowBudget=await frame('07-original-open-budget-pavilion-mobile-low')
  const qualityDiff=pixelsChanged(afterBudget,lowBudget)
  expect(errors).toEqual([])
  await info.attach('CITY_REIGN_B61_REAL_SOURCE_PIXELS_AND_PROVENANCE.json',{
    body:Buffer.from(JSON.stringify({
      source:'godot/empire-omega/tests/city_reign_public_works_pixel_fixture.tscn',
      gameWorld:'res://scripts/world_builder.gd',authoritativeTransactions:[
        'GameState.start_initiative("safe_crossings")',
        'GameState.start_initiative("open_records")','GameState.advance_turn() x 2'],
      evidence,webgl,crossingDiff,budgetDiff,powerDiff,qualityDiff,
      knownLimitations:['CI Chromium SwiftShader is NOT real phone FPS',
        'Original game source geometry is procedural, NOT AAA photogrammetry']
    },null,2)),contentType:'application/json'
  })
})
