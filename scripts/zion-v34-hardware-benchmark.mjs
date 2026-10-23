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
import path from 'node:path'

const url=process.env.OSGARD_GPU_BENCH_URL||
  'https://osgard.world/games/zion-9/queue/ZION-030/index.html'
const duration=Number(process.env.OSGARD_BENCH_DURATION_MS||15000)
if(!Number.isFinite(duration)||duration<8000||duration>60000)
  throw Error('OSGARD_BENCH_DURATION_MS must be between 8000 and 60000')
const maxFrameP95=process.env.OSGARD_MAX_FRAME_P95_MS?
  Number(process.env.OSGARD_MAX_FRAME_P95_MS):null
const requireGPU=process.env.OSGARD_REQUIRE_HARDWARE_GPU!=='0'
const chromePath=process.env.OSGARD_CHROME_PATH
// Edge is installed by default on the owner's Windows desktop; the same
// Chromium GPU benchmark works with either Edge or Chrome.
const channel=process.env.OSGARD_BENCH_BROWSER_CHANNEL||
  (process.platform==='win32'?'msedge':'chrome')
if(!['chrome','msedge','chromium'].includes(channel))
  throw Error('Unsupported OSGARD_BENCH_BROWSER_CHANNEL')
let browser
try{
  browser=await chromium.launch({
    headless:process.env.OSGARD_HEADLESS==='1'?true:false,
    ...(chromePath?{executablePath:chromePath}:{channel}),
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
  const report=await page.evaluate(()=>window.__ZION030_PERFORMANCE__?.stop())
  if(!report)throw Error('No measured benchmark report')
  const outputFolder=process.env.OSGARD_BENCH_OUTPUT||'reports/gpu'
  const file=path.resolve(outputFolder,'zion-v34-'+new Date().toISOString().replace(/[:.]/g,'-')+'.json')
  await fs.mkdir(path.dirname(file),{recursive:true})
  await fs.writeFile(file,JSON.stringify({url,report,pageErrors:errors},null,2)+'\n','utf8')
  console.log('HARDWARE REPORT: '+file)
  console.log(JSON.stringify(report,null,2))
  if(errors.length)throw Error('Runtime page errors: '+errors.join('; '))
  if(!report.benchmarkValid)throw Error('Benchmark too short or no rendered frames')
  if(requireGPU&&!report.physicalGpuConfirmed)
    throw Error('GPU acceleration unverified ('+report.hardwareClassification+
      '). This browser test CANNOT be reported as real-GPU performance.')
  if(maxFrameP95!=null&&(!Number.isFinite(maxFrameP95)||report.frameMsP95>maxFrameP95))
    throw Error('Frame-time p95 exceeded maximum: '+report.frameMsP95+' > '+maxFrameP95)
  console.log('PASS ZION-030 v34: measured hardware evidence collected')
}finally{
  await browser?.close()
}
