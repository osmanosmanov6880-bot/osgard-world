// R16: source-backed, runnable checks of the real WebGL3D renderer.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {coastline,fieldHeight,hash,noise,screenToTerrain,nativeValidPoint,stableObjects,vegetation,worldStateSignature} from './inherit-3d/terrain-core.mjs';
import * as THREE from 'three';
import {makeTrace,disposeTraces,premiumAssetsInfo} from './inherit-3d/trace-models.mjs';
const get=path=>readFileSync(path,'utf8');
const root='public/games/inherit/';
const src=['scripts/inherit-3d/aaa-three-entry.mjs','scripts/inherit-3d/world-geometry.mjs','scripts/inherit-3d/trace-models.mjs','scripts/inherit-3d/premium-sculptures.mjs','scripts/inherit-3d/terrain-core.mjs'];
const index=get(root+'index.html'),css=get(root+'aaa-3d.css'),sw=get(root+'sw.js'),
  entry=get(src[0]),world=get(src[1]),props=get(src[2]),pkg=JSON.parse(get('package.json'));
let total=0;const check=(title,fn)=>{fn();console.log('PASS',title);total++};
check('Source files are valid ES modules under Node',()=>{
 for(const path of src){const run=spawnSync(process.execPath,['--check',path],{encoding:'utf8'});assert.equal(run.status,0,path+': '+run.stderr);}
});
check('Offline browser bundle compiles the exact installed Three.js API',()=>{
 const run=spawnSync(process.execPath,['scripts/build-inherit-3d.mjs','--check'],{encoding:'utf8',timeout:90000});
 assert.equal(run.status,0,run.stdout+run.stderr);
});
check('All 10 new premium sculptures produce distinct finite high-detail 3D geometry',()=>{
 const kinds=['tree','stone','light','path','flower','arch','chime','moss','cairn','marker'];
 const holder=new THREE.Group();
 let highTriangles=0,mediumTriangles=0;
 for(const kind of kinds){
  const high=makeTrace(kind,{quality:'high',seed:6880,cast:true});
  const medium=makeTrace(kind,{quality:'medium',seed:6880,cast:false});
  const classic=makeTrace(kind,{quality:'low'});
  assert.ok(high.userData.detailTriangles>medium.userData.detailTriangles,kind+' is not detailed');
  assert.ok(high.userData.detailDrawCalls<=14,kind+' exceeds material batching budget');
  assert.ok(high.userData.detailTriangles>=120,kind+' has too few triangles to be an upgraded 3D model');
  assert.ok(high.children.some(c=>c.isMesh),kind+' has no real mesh');
  assert.ok(classic.children.length>0,kind+' loses its fallback mesh');
  for(const obj of high.children){
   if(!obj.isMesh)continue;
   const position=obj.geometry.attributes.position?.array;
   assert.ok(position?.length>0);
   for(const value of position)assert.ok(Number.isFinite(value),kind+' has invalid geometry');
   assert.ok(obj.material.isMeshStandardMaterial,kind+' is missing PBR materials');
  }
  highTriangles+=high.userData.detailTriangles;
  mediumTriangles+=medium.userData.detailTriangles;
  holder.add(high,medium,classic);
 }
 assert.ok(highTriangles>mediumTriangles*1.15);
 assert.ok(highTriangles>7500,'Aggregate high quality meshes remain too cheap');
 const info=premiumAssetsInfo();
 assert.deepEqual(info.quality,['high','medium']);
 assert.ok(info.materials>=25);
 assert.equal(info.bumpTextures,3);
 assert.equal(info.batched,true);
 assert.equal(info.externalAssets,0);
 disposeTraces(holder);
 assert.equal(holder.children.length,0);
});
check('Premium models reuse exactly three deterministic local height textures without downloads',()=>{
 const premium=get('scripts/inherit-3d/premium-sculptures.mjs');
 assert.match(premium,/new THREE\.DataTexture/);
 assert.match(premium,/mergeGeometries\(geometryList,false\)/);
 assert.match(premium,/grainBark/);
 assert.match(premium,/grainStone/);
 assert.match(premium,/grainBrass/);
 assert.doesNotMatch(premium,/fetch\s*\(|https?:\/\//);
});
check('Dense saved worlds choose quality by visible center and cap local point lighting',()=>{
 assert.match(entry,/const detailBudget=quality==='high'/);
 assert.match(entry,/tiers\.set\(item\.i/);
 assert.match(entry,/allowLight:lightAllowed/);
 assert.match(entry,/activeLanterns<2/);
 assert.match(entry,/status\.detailTriangles=triangles/);
 assert.match(entry,/syncState\(true\);renderOnce/);
 assert.match(entry,/const traceCache=new Map\(\)/);
 assert.match(entry,/status\.cachedTraces=reused/);
 assert.match(entry,/for\(const \[cacheKey,node\] of traceCache\)/);
});
check('Instanced environment includes multi-layer canopies, woodland flora and a real footbridge',()=>{
 for(const term of ['crownsPerTree','branchPerTree','new THREE.InstancedMesh','grassGoal','blossomGoal','plankCount','bridge.add(deck)'])
  assert.ok(world.includes(term),'Missing '+term);
});
check('Native game and 3D scene have no new game mutation API',()=>{
 assert.match(entry,/game\.snapshot\(\)/);
 assert.doesNotMatch(entry,/game\.apply\s*\(|saveDraft\s*\(|\.setMode\s*\(|S\.objects\.push|S\.budget\s*--|fetch\s*\(/);
 assert.doesNotMatch(world,/fetch\s*\(|new WebSocket\s*\(/);
});
check('All 10 genuine saved prop types are modeled as 3D geometries',()=>{
 for(const name of ['tree','stone','light','path','flower','arch','chime','moss','cairn','marker'])
   assert.ok(props.includes("tool==='"+name+"'"),name);
});
check('Terrain generation is deterministic, bounded, finite and non-flat',()=>{
 const expected=hash(1,3,173);assert.equal(hash(1,3,173),expected);
 const heights=[];
 for(let i=-20;i<=20;i+=4){for(let z=-17;z<=17;z+=3){
  const h=fieldHeight(i,z);assert.ok(Number.isFinite(h));heights.push(h);
  assert.ok(noise(i*.17,z*.17)>=0&&noise(i*.17,z*.17)<=1);
 }}
 assert.ok(Math.max(...heights)-Math.min(...heights)>.45);
 const coast=coastline(Math.PI*.32);assert.ok(Math.abs(coast.x)<25&&Math.abs(coast.z)<22);
});
check('Projected screen coordinates preserve actual clickable game region',()=>{
 for(const x of [8,32,50,75,91])for(const y of [12,30,50,77]){
  const p=screenToTerrain(x,y,1.84,29,.67);
  assert.ok([p.x,p.y,p.z].every(Number.isFinite));
  assert.ok(Math.abs(p.x)<27);
 }
 assert.equal(nativeValidPoint(8,12),true);
 assert.equal(nativeValidPoint(7.9,12),false);
 assert.equal(nativeValidPoint(50,77.1),false);
});
check('Saved world data is filtered without writes or fabricated history',()=>{
 const original={generation:177,budget:12,objects:[
  {tool:'tree',x:45,y:44},{tool:'arch',x:65,y:50},{tool:'other',x:40,y:45},
  {tool:'light',x:200,y:12},{tool:'stone',x:51,y:62}
 ],ownerId:'private-value',pending:[]};
 const previous=JSON.stringify(original),items=stableObjects(original);
 assert.equal(items.length,3);
 assert.equal(JSON.stringify(original),previous);
 assert.ok(!worldStateSignature(original).includes('private-value'));
 assert.equal(worldStateSignature(original),worldStateSignature(JSON.parse(previous)));
});
check('Vegetation is reproducible and capped for mobile scenes',()=>{
 const a=vegetation(173,34),b=vegetation(173,34);
 assert.deepEqual(a,b);assert.ok(a.length>9&&a.length<=34);
 assert.ok(a.every(p=>Number.isFinite(p.x)&&Number.isFinite(p.z)));
});
check('True GPU rendering includes a lit PBR world and water animation',()=>{
 for(const keyword of ['WebGLRenderer','OrthographicCamera','ACESFilmicToneMapping','HemisphereLight','DirectionalLight','shadowMap','requestAnimationFrame','IntersectionObserver'])
  assert.ok(entry.includes(keyword),keyword);
 for(const keyword of ['ShaderMaterial','InstancedMesh','vertexColors:true','cliffGeometry','makeBeachFoam','makeRiver','makeRoad'])
  assert.ok(world.includes(keyword),keyword);
});
check('Scene does not steal native pointer events',()=>{
 assert.match(css,/pointer-events:none/);
 assert.match(entry,/canvas\.style\.pointerEvents='none'/);
 assert.match(entry,/world\.addEventListener\('click',event=>/);
 assert.match(entry,/raycaster\.intersectObjects\(traceRoot\.children,true\)/);
 assert.match(entry,/target\.click\(\)/);
 assert.match(entry,/event\.stopImmediatePropagation\(\)/);
});
check('WebGL loss, reduced motion and offline 2D fallback are implemented',()=>{
 assert.match(entry,/webglcontextlost/);
 assert.match(entry,/webglcontextrestored/);
 assert.match(entry,/prefers-reduced-motion:reduce/);
 assert.match(entry,/setMode\(false,'gpu-lost'\)/);
 assert.match(css,/#island\.aaa3d-active>/);
});
check('Player enables 3D with real controls and can switch quality and 2D',()=>{
 for(const name of ['aaa3d-switch','aaa3d-orbit','aaa3d-quality'])assert.ok(entry.includes(name));
 assert.match(entry,/localStorage\.setItem\('inherit:3d:v1'/);
 assert.match(entry,/getState:\(\)=>/);
});
check('Build provides real locally bundled Three.js before Vite',()=>{
 assert.equal(pkg.scripts.prebuild,'node scripts/build-inherit-3d.mjs');
 assert.equal(pkg.scripts.predev,'node scripts/build-inherit-3d.mjs');
 assert.equal(pkg.scripts['qa:inherit-3d'],'node scripts/inherit-3d-smoke.mjs');
 assert.equal(pkg.dependencies.three,'^0.186.0');
});
check('Canonical game and PWA load CSS and generated WebGL bundle',()=>{
 assert.ok(index.includes('./aaa-3d.css')&&index.includes('./aaa-three.bundle.js'));
 assert.match(sw,/inherit-shell-v28/);
 assert.ok(sw.includes('/games/inherit/aaa-three.bundle.js'));
 assert.ok(sw.includes('/games/inherit/aaa-3d.css'));
});
check('Scene keeps RU, EN, ZH localization and accessible buttons',()=>{
 for(const code of ['ru:','en:','zh:'])assert.ok(entry.includes(code),code);
 assert.match(entry,/aria-live/);
 assert.match(css,/focus-visible/);
 assert.match(css,/@media\(max-width:740px\)/);
});
console.log('INHERIT R16 true 3D smoke:',total,'checks passed');
