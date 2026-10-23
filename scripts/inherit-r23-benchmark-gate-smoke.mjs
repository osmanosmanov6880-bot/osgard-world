import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {evaluateWebGLFrameEvidence,evaluateHardwareThroughput,WEBGL_MIN_SAMPLES,HARDWARE_MIN_SAMPLES} from './inherit-benchmark-gate.mjs';
let passed=0;const test=(title,fn)=>{fn();passed++;console.log('PASS',title)};
const make=({software=true,frames=25,sessionFrames=28,valid=false,hardware=false}={})=>({
 softwareRenderer:software,evidence:hardware?'hardware-identified':'software-webgl',
 pageErrors:[],
 telemetry:{available:true,active:true,after:{samples:sessionFrames},
  hardwareBenchmark:{schema:'INHERIT-3D-HARDWARE-BENCHMARK-v1',samples:frames,valid,frameP95Ms:500}}
});
test('Real software WebGL frames pass render evidence without fabricating hardware FPS',()=>{
 const r=make();
 assert.equal(evaluateWebGLFrameEvidence(r).ok,true);
 assert.equal(evaluateHardwareThroughput(r).ok,false);
 assert.equal(evaluateWebGLFrameEvidence(r).independentlyVerifiedHardware,false);
 assert.ok(WEBGL_MIN_SAMPLES<HARDWARE_MIN_SAMPLES);
});
test('Incomplete shader or no WebGL context never receives a green render gate',()=>{
 assert.equal(evaluateWebGLFrameEvidence(make({frames:4})).ok,false);
 const missing=make();missing.telemetry.available=false;
 assert.equal(evaluateWebGLFrameEvidence(missing).ok,false);
 const errors=make();errors.pageErrors.push('shader failed');
 assert.equal(evaluateWebGLFrameEvidence(errors).ok,false);
});
test('Reported physical GPU still needs enough complete hardware frames',()=>{
 assert.equal(evaluateWebGLFrameEvidence(make({software:false,hardware:true,frames:25})).ok,true);
 assert.equal(evaluateHardwareThroughput(make({software:false,hardware:true,frames:25})).ok,false);
 const better=make({software:false,hardware:true,frames:300,valid:true,sessionFrames:301});
 assert.equal(evaluateHardwareThroughput(better).ok,true);
 assert.equal(evaluateHardwareThroughput(better).independentlyVerifiedHardware,false);
});
test('Slow physical GPU and fast software GPU are not confused',()=>{
 const fastSoftware=make({software:true,frames:300,valid:true,hardware:false});
 assert.equal(evaluateHardwareThroughput(fastSoftware).ok,false);
 const slowReal=make({software:false,hardware:true,frames:9});
 assert.equal(evaluateWebGLFrameEvidence(slowReal).ok,true);
 assert.equal(evaluateHardwareThroughput(slowReal).ok,false);
});
test('The executable benchmark has strict separate hardware and reference gates',()=>{
 const src=readFileSync('scripts/inherit-hardware-benchmark.mjs','utf8');
 assert.match(src,/evaluateWebGLFrameEvidence/);
 assert.match(src,/evaluateHardwareThroughput/);
 assert.match(src,/hardwareGate/);
 assert.match(src,/webglGate/);
 assert.doesNotMatch(readFileSync('scripts/inherit-benchmark-gate.mjs','utf8'),
  /hardwareVerified:true|independentlyVerifiedHardware:true|new WebSocket|fetch\s*\(/);
});
console.log('INHERIT browser WebGL evidence versus genuine device-gate:',passed,'tests passed');
