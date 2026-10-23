/* INHERIT R21. Original procedurally sculpted shoreline and temporal surf.
 * One offline GPU batch; deterministic topology, fixed per-quality budgets.
 * Purely visual: zero game storage/network/interaction writes.
 */
import * as THREE from 'three';
import {coastline} from './terrain-core.mjs';

const TAU=Math.PI*2;
const TIERS=Object.freeze({
 low:Object.freeze({segments:96,bands:1}),
 medium:Object.freeze({segments:160,bands:2}),
 high:Object.freeze({segments:240,bands:3})
});
export function surfProfile(quality='high'){
 const t=TIERS[quality]||TIERS.low;
 return Object.freeze({quality:TIERS[quality]?quality:'low',segments:t.segments,bands:t.bands,
  vertices:t.bands*(t.segments+1)*3,triangles:t.bands*t.segments*4,drawCalls:1});
}
export function makeSurfGeometry(quality='high'){
 const {segments,bands}=surfProfile(quality),vertices=[],uv=[],bandIds=[],indices=[];
 for(let band=0;band<bands;band++){
  const offset=vertices.length/3,inner=1.006+band*.024,width=.014+band*.003;
  for(let i=0;i<=segments;i++){
   const u=i/segments,angle=u*TAU,shore=coastline(angle);
   // Integer Fourier frequencies close exactly at the 0/360-degree seam.
   const shoreRipple=1+.0026*Math.sin(angle*13+band*1.9)+.0018*Math.sin(angle*29);
   for(let j=0;j<3;j++){
    const v=j/2,r=(inner+v*width)*shoreRipple;
    vertices.push(shore.x*r,-2.056+band*.005,shore.z*r);
    uv.push(u,v);bandIds.push(band);
   }
   if(i<segments){
    const k=offset+i*3,next=k+3;
    for(let j=0;j<2;j++)indices.push(k+j,next+j,k+j+1,k+j+1,next+j,next+j+1);
   }
  }
 }
 const geo=new THREE.BufferGeometry();
 geo.setIndex(indices);
 geo.setAttribute('position',new THREE.Float32BufferAttribute(vertices,3));
 geo.setAttribute('uv',new THREE.Float32BufferAttribute(uv,2));
 geo.setAttribute('aBand',new THREE.Float32BufferAttribute(bandIds,1));
 geo.computeVertexNormals();
 geo.computeBoundingSphere();
 return geo;
}
export const surfVertex=[
 'precision highp float;',
 'attribute float aBand;',
 'uniform float uTime;',
 'uniform float uWind;',
 'varying vec2 vSurfUv;',
 'varying float vBand;',
 'varying float vLift;',
 'void main(){',
 ' vSurfUv=uv; vBand=aBand;',
 ' float arc=uv.x*6.28318530718;',
 ' float tide=sin(arc*11.0-uTime*(.75+uWind*.28)-aBand*1.8);',
 ' float detail=sin(arc*29.0+uTime*.55+aBand);',
 ' vec3 p=position;',
 ' p.xz*=1.0+.0024*tide*uWind;',
 ' p.y+=(tide*.018+detail*.006)*(.3+.7*uWind);',
 ' vLift=.5+.5*tide;',
 ' gl_Position=projectionMatrix*modelViewMatrix*vec4(p,1.0);',
 '}'
].join('\n');
export const surfFragment=[
 'precision highp float;',
 'uniform float uTime;',
 'uniform float uWind;',
 'uniform float uStrength;',
 'uniform float uWarmth;',
 'varying vec2 vSurfUv;',
 'varying float vBand;',
 'varying float vLift;',
 'void main(){',
 ' float arc=vSurfUv.x*6.28318530718;',
 ' float lace=sin(arc*43.0+sin(arc*9.0)*1.2-uTime*(.62+.45*uWind)-vSurfUv.y*5.0);',
 ' float bubbles=sin(arc*97.0+uTime*.81+vSurfUv.y*13.0+vBand*.71);',
 ' float threads=sin(arc*181.0-uTime*1.21+vSurfUv.y*25.0);',
 ' float pattern=.47+.23*lace+.18*bubbles+.10*threads+.08*vLift;',
 ' float foam=smoothstep(.44,.78,pattern);',
 ' float feather=smoothstep(.015,.24,vSurfUv.y)*(1.0-smoothstep(.76,.995,vSurfUv.y));',
 ' float alpha=feather*(.15+.65*foam)*uStrength;',
 ' vec3 wet=vec3(.14,.38,.38);',
 ' vec3 white=vec3(.80+.07*uWarmth,.89+.04*uWarmth,.86);',
 ' vec3 color=mix(wet,white,foam*.9+.1);',
 ' gl_FragColor=vec4(color,clamp(alpha,0.0,.85));',
 '}'
].join('\n');
export function makeShorelineSurf({quality='high'}={}){
 const profile=surfProfile(quality),geometry=makeSurfGeometry(quality);
 const uniforms={uTime:{value:0},uWind:{value:.58},uStrength:{value:.95},uWarmth:{value:.4}};
 const material=new THREE.ShaderMaterial({
  uniforms,vertexShader:surfVertex,fragmentShader:surfFragment,
  transparent:true,depthWrite:false,depthTest:true,
  side:THREE.DoubleSide,polygonOffset:true,polygonOffsetFactor:-1
 });
 const mesh=new THREE.Mesh(geometry,material);
 mesh.name='Genuine tidal whitecaps / single batched 3D coastal film shader';
 mesh.castShadow=false;mesh.receiveShadow=false;mesh.renderOrder=2;
 const root=new THREE.Group();root.name='R21 original shoreline surf';
 root.userData.kind='noninteractive environment';root.add(mesh);
 let season='tide',frames=0;
 function setSeason(next='tide'){
  season=['tide','wind','sun','mist'].includes(next)?next:'tide';
  const params={
   tide:{wind:.68,strength:1.0,warmth:.52},
   wind:{wind:1.3,strength:1.16,warmth:.17},
   sun:{wind:.35,strength:.55,warmth:.95},
   mist:{wind:.21,strength:.42,warmth:.18}
  }[season];
  uniforms.uWind.value=params.wind;
  uniforms.uStrength.value=params.strength;
  uniforms.uWarmth.value=params.warmth;
  return params.strength;
 }
 function update(time=0,{reducedMotion=false}={}){
  uniforms.uTime.value=reducedMotion?0:Math.max(0,Number.isFinite(time)?time:0)*.001;
  frames++;
 }
 function dispose(){geometry.dispose();material.dispose();}
 setSeason('tide');
 return {root,mesh,setSeason,update,dispose,
  stats:()=>Object.freeze({...profile,season,frames,wind:uniforms.uWind.value,
   foamStrength:uniforms.uStrength.value,externalAssets:0,gameplayWrites:0})};
}
