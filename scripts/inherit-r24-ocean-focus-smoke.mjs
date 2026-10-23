/* INHERIT R24 — ocean cinematic shading, LOD and game-control contracts */
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {horizonCoverage,swell,waterVertex,waterFragment} from './inherit-3d/cinematic-water.mjs';
let passed=0;const test=(title,fn)=>{fn();passed++;console.log('PASS',title)};
const read=file=>readFileSync(file,'utf8');
test('Water module and scene entry are valid ES modules',()=>{
 for(const path of ['scripts/inherit-3d/cinematic-water.mjs','scripts/inherit-3d/aaa-three-entry.mjs','scripts/inherit-3d/world-geometry.mjs']){
  const result=spawnSync(process.execPath,['--check',path],{encoding:'utf8'});
  assert.equal(result.status,0,path+' '+result.stderr);
 }
});
test('Sea alpha fades smoothly before the rectangle boundary in every season',()=>{
 for(const start of [.53,.66,.70]){
  assert.equal(horizonCoverage(0,0,start),1);
  assert.equal(horizonCoverage(70,0,start),0);
  assert.equal(horizonCoverage(0,55,start),0);
  assert.equal(horizonCoverage(-70,-55,start),0);
  for(let i=1;i<90;i++){
   const a=horizonCoverage((i-1)*70/90,0,start);
   const b=horizonCoverage(i*70/90,0,start);
   assert.ok(a>=b&&a>=0&&b<=1);
   assert.ok(a-b<.07,'Horizon opacity must never jump abruptly');
  }
 }
});
test('Sea shader interpolates physical camera-space normals and Schlick Fresnel',()=>{
 assert.match(waterVertex,/normalMatrix\*vec3\(0.,0.,1.\)/);
 assert.match(waterVertex,/vEyeAxisX/);
 assert.match(waterVertex,/vSunEye/);
 assert.match(waterFragment,/dot\(n,view\)/);
 assert.match(waterFragment,/pow\(1.0-ndv,5.0\)/);
 assert.match(waterFragment,/sun=pow/);
 assert.match(waterFragment,/fresnel/);
 assert.match(waterFragment,/smoothstep\(uHorizonFade,1.0,ellipse\)/);
 assert.match(waterFragment,/gl_FragColor=vec4\(color,clamp\(oceanAlpha/);
 assert.doesNotMatch(waterFragment,/texture2D\(|sampler2D/);
});
test('Wave heights stay finite and react to time and season wind',()=>{
 for(const [x,z] of [[-65,-51],[-13,8],[0,0],[32,21],[70,55]]){
  const values=[swell(x,z,0,.2),swell(x,z,217,1.3),swell(x,z,500,.65)];
  assert.ok(values.every(Number.isFinite));
  assert.ok(values.every(n=>Math.abs(n)<.35));
  assert.notEqual(values[0],values[1]);
 }
});
test('Every tier retains 3D water and explicit transparent scene geometry',()=>{
 const world=read('scripts/inherit-3d/world-geometry.mjs');
 assert.match(world,/PlaneGeometry\(140,110,quality==='high'\?42:quality==='medium'\?30:20/);
 assert.match(world,/uHorizonFade:\{value:\.66\}/);
 assert.match(world,/transparent:true,depthWrite:false,depthTest:true/);
 assert.match(world,/makeShorelineSurf\(\{quality\}\)/);
 assert.match(world,/makeSeaStackEnvironment\(\{quality\}\)/);
});
test('Cinematic focus is explicit, reversible, translated, and never writes saves',()=>{
 const entry=read('scripts/inherit-3d/aaa-three-entry.mjs');
 const css=read('public/games/inherit/aaa-3d.css');
 assert.match(entry,/classList\.toggle\('inherit-r24-focus',enabled\)/);
 assert.match(entry,/focus\.disabled=!status\.active/);
 assert.match(entry,/if\(!next\)\{setFocusMode\(false\)/);
 assert.match(entry,/event\.key!=='Escape'/);
 assert.match(entry,/setFocusMode\(false\)/);
 assert.match(entry,/status\.oceanFade=waterUniforms\.uHorizonFade\.value/);
 assert.match(entry,/focusOn:'Cinema view'/);
 assert.match(entry,/focusOn:'电影全景'/);
 assert.match(css,/\.app>#world\{\s*position:fixed!important/);
 assert.match(css,/grid-template-columns:repeat\(4,minmax\(0,1fr\)\)/);
 assert.match(css,/min-height:44px!important/);
 assert.match(css,/body\.living-legacy \.app > \.aaa3d-controls/);
 assert.match(entry,/game\.snapshot\(\)/);
 assert.doesNotMatch(entry,/game\.apply\s*\(|saveDraft\s*\(|S\.budget\s*--/);
});
console.log('INHERIT R24 ocean/focus quality gates:',passed,'passed');
