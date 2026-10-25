import {test,expect} from '@playwright/test'
import {PNG} from 'pngjs'
import {browserTouchPoint} from './omega-mobile-touch-geometry.mjs'
import {captureAnimatedWebGLViewport} from './omega-browser-evidence.mjs'
import {PHYSICS_SCHEMA,verifyRealVehicleMovement} from './omega-vehicle-physics-proof.mjs'

function edgeDeviation(png,from,to) {
  let sum=0,sumSq=0,count=0
  for(let y=Math.floor(png.height*from);y<Math.ceil(png.height*to);y+=4) {
    for(let x=Math.floor(png.width*0.05);x<Math.floor(png.width*0.95);x+=5) {
      const i=(y*png.width+x)*4
      const v=0.2126*png.data[i]+0.7152*png.data[i+1]+0.0722*png.data[i+2]
      sum+=v;sumSq+=v*v;count++
    }
  }
  return count?Math.sqrt(Math.max(0,sumSq/count-(sum/count)**2)):0
}

async function latestPhysics(page) {
  return page.evaluate(()=>{
    const v=window.__omegaRealVehicleQAv1
    return v ? JSON.parse(JSON.stringify(v)) : null
  })
}
test('unpublished original Godot R70: drive 2m, rotate car and grow odometer, never accept fake pixels',async({page},info)=>{
  test.setTimeout(300_000)
  const errors=[]
  page.on('pageerror',e=>errors.push(e.message))
  page.on('crash',()=>errors.push('real Chromium renderer crashed'))

  const touch=info.project.name.startsWith('touch')
  const response=await page.goto('/index.html?omega_real_vehicle_qa=r70',{
    waitUntil:'domcontentloaded',timeout:30000
  })
  expect(response?.status()).toBe(200)
  await expect(page.locator('canvas#canvas')).toBeVisible()
  await page.waitForFunction(()=>document.querySelector('#status')===null,null,{timeout:125000})
  const viewport=await page.locator('canvas#canvas').evaluate(canvas=>({
    webgl:!!canvas.getContext('webgl2'),
    contextLost:canvas.getContext('webgl2')?.isContextLost()??true,
    width:canvas.width,height:canvas.height
  }))
  expect(viewport.webgl,'original live Godot WebGL2 runtime').toBe(true)
  expect(viewport.contextLost).toBe(false)

  // The old CI reached an empty #status and gray #242424 WebGL canvas
  // while original WorldBuilder was still constructing the city. Require
  // an independent opt-in marker emitted AFTER main.gd finishes _ready().
  // On failure retain the last real Godot startup phase, never manufacture
  // car motion or silently waive the production gate.
  try {
    await page.waitForFunction(()=>
      window.__omegaRealVehicleQABoot?.schema==='empire-omega-r70-original-boot-v1' &&
      window.__omegaRealVehicleQABoot?.stage==='ready',
      null,{timeout:60000}
    )
  } catch(error) {
    const diagnostic=await page.evaluate(()=>{
      const canvas=document.querySelector('#canvas')
      return {
        boot:window.__omegaRealVehicleQABoot??null,
        vehicle:window.__omegaRealVehicleQAv1??null,
        status:document.querySelector('#status')?.textContent??null,
        canvas:canvas?{width:canvas.width,height:canvas.height}:null,
        url:window.location.pathname,
      }
    }).catch(e=>({diagnostic_error:String(e)}))
    await info.attach('r70-authentic-godot-startup-blocker.json',{
      body:Buffer.from(JSON.stringify({project:info.project.name,
        head:process.env.GITHUB_SHA??'local',diagnostic},null,2)),
      contentType:'application/json'
    })
    throw new Error('Real Godot scene did not complete startup; '+JSON.stringify(diagnostic).slice(0,700)+'; '+String(error))
  }
  await page.waitForFunction(schema=>
    window.__omegaRealVehicleQAv1?.schema===schema,
    PHYSICS_SCHEMA,{timeout:20000}
  )

  const box=await page.locator('canvas#canvas').boundingBox()
  expect(box).toBeTruthy()
  if(touch) {
    const enter=browserTouchPoint(box,'enter_vehicle')
    await page.touchscreen.tap(enter.x,enter.y)
  }else{
    await page.mouse.click(box.x+box.width*0.5,box.y+box.height*0.55)
    await page.keyboard.press('e')
  }
  await page.waitForFunction(()=>window.__omegaRealVehicleQAv1?.driving===true &&
     window.__omegaRealVehicleQAv1?.car_driving===true,null,{timeout:12000})
  const before=await latestPhysics(page)
  let during,after
  if(touch) {
    const cdp=await page.context().newCDPSession(page)
    const gas={...browserTouchPoint(box,'move_forward'),id:0,radiusX:6,radiusY:6}
    const steer={...browserTouchPoint(box,'move_left'),id:1,radiusX:6,radiusY:6}
    try{
      await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[gas,steer]})
      await page.waitForTimeout(850)
      during=await latestPhysics(page)
      await page.waitForTimeout(1200)
      after=await latestPhysics(page)
    }finally{
      await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]}).catch(()=>{})
      await cdp.detach().catch(()=>{})
    }
  }else{
    await page.keyboard.down('w')
    try{
      await page.waitForTimeout(850)
      during=await latestPhysics(page)
      await page.keyboard.down('a')
      await page.waitForTimeout(1200)
      after=await latestPhysics(page)
    }finally{
      await page.keyboard.up('a').catch(()=>{})
      await page.keyboard.up('w').catch(()=>{})
    }
  }

  // Running Godot truth. A large image difference caused by swapping
  // from the #242424 splash to city is NOT evidence of driven kilometres.
  const proof=verifyRealVehicleMovement(before,during,after)
  await info.attach('original-authoritative-godot-drive.json',{
    body:Buffer.from(JSON.stringify({
      game:"EMPIRE Ω",source_commit:process.env.GITHUB_SHA||"local",
      project:info.project.name,viewport,before,during,after,proof
    },null,2)),contentType:'application/json'
  })
  const original=(await captureAnimatedWebGLViewport(page)).png
  const png=PNG.sync.read(original)
  const upper=edgeDeviation(png,0,0.15)
  const lower=edgeDeviation(png,0.9,1)
  await info.attach('original-real-world-after-physical-drive.png',{
    body:original,contentType:'image/png'
  })
  await info.attach('original-frame-authenticity.json',{
    body:Buffer.from(JSON.stringify({
      upperEdgeLumaStd:upper,lowerEdgeLumaStd:lower,
      realWorldPixels:upper>10&&lower>10,
      originalPhysicsProof:proof.real_godot_physics_verified
    },null,2)),contentType:'application/json'
  })
  expect(upper,'Godot loader cannot masquerade as a real city').toBeGreaterThan(10)
  expect(lower,'real road scene must reach the bottom of viewport').toBeGreaterThan(10)
  expect(errors).toEqual([])
})
