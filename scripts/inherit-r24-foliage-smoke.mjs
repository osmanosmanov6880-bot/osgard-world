/* R24: physically sculpted leaf silhouettes / instanced PBR / deterministic LOD */
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import * as THREE from 'three';
import {makeFineFoliage,leafRibbonGeometry,fineFoliageProfile} from './inherit-3d/fine-foliage.mjs';
import {makeLivingAtmosphere} from './inherit-3d/living-atmosphere.mjs';
let passed=0;
const test=(name,run)=>{run();passed++;console.log('PASS',name)};
const trees=[
 {x:2,y:1,z:3,size:1.15,hue:.4},
 {x:-5,y:.8,z:7,size:.93,hue:.2},
 {x:4,y:1.1,z:-6,size:1.04,hue:.7}
];
test('Three LODs are bounded and low-tier adds no costly leaf draw calls',()=>{
 const [l,m,h]=['low','medium','high'].map(tier=>fineFoliageProfile(tier,trees.length));
 assert.equal(l.leaves,0);assert.equal(l.drawCalls,0);
 assert.ok(h.leaves>m.leaves&&m.leaves>0);
 assert.equal(h.drawCalls,1);assert.equal(m.drawCalls,1);
 assert.ok(h.triangles>m.triangles*1.5);
 assert.ok(fineFoliageProfile('high',1000).leaves<=200*68);
});
test('Actual curved individual leaves have finite normals and bounded triangles',()=>{
 const g=leafRibbonGeometry(),p=g.getAttribute('position'),n=g.getAttribute('normal');
 assert.equal(p.count,14);
 assert.equal(n.count,p.count);
 assert.equal(g.index.count,36);
 assert.ok(g.boundingSphere.radius>.3&&g.boundingSphere.radius<1.2);
 for(let i=0;i<p.count;i++)for(const v of [p.getX(i),p.getY(i),p.getZ(i),n.getX(i),n.getY(i),n.getZ(i)])
  assert.ok(Number.isFinite(v));
 g.dispose();
});
test('High-tier uses physically shaded PBR normals and one draw call for real leaf mesh',()=>{
 const fine=makeFineFoliage({quality:'high',trees}),m=fine.mesh;
 assert.equal(fine.root.children.length,1);
 assert.ok(m.isInstancedMesh&&m.material.isMeshStandardMaterial);
 assert.ok(m.material.normalMap&&m.material.roughnessMap);
 assert.equal(m.material.side,THREE.DoubleSide);
 assert.equal(m.count,trees.length*68);
 assert.equal(fine.stats().drawCalls,1);
 assert.equal(fine.stats().gameplayWrites,0);
 assert.equal(fine.stats().externalAssets,0);
 fine.dispose();
});
test('Leaf placement is deterministic with physical matrices, individual color',()=>{
 const first=makeFineFoliage({quality:'medium',trees});
 const second=makeFineFoliage({quality:'medium',trees});
 assert.deepEqual(Array.from(first.mesh.instanceMatrix.array),
  Array.from(second.mesh.instanceMatrix.array));
 assert.deepEqual(Array.from(first.mesh.instanceColor.array),
  Array.from(second.mesh.instanceColor.array));
 const mat=new THREE.Matrix4();
 for(let i of [0,Math.floor(first.mesh.count/2),first.mesh.count-1]){
  first.mesh.getMatrixAt(i,mat);
  assert.ok(mat.elements.every(Number.isFinite));
  assert.ok(Math.abs(mat.determinant())>0.0000001);
 }
 first.dispose();second.dispose();
});
test('Actual wind engine deforms leaf vertices, not a CSS fake animation',()=>{
 const life=makeLivingAtmosphere({quality:'high'});
 const fine=makeFineFoliage({quality:'high',trees,registerWind:life.addWindMaterial});
 const shader={uniforms:{},vertexShader:'#include <begin_vertex>'};
 fine.mesh.material.onBeforeCompile(shader);
 assert.match(shader.vertexShader,/uWindTime/);
 assert.match(shader.vertexShader,/bend/);
 assert.ok(shader.uniforms.uWindTime);
 fine.dispose();life.dispose?.();
});
test('Season updates wetness and material roughness without changing games',()=>{
 const fine=makeFineFoliage({quality:'high',trees});
 const wet=fine.stats();
 fine.setSeason('sun');const dry=fine.stats();
 assert.ok(wet.wetness>dry.wetness);
 assert.ok(wet.roughness<dry.roughness);
 const low=makeFineFoliage({quality:'low',trees});
 assert.equal(low.root.children.length,0);
 assert.equal(low.stats().leaves,0);
 fine.dispose();low.dispose();
});
test('Real game scene registers wind, season, one leaf batch, and native-save ownership',()=>{
 const source=readFileSync('scripts/inherit-3d/world-geometry.mjs','utf8');
 const entry=readFileSync('scripts/inherit-3d/aaa-three-entry.mjs','utf8');
 assert.match(source,/makeFineFoliage\(\{quality,trees,registerWind:life\.addWindMaterial\}\)/);
 assert.match(source,/fineFoliage\.setSeason\(season\)/);
 assert.match(entry,/status\.fineFoliage=built\.fineFoliage\?\.stats/);
 assert.match(entry,/status\.fineFoliage=seasonalScene\?\.fineFoliage\?\.stats/);
 assert.doesNotMatch(readFileSync('scripts/inherit-3d/fine-foliage.mjs','utf8'),
  /\bfetch\s*\(|WebSocket|requestAnimationFrame\s*\(|saveDraft|localStorage|InheritGame/);
});
console.log('INHERIT R24 real PBR fine-foliage:',passed,'checks passed');
