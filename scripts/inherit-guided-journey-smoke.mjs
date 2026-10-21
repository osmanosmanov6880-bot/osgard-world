import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import '../public/games/inherit/legacy-engine.js';
import '../public/games/inherit/trace-compass-core.js';
import '../public/games/inherit/guided-journey-core.js';
const core=globalThis.InheritGuidedJourney,legacy=globalThis.InheritLegacyEngine,compass=globalThis.InheritTraceCompassCore;
const read=name=>readFileSync('public/games/inherit/'+name,'utf8');
const tool=(t,x=49,y=44)=>({tool:t,x,y});
const world=(objects=[],pending=[],budget=100,generation=173)=>({objects,pending,budget,generation,snapshots:[],history:[],changes:[]});
const plan=(w,allow)=>core.plan(w,compass,legacy,allow);
const begin=w=>core.begin(w,plan(w));
const next=(state,s,coordinateShift=0)=>{
 const step=s.steps[state.objects.length-s.objects.length];
 assert.ok(step,'expected a further step');
 const item=tool(step.tool,step.x+coordinateShift,step.y);
 return {...state,objects:[...state.objects,item],pending:[...state.pending,{type:item.tool,x:item.x,y:item.y}],
   budget:state.budget-1,changes:[...state.changes,step.tool]};
};
let pass=0;
function check(name,fn){fn();pass++;console.log('PASS',name)}
check('empty world yields an actual two-placement path with compatible grove, never game writes',()=>{
 const w=world(),serialized=JSON.stringify(w),p=plan(w);
 assert.equal(p.status,'ready');assert.equal(p.steps.length,2);
 assert.equal(p.steps[0].tool,'tree');assert.equal(p.steps[0].starter,true);
 assert.equal(p.steps[1].tool,'moss');assert.ok(p.steps[1].expectedNewLinks>0);
 assert.equal(p.steps[0].source,'hypothetical-only');
 assert.equal(JSON.stringify(w),serialized);
 assert.equal(w.objects.length,0);assert.equal(w.budget,100);
});
check('starting a route does not create traces and native placements advance steps one at a time',()=>{
 const w=world(),s=begin(w);assert.ok(s);assert.equal(s.steps.length,2);
 assert.equal(core.progress(s,w,legacy).completed,0);
 const first=next(w,s);
 let p=core.progress(s,first,legacy);
 assert.equal(p.status,'awaiting-placement');assert.equal(p.completed,1);
 assert.equal(first.objects.length,1);assert.equal(first.budget,99);
 const second=next(first,s);
 p=core.progress(s,second,legacy);
 assert.equal(p.status,'ready-for-handoff');assert.equal(p.completed,2);
 assert.equal(legacy.derive(second).totals.grove,1);
});
check('the player may click slightly away from guide marker if true Legacy discovery still increases',()=>{
 const w=world(),s=begin(w),a=next(w,s,1.4),b=next(a,s,0.9);
 assert.equal(core.progress(s,a,legacy).completed,1);
 assert.equal(core.progress(s,b,legacy).status,'ready-for-handoff');
 assert.equal(legacy.derive(b).totals.grove,1);
});
check('a guide button never passes a generation; only validated real handoff receipt can complete',()=>{
 const w=world(),s=begin(w),a=next(w,s),before=next(a,s);
 assert.equal(core.progress(s,before,legacy).status,'ready-for-handoff');
 const after={...before,generation:before.generation+1,budget:100,pending:[],changes:[]};
 assert.equal(core.finish(s,before,after,null,legacy).status,'unverified');
 const event={mode:'local',outcome:'confirmed',fromGeneration:173,toGeneration:174,delta:before.pending};
 assert.equal(core.finish(s,before,after,event,legacy).status,'confirmed-server-response');
 const fallback=core.finish(s,before,after,{...event,outcome:'local'},legacy);
 assert.equal(fallback.status,'local-server-unverified');
 assert.equal(fallback.to,174);assert.equal(fallback.placedAlongRoute,2);
});
check('a non-committed or mismatching server result cannot claim completion',()=>{
 const w=world(),s=begin(w),before=next(next(w,s),s);
 const after={...before,generation:174,budget:100,pending:[]};
 const event={mode:'local',outcome:'confirmed',fromGeneration:173,toGeneration:174,delta:before.pending};
 assert.equal(core.finish(s,before,{...after,generation:173},event,legacy).status,'unverified');
 assert.equal(core.finish(s,before,after,{...event,delta:[]},legacy).status,'unverified');
 assert.equal(core.finish(s,before,after,{...event,mode:'account'},legacy).status,'unverified');
 assert.equal(core.finish(s,before,after,{...event,toGeneration:175},legacy).status,'unverified');
 assert.equal(core.finish(s,w,after,event,legacy).status,'unverified');
});
check('a different tool, unrelated placement, wrong budget or pending suffix cancels guidance',()=>{
 const w=world(),s=begin(w),a=next(w,s);
 assert.equal(core.progress(s,{...a,objects:[tool('stone',a.objects[0].x,a.objects[0].y)]},legacy).status,'invalidated');
 assert.equal(core.progress(s,{...a,objects:[tool('tree',15,15)]},legacy).reason,'different-placement');
 assert.equal(core.progress(s,{...a,budget:100},legacy).reason,'unplanned-move');
 assert.equal(core.progress(s,{...a,pending:[]},legacy).reason,'unplanned-move');
 assert.equal(core.progress(s,{...a,generation:174},legacy).reason,'generation-changed');
});
check('a recreated world with same object count but altered original objects invalidates the session',()=>{
 const w=world([tool('tree',40,45)],[],99),s=begin(w);
 assert.ok(s);
 const replaced={...w,objects:[tool('tree',40,46)]};
 assert.equal(core.progress(s,replaced,legacy).reason,'world-replaced');
});
check('a surviving tree can produce a short real grove-making route',()=>{
 const w=world([tool('tree',40,45)],[],99);
 const p=plan(w);assert.equal(p.status,'ready');assert.ok(p.steps.length>=1);
 assert.equal(p.steps[0].tool,'moss');
 assert.ok(p.steps[0].expectedNewLinks>=1);
 const s=core.begin(w,p),a=next(w,s);
 assert.equal(core.progress(s,a,legacy).completed,1);
});
check('a real pending generation with zero budget is handoff-only, not a paid or imagined placement',()=>{
 const objects=[tool('tree',49,44)],pending=[{type:'tree',x:49,y:44}];
 const w=world(objects,pending,0);
 const p=plan(w);assert.equal(p.status,'handoff-only');assert.equal(p.steps.length,0);
 const session=core.begin(w,p);assert.ok(session);
 assert.equal(core.progress(session,w,legacy).status,'ready-for-handoff');
 const none=plan(world(objects,[],0));
 assert.equal(none.status,'budget-exhausted');assert.equal(none.steps.length,0);
});
check('history is not an entitlement: invalid objects and records disable route without repairs',()=>{
 const broken=[
  world([tool('stone',NaN,12)]),world([tool('admin',23,44)]),
  world([],[],101),world([],[],100,-1),
  world(Array.from({length:core.maxObjects+1},()=>tool('tree',45,50))),
  world([tool('tree',49,44)],[{type:'stone',x:49,y:44}])
 ];
 for(const w of broken)assert.equal(plan(w).status,'unavailable');
 assert.equal(core.begin(world(),{status:'ready',steps:[],generation:173,source:'hypothetical-only'}),null);
});
check('no pointer-safe point means no predicted route and no fabricated history',()=>{
 const w=world(),p=plan(w,()=>false);
 assert.equal(p.status,'no-suitable-route');assert.deepEqual(p.steps,[]);
});
check('routes are finite, capped and cannot spend nonexistent generation budget',()=>{
 const w=world(),p=plan(w);
 assert.ok(p.steps.length<=core.maxSteps);
 assert.ok(p.steps.every(x=>x.x>8&&x.x<91&&x.y>12&&x.y<77));
 const limited=world([],[],1);
 assert.equal(plan(limited).steps.length,1);
});
check('stale suggestions cannot silently resume after another move or a world reset',()=>{
 const w=world(),p=plan(w);
 assert.equal(core.begin({...w,budget:99},p),null);
 assert.equal(core.begin({...w,generation:174},p),null);
 assert.equal(core.begin({...w,objects:[tool('tree',49,44)]},p),null);
});
check('all logic is read-only; UI routes use explicit buttons and existing generation bridge',()=>{
 const script=read('guided-journey.js'),engine=read('guided-journey-core.js'),
  css=read('guided-journey.css'),html=read('index.html'),sw=read('sw.js'),iface=read('interface.js');
 for(const file of ['guided-journey-core.js','guided-journey.js','guided-journey.css']){
  assert.ok(html.includes('./'+file),'HTML missing '+file);
  assert.ok(sw.includes('/games/inherit/'+file),'offline missing '+file);
 }
 assert.match(sw,/inherit-shell-v25/);
 assert.match(css,/prefers-reduced-motion:reduce/);
 assert.match(css,/focus-visible/);
 for(const label of ['ru:','en:','zh:','showModal','aria-live','progress(session','pass.focus'])assert.ok(script.includes(label),label);
 for(const item of [script,engine])
  for(const forbidden of ['fetch(', 'sendBeacon(', 'localStorage.setItem(', 'sessionStorage.setItem(', 'InheritGame.apply(', 'pass.click(', 'innerHTML='])
   assert.ok(!item.includes(forbidden),'unwanted side effect '+forbidden);
 assert.ok(html.includes('window.InheritJourneyUI?.committed?.(event)'));
 assert.ok(iface.includes('window.InheritJourneyUI?.refresh?.()'));
 new vm.Script(script);new vm.Script(engine);
});
console.log('INHERIT GUIDED JOURNEY:',pass,'passed');
