// INHERIT R16 — real three-dimensional models for ten native saved trace types.
import * as THREE from 'three';
const bark=new THREE.MeshStandardMaterial({color:0x5a4230,roughness:.93});
const darkBark=new THREE.MeshStandardMaterial({color:0x493a2d,roughness:.96});
const leaf=new THREE.MeshStandardMaterial({color:0x5a8a5e,roughness:.95,metalness:0});
const leafLight=new THREE.MeshStandardMaterial({color:0x9fbf72,roughness:.95});
const leafDark=new THREE.MeshStandardMaterial({color:0x315e4e,roughness:.94});
const moss=new THREE.MeshStandardMaterial({color:0x426d4c,roughness:1});
const stone=new THREE.MeshStandardMaterial({color:0xa1a994,roughness:.98});
const stoneLight=new THREE.MeshStandardMaterial({color:0xc5c9b6,roughness:.96});
const slate=new THREE.MeshStandardMaterial({color:0x6e857a,roughness:.88});
const amber=new THREE.MeshStandardMaterial({color:0xf1ce8d,metalness:.45,roughness:.28});
const gold=new THREE.MeshStandardMaterial({color:0xbd995e,metalness:.78,roughness:.28});
const pale=new THREE.MeshStandardMaterial({color:0xeee4c5,roughness:.72});
const pink=new THREE.MeshStandardMaterial({color:0xe4a6a7,roughness:.75});
const flowerWhite=new THREE.MeshStandardMaterial({color:0xf3eacb,roughness:.7});
const glow=new THREE.MeshStandardMaterial({color:0xffe0a2,emissive:0xffbd57,emissiveIntensity:3.1,roughness:.24,metalness:.05});
const trunkGeo=new THREE.CylinderGeometry(.14,.24,2.7,7);
const boulderGeo=new THREE.IcosahedronGeometry(1,1);
const crownGeo=new THREE.IcosahedronGeometry(1,1);
const sphereGeo=new THREE.SphereGeometry(1,12,8);
function mesh(geometry,material,position,scale){
 const item=new THREE.Mesh(geometry,material);
 if(position)item.position.set(...position);
 if(scale)item.scale.set(...scale);
 item.castShadow=true;item.receiveShadow=true;
 return item;
}
function box(g,scale,xyz,mat,rotate=0){
 const a=mesh(new THREE.BoxGeometry(1,1,1),mat,xyz,scale);a.rotation.y=rotate;g.add(a);return a;
}
function bulb(g,y=2.6){
 const glass=mesh(new THREE.OctahedronGeometry(.35,1),glow,[0,y,0]);g.add(glass);
 const light=new THREE.PointLight(0xffd68a,1.8,10,2);
 light.position.set(0,y+.1,0);light.castShadow=false;g.add(light);return light;
}
export function makeTrace(tool,{size=1,cast=true}={}){
 const g=new THREE.Group();g.name='Trace '+tool;
 if(tool==='tree'){
  g.add(mesh(trunkGeo,bark,[0,1.25,0],[1,1,1]));
  g.add(mesh(crownGeo,leafDark,[0,2.7,0],[1.0,1.1,1.05]));
  g.add(mesh(crownGeo,leaf,[.47,3.04,.08],[1.02,.92,1]));
  g.add(mesh(crownGeo,leafLight,[-.42,3.0,.12],[.88,.94,.88]));
 }else if(tool==='stone'){
  g.add(mesh(boulderGeo,stone,[0,.6,0],[1.2,.67,.84]));
  g.add(mesh(boulderGeo,stoneLight,[-.52,.36,.52],[.5,.42,.43]));
  g.add(mesh(boulderGeo,slate,[.52,.38,-.35],[.5,.36,.4]));
 }else if(tool==='light'){
  box(g,[.27,2.3,.27],[0,1.22,0],bark);
  box(g,[1.0,.23,.65],[0,2.42,0],gold);
  box(g,[.95,.2,.65],[0,3.18,0],amber);
  box(g,[.82,.16,.7],[0,2.75,0],pale);
  bulb(g,2.85);
 }else if(tool==='path'){
  for(let i=0;i<5;i++){
   const slab=mesh(new THREE.BoxGeometry(1.15,.13,.88),i%2?stone:stoneLight,
     [Math.sin(i*1.8)*.22,.16,i*.73-1.46]);
   slab.rotation.y=Math.sin(i*1.43)*.12;g.add(slab);
  }
 }else if(tool==='flower'){
  g.add(mesh(new THREE.CylinderGeometry(.12,.2,.65,7),moss,[0,.31,0]));
  for(let i=0;i<7;i++){
   const a=i*Math.PI*2/7,r=.56;
   const x=Math.cos(a)*r,z=Math.sin(a)*r;
   const stem=mesh(new THREE.CylinderGeometry(.028,.045,.84,5),leafDark,[x,.59,z]);stem.rotation.z=Math.sin(a)*.17;g.add(stem);
   g.add(mesh(sphereGeo,i%3===0?flowerWhite:pink,[x,.99,z],[.22,.16,.22]));
   g.add(mesh(sphereGeo,amber,[x,1.08,z],[.085,.085,.085]));
  }
 }else if(tool==='arch'){
  box(g,[.76,2.55,.78],[-1.23,1.27,0],stone);
  box(g,[.76,2.55,.78],[1.23,1.27,0],stone);
  const ring=mesh(new THREE.TorusGeometry(1.23,.34,9,26,Math.PI),stoneLight,[0,2.42,0]);
  g.add(ring);
  box(g,[3.25,.27,1.1],[0,.24,0],slate);
 }else if(tool==='chime'){
  box(g,[.21,2.9,.24],[0,1.5,0],bark);
  box(g,[2.15,.18,.31],[0,2.88,0],gold);
  for(let k=-1;k<=1;k++){
   const x=k*.67;
   g.add(mesh(new THREE.CylinderGeometry(.025,.025,.61,5),pale,[x,2.57,0]));
   g.add(mesh(new THREE.CylinderGeometry(.19,.27,.51,8),gold,[x,2.17,0]));
  }
 }else if(tool==='moss'){
  for(let i=0;i<6;i++){
   const a=i*2.399,r=.2+Math.sqrt(i/6)*.9;
   g.add(mesh(crownGeo,i%2?leafDark:moss,[Math.cos(a)*r,.23,Math.sin(a)*r],[.41,.28,.46]));
  }
 }else if(tool==='cairn'){
  for(let i=0;i<4;i++){
   const width=1.1-i*.21;
   const b=mesh(boulderGeo,i%2?stoneLight:slate,[Math.sin(i*2.1)*.12,.32+i*.49,0],[width,.27,width*.8]);
   b.rotation.y=i*.37;g.add(b);
  }
 }else if(tool==='marker'){
  box(g,[.28,2.55,.29],[0,1.4,0],darkBark);
  const sign=box(g,[1.95,.68,.20],[.5,2.64,0],bark,-.07);
  box(g,[.44,.07,.26],[.34,2.69,.13],gold,-.06);
  const tip=mesh(new THREE.ConeGeometry(.36,.6,5),amber,[0,3.15,0]);
  g.add(tip);
 }else return g;
 g.scale.setScalar(size);
 for(const child of g.children){
   child.traverse?.(o=>{if(o.isMesh){o.castShadow=cast;o.receiveShadow=true;}});
 }
 return g;
}
export function makeHeroTree(){
 const g=makeTrace('tree',{size:2.45});
 g.rotation.y=.3;return g;
}
export function disposeTraces(group){
 for(const child of [...group.children]){
   group.remove(child);
   child.traverse(o=>{
     if(o.isPointLight)return;
     // Geometry is shared by many props; material is module-level and reused.
     // The scene owns disposal at teardown. This only clears scene nodes.
   });
 }
}
