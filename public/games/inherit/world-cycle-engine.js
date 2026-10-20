/* INHERIT WORLD CYCLE v2 — deterministic, read-only world progression.
   Existing generation saves are the single source of game state. No fetch, storage,
   score mutation, currency, speculative players or client-authored server history. */
(function (root) {
'use strict';
const ALL = new Set(['tree','stone','light','path','flower','arch','chime','moss','cairn','marker']);
const EVENT_DEFINITIONS = Object.freeze([
  {id:'afterstorm',types:['tree','stone'],zone:'nature',impact:{tree:'sprout',stone:'shelter'}},
  {id:'tidal-flare',types:['light','marker'],zone:'routes',impact:{light:'glow',marker:'route'}},
  {id:'first-nesting',types:['tree','flower'],zone:'nature',impact:{tree:'birds',flower:'pollinators'}},
  {id:'voices-under-stone',types:['arch','stone'],zone:'memory',impact:{arch:'echo',stone:'memorial'}},
  {id:'waterline',types:['moss','path'],zone:'nature',impact:{moss:'reeds',path:'crossing'}},
  {id:'cloudless-watch',types:['light','chime'],zone:'routes',impact:{light:'glow',chime:'breeze'}},
  {id:'garden-in-wind',types:['flower','moss'],zone:'nature',impact:{flower:'pollinators',moss:'sprout'}},
  {id:'forgotten-inscription',types:['stone','marker'],zone:'memory',impact:{stone:'memorial',marker:'route'}},
  {id:'quiet-crossing',types:['path','tree'],zone:'routes',impact:{path:'crossing',tree:'shelter'}},
  {id:'distant-shimmer',types:['light','cairn'],zone:'routes',impact:{light:'glow',cairn:'memorial'}},
  {id:'return-of-colors',types:['flower','chime'],zone:'nature',impact:{flower:'pollinators',chime:'breeze'}},
  {id:'old-foundations',types:['arch','cairn'],zone:'memory',impact:{arch:'echo',cairn:'memorial'}},
  {id:'high-meadow',types:['tree','moss'],zone:'nature',impact:{tree:'birds',moss:'reeds'}},
  {id:'signal-in-fog',types:['light','path'],zone:'routes',impact:{light:'glow',path:'route'}},
  {id:'last-wildflowers',types:['flower','tree'],zone:'nature',impact:{flower:'pollinators',tree:'birds'}},
  {id:'names-on-the-shore',types:['marker','stone'],zone:'memory',impact:{marker:'route',stone:'memorial'}}
]);
const MILESTONES = Object.freeze([
 {id:'first',threshold:1,metric:'objects'},
 {id:'diversity',threshold:3,metric:'diversity'},
 {id:'connected',threshold:1,metric:'connections'},
 {id:'gardener',threshold:3,metric:'living'},
 {id:'pathfinder',threshold:3,metric:'routes'},
 {id:'architect',threshold:3,metric:'built'},
 {id:'sanctuary',threshold:3,metric:'connections'},
 {id:'ten',threshold:10,metric:'objects'},
 {id:'collector',threshold:10,metric:'diversity'},
 {id:'enduring',threshold:1,metric:'ancient'},
 {id:'fifty',threshold:50,metric:'objects'},
 {id:'woven',threshold:6,metric:'connections'}
]);
function validObject(raw){
 if(!raw||typeof raw!=='object'||!ALL.has(raw.tool||raw.type))return null;
 const x=raw.x,y=raw.y;
 if(typeof x!=='number'||typeof y!=='number'||!Number.isFinite(x)||!Number.isFinite(y)||x<0||x>100||y<0||y>100)return null;
 return {type:raw.tool||raw.type,x,y};
}
function key(o){return o.type+':'+o.x.toFixed(5)+':'+o.y.toFixed(5)}
function validGeneration(n){return Number.isSafeInteger(n)&&n>=0}
function resolvePending(world,objects) {
 const raw=world&&world.pending;
 if(!Array.isArray(raw)||raw.length>100||raw.length>objects.length)return {valid:false,objects:[]};
 const pending=raw.map(validObject);
 if(pending.some(x=>x===null))return {valid:false,objects:[]};
 const begin=objects.length-pending.length;
 for(let i=0;i<pending.length;i++){
   const match=objects[begin+i];
   if(!match||key(match)!==key(pending[i]))return {valid:false,objects:[]};
 }
 return {valid:true,objects:pending};
}
function minimum(a,b){return a<b?a:b}
function evaluate(world){
 const generation=validGeneration(world?.generation)?world.generation:0;
 const raw=Array.isArray(world?.objects)?world.objects:[];
 const inputLimited=raw.length>10000;
 const objects=raw.slice(0,10000).map(validObject);
 const validObjects=objects.every(Boolean);
 const facts=objects.filter(Boolean);
 const pending=resolvePending(world,facts);
 if(inputLimited||!validObjects)pending.valid=false;
 const counts=Object.fromEntries([...ALL].map(t=>[t,0]));
 for(const o of facts)counts[o.type]++;
 const links=root.InheritLegacyEngine?.derive?.(world);
 const connections=links?.total||0;
 const types=Object.values(counts).filter(n=>n>0).length;
 const living=counts.tree+counts.flower+counts.moss+counts.chime;
 const routes=counts.light+counts.path+counts.marker;
 const built=counts.stone+counts.arch+counts.cairn;
 const ageKnown=links?.memoryCount||0;
 const metrics={objects:facts.length,diversity:types,connections,living,routes,built,ancient:ageKnown};
 const benchmarks=MILESTONES.map(m=>{
   const progress=minimum(m.threshold,metrics[m.metric]);
   return {id:m.id,metric:m.metric,threshold:m.threshold,progress,unlocked:progress>=m.threshold};
 });
 const unlocked=benchmarks.filter(m=>m.unlocked).length;
 const domain={nature:living+2*((links?.totals?.grove||0)+(links?.totals?.garden||0)),
   routes:routes+2*((links?.totals?.waylight||0)+(links?.totals?.waymark||0)+(links?.totals?.landmark||0)),
   memory:built+2*(links?.totals?.monument||0)};
 const stage=links?.memoryCount>=4&&connections>=3?'ancient':connections>=3&&facts.length>=8?'settlement':facts.length>=3?'growing':'untouched';
 const tone=Object.values(domain).every(v=>v===0)?'quiet':Object.entries(domain).sort((a,b)=>b[1]-a[1])[0][0];
 const season=['tide','sun','wind','mist'][generation%4]; // fictional cycle; not real weather
 const event=EVENT_DEFINITIONS[generation%EVENT_DEFINITIONS.length];
 // Only the *current* pending suffix can resolve a current-generation incident.
 const chosen=pending.valid ? pending.objects.find(o=>event.types.includes(o.type)) : null;
 const incident={
   id:event.id,zone:event.zone,types:[...event.types],
   resolved:!!chosen,choice:chosen?.type||null,
   impact:chosen?event.impact[chosen.type]:null,
   // This visual outcome is an interpretation, not a server-authored event.
   evidence:chosen?'current-generation-trace':'not-yet-placed'
 };
 const earliest=Array.isArray(world?.snapshots)?
   world.snapshots.filter(s=>validGeneration(s?.generation)&&s.generation<=generation&&Array.isArray(s?.objects)).map(s=>s.generation).sort((a,b)=>a-b)[0]:undefined;
 const history={earliestGeneration:earliest===undefined?null:earliest,
   span:earliest===undefined?null:Math.max(0,generation-earliest),
   witnessed:ageKnown};
 const summary={generation,season,stage,tone,counts,metrics,domain,history,event:incident,milestones:benchmarks,unlocked,totalMilestones:MILESTONES.length,
   pendingValid:pending.valid,limited:!!(inputLimited||!validObjects||links?.limited),
   // A player must never infer another visitor from this field.
   source:'saved-objects-only'};
 return summary;
}
const api=Object.freeze({evaluate,events:EVENT_DEFINITIONS,milestones:MILESTONES,types:[...ALL]});
root.InheritWorldCycle=api;
if(typeof module!=='undefined'&&module.exports)module.exports=api;
})(typeof window==='object'?window:globalThis);
