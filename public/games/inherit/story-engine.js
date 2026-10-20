/* INHERIT — Story Engine v1.
   Deterministic quests and environmental consequences derived from existing world data.
   No persistence, network requests, random rewards, or authority over server events. */
(function(root) {
'use strict';
const rules=root.InheritLegacyEngine?.rules||[
 {id:'grove',first:'tree',second:'moss',radius:16},
 {id:'waylight',first:'path',second:'light',radius:17},
 {id:'garden',first:'flower',second:'chime',radius:15},
 {id:'monument',first:'arch',second:'stone',radius:17},
 {id:'waymark',first:'marker',second:'path',radius:15},
 {id:'landmark',first:'cairn',second:'light',radius:14}
];
const TYPES=new Set(['tree','stone','light','path','flower','arch','chime','moss','cairn','marker']);
const CHAPTERS=Object.freeze([
 {id:'shore',objectives:[
  {id:'shelter',kind:'place',types:['tree','flower','moss']},
  {id:'route',kind:'place',types:['path','marker']},
  {id:'meeting',kind:'link',links:['grove','waylight','garden','monument','waymark','landmark']}
 ]},
 {id:'signal',objectives:[
  {id:'flame',kind:'place',types:['light','chime']},
  {id:'guidance',kind:'place',types:['path','marker']},
  {id:'beacon',kind:'link',links:['waylight','waymark','landmark']}
 ]},
 {id:'haven',objectives:[
  {id:'roots',kind:'place',types:['tree','moss']},
  {id:'color',kind:'place',types:['flower','chime']},
  {id:'refuge',kind:'link',links:['grove','garden']}
 ]},
 {id:'memory',objectives:[
  {id:'foundation',kind:'place',types:['stone','arch']},
  {id:'waystone',kind:'place',types:['cairn','marker']},
  {id:'monument',kind:'link',links:['monument','landmark']}
 ]}
]);
function isInt(n){return Number.isSafeInteger(n)&&n>=0}
function normalize(v){
 if(!v||typeof v!=='object')return null;
 const type=v.tool||v.type, x=v.x,y=v.y;
 return TYPES.has(type)&&typeof x==='number'&&Number.isFinite(x)&&x>=0&&x<=100&&typeof y==='number'&&Number.isFinite(y)&&y>=0&&y<=100 ? {type,x,y}:null;
}
function same(a,b){return a.type===b.type&&Math.abs(a.x-b.x)<1e-6&&Math.abs(a.y-b.y)<1e-6}
function placeable(world){
 const all=Array.isArray(world?.objects)?world.objects:[];
 const pending=Array.isArray(world?.pending)?world.pending:[];
 if(all.length>10000||pending.length>100||pending.length>all.length)return {all:all.slice(0,10000).map(normalize),fresh:[],valid:false};
 const objects=all.map(normalize);
 if(objects.some(o=>o===null))return {all:[],fresh:[],valid:false};
 const fresh=pending.map(normalize), offset=objects.length-fresh.length;
 if(fresh.some(o=>o===null)||fresh.some((o,i)=>!same(o,objects[offset+i])))return {all:objects,fresh:[],valid:false};
 return {all:objects,fresh,valid:true};
}
function recentLinks(all,fresh,allowedLinks){
 const earned=new Set();
 if(!fresh.length)return earned;
 const matchingRules=rules.filter(r=>allowedLinks.includes(r.id));
 // 20% of the island per cell, enough for every rule radius (14..17).
 const byCell=new Map(),size=20;
 const coords=(o)=>Math.floor(o.x/size)+':'+Math.floor(o.y/size);
 for(const o of all){
   const key=o.type+'|'+coords(o);
   if(!byCell.has(key))byCell.set(key,[]);
   byCell.get(key).push(o);
 }
 for(const rule of matchingRules){
   for(const freshObject of fresh){
     if(freshObject.type!==rule.first&&freshObject.type!==rule.second)continue;
     const other=freshObject.type===rule.first?rule.second:rule.first;
     const cx=Math.floor(freshObject.x/size),cy=Math.floor(freshObject.y/size);
     let found=false;
     for(let dx=-1;dx<=1&&!found;dx++)for(let dy=-1;dy<=1&&!found;dy++){
       for(const point of byCell.get(other+'|'+(cx+dx)+':'+(cy+dy))||[]){
         if((point.x-freshObject.x)**2+(point.y-freshObject.y)**2<=rule.radius**2){
           found=true;break;
         }
       }
     }
     if(found){earned.add(rule.id);break;}
   }
 }
 return earned;
}
function pickTool(goal,counts,fresh){
 if(goal.kind==='place')return goal.types.find(t=>!fresh.some(o=>o.type===t))||goal.types[0];
 for(const linkId of goal.links||[]){
   const rule=rules.find(r=>r.id===linkId);
   if(!rule)continue;
   if(counts[rule.first]>0)return rule.second;
   if(counts[rule.second]>0)return rule.first;
 }
 return rules.find(r=>r.id===goal.links?.[0])?.first||'tree';
}
function evaluate(world){
 const generation=isInt(world?.generation)?world.generation:0;
 const chapter=CHAPTERS[generation%CHAPTERS.length];
 const {all,fresh,valid}=placeable(world);
 const counts=Object.fromEntries([...TYPES].map(t=>[t,0]));
 for(const o of all)if(o)counts[o.type]++;
 const legacy=root.InheritLegacyEngine?.derive?.(world);
 const totals=legacy?.totals||{};
 const scores={
   nature:counts.tree+counts.flower+counts.moss+counts.chime+2*((totals.grove||0)+(totals.garden||0)),
   routes:counts.path+counts.marker+counts.light+2*((totals.waylight||0)+(totals.waymark||0)+(totals.landmark||0)),
   memory:counts.stone+counts.arch+counts.cairn+2*(totals.monument||0)
 };
 const mood=Object.values(scores).every(v=>v===0)?'quiet':Object.entries(scores).sort((a,b)=>b[1]-a[1])[0][0];
 const allLinks=[...new Set(chapter.objectives.flatMap(o=>o.links||[]))];
 const links=valid?recentLinks(all,fresh,allLinks):new Set();
 const objectives=chapter.objectives.map(goal=>{
   const achieved=valid&&(goal.kind==='place'?fresh.some(o=>goal.types.includes(o.type)):goal.links.some(id=>links.has(id)));
   return {id:goal.id,kind:goal.kind,done:achieved,tool:achieved?null:pickTool(goal,counts,fresh)};
 });
 const done=objectives.filter(o=>o.done).length;
 return {
   generation,chapter:chapter.id,mood,scores,objectives,done,goalCount:objectives.length,
   complete:done===objectives.length, pendingCount:fresh.length, dataConsistent:valid,
   legacyTotals:Object.fromEntries(rules.map(r=>[r.id,totals[r.id]||0])),
   limited:!!legacy?.limited
 };
}
const api=Object.freeze({evaluate,chapters:CHAPTERS,types:[...TYPES]});
root.InheritStoryEngine=api;
if(typeof module!=='undefined'&&module.exports)module.exports=api;
})(typeof window==='object'?window:globalThis);
