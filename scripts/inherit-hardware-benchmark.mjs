/* INHERIT R18 physical-device benchmark.
 * Execute locally with `npm run qa:inherit-benchmark` and system Chrome.
 * The same script runs on GitHub CI (typically SwiftShader software).
 * The report ALWAYS records the WebGL vendor/model and never calls CPU
 * submission timing "GPU time". --require-gpu rejects browser-reported software
 * renderers but physical GPU identity is not independently attested.
 */
import {chromium} from '@playwright/test';
import {spawn} from 'node:child_process';
import {evaluateWebGLFrameEvidence,evaluateHardwareThroughput} from './inherit-benchmark-gate.mjs';
import {writeFileSync,mkdirSync} from 'node:fs';
import {setTimeout as sleep} from 'node:timers/promises';
const args=new Set(process.argv.slice(2)),software=args.has('--swiftshader')||
 process.env.OSGARD_ENABLE_SWIFTSHADER==='1';
const base=process.env.OSGARD_BASE_URL||'http://127.0.0.1:4175';
const output=process.env.OSGARD_BENCHMARK_OUTPUT||'browser-report/inherit-r18-local-device-profile.json';
const serve=args.has('--serve');
const requireGPU=args.has('--require-gpu');
const requireWebGL=args.has('--require-webgl')||requireGPU;
let proc,browser;
async function isReady(){
 try{const r=await fetch(base+'/games/inherit/index.html',{signal:AbortSignal.timeout(1800)});return r.ok;}catch{return false}
}
async function startPreview(){
 if(!serve)return;
 proc=spawn(process.platform==='win32'?'npm.cmd':'npm',['run','preview','--','--port','4175','--strictPort'],{stdio:'ignore'});
 for(let i=0;i<55;i++){if(await isReady())return;await sleep(400);}
 throw Error('Production preview did not start; run npm run build first');
}
async function profile({name,width,height,dpr}){
 const ctx=await browser.newContext({
  viewport:{width,height},deviceScaleFactor:dpr,
  reducedMotion:'no-preference',locale:'ru-RU'
 });
 const page=await ctx.newPage();const pageErrors=[];
 page.on('pageerror',error=>pageErrors.push(String(error)));
 await page.goto(base+'/games/inherit/?lang=ru',{waitUntil:'domcontentloaded',timeout:30000});
 await page.waitForFunction(()=>!!window.InheritAAA3D?.getState,{timeout:10000});
 await page.locator('#island').scrollIntoViewIfNeeded({timeout:10000});
 let state=await page.evaluate(()=>window.InheritAAA3D.getState());
 if(state.available&&!state.active){await page.evaluate(()=>window.InheritAAA3D.toggle());}
 let telemetry=await page.evaluate(async()=>{
  const controller=window.InheritAAA3D;
  const gpu=controller.getState();
  const caps={};
  try{
   const canvas=document.querySelector('#island>.aaa3d-canvas');
   const gl=canvas.getContext('webgl2')||canvas.getContext('webgl');
   if(gl){
    caps.maxTextureSize=gl.getParameter(gl.MAX_TEXTURE_SIZE);
    caps.maxViewportDims=Array.from(gl.getParameter(gl.MAX_VIEWPORT_DIMS)||[]);
    caps.maxRenderbufferSize=gl.getParameter(gl.MAX_RENDERBUFFER_SIZE);
   }
  }catch{}
  const before=controller.getPerformanceReport();
  const after=await controller.samplePerformance({minFrames:55,maxWaitMs:13000});
  // A full opt-in 10-second test on this actual browser/device, NOT an
  // estimate based on the 30 FPS normal gameplay pacing.
  let hardwareBenchmark=null;
  if(gpu.available){
   const began=controller.startHardwareBenchmark({durationMs:10000});
   if(began){
    const deadline=performance.now()+25000;
    while(!controller.getHardwareBenchmark()&&performance.now()<deadline)
     await new Promise(resolve=>setTimeout(resolve,250));
    hardwareBenchmark=controller.getHardwareBenchmark();
   }
  }
  return {
   available:gpu.available,active:gpu.active,quality:gpu.quality,
   adapter:gpu.adapter,postFX:gpu.postFX,
   ambientLife:gpu.ambientLife,materials:gpu.materials,
   caps,before,after,hardwareBenchmark,
   deviceMemory:navigator.deviceMemory??null,
   platform:navigator.platform??null,userAgent:navigator.userAgent
  };
 });
 const adapter=telemetry.adapter||{};
 const identified=/(NVIDIA|AMD|Radeon|GeForce|Intel|Apple|Adreno|Mali)/i.test(adapter.model||'');
 const softwareRenderer=!!adapter.isSoftware;
 const evidence=!telemetry.available?'no-webgl':
  softwareRenderer?'software-webgl':identified?'hardware-identified':'gpu-not-verified';
 const result={viewport:name,width,height,dpr,chrome:browser.version(),evidence,softwareRenderer,
  renderer:adapter,telemetry,pageErrors};
 await ctx.close();
 return result;
}
try{
 await startPreview();
 if(!(await isReady()))throw Error('Preview unavailable at '+base);
 browser=await chromium.launch({
  channel:'chrome',headless:!args.has('--headed'),
  args:software?['--enable-webgl','--ignore-gpu-blocklist','--use-gl=angle',
   '--use-angle=swiftshader','--enable-unsafe-swiftshader']:[]
 });
 const results=[];
 for(const v of [{name:'desktop-1440x900',width:1440,height:900,dpr:1},
  {name:'mobile-390x844',width:390,height:844,dpr:1}])
   results.push(await profile(v));
 for(const res of results){
  res.webglGate=evaluateWebGLFrameEvidence(res);
  res.hardwareGate=evaluateHardwareThroughput(res);
 }
 const outputRecord={createdAt:new Date().toISOString(),base,chromeVersion:browser.version(),
  simulatedSoftwareGPU:software,requireGPU,results};
 mkdirSync(output.slice(0,output.lastIndexOf('/'))||'.',{recursive:true});
 writeFileSync(output,JSON.stringify(outputRecord,null,2)+'\n','utf8');
 console.log('INHERIT R18 measured Chrome / local device frame timings');
 for(const res of results){
  const m=res.telemetry.after;
  console.log(JSON.stringify({
   profile:res.viewport,adapter:res.renderer.model,
   evidence:res.evidence,frames:m.samples,fps:m.fps,
   p95FrameIntervalMs:m.frameIntervalP95Ms,
   p95CpuSubmissionMs:m.cpuSubmissionP95Ms,
   drawCalls:m.renderer?.calls,triangles:m.renderer?.triangles,
   postFX:res.telemetry.postFX,webglGate:res.webglGate.status,
   hardwareGate:res.hardwareGate.status,
   tenSecondBenchmark:res.telemetry.hardwareBenchmark&&{
    fps:res.telemetry.hardwareBenchmark.averageFps,
    p95FrameMs:res.telemetry.hardwareBenchmark.frameP95Ms,
    trueGpuP95Ms:res.telemetry.hardwareBenchmark.gpuP95Ms,
    gpuTimerSupported:res.telemetry.hardwareBenchmark.gpuTimerAvailable,
    adapterClassification:res.telemetry.hardwareBenchmark.rendererClassification,
    hardwareVerified:false
   }
  }));
 }
 console.log('Benchmark report:',output);
 if(results.some(v=>v.pageErrors.length))throw Error('Browser reported uncaught JS errors');
 if(requireWebGL&&results.some(v=>!v.webglGate.ok))
  throw Error('Insufficient actual WebGL frame evidence (not an FPS target)');
 if(requireGPU&&results.some(v=>!v.hardwareGate.ok))
  throw Error('Hardware throughput gate failed: physical GPU not independently attested');
}finally{
 await browser?.close();
 if(proc){proc.kill();await sleep(100);}
}
