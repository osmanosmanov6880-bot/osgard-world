/* INHERIT R18 — on-device rendering benchmark.
 * Uses real rAF intervals and measured CPU submission time. GPU time is
 * available ONLY if EXT_disjoint_timer_query_webgl2 returns valid samples.
 * This module has no network, storage, analytics or personally identifying
 * access. Reports never claim CI's SwiftShader is a physical GPU.
 */
const sort=values=>[...values].sort((a,b)=>a-b);
export const percentile=(values,p)=>{
 if(!values?.length)return null;
 const sorted=sort(values);
 return sorted[Math.max(0,Math.min(sorted.length-1,Math.floor((sorted.length-1)*p)))];
};
const avg=values=>values.length?values.reduce((a,b)=>a+b,0)/values.length:null;
const round=(v,d=1)=>Number.isFinite(v)?Number(v.toFixed(d)):null;
const clamp=(v,lo,hi)=>Math.min(hi,Math.max(lo,v));
const safeInteger=(n)=>Number.isSafeInteger(n)&&n>=0?n:null;
const fixedStats=(renderer)=>renderer?{
 drawCalls:safeInteger(renderer.info?.render?.calls),
 triangles:safeInteger(renderer.info?.render?.triangles),
 textureCount:safeInteger(renderer.info?.memory?.textures),
 geometryCount:safeInteger(renderer.info?.memory?.geometries)
}:null;
export function classifyRenderer(adapter){
 if(adapter?.isSoftware===true)return 'software';
 const desc=String(adapter?.evidence||'');
 if(adapter?.isSoftware===false&&/hardware not independently verified/.test(desc))return 'reported-adapter-unverified';
 return 'unverified';
}
export function computeHardwareReport({intervals=[],cpu=[],gpu=[],meta={},reason='complete',warmupMs=0}={}){
 const good=intervals.filter(x=>Number.isFinite(x)&&x>0&&x<1500);
 const submit=cpu.filter(x=>Number.isFinite(x)&&x>=0&&x<1500);
 const timers=gpu.filter(x=>Number.isFinite(x)&&x>0&&x<1500);
 const intervalMean=avg(good),p95=percentile(good,.95);
 const avgFps=intervalMean?1000/intervalMean:null;
 const slow33=good.length?good.filter(x=>x>33.4).length/good.length:null;
 const slow50=good.length?good.filter(x=>x>50).length/good.length:null;
 // This is a relative recommendation for the QUALITY THAT WAS TESTED.
 // A low-tier 60 FPS result is not proof that ultra runs at 60 FPS.
 const qualityTested=['high','medium','low'].includes(meta.quality)?meta.quality:'unknown';
 const eligible=good.length>=45&&reason==='complete';
 const rating=!eligible?'inconclusive':p95<=20&&slow33<=.08?'smooth-60':
  p95<=36&&slow50<=.09?'playable-30':'below-target';
 const suggestion=!eligible?'repeat-valid-test':
  rating==='below-target'?(qualityTested==='high'?'try-balanced':
    qualityTested==='medium'?'try-efficient':'reduce-resolution'):
  rating==='smooth-60'&&qualityTested!=='high'?'try-next-tier-and-retest':'keep-tested-tier';
 const classification=classifyRenderer(meta.adapter);
 return Object.freeze({
  schema:'INHERIT-3D-HARDWARE-BENCHMARK-v1',
  reason,valid:eligible,qualityTested,rendererClassification:classification,
  hardwareVerified:false, // Browser adapter strings cannot independently attest hardware identity.
  hardwareEvidence:classification==='software'?'software renderer (not physical GPU benchmark)':
   classification==='reported-adapter-unverified'?'reported WebGL adapter only (unverified physical GPU)':
    'adapter information unavailable; physical GPU not established',
  durationMs:round(meta.durationMs,0),warmupMs:round(warmupMs,0),
  samples:good.length,gpuSamples:timers.length,
  averageFps:round(avgFps),frameP50Ms:round(percentile(good,.5),2),
  frameP95Ms:round(p95,2),frameP99Ms:round(percentile(good,.99),2),
  framesOver33msRatio:round(slow33,4),framesOver50msRatio:round(slow50,4),
  cpuSubmitP50Ms:round(percentile(submit,.5),2),
  cpuSubmitP95Ms:round(percentile(submit,.95),2),
  gpuP50Ms:round(percentile(timers,.5),2),
  gpuP95Ms:round(percentile(timers,.95),2),
  gpuTimerAvailable:meta.gpuTimerAvailable===true,
  gpuTimerMeasured:timers.length>0,
  // No synthetic GPU time. Null means query unsupported, disjoint or no samples.
  pixelRatio:round(meta.pixelRatio,2),
  viewport:meta.viewport&&Number.isSafeInteger(meta.viewport.width)&&Number.isSafeInteger(meta.viewport.height)?
   {width:meta.viewport.width,height:meta.viewport.height}:null,
  render:meta.render||null,postFX:meta.postFX||'off',
  score:rating,recommendation:suggestion,
  notes:['These are measured browser frame intervals, not uncapped theoretical GPU FPS.',
   'CPU submission duration is NOT GPU render duration.',
   'A report measured on this browser is not a test on every user device.',
   'No measurements or adapter details were uploaded to a server.']
 });
}
export function makeHardwareBenchmark({durationMs=10000,warmupMs=500,maxSamples=1600}={}){
 let state='idle',startedAt=0,until=0,warmupUntil=0,last=0;
 let intervals=[],cpu=[],gpu=[],meta={},finished=null;
 const start=(now,information={})=>{
  if(!Number.isFinite(now))throw new TypeError('A monotonic browser timestamp is required');
  state='running';startedAt=now;warmupUntil=now+clamp(warmupMs,0,3000);
  until=now+clamp(durationMs,1000,20000);last=0;finished=null;
  intervals=[];cpu=[];gpu=[];meta={...information};
  return {startedAt,durationMs:until-now,warmupMs:warmupUntil-now};
 };
 const running=()=>state==='running';
 const progress=(now)=>running()?clamp((now-startedAt)/(until-startedAt),0,1):finished?1:0;
 const addGpuTime=ms=>{if(running()&&Number.isFinite(ms)&&ms>0&&ms<1500&&gpu.length<maxSamples)gpu.push(ms)};
 const record=(now,submitMs,rendererInfo)=>{
  if(!running()||!Number.isFinite(now))return null;
  if(rendererInfo)meta.render=rendererInfo;
  if(now<=warmupUntil){last=now;return null}
  if(last&&now>last&&now-last<1500&&intervals.length<maxSamples)intervals.push(now-last);
  last=now;
  if(Number.isFinite(submitMs)&&submitMs>=0&&submitMs<1500&&cpu.length<maxSamples)cpu.push(submitMs);
  if(now>=until)return stop(now,'complete');
  return null;
 };
 const stop=(now,reason='cancelled')=>{
  if(!running())return finished;
  state='stopped';
  finished=computeHardwareReport({
   intervals,cpu,gpu,reason,warmupMs:warmupUntil-startedAt,
   meta:{...meta,durationMs:Math.max(0,Number.isFinite(now)?now-startedAt:until-startedAt)}
  });
  return finished;
 };
 return Object.freeze({start,running,record,addGpuTime,stop,progress,
  result:()=>finished,
  state:()=>({state,progress:running()?null:finished?1:0,samples:intervals.length})
 });
}
// Timer queries do not expose hardware identity, but return real GPU execution
// duration in milliseconds on supporting, non-disjoint WebGL2 contexts.
export function makeGpuQueryTimer(gl){
 const ext=gl&&typeof gl.beginQuery==='function'&&
  typeof gl.getQueryParameter==='function'?gl.getExtension('EXT_disjoint_timer_query_webgl2'):null;
 let supported=!!(ext&&gl.TIME_ELAPSED_EXT!==undefined||ext?.TIME_ELAPSED_EXT!==undefined);
 let active=null,pending=[],disabledReason=supported?null:'unsupported';
 const disable=(reason)=>{
  disabledReason=reason;supported=false;
  if(active){try{gl.endQuery(ext.TIME_ELAPSED_EXT)}catch{};pending.push(active);active=null;}
  for(const query of pending)try{gl.deleteQuery(query)}catch{}
  pending=[];
 };
 const begin=()=>{
  if(!supported||active||pending.length>=3)return false;
  try{
   active=gl.createQuery();if(!active)return false;
   gl.beginQuery(ext.TIME_ELAPSED_EXT,active);return true;
  }catch{disable('invalid-query');return false;}
 };
 const end=()=>{
  if(!active||!supported)return false;
  try{gl.endQuery(ext.TIME_ELAPSED_EXT);pending.push(active);active=null;return true}
  catch{disable('invalid-query');return false}
 };
 const poll=()=>{
  if(!supported||!pending.length)return [];
  const out=[],remaining=[];
  try{
   const disjoint=!!gl.getParameter(ext.GPU_DISJOINT_EXT);
   if(disjoint){disable('gpu-disjoint');return []}
   for(const query of pending){
    if(gl.getQueryParameter(query,gl.QUERY_RESULT_AVAILABLE)){
     const nanos=gl.getQueryParameter(query,gl.QUERY_RESULT);
     if(Number.isFinite(nanos)&&nanos>0)out.push(nanos/1e6);
     gl.deleteQuery(query);
    }else remaining.push(query);
   }
   pending=remaining;return out;
  }catch{disable('query-poll-error');return []}
 };
 return Object.freeze({
  supported:()=>supported,reason:()=>disabledReason,
  begin,end,poll,dispose:()=>disable('disposed')
 });
}
export {fixedStats};
