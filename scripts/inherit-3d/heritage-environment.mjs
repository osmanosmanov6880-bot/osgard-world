/* INHERIT R16.4 — original, high-detail architectural environment.
 * Actual GPU meshes: carved cliff sanctuary, fluted columns, masonry arches,
 * old harbor, joined wooden pier, sculpted rowing skiff, ropes and beach litter.
 * All assets are created locally; no textures downloaded and no game writes.
 */
import * as THREE from 'three';
import {fieldHeight,hash} from './terrain-core.mjs';

const PI=Math.PI,TAU=PI*2;
const TIERS=Object.freeze({
 high:{courses:7,blocks:144,columns:12,tiles:124,rubble:110,vines:136,planks:38,posts:16,drift:54,boatLong:30,boatCross:18,rope:64,details:true},
 medium:{courses:5,blocks:76,columns:9,tiles:64,rubble:55,vines:64,planks:25,posts:12,drift:24,boatLong:20,boatCross:12,rope:32,details:true},
 low:{courses:4,blocks:32,columns:6,tiles:20,rubble:18,vines:20,planks:16,posts:8,drift:8,boatLong:12,boatCross:8,rope:12,details:false}
});
const BASE_BOX=new THREE.BoxGeometry(1,1,1);
const STONE_GEO=new THREE.IcosahedronGeometry(1,1);
const LEAF_GEO=new THREE.IcosahedronGeometry(1,0);
const WORKER=new THREE.Object3D();
function stoneMaps(){
 const n=96,N=new Uint8Array(n*n*4),R=new Uint8Array(n*n*4);
 const h=(x,y)=>Math.max(.04,Math.min(.96,
  .5+.19*Math.sin(x*.27+y*.044)+.15*Math.sin(y*.73-x*.056)
   +(hash(Math.floor(x/4),Math.floor(y/6),57)-.5)*.23));
 for(let y=0;y<n;y++)for(let x=0;x<n;x++){
  const k=(y*n+x)*4,dx=(h(x+1,y)-h(x-1,y))*.47,dy=(h(x,y+1)-h(x,y-1))*.47;
  const norm=Math.hypot(dx,dy,1);
  N[k]=Math.round(127.5-127.5*dx/norm);
  N[k+1]=Math.round(127.5-127.5*dy/norm);
  N[k+2]=Math.round(127.5+127.5/norm);N[k+3]=255;
  const rough=Math.round((.73+.25*h(x,y))*255);
  R[k]=R[k+1]=R[k+2]=rough;R[k+3]=255;
 }
 function tex(bytes){
  const t=new THREE.DataTexture(bytes,n,n,THREE.RGBAFormat);
  t.wrapS=t.wrapT=THREE.RepeatWrapping;
  t.minFilter=THREE.LinearMipmapLinearFilter;t.magFilter=THREE.LinearFilter;
  t.generateMipmaps=true;t.needsUpdate=true;return t;
 }
 return {normal:tex(N),roughness:tex(R)};
}
const DETAIL_MAPS=stoneMaps();
const weathered=color=>new THREE.MeshStandardMaterial({
 color,metalness:.015,roughness:.87,normalMap:DETAIL_MAPS.normal,
 roughnessMap:DETAIL_MAPS.roughness,normalScale:new THREE.Vector2(.28,.28)
});
const MAT={
 stone:weathered(0xadb4a6),pale:weathered(0xc8c6b4),
 slate:weathered(0x687b72),moss:weathered(0x759577),
 timber:new THREE.MeshStandardMaterial({color:0x84654a,roughness:.91}),
 darkTimber:new THREE.MeshStandardMaterial({color:0x463a31,roughness:.95}),
 amberTimber:new THREE.MeshStandardMaterial({color:0xaf8862,roughness:.82}),
 copper:new THREE.MeshStandardMaterial({color:0x9d7562,metalness:.71,roughness:.36}),
 brass:new THREE.MeshStandardMaterial({color:0xd3b67d,metalness:.81,roughness:.29}),
 window:new THREE.MeshStandardMaterial({color:0x1b4046,metalness:.19,roughness:.15}),
 glass:new THREE.MeshStandardMaterial({color:0xfbd5a2,emissive:0xf8a650,emissiveIntensity:1.1,roughness:.22}),
 leaves:new THREE.MeshStandardMaterial({color:0x4c7958,roughness:.94}),
 rope:new THREE.MeshStandardMaterial({color:0xc9b58b,roughness:.99})
};
function mesh(parent,geometry,mat,p=[0,0,0],scale=[1,1,1],rotation=[0,0,0],shadow=true){
 const m=new THREE.Mesh(geometry,mat);
 m.position.set(...p);m.scale.set(...scale);m.rotation.set(...rotation);
 m.castShadow=shadow;m.receiveShadow=true;parent.add(m);return m;
}
function box(g,mat,xyz,size,rot=0){
 return mesh(g,BASE_BOX,mat,xyz,size,[0,rot,0]);
}
function color(base,i){
 const c=new THREE.Color(base);
 c.offsetHSL((hash(i,13,71)-.5)*.025,0,(hash(i,23,91)-.5)*.14);
 return c;
}
function instanced(group,geo,material,count,name,place,withColors=false){
 const m=new THREE.InstancedMesh(geo,material,count);m.name=name;m.receiveShadow=true;m.castShadow=false;
 for(let i=0;i<count;i++){
  WORKER.position.set(0,0,0);WORKER.rotation.set(0,0,0);WORKER.scale.set(1,1,1);
  place(i,WORKER,m);
  WORKER.updateMatrix();m.setMatrixAt(i,WORKER.matrix);
 }
 m.instanceMatrix.needsUpdate=true;
 if(withColors&&m.instanceColor)m.instanceColor.needsUpdate=true;
 m.computeBoundingSphere();group.add(m);return m;
}
function tube(group,pts,radius,mat,segments){
 const curve=new THREE.CatmullRomCurve3(pts.map(v=>new THREE.Vector3(...v)),false,'centripetal');
 return mesh(group,new THREE.TubeGeometry(curve,segments,radius,6,false),mat);
}
function flutedColumn(){
 const geometry=new THREE.CylinderGeometry(.19,.24,2.86,48,7);
 const positions=geometry.attributes.position;
 for(let i=0;i<positions.count;i++){
  const x=positions.getX(i),z=positions.getZ(i);
  const flutes=1-.065*(.5+.5*Math.cos(Math.atan2(z,x)*14));
  positions.setXYZ(i,x*flutes,positions.getY(i),z*flutes);
 }
 positions.needsUpdate=true;geometry.computeVertexNormals();return geometry;
}
function makeSanctuary(q){
 const group=new THREE.Group();
 group.name='Sculpted sanctuary | masonry and fluted colonnades';
 group.position.set(-14,fieldHeight(-14,-9)+.18,-9);
 // Layered twelve-sided dressed stone plinth and patterned mosaic.
 for(let i=0;i<3;i++)mesh(group,new THREE.CylinderGeometry(3.62-i*.13,3.71-i*.13,.32,12),
  i%2?MAT.slate:MAT.stone,[0,.04+i*.23,0]);
 mesh(group,new THREE.CylinderGeometry(3.31,3.36,.09,12),MAT.pale,[0,.79,0]);
 mesh(group,new THREE.TorusGeometry(2.35,.052,7,q.details?80:32),
  MAT.brass,[0,.855,0],[1,1,1],[PI/2,0,0]);
 // Independent slab joints and mineral coloring, but just one draw call.
 instanced(group,BASE_BOX,MAT.stone,q.blocks,'Instanced dressed limestone courses',(i,d,m)=>{
  const idx=Math.floor(i/q.courses),course=i%q.courses;
  const per=Math.ceil(q.blocks/q.courses),theta=(idx+.5*(course%2))*TAU/per;
  const radius=3.55-.045*course+(hash(i,4,203)-.5)*.12;
  d.position.set(Math.cos(theta)*radius,.05+.245*course,Math.sin(theta)*radius);
  d.rotation.y=-theta;
  d.scale.set(.14+.07*hash(i,5,14),.215,.55+hash(i,7,9)*.08);
  m.setColorAt(i,color(0xb9baa9,i));
 },true);
 instanced(group,BASE_BOX,MAT.pale,q.tiles,'Individually colored mosaic tesserae',(i,d,m)=>{
  const radial=.45+Math.sqrt((i+.5)/q.tiles)*1.74;
  const a=i*2.399963;
  d.position.set(Math.cos(a)*radial,.855,Math.sin(a)*radial);
  d.rotation.y=a;d.scale.set(.22,.045,.12);
  m.setColorAt(i,color(i%9===0?0xcba773:i%3===0?0x71897b:0xc8c6af,i));
 },true);
 // Many genuinely fluted shafts: silhouettes are high-poly, not flat billboards.
 const col=flutedColumn();
 instanced(group,col,MAT.pale,q.columns,'Carved fluted stone pillars',(i,d)=>{
  const angle=(i+.5)/q.columns*TAU;
  d.position.set(Math.cos(angle)*2.67,2.42,Math.sin(angle)*2.67);
  d.rotation.y=angle;
 });
 instanced(group,BASE_BOX,MAT.slate,q.columns,'Stone capitals and abaci',(i,d)=>{
  const angle=(i+.5)/q.columns*TAU;
  d.position.set(Math.cos(angle)*2.67,3.9,Math.sin(angle)*2.67);
  d.rotation.y=angle;d.scale.set(.52,.17,.52);
 });
 instanced(group,BASE_BOX,MAT.pale,q.columns,'Stone column bases',(i,d)=>{
  const angle=(i+.5)/q.columns*TAU;
  d.position.set(Math.cos(angle)*2.67,.995,Math.sin(angle)*2.67);
  d.rotation.y=angle;d.scale.set(.58,.2,.59);
 });
 // Broken aqueduct entrance with voussoir segments and a true arched opening.
 for(const sx of [-1.03,1.03]){
  box(group,MAT.slate,[sx,1.77,3.04],[.48,1.95,.67]);
  box(group,MAT.pale,[sx,2.82,3.04],[.63,.18,.72]);
 }
 const stones=q.details?18:9;
 instanced(group,BASE_BOX,MAT.stone,stones,'Individual arch voussoirs',(i,d,m)=>{
  const angle=(i+.5)/stones*PI;
  d.position.set(Math.cos(angle)*1.05,2.73+Math.sin(angle)*1.05,3.04);
  d.rotation.z=-angle;
  d.scale.set(.29,.31,.73);
  m.setColorAt(i,color(i===Math.floor(stones/2)?0xe2d8c2:0xadb3a7,i));
 },true);
 const keystone=box(group,MAT.brass,[0,3.88,3.43],[.32,.18,.095]);
 keystone.rotation.z=.08;
 // Multi-course tapered octagonal keep with crenellated lookout.
 const keep=new THREE.Group();keep.name='Octagonal lighthouse of generations';
 keep.position.set(-.82,.72,-.94);
 group.add(keep);
 mesh(keep,new THREE.CylinderGeometry(1.03,1.24,3.52,12,q.details?7:2),
  MAT.slate,[0,1.76,0]);
 const layers=q.courses;
 instanced(keep,BASE_BOX,MAT.stone,layers*12,'Separate octagonal tower masonry seams',(i,d,m)=>{
  const row=Math.floor(i/12),side=i%12,theta=(side+(row%2)*.5)*TAU/12;
  const rad=1.18-row*.024;
  d.position.set(Math.cos(theta)*rad,.36+row*.49,Math.sin(theta)*rad);
  d.rotation.y=-theta;d.scale.set(.19,.085,.49);
  m.setColorAt(i,color(0xa2ac9f,i));
 },true);
 mesh(keep,new THREE.CylinderGeometry(1.18,1.22,.26,12),MAT.pale,[0,3.48,0]);
 const battlements=q.details?16:8;
 instanced(keep,BASE_BOX,MAT.stone,battlements,'Parapet crenellations',(i,d)=>{
  const a=i/battlements*TAU;
  d.position.set(Math.cos(a)*1.05,3.74,Math.sin(a)*1.05);
  d.rotation.y=-a;d.scale.set(.26,.42,.38);
 });
 mesh(keep,new THREE.ConeGeometry(1.3,1.31,12,q.details?2:1),
  MAT.copper,[0,4.57,0]);
 mesh(keep,new THREE.SphereGeometry(.18,16,10),MAT.brass,[0,5.3,0]);
 mesh(keep,new THREE.CylinderGeometry(.038,.09,.77,8),MAT.brass,[0,5.7,0]);
 // Deep windows + bronze ribs give depth even from a distance.
 for(const angle of [PI*.22,PI*.88,PI*1.65]){
  const x=Math.cos(angle)*1.06,z=Math.sin(angle)*1.06;
  const glass=mesh(keep,new THREE.PlaneGeometry(.45,.95),MAT.window,[x,2.04,z],[1,1,1],[0,angle+PI/2,0],false);
  const rim=mesh(keep,new THREE.TorusGeometry(.29,.055,8,18,PI),
   MAT.brass,[x*1.02,2.57,z*1.02],[1,1,1],[0,angle+PI/2,0],false);
  rim.rotation.z=.06;
 }
 // Vegetation genuinely climbs over the walls.
 instanced(group,LEAF_GEO,MAT.leaves,q.vines,'Sculpted climbing foliage',(i,d,m)=>{
  const a=i*2.399963,wall=i%4===0?2.77:3.47;
  const x=Math.cos(a)*wall,z=Math.sin(a)*wall;
  d.position.set(x,.47+hash(i,17,22)*(i%4===0?2.8:1.48),z);
  d.rotation.set(.18,a,.42);
  const size=.075+.11*hash(i,18,86);
  d.scale.set(size*1.32,size*.44,size);
  m.setColorAt(i,color(i%4===0?0x8aa473:0x436f50,i));
 },true);
 instanced(group,STONE_GEO,MAT.slate,q.rubble,'Weathered foundation rubble',(i,d,m)=>{
  const a=i*2.399963,rad=3.7+.93*hash(i,18,7);
  d.position.set(Math.cos(a)*rad,.12,Math.sin(a)*rad);
  d.rotation.set(.12*i,a,.06*i);
  const k=.1+.19*hash(i,19,11);
  d.scale.set(k,k*.59,k*1.15);
  m.setColorAt(i,color(i%4?0x85958c:0xb6baad,i));
 },true);
 // Lanterns emit little diffuse light; only the high tier adds two GPU lights.
 for(const x of [-2.75,2.75]){
  box(group,MAT.brass,[x,1.06,1.77],[.12,.68,.13]);
  mesh(group,new THREE.IcosahedronGeometry(.18,1),MAT.glass,[x,1.53,1.77],[1,1,1]);
  if(q.details&&q.blocks>100){
   const light=new THREE.PointLight(0xf8c486,.36,5,2);
   light.position.set(x,1.56,1.77);group.add(light);
  }
 }
 group.userData.heritageSite='sanctuary';
 return group;
}
function boatGeometry(lengthSegments,crossSegments){
 // Double-sided curved *hollow* hull, with open upper lip and joined keel.
 const positions=[],colors=[],index=[],c=new THREE.Color();
 for(let i=0;i<=lengthSegments;i++){
  const u=i/lengthSegments,x=(u-.5)*3.85;
  const width=.92*Math.pow(Math.max(0,Math.sin(PI*u)),.67);
  for(let j=0;j<=crossSegments;j++){
   const a=-PI/2+PI*j/crossSegments;
   const z=width*Math.sin(a);
   const y=.25-.70*Math.cos(a)+.025*Math.sin(u*11);
   positions.push(x,y,z);
   c.setHSL(.072+.013*Math.cos(a),.31,.28+.09*u+.035*Math.cos(j));
   colors.push(c.r,c.g,c.b);
   if(i<lengthSegments&&j<crossSegments){
    const k=i*(crossSegments+1)+j,n=k+crossSegments+1;
    index.push(k,n,k+1,k+1,n,n+1);
   }
  }
 }
 const g=new THREE.BufferGeometry();g.setIndex(index);
 g.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));
 g.setAttribute('color',new THREE.Float32BufferAttribute(colors,3));g.computeVertexNormals();return g;
}
function makeSkiff(q){
 const boat=new THREE.Group();boat.name='Sculpted oak rowing skiff with ribs and ropes';
 const hullMat=new THREE.MeshStandardMaterial({vertexColors:true,roughness:.87,metalness:.02,side:THREE.DoubleSide});
 mesh(boat,boatGeometry(q.boatLong,q.boatCross),hullMat);
 // Interior backbone and individual transverse hull ribs.
 box(boat,MAT.darkTimber,[0,-.32,0],[3.56,.14,.12]);
 const ribCount=q.details?11:6;
 instanced(boat,BASE_BOX,MAT.amberTimber,ribCount,'Boat transverse ribs',(i,d)=>{
  const u=(i+.8)/(ribCount+.6),x=(u-.5)*3.45;
  d.position.set(x,-.14,0);d.rotation.x=.045*Math.sin(i);
  d.scale.set(.075,.075,1.5*Math.pow(Math.sin(PI*u),.65));
 });
 for(const x of [-1.04,0,1.03])box(boat,MAT.amberTimber,[x,.105,0],[.24,.11,1.52]);
 // Two separately modeled sheer rails follow the actual hull contour.
 for(const side of [-1,1]){
  const pts=[];
  const segments=q.details?22:10;
  for(let i=0;i<=segments;i++){
   const u=i/segments,x=(u-.5)*3.84;
   const width=.92*Math.pow(Math.max(0,Math.sin(PI*u)),.67);
   pts.push([x,.255+.024*Math.sin(u*11),width*side]);
  }
  tube(boat,pts,.055,MAT.amberTimber,q.rope);
 }
 if(q.details){
  // Both oars have a shaft, broad blade, and bronze collar.
  for(const side of [-1,1]){
   const pos=[-.11,.15,side*.55];
   const oar=new THREE.Group();boat.add(oar);oar.position.set(...pos);
   const o=mesh(oar,new THREE.CylinderGeometry(.048,.07,3.18,10),
    MAT.amberTimber,[0,.07,side*1.14],[1,1,1],[PI/2,0,side*.15]);
   box(oar,MAT.amberTimber,[0,.08,side*2.54],[.29,.065,.68]);
   mesh(oar,new THREE.TorusGeometry(.085,.022,7,16),MAT.brass,[0,.14,side*.78],[1,1,1],[PI/2,0,0]);
  }
  const ropes=[];
  for(let i=0;i<=7;i++){
   const a=i/7*TAU;
   ropes.push([.4+Math.sin(a)*.23,-.06,.31+Math.cos(a)*.22]);
  }
  tube(boat,ropes,.028,MAT.rope,24);
 }
 const bow=mesh(boat,new THREE.ConeGeometry(.15,.48,12),MAT.brass,[1.88,.36,0],[1,1,1],[0,0,-PI/2]);
 boat.userData.heritageSite='skiff';
 return boat;
}
function makeHarbor(q){
 const group=new THREE.Group();group.name='Joined timber quay and coastal objects';
 // Actual shore near x=21, z=9.5. Pier projects into the modeled sea.
 group.position.set(17.8,0,9.5);
 const deckY=-.86,extent=7.12;
 instanced(group,BASE_BOX,MAT.amberTimber,q.planks,'Individually weathered pier deck planks',(i,d,m)=>{
  const u=i/(q.planks-1),x=.4+extent*u;
  d.position.set(x,deckY+.012*Math.sin(i*2.13),0);
  d.rotation.y=.014*Math.sin(i*1.91);
  d.scale.set(.94*extent/q.planks,.16,2.65);
  m.setColorAt(i,color(i%5===0?0x695640:0xaa8561,i));
 },true);
 const postCount=q.posts;
 instanced(group,new THREE.CylinderGeometry(.10,.15,2.65,10),MAT.timber,postCount,'Pier piling joinery',(i,d)=>{
  const u=(i%Math.ceil(postCount/2))/Math.max(1,Math.ceil(postCount/2)-1);
  const side=i<Math.ceil(postCount/2)?-1:1;
  d.position.set(.55+u*7,-2.05,side*1.17);
  d.scale.set(1,1,1);
 });
 // Curved rope handrails between bronze-braced piles.
 for(const side of [-1,1]){
  const pts=[];
  for(let i=0;i<9;i++){
   const u=i/8, sag=.14*Math.pow(Math.sin(PI*u*7),2);
   pts.push([.53+u*7,-.35-sag,side*1.25]);
  }
  tube(group,pts,.038,MAT.rope,q.rope);
  for(let k=0;k<5;k++){
   const x=.55+k*1.75;
   box(group,MAT.brass,[x,-.44,side*1.25],[.22,.06,.22]);
  }
 }
 // Set stone steps from the land down to the old wooden landing.
 const steps=q.details?9:5;
 for(let i=0;i<steps;i++){
  const u=(i+.5)/steps,x=-2.1+u*2.2;
  const ground=fieldHeight(15.7,9.5);
  box(group,i%2?MAT.stone:MAT.pale,[x,ground+(deckY-ground)*u,0],[2.4/steps,.21,2.62]);
 }
 // Harbor lanterns: emissive glass without overloading shadow budget.
 for(const x of [.55,6.7]){
  box(group,MAT.darkTimber,[x,-.33,-1.4],[.14,1.19,.14]);
  mesh(group,new THREE.BoxGeometry(.37,.44,.37),MAT.glass,[x,.51,-1.4]);
  box(group,MAT.brass,[x,.79,-1.4],[.49,.085,.49]);
 }
 const skiff=makeSkiff(q);
 skiff.position.set(8.65,-1.9,2.7);
 skiff.rotation.y=-.22;group.add(skiff);
 // Driftwood logs, broken planks, shell pebbles and moss — instanced.
 instanced(group,new THREE.CylinderGeometry(.09,.14,1,8),MAT.timber,q.drift,
   'Storm washed driftwood',(i,d,m)=>{
    const a=i*2.399963,rad=2.9+hash(i,24,18)*3.0;
    const x=-2.7+Math.cos(a)*rad,z=Math.sin(a)*rad*1.05;
    d.position.set(x,fieldHeight(17.8+x,9.5+z)+.10,z);
    d.rotation.set(.4,a,PI/2);
    const k=.45+hash(i,17,99);
    d.scale.set(k,k*.85,k);
    m.setColorAt(i,color(i%3?0x927a59:0xb0a080,i));
   },true);
 group.userData.heritageSite='harbor';
 return group;
}
export function makeHeritageEnvironment({quality='high'}={}){
 const tier=TIERS[quality]||TIERS.low;
 const root=new THREE.Group();root.name='INHERIT / Architectural Heritage World';
 root.add(makeSanctuary(tier),makeHarbor(tier));
 root.userData.quality=quality;
 root.userData.assetStats={
  tier:quality,stoneBlocks:tier.blocks,flutedColumns:tier.columns,mosaicTiles:tier.tiles,
  climbingLeaves:tier.vines,boatHullSegments:tier.boatLong*tier.boatCross,
  harborPlanks:tier.planks,coastalDebris:tier.drift
 };
 return root;
}
export function heritageEnvironmentInfo(){
 return {originalModels:3,sites:['sanctuary','harbor','skiff'],
  materials:12,proceduralNormalTextures:1,proceduralRoughnessTextures:1,
  drawCallStrategy:'instanced masonry, mosaics, debris and fluted columns',
  tiers:TIERS,externalAssets:0};
}
