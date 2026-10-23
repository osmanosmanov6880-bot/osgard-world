/**
 * ZION-030 v36 PHYSICAL GPU evidence matrix.
 * Requires a genuine self-hosted GPU runner with a live Chrome graphics stack.
 * Never silently substitutes SwiftShader, lavapipe or a synthetic FPS estimate.
 *
 * Each scenario produces a screenshot and raw JSON report. High-day and
 * high-rain-night MUST hold the requested quality to meet the strict gate.
 * ECO has its own truthful timing and is not allowed to pass as cinematic.
 */
import {spawnSync} from 'node:child_process'
import fs from 'node:fs/promises'
import path from 'node:path'

const root=path.resolve(process.env.OSGARD_BENCH_OUTPUT||'reports/gpu')
const scenarios=['high-day','high-rain-night','eco-rain']
const results=[]
const duration=Number(process.env.OSGARD_BENCH_DURATION_MS||15000)
if(!Number.isFinite(duration)||duration<8000||duration>60000)
  throw Error('Hardware matrix requires a genuine 8–60 second capture per scenario')
await fs.mkdir(root,{recursive:true})
for(const scenario of scenarios){
  const folder=path.join(root,scenario)
  await fs.mkdir(folder,{recursive:true})
  const env={...process.env,
    OSGARD_BENCH_SCENARIO:scenario,
    OSGARD_BENCH_OUTPUT:folder,
    OSGARD_BENCH_DURATION_MS:String(duration),
    OSGARD_REQUIRE_HARDWARE_GPU:'1',
    OSGARD_FORBID_ADAPTIVE_LOD:scenario==='eco-rain'?'0':'1'}
  const run=spawnSync(process.execPath,['scripts/zion-v34-hardware-benchmark.mjs'],{
    cwd:process.cwd(),env,encoding:'utf8',timeout:duration+120000,maxBuffer:8*1024*1024
  })
  const files=(await fs.readdir(folder)).filter(f=>f.endsWith('.json')).sort()
  let evidence=null
  for(const file of files)try{
    const parsed=JSON.parse(await fs.readFile(path.join(folder,file),'utf8'))
    if(parsed?.report?.scenario===scenario)evidence=parsed
  }catch(_){}
  const ok=run.status===0&&Boolean(evidence?.report?.physicalGpuConfirmed&&
    evidence?.report?.benchmarkValid)&&
    (scenario==='eco-rain'||!evidence?.report?.dynamicLodTriggered)
  const row={scenario,ok,
    exitCode:run.status,signal:run.signal,error:run.error?.message||null,
    hardwareConfirmed:evidence?.report?.physicalGpuConfirmed??false,
    qualityBefore:evidence?.report?.graphicsStateBefore?.quality??null,
    qualityAfter:evidence?.report?.graphicsStateAfter?.quality??null,
    frameMsP50:evidence?.report?.frameMsP50??null,
    frameMsP95:evidence?.report?.frameMsP95??null,
    gpuMsP95:evidence?.report?.gpuRenderMsP95??null,
    gpuTimerSamples:evidence?.report?.gpuTimerSamples??0,
    drawCallsP95:evidence?.report?.drawCallsP95??null,
    trianglesP95:evidence?.report?.trianglesP95??null,
    renderedFrames:evidence?.report?.renderedFrames??0,
    diagnostic:(run.stderr||'').slice(-2000)}
  results.push(row)
  console.log('SCENARIO '+scenario+': '+JSON.stringify(row))
}
const summary={
  benchmark:'ZION-030 v36 physical GPU / gameplay / dynamic LOD matrix',
  timestamp:new Date().toISOString(),
  runner:process.env.RUNNER_NAME||null,
  requestedGpuHardware:true,
  requestedScenarios:scenarios,
  physicalGpuConfirmed:results.length===3&&results.every(x=>x.hardwareConfirmed),
  allPassed:results.length===3&&results.every(x=>x.ok),
  results
}
const summaryPath=path.join(root,'zion-v36-matrix-summary.json')
await fs.writeFile(summaryPath,JSON.stringify(summary,null,2)+'\n')
console.log('Physical GPU evidence summary: '+summaryPath)
if(!summary.allPassed)
  throw Error('ZION-030 v36 physical GPU matrix is NOT VERIFIED. Inspect per-scenario evidence and/or obtain a real GPU runner.')
console.log('PASS ZION-030 v36 on a physical GPU — three independently measured quality/weather cases')
