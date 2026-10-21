/* INHERIT R9: a read-only placement planner derived from actual saved island
   objects and the shipped Legacy rule engine. Hypothetical positions are NOT
   game actions, confirmed discoveries, purchases, or another player's work. */
(function(root){
'use strict';
const TOOLS=Object.freeze(['tree','stone','light','path','flower','arch','chime','moss','cairn','marker']);
const TYPES=new Set(TOOLS);
const OFFSETS=Object.freeze([[5,0],[-5,0],[0,5],[0,-5]]);
const MAX_OBJECTS=600,MAX_ANCHORS=3,MAX_EVALUATIONS=72,MAX_CHOICES=5;
const integer=x=>Number.isSafeInteger(x)&&x>=0&&x<=10000000;
const round=x=>Number(x.toFixed(3));
function valid(raw){
 if(!raw||typeof raw!=='object'||Array.isArray(raw))return null;
 const type=raw.tool||raw.type,x=raw.x,y=raw.y;
 return TYPES.has(type)&&typeof x==='number'&&typeof y==='number'&&
  Number.isFinite(x)&&Number.isFinite(y)&&x>=0&&x<=100&&y>=0&&y<=100?
  {tool:type,x,y}:null;
}
function inside(x,y){return x>8&&x<91&&y>12&&y<77}
function predict(world,legacy){
 if(!legacy||typeof legacy.derive!=='function'||!Array.isArray(legacy.rules))
  return {status:'unavailable',choices:[],evaluated:0};
 if(!world||!integer(world.generation)||!Array.isArray(world.objects)||
  world.objects.length>MAX_OBJECTS)return {status:'limited',choices:[],evaluated:0};
 if(!Number.isSafeInteger(world.budget)||world.budget<0||world.budget>100)
  return {status:'unavailable',choices:[],evaluated:0};
 const normalized=world.objects.map(valid);
 if(normalized.some(o=>!o))return {status:'unavailable',choices:[],evaluated:0};
 const state={generation:world.generation,objects:normalized};
 const existing=legacy.derive(state);
 if(existing.limited)return {status:'limited',choices:[],evaluated:0};
 if(world.budget===0)return {status:'budget-exhausted',choices:[],evaluated:0,baseline:existing.total};
 if(normalized.length===0){
  return {status:'first-trace',choices:[{tool:'tree',x:49,y:44,newLinks:0,rules:[],starter:true}],
   baseline:0,objects:0,evaluated:0,source:'hypothetical-only'};
 }
 // Visit each known recipe in turn before checking second and third anchors:
 // crowded islands must not starve the later recipes of their preview budget.
 const anchorsByType=Object.fromEntries(TOOLS.map(type=>[
  type,normalized.filter(item=>item.tool===type).slice(0,MAX_ANCHORS)]));
 const attempts=[];
 const inspectedRules=new Set();
 for(let anchorIndex=0;anchorIndex<MAX_ANCHORS;anchorIndex++){
  for(const rule of legacy.rules){
   if(!TYPES.has(rule.first)||!TYPES.has(rule.second)||!Number.isFinite(rule.radius))continue;
   for(const [tool,anchorType] of [[rule.first,rule.second],[rule.second,rule.first]]){
    const anchor=anchorsByType[anchorType][anchorIndex];
    if(!anchor)continue;
    for(const [dx,dy] of OFFSETS)
     attempts.push({tool,x:round(anchor.x+dx),y:round(anchor.y+dy),ruleId:rule.id});
   }
  }
 }
 const seen=new Set(),possibilities=[];
 let evaluated=0,cutShort=false;
 for(const attempt of attempts){
  const {tool,x,y,ruleId}=attempt;
  if(!inside(x,y))continue;
  const key=tool+'|'+x.toFixed(3)+'|'+y.toFixed(3);
  if(seen.has(key))continue;
  seen.add(key);
  if(evaluated>=MAX_EVALUATIONS){cutShort=true;break}
  evaluated++;inspectedRules.add(ruleId);
  // Predictions use precisely the same rule engine as the Legacy journal.
  const after=legacy.derive({generation:state.generation,
   objects:[...normalized,{tool,x,y}]});
  if(after.limited)continue;
  const newLinks=after.total-existing.total;
  if(newLinks<=0)continue;
  const links=legacy.rules.map(r=>({id:r.id,
   delta:(after.totals[r.id]||0)-(existing.totals[r.id]||0)}))
   .filter(item=>item.delta>0);
  possibilities.push({tool,x,y,newLinks,rules:links,starter:false});
 }
 possibilities.sort((a,b)=>b.newLinks-a.newLinks||
  TOOLS.indexOf(a.tool)-TOOLS.indexOf(b.tool)||a.x-b.x||a.y-b.y);
 // The top choice of each available trace type is more useful to the player
 // than five almost-identical positions for one tool.
 const choices=[],chosenTypes=new Set();
 for(const item of possibilities){
  if(chosenTypes.has(item.tool))continue;
  chosenTypes.add(item.tool);choices.push(item);
  if(choices.length>=MAX_CHOICES)break;
 }
 return {status:choices.length?'opportunities':'no-synergy',choices,
  baseline:existing.total,objects:normalized.length,evaluated,cutShort,inspectedRules:[...inspectedRules],
  source:'hypothetical-only'};
}
const api=Object.freeze({predict,valid,types:TOOLS,maxObjects:MAX_OBJECTS,
 maxEvaluations:MAX_EVALUATIONS,maxChoices:MAX_CHOICES});
root.InheritTraceCompassCore=api;
if(typeof module!=='undefined'&&module.exports)module.exports=api;
})(typeof window==='object'?window:globalThis);
