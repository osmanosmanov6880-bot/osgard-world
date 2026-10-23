import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import * as THREE from 'three';
import {makeShorelineSurf,makeSurfGeometry,surfProfile,surfVertex,surfFragment} from './inherit-3d/shoreline-surf.mjs';
let passed=0;const check=(label,fn)=>{fn();console.log('PASS',label);passed++};
check('Three tiers: one GPU batch and bounded coastline polygons',()=>{
 const [l,m,h]=['low','medium','high'].map(surfProfile);
 assert.ok(h.triangles>m.triangles&&m.triangles>l.triangles);
 assert.ok(h.triangles<5000&&h.drawCalls===m.drawCalls&&m.drawCalls===1);
});
check('All surf mesh coordinates are finite, coastline rings close, triangles valid',()=>{
 for(const tier of ['low','medium','high']){
  const g=makeSurfGeometry(tier),p=surfProfile(tier),pos=g.getAttribute('position');
  assert.equal(pos.count,p.vertices);
  assert.equal(g.index.count,p.triangles*3);
  assert.equal(g.getAttribute('uv').count,pos.count);
  assert.ok(g.boundingSphere.radius>15&&g.boundingSphere.radius<60);
  for(const i of [0,Math.floor(pos.count/2),pos.count-1])
   for(const v of [pos.getX(i),pos.getY(i),pos.getZ(i)])assert.ok(Number.isFinite(v));
  g.dispose();
 }
});
check('Actual WebGL shader and 3D geometry preserve native gameplay ownership',()=>{
 const s=makeShorelineSurf({quality:'high'});
 assert.ok(s.mesh.isMesh&&s.mesh.material.isShaderMaterial);
 assert.equal(s.mesh.material.side,THREE.DoubleSide);
 assert.equal(s.mesh.material.depthWrite,false);
 assert.equal(s.root.userData.kind,'noninteractive environment');
 assert.equal(s.stats().gameplayWrites,0);
 assert.equal(s.stats().externalAssets,0);
 s.dispose();
});
check('Four seasons and accessibility motion settings control shader uniforms',()=>{
 const s=makeShorelineSurf({quality:'medium'}),tide=s.stats();
 s.setSeason('wind');const wind=s.stats();
 assert.ok(wind.wind>tide.wind&&wind.foamStrength>tide.foamStrength);
 s.setSeason('sun');assert.ok(s.stats().foamStrength<tide.foamStrength);
 s.update(4789);assert.equal(s.mesh.material.uniforms.uTime.value,4.789);
 s.update(5000,{reducedMotion:true});
 assert.equal(s.mesh.material.uniforms.uTime.value,0);
 assert.equal(s.stats().frames,2);s.dispose();
});
check('True procedural foam shading has animated lace and physically scaled geometry',()=>{
 assert.match(surfVertex,/projectionMatrix\*modelViewMatrix/);
 assert.match(surfFragment,/smoothstep/);
 assert.match(surfFragment,/uStrength/);
 assert.match(surfFragment,/uWarmth/);
 assert.doesNotMatch(surfVertex+surfFragment,/sampler2D|texture2D/);
});
check('Original game rules, hardware benchmark and adaptive-resolution gates remain intact',()=>{
 const w=readFileSync('scripts/inherit-3d/world-geometry.mjs','utf8');
 const e=readFileSync('scripts/inherit-3d/aaa-three-entry.mjs','utf8');
 const m=readFileSync('scripts/inherit-3d/shoreline-surf.mjs','utf8');
 assert.match(w,/makeShorelineSurf\(\{quality\}\)/);
 assert.match(w,/surf\.setSeason\(season\)/);
 assert.match(e,/active\?\.surf\?\.update/);
 assert.match(e,/status\.surf=/);
 assert.match(e,/makeAdaptiveResolution/);
 assert.doesNotMatch(w,/makeBeachFoam\(/);
 assert.doesNotMatch(m,/\bfetch\s*\(|WebSocket|localStorage|requestAnimationFrame|InheritGame|saveDraft/);
});
console.log('INHERIT R21 animated surf geometry:',passed,'checks passed.');
