/**
 * ZION-030 v34: executable hardware benchmark for a desktop with a real GPU.
 *
 * Requirements: Node 22+, npm ci, installed Google Chrome, visible desktop session.
 * OSGARD_GPU_BENCH_URL=https://osgard.world/games/zion-9/queue/ZION-030/index.html \
 *   node scripts/zion-v34-hardware-benchmark.mjs
 *
 * A software renderer (SwiftShader/llvmpipe), unknown renderer or insufficient
 * frames fails closed. This intentionally cannot produce fake AAA hardware evidence.
 */
import {chromium} from '@playwright/test'
import fs from 'node:fs/promises'
import {existsSync,readdirSync,readFileSync} from 'node:fs'
import {execFileSync} from 'node:child_process'
import path from 'node:path'

// Browser renderer strings alone are not independent hardware attestation.
// Check the machine's actual graphics devices or driver before certifying FPS.
function attestPhysicalGpu(){
  const devices=[];
  const accepted=/nvidia|geforce|quadro|amd|radeon|intel|apple gpu|adreno|mali/i;
  const rejected=/microsoft basic|remote display|swiftshader|llvmpipe|virtualbox|vmware svga|software/i;
  const run=(bin,args,timeout=5500)=>{
    try{return execFileSync(bin,args,{encoding:'utf8',timeout,stdio:['ignore','pipe','ignore']})}
    catch(_){return ''}
  };
  if(process.platform==='linux'){
    const nvidia=run('nvidia-smi',['--query-gpu=name','--format=csv,noheader']);
    for(const name of nvidia.split(/\r?\n/).map(x=>x.trim()).filter(Boolean))
      if(accepted.test(name)&&!rejected.test(name))devices.push('NVIDIA driver: '+name);
    if(existsSync('/dev/dri'))for(const name of readdirSync('/dev/dri')){
      if(!/^renderD[0-9]+$/.test(name))continue;
      try{
        const vendor=readFileSync('/sys/class/drm/'+name+'/device/vendor','utf8').trim().toLowerCase();
        if(['0x10de','0x1002','0x8086','0x106b','0x13b5','0x5143'].includes(vendor))
          devices.push('DRM render node '+name+', PCI vendor '+vendor);
      }catch(_){}
    }
  }else if(process.platform==='win32'){
    const lines=run('powershell.exe',['-NoProfile','-Command',
      '(Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name)']);
    for(const name of lines.split(/\r?\n/).map(x=>x.trim()).filter(Boolean))
      if(accepted.test(name)&&!rejected.test(name))devices.push('Windows GPU driver: '+name);
  }else if(process.platform==='darwin'){
    const out=run('system_profiler',['SPDisplaysDataType'],9000);
    for(const line of out.split(/\r?\n/)){
      const m=line.match(/Chipset Model:\s*(.+)/i);
      if(m&&accepted.test(m[1])&&!rejected.test(m[1]))devices.push('macOS GPU: '+m[1].trim());
    }
  }
  return {available:devices.length>0,platform:process.platform,devices,
    method:'OS/driver device enumeration independent of WebGL renderer text'};
}


const url=process.env.OSGARD_GPU_BENCH_URL||
  'https://osgard.world/games/zion-9/queue/ZION-030/index.html'
const duration=Number(process.env.OSGARD_BENCH_DURATION_MS||15000)
const scenario=process.env.OSGARD_BENCH_SCENARIO||'high-day'
if(!['high-day','high-rain-night','eco-rain'].includes(scenario))
  throw Error('Unrecognized ZION hardware scenario: '+scenario)
if(!Number.isFinite(duration)||duration<8000||duration>60000)
  throw Error('OSGARD_BENCH_DURATION_MS must be between 8000 and 60000')
const maxFrameP95=process.env.OSGARD_MAX_FRAME_P95_MS?
  Number(process.env.OSGARD_MAX_FRAME_P95_MS):null
const requireGPU=process.env.OSGARD_REQUIRE_HARDWARE_GPU!=='0'
const chromePath=process.env.OSGARD_CHROME_PATH
let browser
try{
  browser=await chromium.launch({
    headless:process.env.OSGARD_HEADLESS==='1'?true:false,
    ...(chromePath?{executablePath:chromePath}:{channel:'chrome'}),
    args:['--enable-gpu-rasterization','--enable-zero-copy','--ignore-gpu-blocklist']
  })
  const page=await browser.newPage({
    viewport:{width:1600,height:900},
    deviceScaleFactor:1
  })
  const errors=[]
  page.on('pageerror',e=>errors.push(e.message))
  await page.goto(url,{waitUntil:'domcontentloaded',timeout:60000})
  await page.waitForFunction(()=>window.__ZION030_OPEN_CITY__?.state()?.ready,
    null,{timeout:45000})
  const initial=await page.evaluate(()=>window.__ZION030_OPEN_CITY__.state())
  if(initial.atelier?.version!=='34.0')
    throw Error('Requested URL does not serve ZION-030 v34. Deploy v34 before GPU measurement.')
  await page.locator('#oc-entry').click()
  await page.locator('#oc-start-play').click()
  await page.locator('#oc-shell').waitFor({state:'visible'})
  // Keep the world and camera authentic: switch the actual in-game controls.
  if(scenario!=='high-day')await page.locator('#oc-rain').click()
  if(scenario==='high-rain-night')await page.locator('#oc-time').click()
  if(scenario==='eco-rain')await page.locator('#oc-quality').click()
  const before=await page.evaluate(()=>window.__ZION030_OPEN_CITY__.state())
  if(before.civic?.version!=='36.0'||before.surfaces?.version!=='35.0'||
     before.photoreal?.version!=='37.0')
    throw Error('URL does not contain the complete ZION v36 playable graphics release')
  if(scenario==='eco-rain'&&before.quality!=='eco')
    throw Error('ECO quality scenario failed to apply')
  if(scenario!=='eco-rain'&&before.quality!=='high')
    throw Error('High quality scenario failed to apply')
  const started=await page.evaluate(ms=>window.__ZION030_PERFORMANCE__?.start(ms),duration)
  if(!started)throw Error('GPU benchmark did not start')
  // Genuine motion stresses traversals, pedestrians and car traffic.
  await page.keyboard.down('w')
  await page.waitForTimeout(Math.ceil(duration*.45))
  await page.keyboard.up('w')
  await page.keyboard.down('d')
  await page.waitForTimeout(Math.ceil(duration*.30))
  await page.keyboard.up('d')
  await page.keyboard.down('w')
  await page.waitForTimeout(Math.ceil(duration*.25)+900)
  await page.keyboard.up('w')
  const browserReport=await page.evaluate(()=>window.__ZION030_PERFORMANCE__?.stop())
  if(!browserReport)throw Error('No measured benchmark report')
  const hardwareAttestation=attestPhysicalGpu()
  const after=await page.evaluate(()=>window.__ZION030_OPEN_CITY__.state())
  const report={
    ...browserReport,
    scenario,
    graphicsStateBefore:{quality:before.quality,raining:before.raining,dayMode:before.dayMode,
      dpr:before.perf?.pixelRatio??null,civic:before.civic,surfaces:before.surfaces,
      postfx:before.postfx,photoreal:before.photoreal},
    graphicsStateAfter:{quality:after.quality,raining:after.raining,dayMode:after.dayMode,
      civic:after.civic,surfaces:after.surfaces,postfx:after.postfx,
      photoreal:after.photoreal},
    dynamicLodTriggered:scenario!=='eco-rain'&&after.quality!=='high',
    hardwareAttestation,
    physicalGpuConfirmed:Boolean(browserReport.browserHardwareReported&&hardwareAttestation.available)
  }
  const outputFolder=process.env.OSGARD_BENCH_OUTPUT||'reports/gpu'
  const file=path.resolve(outputFolder,'zion-v36-'+scenario+'-'+new Date().toISOString().replace(/[:.]/g,'-')+'.json')
  await fs.mkdir(path.dirname(file),{recursive:true})
  await fs.writeFile(file,JSON.stringify({url,report,pageErrors:errors},null,2)+'\n','utf8')
  await page.screenshot({path:path.resolve(outputFolder,'zion-v36-'+scenario+'.png')})
  console.log('HARDWARE REPORT: '+file)
  console.log(JSON.stringify(report,null,2))
  if(errors.length)throw Error('Runtime page errors: '+errors.join('; '))
  if(!report.benchmarkValid)throw Error('Benchmark too short or no rendered frames')
  if(process.env.OSGARD_REQUIRE_PHOTO_PBR==='1'&&scenario!=='eco-rain'&&
      (report.graphicsStateAfter.photoreal?.photoTexturesLoaded||0)<4)
    throw Error('Photographic PBR asset load was not verified: local procedural fallback was used')
  if(report.dynamicLodTriggered&&process.env.OSGARD_FORBID_ADAPTIVE_LOD==='1')
    throw Error('Requested cinematic quality dropped to adaptive during benchmark')
  if(requireGPU&&!report.physicalGpuConfirmed)
    throw Error('Physical GPU NOT independently confirmed: WebGL='+report.hardwareClassification+
      ', OS GPU driver='+hardwareAttestation.available+'. No real-device FPS claim is permitted.')
  if(maxFrameP95!=null&&(!Number.isFinite(maxFrameP95)||report.frameMsP95>maxFrameP95))
    throw Error('Frame-time p95 exceeded maximum: '+report.frameMsP95+' > '+maxFrameP95)
  console.log('PASS ZION-030 v34: measured hardware evidence collected')
}finally{
  await browser?.close()
}
