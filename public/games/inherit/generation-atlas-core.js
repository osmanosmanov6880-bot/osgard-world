/* INHERIT Generation Atlas — pure, deterministic comparison of real local
   or account world snapshots. No storage, network, author claims or game writes. */
(function(root){
'use strict';
const TYPES=Object.freeze(['tree','stone','light','path','flower','arch','chime','moss','cairn','marker']);
const TYPE_SET=new Set(TYPES),MAX_FRAMES=160,MAX_OBJECTS=10000,MAX_MARKERS=220;
const isGen=n=>Number.isSafeInteger(n)&&n>=0&&n<=10000000;
function normalizeObject(raw){
 if(!raw||typeof raw!=='object'||Array.isArray(raw))return null;
 const type=raw.tool||raw.type,x=raw.x,y=raw.y;
 if(!TYPE_SET.has(type)||typeof x!=='number'||typeof y!=='number'||
    !Number.isFinite(x)||!Number.isFinite(y)||x<0||x>100||y<0||y>100)return null;
 return {type,x,y};
}
function normalizeObjects(objects){
 if(!Array.isArray(objects)||objects.length>MAX_OBJECTS)return null;
 const out=objects.map(normalizeObject);
 return out.every(Boolean)?out:null;
}
function key(o){return o.type+'|'+o.x.toFixed(5)+'|'+o.y.toFixed(5)}
function getFrames(world){
 if(!world||typeof world!=='object'||!isGen(world.generation))return {frames:[],skipped:0,limited:false,source:'saved-frames-only'};
 const candidates=Array.isArray(world.snapshots)?world.snapshots:[],selected=candidates.slice(-MAX_FRAMES);
 const frames=[],seen=new Set();
 let skipped=0;
 for(const record of selected){
  if(!record||!isGen(record.generation)||record.generation>world.generation||seen.has(record.generation)){skipped++;continue}
  const objects=normalizeObjects(record.objects);
  if(!objects){skipped++;continue}
  seen.add(record.generation);
  frames.push({id:'s:'+record.generation,generation:record.generation,source:'snapshot',objects});
 }
 const currentObjects=normalizeObjects(world.objects);
 if(currentObjects!==null){
  frames.push({id:'current:'+world.generation,generation:world.generation,source:'current',objects:currentObjects});
 }else skipped++;
 frames.sort((a,b)=>a.generation-b.generation||(a.source==='snapshot'?-1:1));
 return {frames,skipped,limited:candidates.length>MAX_FRAMES,source:'saved-frames-only'};
}
function difference(older,newer){
 const groups=new Map();
 for(const item of older){
  const k=key(item);
  if(!groups.has(k))groups.set(k,[]);
  groups.get(k).push(item);
 }
 const added=[],same=[],removed=[];
 for(const item of newer){
  const k=key(item),bucket=groups.get(k);
  if(bucket?.length){bucket.pop();same.push(item)}else added.push(item);
 }
 for(const bucket of groups.values())removed.push(...bucket);
 return {added,removed,same};
}
function compare(world,fromId,toId){
 const view=getFrames(world),{frames}=view;
 const from=frames.find(f=>f.id===fromId)||(frames.length>1?frames[0]:null);
 const to=frames.find(f=>f.id===toId)||(frames.length>1?frames[frames.length-1]:null);
 if(!from||!to||from.id===to.id){
  return {status:'insufficient',frames:frames.map(({id,generation,source,objects})=>({id,generation,source,total:objects.length})),
   skipped:view.skipped,limited:view.limited,source:view.source};
 }
 const {added,removed,same}=difference(from.objects,to.objects);
 const pins=[...added.slice(0,100).map(item=>({...item,kind:'added'})),
  ...removed.slice(0,100).map(item=>({...item,kind:'removed'})),
  ...same.slice(0,20).map(item=>({...item,kind:'same'}))].slice(0,MAX_MARKERS);
 const counts=objects=>Object.fromEntries(TYPES.map(type=>[type,objects.filter(item=>item.type===type).length]));
 const fromCounts=counts(from.objects),toCounts=counts(to.objects);
 return {
  status:'ok',source:view.source,skipped:view.skipped,limited:view.limited,
  from:{id:from.id,generation:from.generation,source:from.source,total:from.objects.length,counts:fromCounts},
  to:{id:to.id,generation:to.generation,source:to.source,total:to.objects.length,counts:toCounts},
  frames:frames.map(({id,generation,source,objects})=>({id,generation,source,total:objects.length})),
  totals:{added:added.length,removed:removed.length,unchanged:same.length,
   net:to.objects.length-from.objects.length,from:from.objects.length,to:to.objects.length},
  perType:TYPES.map(type=>({type,before:fromCounts[type],after:toCounts[type],delta:toCounts[type]-fromCounts[type]}))
    .filter(item=>item.before!==0||item.after!==0),
  pins,pinsTruncated:added.length+removed.length+same.length>pins.length,
  // A snapshot proves only what is in saved world data, not who or when.
  caveat:'local-or-account-saved-objects; no verified authorship or server event attribution'
 };
}
const api=Object.freeze({getFrames,compare,normalizeObject,types:TYPES,maxFrames:MAX_FRAMES,maxObjects:MAX_OBJECTS,maxMarkers:MAX_MARKERS});
root.InheritGenerationAtlas=api;
if(typeof module!=='undefined'&&module.exports)module.exports=api;
})(typeof window==='object'?window:globalThis);
