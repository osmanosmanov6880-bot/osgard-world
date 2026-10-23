/* INHERIT R23 — local, season-aware PBR image-based lighting.
 * Offline deterministic equirectangular radiance; the engine prefilters it
 * for physically based metal and clearcoat. Background and gameplay stay native.
 * Low quality and software adapters skip the environment map entirely.
 */
import * as THREE from 'three';

export const SKY_TIERS=Object.freeze({
 low:Object.freeze({width:0,height:0}),
 medium:Object.freeze({width:128,height:64}),
 high:Object.freeze({width:256,height:128})
});
const SEASONS=Object.freeze({
 tide:{zenith:[74,123,149],horizon:[169,191,185],sea:[38,89,93],sun:[250,224,171],strength:.72},
 sun:{zenith:[77,148,171],horizon:[224,204,161],sea:[58,113,113],sun:[255,229,168],strength:1.0},
 wind:{zenith:[71,107,126],horizon:[146,172,174],sea:[40,79,92],sun:[220,215,196],strength:.56},
 mist:{zenith:[137,166,164],horizon:[181,195,184],sea:[93,123,120],sun:[225,224,204],strength:.33}
});
const clamp=(n,lo=0,hi=1)=>Math.min(hi,Math.max(lo,n));
const mix=(a,b,t)=>a+(b-a)*t;
const smooth=t=>{const q=clamp(t);return q*q*(3-2*q);};
export function makeSkyPanorama(season='tide',{quality='high'}={}){
 const key=Object.hasOwn(SEASONS,season)?season:'tide';
 const tier=SKY_TIERS[quality]||SKY_TIERS.low;
 if(!tier.width)return null;
 const {width,height}=tier,p=SEASONS[key];
 const pixels=new Uint8Array(width*height*4);
 for(let y=0;y<height;y++)for(let x=0;x<width;x++){
  const u=(x+.5)/width,v=(y+.5)/height;
  const towardsHorizon=smooth(v/.54);
  const down=smooth((v-.51)/.49);
  const cloud=(Math.sin(u*Math.PI*14+Math.sin(v*19)*1.6)*Math.sin(v*37+u*Math.PI*6))*.055;
  const dU=Math.min(Math.abs(u-.71),1-Math.abs(u-.71)),dV=v-.30;
  const sunDisc=Math.exp(-(dU*dU/(.012*.012)+dV*dV/(.026*.026))*1.6);
  const halo=Math.exp(-(dU*dU/(.08*.08)+dV*dV/(.11*.11))*2.2);
  const k=(y*width+x)*4;
  for(let c=0;c<3;c++){
   const ambient=mix(p.zenith[c],p.horizon[c],towardsHorizon);
   const color=mix(ambient,p.sea[c],down*.92);
   pixels[k+c]=Math.round(clamp(color*(1+cloud*(1-down))+
    halo*(p.sun[c]-color)*.24+sunDisc*(p.sun[c]-color),0,255));
  }
  pixels[k+3]=255;
 }
 const texture=new THREE.DataTexture(pixels,width,height,THREE.RGBAFormat);
 texture.name='INHERIT R23 original '+key+' PBR sky reflections';
 texture.mapping=THREE.EquirectangularReflectionMapping;
 texture.wrapS=THREE.RepeatWrapping;
 texture.minFilter=THREE.LinearFilter;
 texture.magFilter=THREE.LinearFilter;
 texture.generateMipmaps=false;
 texture.colorSpace=THREE.SRGBColorSpace;
 texture.needsUpdate=true;
 return texture;
}
export function makeSkyLighting({quality='high',software=false}={}){
 const enabled=!software&&quality!=='low'&&Boolean(SKY_TIERS[quality]?.width);
 const cache=new Map();
 let scene=null,season='tide',writes=0;
 function setSeason(next='tide',target=scene){
  season=Object.hasOwn(SEASONS,next)?next:'tide';
  if(target)scene=target;
  if(!scene)return null;
  if(!enabled){
   scene.environment=null;scene.environmentIntensity=1;
   return null;
  }
  if(!cache.has(season))cache.set(season,makeSkyPanorama(season,{quality}));
  const texture=cache.get(season);
  scene.environment=texture;
  scene.environmentIntensity=SEASONS[season].strength;
  return texture;
 }
 function stats(){
  const dims=SKY_TIERS[quality]||SKY_TIERS.low;
  return Object.freeze({enabled,quality,season,resolution:[dims.width,dims.height],
   generated:cache.size,textureBytes:[...cache.values()].reduce((n,t)=>n+(t.image?.data?.byteLength||0),0),
   externalAssets:0,gameplayWrites:writes,hardwareVerified:false});
 }
 function dispose(){
  if(scene&&cache.has(season)&&scene.environment===cache.get(season))scene.environment=null;
  for(const texture of cache.values())texture.dispose();
  cache.clear();scene=null;
 }
 return Object.freeze({setSeason,stats,dispose});
}
