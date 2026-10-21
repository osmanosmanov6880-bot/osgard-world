/* INHERIT R13 — Guided Journey Planner.
 * Plans up to two *hypothetical* placements and an explicit handoff using
 * the shipped Trace Compass + Legacy engines. No IO, persistence, edits,
 * purchased advantages, synthetic players or automatic gameplay actions.
 */
(function(root){
'use strict';
const TOOLS=Object.freeze(['tree','stone','light','path','flower','arch','chime','moss','cairn','marker']);
const ALLOWED=new Set(TOOLS),MAX_OBJECTS=450,MAX_STEPS=2,RADIUS=2.2;
const integer=n=>Number.isSafeInteger(n)&&n>=0&&n<=10000000;
const budget=n=>Number.isSafeInteger(n)&&n>=0&&n<=100;
function object(raw){
 if(!raw||typeof raw!=='object'||Array.isArray(raw))return null;
 const type=raw.tool||raw.type,x=raw.x,y=raw.y;
 return ALLOWED.has(type)&&typeof x==='number'&&typeof y==='number'&&
  Number.isFinite(x)&&Number.isFinite(y)&&x>=0&&x<=100&&y>=0&&y<=100?{tool:type,x,y}:null;
}
function same(a,b){return a.tool===b.tool&&a.x===b.x&&a.y===b.y}
function near(a,b,radius=RADIUS){return Math.hypot(a.x-b.x,a.y-b.y)<=radius}
function safe(x,y){return x>8&&x<91&&y>12&&y<77}
function normalized(world){
 if(!world||!integer(world.generation)||!budget(world.budget)||
    !Array.isArray(world.objects)||world.objects.length>MAX_OBJECTS||
    !Array.isArray(world.pending)||world.pending.length>world.objects.length||
    world.pending.length>100)return null;
 const objects=world.objects.map(object),pending=world.pending.map(object);
 if(objects.some(x=>!x)||pending.some(x=>!x))return null;
 if(!pending.every((item,i)=>same(item,objects[objects.length-pending.length+i])))return null;
 return {generation:world.generation,budget:world.budget,objects,pending};
}
function fingerprint(world){
 return JSON.stringify({g:world.generation,b:world.budget,objects:world.objects,pending:world.pending});
}
function asWorld(w){return {generation:w.generation,budget:w.budget,objects:w.objects,pending:w.pending}}
function plan(raw,compass=root.InheritTraceCompassCore,legacy=root.InheritLegacyEngine,reachable){
 const base=normalized(raw);
 if(!base||!compass||typeof compass.predict!=='function'||!legacy||typeof legacy.derive!=='function')
  return {status:'unavailable',steps:[]};
 if(base.objects.length>=MAX_OBJECTS)return {status:'limited',steps:[]};
 const original=legacy.derive(asWorld(base));
 if(!original||original.limited||!Number.isSafeInteger(original.total))return {status:'limited',steps:[]};
 const permit=(x,y)=>safe(x,y)&&(typeof reachable!=='function'||reachable(x,y)!==false);
 let sim={generation:base.generation,budget:base.budget,objects:base.objects.slice(),pending:base.pending.slice()};
 const steps=[];
 const starterFallback=[[49,44],[41,57],[56,60],[36,60],[60,55],[51,60],[58,50],[48,65],[29,55]];
 // On a blank island, a single safe tree position may lead to a second
 // suggestion behind a real interactive landmark. Check *both* coordinates
 // before offering an honest two-move grove route. The exact shipped Legacy
 // rule must confirm the hypothetical combination; no object is placed here.
 if(!sim.objects.length&&sim.budget>=2){
  const firstPredicted=compass.predict(asWorld(sim),legacy);
  const seeds=[
   ...(firstPredicted.status==='first-trace'&&Array.isArray(firstPredicted.choices)?
      firstPredicted.choices.filter(choice=>choice.tool==='tree'):[]),
   ...starterFallback.map(([x,y])=>({tool:'tree',x,y,starter:true}))
  ];
  const offsets=[[5,0],[-5,0],[0,5],[0,-5],[7,0],[-7,0],[0,7]];
  let found=false;
  for(const seed of seeds){
   if(!permit(seed.x,seed.y))continue;
   const before=legacy.derive({generation:base.generation,objects:[{tool:'tree',x:seed.x,y:seed.y}]});
   if(before?.limited||!Number.isSafeInteger(before?.total))continue;
   for(const [dx,dy] of offsets){
    const x=seed.x+dx,y=seed.y+dy;
    if(!permit(x,y))continue;
    const after=legacy.derive({generation:base.generation,
     objects:[{tool:'tree',x:seed.x,y:seed.y},{tool:'moss',x,y}]});
    if(after?.limited||!Number.isSafeInteger(after?.total)||after.total<=before.total)continue;
    steps.push({tool:'tree',x:seed.x,y:seed.y,expectedNewLinks:0,
       starter:true,source:'hypothetical-only'});
    steps.push({tool:'moss',x,y,expectedNewLinks:after.total-before.total,
       starter:false,source:'hypothetical-only'});
    found=true;break;
   }
   if(found)break;
  }
  if(found)sim={...sim,budget:sim.budget-2,
    objects:[...steps.map(step=>({tool:step.tool,x:step.x,y:step.y}))],
    pending:[...steps.map(step=>({tool:step.tool,x:step.x,y:step.y}))]};
 }

 for(let index=steps.length;index<Math.min(MAX_STEPS,base.budget);index++){
  const predicted=compass.predict(asWorld(sim),legacy),choices=Array.isArray(predicted?.choices)?predicted.choices:[];
  if(!['first-trace','opportunities'].includes(predicted?.status))break;
  let allowed=choices.filter(choice=>ALLOWED.has(choice.tool)&&Number.isFinite(choice.x)&&Number.isFinite(choice.y)&&
    permit(choice.x,choice.y)&&!steps.some(other=>Math.hypot(choice.x-other.x,choice.y-other.y)<3.5));
  if(predicted.status==='first-trace'&&sim.objects.length===0&&!allowed.length){
   allowed=starterFallback.filter(([x,y])=>permit(x,y)).map(([x,y])=>({
     tool:'tree',x,y,newLinks:0,rules:[],starter:true
   }));
  }
  if(!allowed.length)break;
  // Prefer a distinct tool for the second move when choices allow it.
  allowed.sort((a,b)=>(steps.length&&a.tool!==steps[0].tool?-1:0)-
    (steps.length&&b.tool!==steps[0].tool?-1:0));
  let selected=null,next=null;
  for(const choice of allowed){
   const nextWorld={...sim,objects:[...sim.objects,{tool:choice.tool,x:choice.x,y:choice.y}],
    pending:[...sim.pending,{tool:choice.tool,x:choice.x,y:choice.y}],budget:sim.budget-1};
   const before=legacy.derive(asWorld(sim)),after=legacy.derive(asWorld(nextWorld));
   if(!before||!after||before.limited||after.limited||!Number.isSafeInteger(after.total))continue;
   const gained=after.total-before.total;
   if(gained<=0&&!choice.starter)continue;
   selected={tool:choice.tool,x:choice.x,y:choice.y,expectedNewLinks:Math.max(0,gained),
    starter:!!choice.starter,source:'hypothetical-only'};
   next=nextWorld;break;
  }
  if(!selected)break;
  steps.push(selected);sim=next;
 }
 if(!steps.length&&!base.pending.length)return {
  status:base.budget===0?'budget-exhausted':'no-suitable-route',
  steps:[],generation:base.generation,source:'hypothetical-only'};
 const status=steps.length?'ready':'handoff-only';
 return {status,steps,generation:base.generation,budget:base.budget,
  currentObjects:base.objects.length,currentPending:base.pending.length,
  baselineLinks:original.total,fingerprint:fingerprint(base),source:'hypothetical-only',
  caveat:'suggested tools and coordinates are never real placements or a completed generation'};
}
function begin(raw,proposal){
 const base=normalized(raw);
 if(!base||!proposal||!['ready','handoff-only'].includes(proposal.status)||
   proposal.source!=='hypothetical-only'||proposal.generation!==base.generation||
   proposal.fingerprint!==fingerprint(base)||!Array.isArray(proposal.steps)||
   proposal.steps.length>MAX_STEPS)return null;
 const steps=proposal.steps.map(item=>({tool:item.tool,x:item.x,y:item.y,
  expectedNewLinks:item.expectedNewLinks}));
 if(steps.some(item=>!object(item)||!safe(item.x,item.y)||
    !Number.isSafeInteger(item.expectedNewLinks)||item.expectedNewLinks<0))return null;
 return {kind:'in-memory-journey',generation:base.generation,mode:'local',
  budget:base.budget,objects:base.objects.map(item=>({...item})),
  pending:base.pending.map(item=>({...item})),steps,source:'player-selected-plan'};
}
function progress(session,raw,legacy=root.InheritLegacyEngine){
 if(!session||session.kind!=='in-memory-journey'||session.mode!=='local'||
    !legacy||typeof legacy.derive!=='function')return {status:'unavailable'};
 const now=normalized(raw);
 if(!now)return {status:'invalidated',reason:'invalid-world'};
 if(now.generation!==session.generation)return {status:'invalidated',reason:'generation-changed'};
 const baseline=session.objects;
 if(now.objects.length<baseline.length||
    !baseline.every((item,index)=>same(item,now.objects[index])))
   return {status:'invalidated',reason:'world-replaced'};
 const added=now.objects.length-baseline.length,steps=session.steps;
 if(added>steps.length||now.budget!==session.budget-added||
    now.pending.length!==session.pending.length+added||
    !session.pending.every((item,index)=>same(item,now.pending[index])))
   return {status:'invalidated',reason:'unplanned-move'};
 for(let i=0;i<added;i++){
  const item=now.objects[baseline.length+i],expected=steps[i];
  if(!expected||item.tool!==expected.tool||!near(item,expected)||
     !same(item,now.pending[session.pending.length+i]))
   return {status:'invalidated',reason:'different-placement'};
  if(expected.expectedNewLinks>0){
   const before=legacy.derive({generation:now.generation,objects:now.objects.slice(0,baseline.length+i)});
   const after=legacy.derive({generation:now.generation,objects:now.objects.slice(0,baseline.length+i+1)});
   if(before?.limited||after?.limited||!Number.isSafeInteger(before?.total)||
      !Number.isSafeInteger(after?.total)||after.total<=before.total)
    return {status:'invalidated',reason:'no-actual-discovery'};
  }
 }
 return {status:added===steps.length?'ready-for-handoff':'awaiting-placement',
  completed:added,total:steps.length,remaining:steps.length-added,
  generation:now.generation,budget:now.budget,source:'observed-current-world-only'};
}
function finish(session,before,after,event,legacy=root.InheritLegacyEngine){
 if(progress(session,before,legacy).status!=='ready-for-handoff')return {status:'unverified'};
 const prior=normalized(before),next=normalized(after);
 if(!prior||!next||event?.mode!=='local'||
    !['confirmed','local'].includes(event.outcome)||
    event.fromGeneration!==session.generation||
    event.toGeneration!==session.generation+1||
    next.generation!==session.generation+1||next.pending.length!==0||
    next.budget!==100||next.objects.length!==prior.objects.length||
    !prior.objects.every((item,i)=>same(item,next.objects[i]))||
    !Array.isArray(event.delta)||event.delta.length!==prior.pending.length)
  return {status:'unverified'};
 const delta=event.delta.map(object);
 if(delta.some(x=>!x)||!delta.every((item,i)=>same(item,prior.pending[i])))
  return {status:'unverified'};
 return {status:event.outcome==='confirmed'?'confirmed-server-response':'local-server-unverified',
  from:session.generation,to:next.generation,
  placedAlongRoute:session.steps.length,source:'actual-handoff-bridge',
  caveat:'does-not-establish-next-player-or-server-authoritative-identity'};
}
const api=Object.freeze({plan,begin,progress,finish,object,maxObjects:MAX_OBJECTS,maxSteps:MAX_STEPS});
root.InheritGuidedJourney=api;
if(typeof module!=='undefined'&&module.exports)module.exports=api;
})(typeof window==='object'?window:globalThis);
