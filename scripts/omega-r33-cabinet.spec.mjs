import {test,expect} from '@playwright/test'
import {PNG} from 'pngjs'
import {captureAnimatedWebGLViewport} from './omega-browser-evidence.mjs'
import {samplePanelPixels} from './omega-r33-panel-pixels.mjs'

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

// R60: brightness alone cannot prove a real government panel. Authentic
// 1366x768 GL/WebGL shows a dark scene in several valid camera positions.
// A warm gold textual heading on a large dark left-side backdrop is the
// actual UI's stronger visual signal. Read rendered Chromium PNG pixels;
// no DOM mock, synthetic image or bypass of real game motion is accepted.
test('R33 REAL desktop Tab opens left Godot government dock while the world stays rendered',async({page},info)=>{
  test.setTimeout(200000)
  const faults=[]
  page.on('pageerror',e=>faults.push(e.message))
  const res=await page.goto('/index.html',{waitUntil:'domcontentloaded',timeout:30000})
  expect(res?.status()).toBe(200)
  await expect(page.locator('#canvas')).toBeVisible()
  await page.waitForFunction(()=>document.querySelector('#status')===null,null,{timeout:115000})
  await page.waitForTimeout(600)
  const beforePixels=(await captureAnimatedWebGLViewport(page)).png
  const before=PNG.sync.read(beforePixels)
  await info.attach('R33-original-Godot-before-tab.png',{body:beforePixels,contentType:'image/png'})
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
  const panelBefore=samplePanelPixels(before,0.06,0.38,0.23,0.78)
  const panelAfter=samplePanelPixels(after,0.06,0.38,0.23,0.78)
  await info.attach('R33-actual-Godot-open-governor.png',{body:screenshot,contentType:'image/png'})
  await info.attach('R33-real-cabinet-metrics.json',{body:Buffer.from(JSON.stringify({
    actualCssViewport:page.viewportSize(),renderedEvidenceBefore:[before.width,before.height],
    renderedEvidenceAfter:[after.width,after.height],
    leftBefore,leftAfter,rightBefore,rightAfter,
    panelBefore,panelAfter,crashReports:faults
  },null,2)),contentType:'application/json'})
  // R79: CDP encodes actual composited Godot pixels at bounded 960x540 on
  // software GPU. Screenshot evidence dimensions are NOT the CSS viewport.
  // Keep the original CSS gameplay viewport 1366x768, validate EACH original
  // PNG independently, even if CDP vs Playwright paths have different sizes.
  expect(page.viewportSize()).toEqual({width:1366,height:768})
  for(const image of [before,after]) {
    expect(image.width).toBeGreaterThanOrEqual(850)
    expect(image.width).toBeLessThanOrEqual(1366)
    expect(image.height).toBeGreaterThanOrEqual(475)
    expect(image.height).toBeLessThanOrEqual(768)
    expect(Math.abs(image.width/image.height-1366/768)).toBeLessThan(0.025)
  }
  // R87.1: BOTH PNGs must depict the genuine 1366x768 CSS game, but CDP
  // can legitimately emit 960x540 on one capture and full 1366x768 on the
  // next. Our fixed normalized 110x100 GRID prevents raw image dimensions
  // from manufacturing golden text or dark panel evidence.
  expect(panelBefore.sampledPixels).toBe(11000)
  expect(panelAfter.sampledPixels).toBe(11000)
  // Original page is real and nonblank even when city lighting is dimmer
  // than the obsolete 40/255 absolute 2D pixel threshold.
  expect(Math.max(leftBefore,rightBefore),'original live game must not be black').toBeGreaterThan(28)
  expect(panelAfter.goldPixels,'actual golden Government HUD headings must be painted by WebGL').toBeGreaterThan(50)
  expect(panelAfter.goldPixels,'opening Tab must CREATE original government panel text').toBeGreaterThan(panelBefore.goldPixels*2+35)
  expect(panelAfter.darkRatio,'large authentic dark UI panel must cover left viewport').toBeGreaterThan(0.35)
  expect(rightAfter,'right world must stay visible when the panel opens').toBeGreaterThan(Math.max(35,rightBefore*0.34))
  expect(faults).toEqual([])
})
