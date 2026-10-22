/* INHERIT R17 MATERIAL LAB
 * Three reusable tileable, 100% original procedural albedo/normal/roughness
 * material packs. Deterministic, CPU-generated once; no external photos,
 * runtime fetches, ad trackers, canvas permission or synthetic save data.
 */
import * as THREE from 'three';
import {hash,noise} from './terrain-core.mjs';
const FAMILIES=Object.freeze({
 earth:{rgb:[114,99,74],roughness:.94,normal:.58},
 limestone:{rgb:[172,175,157],roughness:.86,normal:.88},
 basalt:{rgb:[103,122,115],roughness:.84,normal:1.02},
 forest:{rgb:[152,185,134],roughness:.96,normal:.28},
 bark:{rgb:[129,99,72],roughness:.94,normal:.95},
 timber:{rgb:[163,133,94],roughness:.87,normal:.7},
 sand:{rgb:[210,196,150],roughness:.9,normal:.41},
 fern:{rgb:[136,176,131],roughness:.96,normal:.29},
});
const cache=new Map();
const saturate=v=>Math.max(0,Math.min(1,v));
const fract=v=>v-Math.floor(v);
export function mineralHeight(type,x,y,size,seed=173){
 // Wrapped coordinates and integer wavelengths make the map periodic.
 const u=x/size*Math.PI*2,v=y/size*Math.PI*2;
 const broad=.5+.20*Math.sin(u*3+Math.cos(v*2)*.63)+.16*Math.sin(v*4-u*2);
 const fine=(hash(Math.floor(x/3),Math.floor(y/3),seed)-.5)*.24+
   (hash(x,y,seed+113)-.5)*.11;
 let detail=0;
 if(type==='limestone'||type==='basalt'){
  detail=.17*Math.sin(u*7+v*2+.7*Math.sin(v*3))+
    .08*Math.sin(v*13-u*4)+.03*Math.cos(u*17);
 }else if(type==='bark'||type==='timber'){
  detail=.23*Math.sin(u*13+.48*Math.sin(v*2))+
    .13*Math.sin(u*26+v*1.8)+.07*Math.sin(u*43);
 }else if(type==='sand'){
  detail=.12*Math.sin(u*11+v*5)+.085*Math.sin(v*19-u*2);
 }else if(type==='forest'||type==='fern'){
  detail=.10*Math.sin(u*9+v*7)+.05*Math.sin(v*18-u*5);
 }else detail=.16*Math.sin(u*5-v*3)+.05*Math.sin(v*17);
 return saturate(broad+fine+detail);
}
function texture(data,size,repeat=1,normal=false){
 const t=new THREE.DataTexture(data,size,size,THREE.RGBAFormat);
 t.wrapS=t.wrapT=THREE.RepeatWrapping;
 t.minFilter=THREE.LinearMipmapLinearFilter;t.magFilter=THREE.LinearFilter;
 t.generateMipmaps=true;t.anisotropy=4;t.flipY=false;
 if(!normal)t.colorSpace=THREE.SRGBColorSpace;
 t.repeat.set(repeat,repeat);
 t.needsUpdate=true;
 return t;
}
export function createSurfacePack(type,{quality='high',seed=173}={}){
 if(!Object.hasOwn(FAMILIES,type))throw Error('Unknown physical surface '+type);
 const size=quality==='high'?192:quality==='medium'?128:64;
 const key=type+'|'+size+'|'+seed;
 if(cache.has(key))return cache.get(key);
 const meta=FAMILIES[type],levels=new Float32Array(size*size);
 for(let y=0;y<size;y++)for(let x=0;x<size;x++)levels[y*size+x]=mineralHeight(type,x,y,size,seed);
 const albedo=new Uint8Array(size*size*4),
   normal=new Uint8Array(size*size*4),rough=new Uint8Array(size*size*4);
 const read=(x,y)=>levels[((y+size)%size)*size+((x+size)%size)];
 for(let y=0;y<size;y++)for(let x=0;x<size;x++){
  const i=(y*size+x)*4,h=read(x,y);
  const grain=(hash(x,y,seed+17)-.5)*13,
    veins=(h-.5)*55,lichen=type==='limestone'&&h>.68?13:0;
  for(let ch=0;ch<3;ch++){
   const bi=meta.rgb[ch];
   const v=bi+veins*.62+grain+lichen*(ch===1?1:.35);
   albedo[i+ch]=Math.round(Math.max(7,Math.min(247,v)));
  }
  albedo[i+3]=255;
  const dx=(read(x+1,y)-read(x-1,y))*meta.normal*2.8;
  const dy=(read(x,y+1)-read(x,y-1))*meta.normal*2.8;
  const scale=1/Math.sqrt(dx*dx+dy*dy+1);
  normal[i]=Math.round((1-dx*scale)*127.5);
  normal[i+1]=Math.round((1-dy*scale)*127.5);
  normal[i+2]=Math.round((1+scale)*127.5);normal[i+3]=255;
  const micro=saturate(meta.roughness+(.5-h)*.18+
    (hash(x,y,seed+99)-.5)*.085);
  const rr=Math.round(micro*255);
  rough[i]=rr;rough[i+1]=rr;rough[i+2]=rr;rough[i+3]=255;
 }
 const pack=Object.freeze({
  map:texture(albedo,size),normalMap:texture(normal,size,1,true),
  roughnessMap:texture(rough,size,1,true),size,
  bytes:albedo.byteLength+normal.byteLength+rough.byteLength,
  type,quality,
  sample:(x,y)=>levels[(((y%size)+size)%size)*size+(((x%size)+size)%size)]
 });
 cache.set(key,pack);
 return pack;
}
export function makeSurfaceMaterial(type,{quality='high',vertexColors=false,side=THREE.FrontSide,repeat=1,seed=173}={}){
 if(quality==='low'){
  const p=FAMILIES[type];
  return new THREE.MeshStandardMaterial({color:new THREE.Color().setRGB(
   p.rgb[0]/255,p.rgb[1]/255,p.rgb[2]/255,THREE.SRGBColorSpace),
   roughness:p.roughness,side,vertexColors});
 }
 const pack=createSurfacePack(type,{quality,seed});
 // Diffuse maps already carry calibrated material color; avoid double tint.
 const mat=new THREE.MeshStandardMaterial({
  map:pack.map,normalMap:pack.normalMap,roughnessMap:pack.roughnessMap,
  normalScale:new THREE.Vector2(.51,.51),
  color:0xffffff,roughness:FAMILIES[type].roughness,
  metalness:type==='basalt'?.045:.008,
  side,vertexColors
 });
 if(repeat!==1){
  // The family textures are shared. Cloning for a repeated UV variant is
  // safer than mutating the common pack used by multiple meshes.
  for(const field of ['map','normalMap','roughnessMap']){
   mat[field]=mat[field].clone();
   mat[field].repeat.set(repeat,repeat);
   mat[field].needsUpdate=true;
  }
 }
 return mat;
}
export function surfacePackStats(){
 return {packs:cache.size,textureBytes:[...cache.values()].reduce((n,p)=>n+p.bytes,0),
  families:Object.keys(FAMILIES)};
}
