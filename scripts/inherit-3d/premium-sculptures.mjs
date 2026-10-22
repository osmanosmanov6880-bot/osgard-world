// INHERIT R16.2 — sculpted, batched procedural PBR assets.
// Detailed geometry, bark grain, mineral veins, carved masonry and brass
// joinery are ORIGINAL local source art: no CDN, external textures or GLTF.
import * as THREE from 'three';
import {mergeGeometries} from 'three/addons/utils/BufferGeometryUtils.js';

const UNIT={
 box:new THREE.BoxGeometry(1,1,1),
 cube:new THREE.BoxGeometry(1,1,1,1,1,1),
 stone:new THREE.IcosahedronGeometry(1,2),
 rock:new THREE.IcosahedronGeometry(1,1),
 pebble:new THREE.IcosahedronGeometry(1,0),
 bulb:new THREE.SphereGeometry(1,12,9),
 leaf:new THREE.SphereGeometry(1,8,6),
 cone:new THREE.ConeGeometry(1,1,9),
 trunk:new THREE.CylinderGeometry(.73,1,1,12,1),
 rod:new THREE.CylinderGeometry(1,1,1,10,1),
 ring:new THREE.TorusGeometry(1,.12,8,48),
 jewel:new THREE.OctahedronGeometry(1,1)
};
function grain(seed=1,type='stone'){
 const n=96,data=new Uint8Array(n*n*4);
 const sq=(x)=>{let i=(Math.imul(x|0,1664525)+1013904223)>>>0;i=Math.imul(i^(i>>>15),2246822519);return ((i^(i>>>13))>>>0)/4294967295;};
 for(let y=0;y<n;y++)for(let x=0;x<n;x++){
  const at=(y*n+x)*4;
  const base=(sq(seed+x*97+y*131)*.65+sq(seed+Math.floor(x/5)*47+Math.floor(y/5)*79)*.35);
  const fib=type==='bark'?Math.pow(.5+.5*Math.sin(x*.53+y*.07+sq(y+seed)*8),5):0;
  const strata=type==='stone'?Math.sin((x+y*.28)*.09+sq(seed+y)*5)*.13:0;
  const metallic=type==='metal'?Math.sin(y*.65+x*.02)*.11:0;
  const value=Math.max(20,Math.min(245,Math.round(101+base*104+fib*48+strata*100+metallic*110)));
  data[at]=data[at+1]=data[at+2]=value;data[at+3]=255;
 }
 const tex=new THREE.DataTexture(data,n,n,THREE.RGBAFormat);
 tex.wrapS=tex.wrapT=THREE.RepeatWrapping;
 tex.minFilter=THREE.LinearMipmapLinearFilter;tex.magFilter=THREE.LinearFilter;
 tex.generateMipmaps=true;tex.needsUpdate=true;
 return tex;
}
const grainStone=grain(197,'stone'),grainBark=grain(661,'bark'),grainBrass=grain(417,'metal');
// High-frequency tactile microstructure, derived solely from our local seeded
// bump textures. GPU-readable tangent normals + roughness variation make carved
// limestone, weathered bark and patinated brass visibly different in close-ups.
// Three shared 96px packs = six extra tiny textures, not dozens of downloads.
function microstructure(height,strength=.8){
 const n=height.image.width,src=height.image.data;
 const normals=new Uint8Array(n*n*4),roughness=new Uint8Array(n*n*4);
 const grey=(x,y)=>src[((((y+n)%n)*n+((x+n)%n))*4)];
 for(let y=0;y<n;y++)for(let x=0;x<n;x++){
  const i=(y*n+x)*4, center=grey(x,y);
  const dx=(grey(x+1,y)-grey(x-1,y))/255*strength;
  const dy=(grey(x,y+1)-grey(x,y-1))/255*strength;
  const inv=1/Math.hypot(dx,dy,1);
  normals[i]=Math.round(255*(1-dx*inv)*.5);
  normals[i+1]=Math.round(255*(1-dy*inv)*.5);
  normals[i+2]=Math.round(255*(1+inv)*.5);
  normals[i+3]=255;
  const rough=THREE.MathUtils.clamp(.58+center/255*.42,.48,1);
  const amount=Math.round(rough*255);
  roughness[i]=roughness[i+1]=roughness[i+2]=amount;
  roughness[i+3]=255;
 }
 const texture=(bytes)=>{
  const t=new THREE.DataTexture(bytes,n,n,THREE.RGBAFormat);
  t.wrapS=t.wrapT=THREE.RepeatWrapping;
  t.minFilter=THREE.LinearMipmapLinearFilter;t.magFilter=THREE.LinearFilter;
  t.generateMipmaps=true;t.needsUpdate=true;return t;
 };
 return Object.freeze({normalMap:texture(normals),roughnessMap:texture(roughness)});
}
const microStone=microstructure(grainStone,1.22);
const microBark=microstructure(grainBark,1.83);
const microBrass=microstructure(grainBrass,.31);

const mat=(color,roughness=0.9,extra={})=>new THREE.MeshStandardMaterial({color,roughness,...extra});
const P={
 bark:mat(0x594434,.97,{bumpMap:grainBark,bumpScale:.073,...microBark,normalScale:new THREE.Vector2(.67,.83)}),
 barkDeep:mat(0x332c25,1,{bumpMap:grainBark,bumpScale:.11,...microBark,normalScale:new THREE.Vector2(.78,.95)}),
 barkWarm:mat(0x926746,.9,{bumpMap:grainBark,bumpScale:.04,...microBark,normalScale:new THREE.Vector2(.55,.69)}),
 foliage:mat(0x426d51,.86,{side:THREE.DoubleSide}),
 foliageDeep:mat(0x284e43,.95,{side:THREE.DoubleSide}),
 foliageGold:mat(0x94ad68,.83,{side:THREE.DoubleSide}),
 foliageBright:mat(0xc4bd7a,.82,{side:THREE.DoubleSide}),
 stone:mat(0x8e9b8f,.96,{bumpMap:grainStone,bumpScale:.065,...microStone,normalScale:new THREE.Vector2(.72,.72)}),
 limestone:mat(0xc5c8ae,.91,{bumpMap:grainStone,bumpScale:.06,...microStone,normalScale:new THREE.Vector2(.54,.54)}),
 stoneDark:mat(0x596969,.99,{bumpMap:grainStone,bumpScale:.1,...microStone,normalScale:new THREE.Vector2(.86,.86)}),
 stoneMoss:mat(0x65806a,.99,{bumpMap:grainStone,bumpScale:.1,...microStone,normalScale:new THREE.Vector2(.58,.58)}),
 slate:mat(0x72837f,.91,{bumpMap:grainStone,bumpScale:.07,...microStone,normalScale:new THREE.Vector2(.8,.8)}),
 brass:mat(0xc5a36c,.24,{metalness:.84,bumpMap:grainBrass,bumpScale:.015,...microBrass,normalScale:new THREE.Vector2(.25,.3)}),
 brassDark:mat(0x77583a,.43,{metalness:.65,bumpMap:grainBrass,bumpScale:.024,...microBrass,normalScale:new THREE.Vector2(.3,.38)}),
 bronze:mat(0x9d875f,.46,{metalness:.59}),
 gold:mat(0xe8cb88,.22,{metalness:.73}),
 cord:mat(0xd4c7a3,.92),
 moon:mat(0xe9ecdc,.53),
 glass:mat(0xc1e7d9,.21,{metalness:.04,transparent:true,opacity:.64,side:THREE.DoubleSide,depthWrite:false}),
 fire:mat(0xffdb89,.25,{emissive:0xffac47,emissiveIntensity:3.0}),
 petalRose:mat(0xe3a9ac,.71,{side:THREE.DoubleSide}),
 petalCream:mat(0xece2c1,.65,{side:THREE.DoubleSide}),
 petalBlue:mat(0xaacac1,.65,{side:THREE.DoubleSide}),
 flowerHeart:mat(0xf4c36d,.5),
 mushroom:mat(0xd6b28b,.83),
 fungiTop:mat(0xb17051,.73),
 water:mat(0x8db6a7,.2,{metalness:.24,transparent:true,opacity:.7}),
 soil:mat(0x534f40,.98),
 rust:mat(0x946d50,.88)
};
export const SCULPT_QUALITY=Object.freeze({
 high:Object.freeze({branch:13,foliage:41,petals:12,masonry:22,engravings:15}),
 medium:Object.freeze({branch:6,foliage:15,petals:7,masonry:13,engravings:5})
});
const xyz=(p)=>new THREE.Vector3(p[0],p[1],p[2]);
function batch(){
 const containers=new Map();
 const transform=new THREE.Object3D();
 const add=(geometry,material,pos=[0,0,0],scale=[1,1,1],rot=[0,0,0],quat=null)=>{
  transform.position.set(...pos);transform.scale.set(...scale);
  if(quat)transform.quaternion.copy(quat);
  else transform.rotation.set(...(Array.isArray(rot)?rot:[0,0,0]));
  transform.updateMatrix();
  const transformed=geometry.index?geometry.toNonIndexed():geometry.clone();
  // Box/Cylinder are indexed while sculpted polyhedra are not: normalize
  // topology before batch merge, preserving normals/UVs and legal materials.
  transformed.applyMatrix4(transform.matrix);
  if(!containers.has(material))containers.set(material,[]);
  containers.get(material).push(transformed);
 };
 const box=(material,p,s,rot=0)=>add(UNIT.box,material,p,s,Array.isArray(rot)?rot:[0,rot,0]);
 const rock=(material,p,s,rot=0)=>add(UNIT.stone,material,p,s,[.18,rot,.1]);
 const pebble=(material,p,s,rot=0)=>add(UNIT.rock,material,p,s,[.1,rot,.2]);
 const orb=(material,p,s,rot=[0,0,0])=>add(UNIT.leaf,material,p,s,rot);
 const cone=(material,p,s)=>add(UNIT.cone,material,p,s);
 const rod=(material,p,s)=>add(UNIT.rod,material,p,s);
 const ring=(material,p,radius,rotation=[0,0,0])=>add(UNIT.ring,material,p,[radius,radius,radius],rotation);
 const joint=(material,start,end,width,topRatio=0.73)=>{
  const p=xyz(start),e=xyz(end),d=e.clone().sub(p),mid=p.add(e).multiplyScalar(.5);
  const quat=new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0,1,0),d.clone().normalize());
  add(topRatio>.91?UNIT.rod:UNIT.trunk,material,mid.toArray(),[width,d.length(),width],null,quat);
 };
 function flush(label,cast){
  const group=new THREE.Group();group.name=label;
  let triangles=0;
  for(const [material,geometryList] of containers){
   const merged=mergeGeometries(geometryList,false);
   for(const g of geometryList)g.dispose();
   if(!merged)throw new Error('Unable to merge detailed '+label);
   merged.computeBoundingSphere();
   const drawable=new THREE.Mesh(merged,material);
   drawable.castShadow=cast&&material!==P.glass&&material!==P.water;
   drawable.receiveShadow=true;
   group.add(drawable);
   triangles+=merged.index?merged.index.count/3:merged.attributes.position.count/3;
  }
  group.userData.detailTriangles=Math.round(triangles);
  group.userData.detailDrawCalls=group.children.length;
  group.userData.quality='sculpted';
  return group;
 }
 return {add,box,rock,pebble,orb,cone,rod,ring,joint,flush};
}
function tree(b,H,seed){
 const wood=P.bark,outline=P.barkDeep,brightness=seed%3===0?P.foliageGold:P.foliage;
 b.rock(P.soil,[0,.11,0],[.9,.2,.75]);
 b.joint(wood,[0,.16,0],[.07,2.85,.03],.26);
 for(let i=0;i<8;i++){
  const a=i*Math.PI*2/8+seed*.1;
  const start=[Math.sin(a)*.11,.27,Math.cos(a)*.11];
  const end=[Math.sin(a)*(1.03+(i%3)*.21),.08,Math.cos(a)*(.86+(i%2)*.15)];
  b.joint(i%2?wood:outline,start,end,.09,.55);
 }
 for(let k=0;k<(H?15:7);k++){
  const theta=(k*2.39996+seed*.17),height=.4+k*.137,r=.274;
  const x=Math.sin(theta)*r,z=Math.cos(theta)*r;
  b.joint(k%4?outline:P.barkWarm,[x*.91,height,z*.91],[x*.96,height+.37,z*.96],.016,1);
 }
 const branches=H?13:6;
 for(let i=0;i<branches;i++){
  const ring=Math.floor(i/4),phase=i*2.399963+seed*.19,reach=(1.15+((i%4)*.17))*(1-ring*.1);
  const side=Math.sin(phase),forward=Math.cos(phase);
  const y=1.43+(i%6)*.24;
  const shoulder=[side*.21,y,forward*.2];
  const elbow=[side*reach*.6,y+.63,forward*reach*.6];
  const tip=[side*reach,y+.92,forward*reach];
  b.joint(wood,shoulder,elbow,.12,.7);b.joint(wood,elbow,tip,.077,.6);
  if(H)for(let j=0;j<2;j++){
   const a=phase+(j?1:-1)*.56;
   b.joint(P.barkWarm,elbow,[tip[0]+Math.sin(a)*.39,tip[1]+(j?.26:.1),tip[2]+Math.cos(a)*.4],.035,.4);
  }
 }
 const count=H?41:15;
 for(let i=0;i<count;i++){
  const angle=i*2.399963+seed*.31;
  const spread=Math.sqrt((i+.5)/count);
  const radius=1.75*spread;
  const y=2.52+1.04*Math.sin(i*3.1)+.64*(1-spread);
  const x=Math.cos(angle)*radius,z=Math.sin(angle)*radius*.88;
  const w=.3+(i%4)*.09,h=.32+(i%3)*.1;
  b.orb(i%5===0?P.foliageGold:i%4===0?brightness:i%3===0?P.foliageDeep:P.foliage,[x,y,z],[w,h,w*.8],[0,angle*.2,Math.sin(angle)*.35]);
  if(H&&i%3===0)b.orb(P.foliageBright,[x+.13,y+.16,z-.09],[.16,.20,.09],[0,angle,.5]);
 }
 for(let i=0;i<(H?8:3);i++){
  const theta=i*2.4+seed*.2;
  b.pebble(P.stoneMoss,[Math.cos(theta)*.72,.11,Math.sin(theta)*.67],[.16,.1,.19],theta);
 }
}
function stone(b,H,seed){
 b.rock(P.stone,[0,.61,0],[1.35,.63,1.04],seed*.17);
 b.rock(P.limestone,[-.73,.4,.58],[.61,.37,.46],.35);
 b.rock(P.stoneDark,[.79,.43,-.49],[.51,.41,.48],.58);
 for(let i=0;i<(H?14:6);i++){
  const a=i*2.3999+seed*.03,r=.22+(i%5)*.18;
  const pos=[Math.cos(a)*r,.9+Math.sin(i*1.7)*.16,Math.sin(a)*r*.7];
  b.box(i%4?P.stoneMoss:P.slate,pos,[.04,.017,.15],[0,a,0]);
  if(i%3===0)b.pebble(P.stoneDark,[pos[0]+.06,pos[1]+.05,pos[2]],[.08,.08,.12],a);
 }
 if(H)for(let i=0;i<8;i++){
  const a=i*2.399963,r=.8+(i%2)*.2;
  b.orb(i%2?P.foliage:P.stoneMoss,[Math.cos(a)*r,.17,Math.sin(a)*r],[.17,.08,.23]);
 }
}
function lantern(b,H,allowLight){
 b.rock(P.stoneDark,[0,.18,0],[.53,.20,.53]);
 b.rock(P.limestone,[0,.37,0],[.36,.22,.32]);
 b.joint(P.brassDark,[0,.39,0],[0,2.52,0],.14,.75);
 for(let i=0;i<(H?4:2);i++){
  const a=i*Math.PI*2/(H?4:2)+Math.PI/4;
  const x=Math.cos(a)*.35,z=Math.sin(a)*.35;
  b.joint(P.brass,[x,2.36,z],[x,3.16,z],.05,1);
  b.orb(P.brass,[x,3.16,z],[.09,.07,.09]);
 }
 b.box(P.brassDark,[0,2.37,0],[.98,.18,.98]);
 b.box(P.brass,[0,3.18,0],[1.15,.14,1.15]);
 for(let i=0;i<(H?4:2);i++)b.box(P.glass,[0,2.77,i%2===0?.35:-.35],i%2===0?[.68,.65,.045]:[.045,.65,.68],i%2===0?0:.01);
 b.orb(P.fire,[0,2.77,0],[.29,.4,.29]);
 b.cone(P.brassDark,[0,3.42,0],[.62,.45,.62]);
 b.ring(P.brass,[0,3.66,0],.19,[Math.PI/2,0,0]);
 if(H)for(let i=0;i<10;i++){
  const a=i/10*Math.PI*2;
  b.box(P.gold,[Math.sin(a)*.44,3.18,Math.cos(a)*.44],[.085,.045,.08],a);
 }
 return allowLight;
}
function path(b,H){
 const count=H?12:7;
 for(let i=0;i<count;i++){
  const z=i*.38-(count-1)*.19,x=Math.sin(i*1.38)*.19;
  const w=.42+(i%3)*.035;
  b.box(i%3===0?P.limestone:i%2?P.slate:P.stone,[x,.15,z],[w,.18,.39],.03*Math.sin(i*3));
  b.box(P.stoneDark,[x,.055,z],[w+.06,.04,.41],.03*Math.sin(i*3));
  if(H)for(let j=0;j<3;j++){
   const lx=x+(j-1)*.13,zp=z+((j*2+i)%3-1)*.065;
   b.box(j%2?P.stoneMoss:P.limestone,[lx,.249,zp],[.025,.011,.064],Math.sin(i+j)*.55);
  }
 }
 for(let i=0;i<(H?12:5);i++){
  const z=(i*.62)%(count*.38)-(count*.38)/2,x=(i%2?1:-1)*(.57+(i%3)*.13);
  b.pebble(P.stoneMoss,[x,.13,z],[.09,.08,.11],i);
 }
}
function flower(b,H,seed){
 b.rock(P.soil,[0,.1,0],[.77,.18,.72]);
 const flowers=H?12:7;
 for(let i=0;i<flowers;i++){
  const a=i*2.39996+seed*.2,r=.19+.69*Math.sqrt((i+1)/flowers);
  const x=Math.cos(a)*r,z=Math.sin(a)*r,height=.75+.25*Math.sin(i*2.2);
  b.joint(P.foliageDeep,[x,.13,z],[x+.1*Math.sin(a),height,z],.029,1);
  b.orb(P.foliage,[x-.18,height*.55,z],[.22,.035,.095],[.27,a,.35]);
  b.orb(P.foliageGold,[x+.1,height*.62,z-.09],[.17,.04,.1],[0,a,.5]);
  const px=x+.1*Math.sin(a),py=height;
  const petals=H?6:5,pt=i%4===0?P.petalCream:i%3===0?P.petalBlue:P.petalRose;
  for(let j=0;j<petals;j++){
   const angle=j/petals*Math.PI*2;
   b.orb(pt,[px+Math.cos(angle)*.16,py, z+Math.sin(angle)*.16],[.14,.055,.09],[0,angle,-.13]);
  }
  b.orb(P.flowerHeart,[px,py+.033,z],[.085,.074,.085]);
 }
}
function arch(b,H,seed){
 b.box(P.stoneDark,[0,.18,0],[4.2,.36,2.1]);
 b.box(P.limestone,[0,.42,0],[3.94,.12,1.82]);
 for(let side of [-1,1]){
  const x=side*1.48;
  b.box(P.slate,[x,.63,0],[.8,.43,1.1]);
  for(let i=0;i<(H?5:3);i++){
   const y=.94+i*.31;
   b.box(i%3===0?P.limestone:i%2===0?P.stoneDark:P.stone,[x,y,0],[.71,.3,.89]);
   if(H){
    b.box(P.stoneDark,[x+(i%2?.27:-.27),y+.1,.454],[.09,.025,.023]);
    b.box(P.gold,[x,y,-.457],[.13,.03,.025]);
   }
  }
  b.box(P.limestone,[x,2.57,0],[.94,.24,1.08]);
 }
 const segments=H?22:13,r=1.52,centerY=2.55;
 for(let i=0;i<segments;i++){
  const a=(i+.5)/segments*Math.PI;
  const x=Math.cos(a)*r,y=centerY+Math.sin(a)*r;
  const mat=i===Math.floor(segments/2)?P.limestone:i%4===0?P.stoneDark:P.stone;
  b.box(mat,[x,y,0],[.245,.44,.91],-a+Math.PI/2);
  if(H&&i%2===0){
   const innerR=r-.2;
   b.box(P.brassDark,[Math.cos(a)*innerR,centerY+Math.sin(a)*innerR,.48],[.10,.075,.05],-a);
  }
 }
 b.box(P.gold,[0,4.22,.54],[.4,.17,.075]);
 if(H)for(let i=0;i<18;i++){
  const phase=i*2.39996+seed*.04,x=Math.sin(phase)*1.93,z=(i%3-1)*.53;
  b.orb(i%2?P.stoneMoss:P.foliage,[x,.36+Math.sin(i)*.07,z],[.13,.075,.13]);
 }
}
function chime(b,H){
 b.rock(P.stoneDark,[0,.14,0],[.56,.19,.51]);
 b.joint(P.bark,[0,.22,0],[0,3.18,0],.17);
 b.box(P.barkDeep,[0,3.02,0],[2.65,.21,.37]);
 b.box(P.brass,[0,3.15,0],[2.7,.07,.4]);
 const n=H?5:3;
 for(let i=0;i<n;i++){
  const x=(i-(n-1)/2)*.46;
  b.joint(P.cord,[x,2.96,0],[x,2.57-(i%3)*.09,0],.021,1);
  b.add(UNIT.rod,i%2?P.brass:P.bronze,[x,2.34-(i%3)*.10,0],[.19,.43+(i%2)*.2,.19]);
  b.add(UNIT.rod,P.brassDark,[x,2.09-(i%3)*.10,0],[.20,.055,.2]);
  b.orb(P.gold,[x,2.0-(i%3)*.10,0],[.105,.07,.105]);
  if(H)b.ring(P.gold,[x,2.67-(i%3)*.09,0],.08,[Math.PI/2,0,0]);
 }
 for(let i=0;i<3;i++)b.box(P.brassDark,[0,1.06+i*.39,0],[.22,.07,.25]);
}
function moss(b,H){
 const count=H?20:9;
 for(let i=0;i<count;i++){
  const angle=i*2.39996,rad=.2+Math.sqrt(i/count)*1.1,x=Math.cos(angle)*rad,z=Math.sin(angle)*rad;
  const w=.22+(i%4)*.04;
  b.orb(i%5===0?P.foliageGold:i%2?P.foliageDeep:P.foliage,[x,.21,z],[w,.2,w*1.08]);
  if(H&&i%4===0){
   b.joint(P.mushroom,[x,.2,z],[x,.46,z],.035,1);
   b.add(UNIT.cone,P.fungiTop,[x,.48,z],[.23,.21,.23]);
   b.orb(P.petalCream,[x-.085,.5,z+.02],[.032,.03,.028]);
  }
 }
 for(let i=0;i<(H?11:3);i++){
  const a=i*2.399,r=.28+(i%5)*.17;
  b.orb(P.moon,[Math.cos(a)*r,.36,Math.sin(a)*r],[.055,.055,.055]);
 }
}
function cairn(b,H){
 const count=H?7:5;
 b.rock(P.stoneDark,[0,.22,0],[1.35,.28,1.22]);
 for(let i=0;i<count;i++){
  const width=1.05-i*.126,offset=Math.sin(i*2.7)*.14;
  const material=i%3===0?P.limestone:i%2?P.slate:P.stone;
  b.rock(material,[offset,.43+i*.37,Math.cos(i*2.2)*.08],[width,.245,width*.82],i*.37);
  if(H){
   const y=.55+i*.37;
   b.box(P.gold,[offset+.01,y,width*.7],[.11,.021,.04],i*.3);
  }
 }
 if(H){
  b.ring(P.brass,[0,2.2,0],.38,[Math.PI/2,0,0]);
  for(let i=0;i<11;i++){
   const a=i*2.399963,r=1.1+(i%4)*.14;
   b.pebble(P.stoneMoss,[Math.cos(a)*r,.15,Math.sin(a)*r],[.12,.09,.17],a);
  }
 }
}
function marker(b,H){
 b.rock(P.stoneDark,[0,.16,0],[.64,.19,.59]);
 b.joint(P.barkDeep,[0,.21,0],[0,3.04,0],.21);
 b.box(P.barkWarm,[.57,2.67,0],[1.94,.74,.18],-.03);
 b.box(P.barkDeep,[.57,2.29,.0],[2.03,.1,.25]);
 b.box(P.brass,[.61,3.03,0],[2.05,.09,.22]);
 // Three-dimensional decorative lettering, readable as an abstract sigil.
 for(let i=0;i<(H?11:5);i++){
  const x=.02+i*.15;
  const y=2.57+((i*7)%5)*.05;
  b.box(i%3?P.gold:P.brassDark,[x,y,.11],[.085,.027,.02],.15*Math.sin(i*3));
 }
 b.cone(P.brassDark,[0,3.31,0],[.29,.49,.29]);
 if(H){
  for(let i=0;i<4;i++){
   const y=.64+i*.45;
   b.ring(P.cord,[0,y,0],.17,[Math.PI/2,0,0]);
  }
  b.joint(P.brass,[1.24,2.67,0],[1.42,2.74,0],.075,1);
 }
}
export function makePremiumTrace(tool,{size=1,quality='high',cast=true,seed=173,allowLight=false}={}){
 const H=quality==='high';const b=batch();
 if(tool==='tree')tree(b,H,seed);
 else if(tool==='stone')stone(b,H,seed);
 else if(tool==='light')lantern(b,H,allowLight);
 else if(tool==='path')path(b,H);
 else if(tool==='flower')flower(b,H,seed);
 else if(tool==='arch')arch(b,H,seed);
 else if(tool==='chime')chime(b,H);
 else if(tool==='moss')moss(b,H);
 else if(tool==='cairn')cairn(b,H);
 else if(tool==='marker')marker(b,H);
 else return new THREE.Group();
 const group=b.flush('Sculpted '+quality+' '+tool,cast);
 group.userData.quality=quality;
 if(tool==='light'&&allowLight){
  const light=new THREE.PointLight(0xffd4a1,2.5,8,2);
  light.position.set(0,2.75,0);light.castShadow=false;
  group.add(light);
 }
 group.scale.setScalar(size);
 return group;
}
export function premiumAssetsInfo(){
 return {quality:['high','medium'],materials:Object.keys(P).length,bumpTextures:3,normalTextures:3,roughnessTextures:3,batched:true,externalAssets:0};
}
