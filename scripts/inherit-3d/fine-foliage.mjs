/* INHERIT R24 FINE FOLIAGE — sculpted curved leaves, one instanced PBR batch.
 * A real 3D vein-shaped leaf silhouette for Medium/High quality.
 * Low quality intentionally adds no GPU batches, and all leaves are cosmetic.
 */
import * as THREE from 'three';
import {hash} from './terrain-core.mjs';
import {makeSurfaceMaterial} from './cinematic-surfaces.mjs';
const TAU=Math.PI*2,GOLD=2.399963229728653;
export const FOLIAGE_PROFILES=Object.freeze({
 low:Object.freeze({leavesPerTree:0,leafSegments:0}),
 medium:Object.freeze({leavesPerTree:28,leafSegments:6}),
 high:Object.freeze({leavesPerTree:68,leafSegments:6})
});
export function fineFoliageProfile(quality='high',treeCount=0){
 const key=Object.hasOwn(FOLIAGE_PROFILES,quality)?quality:'low';
 const p=FOLIAGE_PROFILES[key],trees=Math.max(0,Math.min(200,Math.floor(treeCount)||0));
 return Object.freeze({quality:key,trees,leavesPerTree:p.leavesPerTree,
  leaves:trees*p.leavesPerTree,triangles:trees*p.leavesPerTree*p.leafSegments*2,
  drawCalls:trees>0&&p.leavesPerTree>0?1:0});
}
export function leafRibbonGeometry(segments=6){
 const positions=[],uvs=[],indices=[];
 for(let i=0;i<=segments;i++){
  const t=i/segments,width=.012+.16*Math.pow(Math.max(0,Math.sin(Math.PI*t)),.85);
  const z=.08*Math.sin(Math.PI*t)+.027*Math.sin(3*Math.PI*t);
  for(const side of [-1,1]){
   positions.push(side*width,t*.72,z+side*side*.014);
   uvs.push((side+1)/2,t);
  }
  if(i<segments){
   const n=i*2;
   indices.push(n,n+1,n+2,n+1,n+3,n+2);
  }
 }
 const geo=new THREE.BufferGeometry();
 geo.setIndex(indices);
 geo.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));
 geo.setAttribute('uv',new THREE.Float32BufferAttribute(uvs,2));
 geo.computeVertexNormals();geo.computeBoundingSphere();
 return geo;
}
export function makeFineFoliage({quality='high',trees=[],registerWind=(mat)=>mat}={}){
 const profile=fineFoliageProfile(quality,trees.length);
 const root=new THREE.Group();root.name='True individual curved leaf canopy details';
 root.userData.kind='offline decorative geometry / never saved';
 if(!profile.leaves){
  return Object.freeze({root,setSeason:()=>0,stats:()=>Object.freeze({...profile,
   wetness:0,season:'tide',gameplayWrites:0,externalAssets:0}),
   dispose:()=>{}});
 }
 const geo=leafRibbonGeometry(FOLIAGE_PROFILES[profile.quality].leafSegments);
 const material=registerWind(makeSurfaceMaterial('fern',{quality:profile.quality,side:THREE.DoubleSide}),
  {amplitude:quality==='high'?.115:.06,frequency:1.16});
 material.roughness=.88;
 const mesh=new THREE.InstancedMesh(geo,material,profile.leaves);
 mesh.name='Individually articulated PBR broadleaf blades / 1 draw call';
 mesh.castShadow=false;mesh.receiveShadow=true;
 const dummy=new THREE.Object3D(),tint=new THREE.Color();
 for(let t=0;t<trees.length;t++){
  const tree=trees[t],size=tree.size;
  for(let k=0;k<profile.leavesPerTree;k++){
   const n=t*profile.leavesPerTree+k,angle=k*GOLD+tree.hue*TAU;
   const radial=Math.sqrt(hash(k+13,t+7,173)),shell=.55+.44*radial;
   const elevation=(hash(k+17,t+4,99)-.5)*.82;
   const r=size*(.68+shell*.48);
   dummy.position.set(tree.x+Math.cos(angle)*r,
    tree.y+size*(3.01+elevation),
    tree.z+Math.sin(angle)*r*.81);
   dummy.rotation.set((hash(k+8,t,21)-.5)*.8,angle+Math.PI/2,
    -.42+(hash(k,t+3,41)-.5)*.68);
   const len=size*(.46+hash(k,t+2,77)*.39);
   dummy.scale.set(len*.85,len,len*.7);
   dummy.updateMatrix();
   mesh.setMatrixAt(n,dummy.matrix);
   tint.setHSL(.245+hash(k,t,53)*.095,.17+hash(k+1,t+3,81)*.19,
    .64+hash(k+7,t+2,23)*.17);
   mesh.setColorAt(n,tint);
  }
 }
 mesh.instanceMatrix.needsUpdate=true;
 if(mesh.instanceColor)mesh.instanceColor.needsUpdate=true;
 mesh.computeBoundingSphere();root.add(mesh);
 let season='tide',wetness=0;
 function setSeason(next='tide'){
  season=['tide','sun','mist','wind'].includes(next)?next:'tide';
  wetness=season==='tide'?.71:season==='mist'?.59:season==='wind'?.23:.06;
  material.roughness=.94-wetness*.20;
  return wetness;
 }
 setSeason('tide');
 function dispose(){root.remove(mesh);geo.dispose();material.dispose();}
 return Object.freeze({root,mesh,setSeason,dispose,
  stats:()=>Object.freeze({...profile,season,wetness,roughness:material.roughness,
   gameplayWrites:0,externalAssets:0})});
}
