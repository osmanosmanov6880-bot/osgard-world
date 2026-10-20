/* INHERIT R7 — a read-only receipt for a real completed generation.
   No IO, storage, server identity, gameplay mutation, simulated players or timestamps. */
(function(root){
'use strict';
const TYPES=Object.freeze(['tree','stone','light','path','flower','arch','chime','moss','cairn','marker']);
const allowed=new Set(TYPES),MAX_DELTA=100,MAX_MARKERS=32;
const gen=n=>Number.isSafeInteger(n)&&n>=0&&n<10000000;
function object(raw){
 if(!raw||typeof raw!=='object'||Array.isArray(raw))return null;
 const type=raw.tool||raw.type,x=raw.x,y=raw.y;
 return allowed.has(type)&&typeof x==='number'&&typeof y==='number'
  &&Number.isFinite(x)&&Number.isFinite(y)&&x>=0&&x<=100&&y>=0&&y<=100?{type,x,y}:null;
}
function same(a,b){return a.type===b.type&&a.x===b.x&&a.y===b.y}
function create(value){
 if(!value||typeof value!=='object'||Array.isArray(value))return null;
 const mode=value.mode,outcome=value.outcome,from=value.fromGeneration,to=value.toGeneration;
 if(!['local','account'].includes(mode)||!['confirmed','local'].includes(outcome)
  ||(mode==='account'&&outcome!=='confirmed')||!gen(from)||!gen(to)||to!==from+1)return null;
 if(!Array.isArray(value.delta)||value.delta.length===0||value.delta.length>MAX_DELTA)return null;
 const items=value.delta.map(object);
 if(items.some(x=>x===null))return null;
 let afterTotal=null;
 if(mode==='local'){
  const after=value.after;
  if(!after||after.generation!==to||!Array.isArray(after.objects)||after.objects.length>10000
   ||!Array.isArray(after.pending)||after.pending.length!==0)return null;
  const suffix=after.objects.slice(-items.length).map(object);
  if(suffix.some(x=>x===null)||!suffix.every((point,i)=>same(point,items[i])))return null;
  afterTotal=after.objects.length;
 }
 const counts=TYPES.map(type=>({type,count:items.filter(item=>item.type===type).length})).filter(x=>x.count>0);
 const markers=items.slice(0,MAX_MARKERS).map(item=>({...item}));
 return Object.freeze({
  kind:'real-generation-receipt',source:'explicit-commit-only',
  verification:mode==='account'?'account-server-confirmed':outcome==='confirmed'?'shared-server-confirmed':'local-saved-server-unverified',
  from,to,traceCount:items.length,afterTotal,
  counts,markers,markersTruncated:items.length>MAX_MARKERS,
  // This receipt is about a completed generation, not custody transferred to a real person.
  caveat:'no-next-player-or-verified-author-claim'
 });
}
const api=Object.freeze({create,types:TYPES,maxDelta:MAX_DELTA,maxMarkers:MAX_MARKERS});
root.InheritHandoffMomentCore=api;
if(typeof module!=='undefined'&&module.exports)module.exports=api;
})(typeof window==='object'?window:globalThis);
