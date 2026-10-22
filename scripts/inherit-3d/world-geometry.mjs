// INHERIT R16 — procedural, physically lit 3D archipelago, no remote assets.
import * as THREE from 'three';
import {coastline,fieldHeight,vegetation,hash} from './terrain-core.mjs';
import {makeHeroTree,makeTrace} from './trace-models.mjs';
const earth=new THREE.MeshStandardMaterial({color:0x655f4d,roughness:1});
const rock=new THREE.MeshStandardMaterial({color:0x697b75,roughness:.95});
const waterStream=new THREE.MeshStandardMaterial({color:0x3b9f9b,metalness:.28,roughness:.27,transparent:true,opacity:.91,emissive:0x105b63,emissiveIntensity:.16});
function mesh(geo,mat){const m=new THREE.Mesh(geo,mat);m.castShadow=true;m.receiveShadow=true;return m;}
function topGeometry({rings=29,segments=92}={}){
 const positions=[],colors=[],indices=[],c=new THREE.Color();
 for(let ring=0;ring<=rings;ring++){
  const radius=ring/rings;
  for(let i=0;i<segments;i++){
   const a=i/segments*Math.PI*2,p=coastline(a),x=p.x*radius,z=p.z*radius,y=fieldHeight(x,z);
   positions.push(x,y,z);
   const variation=(hash(x*1.47,z*1.28,78)-.5)*.10;
   if(radius>.89)c.setHSL(.116,.34,.63+variation);
   else if(radius>.67)c.setHSL(.27,.30,.38+variation);
   else c.setHSL(.31,.35,.33+variation);
   colors.push(c.r,c.g,c.b);
   if(ring===rings)continue;
   const k=ring*segments+i,next=ring*segments+(i+1)%segments;
   indices.push(k,next,k+segments,next,next+segments,k+segments);
  }
 }
 const geo=new THREE.BufferGeometry();
 geo.setIndex(indices);geo.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));
 geo.setAttribute('color',new THREE.Float32BufferAttribute(colors,3));geo.computeVertexNormals();
 return geo;
}
function cliffGeometry(){
 const edges=92,vertical=7,positions=[],indices=[],colors=[],c=new THREE.Color();
 for(let j=0;j<=vertical;j++){
  const fraction=j/vertical;
  for(let i=0;i<edges;i++){
   const a=i/edges*Math.PI*2,p=coastline(a),scale=1-fraction*.054;
   const x=p.x*scale,z=p.z*scale,y=fieldHeight(p.x,p.z)-fraction*(3.1+.4*Math.sin(4*a));
   positions.push(x,y,z);c.setHSL(.10,.09,.34-fraction*.17+(hash(i,j,19)-.5)*.09);
   colors.push(c.r,c.g,c.b);
   if(j<vertical){
    const k=j*edges+i,n=j*edges+(i+1)%edges;indices.push(k,k+edges,n,n,k+edges,n+edges);
   }
  }
 }
 const geo=new THREE.BufferGeometry();geo.setIndex(indices);
 geo.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));
 geo.setAttribute('color',new THREE.Float32BufferAttribute(colors,3));geo.computeVertexNormals();return geo;
}
function ribbon(points,width,mat){
 const positions=[],ind=[];
 for(let i=0;i<points.length;i++){
  const p=points[i],a=points[Math.max(0,i-1)],b=points[Math.min(points.length-1,i+1)];
  const dx=b.x-a.x,dz=b.z-a.z,len=Math.hypot(dx,dz)||1,nx=-dz/len,nz=dx/len,y=fieldHeight(p.x,p.z)+.085;
  positions.push(p.x+nx*width/2,y,p.z+nz*width/2,p.x-nx*width/2,y,p.z-nz*width/2);
  if(i){const k=i*2;ind.push(k-2,k-1,k,k-1,k+1);}
 }
 const geo=new THREE.BufferGeometry();
 geo.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));geo.setIndex(ind);geo.computeVertexNormals();
 return mesh(geo,mat);
}
function makeRiver(){
 const pts=[];
 for(let i=0;i<=64;i++){const z=-18+i/64*36;pts.push({x:1.8+Math.sin(z*.17+1.3)*2.1+Math.sin(z*.41)*.45,z});}
 const stream=ribbon(pts,1.4,waterStream);stream.position.y=.055;stream.castShadow=false;return stream;
}
function makeRoad(){
 const pts=[];
 for(let i=0;i<=68;i++){const x=-19+i/68*38,z=.22*x+2*Math.sin(x*.19);pts.push({x,z});}
 const road=ribbon(pts,1.25,new THREE.MeshStandardMaterial({color:0x8c866d,roughness:.98}));
 road.position.y=.06;road.castShadow=false;return road;
}
function makeBeachFoam(){
 const pts=[],segments=120;
 for(let i=0;i<segments;i++){
  const a=i/segments*2*Math.PI,p=coastline(a),q=coastline((i+1)/segments*2*Math.PI);
  if(i%3===0)continue;
  pts.push(p.x*1.009,-1.9,p.z*1.015,q.x*1.011,-1.9,q.z*1.015);
 }
 const geo=new THREE.BufferGeometry();geo.setAttribute('position',new THREE.Float32BufferAttribute(pts,3));
 return new THREE.LineSegments(geo,new THREE.LineBasicMaterial({color:0xe3e5ce,transparent:true,opacity:.6,depthWrite:false}));
}
const waterVertex=[
'precision mediump float;',
'uniform float uTime;',
'varying vec2 vPos;',
'varying float vWave;',
'void main(){',
' vec3 p=position;',
' float wave=sin(p.x*.24+uTime*.55)*.08+cos(p.y*.28-uTime*.36)*.09;',
' p.z+=wave;vPos=p.xy;vWave=wave;',
' gl_Position=projectionMatrix*modelViewMatrix*vec4(p,1.);',
'}'
].join('\n');
const waterFragment=[
'precision mediump float;',
'uniform float uTime;',
'uniform float uDawn;',
'varying vec2 vPos;',
'varying float vWave;',
'void main(){',
' float ribbons=pow(max(0.,sin(vPos.x*.55+uTime*.5+sin(vPos.y*.23+uTime*.31))),13.);',
' float ribbons2=pow(max(0.,sin(vPos.y*.41-uTime*.27)),10.);',
' float ripples=.5+.5*sin(vPos.x*.37+vPos.y*.29+uTime*.62);',
' vec3 night=vec3(.045,.27,.33),day=vec3(.18,.51,.55);',
' vec3 base=mix(night,day,clamp(ripples*.65+uDawn*.38,0.,1.));',
' base+=vec3(.23,.29,.20)*ribbons*.28;',
' base+=vec3(.25,.38,.30)*ribbons2*.12;',
' base+=vWave*.16;',
' gl_FragColor=vec4(base,1.);',
'}'
].join('\n');
export function makeArchipelago({quality='high'}={}){
 const terrain=new THREE.Group();terrain.name='Original playable 3D island';
 const grassMat=new THREE.MeshStandardMaterial({vertexColors:true,roughness:.96,side:THREE.DoubleSide});
 terrain.add(mesh(topGeometry({rings:quality==='low'?19:29,segments:quality==='low'?60:92}),grassMat));
 terrain.add(mesh(cliffGeometry(),new THREE.MeshStandardMaterial({vertexColors:true,roughness:.99,side:THREE.DoubleSide})));
 const undershell=mesh(new THREE.CylinderGeometry(18.6,15.2,1.2,12),earth);
 undershell.scale.z=1.19;undershell.position.y=-2.5;terrain.add(undershell);
 const sea=new THREE.Mesh(new THREE.PlaneGeometry(140,110,20,20),new THREE.ShaderMaterial({
  uniforms:{uTime:{value:0},uDawn:{value:.53}},
  vertexShader:waterVertex,fragmentShader:waterFragment,side:THREE.DoubleSide,depthWrite:true
 }));
 sea.rotation.x=-Math.PI/2;sea.position.y=-2.21;terrain.add(sea);
 terrain.add(makeBeachFoam(),makeRiver(),makeRoad());
 const layout=vegetation(173,quality==='low'?34:quality==='medium'?57:91);
 const trees=layout.filter(x=>x.type==='tree'),bushes=layout.filter(x=>x.type==='bush');
 const trunkInst=new THREE.InstancedMesh(new THREE.CylinderGeometry(.14,.22,2.7,7),
  new THREE.MeshStandardMaterial({color:0x695137,roughness:.98}),trees.length);
 const crownInst=new THREE.InstancedMesh(new THREE.IcosahedronGeometry(1,1),
  new THREE.MeshStandardMaterial({color:0x639166,roughness:.95}),trees.length*2);
 trunkInst.castShadow=true;trunkInst.receiveShadow=true;crownInst.castShadow=true;crownInst.receiveShadow=true;
 const dummy=new THREE.Object3D(),color=new THREE.Color();
 for(let i=0;i<trees.length;i++){
  const p=trees[i],s=p.size;
  dummy.position.set(p.x,p.y+1.32*s,p.z);dummy.rotation.set(0,p.hue*6.28,0);dummy.scale.setScalar(s);
  dummy.updateMatrix();trunkInst.setMatrixAt(i,dummy.matrix);
  for(let j=0;j<2;j++){
   dummy.position.set(p.x+(j?-.48:.24)*s,p.y+(j?3.25:2.9)*s,p.z+(j?.13:0)*s);
   dummy.scale.set(s*(j?.85:1.12),s*(j?.94:1.05),s*(j?.89:1.15));dummy.updateMatrix();
   const k=i*2+j;crownInst.setMatrixAt(k,dummy.matrix);
   color.setHSL(.27+p.hue*.075,.32+p.hue*.1,.27+(i%4)*.045);crownInst.setColorAt(k,color);
  }
 }
 trunkInst.instanceMatrix.needsUpdate=true;crownInst.instanceMatrix.needsUpdate=true;
 if(crownInst.instanceColor)crownInst.instanceColor.needsUpdate=true;
 terrain.add(trunkInst,crownInst);
 const shrubs=new THREE.InstancedMesh(new THREE.IcosahedronGeometry(1,1),
  new THREE.MeshStandardMaterial({color:0x6d9c69,roughness:1}),bushes.length);
 shrubs.castShadow=true;
 for(let i=0;i<bushes.length;i++){
  const p=bushes[i],s=p.size*.54;dummy.position.set(p.x,p.y+.4*s,p.z);
  dummy.rotation.set(0,p.hue*6,0);dummy.scale.set(s*1.3,s*.65,s*1.1);dummy.updateMatrix();shrubs.setMatrixAt(i,dummy.matrix);
 }
 shrubs.instanceMatrix.needsUpdate=true;terrain.add(shrubs);
 const count=quality==='low'?44:125;
 const pebbles=new THREE.InstancedMesh(new THREE.IcosahedronGeometry(1,0),rock,count);
 for(let i=0;i<count;i++){
  const theta=i*2.399963,rad=4+Math.sqrt((i+1)/count)*18.5;
  const x=Math.cos(theta)*rad,z=Math.sin(theta)*rad*.82;
  dummy.position.set(x,fieldHeight(x,z)+.05,z);dummy.rotation.set(i*.19,i*.46,i*.19);
  const s=.09+hash(i,1,77)*.31;dummy.scale.set(s*1.5,s*.64,s);dummy.updateMatrix();pebbles.setMatrixAt(i,dummy.matrix);
 }
 pebbles.instanceMatrix.needsUpdate=true;terrain.add(pebbles);
 const landmarks=new THREE.Group();landmarks.name='Fictional template landmarks';
 const ancient=makeHeroTree();ancient.position.set(-7.2,fieldHeight(-7.2,-5),-5);landmarks.add(ancient);
 const sapling=makeTrace('tree',{size:1.25});sapling.position.set(11,fieldHeight(11,3),3);landmarks.add(sapling);
 const arch=makeTrace('arch',{size:1.35});arch.position.set(8.8,fieldHeight(8.8,-6),-6);landmarks.add(arch);
 const beacon=makeTrace('light',{size:1.25});beacon.position.set(-3,fieldHeight(-3,4),4);landmarks.add(beacon);
 terrain.add(landmarks);
 return {root:terrain,waterUniforms:sea.material.uniforms,landmarks};
}
