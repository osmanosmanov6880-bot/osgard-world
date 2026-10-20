/* INHERIT return notebook: opt-in LOCAL metadata only, no identity/history/content or analytics. */
(function(root){
'use strict';
const KEY='inherit:return-notebook:v2:local';
const MAX_DAYS=30;
function day(value){
 const v=String(value||'');
 return /^\d{4}-\d{2}-\d{2}$/.test(v)&&!Number.isNaN(Date.parse(v+'T00:00:00Z'))?v:null;
}
function clamp(v,max=1000000){return Number.isSafeInteger(v)&&v>=0?Math.min(v,max):0}
function summary(world){
 return {generation:clamp(world?.generation),objects:clamp(world?.metrics?.objects,10000),
  links:clamp(world?.metrics?.connections,10000),discoveries:clamp(world?.unlocked,12)};
}
function normalize(raw){
 if(!raw||raw.v!==2||raw.enabled!==true||!day(raw.last?.day))return null;
 const days=Array.isArray(raw.days)?[...new Set(raw.days.filter(day))].sort().slice(-MAX_DAYS):[raw.last.day];
 const last=raw.last;
 return {v:2,enabled:true,dayCount:Math.max(days.length,clamp(raw.dayCount,50000)),
   days,last:{...summary(last),day:last.day}};
}
function enter(stored,today,world){
 const now=day(today);
 if(!now)return {record:null,delta:null,isNewDay:false};
 const past=normalize(stored);
 if(!past)return {record:null,delta:null,isNewDay:false};
 if(now<=past.last.day)return {record:past,delta:null,isNewDay:false};
 const current=summary(world);
 const previous=past.last;
 // This is purely a comparison with the prior local snapshot. It does not
 // claim who changed the world, or that a remote server confirmed anything.
 const delta={generation:current.generation-previous.generation,
   objects:current.objects-previous.objects,links:current.links-previous.links,
   discoveries:current.discoveries-previous.discoveries,from:previous.day,to:now};
 const days=[...new Set([...past.days,now])].sort().slice(-MAX_DAYS);
 return {record:{v:2,enabled:true,dayCount:past.dayCount+1,days,last:{...current,day:now}},delta,isNewDay:true};
}
function enable(today,world){
 const now=day(today);
 if(!now)return null;
 return {v:2,enabled:true,dayCount:1,days:[now],last:{...summary(world),day:now}};
}
function todayLocal(){
 const date=new Date(),n=v=>String(v).padStart(2,'0');
 return date.getFullYear()+'-'+n(date.getMonth()+1)+'-'+n(date.getDate());
}
const api=Object.freeze({KEY,enter,enable,normalize,summary,todayLocal});
root.InheritReturnNotebook=api;
if(typeof module!=='undefined'&&module.exports)module.exports=api;
})(typeof window==='object'?window:globalThis);
