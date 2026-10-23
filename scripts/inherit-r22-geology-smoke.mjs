import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import * as THREE from 'three';
import {makeCoastalGeology,geologyProfile} from './inherit-3d/coastal-geology.mjs';
import {makeShorelineSurf} from './inherit-3d/shoreline-surf.mjs';
let passed=0;const check=(name,fn)=>{fn();passed++;console.log('PASS',name)};
check('Two/three GPU batches of authentic coastal geometry with bounded LOD',()=>{
 const [low,medium,high]=['low','medium','high'].map(geologyProfile);
 assert.ok(high.instances>medium.instances&&medium.instances>low.instances);
 assert.ok(high.instances<1000&&high.batches===3&&low.batches===2);
});
check('Three material tiers physically place hundreds of finite nondegenerate instances',()=>{
 for(const tier of ['low','medium','high']){
  const coast=makeCoastalGeology({quality:tier}),p=geologyProfile(tier);
  assert.equal(coast.root.children.length,p.batches);
  assert.ok(coast.stats().triangles>p.instances);
  for(const mesh of coast.root.children){
   assert.ok(mesh.isInstancedMesh&&mesh.count>0);
   assert.ok(mesh.material.isMeshStandardMaterial);
   const m=new THREE.Matrix4();
   for(const index of [0,Math.floor(mesh.count/2),mesh.count-1]){
    mesh.getMatrixAt(index,m);
    assert.ok(m.elements.every(Number.isFinite));
    assert.ok(Math.abs(m.determinant())>0.000001);
   }
  }
  coast.dispose();
 }
});
check('Wet weather alters roughness without mutating the gameplay state',()=>{
 const coast=makeCoastalGeology({quality:'medium'}),tide=coast.stats();
 coast.setSeason('sun');const dry=coast.stats();
 assert.ok(tide.wetness>dry.wetness);
 assert.ok(tide.rockRoughness<dry.rockRoughness);
 assert.equal(dry.gameplayWrites,0);
 assert.equal(dry.assetRequests,0);coast.dispose();
});
check('Three-dimensional surf and rock details share the same island pipeline',()=>{
 const e=readFileSync('scripts/inherit-3d/aaa-three-entry.mjs','utf8');
 const w=readFileSync('scripts/inherit-3d/world-geometry.mjs','utf8');
 const coast=makeShorelineSurf({quality:'high'});
 assert.ok(coast.mesh.isMesh&&coast.mesh.material.isShaderMaterial);
 coast.dispose();
 assert.match(e,/active\?\.surf\?\.update/);
 assert.match(w,/makeCoastalGeology\(\{quality\}\)/);
 assert.match(w,/geology\.setSeason\(season\)/);
 assert.match(w,/surf\.setSeason\(season\)/);
 assert.match(e,/makeAdaptiveResolution/);
 assert.match(e,/getHardwareBenchmark/);
});
check('Both graphics components are offline and read-only',()=>{
 for(const path of ['scripts/inherit-3d/coastal-geology.mjs','scripts/inherit-3d/shoreline-surf.mjs']){
  const src=readFileSync(path,'utf8');
  assert.doesNotMatch(src,/\bfetch\s*\(|new WebSocket|localStorage|requestAnimationFrame\s*\(|InheritGame\.|saveDraft\s*\(/);
 }
});
console.log('INHERIT R22 coastal geology and on-device acceptance:',passed,'checks passed.');
