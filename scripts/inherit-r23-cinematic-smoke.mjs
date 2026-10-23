/* INHERIT R23: executable geometry/material and hardware-proof invariants. */
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import * as THREE from 'three';
import {SKY_TIERS,makeSkyPanorama,makeSkyLighting} from './inherit-3d/sky-reflections.mjs';
import {seaStackProfile,makeErodedStackGeometry,makeSeaStackEnvironment} from './inherit-3d/sea-stack-erosion.mjs';
let checks=0;
function test(name,action){action();checks++;console.log('PASS',name)}
const read=path=>readFileSync(path,'utf8');

test('New cinematic engines and integration files parse as ES modules',()=>{
 for(const path of ['scripts/inherit-3d/sky-reflections.mjs',
  'scripts/inherit-3d/sea-stack-erosion.mjs','scripts/inherit-3d/cinematic-postfx.mjs',
  'scripts/inherit-3d/world-geometry.mjs','scripts/inherit-3d/aaa-three-entry.mjs']){
  const run=spawnSync(process.execPath,['--check',path],{encoding:'utf8'});
  assert.equal(run.status,0,path+': '+run.stderr);
 }
});
test('Local season radiance panoramas contain true bounded equirectangular RGB',()=>{
 for(const tier of ['medium','high']){
  for(const season of ['tide','sun','wind','mist']){
   const t=makeSkyPanorama(season,{quality:tier}),p=SKY_TIERS[tier];
   assert.ok(t.isDataTexture);
   assert.equal(t.image.data.byteLength,p.width*p.height*4);
   assert.equal(t.mapping,THREE.EquirectangularReflectionMapping);
   assert.equal(t.colorSpace,THREE.SRGBColorSpace);
   assert.notEqual(t.image.data[0],t.image.data[p.width*(p.height-1)*4]);
   t.dispose();
  }
 }
 assert.equal(makeSkyPanorama('sun',{quality:'low'}),null);
});
test('Image-based lighting responds to seasons and skips software rasterizers',()=>{
 const scene=new THREE.Scene(),sky=makeSkyLighting({quality:'medium'});
 assert.ok(sky.setSeason('tide',scene)?.isDataTexture);
 const first=scene.environment;
 sky.setSeason('sun');
 assert.notEqual(scene.environment,first);
 assert.ok(scene.environmentIntensity>0);
 assert.equal(sky.stats().generated,2);
 assert.equal(sky.stats().gameplayWrites,0);
 sky.dispose();
 assert.equal(scene.environment,null);
 const software=makeSkyLighting({quality:'high',software:true});
 assert.equal(software.setSeason('tide',scene),null);
 assert.equal(software.stats().textureBytes,0);
 software.dispose();
});
test('Real erosion mesh has finite displaced ring normals and top cap',()=>{
 for(const tier of ['low','medium','high']){
  const g=makeErodedStackGeometry(tier),p=seaStackProfile(tier);
  const positions=g.getAttribute('position'),normals=g.getAttribute('normal');
  assert.equal(positions.count,(p.rings+1)*(p.segments+1)+1);
  assert.equal(normals.count,positions.count);
  assert.ok(g.index.count>p.segments*p.rings*6);
  assert.ok(g.boundingSphere.radius>2&&g.boundingSphere.radius<9);
  for(const i of [0,Math.floor(positions.count/2),positions.count-1]){
   assert.ok([positions.getX(i),positions.getY(i),positions.getZ(i),
    normals.getX(i),normals.getY(i),normals.getZ(i)].every(Number.isFinite));
  }
  g.dispose();
 }
});
test('LOD profiles cap GPU draw calls and provide nondegenerate real rock batches',()=>{
 const [low,medium,high]=['low','medium','high'].map(seaStackProfile);
 assert.ok(low.instances<medium.instances&&medium.instances<high.instances);
 assert.equal(low.drawCalls,2);
 assert.equal(high.drawCalls,4);
 assert.ok(high.spray>medium.spray&&medium.spray>0);
 for(const tier of ['low','medium','high']){
  const coast=makeSeaStackEnvironment({quality:tier}),stat=coast.stats();
  assert.ok(stat.triangles>200&&stat.triangles<65000);
  assert.equal(coast.root.userData.kind,'decorative noninteractive 3D');
  const groups=coast.root.children.filter(o=>o.isInstancedMesh);
  assert.ok(groups.length>=2);
  for(const obj of groups){
   const m=new THREE.Matrix4();
   for(const i of [0,Math.floor(obj.count/2),obj.count-1]){
    obj.getMatrixAt(i,m);
    assert.ok(m.elements.every(Number.isFinite));
    assert.ok(Math.abs(m.determinant())>.00001);
   }
  }
  coast.dispose();
 }
});
test('GPU sea spray animation pauses when the OS requests reduced motion',()=>{
 const coast=makeSeaStackEnvironment({quality:'high'});
 const points=coast.root.children.find(o=>o.isPoints);
 assert.ok(points?.material?.isShaderMaterial);
 coast.update(4750,{pixelRatio:1.5});
 assert.equal(points.material.uniforms.uTime.value,4.75);
 coast.update(6000,{reducedMotion:true});
 assert.equal(points.material.uniforms.uTime.value,0);
 const wet=coast.stats();coast.setSeason('wind');const dry=coast.stats();
 assert.ok(dry.wetness<wet.wetness);
 assert.equal(dry.gameplayWrites,0);
 assert.equal(dry.externalTextures,0);
 coast.dispose();
});
test('Cinematic sea stacks use authentic PBR normals and roughness maps',()=>{
 const coast=makeSeaStackEnvironment({quality:'high'});
 const rocks=coast.root.children.find(o=>o.isInstancedMesh);
 assert.ok(rocks.material.normalMap);
 assert.ok(rocks.material.roughnessMap);
 assert.ok(rocks.material.vertexColors);
 coast.dispose();
});
test('Real world integrates IBL, seasonal sea stacks, film halation and fallback',()=>{
 const entry=read('scripts/inherit-3d/aaa-three-entry.mjs');
 const world=read('scripts/inherit-3d/world-geometry.mjs');
 const grade=read('scripts/inherit-3d/cinematic-postfx.mjs');
 assert.match(world,/makeSeaStackEnvironment\(\{quality\}\)/);
 assert.match(world,/seaStacks\.setSeason\(season\)/);
 assert.match(entry,/active\?\.seaStacks\?\.update/);
 assert.match(entry,/skyLighting\?\.setSeason/);
 assert.match(entry,/if\(!status\.available\|\|!traceRoot\|\|!scene\|\|!renderer\)return/);
 assert.match(entry,/makeAdaptiveResolution/);
 assert.match(grade,/uHalation/);
 assert.match(grade,/uTexelSize/);
 assert.match(grade,/mode==='cinematic'\?p\.halation:0/);
 assert.match(grade,/if\(grade\)grade\.uniforms\.uTexelSize/);
 assert.match(read('scripts/inherit-3d/hardware-benchmark.mjs'),/hardwareVerified:false/);
});
test('Original R23 scene uses no network, save writes or separate frame loops',()=>{
 for(const path of ['scripts/inherit-3d/sea-stack-erosion.mjs','scripts/inherit-3d/sky-reflections.mjs']){
  const src=read(path);
  assert.doesNotMatch(src,/\bfetch\s*\(|new WebSocket|requestAnimationFrame\s*\(|InheritGame\.|localStorage|saveDraft\s*\(/);
 }
});
console.log('INHERIT R23 high-detail native 3D and device evidence:',checks,'tests passed.');
