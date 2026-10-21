/* INHERIT R9 — read-only examination of a genuinely saved trace.
   Never creates histories, player identities, world events, permissions or writes. */
(function(root){
'use strict';
const TYPES=Object.freeze(['tree','stone','light','path','flower','arch','chime','moss','cairn','marker']);
const ALLOWED=new Set(TYPES);
const MAX_OBJECTS=10000,MAX_FRAMES=160,MAX_NEIGHBORS=8,MAX_LINKS=6,MAX_MARKERS=20;
const MAX_DISTANCE=24;
const validGen=n=>Number.isSafeInteger(n)&&n>=0&&n<=10000000;
function normalize(raw){
 if(!raw||typeof raw!=='object'||Array.isArray(raw))return null;
 const type=raw.tool||raw.type,x=raw.x,y=raw.y;
 if(!ALLOWED.has(type)||typeof x!=='number'||typeof y!=='number'||
    !Number.isFinite(x)||!Number.isFinite(y)||x<0||x>100||y<0||y>100)return null;
 return {type,x,y};
}
function key(o){return o.type+'|'+o.x.toFixed(5)+'|'+o.y.toFixed(5)}
function inspect(world,index,legacy=root.InheritLegacyEngine){
 if(!world||typeof world!=='object'||!validGen(world.generation)||
    !Array.isArray(world.objects)||world.objects.length>MAX_OBJECTS)return {status:'unavailable'};
 if(!Number.isSafeInteger(index)||index<0||index>=world.objects.length)return {status:'no-selection'};
 const selected=normalize(world.objects[index]);
 if(!selected)return {status:'invalid-trace'};
 let ordinal=0;
 for(let i=0;i<=index;i++){
  const item=normalize(world.objects[i]);
  if(item&&key(item)===key(selected))ordinal++;
 }
 const pending=Array.isArray(world.pending)?world.pending:[];
 let pendingValid=pending.length<=world.objects.length;
 if(pendingValid){
  for(let i=0;i<pending.length;i++){
   const expected=normalize(world.objects[world.objects.length-pending.length+i]);
   const actual=normalize(pending[i]);
   if(!expected||!actual||key(expected)!==key(actual)){pendingValid=false;break}
  }
 }
 const draft=pendingValid?index>=world.objects.length-pending.length&&pending.length>0:null;
 let all=[];
 for(let i=0;i<world.objects.length;i++){
  if(i===index)continue;
  const item=normalize(world.objects[i]);if(!item)continue;
  const distance=Math.hypot(selected.x-item.x,selected.y-item.y);
  if(distance<=MAX_DISTANCE)all.push({...item,index:i,distance});
 }
 all.sort((a,b)=>a.distance-b.distance||a.index-b.index);
 const nearby=all.slice(0,MAX_NEIGHBORS).map(o=>({...o,distance:Number(o.distance.toFixed(2))}));
 const rawRules=Array.isArray(legacy?.rules)?legacy.rules:[];
 const rules=rawRules.filter(r=>r&&typeof r.id==='string'&&
  ALLOWED.has(r.first)&&ALLOWED.has(r.second)&&
  typeof r.radius==='number'&&Number.isFinite(r.radius)&&r.radius>0&&r.radius<=MAX_DISTANCE);
 const connections=[];
 for(const item of all){
  for(const rule of rules){
   if(((selected.type===rule.first&&item.type===rule.second)||
        (selected.type===rule.second&&item.type===rule.first))&&item.distance<=rule.radius){
    connections.push({id:rule.id,otherIndex:item.index,otherType:item.type,
      x:item.x,y:item.y,distance:Number(item.distance.toFixed(2)),radius:rule.radius});
   }
  }
 }
 const compatible=connections.slice(0,MAX_LINKS);
 const possibilities=rules.filter(r=>r.first===selected.type||r.second===selected.type)
  .map(rule=>({id:rule.id,type:rule.first===selected.type?rule.second:rule.first,
    radius:rule.radius,present:connections.some(c=>c.id===rule.id)}));
 const frames=Array.isArray(world.snapshots)?world.snapshots:[],observed=[],seen=new Set();
 const chosen=frames.slice(-MAX_FRAMES),archiveLimited=frames.length>MAX_FRAMES;
 let rejected=0;
 for(const frame of chosen){
  if(!frame||!validGen(frame.generation)||frame.generation>world.generation||
    !Array.isArray(frame.objects)||frame.objects.length>MAX_OBJECTS||seen.has(frame.generation)){
   rejected++;continue;
  }
  // Any invalid item makes that snapshot unfit as evidence of absence.
  const normalized=frame.objects.map(normalize);
  if(normalized.some(item=>!item)){rejected++;continue}
  seen.add(frame.generation);
  const copies=normalized.filter(item=>key(item)===key(selected)).length;
  observed.push({generation:frame.generation,copies,matched:copies>=ordinal});
 }
 observed.sort((a,b)=>a.generation-b.generation);
 const seenAt=observed.filter(f=>f.matched).map(f=>f.generation);
 const evidence={firstMatch:seenAt.length?seenAt[0]:null,
  latestMatch:seenAt.length?seenAt[seenAt.length-1]:null,
  matchedFrames:seenAt.length,validFrames:observed.length,
  archiveLimited,rejected,
  // Positional matching cannot prove the same individual object survived.
  identity:'type-position-and-occurrence-only'};
 const mapPoints=[{kind:'selected',x:selected.x,y:selected.y,type:selected.type}];
 const included=new Set();
 for(const record of compatible){
  if(included.has(record.otherIndex))continue;
  included.add(record.otherIndex);
  mapPoints.push({kind:'compatible',x:record.x,y:record.y,type:record.otherType});
 }
 for(const item of all){
  if(mapPoints.length>=MAX_MARKERS)break;
  if(included.has(item.index))continue;
  mapPoints.push({kind:'nearby',x:item.x,y:item.y,type:item.type});
  included.add(item.index);
 }
 return {
  status:'ok',source:'saved-world-objects-only',
  selected:{...selected,index,ordinal},generation:world.generation,
  currentTotal:world.objects.length,draft,pendingKnown:pendingValid,
  nearTotal:all.length,nearby,
  connectionTotal:connections.length,connections:compatible,
  connectionsTruncated:connections.length>compatible.length,
  possibilities,evidence,mapPoints,mapTruncated:all.length+1>mapPoints.length,
  caveat:'not-author-not-creation-not-server-confirmation'
 };
}
const api=Object.freeze({inspect,normalize,types:TYPES,maxObjects:MAX_OBJECTS,maxFrames:MAX_FRAMES,
 maxNeighbors:MAX_NEIGHBORS,maxLinks:MAX_LINKS,maxMarkers:MAX_MARKERS});
root.InheritTraceInspectorCore=api;
if(typeof module!=='undefined'&&module.exports)module.exports=api;
})(typeof window==='object'?window:globalThis);
