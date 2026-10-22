/* INHERIT R17 / FRAME BUDGET. All numbers are from actual browser frames.
 * CPU render-call duration is NOT claimed as GPU time. WebGL renderer
 * identification is recorded so a software rasterizer cannot masquerade as
 * verified hardware GPU performance.
 */
const percentile=(sorted,p)=>sorted.length?sorted[Math.min(sorted.length-1,Math.floor((sorted.length-1)*p))]:null;
export function makeFrameBudget({sampleLimit=240}={}){
 const intervals=[],cpu=[],memory=[];
 let lastTime=0,lastRendererInfo=null,lastPixelRatio=1,adaptive=false;
 const record=(time,submitMs,renderer,pixelRatio=1)=>{
  if(lastTime&&time>lastTime&&time-lastTime<2000)intervals.push(time-lastTime);
  lastTime=time;
  cpu.push(submitMs);
  lastPixelRatio=pixelRatio;
  lastRendererInfo=renderer?{
   calls:renderer.info.render.calls,
   triangles:renderer.info.render.triangles,
   points:renderer.info.render.points,
   lines:renderer.info.render.lines,
   textures:renderer.info.memory.textures,
   geometries:renderer.info.memory.geometries
  }:null;
  if(typeof performance!=='undefined'&&Number.isFinite(performance.memory?.usedJSHeapSize))
   memory.push(performance.memory.usedJSHeapSize);
  for(const ar of [intervals,cpu,memory])if(ar.length>sampleLimit)ar.shift();
 };
 const snapshot=()=>{
  const sorted=(a)=>[...a].sort((x,y)=>x-y);
  const intervalsSorted=sorted(intervals),cpuSorted=sorted(cpu);
  const avg=a=>a.length?a.reduce((n,v)=>n+v,0)/a.length:null;
  const meanInterval=avg(intervals);
  return Object.freeze({
   samples:cpu.length,intervalSamples:intervals.length,
   fps:meanInterval?1000/meanInterval:null,
   frameIntervalMedianMs:percentile(intervalsSorted,.5),
   frameIntervalP95Ms:percentile(intervalsSorted,.95),
   cpuSubmissionMedianMs:percentile(cpuSorted,.5),
   cpuSubmissionP95Ms:percentile(cpuSorted,.95),
   renderer:lastRendererInfo,pixelRatio:lastPixelRatio,
   heapBytes:memory.length?memory[memory.length-1]:null,
   autoResolutionReduction:adaptive,
   gpuTimerMs:null, // NEVER invent a GPU timing result
   explanation:'Frame intervals include browser scheduling; CPU submission is not GPU execution time.'
  });
 };
 return {record,snapshot,
  shouldReduceResolution:()=>!adaptive&&intervals.length>=95&&
    (percentile([...intervals].sort((a,b)=>a-b),.85)||0)>49,
  markReduced:()=>{adaptive=true;},
  reset:()=>{intervals.length=cpu.length=memory.length=0;lastTime=0;adaptive=false;}
 };
}
