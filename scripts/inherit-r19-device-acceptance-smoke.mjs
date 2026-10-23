import assert from 'node:assert/strict';
import {computeHardwareReport} from './inherit-3d/hardware-benchmark.mjs';
import {evaluateDeviceReport,DEVICE_BUDGETS} from './inherit-device-acceptance.mjs';
import {readFileSync} from 'node:fs';
let passed=0;function check(name,fn){fn();passed++;console.log('PASS',name)}
function realFormat({interval=31.7,software=false,count=300,cpu=6,drawCalls=85,triangles=820000,duration=10700,quality='high',postFX='cinematic'}={}){
 return computeHardwareReport({
  intervals:Array.from({length:count},()=>interval),
  cpu:Array.from({length:count},()=>cpu),
  gpu:[],
  reason:'complete',
  meta:{quality,durationMs:duration,
   adapter:{isSoftware:software,evidence:software?'software rasterizer':'hardware not independently verified'},
   render:{drawCalls,triangles,geometryCount:88,textureCount:12},
   viewport:{width:1280,height:720},pixelRatio:1.5,postFX}
 });
}
check('Real benchmark report shape allows observed performance acceptance',()=>{
 const result=evaluateDeviceReport(realFormat(),{profile:'desktop-30'});
 assert.equal(result.status,'observed-pass');
 assert.equal(result.independentlyVerifiedHardware,false);
 assert.equal(result.coverage.completed,true);
 assert.equal(result.checks.length,6);
 assert.ok(result.checks.every(c=>c.pass));
 assert.equal(result.gpuP95Ms,null,'Missing GPU timer is not a synthetic measurement');
});
check('Very fast software rasterizer is NEVER accepted as physical hardware evidence',()=>{
 const result=evaluateDeviceReport(realFormat({interval:8,software:true}),{profile:'desktop-30'});
 assert.equal(result.status,'software-reference-only');
 assert.equal(result.browserSoftwareRenderer,true);
 assert.equal(result.independentlyVerifiedHardware,false);
});
check('Slow rendering is reported accurately even when draw calls are low',()=>{
 const result=evaluateDeviceReport(realFormat({interval:64,cpu:15,quality:'low',postFX:'off'}),{profile:'mobile-30'});
 assert.equal(result.status,'observed-below-target');
 assert.ok(result.failures.some(x=>x.includes('frames per second')));
});
check('Missing graphics statistics yields an inconclusive hardware budget, not a pass',()=>{
 const result=evaluateDeviceReport(realFormat({triangles:null}),{profile:'desktop-30'});
 assert.equal(result.status,'incomplete-metrics');
 assert.ok(result.failures.includes('Renderer triangles'));
});
check('Short interrupted benchmark is never sufficient',()=>{
 const report=realFormat({count:30,duration:3000});
 const result=evaluateDeviceReport(report,{profile:'desktop-30'});
 assert.equal(result.status,'inconclusive');
});
check('Ultra performance cannot be proven by fast low-quality rendering or disabled postprocessing',()=>{
 const wrongMode=evaluateDeviceReport(realFormat({quality:'low',postFX:'off'}),{profile:'desktop-30'});
 assert.equal(wrongMode.status,'configuration-mismatch');
 const noEffects=evaluateDeviceReport(realFormat({quality:'high',postFX:'off'}),{profile:'desktop-30'});
 assert.equal(noEffects.status,'configuration-mismatch');
 const mobile=evaluateDeviceReport(realFormat({quality:'low',postFX:'off'}),{profile:'mobile-30'});
 assert.equal(mobile.status,'observed-pass');
});
check('Untrusted schema is rejected, all tier constraints are explicit',()=>{
 assert.equal(evaluateDeviceReport({schema:'random'},{}).status,'invalid-report');
 assert.throws(()=>evaluateDeviceReport(realFormat(),{profile:'unverified-ultra'}),RangeError);
 assert.deepEqual(Object.keys(DEVICE_BUDGETS),['desktop-30','mobile-30','entry-24']);
});
check('Acceptance tool contains no network calls and never upgrades hardware trust',()=>{
 const src=readFileSync('scripts/inherit-device-acceptance.mjs','utf8');
 assert.doesNotMatch(src,/\bfetch\s*\(|XMLHttpRequest|new WebSocket|hardwareVerified:true/);
 assert.match(src,/independentlyVerifiedHardware:false/);
 assert.match(src,/--report/);
});
console.log('INHERIT R19 on-device performance acceptance:',passed,'passed.');
