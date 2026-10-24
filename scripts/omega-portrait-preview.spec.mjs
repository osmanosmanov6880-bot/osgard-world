import { test, expect } from '@playwright/test'
import { PNG } from 'pngjs'

// Verify genuine independently exported WebGL, not a CSS mock. The original
// R11 Chromium trace had black rows 0..311 and 540..843 on a 390x844 phone.
function measureRealScenePng(raw) {
  const png=PNG.sync.read(raw)
  let activeRows=0,longest=0,continuous=0
  const band=(start,end)=>{
    let active=0,rows=0
    for(let y=start;y<end;y+=2) {
      let alive=0,visited=0
      for(let x=Math.floor(png.width*0.25);x<Math.floor(png.width*0.75);x+=8) {
        const i=(y*png.width+x)*4
        visited++
        if(Math.max(png.data[i],png.data[i+1],png.data[i+2])>28)alive++
      }
      if(alive>=Math.max(2,Math.round(visited*0.18)))active++
      rows++
    }
    return rows===0?0:active/rows
  }
  for(let y=0;y<png.height;y+=2) {
    let alive=0,visited=0
    for(let x=Math.floor(png.width*0.25);x<Math.floor(png.width*0.75);x+=8) {
      const i=(y*png.width+x)*4
      visited++
      if(Math.max(png.data[i],png.data[i+1],png.data[i+2])>28)alive++
    }
    if(alive>=Math.max(2,Math.round(visited*0.18))) {
      activeRows++;continuous++;longest=Math.max(longest,continuous)
    } else continuous=0
  }
  const n=Math.ceil(png.height/2)
  return {width:png.width,height:png.height,
    activeFraction:activeRows/n,continuousFraction:longest/n,
    topFraction:band(0,Math.floor(png.height*0.27)),
    bottomFraction:band(Math.floor(png.height*0.73),png.height)}
}

test('REAL Godot 4.4.1 fills the phone, tablet and desktop canvas without black 16:9 bars',async({page},info)=>{
  test.setTimeout(150_000)
  const failures=[]
  page.on('pageerror',err=>failures.push(err.message))
  page.on('crash',()=>failures.push('Browser tab crashed'))
  const res=await page.goto('/index.html',{waitUntil:'domcontentloaded',timeout:30000})
  expect(res?.status()).toBe(200)
  await expect(page.locator('#canvas')).toBeVisible()
  await page.waitForFunction(()=>document.querySelector('#status')===null,null,{timeout:110000})
  const view=await page.locator('#canvas').evaluate(canvas=>{
    const rect=canvas.getBoundingClientRect()
    const gl=canvas.getContext('webgl2')
    return {
      buffer:[canvas.width,canvas.height],
      css:[rect.x,rect.y,rect.width,rect.height],
      viewport:[innerWidth,innerHeight],
      webgl2:!!gl,contextLost:gl?.isContextLost()??true
    }
  })
  expect(view.webgl2).toBe(true)
  expect(view.contextLost).toBe(false)
  expect(view.css[2]).toBeGreaterThan(view.viewport[0]*0.95)
  expect(view.css[3]).toBeGreaterThan(view.viewport[1]*0.95)
  await page.waitForTimeout(700)
  // Viewport screenshot, not locator().screenshot(): a continuously painted
  // native Godot canvas never becomes "stable" for Playwright's locator.
  const png=await page.screenshot({timeout:45000,animations:'disabled'})
  const proof=measureRealScenePng(png)
  await info.attach('actual-godot-world.png',{body:png,contentType:'image/png'})
  await info.attach('actual-godot-screen-coverage.json',{
    body:Buffer.from(JSON.stringify({project:info.project.name,view,proof},null,2)),
    contentType:'application/json'
  })
  expect(proof.activeFraction,'scene needs to occupy >=70% of actual height').toBeGreaterThan(0.70)
  expect(proof.continuousFraction,'road and sky need one connected full-height view').toBeGreaterThan(0.65)
  if(info.project.name.includes('portrait')||info.project.name.includes('phone-320')){
    expect(proof.topFraction,'top 27% cannot be a black bar').toBeGreaterThan(0.50)
    expect(proof.bottomFraction,'bottom 27% cannot be a black bar').toBeGreaterThan(0.50)
  }
  expect(failures).toEqual([])
})
