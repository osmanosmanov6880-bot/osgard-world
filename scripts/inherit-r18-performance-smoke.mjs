/* INHERIT R18 benchmark unit and source acceptance.
 * Synthetic input below checks math ONLY. Never present it as real device FPS.
 * Actual device measurements are made by user opt-in or the separate Chrome
 * physical-machine benchmark and tagged software where applicable.
 */
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {
 percentile,computeHardwareReport,classifyRenderer,makeHardwareBenchmark,
 makeGpuQueryTimer,fixedStats
} from './inherit-3d/hardware-benchmark.mjs';
const files=['scripts/inherit-3d/hardware-benchmark.mjs',
 'scripts/inherit-3d/hardware-benchmark-ui.mjs','scripts/inherit-3d/aaa-three-entry.mjs'];
let passed=0;
const test=(name,run)=>{run();console.log('PASS',name);passed++};
const source=p=>readFileSync(p,'utf8');
test('All R18 modules parse as valid JavaScript',()=>{
 for(const file of files){const x=spawnSync(process.execPath,['--check',file],{encoding:'utf8'});
  assert.equal(x.status,0,file+': '+x.stderr);}
});
test('Percentiles are deterministic and never invent absent GPU timings',()=>{
 assert.equal(percentile([], .95),null);assert.equal(percentile([5,3,2,7,4],.5),4);
 const data=computeHardwareReport({intervals:[16,17,18],cpu:[1,2,4],gpu:[],reason:'cancelled'});
 assert.equal(data.gpuP95Ms,null);
 assert.equal(data.gpuSamples,0);
 assert.equal(data.valid,false);
});
test('Software and masked adapter labels cannot claim real hardware verification',()=>{
 for(const a of [{isSoftware:true,model:'SwiftShader'},{isSoftware:false,model:'masked'},
 {isSoftware:false,evidence:'hardware not independently verified',model:'NVIDIA'}]){
  const category=classifyRenderer(a);const report=computeHardwareReport({
   intervals:Array(60).fill(16),cpu:Array(60).fill(2),reason:'complete',
   meta:{adapter:a,quality:'high',durationMs:10500}
  });
  assert.equal(report.hardwareVerified,false);
  assert.ok(['software','unverified','reported-adapter-unverified'].includes(category));
  assert.equal(report.gpuP95Ms,null);
 }
});
test('Synthetic 60fps and stutter frame series are reported as distinct test classes',()=>{
 const quick=computeHardwareReport({intervals:Array(85).fill(16.6),cpu:Array(85).fill(4),
   reason:'complete',meta:{quality:'high',durationMs:10000}});
 const poor=computeHardwareReport({intervals:Array(85).fill(58),cpu:Array(85).fill(21),
   reason:'complete',meta:{quality:'high',durationMs:10000}});
 assert.equal(quick.score,'smooth-60');assert.equal(poor.score,'below-target');
 assert.equal(poor.recommendation,'try-balanced');
 assert.ok(quick.averageFps>55&&poor.averageFps<18);
});
test('A good result on the LOW tier is not proof of HIGH-tier frame rate',()=>{
 const report=computeHardwareReport({intervals:Array(85).fill(11),cpu:Array(85).fill(1),
   reason:'complete',meta:{quality:'low',durationMs:10000}});
 assert.equal(report.qualityTested,'low');
 assert.equal(report.recommendation,'try-next-tier-and-retest');
});
test('Frame timings use actual caller timestamps and honor warmup',()=>{
 const b=makeHardwareBenchmark({durationMs:1200,warmupMs:130});
 const setup=b.start(100,{quality:'medium',pixelRatio:1,postFX:'lite'});
 assert.equal(setup.durationMs,1200);
 for(let time=100;time<=1300;time+=16){b.record(time,4,{drawCalls:18,triangles:21000});}
 const out=b.result()||b.stop(1300,'complete');
 assert.ok(out.samples>45);
 assert.ok(out.durationMs>=1200);
 assert.equal(out.qualityTested,'medium');
 assert.ok(out.averageFps>60);
 assert.equal(out.render.drawCalls,18);
});
test('Cancelled, missing, corrupted and insufficient results remain inconclusive',()=>{
 const b=makeHardwareBenchmark({durationMs:10000});
 b.start(0,{quality:'high'});
 for(let now=0;now<400;now+=30)b.record(now,8);
 const r=b.stop(400,'tab-hidden');
 assert.equal(r.reason,'tab-hidden');assert.equal(r.valid,false);
 assert.equal(b.running(),false);
 assert.equal(b.stop(700,'complete'),r);
});
test('No storage, telemetry, network or hidden uploads from the measurement engine',()=>{
 const s=source(files[0])+source(files[1]);
 for(const bad of ['fetch(', 'XMLHttpRequest','sendBeacon','WebSocket','localStorage.','sessionStorage.']){
  assert.ok(!s.includes(bad),bad);
 }
 assert.ok(s.includes('navigator.clipboard?.writeText('),'manual-only sharing missing');
});
test('Optional GPU time is a real timer-query value, not CPU submission time',()=>{
 const done=[],ext={TIME_ELAPSED_EXT:88,GPU_DISJOINT_EXT:89};
 const fake={
  QUERY_RESULT_AVAILABLE:11,QUERY_RESULT:12,
  getExtension:name=>name==='EXT_disjoint_timer_query_webgl2'?ext:null,
  createQuery:()=>({id:1}),beginQuery:(...x)=>done.push(['begin',...x]),
  endQuery:x=>done.push(['end',x]),getParameter:k=>k===89?false:null,
  getQueryParameter:(q,k)=>k===11?true:7600000,
  deleteQuery:()=>{}
 };
 const t=makeGpuQueryTimer(fake);
 assert.equal(t.supported(),true);
 assert.equal(t.begin(),true);assert.equal(t.end(),true);
 const values=t.poll();
 assert.ok(Math.abs(values[0]-7.6)<.001);t.dispose();
 assert.ok(done.length===2);
 const off=makeGpuQueryTimer({getExtension:()=>null});
 assert.equal(off.supported(),false);
});
test('Renderer statistics are safe integer counters, never synthetic GPU FPS',()=>{
 const summary=fixedStats({info:{
  render:{calls:43,triangles:123456,points:54,lines:12},
  memory:{textures:18,geometries:80}
 }});
 assert.equal(summary.drawCalls,43);assert.equal(summary.triangles,123456);
 assert.equal(summary.textureCount,18);
});
test('Main render loop captures real frames and pauses mutation during benchmark tour',()=>{
 const app=source(files[2]),ui=source(files[1]),css=source('public/games/inherit/aaa-3d.css');
 for(const term of ['perfLab?.startFrame(time)','perfLab?.endFrame(time,cpuSubmissionMs)',
  'perfLab?.running()?0:','perfLab.moveCamera(time)','perfLab?.running()||d.body.classList.contains']){
  assert.ok(app.includes(term),term);
 }
 assert.match(ui,/test\.start\(performance\.now\(\)/);
 assert.match(ui,/test\.record\(now,submitMs/);
 assert.match(ui,/camera\.lookAt\(0,0,0\)/);
 assert.match(css,/aaa3d-benchmark-result/);
 assert.match(ui,/reducedMotion\(\)/);
});
console.log('INHERIT R18 honest on-device benchmarking:',passed,'checks passed');
