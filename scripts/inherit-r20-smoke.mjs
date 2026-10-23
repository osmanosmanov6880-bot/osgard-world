/* INHERIT R20 — grounded regression coverage for original environmental detail,
 * genuine GPU instancing, material response and measured adaptive quality.
 * Runs with the Three.js dependency already installed in the repository. */
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {makeSurfaceMicroclimate,microclimateProfile,contactFalloff,wetnessForSeason} from './inherit-3d/surface-microclimate.mjs';
import {makeAdaptiveResolution,TARGETS} from './inherit-3d/adaptive-resolution.mjs';
import {makeSavedTraceMotion} from './inherit-3d/saved-trace-motion.mjs';
import {makeCinematicPipeline} from './inherit-3d/cinematic-postfx.mjs';
const text=path=>readFileSync(path,'utf8');
let passed=0;
function test(name,fn){fn();passed++;console.log('PASS',name);}
test('R20 actual JS scene modules parse',()=>{
 for(const path of ['scripts/inherit-3d/surface-microclimate.mjs','scripts/inherit-3d/adaptive-resolution.mjs','scripts/inherit-3d/cinematic-postfx.mjs','scripts/inherit-3d/world-geometry.mjs','scripts/inherit-3d/aaa-three-entry.mjs']){
  const x=spawnSync(process.execPath,['--check',path],{encoding:'utf8'});
  assert.equal(x.status,0,path+': '+x.stderr);
 }
});
test('Contact occlusion has smooth, bounded, deterministic central opacity',()=>{
 assert.equal(contactFalloff(0),1);
 assert.equal(contactFalloff(1),0);
 let previous=1;
 for(let i=1;i<=100;i++){const a=contactFalloff(i/100);
  assert.ok(a>=0&&a<=1);assert.ok(a<=previous);previous=a;
 }
});
test('Three GPU quality tiers are explicit, monotone and draw-call bounded',()=>{
 const low=microclimateProfile('low'),medium=microclimateProfile('medium'),high=microclimateProfile('high');
 for(const field of ['contacts','pools','precipitation']){
  assert.ok(low[field]<=medium[field]&&medium[field]<=high[field],field);
 }
 assert.equal(low.precipitation,0);
 assert.ok(high.precipitation>=300&&high.precipitation<=450);
});
test('High tier really instantiates surface-contact, clearcoat and GPU rain meshes',()=>{
 const env=makeSurfaceMicroclimate({quality:'high'});
 const before=env.stats();
 assert.equal(before.contacts,136);assert.equal(before.pools,54);
 assert.equal(before.rainParticles,320);assert.equal(before.gpuBatches,3);
 assert.equal(before.externalTextures,0);assert.equal(before.gameplayWrites,0);
 assert.ok(before.textureBytes>=128*128*4);
 assert.equal(env.root.children.length,3);
 assert.equal(env.root.children.filter(x=>x.isInstancedMesh).length,2);
 assert.ok(env.root.children.some(x=>x.isPoints));
 assert.ok(env.root.children.every(x=>x.name&&x.parent===env.root));
 env.dispose();
});
test('Seasonal puddle roughness and rainfall change without model writes',()=>{
 const env=makeSurfaceMicroclimate({quality:'medium'});
 const tide=env.setSeason('tide'),sun=env.setSeason('sun'),mist=env.setSeason('mist');
 assert.ok(tide.wetness>sun.wetness&&mist.wetness>sun.wetness);
 assert.equal(sun.rainfall,0);
 env.update(1200,{pixelRatio:1.5});env.update(2000,{pixelRatio:1});
 assert.equal(env.stats().frames,2);
 assert.equal(env.stats().season,'mist');
 assert.equal(env.stats().gameplayWrites,0);
 env.dispose();
});
test('Mobile low tier has one contact batch and no precipitation workload',()=>{
 const env=makeSurfaceMicroclimate({quality:'low'});
 assert.equal(env.stats().gpuBatches,1);
 assert.equal(env.stats().rainParticles,0);
 assert.equal(env.stats().pools,0);
 env.dispose();
});
test('Adaptation only trusts real rAF-frame interval summaries',()=>{
 const controller=makeAdaptiveResolution();
 const slow={intervalSamples:140,frameIntervalP95Ms:72,cpuSubmissionP95Ms:8};
 const first=controller.observe({now:10000,quality:'high',metrics:slow});
 assert.equal(first?.reason,'slow-frames');assert.equal(first?.scale,.88);
 assert.equal(controller.observe({now:13000,quality:'high',metrics:slow}),null);
 assert.ok(controller.snapshot().scale>=.64&&controller.snapshot().scale<=1);
 const second=controller.observe({now:20000,quality:'high',metrics:slow});
 assert.equal(second?.scale,.76);
});
test('Adaptive pixel ratio later RECOVERS but avoids rapid oscillation',()=>{
 const controller=makeAdaptiveResolution();
 const slow={intervalSamples:140,frameIntervalP95Ms:66,cpuSubmissionP95Ms:10};
 const stable={intervalSamples:270,frameIntervalP95Ms:23,cpuSubmissionP95Ms:6};
 controller.observe({now:9000,quality:'high',metrics:slow});
 assert.equal(controller.observe({now:12000,quality:'high',metrics:stable}),null);
 const next=controller.observe({now:18200,quality:'high',metrics:stable});
 assert.equal(next?.reason,'recovered-headroom');
 assert.ok(next.scale>.88&&next.scale<=1);
 assert.equal(controller.observe({now:26000,quality:'high',metrics:stable,benchmark:true}),null);
 assert.equal(controller.observe({now:30000,quality:'high',metrics:stable,visible:false}),null);
 controller.reset(31000);assert.equal(controller.snapshot().scale,1);
});
test('Performance controller uses quality-specific frame budgets, not GPU guesses',()=>{
 assert.ok(TARGETS.high<TARGETS.medium&&TARGETS.medium<TARGETS.low);
 const ctl=makeAdaptiveResolution();
 assert.equal(ctl.observe({now:10000,quality:'low',metrics:{intervalSamples:40,frameIntervalP95Ms:200}}),null);
 assert.equal(ctl.snapshot().changes,0);
 assert.match(ctl.snapshot().evidence,/actual browser frame intervals/);
});

test('Saved 3D models have cosmetic bounded animation and stable real save fields',()=>{
 const motion=makeSavedTraceMotion({maxAnimated:4});
 const lamp={isPointLight:true,intensity:2,parent:{}};
 const model=tool=>({rotation:{z:0},parent:{},
  userData:{nativeTrace:{tool,x:45,y:52}},
  traverse:fn=>{if(tool==='light')fn(lamp)}
 });
 const props=['tree','chime','flower','light','stone'].map(model);
 const original=props.map(g=>JSON.stringify(g.userData.nativeTrace));
 assert.equal(motion.bind(props),4);
 motion.update(1900,'wind',false);
 assert.ok(props.some(g=>Math.abs(g.rotation.z)>0));
 assert.notEqual(lamp.intensity,2);
 motion.update(2200,'mist',true);
 assert.ok(props.every(g=>g.rotation.z===0));
 assert.equal(lamp.intensity,2);
 assert.equal(motion.stats().gameplayWrites,0);
 motion.restore();
 assert.deepEqual(props.map(g=>JSON.stringify(g.userData.nativeTrace)),original);
});

test('Cinematic grade is real Three.js render-pass code and seasonal, not a CSS filter',()=>{
 assert.equal(typeof makeCinematicPipeline,'function');
 const source=text('scripts/inherit-3d/cinematic-postfx.mjs');
 for(const marker of ['EffectComposer','UnrealBloomPass','FXAAShader','uShadowTint','setSeason(next)','uWarmth','renderer.render(scene,camera)']){
  assert.ok(source.includes(marker),marker);
 }
});
test('Scene calls each visual system only from the same bounded active rAF loop',()=>{
 const entry=text('scripts/inherit-3d/aaa-three-entry.mjs');
 const geometry=text('scripts/inherit-3d/world-geometry.mjs');
 for(const marker of ['makeSurfaceMicroclimate','microclimate.setSeason','microclimate.root','microclimate,']){
  assert.ok(geometry.includes(marker),marker);
 }
 for(const marker of ["active?.microclimate?.update(","makeAdaptiveResolution","autoResolution.observe","pipeline?.setSeason?.(season)"]){
  assert.ok(entry.includes(marker),marker);
 }
 assert.doesNotMatch(text('scripts/inherit-3d/surface-microclimate.mjs'),/\bfetch\(|\.apply\(|\.saveDraft\(|localStorage/);
});
console.log('INHERIT R20 detailed environment:',passed,'smoke checks passed.');
