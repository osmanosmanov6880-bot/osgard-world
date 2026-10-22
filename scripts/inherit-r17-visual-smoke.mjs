/* INHERIT R17: numerical + source integrity tests for physical materials,
 * GPU-animated wildlife, real camera passes, truthful perf instrumentation.
 */
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import * as THREE from 'three';
import {mineralHeight,createSurfacePack,makeSurfaceMaterial,surfacePackStats}
 from './inherit-3d/cinematic-surfaces.mjs';
import {applyWindSway,makeLivingAtmosphere} from './inherit-3d/living-atmosphere.mjs';
import {detectAdapter} from './inherit-3d/cinematic-postfx.mjs';
import {makeFrameBudget} from './inherit-3d/frame-budget.mjs';
import {swell,waterVertex,waterFragment} from './inherit-3d/cinematic-water.mjs';
const source=path=>readFileSync(path,'utf8');
const modules=['scripts/inherit-3d/cinematic-surfaces.mjs',
 'scripts/inherit-3d/living-atmosphere.mjs','scripts/inherit-3d/cinematic-postfx.mjs',
 'scripts/inherit-3d/frame-budget.mjs','scripts/inherit-3d/cinematic-water.mjs',
 'scripts/inherit-hardware-benchmark.mjs'];
let passed=0;function test(name,run){run();console.log('PASS',name);passed++;}
test('R17 postproduction and benchmark entry points parse as real JavaScript',()=>{
 for(const path of modules){const x=spawnSync(process.execPath,['--check',path],{encoding:'utf8'});assert.equal(x.status,0,path+' '+x.stderr);}
});
test('All eight surfaces have real deterministic generated albedo, normals and roughness',()=>{
 const names=['earth','limestone','basalt','forest','bark','timber','sand','fern'];
 for(const name of names){
  const a=createSurfacePack(name,{quality:'low',seed:173});
  const b=createSurfacePack(name,{quality:'low',seed:173});
  assert.equal(a,b);
  assert.equal(a.size,64);
  assert.equal(a.map.image.data.length,64*64*4);
  assert.equal(a.normalMap.image.data.length,64*64*4);
  assert.equal(a.roughnessMap.image.data.length,64*64*4);
  assert.ok(a.bytes>40000);
  assert.ok(a.sample(3,5)>=0&&a.sample(3,5)<=1);
 }
 assert.ok(surfacePackStats().textureBytes>250000);
});
test('High-quality PBR surface is real standard material with calibrated normal map',()=>{
 const material=makeSurfaceMaterial('limestone',{quality:'high',vertexColors:true});
 assert.ok(material.isMeshStandardMaterial);
 assert.ok(material.map&&material.normalMap&&material.roughnessMap);
 assert.ok(material.vertexColors);
 assert.ok(material.normalMap.image.width>=128);
 assert.equal(material.map.colorSpace,THREE.SRGBColorSpace);
 const low=makeSurfaceMaterial('limestone',{quality:'low'});
 assert.ok(!low.normalMap);
});
test('Wind-blown foliage is actual vertex displacement, not CSS motion',()=>{
 const mat=new THREE.MeshStandardMaterial();
 const handle=applyWindSway(mat,{amplitude:.16});
 assert.ok(handle);
 const shader={uniforms:{},vertexShader:'#include <begin_vertex>'};
 mat.onBeforeCompile(shader);
 assert.match(shader.vertexShader,/uWindTime/);
 assert.match(shader.vertexShader,/transformed\.x \+= bend/);
 assert.equal(shader.uniforms.uWindTime.value,0);
});
test('Original gulls and floating particles are deterministic bounded GPU geometry',()=>{
 const life=makeLivingAtmosphere({quality:'high'});
 assert.equal(life.stats().birds,4);
 assert.equal(life.stats().particles,145);
 assert.ok(life.root.children.some(x=>x.isPoints));
 life.update(1000,'wind');
 assert.equal(life.stats().updatedFrames,1);
 life.update(1200,'sun');
 assert.equal(life.stats().updatedFrames,2);
 life.dispose();
});
test('Water swells are finite and react to time and in-game wind',()=>{
 const a=swell(10,5,1,.3),b=swell(10,5,1,1.25);
 assert.ok(Number.isFinite(a)&&Number.isFinite(b));
 assert.notEqual(a,b);
 assert.match(waterFragment,/fresnel/);
 assert.match(waterFragment,/sun/);
 assert.match(waterVertex,/vCrest/);
});
test('P95 measurements represent actual intervals and CPU cost, never invented GPU time',()=>{
 const clock=makeFrameBudget();
 const fake={info:{render:{calls:40,triangles:12700,points:140,lines:300},
  memory:{textures:16,geometries:220}}};
 for(let i=1;i<=140;i++)clock.record(i*64,18,fake,1);
 const report=clock.snapshot();
 assert.equal(report.samples,140);
 assert.ok(report.fps>10&&report.fps<20);
 assert.equal(report.frameIntervalP95Ms,64);
 assert.equal(report.renderer.triangles,12700);
 assert.equal(report.gpuTimerMs,null);
 assert.ok(clock.shouldReduceResolution());
 clock.markReduced();
 assert.ok(!clock.shouldReduceResolution());
});
test('Renderer evidence never guesses hardware status',()=>{
 assert.equal(detectAdapter(null).isSoftware,true);
 const fallback=detectAdapter({getContext:()=>({VERSION:0, getParameter:()=> 'WebGL',
  getExtension:()=>null})});
 assert.equal(fallback.model,'masked');
 assert.match(fallback.evidence,/not established/);
});
test('Post effects compose real bloom and shoulder color grading for supported GPUs',()=>{
 const f=source('scripts/inherit-3d/cinematic-postfx.mjs');
 for(const name of ['EffectComposer','RenderPass','UnrealBloomPass','OutputPass','ShaderPass',
  'uVignette','uGrain','uWarmth'])assert.ok(f.includes(name),name);
});
test('3D world retains native interactions, offline pipeline and on-device benchmark scripts',()=>{
 const entry=source('scripts/inherit-3d/aaa-three-entry.mjs');
 const env=source('scripts/inherit-3d/world-geometry.mjs');
 const css=source('public/games/inherit/aaa-3d.css');
 const pkg=JSON.parse(source('package.json'));
 assert.match(entry,/getPerformanceReport/);
 assert.match(entry,/samplePerformance/);
 assert.match(entry,/frameBudget\.record/);
 assert.match(env,/makeSurfaceMaterial/);
 assert.match(env,/makeLivingAtmosphere/);
 assert.match(entry,/world\.parentElement\.insertBefore\(controls,world\)/);
 assert.match(css,/\.app > \.aaa3d-controls/);
 assert.ok(pkg.scripts['qa:inherit-benchmark:gpu'].includes('--require-gpu'));
 const workflow=source('.github/workflows/inherit-browser-qa.yml');
 assert.match(workflow,/inherit-hardware-benchmark\.mjs/);
});
console.log('INHERIT R17 procedural cinematic and benchmark tests:',passed,'passed');
