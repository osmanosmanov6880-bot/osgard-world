// Read ACTUAL public, SSH-served Godot WebGL2 pixels. No simulated CSS/render.
import {chromium} from '@playwright/test'
import {PNG} from 'pngjs'
import fs from 'node:fs/promises'
import path from 'node:path'
const LIVE = 'https://osgard.world/games/city-reign-preview/'
const SOURCE = process.env.CITY_REIGN_SOURCE_SHA
const OUT = process.env.CITY_REIGN_EVIDENCE_DIR || 'city-reign-preview-evidence'
if (!/^[0-9a-f]{40}$/.test(SOURCE ?? '')) throw Error('Missing exact source SHA')
await fs.mkdir(OUT,{recursive:true})
const browser=await chromium.launch({headless:true,args:[
  '--enable-webgl','--ignore-gpu-blocklist','--use-gl=angle','--use-angle=gl'
]})
const results=[]
try{
  for(const viewport of [{width:1366,height:768},{width:390,height:844}]){
    const context=await browser.newContext({viewport,deviceScaleFactor:1,
      locale:'ru-RU',ignoreHTTPSErrors:false,serviceWorkers:'block'})
    const page=await context.newPage()
    const errors=[]
    page.on('pageerror',e=>errors.push(String(e).slice(0,300)))
    page.on('crash',()=>errors.push('Chromium source game renderer crashed'))
    const res=await page.goto(LIVE+'?release='+SOURCE.slice(0,12),
      {waitUntil:'domcontentloaded',timeout:60000})
    if(res?.status()!==200)throw Error('Published game HTML is not HTTP 200')
    const canvas=page.locator('#canvas')
    await canvas.waitFor({state:'visible',timeout:65000})
    await page.waitForFunction(()=>document.querySelector('#status')===null,
      null,{timeout:150000})
    await page.waitForTimeout(2700)
    const webgl=await canvas.evaluate(el=>{
      const ctx=el.getContext('webgl2')
      return {enabled:!!ctx,lost:ctx?.isContextLost()??true,pixels:[el.width,el.height]}
    })
    if(!webgl.enabled||webgl.lost||webgl.pixels[0]<300||webgl.pixels[1]<300)
      throw Error('Not original running Godot WebGL2 canvas: '+JSON.stringify(webgl))
    const png=await canvas.screenshot({timeout:35000})
    const image=PNG.sync.read(png)
    let count=0,lit=0,edges=0,illumination=0
    for(let y=Math.floor(image.height*.1);y<image.height*.9;y+=4){
      for(let x=Math.floor(image.width*.07);x<image.width*.93;x+=5){
        const offset=(y*image.width+x)*4
        const R=image.data[offset],G=image.data[offset+1],B=image.data[offset+2]
        illumination+=(R+G+B)/3
        if(Math.max(R,G,B)>27)lit++
        if(x>=5){
          const prev=offset-20
          const delta=Math.max(Math.abs(R-image.data[prev]),
            Math.abs(G-image.data[prev+1]),Math.abs(B-image.data[prev+2]))
          if(delta>24)edges++
        }
        count++
      }
    }
    const proof={viewport,webgl,pixels:[image.width,image.height],
      meanLight:illumination/count,nonblackFraction:lit/count,
      sceneEdgesFraction:edges/count,jsErrors:errors}
    const filename='CITY_REIGN_PUBLIC_'+SOURCE.slice(0,8)+'_'+viewport.width+'x'+viewport.height+'.png'
    await fs.writeFile(path.join(OUT,filename),png)
    if(proof.nonblackFraction<0.16||proof.sceneEdgesFraction<0.003||proof.meanLight<12)
      throw Error('Original published gameplay is blank or splash-only: '+JSON.stringify(proof))
    if(errors.length)throw Error('Published WebGL page exceptions: '+errors.join(' | '))
    results.push(proof)
    await context.close()
  }
  const report={result:'PASS',source_commit:SOURCE,public_url:LIVE,
    engine:'Original Godot 4.4.1 WebGL2',
    hardware_note:'Software renderer CI, NOT physical PC/iPhone/Android FPS',
    actual_public_game_frames:results}
  await fs.writeFile(path.join(OUT,'PUBLIC-WEBGL-DESKTOP-MOBILE.json'),
    JSON.stringify(report,null,2)+'\n')
  console.log('CITY REIGN PUBLIC SOURCE WEBGL PASS',JSON.stringify(report))
}finally{
  await browser.close()
}
