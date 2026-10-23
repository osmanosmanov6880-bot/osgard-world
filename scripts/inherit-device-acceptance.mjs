/* INHERIT R19 — explicit on-device frame-budget acceptance.
 * Takes the JSON created by the actual ten-second INHERIT browser benchmark.
 * Never mistakes GitHub's SwiftShader for a verified physical graphics card.
 * This checks observed results only; hardware identity needs independent proof.
 */
import {readFileSync,writeFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';

export const DEVICE_BUDGETS=Object.freeze({
 'desktop-30':Object.freeze({name:'Desktop high-quality 30 FPS',minFps:28,maxP95Ms:37,maxSlow50Ratio:.09,maxCpuP95Ms:20,maxDrawCalls:300,maxTriangles:2800000}),
 'mobile-30':Object.freeze({name:'Mobile efficient 30 FPS',minFps:26,maxP95Ms:50,maxSlow50Ratio:.14,maxCpuP95Ms:26,maxDrawCalls:230,maxTriangles:1650000}),
 'entry-24':Object.freeze({name:'Entry device low-quality 24 FPS',minFps:20,maxP95Ms:67,maxSlow50Ratio:.27,maxCpuP95Ms:33,maxDrawCalls:200,maxTriangles:950000})
});
const number=value=>Number.isFinite(value)?value:null;
const check=(name,actual,rule,threshold)=>({
 name,actual:number(actual),rule,threshold,
 pass:Number.isFinite(actual)&&(rule==='at-least'?actual>=threshold:actual<=threshold)
});
export function evaluateDeviceReport(report,{profile='desktop-30'}={}){
 const budget=DEVICE_BUDGETS[profile];
 if(!budget)throw new RangeError('Unknown profile. Use desktop-30, mobile-30 or entry-24.');
 if(!report||typeof report!=='object'||report.schema!=='INHERIT-3D-HARDWARE-BENCHMARK-v1')
  return Object.freeze({status:'invalid-report',profile,checks:[],reason:'Only original R18/R19 INHERIT browser benchmark reports are supported.',independentlyVerifiedHardware:false});
 const software=report.rendererClassification==='software';
 const complete=report.reason==='complete'&&report.valid===true&&
  report.samples>=90&&report.durationMs>=9500;
 const coverage={
  completed:complete,
  samples:report.samples??null,
  durationMs:report.durationMs??null,
  softwareRasterizer:software,
  gpuTimerMeasured:report.gpuTimerMeasured===true
 };
 if(!complete)return Object.freeze({
  status:'inconclusive',profile,coverage,checks:[],
  reason:'Collect at least 90 real WebGL frame intervals over a complete 10-second run.',
  independentlyVerifiedHardware:false
 });
 const budgetChecks=[
  check('Observed average frames per second',report.averageFps,'at-least',budget.minFps),
  check('Observed p95 frame time (ms)',report.frameP95Ms,'at-most',budget.maxP95Ms),
  check('Frames slower than 50 ms share',report.framesOver50msRatio,'at-most',budget.maxSlow50Ratio),
  check('CPU submission p95 (ms; not GPU time)',report.cpuSubmitP95Ms,'at-most',budget.maxCpuP95Ms),
  check('Renderer draw calls',report.render?.drawCalls,'at-most',budget.maxDrawCalls),
  check('Renderer triangles',report.render?.triangles,'at-most',budget.maxTriangles)
 ];
 const allValid=budgetChecks.every(c=>c.actual!==null);
 const allPass=allValid&&budgetChecks.every(c=>c.pass);
 const status=software?'software-reference-only':!allValid?'incomplete-metrics':
  allPass?'observed-pass':'observed-below-target';
 const note=software?
  'This run used a software rasterizer. Its FPS cannot be claimed as physical GPU performance.':
  status==='observed-pass'?
   'The supplied browser observations meet this tier. The physical device identity and real-world representativeness are not independently verified.':
   'The supplied browser observations do not demonstrate that this tier meets its budget.';
 const failures=budgetChecks.filter(x=>!x.pass).map(x=>x.name);
 return Object.freeze({
  schema:'INHERIT-R19-PERFORMANCE-ACCEPTANCE-v1',status,profile,tier:budget.name,
  testedQuality:report.qualityTested||'unknown',
  postFX:report.postFX||'off',
  browserSoftwareRenderer:software,
  independentlyVerifiedHardware:false,
  gpuTimerObserved:report.gpuTimerMeasured===true,
  gpuP95Ms:report.gpuTimerMeasured===true?number(report.gpuP95Ms):null,
  coverage,checks:budgetChecks,failures,
  recommendation:status==='observed-below-target'?
   'Lower pixel ratio, disable bloom or switch to efficient mode and rerun the full benchmark.':
   status==='software-reference-only'?'Repeat on a locally identifiable physical GPU.':
    allPass?'Keep this tested quality tier, then independently validate on the intended hardware.':
     'Repeat with complete metrics in the final browser build.',
  note
 });
}
function main(args){
 const get=key=>{const i=args.indexOf(key);return i<0?null:args[i+1]};
 const file=get('--report'),profile=get('--profile')||'desktop-30';
 if(!file){
  console.error('Usage: node scripts/inherit-device-acceptance.mjs --report <real-browser-report.json> --profile desktop-30|mobile-30|entry-24 [--out decision.json]');
  process.exitCode=2;return;
 }
 let report;
 try{report=JSON.parse(readFileSync(file,'utf8'))}
 catch(err){console.error('Cannot parse browser report:',err.message);process.exitCode=2;return}
 let assessed;
 try{assessed=evaluateDeviceReport(report,{profile})}
 catch(err){console.error(err.message);process.exitCode=2;return}
 const out=JSON.stringify(assessed,null,2);
 const destination=get('--out');
 if(destination)writeFileSync(destination,out+'\n','utf8');
 console.log(out);
 if(assessed.status!=='observed-pass')process.exitCode=1;
}
if(process.argv[1]&&pathToFileURL(process.argv[1]).href===import.meta.url)main(process.argv.slice(2));
