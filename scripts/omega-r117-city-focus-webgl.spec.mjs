import {test,expect} from '@playwright/test'
import {PNG} from 'pngjs'
import {captureAnimatedWebGLViewport} from './omega-browser-evidence.mjs'
import {realGameFrameEvidence} from './omega-world-frame-evidence.mjs'

// Prove that F9 actually changes the original Godot 3D governance screen.
// Unlike a DOM mock, the only browser UI is an exported native WebGL canvas.
function sampledDifference(a,b){
  const one=PNG.sync.read(a),two=PNG.sync.read(b)
  const channel=(img,x,y,k)=>{
    const px=Math.min(img.width-1,Math.floor((x+0.5)*img.width/56))
    const py=Math.min(img.height-1,Math.floor((y+0.5)*img.height/36))
    return img.data[(py*img.width+px)*4+k]
  }
  let sum=0,count=0
  for(let y=3;y<33;y++)for(let x=2;x<54;x++)for(let k=0;k<3;k++){
    sum+=Math.abs(channel(one,x,y,k)-channel(two,x,y,k))
    count++
  }
  return sum/count
}

test('R117 original native Godot F9 city focus expands AND restores live 3D dashboard',async({page},info)=>{
  test.setTimeout(220000)
  const faults=[]
  page.on('pageerror',e=>faults.push(e.message))
  page.on('crash',()=>faults.push('Actual Godot WASM renderer crashed'))
  const response=await page.goto('/index.html',{waitUntil:'domcontentloaded',timeout:30000})
  expect(response?.status()).toBe(200)
  await expect(page.locator('#canvas')).toBeVisible()
  await page.waitForFunction(()=>document.querySelector('#status')===null,null,{timeout:120000})

  let world,evidence
  for(let attempt=0;attempt<5;attempt++){
    await page.waitForTimeout(attempt===0?4200:1600)
    world=(await captureAnimatedWebGLViewport(page)).png
    evidence=realGameFrameEvidence(world)
    if(evidence.realWorldEdges)break
  }
  expect(evidence.realWorldEdges,'actual native 3D city must be running, not a still image').toBe(true)
  await page.mouse.click(Math.floor(page.viewportSize().width/2),Math.floor(page.viewportSize().height/2))
  await page.keyboard.press('Tab')
  await page.waitForTimeout(1400)
  const normal=(await captureAnimatedWebGLViewport(page)).png
  await info.attach('r117-original-governance-before-focus.png',{body:normal,contentType:'image/png'})

  await page.keyboard.press('F9')
  await page.waitForTimeout(850)
  const focused=(await captureAnimatedWebGLViewport(page)).png
  await info.attach('r117-actual-full-width-Godot-city-focus.png',{body:focused,contentType:'image/png'})

  await page.keyboard.press('F9')
  await page.waitForTimeout(750)
  const restored=(await captureAnimatedWebGLViewport(page)).png
  await info.attach('r117-restored-original-six-city-metrics.png',{body:restored,contentType:'image/png'})

  const enterDelta=sampledDifference(normal,focused)
  const exitDelta=sampledDifference(focused,restored)
  await info.attach('r117-native-city-focus-pixel-differences.json',{
    body:Buffer.from(JSON.stringify({engine:'Godot 4.4.1 authentic WebGL WASM',
      beforeSize:[PNG.sync.read(normal).width,PNG.sync.read(normal).height],
      focusSize:[PNG.sync.read(focused).width,PNG.sync.read(focused).height],
      enterMeanRgbDifference:enterDelta,exitMeanRgbDifference:exitDelta,
      webglScene:evidence,errors:faults},null,2)),
    contentType:'application/json'
  })
  expect(enterDelta,'F9 must visibly COLLAPSE original sidebar cards in native Godot').toBeGreaterThan(6)
  expect(exitDelta,'F9 must visibly RESTORE the original governance cards').toBeGreaterThan(6)
  expect(faults).toEqual([])
  await expect(page.locator('#canvas')).toBeVisible()
})
