import {test,expect} from '@playwright/test'
import {captureAnimatedWebGLViewport} from './omega-browser-evidence.mjs'
import {realGameFrameEvidence} from './omega-world-frame-evidence.mjs'

// Mandatory release-screen test for ORIGINAL playable main.tscn exported by
// official Godot Web template. No source replacement with cinematic test
// camera, no DOM image mock, no generated fake screenshots or remote media.
test('CITY REIGN real gameplay WebGL2 runs with genuine world pixels at desktop and phone',async({page,request},info)=>{
  test.setTimeout(285000)
  const targetSHA=process.env.CITY_REIGN_PREVIEW_SOURCE_SHA
  expect(targetSHA).toMatch(/^[a-f0-9]{40}$/)
  const releaseResponse=await request.get('/release.json')
  expect(releaseResponse.status()).toBe(200)
  const manifest=await releaseResponse.json()
  expect(manifest.source_commit).toBe(targetSHA)
  expect(manifest.main_scene).toBe('res://scenes/main.tscn')
  expect(manifest.channel).toBe('public-technical-preview')
  expect(manifest.commercial_aaa_release).toBe(false)
  const errors=[]
  page.on('pageerror',e=>errors.push(String(e.message).slice(0,250)))
  page.on('crash',()=>errors.push('Godot WebGL renderer crashed'))
  const response=await page.goto('/index.html',{waitUntil:'domcontentloaded',timeout:60000})
  expect(response?.status()).toBe(200)
  await page.waitForFunction(()=>document.querySelector('#status')===null,null,
    {timeout:155000})
  const canvas=page.locator('#canvas')
  await expect(canvas).toBeVisible({timeout:15000})
  const gl=await canvas.evaluate(el=>{
    const ctx=el.getContext('webgl2')
    return {webgl2:!!ctx,contextLost:ctx?.isContextLost()??true,
      width:el.width,height:el.height}
  })
  expect(gl.webgl2,'Actual Godot must create its WebGL2 context').toBe(true)
  expect(gl.contextLost,'Godot context cannot be lost').toBe(false)
  await canvas.focus()
  const captures=[]
  for(const {name,width,height} of [
    {name:'genuine-desktop-original-main',width:1366,height:768},
    {name:'genuine-portrait-original-main',width:390,height:844}
  ]){
    await page.setViewportSize({width,height})
    let proof=null,png=null
    for(let attempt=0;attempt<6;attempt++){
      await page.waitForTimeout(attempt===0?2100:1250)
      png=(await captureAnimatedWebGLViewport(page)).png
      proof=realGameFrameEvidence(png)
      if(proof.realWorldEdges)break
    }
    expect(proof.realWorldEdges,
      'This MUST be actual playable 3D city pixels, not engine logo or flat loader at '+name)
      .toBe(true)
    captures.push({name,viewport:[width,height],proof,renderedOriginalGodot:true})
    await info.attach(name+'.png',{body:png,contentType:'image/png'})
  }
  expect(errors).toEqual([])
  await info.attach('CITY_REIGN_REAL_GAME_PREVIEW_SOURCE.json',{
    body:Buffer.from(JSON.stringify({
      exactSourceSHA:targetSHA,mainScene:'res://scenes/main.tscn',
      engine:'Godot 4.4.1',actualWebGL2:gl,tests:captures,
      knownLimits:['software-browser pass is not a physical phone GPU FPS',
        'procedural Godot scene is a technical preview, NOT commercial AAA'],
      errors
    },null,2)),
    contentType:'application/json'
  })
})
