/* INHERIT R23 — cinematic eroded sea stacks, broken rock and GPU sea spray.
 * Real sculpted normals / silhouette and PBR mineral materials.
 * 2-4 additional draw calls depending on LOD; zero gameplay writes / requests.
 */
import * as THREE from 'three';
import {coastline,hash} from './terrain-core.mjs';
import {makeSurfaceMaterial} from './cinematic-surfaces.mjs';

const GOLD=2.399963229728653,PI=Math.PI,TAU=PI*2;
const TIERS=Object.freeze({
 low:Object.freeze({stacks:3,talus:24,saltMoss:0,spray:0,segments:10,rings:7}),
 medium:Object.freeze({stacks:5,talus:90,saltMoss:35,spray:65,segments:20,rings:12}),
 high:Object.freeze({stacks:7,talus:210,saltMoss:120,spray:180,segments:32,rings:18})
});
export function seaStackProfile(quality='high'){
 const key=Object.hasOwn(TIERS,quality)?quality:'low';
 const p=TIERS[key];
 return Object.freeze({...p,quality:key,instances:p.stacks+p.talus+p.saltMoss,
  drawCalls:2+Number(p.saltMoss>0)+Number(p.spray>0)});
}
export function makeErodedStackGeometry(quality='high'){
 const {segments,rings}=seaStackProfile(quality),positions=[],uvs=[],colors=[],indices=[];
 const tint=new THREE.Color();
 for(let i=0;i<=rings;i++){
  const t=i/rings;
  const taper=.92-.61*t+.085*Math.sin(t*19);
  for(let j=0;j<=segments;j++){
   const angle=j/segments*TAU;
   const striation=.19*Math.sin(t*19+Math.sin(angle*7)*.43)*
     Math.sin(angle*5.0+t*7.0);
   const fracture=.082*Math.sin(angle*11+t*15)+.045*Math.sin(angle*19-t*13);
   const r=Math.max(.13,taper*(1+striation+fracture));
   positions.push(Math.cos(angle)*r,t*4.7+.065*Math.sin(angle*5+t*14),Math.sin(angle)*r*.84);
   uvs.push(j/segments*2,t*3);
   tint.setHSL(.14+.017*Math.cos(angle*7+t*8),.09,.37+(.5-t)*.11+
     .035*Math.sin(t*22+angle*4));
   colors.push(tint.r,tint.g,tint.b);
   if(i<rings&&j<segments){
    const k=i*(segments+1)+j,n=k+segments+1;
    indices.push(k,n,k+1,k+1,n,n+1);
   }
  }
 }
 // End cap prevents seeing a hollow chimney during cinematic flyovers.
 const cap=positions.length/3;
 positions.push(0,4.69,0);uvs.push(.5,.5);
 tint.setHSL(.14,.06,.42);colors.push(tint.r,tint.g,tint.b);
 for(let j=0;j<segments;j++)indices.push(cap,rings*(segments+1)+j,rings*(segments+1)+j+1);
 const geo=new THREE.BufferGeometry();
 geo.setIndex(indices);
 geo.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));
 geo.setAttribute('uv',new THREE.Float32BufferAttribute(uvs,2));
 geo.setAttribute('color',new THREE.Float32BufferAttribute(colors,3));
 geo.computeVertexNormals();geo.computeBoundingSphere();
 return geo;
}
const dummy=new THREE.Object3D(),tint=new THREE.Color();
const angles=[.31,1.02,1.89,2.61,3.58,4.46,5.53];
function anchor(i){
 const a=angles[i%angles.length],p=coastline(a),offset=1.034+.020*hash(i,8,71);
 return {x:p.x*offset,z:p.z*offset,angle:a};
}
function instance(mesh,index,x,y,z,sx,sy,sz,rotation,color=null){
 dummy.position.set(x,y,z);dummy.rotation.set(0,rotation,0);
 dummy.scale.set(sx,sy,sz);dummy.updateMatrix();
 mesh.setMatrixAt(index,dummy.matrix);
 if(color)mesh.setColorAt(index,color);
}
const sprayVertex=[
 'precision highp float;',
 'attribute float aPhase;',
 'attribute float aSpeed;',
 'uniform float uTime;',
 'uniform float uRatio;',
 'uniform float uWind;',
 'varying float vFade;',
 'void main(){',
 ' float phase=fract(uTime*(.19+.18*aSpeed)+aPhase);',
 ' vec3 p=position;',
 ' p.y+=phase*3.4-phase*phase*2.75;',
 ' p.x+=sin(aPhase*39.0+uTime*.92)*phase*uWind*.34;',
 ' p.z+=cos(aPhase*26.0+uTime*.71)*phase*.26;',
 ' vFade=(1.0-phase)*(.5+.5*sin(phase*3.14159));',
 ' vec4 cameraPos=modelViewMatrix*vec4(p,1.0);',
 ' gl_Position=projectionMatrix*cameraPos;',
 ' gl_PointSize=clamp(uRatio*110.0/max(9.0,-cameraPos.z),1.0,4.5);',
 '}'
].join('\n');
const sprayFragment=[
 'precision mediump float;',
 'uniform float uDensity;',
 'varying float vFade;',
 'void main(){',
 ' vec2 uv=gl_PointCoord*2.0-1.0;',
 ' float disk=smoothstep(1.0,.14,dot(uv,uv));',
 ' gl_FragColor=vec4(vec3(.77,.90,.91),disk*vFade*uDensity*.58);',
 '}'
].join('\n');
export function makeSeaStackEnvironment({quality='high'}={}){
 const p=seaStackProfile(quality),root=new THREE.Group();
 root.name='INHERIT cinematic sea-stack archipelago / tidal spray';
 root.userData.kind='decorative noninteractive 3D';
 const geometries=[],materials=[],meshes=[];
 function add(name,geo,mat,count,shadow=false){
  const m=new THREE.InstancedMesh(geo,mat,count);
  m.name=name;m.castShadow=shadow;m.receiveShadow=true;
  root.add(m);meshes.push(m);geometries.push(geo);materials.push(mat);
  return m;
 }
 const stoneMat=makeSurfaceMaterial('basalt',{quality,vertexColors:true});
 const stack=add('Actually sculpted weathered rock sea stacks',
  makeErodedStackGeometry(quality),stoneMat,p.stacks,quality==='high');
 for(let i=0;i<p.stacks;i++){
  const a=anchor(i),size=.65+.67*hash(i,11,50);
  tint.setHSL(.14,.09,.78+hash(i,33,99)*.13);
  instance(stack,i,a.x,-2.15,a.z,size,size,size*.86,a.angle,tint);
 }
 const talusMat=makeSurfaceMaterial('limestone',{quality});
 const talus=add('3D volcanic talus and broken shoreline stones',
  new THREE.IcosahedronGeometry(.45,quality==='high'?1:0),talusMat,p.talus);
 for(let i=0;i<p.talus;i++){
  const idx=i%p.stacks,a=anchor(idx),ang=i*GOLD,rad=.65+1.6*hash(i,14,93);
  const size=.20+hash(i,8,77)*.76;
  tint.setHSL(.13,.075,.76+hash(i,17,51)*.17);
  instance(talus,i,a.x+Math.cos(ang)*rad,-2.01+size*.12,
   a.z+Math.sin(ang)*rad*.87,size,size*.44,size*.94,ang,tint);
 }
 let moss=null;
 if(p.saltMoss){
  const mossMat=makeSurfaceMaterial('fern',{quality,side:THREE.DoubleSide});
  moss=add('Rock crest mineral patina and sheltered lichen',
   new THREE.IcosahedronGeometry(.17,0),mossMat,p.saltMoss);
  for(let i=0;i<p.saltMoss;i++){
   const j=i%p.stacks,a=anchor(j),angle=hash(i,20,19)*TAU;
   const sy=.65+.67*hash(j,11,50),y=-2.15+(2.1+hash(i,10,66)*2.2)*sy;
   const s=.54+hash(i,16,79);
   tint.setHSL(.23+hash(i,9,73)*.11,.22,.58+hash(i,18,27)*.12);
   instance(moss,i,a.x+Math.cos(angle)*sy*.5,y,
    a.z+Math.sin(angle)*sy*.5,.4*s,.21*s,.65*s,angle,tint);
  }
 }
 for(const mesh of meshes){
  mesh.instanceMatrix.needsUpdate=true;
  if(mesh.instanceColor)mesh.instanceColor.needsUpdate=true;
  mesh.computeBoundingSphere();
 }
 let spray=null;
 if(p.spray){
  const geo=new THREE.BufferGeometry(),xyz=new Float32Array(p.spray*3),
   phase=new Float32Array(p.spray),speed=new Float32Array(p.spray);
  for(let i=0;i<p.spray;i++){
   const a=anchor(i%p.stacks),angle=i*GOLD,dist=.7+hash(i,7,45)*1.3;
   xyz[i*3]=a.x+Math.cos(angle)*dist;xyz[i*3+1]=-2.02;
   xyz[i*3+2]=a.z+Math.sin(angle)*dist;
   phase[i]=hash(i,11,17);speed[i]=hash(i,17,31);
  }
  geo.setAttribute('position',new THREE.BufferAttribute(xyz,3));
  geo.setAttribute('aPhase',new THREE.BufferAttribute(phase,1));
  geo.setAttribute('aSpeed',new THREE.BufferAttribute(speed,1));
  const mat=new THREE.ShaderMaterial({
   uniforms:{uTime:{value:0},uDensity:{value:.55},uWind:{value:.55},uRatio:{value:1}},
   vertexShader:sprayVertex,fragmentShader:sprayFragment,
   transparent:true,depthWrite:false,blending:THREE.AdditiveBlending
  });
  spray=new THREE.Points(geo,mat);
  spray.name='GPU-animated sea-spray / no per-particle JavaScript';
  spray.frustumCulled=false;root.add(spray);geometries.push(geo);materials.push(mat);
 }
 let season='tide',frames=0,wetness=.78;
 function setSeason(next){
  season=['tide','sun','wind','mist'].includes(next)?next:'tide';
  wetness=season==='tide'?.84:season==='mist'?.65:season==='wind'?.37:.07;
  stoneMat.roughness=.90-wetness*.35;
  talusMat.roughness=.94-wetness*.19;
  if(spray){
   spray.material.uniforms.uDensity.value=season==='wind'?.93:season==='tide'?.71:season==='mist'?.32:.22;
   spray.material.uniforms.uWind.value=season==='wind'?1.35:season==='sun'?.25:.65;
  }
  return wetness;
 }
 function update(time=0,{reducedMotion=false,pixelRatio=1}={}){
  if(spray){
   spray.material.uniforms.uTime.value=reducedMotion?0:Math.max(0,Number.isFinite(time)?time:0)*.001;
   spray.material.uniforms.uRatio.value=Math.max(.7,Math.min(1.6,pixelRatio));
  }
  frames++;
 }
 function dispose(){
  for(const g of geometries)g.dispose();
  for(const mat of materials)mat.dispose();
 }
 let triangles=0;
 for(const mesh of meshes)triangles+=
  ((mesh.geometry.index?.count||mesh.geometry.attributes.position.count)/3)*mesh.count;
 setSeason('tide');
 return Object.freeze({
  root,setSeason,update,dispose,
  stats:()=>Object.freeze({...p,triangles,frames,season,wetness,
   stoneRoughness:stoneMat.roughness,externalTextures:0,gameplayWrites:0})
 });
}
