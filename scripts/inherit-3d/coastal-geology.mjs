/* INHERIT R22 — original coastal rock stratification, erosion scars, salt lichens.
 * All real instanced 3D/PBR meshes. Deterministic geology does not touch
 * historical generations, native placement, collisions, storage or network.
 */
import * as THREE from 'three';
import {coastline,fieldHeight,hash} from './terrain-core.mjs';
import {makeSurfaceMaterial} from './cinematic-surfaces.mjs';
const GOLD=2.399963229728653;
const TIERS=Object.freeze({
 low:Object.freeze({shelves:24,shards:65,lichen:0}),
 medium:Object.freeze({shelves:64,shards:140,lichen:180}),
 high:Object.freeze({shelves:120,shards:280,lichen:420})
});
export function geologyProfile(quality='high'){
 const p=TIERS[quality]||TIERS.low;
 return Object.freeze({quality:TIERS[quality]?quality:'low',
  ...p,instances:p.shelves+p.shards+p.lichen,batches:p.lichen?3:2});
}
const dummy=new THREE.Object3D(),color=new THREE.Color();
function set(mesh,index,x,y,z,sx,sy,sz,ry,tilt=0,tint=null){
 dummy.position.set(x,y,z);dummy.scale.set(sx,sy,sz);
 dummy.rotation.set(tilt,ry,0);dummy.updateMatrix();
 mesh.setMatrixAt(index,dummy.matrix);
 if(tint)mesh.setColorAt(index,tint);
}
export function makeCoastalGeology({quality='high'}={}){
 const profile=geologyProfile(quality),root=new THREE.Group();
 root.name='Sculpted erosion strata and salt-weathered basalt';
 root.userData.kind='decorative 3D geology / noninteractive';
 const basalt=makeSurfaceMaterial('basalt',{quality});
 const limestone=makeSurfaceMaterial('limestone',{quality});
 const moss=profile.lichen?makeSurfaceMaterial('fern',{quality,side:THREE.DoubleSide}):null;
 const meshes=[],geometries=[],materials=[basalt,limestone];
 if(moss)materials.push(moss);
 const make=(name,geo,mat,count)=>{
  const mesh=new THREE.InstancedMesh(geo,mat,count);
  mesh.name=name;mesh.castShadow=false;mesh.receiveShadow=true;
  root.add(mesh);meshes.push(mesh);geometries.push(geo);return mesh;
 };
 // Successive horizontal weathering shelves physically project from the cliffs.
 const shelfGeo=new THREE.CylinderGeometry(.48,.52,.10,10,1);
 const shelves=make('Physical sedimentary rock shelves / shoreline overhangs',
  shelfGeo,basalt,profile.shelves);
 for(let i=0;i<profile.shelves;i++){
  const angle=i*GOLD+.14,coast=coastline(angle);
  const radial=.982+.022*hash(i,2,73);
  const x=coast.x*radial,z=coast.z*radial;
  const h=fieldHeight(coast.x,coast.z);
  const layer=i%6,scale=.58+hash(i,4,19)*.89;
  color.setHSL(.43,.09,.29+hash(i,7,22)*.15);
  set(shelves,i,x,h-.29-layer*.36,z,scale,1,scale*.70,
   angle*.61,0,color);
 }
 // A second batch of irregular, fractured vertices breaks artificial cliff sides.
 const chipGeo=new THREE.DodecahedronGeometry(1,quality==='high'?1:0);
 const chips=make('Fractured basalt and independently shaded mineral chips',
  chipGeo,limestone,profile.shards);
 for(let i=0;i<profile.shards;i++){
  const a=i*GOLD+1.7,shore=coastline(a);
  const rad=.974+.024*hash(i,9,18);
  const x=shore.x*rad,z=shore.z*rad;
  const depth=.16+hash(i,14,67)*2.5;
  const extent=.16+hash(i,11,65)*.29;
  color.setHSL(.13,.10+hash(i,21,85)*.07,.40+hash(i,22,77)*.19);
  set(chips,i,x,fieldHeight(shore.x,shore.z)-depth,z,
   extent*(.66+hash(i,5,99)*.5),extent*.32,extent*1.4,
   a*1.34,(hash(i,8,65)-.5)*.44,color);
 }
 // Moss on sheltered cracks is actual mesh geometry, never CSS decals.
 if(profile.lichen){
  const patchGeo=new THREE.IcosahedronGeometry(.18,0);
  const patches=make('Salt-tolerant lichen microgrowth attached to basalt',
   patchGeo,moss,profile.lichen);
  for(let i=0;i<profile.lichen;i++){
   const a=i*GOLD+.43,shore=coastline(a);
   const radius=.982+.015*hash(i,4,89);
   const x=shore.x*radius,z=shore.z*radius,h=fieldHeight(shore.x,shore.z);
   const size=.47+hash(i,2,18)*1.4;
   color.setHSL(.235+hash(i,23,19)*.12,.14+hash(i,16,86)*.19,
    .34+hash(i,13,12)*.19);
   set(patches,i,x,h-.32-hash(i,3,56)*1.3,z,
    size*.74,size*.26,size,hash(i,15,81)*Math.PI*2,0,color);
  }
 }
 let triangles=0;
 for(const item of meshes){
  item.instanceMatrix.needsUpdate=true;
  if(item.instanceColor)item.instanceColor.needsUpdate=true;
  item.computeBoundingSphere();
  const geo=item.geometry;
  triangles+=((geo.index?.count||geo.attributes.position.count)/3)*item.count;
 }
 let season='tide',wetness=0;
 function setSeason(value){
  season=['tide','sun','wind','mist'].includes(value)?value:'tide';
  wetness=season==='tide'?.83:season==='mist'?.56:season==='wind'?.25:.04;
  basalt.roughness=.88-wetness*.33;
  basalt.metalness=.025+wetness*.032;
  limestone.roughness=.92-wetness*.23;
  if(moss)moss.roughness=.97-wetness*.10;
  return wetness;
 }
 setSeason('tide');
 return Object.freeze({
  root,setSeason,
  stats:()=>Object.freeze({...profile,triangles,season,wetness,
   rockRoughness:basalt.roughness,assetRequests:0,gameplayWrites:0}),
  dispose:()=>{
   for(const mesh of meshes)mesh.parent?.remove(mesh);
   for(const g of geometries)g.dispose();
   for(const material of materials)material.dispose();
  }
 });
}
