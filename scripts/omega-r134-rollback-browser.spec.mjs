import {test,expect} from '@playwright/test'
import {createHash} from 'node:crypto'
import {mkdirSync,writeFileSync} from 'node:fs'
import {join} from 'node:path'
import {captureAnimatedWebGLViewport} from './omega-browser-evidence.mjs'
import {realGameFrameEvidence} from './omega-world-frame-evidence.mjs'

const R87='43ae041e8df52418ca74c02405de9c196b59bd37'
const WASM='e4a43dbae28662b2a68f6136857a94db6695430901515800b9883f6327cb7116'
const PCK='c34d9b717b024bcec43239032d259229181568284186482ecfcd0f28e580fd4e'

test('R134 restored exact original R87 native WebGL actually paints a city and keeps rollback hashes',async({page,request},info)=>{
  test.setTimeout(190000)
  const faults=[]
  page.on('pageerror',error=>faults.push(error.message))
  page.on('crash',()=>faults.push('Real Godot Chromium process crashed'))
  const manifest=await request.get('/release.json',{timeout:12000})
  expect(manifest.status()).toBe(200)
  const installed=await manifest.json()
  expect(installed.source_commit).toBe(R87)
  expect(installed.files['index.wasm']).toBe(WASM)
  expect(installed.files['index.pck']).toBe(PCK)
  expect(Object.keys(installed.files).length).toBe(7)

  // This is the isolated restored R87 game, served over local HTTP with
  // COOP/COEP. Never a remotely published or generated replacement image.
  for(const name of ['index.html','index.js','index.wasm','index.pck']){
    const response=await request.head('/'+name,{timeout:20000})
    expect(response.status(),name+' must be reachable in restored R87').toBe(200)
    const origin=response.headers()
    expect(origin['cross-origin-opener-policy']).toBe('same-origin')
    expect(origin['cross-origin-embedder-policy']).toBe('require-corp')
    expect(origin['cross-origin-resource-policy']).toBe('same-origin')
  }
  const resp=await page.goto('/index.html',{waitUntil:'domcontentloaded',timeout:30000})
  expect(resp?.status()).toBe(200)
  await expect(page.locator('#canvas')).toBeVisible()
  await page.waitForFunction(()=>document.querySelector('#status')===null,
    null,{timeout:120000})
  const viewport=await page.locator('#canvas').evaluate(canvas=>{
    const rect=canvas.getBoundingClientRect()
    const gl=canvas.getContext('webgl2')
    return {webgl2:!!gl,contextLost:gl?.isContextLost()??true,
      width:canvas.width,height:canvas.height,
      css:[rect.width,rect.height],
      viewport:[innerWidth,innerHeight]}
  })
  expect(viewport.webgl2).toBe(true)
  expect(viewport.contextLost).toBe(false)
  expect(viewport.css[0]).toBeGreaterThan(viewport.viewport[0]*0.90)
  expect(viewport.css[1]).toBeGreaterThan(viewport.viewport[1]*0.90)
  let capture=null,world=null
  for(let i=0;i<5;i++){
    await page.waitForTimeout(i===0?2300:1600)
    capture=await captureAnimatedWebGLViewport(page)
    world=realGameFrameEvidence(capture.png)
    if(world.realWorldEdges)break
  }
  expect(world.realWorldEdges,
    'R87 rollback must render a genuine Godot street world, NOT the startup splash').toBe(true)
  expect(world.upperEdgeLumaStd).toBeGreaterThan(10)
  expect(world.lowerEdgeLumaStd).toBeGreaterThan(10)
  expect(faults).toEqual([])
  await info.attach('R134-REALLY-RESTORED-R87-ORIGINAL-GODOT.png',{
    body:capture.png,contentType:'image/png'
  })
  const record={
    schema:'empire-omega-r134-r87-chromium-real-recovery-v1',
    project:info.project.name,
    git_manifest_source_commit:installed.source_commit,
    rollback_wasm_sha256:WASM,
    rollback_pck_sha256:PCK,
    actual_render_method:capture.method,
    actual_rendered_png_sha256:createHash('sha256').update(capture.png).digest('hex'),
    real_original_godot_webgl2:viewport.webgl2&&!viewport.contextLost,
    world,viewport,page_errors:faults,
    independent_production_https: false,
    production_rollback_verified:false,
    real_physical_iphone_android_tested:false,
    production_authorized:false
  }
  const evidence=process.env.R134_EVIDENCE_DIR
  expect(evidence,'R134 actual browser provenance destination required').toBeTruthy()
  mkdirSync(evidence,{recursive:true})
  writeFileSync(join(evidence,info.project.name+'.json'),JSON.stringify(record,null,2)+'\n')
  await info.attach('R134-REALISED-RECOVERY-RENDER.json',{
    body:Buffer.from(JSON.stringify(record,null,2)),contentType:'application/json'
  })
})
