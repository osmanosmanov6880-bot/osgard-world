import {test,expect} from '@playwright/test'
import {PNG} from 'pngjs'
import {captureAnimatedWebGLViewport} from './omega-browser-evidence.mjs'
import {realGameFrameEvidence} from './omega-world-frame-evidence.mjs'

function meaningfulDifference(a,b){
  // Equal-normalized sampling: original Chromium may return 960x540 or 1366x768
  // on different authentic CDP capture paths. Do not compare pixel indexes.
  let sum=0,n=0
  for(let y=2;y<38;y++)for(let x=2;x<58;x++){
    const pixel=(im)=>{
      const xx=Math.min(im.width-1,Math.floor((x+0.5)*im.width/60))
      const yy=Math.min(im.height-1,Math.floor((y+0.5)*im.height/40))
      const at=(yy*im.width+xx)*4
      return [im.data[at],im.data[at+1],im.data[at+2]]
    }
    const c=pixel(a),d=pixel(b)
    for(let k=0;k<3;k++){sum+=Math.abs(c[k]-d[k]);n++}
  }
  return sum/n
}

test('R90 live Godot cabinet opens the signed-off full game-state command screen',async({page},info)=>{
  test.setTimeout(210000)
  const faults=[]
  page.on('pageerror',e=>faults.push(e.message))
  page.on('crash',()=>faults.push('Godot WebGL browser crashed'))
  const response=await page.goto('/index.html',{waitUntil:'domcontentloaded',timeout:30000})
  expect(response?.status()).toBe(200)
  await expect(page.locator('#canvas')).toBeVisible()
  await page.waitForFunction(()=>document.querySelector('#status')===null,null,{timeout:115000})
  // Loading splash is insufficient: require real sky + road screen evidence.
  let beforeRaw,beforeEvidence
  for(let attempt=0;attempt<5;attempt++){
    await page.waitForTimeout(attempt===0?4200:2000)
    beforeRaw=(await captureAnimatedWebGLViewport(page)).png
    beforeEvidence=realGameFrameEvidence(beforeRaw)
    if(beforeEvidence.realWorldEdges)break
  }
  expect(beforeEvidence.realWorldEdges,'render live Godot 3D, never loader splash').toBe(true)
  const before=PNG.sync.read(beforeRaw)
  await info.attach('r90-real-city-before-tab.png',{body:beforeRaw,contentType:'image/png'})
  await page.mouse.click(Math.floor(page.viewportSize().width/2),Math.floor(page.viewportSize().height/2))
  await page.keyboard.press('Tab')
  await page.waitForTimeout(1400)
  const afterRaw=(await captureAnimatedWebGLViewport(page)).png
  const after=PNG.sync.read(afterRaw)
  const difference=meaningfulDifference(before,after)
  await info.attach('r90-actual-command-center-after-tab.png',{body:afterRaw,contentType:'image/png'})
  await info.attach('r90-live-command-center-evidence.json',{body:Buffer.from(JSON.stringify({
    viewport:page.viewportSize(),before:[before.width,before.height],
    after:[after.width,after.height],meanRgbDifference:difference,
    beforeEvidence,exceptions:faults
  },null,2)),contentType:'application/json'})
  expect(difference,'actual Godot 3D command UI must replace driving HUD on Tab').toBeGreaterThan(9)
  expect(faults).toEqual([])
  await page.keyboard.press('Tab')
  await page.waitForTimeout(650)
  expect(await page.locator('#canvas').isVisible()).toBe(true)
})
