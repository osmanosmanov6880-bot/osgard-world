import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import * as THREE from 'three';
import {makeCoastalMicroBiomes,MICRO_BIOME_TIERS,marineProfile} from './inherit-3d/coastal-micro-biomes.mjs';
const source=path=>readFileSync(path,'utf8');
let passed=0;
function test(name,fn){fn();passed++;console.log('PASS',name);}
test('High, medium and low quality have independently bounded real meshes',()=>{
 assert.equal(Object.keys(MICRO_BIOME_TIERS).length,3);
 const high=marineProfile('high'),medium=marineProfile('medium'),low=marineProfile('low');
 assert.equal(high.groups,7);
 assert.ok(high.instances>medium.instances&&medium.instances>low.instances);
 assert.ok(high.instances<2200, 'Do not create an unbounded number of high-tier objects');
});
test('Real 3D instancing generates seven batches with valid matrices',()=>{
 for(const tier of ['low','medium','high']){
  const biome=makeCoastalMicroBiomes({quality:tier});
  const stat=biome.stats();
  assert.equal(stat.groups,7);
  assert.equal(stat.instances,marineProfile(tier).instances);
  assert.ok(stat.triangles>200&&stat.triangles<300000);
  assert.equal(biome.root.children.length,7);
  assert.ok(biome.root.children.every(x=>x.isInstancedMesh&&x.count>0));
  for(const mesh of biome.root.children){
   const m=new THREE.Matrix4();
   for(const i of [0,Math.floor(mesh.count/2),mesh.count-1]){
    mesh.getMatrixAt(i,m);
    assert.ok([...m.elements].every(Number.isFinite),mesh.name);
    assert.notEqual(m.determinant(),0);
   }
  }
  biome.dispose();
 }
});
test('High sculpted coastal details are deterministic at the same generation',()=>{
 const first=makeCoastalMicroBiomes({quality:'high'});
 const next=makeCoastalMicroBiomes({quality:'high'});
 const a=first.root.children[0],c=next.root.children[0],m1=new THREE.Matrix4(),m2=new THREE.Matrix4();
 for(let i of [0,13,45,99]){
  a.getMatrixAt(i,m1);c.getMatrixAt(i,m2);
  assert.deepEqual(m1.elements,m2.elements);
 }
 first.dispose();next.dispose();
});
test('Seasonal wet basalt, water roughness and shoreline are visual only',()=>{
 const biome=makeCoastalMicroBiomes({quality:'medium'});
 const rock=biome.root.children.find(m=>m.name.includes('shore basalt'));
 const tide=biome.setSeason('tide'),rough=rock.material.roughness;
 assert.ok(tide>.5);
 const dry=biome.setSeason('sun');
 assert.ok(dry<tide);
 assert.ok(rock.material.roughness>rough);
 const before=biome.stats();biome.update(2345);biome.update(2412);
 const after=biome.stats();
 assert.equal(after.season,'sun');
 assert.equal(after.animationFrames,before.animationFrames+2);
 assert.equal(after.gameplayObjectsCreated,0);
 assert.equal(after.texturesLoadedExternally,0);
 assert.equal(after.instances,before.instances);
 biome.dispose();
});
test('Quality-tier economics use fixed groups and no runtime fetch calls',()=>{
 const src=source('scripts/inherit-3d/coastal-micro-biomes.mjs');
 assert.doesNotMatch(src,/\bfetch\s*\(|\bWebSocket\s*\(|\blocalStorage\b|\bsaveDraft\b/);
 assert.match(src,/InstancedMesh/);
 assert.match(src,/registerWind/);
 assert.match(src,/clearcoat/);
 assert.match(src,/roughness/);
 assert.doesNotMatch(src,/requestAnimationFrame\s*\(/);
});
test('Biome water and reeds remain noninteractive native 3D scenery',()=>{
 const biome=makeCoastalMicroBiomes({quality:'low'});
 assert.equal(biome.root.userData.kind,'purely scenic instanced environment');
 assert.equal(biome.stats().gameplayObjectsCreated,0);
 assert.equal(biome.root.children.length,7);
 biome.dispose();
});
test('Existing cinematic world integrates the new seven real 3D detail layers',()=>{
 const world=source('scripts/inherit-3d/world-geometry.mjs');
 const entry=source('scripts/inherit-3d/aaa-three-entry.mjs');
 assert.match(world,/makeCoastalMicroBiomes/);
 assert.match(world,/microBiomes\.setSeason\(season\)/);
 assert.match(world,/microBiomes,?/);
 assert.match(entry,/microBiomes\?\.update\(/);
 assert.match(entry,/status\.coastDetails=/);
});
test('Hardware tests still require real frame data and never claim verified physical GPU',()=>{
 const sourceReport=source('scripts/inherit-3d/hardware-benchmark.mjs');
 assert.match(sourceReport,/hardwareVerified:false/);
 assert.match(sourceReport,/gpuTimerMeasured:/);
 const workflow=source('.github/workflows/inherit-browser-qa.yml');
 assert.match(workflow,/inherit-hardware-benchmark\.mjs/);
 assert.match(workflow,/--require-webgl/);
});
test('Cinematic high tier uses true edge-aware FXAA at physical viewport pixel ratio',()=>{
 const post=source('scripts/inherit-3d/cinematic-postfx.mjs');
 assert.match(post,/FXAAShader/);
 assert.match(post,/antialias=new ShaderPass\(FXAAShader\)/);
 assert.match(post,/antialias\.uniforms\.resolution\.value\.set\(1\/physicalWidth,1\/physicalHeight\)/);
 assert.match(post,/mode==='cinematic'\?5:mode==='lite'\?3:1/);
 assert.match(post,/quality==='high'&&!software/);
});
console.log('INHERIT R19 coastal micro-biome geometry + physical weather checks:',passed,'passed.');
