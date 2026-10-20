/* INHERIT Legacy Engine v1. Pure, deterministic interpretation of existing traces.
   It never mutates worlds, server data, player budgets or saved archives. */
(function(root){
'use strict';
const VALID=new Set(['tree','stone','light','path','flower','arch','chime','moss','cairn','marker']);
const RULES=Object.freeze([
  {id:'grove',first:'tree',second:'moss',radius:16},
  {id:'waylight',first:'path',second:'light',radius:17},
  {id:'garden',first:'flower',second:'chime',radius:15},
  {id:'monument',first:'arch',second:'stone',radius:17},
  {id:'waymark',first:'marker',second:'path',radius:15},
  {id:'landmark',first:'cairn',second:'light',radius:14}
]);
function objectType(value){return value&&typeof value==='object'&&(value.tool||value.type)}
function normalized(value){
 const type=objectType(value),x=Number(value&&value.x),y=Number(value&&value.y);
 return VALID.has(type)&&Number.isFinite(x)&&Number.isFinite(y)&&x>=0&&x<=100&&y>=0&&y<=100?{type,x,y}:null;
}
function key(value){return value.type+'|'+value.x.toFixed(4)+'|'+value.y.toFixed(4)}
function validGeneration(value){return Number.isSafeInteger(value)&&value>=0}
function derive(world){
 const generation=validGeneration(world?.generation)?world.generation:0;
 const objects=(Array.isArray(world?.objects)?world.objects:[]).slice(0,10000).map(normalized).filter(Boolean);
 const counts=Object.create(null);for(const t of VALID)counts[t]=0;
 const historyFrames=Array.isArray(world?.snapshots)?world.snapshots.filter(f=>validGeneration(f?.generation)&&f.generation<=generation&&Array.isArray(f.objects)).sort((a,b)=>a.generation-b.generation).slice(0,512):[];
 const knownSince=new Map();let inspected=0,truncatedSnapshots=false;
 for(const frame of historyFrames){
   for(const raw of frame.objects.slice(0,10000)){
     if(++inspected>250000){truncatedSnapshots=true;break}
     const o=normalized(raw);if(o&&!knownSince.has(key(o)))knownSince.set(key(o),frame.generation);
   }
   if(truncatedSnapshots)break;
 }
 const enriched=objects.map((o,i)=>{
   counts[o.type]++;
   const since=knownSince.get(key(o));
   return {...o,index:i,since:since===undefined?null:since,age:since===undefined?null:Math.max(0,generation-since)};
 });
 const effects=[],totals=Object.create(null);let truncatedCells=false;
 for(const rule of RULES){
   const primary=enriched.filter(o=>o.type===rule.first);
   const nearby=enriched.filter(o=>o.type===rule.second);
   totals[rule.id]=0;
   if(!primary.length||!nearby.length)continue;
   const cell=rule.radius;
   const index=new Map();
   for(const o of nearby){
     const bucket=Math.floor(o.x/cell)+':'+Math.floor(o.y/cell);
     if(!index.has(bucket))index.set(bucket,[]);
     const values=index.get(bucket);
     if(values.length<64)values.push(o);else truncatedCells=true;
   }
   for(const a of primary){
     let best=null,bestDistance=rule.radius*rule.radius;
     const cx=Math.floor(a.x/cell),cy=Math.floor(a.y/cell);
     for(let dx=-1;dx<=1;dx++)for(let dy=-1;dy<=1;dy++){
       for(const b of index.get((cx+dx)+':'+(cy+dy))||[]){
         if(a.index===b.index)continue;
         const distance=(a.x-b.x)**2+(a.y-b.y)**2;
         if(distance<=bestDistance&&(best===null||distance<bestDistance||b.index<best.index)){
           best=b;bestDistance=distance;
         }
       }
     }
     if(!best)continue;
     totals[rule.id]++;
     if(effects.length<48){
       const since=a.since===null||best.since===null?null:Math.max(a.since,best.since);
       const age=since===null?null:Math.max(0,generation-since);
       effects.push({id:rule.id,x:Number(((a.x+best.x)/2).toFixed(2)),y:Number(((a.y+best.y)/2).toFixed(2)),since,age,stage:age===null?'unknown':age>=4?'heritage':age>=1?'growing':'new',from:[a.index,best.index]});
     }
   }
 }
 const available=RULES.filter(rule=>counts[rule.first]>0&&counts[rule.second]===0).map(rule=>({id:rule.id,near:rule.first,place:rule.second}));
 const mature=enriched.filter(o=>o.age!==null&&o.age>=3).sort((a,b)=>b.age-a.age||a.index-b.index);
 const groups=new Map();
 for(const o of mature){
   const groupKey=o.type+'|'+o.since;
   if(!groups.has(groupKey))groups.set(groupKey,{type:o.type,age:o.age,since:o.since,count:0});
   groups.get(groupKey).count++;
 }
 const memory=[...groups.values()].slice(0,6);
 const memoryCount=mature.length;
 const total=Object.values(totals).reduce((sum,n)=>sum+n,0);
 return {generation,objects:objects.length,counts:Object.fromEntries(Object.entries(counts)),total,totals:Object.fromEntries(Object.entries(totals)),effects,memory,memoryCount,available,hasSnapshots:historyFrames.length>0,
   limited:Boolean(world?.objects?.length>10000||world?.snapshots?.length>512||truncatedCells||truncatedSnapshots)};
}
root.InheritLegacyEngine=Object.freeze({derive, rules:RULES,types:[...VALID]});
if(typeof module!=='undefined'&&module.exports)module.exports=root.InheritLegacyEngine;
})(typeof window==='object'?window:globalThis);
