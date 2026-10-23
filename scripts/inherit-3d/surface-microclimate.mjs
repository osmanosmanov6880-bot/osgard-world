/* INHERIT R20 / SURFACE MICROCLIMATE
 * GPU-instanced contact occlusion, clearcoat tidal pools and weather particles.
 * Original, deterministic materials: no photos, external requests or gameplay
 * mutations. Animation runs inside the game's existing bounded render loop.
 */
import * as THREE from 'three';
import {fieldHeight,vegetation,hash,coastline} from './terrain-core.mjs';

const PROFILES=Object.freeze({
 low:Object.freeze({contacts:36,pools:0,precipitation:0}),
 medium:Object.freeze({contacts:80,pools:21,precipitation:118}),
 high:Object.freeze({contacts:136,pools:54,precipitation:320})
});
const TWOPI=Math.PI*2;
const saturate=v=>Math.min(1,Math.max(0,v));
export function contactFalloff(distance){
 const r=saturate(distance);
 return Math.pow(1-r*r,2.4)*saturate((.98-r)*35);
}
export function microclimateProfile(quality='high'){return PROFILES[quality]||PROFILES.low;}
export function wetnessForSeason(season){
 return season==='tide'?.80:season==='mist'?.58:season==='wind'?.27:.05;
}
function radialTexture(size=128){
 const data=new Uint8Array(size*size*4);
 for(let y=0;y<size;y++)for(let x=0;x<size;x++){
  const dx=(x+.5-size*.5)/(size*.5),dy=(y+.5-size*.5)/(size*.5);
  const r=Math.sqrt(dx*dx+dy*dy),value=Math.round(contactFalloff(r)*255);
  const i=(y*size+x)*4;
  data[i]=data[i+1]=data[i+2]=value;data[i+3]=255;
 }
 const tex=new THREE.DataTexture(data,size,size,THREE.RGBAFormat);
 tex.minFilter=THREE.LinearMipmapLinearFilter;tex.magFilter=THREE.LinearFilter;
 tex.generateMipmaps=true;tex.needsUpdate=true;
 return tex;
}
function place(mesh,index,x,z,sy,sx,sz,rot=0){
 const dummy=new THREE.Object3D();
 dummy.position.set(x,fieldHeight(x,z)+sy,z);
 dummy.rotation.y=rot;dummy.scale.set(sx,1,sz);dummy.updateMatrix();
 mesh.setMatrixAt(index,dummy.matrix);
}
const rainVertex=[
 'precision highp float;',
 'attribute float aPhase;',
 'attribute float aSize;',
 'uniform float uTime;',
 'uniform float uWind;',
 'uniform float uPixels;',
 'varying float vFade;',
 'void main(){',
 ' vec3 p=position;',
 ' float travel=mod(uTime*5.6+aPhase*37.0,28.0);',
 ' p.y=24.0-travel;',
 ' p.x+=travel*(uWind*.15)+sin(aPhase*17.0+uTime*.36)*.16;',
 ' p.z+=sin(aPhase*23.1+uTime*.2)*.1;',
 ' vec4 v=modelViewMatrix*vec4(p,1.0);',
 ' gl_Position=projectionMatrix*v;',
 ' gl_PointSize=clamp(aSize*uPixels*110.0/max(8.0,-v.z),1.4,5.2);',
 ' vFade=smoothstep(-4.0,1.0,p.y)*(1.0-smoothstep(19.0,27.0,p.y));',
 '}'
].join('\n');
const rainFragment=[
 'precision mediump float;',
 'uniform float uRain;',
 'varying float vFade;',
 'void main(){',
 ' vec2 uv=gl_PointCoord*2.0-1.0;',
 ' float drop=exp(-uv.x*uv.x*16.0-uv.y*uv.y*1.9);',
 ' float edge=smoothstep(.04,.42,drop);',
 ' float alpha=min(.42,drop*.33)*uRain*vFade*edge;',
 ' gl_FragColor=vec4(vec3(.72,.87,.87),alpha);',
 '}'
].join('\n');
function makeRain(quality){
 const count=microclimateProfile(quality).precipitation;
 if(!count)return null;
 const geo=new THREE.BufferGeometry(),positions=new Float32Array(count*3),
  phase=new Float32Array(count),sizes=new Float32Array(count);
 for(let i=0;i<count;i++){
  const angle=hash(i,1,87)*TWOPI,r=Math.sqrt(hash(i,9,173))*23;
  positions[i*3]=Math.cos(angle)*r;
  positions[i*3+1]=hash(i,31,97)*26;
  positions[i*3+2]=Math.sin(angle)*r*.88;
  phase[i]=hash(i,17,79);sizes[i]=.75+hash(i,18,77)*.75;
 }
 geo.setAttribute('position',new THREE.BufferAttribute(positions,3));
 geo.setAttribute('aPhase',new THREE.BufferAttribute(phase,1));
 geo.setAttribute('aSize',new THREE.BufferAttribute(sizes,1));
 const uniforms={uTime:{value:0},uRain:{value:0},uWind:{value:.25},uPixels:{value:1}};
 const material=new THREE.ShaderMaterial({
  uniforms,vertexShader:rainVertex,fragmentShader:rainFragment,
  transparent:true,depthWrite:false,blending:THREE.NormalBlending,
  toneMapped:false
 });
 const points=new THREE.Points(geo,material);
 points.name='GPU-weather / purely fictional seasonal microclimate';
 points.frustumCulled=false;points.renderOrder=3;
 return {points,uniforms,count};
}
export function makeSurfaceMicroclimate({quality='high',seed=173}={}){
 const profile=microclimateProfile(quality);
 const group=new THREE.Group();group.name='INHERIT grounded surfaces / microclimate';
 const geometries=[],materials=[],textures=[],gpuGroups=[];
 const alpha=radialTexture(quality==='high'?128:64);textures.push(alpha);
 const contactMat=new THREE.MeshBasicMaterial({
  color:0x1c3029,alphaMap:alpha,transparent:true,opacity:.41,
  depthWrite:false,polygonOffset:true,polygonOffsetFactor:-1,side:THREE.DoubleSide
 });
 materials.push(contactMat);
 const plane=new THREE.PlaneGeometry(1,1);plane.rotateX(-Math.PI/2);geometries.push(plane);
 const shadows=new THREE.InstancedMesh(plane,contactMat,profile.contacts);
 shadows.name='Instanced tree and architectural ground-contact shadows';
 shadows.castShadow=false;shadows.receiveShadow=false;shadows.frustumCulled=false;
 const pts=vegetation(seed,Math.max(profile.contacts,80));
 for(let i=0;i<profile.contacts;i++){
  const p=pts[i%pts.length]||{x:0,z:0};
  let x=p.x,z=p.z,r=1.15;
  if(i>=Math.min(profile.contacts,pts.length)){
   const a=i*2.39996,shore=coastline(a);
   x=shore.x*.63;z=shore.z*.63;r=.8;
  }
  // Always anchored to the actual deterministic height surface.
  const extent=.72+hash(i,6,seed)*.71;
  place(shadows,i,x,z,.035,r*2.8*extent,r*2.4*extent,hash(i,13,41)*TWOPI);
 }
 shadows.instanceMatrix.needsUpdate=true;group.add(shadows);gpuGroups.push(shadows);
 let pools=null,poolMat=null;
 if(profile.pools){
  const alphaMap=radialTexture(128);textures.push(alphaMap);
  const circles=new THREE.CircleGeometry(1,32);circles.rotateX(-Math.PI/2);geometries.push(circles);
  poolMat=new THREE.MeshPhysicalMaterial({
   color:0x367b79,metalness:.1,roughness:.14,clearcoat:1,clearcoatRoughness:.09,
   transparent:true,opacity:.22,alphaMap,side:THREE.DoubleSide,depthWrite:false,
   polygonOffset:true,polygonOffsetFactor:-1
  });materials.push(poolMat);
  pools=new THREE.InstancedMesh(circles,poolMat,profile.pools);
  pools.name='Wet sculpted tidal pools / one GPU batch';
  pools.castShadow=false;pools.receiveShadow=false;pools.frustumCulled=false;
  for(let i=0;i<profile.pools;i++){
   const theta=i*2.39996+hash(i,2,55)*.21,
     radius=.58+.28*hash(i,7,76),shore=coastline(theta);
   const x=shore.x*radius,z=shore.z*radius;
   const w=.42+hash(i,1,75)*.9;
   place(pools,i,x,z,.066,w,w*(.52+hash(i,3,177)*.44),hash(i,5,7)*TWOPI);
  }
  pools.instanceMatrix.needsUpdate=true;group.add(pools);gpuGroups.push(pools);
 }
 const rain=makeRain(quality);
 if(rain){group.add(rain.points);gpuGroups.push(rain.points);}
 let lastSeason='tide',rainfall=.35,wetness=.8,frames=0;
 function setSeason(season){
  lastSeason=['tide','sun','wind','mist'].includes(season)?season:'tide';
  wetness=wetnessForSeason(lastSeason);
  rainfall=lastSeason==='sun'?0:lastSeason==='mist'?.42:lastSeason==='wind'?.57:.82;
  if(poolMat){poolMat.opacity=.08+wetness*.30;poolMat.roughness=.10+(1-wetness)*.19;}
  contactMat.opacity=.34+wetness*.07;
  if(rain){
   rain.uniforms.uRain.value=rainfall;
   rain.uniforms.uWind.value=lastSeason==='wind'?.91:.22;
  }
  return {wetness,rainfall};
 }
 function update(time=0,{pixelRatio=1,reducedMotion=false}={}){
  if(rain){
   rain.uniforms.uTime.value=reducedMotion?0:time*.001;
   rain.uniforms.uPixels.value=Math.min(1.6,Math.max(.7,pixelRatio));
  }
  frames++;
 }
 function dispose(){
  for(const texture of textures)texture.dispose();
  for(const mat of materials)mat.dispose();
  for(const geo of geometries)geo.dispose();
  if(rain){rain.points.geometry.dispose();rain.points.material.dispose();}
 }
 setSeason('tide');
 return Object.freeze({
  root:group,setSeason,update,dispose,
  stats:()=>Object.freeze({
   quality,contacts:profile.contacts,pools:profile.pools,rainParticles:profile.precipitation,
   gpuBatches:gpuGroups.length,textureBytes:textures.reduce((n,t)=>n+(t.image?.data?.byteLength||0),0),
   frames,season:lastSeason,wetness,rainfall,
   externalTextures:0,gameplayWrites:0
  })
 });
}
