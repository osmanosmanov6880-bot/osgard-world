/* INHERIT R23 — Separate frame evidence from actual hardware throughput.
 * Software reference rendering at 2 fps proves pixels render, not 30/60 fps.
 * A browser-reported adapter never independently proves physical GPU identity.
 */
export const WEBGL_MIN_SAMPLES=8;
export const HARDWARE_MIN_SAMPLES=45;
export const WEBGL_MIN_SESSION_SAMPLES=12;
const validCount=n=>Number.isSafeInteger(n)&&n>=0;
export function evaluateWebGLFrameEvidence(result){
 const t=result?.telemetry,b=t?.hardwareBenchmark,failures=[];
 if(t?.available!==true||t?.active!==true)failures.push('missing-active-webgl');
 if(!validCount(t?.after?.samples)||t.after.samples<WEBGL_MIN_SESSION_SAMPLES)
  failures.push('insufficient-render-frame-evidence');
 if(b?.schema!=='INHERIT-3D-HARDWARE-BENCHMARK-v1'||
  !validCount(b.samples)||b.samples<WEBGL_MIN_SAMPLES)
  failures.push('insufficient-timed-webgl-frames');
 if(result?.pageErrors?.length)failures.push('uncaught-browser-errors');
 return Object.freeze({
  ok:failures.length===0,
  status:failures.length?'insufficient-webgl-reference':'observed-webgl-frames',
  failures,softwareRenderer:result?.softwareRenderer===true,
  frameSamples:b?.samples??0,frameP95Ms:b?.frameP95Ms??null,
  independentlyVerifiedHardware:false
 });
}
export function evaluateHardwareThroughput(result){
 const webgl=evaluateWebGLFrameEvidence(result),failures=[...webgl.failures];
 const b=result?.telemetry?.hardwareBenchmark;
 if(result?.softwareRenderer===true)failures.push('software-renderer-not-physical-gpu');
 if(result?.evidence!=='hardware-identified')failures.push('hardware-adapter-not-reported');
 if(!validCount(b?.samples)||b.samples<HARDWARE_MIN_SAMPLES||b?.valid!==true)
  failures.push('insufficient-hardware-throughput-samples');
 return Object.freeze({
  ok:failures.length===0,
  status:failures.length?'not-hardware-throughput':'reported-adapter-throughput',
  failures,samples:b?.samples??0,
  independentlyVerifiedHardware:false,
  note:'OS/device identity and physical GPU must be independently attested.'
 });
}
