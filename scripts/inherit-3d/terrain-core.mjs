// INHERIT R16 — deterministic 3D terrain and game-coordinate adapters.
// This module contains no DOM, WebGL, storage, network access, or game writes.
export const ISLAND_SEED=173;
export const PROPS=new Set(['tree','stone','light','path','flower','arch','chime','moss','cairn','marker']);
export function clamp(n,lo,hi){return Math.min(hi,Math.max(lo,Number.isFinite(n)?n:lo));}
export function hash(x,z,seed=ISLAND_SEED){
  let n=Math.imul(Math.floor(x*271.17),374761393)^Math.imul(Math.floor(z*173.91),668265263)^Math.imul(seed,2246822519);
  n=Math.imul(n^(n>>>13),1274126177);n^=n>>>16;
  return (n>>>0)/4294967295;
}
export function smooth(t){t=clamp(t,0,1);return t*t*(3-2*t);}
export function noise(x,z,seed=ISLAND_SEED){
  const ix=Math.floor(x),iz=Math.floor(z),u=smooth(x-ix),v=smooth(z-iz);
  const a=hash(ix,iz,seed),b=hash(ix+1,iz,seed),c=hash(ix,iz+1,seed),d=hash(ix+1,iz+1,seed);
  return (a+(b-a)*u)*(1-v)+(c+(d-c)*u)*v;
}
export function coastline(theta){
  const n=2.9;const c=Math.cos(theta),s=Math.sin(theta);
  const x=Math.sign(c)*Math.pow(Math.abs(c),2/n);
  const z=Math.sign(s)*Math.pow(Math.abs(s),2/n);
  const wave=1+0.037*Math.sin(theta*7+0.5)+0.024*Math.sin(theta*13-0.7);
  return {x:x*24*wave,z:z*21*wave};
}
export function fieldHeight(x,z){
  // A gentle, playable plateau with worn eroded cliffs at the boundary.
  const radius=Math.pow(Math.pow(Math.abs(x)/24,3)+Math.pow(Math.abs(z)/21,3),1/3);
  const hills=(noise(x*0.17,z*0.17,31)-.5)*1.2+
    (noise(x*.43,z*.43,79)-.5)*.27+
    .13*Math.sin(x*.51+z*.27);
  return .48+Math.max(0,1-radius*radius)*1.22+hills;
}
export function screenToTerrain(percentX,percentY,aspect=1.84,orthoHeight=29,elevation=0.68){
  // Native INHERIT saves percentage coordinates based on the island DOM rect.
  // Keep every saved trace screen-aligned under the cinematic ortho camera.
  const x=(clamp(percentX,0,100)/100-.5)*orthoHeight*aspect;
  const target=(.5-clamp(percentY,0,100)/100)*orthoHeight;
  const s=Math.sin(elevation),c=Math.cos(elevation);
  let z=-target/Math.max(.2,s);
  for(let k=0;k<3;k++)z=(c*fieldHeight(x,z)-target)/Math.max(.2,s);
  return {x,y:fieldHeight(x,z),z};
}
export function nativeValidPoint(x,y){
  return Number.isFinite(x)&&Number.isFinite(y)&&x>=8&&x<=91&&y>=12&&y<=77;
}
export function stableObjects(world,maxObjects=420){
  if(!world||!Array.isArray(world.objects))return [];
  return world.objects.filter(o=>o&&PROPS.has(o.tool)&&nativeValidPoint(o.x,o.y)).slice(0,maxObjects)
    .map(o=>({tool:o.tool,x:o.x,y:o.y}));
}
export function vegetation(seed=ISLAND_SEED,count=80){
  let randomSeed=seed>>>0;
  const random=()=>{randomSeed=(Math.imul(randomSeed,1664525)+1013904223)>>>0;return randomSeed/4294967296;};
  const points=[];
  for(let i=0;i<count*7&&points.length<count;i++){
    const x=(random()-.5)*45,z=(random()-.5)*40;
    const extent=Math.pow(Math.pow(Math.abs(x)/24,3)+Math.pow(Math.abs(z)/21,3),1/3);
    if(extent>.89||extent<.15)continue;
    // Keep a navigable, visually readable path through the island center.
    const roadZ=.22*x+2*Math.sin(x*.19);
    if(Math.abs(z-roadZ)<2.3)continue;
    points.push({x,z,y:fieldHeight(x,z),size:.6+random()*.92,hue:random(),type:random()<.68?'tree':'bush'});
  }
  return points;
}
export function worldStateSignature(world){
  const valid=stableObjects(world);
  // Stable with imports, handoffs and replay. No private account fields in key.
  return String(Number.isSafeInteger(world?.generation)?world.generation:0)+'|'+
    valid.map(o=>[o.tool,Math.round(o.x*1000),Math.round(o.y*1000)].join(':')).join(';');
}
