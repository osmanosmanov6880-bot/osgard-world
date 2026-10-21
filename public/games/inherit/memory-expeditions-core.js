/* INHERIT R12 — Memory Expeditions.
 * Factual opportunities derived ONLY from saved archive frames and the current
 * world. A suggested restoration or companion is never a real placed trace.
 * No IO, storage, fabricated owners, timestamps, rewards or save mutations. */
(function(root){
'use strict';
const MAX_WORLD_OBJECTS=450,MAX_FRAMES=24,MAX_GOALS=8,MAX_PREDICTIONS=96;
const OFFSETS=Object.freeze([[5,0],[-5,0],[0,5],[0,-5],[7,0],[-7,0]]);
const TYPES=Object.freeze(['tree','stone','light','path','flower','arch','chime','moss','cairn','marker']);
const ALLOWED=new Set(TYPES);
const validGen=n=>Number.isSafeInteger(n)&&n>=0&&n<=10000000;
const validBudget=n=>Number.isSafeInteger(n)&&n>=0&&n<=100;
const round=n=>Number(n.toFixed(3));
function normalize(raw){
 if(!raw||typeof raw!=='object'||Array.isArray(raw))return null;
 const tool=raw.tool||raw.type,x=raw.x,y=raw.y;
 return ALLOWED.has(tool)&&typeof x==='number'&&typeof y==='number'&&
  Number.isFinite(x)&&Number.isFinite(y)&&x>=0&&x<=100&&y>=0&&y<=100?
  {tool,x,y}:null;
}
function inside(x,y){return x>8&&x<91&&y>12&&y<77}
function distance(a,b){return Math.hypot(a.x-b.x,a.y-b.y)}
function exact(a,b){return a.tool===b.tool&&a.x===b.x&&a.y===b.y}
function lastMatching(objects,anchor,radius=.35){
 return objects.some(obj=>obj.tool===anchor.tool&&distance(obj,anchor)<=radius);
}
function identifier(kind,anchor,generation,tool,rule){
 return kind+':'+generation+':'+anchor.tool+':'+anchor.x.toFixed(4)+':'+anchor.y.toFixed(4)+':'+tool+':'+(rule||'');
}
function derive(world,atlas=root.InheritGenerationAtlas,legacy=root.InheritLegacyEngine,allowPoint){
 // The optional caller-supplied hit-test is read-only and lets the UI reject
 // coordinates hidden behind decorative, clickable landmarks and game buttons.
 const reachable=(x,y)=>inside(x,y)&&
  (typeof allowPoint!=='function'||allowPoint(x,y)!==false);
 if(!world||!validGen(world.generation)||!validBudget(world.budget)||
  !Array.isArray(world.objects)||typeof atlas?.getFrames!=='function'||
  !Array.isArray(legacy?.rules)||typeof legacy?.derive!=='function')
  return {status:'unavailable',goals:[],inspected:0};
 if(world.objects.length>MAX_WORLD_OBJECTS)return {
  status:'limited',goals:[],maxObjects:MAX_WORLD_OBJECTS,inspected:0};
 const current=world.objects.map(normalize);
 if(current.some(o=>!o))return {status:'unavailable',goals:[],inspected:0};
 const frames=atlas.getFrames(world);
 const archives=frames.frames.filter(frame=>frame.source==='snapshot'&&frame.generation<=world.generation)
  .sort((a,b)=>b.generation-a.generation).slice(0,MAX_FRAMES);
 const metadata={generation:world.generation,budget:world.budget,
  archiveFrames:archives.length,archiveLimited:frames.limited||frames.frames.filter(f=>f.source==='snapshot').length>MAX_FRAMES,
  rejectedFrames:frames.skipped,inspected:0,analyzed:0,source:'saved-archive-objects-only',
  caveat:'No trace identity, author, disappearance event, server validation or reward is inferred.'};
 if(!archives.length)return {...metadata,status:'no-archive',goals:[]};
 const missing=[],memorial=[],seen=new Set();
 const baseline=legacy.derive({generation:world.generation,objects:current});
 if(baseline.limited)return {...metadata,status:'limited',goals:[]};
 let capReached=false;
 for(const frame of archives){
  if(frame.objects.length>MAX_WORLD_OBJECTS){capReached=true;continue}
  for(const raw of frame.objects){
   if(++metadata.inspected>MAX_FRAMES*MAX_WORLD_OBJECTS){capReached=true;break}
   const anchor=normalize(raw);if(!anchor)continue;
   const id=anchor.tool+'|'+anchor.x.toFixed(4)+'|'+anchor.y.toFixed(4);
   if(seen.has(id))continue;
   seen.add(id);
   const present=lastMatching(current,anchor);
   if(!present&&missing.length<MAX_GOALS){
    // Never propose a site where the existing game's island cannot receive
    // a pointer placement. We cannot force a trace outside playable bounds.
    if(reachable(anchor.x,anchor.y)){
     missing.push({id:identifier('restore',anchor,frame.generation,anchor.tool),
      kind:'restore',tool:anchor.tool,x:round(anchor.x),y:round(anchor.y),
      anchor:{tool:anchor.tool,x:anchor.x,y:anchor.y},
      lastSeenGeneration:frame.generation,rule:null,
      evidence:'type-and-position-were-saved-in-an-older-frame'});
    }
   }
   if(present&&memorial.length<MAX_GOALS){
    const rules=legacy.rules.filter(rule=>rule.first===anchor.tool||rule.second===anchor.tool);
    let found=null;
    for(const rule of rules){
     const companion=rule.first===anchor.tool?rule.second:rule.first;
     if(!ALLOWED.has(companion))continue;
     for(const [dx,dy] of OFFSETS){
      if(metadata.analyzed>=MAX_PREDICTIONS){capReached=true;break}
      const x=round(anchor.x+dx),y=round(anchor.y+dy);
      if(!reachable(x,y)||current.some(o=>distance(o,{x,y})<2))continue;
      metadata.analyzed++;
      const after=legacy.derive({generation:world.generation,objects:[...current,{tool:companion,x,y}]});
      if(after.limited||(after.totals[rule.id]||0)<=(baseline.totals[rule.id]||0))continue;
      found={id:identifier('honor',anchor,frame.generation,companion,rule.id),
       kind:'honor',tool:companion,x,y,anchor:{tool:anchor.tool,x:anchor.x,y:anchor.y},
       lastSeenGeneration:frame.generation,rule:rule.id,
       evidence:'historic-trace-present-and-an-actual-rule-can-be-extended'};
      break;
     }
     if(found||capReached)break;
    }
    if(found)memorial.push(found);
   }
   if(missing.length>=MAX_GOALS&&memorial.length>=MAX_GOALS)break;
  }
  if(capReached||missing.length>=MAX_GOALS&&memorial.length>=MAX_GOALS)break;
 }
 const goals=[...missing.slice(0,4),...memorial.slice(0,4)].slice(0,MAX_GOALS);
 // For an island with no losses, offer historical companion expeditions;
 // no fake vanished landmarks are fabricated just to populate the screen.
 if(!goals.length&&memorial.length)goals.push(...memorial.slice(0,MAX_GOALS));
 if(!goals.length&&missing.length)goals.push(...missing.slice(0,MAX_GOALS));
 return {...metadata,status:goals.length?'opportunities':'no-opportunities',
  goals,foundLost:missing.length,foundCompanions:memorial.length,
  inspectionLimited:capReached,canPlace:world.budget>0};
}
function verify(goal,before,after,legacy=root.InheritLegacyEngine){
 if(!goal||!['restore','honor'].includes(goal.kind)||
  !ALLOWED.has(goal.tool)||!inside(goal.x,goal.y)||
  !before||!after||!validGen(before.generation)||
  before.generation!==after.generation||!validBudget(before.budget)||
  before.budget===0||after.budget!==before.budget-1||
  !Array.isArray(before.objects)||!Array.isArray(after.objects)||
  after.objects.length!==before.objects.length+1||
  before.objects.length>MAX_WORLD_OBJECTS||!legacy?.derive)
  return {status:'not-proven'};
 const a=before.objects.map(normalize),b=after.objects.map(normalize);
 if(a.some(x=>!x)||b.some(x=>!x)||!a.every((o,i)=>exact(o,b[i])))
  return {status:'not-proven'};
 if(Array.isArray(before.pending)&&Array.isArray(after.pending)&&
  after.pending.length!==before.pending.length+1)return {status:'not-proven'};
 const added=b.at(-1);
 if(added.tool!==goal.tool||distance(added,goal)>2.2)return {status:'not-proven'};
 if(goal.kind==='restore'){
  if(!goal.anchor||!normalize(goal.anchor)||lastMatching(a,goal.anchor))return {status:'not-proven'};
  if(distance(added,goal.anchor)>2.2)return {status:'not-proven'};
 }else{
  if(!legacy.rules.some(r=>r.id===goal.rule))return {status:'not-proven'};
  const first=legacy.derive({generation:before.generation,objects:a});
  const second=legacy.derive({generation:after.generation,objects:b});
  if(first.limited||second.limited||(second.totals[goal.rule]||0)<=(first.totals[goal.rule]||0))
   return {status:'not-proven'};
 }
 return {status:'observed-placement',tool:added.tool,x:added.x,y:added.y,
  generation:after.generation,kind:goal.kind,
  caveat:'world-object-added; generation handoff, account server confirmation and authorship are not proven'};
}
const api=Object.freeze({derive,verify,normalize,types:TYPES,maxObjects:MAX_WORLD_OBJECTS,
 maxFrames:MAX_FRAMES,maxGoals:MAX_GOALS,maxPredictions:MAX_PREDICTIONS});
root.InheritMemoryExpeditions=api;
if(typeof module!=='undefined'&&module.exports)module.exports=api;
})(typeof window==='object'?window:globalThis);
