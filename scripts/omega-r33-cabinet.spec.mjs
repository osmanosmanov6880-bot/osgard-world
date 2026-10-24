import {test,expect} from '@playwright/test'
import {PNG} from 'pngjs'
import {captureAnimatedWebGLViewport} from './omega-browser-evidence.mjs'

function sampleLuma(png,xa,xb,ya,yb){
  let sum=0,count=0
  for(let y=Math.floor(png.height*ya);y<Math.floor(png.height*yb);y+=7){
    for(let x=Math.floor(png.width*xa);x<Math.floor(png.width*xb);x+=7){
      const at=(y*png.width+x)*4
      sum+=0.2126*png.data[at]+0.7152*png.data[at+1]+0.0722*png.data[at+2]
      count++
    }
  }
  return sum/Math.max(1,count)
}

test('R33 REAL desktop Tab opens left Godot government dock while the world stays rendered',async({page},info)=>{
  test.setTimeout(200000)
  const faults=[]
  page.on('pageerror',e=>faults.push(e.message))
  const res=await page.goto('/index.html',{waitUntil:'domcontentloaded',timeout:30000})
  expect(res?.status()).toBe(200)
  await expect(page.locator('#canvas')).toBeVisible()
  await page.waitForFunction(()=>document.querySelector('#status')===null,null,{timeout:115000})
  await page.waitForTimeout(600)
  const before=PNG.sync.read((await captureAnimatedWebGLViewport(page)).png)
  // Real keyboard event to the actual focused WebGL runtime, not a simulated UI.
  // Continuously painted WebGL is never DOM-stable for locator.click().
  // Use a trusted real mouse event without waiting for animation stability.
  await page.mouse.click(680,380)
  await page.keyboard.press('Tab')
  await page.waitForTimeout(700)
  const screenshot=(await captureAnimatedWebGLViewport(page)).png
  const after=PNG.sync.read(screenshot)
  const leftBefore=sampleLuma(before,0.06,0.38,0.23,0.78)
  const leftAfter=sampleLuma(after,0.06,0.38,0.23,0.78)
  const rightBefore=sampleLuma(before,0.60,0.91,0.23,0.78)
  const rightAfter=sampleLuma(after,0.60,0.91,0.23,0.78)
  await info.attach('R33-actual-Godot-open-governor.png',{body:screenshot,contentType:'image/png'})
  await info.attach('R33-real-cabinet-metrics.json',{body:Buffer.from(JSON.stringify({
    viewport:[after.width,after.height],leftBefore,leftAfter,rightBefore,rightAfter,crashReports:faults
  },null,2)),contentType:'application/json'})
  expect(after.width).toBe(1366)
  expect(after.height).toBe(768)
  expect(leftBefore).toBeGreaterThan(40)
  expect(leftAfter,'left dock must visibly cover most of previous road/building pixels').toBeLessThan(leftBefore*0.75)
  expect(rightAfter,'right side must remain visible instead of becoming a black wall').toBeGreaterThan(Math.max(35,rightBefore*0.34))
  expect(faults).toEqual([])
})
