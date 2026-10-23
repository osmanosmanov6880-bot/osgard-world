/* INHERIT R20 — real-browser frame pacing, not invented GPU timings.
 * Pixel density follows sustained actual rAF intervals with a long cooldown,
 * distinct targets for High / Balanced / Efficient, and hysteresis.
 * Never changes gameplay, save data, geometry, account rights or the user tier.
 */
const clamp=(n,a,b)=>Math.min(b,Math.max(a,n));
const TARGETS=Object.freeze({high:33.4,medium:38.5,low:48.5});
export function makeAdaptiveResolution({min=.64,max=1,stepDown=.12,stepUp=.05,
 cooldownMs=8000,minSamples=110}={}){
 let scale=1,lastChange=-Infinity,changes=0,reason='initial',lastP95=null;
 function reset(now=0){
  scale=1;lastChange=Number.isFinite(now)?now:-Infinity;changes=0;reason='reset';lastP95=null;
 }
 function observe({now,quality='high',metrics,visible=true,reducedMotion=false,benchmark=false}={}){
  if(!Number.isFinite(now)||!visible||benchmark||reducedMotion)return null;
  const count=metrics?.intervalSamples||0,frameP95=metrics?.frameIntervalP95Ms;
  if(count<minSamples||!Number.isFinite(frameP95))return null;
  lastP95=frameP95;
  if(now-lastChange<cooldownMs)return null;
  const target=TARGETS[quality]||TARGETS.medium;
  let next=scale,direction='';
  // A short fluctuation should not trigger a resolution oscillation.
  if(frameP95>target*1.44&&scale>min+.005){
   next=Math.max(min,scale-stepDown);direction='slow-frames';
  }else if(frameP95<target*.87&&scale<max-.005&&count>=minSamples*2){
   const cpu=metrics?.cpuSubmissionP95Ms;
   // CPU-bound work isn't fixed by increasing GPU pixel density.
   if(Number.isFinite(cpu)&&cpu<target*.44){next=Math.min(max,scale+stepUp);direction='recovered-headroom';}
  }
  if(!direction)return null;
  scale=Math.round(next*1000)/1000;
  lastChange=now;changes++;reason=direction;
  return Object.freeze({scale,reason,quality,targetFrameMs:target,measuredP95Ms:frameP95});
 }
 return Object.freeze({
  observe,reset,
  snapshot:()=>Object.freeze({scale,changes,reason,lastP95ms:lastP95,
   evidence:'Only actual browser frame intervals; no GPU time is inferred.'})
 });
}
export {TARGETS};
