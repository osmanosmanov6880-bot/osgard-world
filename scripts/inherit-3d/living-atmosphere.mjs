/* INHERIT R17 — living nature without CPU-heavy per-leaf updates.
 * Original deterministic particle field, instanced scenery vertex bending
 * and small hand-animated gulls. Cosmetic; no save/network writes.
 */
import * as THREE from 'three';
import {hash,fieldHeight} from './terrain-core.mjs';
const TAU=Math.PI*2,MAX_BIRDS=4;
export function applyWindSway(material,{amplitude=.12,frequency=.9}={}){
 if(!material?.isMeshStandardMaterial)return null;
 const clock={uWindTime:{value:0},uWindIntensity:{value:1}};
 const previous=material.onBeforeCompile;
 material.onBeforeCompile=shader=>{
  previous?.(shader);
  shader.uniforms.uWindTime=clock.uWindTime;
  shader.uniforms.uWindIntensity=clock.uWindIntensity;
  shader.vertexShader='uniform float uWindTime;\nuniform float uWindIntensity;\n'+shader.vertexShader;
  shader.vertexShader=shader.vertexShader.replace('#include <begin_vertex>',[
   '#include <begin_vertex>',
   'float bend=sin(uWindTime*'+frequency.toFixed(3)+'+position.x*2.1+position.z*1.7);',
   'float tip=clamp(position.y+0.65,0.0,1.9);',
   'transformed.x += bend * '+amplitude.toFixed(3)+' * tip * uWindIntensity;',
   'transformed.z += cos(uWindTime*.62+position.x*.72) * '+(amplitude*.37).toFixed(3)+' * tip * uWindIntensity;'
  ].join('\n'));
 };
 material.customProgramCacheKey=()=> 'heritagewind-v2:'+amplitude+':'+frequency;
 material.needsUpdate=true;
 return clock;
}
const pollenVertex=[
 'precision mediump float;',
 'attribute float aPhase;',
 'attribute float aSize;',
 'uniform float uTime;',
 'uniform float uWind;',
 'uniform float uPixelRatio;',
 'varying float vGlow;',
 'void main(){',
 ' vec3 p=position;',
 ' p.x+=sin(uTime*.35+aPhase*6.283)*(.31+uWind*.6)+uTime*.12*uWind;',
 ' p.z+=cos(uTime*.19+aPhase*11.)*.39;',
 ' p.y+=sin(uTime*.8+aPhase*19.)*.28;',
 ' p.x=mod(p.x+22.,44.)-22.;',
 ' vec4 view=modelViewMatrix*vec4(p,1.);',
 ' gl_Position=projectionMatrix*view;',
 ' gl_PointSize=clamp(aSize*uPixelRatio*35./max(10.,-view.z),1.0,6.5);',
 ' vGlow=.55+.45*sin(uTime*.7+aPhase*12.);',
 '}'
].join('\n');
const pollenFragment=[
 'precision mediump float;',
 'varying float vGlow;',
 'void main(){',
 ' vec2 xy=gl_PointCoord*2.-1.;',
 ' float radius=dot(xy,xy);',
 ' float alpha=smoothstep(1.0,.07,radius);',
 ' gl_FragColor=vec4(mix(vec3(.91,.74,.38),vec3(.92,.95,.65),vGlow),alpha*.34);',
 '}'
].join('\n');
function makePollen(quality,seed=173){
 const count=quality==='high'?145:quality==='medium'?84:24;
 const positions=new Float32Array(count*3),phases=new Float32Array(count),sizes=new Float32Array(count);
 for(let i=0;i<count;i++){
  const a=hash(i,0,seed)*TAU,r=Math.sqrt(hash(i,5,seed))*19.5;
  const x=Math.cos(a)*r,z=Math.sin(a)*r*.89;
  positions[i*3]=x;positions[i*3+1]=fieldHeight(x,z)+1.2+hash(i,7,seed)*4.8;
  positions[i*3+2]=z;
  phases[i]=hash(i,9,seed);sizes[i]=.75+hash(i,11,seed)*1.3;
 }
 const geo=new THREE.BufferGeometry();
 geo.setAttribute('position',new THREE.BufferAttribute(positions,3));
 geo.setAttribute('aPhase',new THREE.BufferAttribute(phases,1));
 geo.setAttribute('aSize',new THREE.BufferAttribute(sizes,1));
 const uniforms={uTime:{value:0},uWind:{value:.3},uPixelRatio:{value:1}};
 const mat=new THREE.ShaderMaterial({
  vertexShader:pollenVertex,fragmentShader:pollenFragment,uniforms,
  transparent:true,depthWrite:false,blending:THREE.AdditiveBlending,
  toneMapped:false
 });
 const dust=new THREE.Points(geo,mat);
 dust.frustumCulled=false;dust.name='Original GPU-animated floating pollen';
 return {dust,uniforms,count};
}
function makeGulls(quality){
 if(quality==='low')return [];
 const n=quality==='high'?MAX_BIRDS:2,birds=[];
 const wingGeo=new THREE.PlaneGeometry(1.18,.27);
 const wingMat=new THREE.MeshStandardMaterial({
  color:0xe7e5d3,roughness:.95,side:THREE.DoubleSide,metalness:0
 });
 const bodyGeo=new THREE.CapsuleGeometry(.09,.32,3,6);
 const bodyMat=new THREE.MeshStandardMaterial({color:0xcbd8cf,roughness:1});
 for(let i=0;i<n;i++){
  const g=new THREE.Group();g.name='Circling wildlife '+i;
  const body=new THREE.Mesh(bodyGeo,bodyMat);
  body.rotation.x=Math.PI/2;g.add(body);
  const left=new THREE.Group(),right=new THREE.Group();
  left.position.x=-.07;right.position.x=.07;
  const ml=new THREE.Mesh(wingGeo,wingMat),mr=new THREE.Mesh(wingGeo,wingMat);
  ml.position.x=-.57;mr.position.x=.57;
  left.add(ml);right.add(mr);g.add(left,right);
  g.scale.setScalar(.67+hash(i,14,87)*.5);
  birds.push({g,left,right,phase:i*1.93,radius:15+i*1.7,y:9+i*1.2});
 }
 return birds;
}
export function makeLivingAtmosphere({quality='high'}={}){
 const group=new THREE.Group();
 group.name='Animated nature, all cosmetic';
 const pollen=makePollen(quality);group.add(pollen.dust);
 const birds=makeGulls(quality);
 birds.forEach(({g})=>group.add(g));
 const windClocks=[];
 const addWindMaterial=(mat,options)=>{
  const clock=applyWindSway(mat,options);if(clock)windClocks.push(clock);return mat;
 };
 let frameCount=0;
 function update(time,season='tide',pixelRatio=1){
  const seconds=time/1000;
  const wind=season==='wind'?1.1:season==='mist'?.14:season==='sun'?.38:.59;
  for(const clock of windClocks){
   clock.uWindTime.value=seconds;
   clock.uWindIntensity.value=wind;
  }
  pollen.uniforms.uTime.value=seconds;
  pollen.uniforms.uWind.value=wind;
  pollen.uniforms.uPixelRatio.value=Math.min(1.6,pixelRatio);
  for(const item of birds){
   const theta=seconds*.16+item.phase;
   item.g.position.set(Math.cos(theta)*item.radius,
    item.y+Math.sin(seconds*.52+item.phase)*.8,
    Math.sin(theta)*item.radius*.78);
   item.g.rotation.set(0,-theta,.07*Math.sin(seconds*.41));
   item.left.rotation.z=.24+.27*Math.sin(seconds*2.7+item.phase);
   item.right.rotation.z=-item.left.rotation.z;
  }
  frameCount++;
 }
 return {
  root:group,addWindMaterial,update,
  stats:()=>({particles:pollen.count,birds:birds.length,windMaterials:windClocks.length,updatedFrames:frameCount}),
  dispose:()=>{
   pollen.dust.geometry.dispose();pollen.dust.material.dispose();
   for(const item of birds)item.g.parent?.remove(item.g);
  }
 };
}
