import {test,expect} from '@playwright/test'
import {captureAnimatedWebGLViewport} from './omega-browser-evidence.mjs'
import {realGameFrameEvidence} from './omega-world-frame-evidence.mjs'

test.use({viewport:{width:390,height:844},deviceScaleFactor:1,hasTouch:true,isMobile:true})

test('R109 genuine 390x844 portrait Godot gameplay world is playable and not a splash image',async({page},info)=>{
  test.setTimeout(210000)
  const faults=[]
  page.on('pageerror',e=>faults.push(e.message))
  page.on('crash',()=>faults.push('Mobile WebGL renderer crashed'))
  const response=await page.goto('/index.html',{waitUntil:'domcontentloaded',timeout:30000})
  expect(response?.status()).toBe(200)
  await expect(page.locator('#canvas')).toBeVisible()
  await page.waitForFunction(()=>document.querySelector('#status')===null,null,{timeout:120000})
  let raw,evidence
  for(let attempt=0;attempt<5;attempt++){
    await page.waitForTimeout(attempt===0?4400:2000)
    raw=(await captureAnimatedWebGLViewport(page)).png
    evidence=realGameFrameEvidence(raw)
    if(evidence.realWorldEdges)break
  }
  await info.attach('r109-native-Godot-390x844-portrait-gameplay.png',{body:raw,contentType:'image/png'})
  await info.attach('r109-actual-mobile-canvas-evidence.json',{
    body:Buffer.from(JSON.stringify({viewport:page.viewportSize(),render:evidence,exceptions:faults},null,2)),
    contentType:'application/json'
  })
  expect(page.viewportSize()).toEqual({width:390,height:844})
  expect(evidence.realWorldEdges,'require actual mobile Godot city meshes, not loader or painted mockup').toBe(true)
  expect(faults).toEqual([])
  await page.touchscreen.tap(198,418)
  await page.waitForTimeout(300)
  await expect(page.locator('#canvas')).toBeVisible()
  expect(faults).toEqual([])
})
