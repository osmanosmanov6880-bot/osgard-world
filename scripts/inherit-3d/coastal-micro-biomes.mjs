/* INHERIT R19 — coastal micro-biomes / close-range physically-lit detail.
 * Instanced organic geometry adds professional-scale surface variation without
 * changing native save coordinates, game rules, network access, or collisions.
 * Seasonal weather is fictional and purely visual.
 */
import * as THREE from 'three';
import {coastline,fieldHeight,hash} from './terrain-core.mjs';
import {makeSurfaceMaterial} from './cinematic-surfaces.mjs';

export const MICRO_BIOME_TIERS=Object.freeze({
 low:Object.freeze({rocks:32,grass:96,reeds:42,shells:20,pools:8,driftwood:12,sparkles:24}),
 medium:Object.freeze({rocks:84,grass:320,reeds:110,shells:72,pools:18,driftwood:36,sparkles:72}),
 high:Object.freeze({rocks:168,grass:760,reeds:245,shells:180,pools:36,driftwood:75,sparkles:150})
});
export function marineProfile(quality='high'){
 const tier=MICRO_BIOME_TIERS[quality]||MICRO_BIOME_TIERS.low;
 return Object.freeze({...tier,instances:Object.values(tier).reduce((a,b)=>a+b,0),groups:7});
}
function h(i,k,seed){return hash(i*1.716+k*.071,k*2.31+i*.13,seed)}
const transform=new THREE.Object3D();
function setInstance(inst,index,position,scale,rotation,color){
 const dummy=transform;
 dummy.position.set(...position);
 dummy.scale.set(...scale);
 if(rotation)dummy.rotation.set(...rotation);
 dummy.updateMatrix();
 inst.setMatrixAt(index,dummy.matrix);
 if(color)inst.setColorAt(index,color);
}
function releaseSharedMaterial(material){
 if(Array.isArray(material)){for(const m of material)m?.dispose();return;}
 material?.dispose();
}
export function makeCoastalMicroBiomes({quality='high',registerWind}={}){
 const profile=marineProfile(quality);
 const group=new THREE.Group();group.name='Hand-layered coastal micro-biomes';
 group.userData.kind='purely scenic instanced environment';
 const registry=[],materials=[],meshes=[];
 const add=(name,geo,mat,count,cast=false)=>{
  const mesh=new THREE.InstancedMesh(geo,mat,count);
  mesh.name=name;mesh.frustumCulled=false;
  mesh.castShadow=cast;mesh.receiveShadow=true;
  group.add(mesh);registry.push(geo);materials.push(mat);meshes.push(mesh);
  return mesh;
 };
 const rockMat=makeSurfaceMaterial('basalt',{quality});
 const shellMat=new THREE.MeshPhysicalMaterial({color:0xd9cfac,roughness:.49,metalness:.04,clearcoat:.21,clearcoatRoughness:.34,side:THREE.DoubleSide});
 const sandMat=makeSurfaceMaterial('sand',{quality});
 const grassBase=makeSurfaceMaterial('fern',{quality,side:THREE.DoubleSide});
 const reedsBase=new THREE.MeshStandardMaterial({color:0x638a55,roughness:.89,metalness:0,side:THREE.DoubleSide});
 const grassMat=registerWind?registerWind(grassBase,{amplitude:.065,frequency:1.08}):grassBase;
 const reedMat=registerWind?registerWind(reedsBase,{amplitude:.145,frequency:.72}):reedsBase;
 const poolMat=new THREE.MeshPhysicalMaterial({
  color:0x559c9b,roughness:.12,metalness:.11,clearcoat:1,clearcoatRoughness:.07,
  transparent:true,opacity:.62,side:THREE.DoubleSide,depthWrite:false
 });
 const driftMat=makeSurfaceMaterial('timber',{quality});
 const sparkleMat=new THREE.MeshBasicMaterial({
  color:0xf0e4bc,transparent:true,opacity:.24,depthWrite:false
 });

 // Faceted ocean-worn rock formations with different normals and tones.
 const rockGeo=new THREE.DodecahedronGeometry(1,quality==='high'?1:0);
 const rocks=add('Instanced wet shore basalt / mineral detail',rockGeo,rockMat,profile.rocks,quality==='high');
 const color=new THREE.Color();
 for(let i=0;i<profile.rocks;i++){
  const a=i*2.39996+.23,p=coastline(a),dist=.80+.14*h(i,1,45);
  const x=p.x*dist,z=p.z*dist,scale=.12+.39*h(i,3,22);
  color.setHSL(.43+h(i,7,82)*.06,.08+h(i,9,12)*.06,.29+h(i,5,56)*.19);
  setInstance(rocks,i,[x,fieldHeight(x,z)+scale*.13,z],
   [scale*(.9+h(i,2,93)*.6),scale*.63,scale*(1+h(i,4,73)*.7)],
   [i*.11,i*1.23,i*.37],color);
 }
 // Millions of grass blades would be wasteful. This deliberately uses one
 // 3-sided tapered instance mesh; close-range blades bend via the shared wind.
 const grassGeo=new THREE.ConeGeometry(.10,.77,3,1,false);
 grassGeo.translate(0,.37,0);
 const grass=add('Wind-reactive coastal grass and sea lavender',grassGeo,grassMat,profile.grass);
 for(let i=0;i<profile.grass;i++){
  const theta=i*2.399963,hue=h(i,3,21),radius=.25+Math.sqrt((i+.37)/profile.grass)*.61;
  const x=Math.cos(theta)*radius*24,z=Math.sin(theta)*radius*21;
  // Preserve the winding native heritage road for legibility.
  const road=.22*x+2*Math.sin(x*.19);
  const shift=Math.abs(z-road)<1.6?(z>=road?1.9:-1.9):0;
  const zz=z+shift;
  const height=.55+h(i,5,83)*1.11;
  color.setHSL(.25+hue*.11,.26+h(i,6,28)*.15,.30+h(i,7,57)*.19);
  setInstance(grass,i,[x,fieldHeight(x,zz)+.02,zz],
   [height*(.52+h(i,2,92)*.55),height,.50+h(i,1,31)*.55],
   [0,h(i,9,49)*Math.PI*2,(h(i,8,82)-.5)*.24],color);
 }
 // Semi-translucent water plants alongside the non-authoritative stream.
 const reedGeo=new THREE.ConeGeometry(.07,1.6,4,1,false);reedGeo.translate(0,.78,0);
 const reeds=add('Diverse river reeds and fine shoreline grasses',reedGeo,reedMat,profile.reeds);
 for(let i=0;i<profile.reeds;i++){
  const z=-17.9+i/Math.max(1,profile.reeds-1)*35.8;
  const center=1.8+Math.sin(z*.17+1.3)*2.1+Math.sin(z*.41)*.45;
  const sign=i%2?1:-1,x=center+sign*(.98+.97*h(i,1,91));
  const size=.6+h(i,2,74)*.85;
  color.setHSL(.22+h(i,5,32)*.13,.28+h(i,8,13)*.23,.33+h(i,7,13)*.15);
  setInstance(reeds,i,[x,fieldHeight(x,z)+.015,z],[size*.79,size,size*.67],
   [0,h(i,4,39)*Math.PI*2,(h(i,2,3)-.5)*.27],color);
 }
 // Small worn shells add glancing microstructure where wet sand meets stone.
 const shellGeo=new THREE.ConeGeometry(.22,.15,8,1);
 const shells=add('Scattered iridescent shells and shore porcelain',shellGeo,shellMat,profile.shells);
 for(let i=0;i<profile.shells;i++){
  const a=i*2.399963+2.1,p=coastline(a),radius=.91+.045*h(i,2,67);
  const x=p.x*radius,z=p.z*radius,scale=.56+h(i,6,45)*1.25;
  color.setHSL(.09+h(i,5,56)*.052,.16+.13*h(i,7,89),.68+.21*h(i,4,22));
  setInstance(shells,i,[x,fieldHeight(x,z)+.035,z],
   [scale,scale*(.5+h(i,9,51)*.5),scale],
   [0,i*.734,(h(i,3,9)-.5)*.16],color);
 }
 // Multiple shallow, planar clearcoat water layers react to tide level.
 const poolGeo=new THREE.SphereGeometry(1,12,6);
 const pools=add('Seasonally reflective tide pools',poolGeo,poolMat,profile.pools);
 for(let i=0;i<profile.pools;i++){
  const a=i*2.399963+.5,p=coastline(a),radius=.76+.15*h(i,5,34);
  const x=p.x*radius,z=p.z*radius,s=.35+h(i,1,25)*.93;
  setInstance(pools,i,[x,fieldHeight(x,z)+.038,z],[s*1.48,.026,s*(.81+h(i,3,78)*.65)],
   [0,h(i,7,83)*Math.PI,0]);
 }
 // Driftwood and old tree fragments: visible silhouettes at low camera angles.
 const logGeo=new THREE.CylinderGeometry(.10,.14,1.25,6,1);
 const logs=add('Salt-weathered timber and old driftwood',logGeo,driftMat,profile.driftwood);
 for(let i=0;i<profile.driftwood;i++){
  const a=i*2.399963+1.5,p=coastline(a),radius=.76+.18*h(i,8,57);
  const x=p.x*radius,z=p.z*radius,scale=.63+1.3*h(i,2,17);
  setInstance(logs,i,[x,fieldHeight(x,z)+.07,z],
   [.75*scale,.57+h(i,5,27)*1.3,.6*scale],
   [0,i*.59,Math.PI/2+.11*Math.sin(i)]);
 }
 // A single emissive group of glancing wet highlights, with a subtle pulse
 // instead of individual GPU particle systems or many browser timers.
 const sparkGeo=new THREE.OctahedronGeometry(.045,0);
 const sparkles=add('Wet mineral glints / low-cost contact highlights',sparkGeo,sparkleMat,profile.sparkles);
 for(let i=0;i<profile.sparkles;i++){
  const a=i*2.399963,p=coastline(a),r=.80+.13*h(i,6,21);
  const x=p.x*r,z=p.z*r,s=.6+h(i,3,75);
  setInstance(sparkles,i,[x,fieldHeight(x,z)+.12,z],[s,.38*s,s]);
 }
 for(const mesh of meshes){
  mesh.instanceMatrix.needsUpdate=true;
  if(mesh.instanceColor)mesh.instanceColor.needsUpdate=true;
 }
 const seasonLevels=Object.freeze({tide:.9,sun:.09,wind:.2,mist:.61});
 let season='tide',wetness=seasonLevels.tide,frames=0,animTime=0;
 function setSeason(next){
  season=Object.hasOwn(seasonLevels,next)?next:'tide';
  wetness=seasonLevels[season];
  rockMat.roughness=.87-.35*wetness;
  rockMat.metalness=.01+.055*wetness;
  shellMat.clearcoat=.13+.47*wetness;
  sandMat.roughness=.93-.19*wetness;
  poolMat.opacity=.31+wetness*.46;
  poolMat.roughness=.2-wetness*.12;
  sparkleMat.opacity=.07+wetness*.19;
  return wetness;
 }
 function update(now=0){
  // Only two uniforms/material values are animated per frame, independent of
  // detail count. The user can disable motion without accumulating timers.
  animTime=Number.isFinite(now)?now:0;frames++;
  poolMat.opacity=(.29+wetness*.43)*(1+.026*Math.sin(animTime*.00137));
  sparkleMat.opacity=(.055+wetness*.18)*(1+.15*Math.sin(animTime*.0021));
 }
 function stats(){
  const geometryTriangles=meshes.reduce((sum,o)=>{
   const g=o.geometry;
   const count=g.index?.count||g.attributes.position.count;
   return sum+Math.ceil(count/3)*o.count;
  },0);
  return Object.freeze({quality,groups:meshes.length,instances:profile.instances,
   triangles:geometryTriangles,wetness,season,animationFrames:frames,
   texturesLoadedExternally:0,gameplayObjectsCreated:0,
   strategy:'seven bounded InstancedMesh batches, no per-object animation loops'});
 }
 function dispose(){
  group.remove(...group.children);
  registry.forEach(g=>g.dispose());
  [...new Set(materials)].forEach(m=>releaseSharedMaterial(m));
  // Procedural PBR textures use the shared surface-pack cache; avoid disposing
  // the same texture while higher/lower detail scenery is still cached.
 }
 setSeason('tide');
 return Object.freeze({root:group,stats,setSeason,update,dispose});
}
