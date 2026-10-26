import {test,expect} from '@playwright/test'

test('R109 capture genuine Chromium-host frame telemetry on running Godot WebGL',async({page},info)=>{
  test.setTimeout(200000)
  const faults=[]
  page.on('pageerror',e=>faults.push(e.message))
  page.on('crash',()=>faults.push('WebGL page crashed'))
  const response=await page.goto('/index.html',{waitUntil:'domcontentloaded',timeout:30000})
  expect(response?.status()).toBe(200)
  await expect(page.locator('#canvas')).toBeVisible()
  await page.waitForFunction(()=>document.querySelector('#status')===null,null,{timeout:120000})
  await page.waitForTimeout(2000)
  const report=await page.evaluate(async()=>{
    const canvas=document.querySelector('#canvas')
    const metrics={
      source:'Chromium requestAnimationFrame host scheduling, NOT Godot engine physics ticks or verified GPU-only fps',
      viewport:{width:innerWidth,height:innerHeight},
      canvas:{
        cssWidth:canvas?.getBoundingClientRect().width??0,
        cssHeight:canvas?.getBoundingClientRect().height??0,
        backingWidth:canvas?.width??0,
        backingHeight:canvas?.height??0,
      },
      visibility:document.visibilityState,
    }
    const intervals=[]
    let previous
    await new Promise(resolve=>{
      let frames=0
      const run=stamp=>{
        if(previous!==undefined)intervals.push(stamp-previous)
        previous=stamp
        frames++
        if(frames<125)requestAnimationFrame(run)
        else resolve()
      }
      requestAnimationFrame(run)
    })
    const ordered=intervals.filter(Number.isFinite).sort((a,b)=>a-b)
    const at=q=>ordered[Math.min(ordered.length-1,Math.floor(q*(ordered.length-1)))]
    return {...metrics,samples:ordered.length,
      medianRafIntervalMs:at(0.50),p95RafIntervalMs:at(0.95),
      p99RafIntervalMs:at(0.99),
      estimatedHostFPS:at(0.50)>0?1000/at(0.50):null}
  })
  await info.attach('r109-measured-godot-webgl-host-frame-telemetry.json',{
    body:Buffer.from(JSON.stringify({...report,exceptions:faults},null,2)),
    contentType:'application/json'
  })
  expect(report.visibility).toBe('visible')
  expect(report.samples).toBeGreaterThan(100)
  expect(report.canvas.backingWidth).toBeGreaterThan(300)
  expect(report.canvas.backingHeight).toBeGreaterThan(200)
  expect(report.medianRafIntervalMs).toBeGreaterThan(0)
  expect(Number.isFinite(report.p95RafIntervalMs)).toBe(true)
  // Actual framerate is captured for human/hardware review only;
  // never treat software-rendered CI timings as real player hardware FPS.
  expect(faults).toEqual([])
})
