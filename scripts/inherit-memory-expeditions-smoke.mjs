import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import '../public/games/inherit/legacy-engine.js';
import '../public/games/inherit/generation-atlas-core.js';
import '../public/games/inherit/memory-expeditions-core.js';
const legacy=globalThis.InheritLegacyEngine,atlas=globalThis.InheritGenerationAtlas;
const expedition=globalThis.InheritMemoryExpeditions;
const read=name=>readFileSync('public/games/inherit/'+name,'utf8');
const t=(tool,x=40,y=40)=>({tool,x,y});
const world=(objects=[],archive=[],budget=99)=>({
 generation:173,budget,objects,pending:[],changes:[],
 snapshots:archive.map((objects,i)=>({generation:170+i,objects}))
});
let passed=0;
function check(title,callback){callback();console.log('PASS',title);passed++}
check('empty world has no invented historic sites or expeditions',()=>{
 const v=world([],[]);
 const r=expedition.derive(v,atlas,legacy);
 assert.equal(r.status,'no-archive');assert.deepEqual(r.goals,[]);
 assert.equal(r.source,'saved-archive-objects-only');
});
check('an archived tree absent today creates a real recoverable location, not a placed object',()=>{
 const v=world([],[ [t('tree',32,41)] ]);
 const before=JSON.stringify(v),r=expedition.derive(v,atlas,legacy);
 assert.equal(r.status,'opportunities');
 assert.equal(r.goals[0].kind,'restore');
 assert.equal(r.goals[0].tool,'tree');
 assert.equal(r.goals[0].x,32);assert.equal(r.goals[0].y,41);
 assert.equal(r.goals[0].lastSeenGeneration,170);
 assert.equal(JSON.stringify(v),before);
 assert.equal(v.objects.length,0);
});
check('a surviving archived tree creates a real compatible companion mission',()=>{
 const v=world([t('tree',34,42)],[ [t('tree',34,42)] ]);
 const p=expedition.derive(v,atlas,legacy);
 assert.equal(p.status,'opportunities');
 const goal=p.goals.find(x=>x.kind==='honor'&&x.tool==='moss'&&x.rule==='grove');
 assert.ok(goal);
 assert.ok(goal.x>8&&goal.x<91);
 const baseline=legacy.derive(v);
 const next=legacy.derive({...v,objects:[...v.objects,t(goal.tool,goal.x,goal.y)]});
 assert.ok(next.totals.grove>baseline.totals.grove);
});
check('UI geometry can reject a blocked target and choose a truthful second position',()=>{
 const v=world([t('tree',56,46)],[ [t('tree',56,46)] ]);
 const allowed=(x,y)=>x<=59;
 const p=expedition.derive(v,atlas,legacy,allowed);
 assert.equal(p.status,'opportunities');
 const goal=p.goals.find(g=>g.kind==='honor'&&g.tool==='moss');
 assert.ok(goal);assert.ok(goal.x<=59);
 const next=legacy.derive({...v,objects:[...v.objects,t(goal.tool,goal.x,goal.y)]});
 assert.ok(next.totals.grove>0);
 const restored=expedition.derive(world([],[ [t('stone',66,53)] ]),atlas,legacy,
  (x,y)=>x<60);
 assert.equal(restored.status,'no-opportunities');
});
check('do not invent a disappearance for a historical site still in current world',()=>{
 const v=world([t('tree',34,42)],[ [t('tree',34,42)] ]);
 const p=expedition.derive(v,atlas,legacy);
 assert.ok(p.goals.every(x=>x.kind!=='restore'));
});
check('real restoration is detected only when one actual trace was placed nearby',()=>{
 const before=world([],[ [t('stone',36,43)] ]),goal=expedition.derive(before,atlas,legacy).goals[0];
 const after={...before,budget:before.budget-1,
  objects:[t(goal.tool,goal.x+.2,goal.y)],pending:[t(goal.tool,goal.x+.2,goal.y)],changes:['placed']};
 const r=expedition.verify(goal,before,after,legacy);
 assert.equal(r.status,'observed-placement');
 assert.equal(r.kind,'restore');assert.equal(r.generation,before.generation);
 assert.match(r.caveat,/server confirmation/);
});
check('real companion is confirmed by actual rule increase, never by a preview',()=>{
 const before=world([t('path',30,43)],[ [t('path',30,43)] ]);
 const goal=expedition.derive(before,atlas,legacy).goals.find(g=>g.kind==='honor'&&g.tool==='light');
 assert.ok(goal);
 assert.equal(expedition.verify(goal,before,before,legacy).status,'not-proven');
 const mark=t(goal.tool,goal.x,goal.y);
 const after={...before,budget:before.budget-1,objects:[...before.objects,mark],pending:[mark]};
 assert.equal(expedition.verify(goal,before,after,legacy).status,'observed-placement');
});
check('wrong tool or remote click never completes a real expedition',()=>{
 const before=world([],[ [t('stone',37,43)] ]),goal=expedition.derive(before,atlas,legacy).goals[0];
 for(const extra of [t('tree',goal.x,goal.y),t('stone',goal.x+13,goal.y)]){
  const next={...before,budget:98,objects:[extra],pending:[extra]};
  assert.equal(expedition.verify(goal,before,next,legacy).status,'not-proven');
 }
});
check('no verification after passive world replacement, duplicate or budget inconsistency',()=>{
 const before=world([],[ [t('tree',30,43)] ]),goal=expedition.derive(before,atlas,legacy).goals[0];
 const placed=t('tree',30,43);
 for(const changes of [
   {objects:[placed],budget:99},
   {objects:[placed],budget:98,generation:174},
   {objects:[placed,placed],budget:98},
   {objects:[placed],budget:98,pending:[]}
 ]){
  const after={...before,...changes};
  assert.equal(expedition.verify(goal,before,after,legacy).status,'not-proven');
 }
});
check('existing archive at island edge does not imply unreachable placement',()=>{
 const v=world([],[ [t('tree',98,99)] ]);
 const p=expedition.derive(v,atlas,legacy);
 assert.equal(p.status,'no-opportunities');assert.equal(p.goals.length,0);
});
check('out-of-bounds and invalid objects are rejected instead of silently repaired',()=>{
 for(const raw of [t('tree',-1,43),t('stone',105,0),t('path','30',43),t('hat',30,43),
   t('tree',Infinity,40),null]){
  assert.equal(expedition.normalize(raw),null);
 }
 const state=world([t('wrong',40,41)],[ [t('tree',40,41)] ]);
 assert.equal(expedition.derive(state,atlas,legacy).status,'unavailable');
});
check('future and invalid archival snapshots cannot become mission history',()=>{
 const v={...world([],[ [t('tree',34,42)] ]),generation:168};
 assert.equal(expedition.derive(v,atlas,legacy).status,'no-archive');
 const invalid=world([],[]);
 invalid.snapshots=[{generation:172,objects:[t('not-existing',37,40)]}];
 const p=expedition.derive(invalid,atlas,legacy);
 assert.equal(p.status,'no-archive');assert.ok(p.rejectedFrames>0);
});
check('large worlds fail closed and never mutate the save',()=>{
 const v=world(Array.from({length:expedition.maxObjects+1},()=>t('tree',35,41)),
  [ [t('stone',45,47)] ]);
 const saved=JSON.stringify(v),result=expedition.derive(v,atlas,legacy);
 assert.equal(result.status,'limited');assert.deepEqual(result.goals,[]);
 assert.equal(JSON.stringify(v),saved);
});
check('all suggested target coordinates are inside real play bounds',()=>{
 const objects=[t('tree',9,13),t('flower',90,75),t('cairn',40,40),t('path',51,40),t('arch',60,41)];
 const v=world(objects,[objects]);
 const p=expedition.derive(v,atlas,legacy);
 for(const goal of p.goals){
  assert.ok(goal.x>8&&goal.x<91);assert.ok(goal.y>12&&goal.y<77);
  assert.ok(expedition.normalize(t(goal.tool,goal.x,goal.y)));
 }
 assert.ok(p.analyzed<=expedition.maxPredictions);
 assert.ok(p.goals.length<=expedition.maxGoals);
});
check('zero budget yields historical opportunities but cannot be armed',()=>{
 const v=world([t('tree',40,40)],[ [t('tree',40,40)] ],0);
 const p=expedition.derive(v,atlas,legacy);
 assert.equal(p.status,'opportunities');assert.equal(p.canPlace,false);
});
check('same-world repeated derivations are deterministic and unchanged',()=>{
 const v=world([t('tree',33,40),t('path',50,46),t('light',53,50)],
  [ [t('tree',33,40),t('stone',66,43)], [t('tree',33,40),t('stone',66,43),t('path',50,46)] ]);
 const raw=JSON.stringify(v);
 const a=expedition.derive(v,atlas,legacy),b=expedition.derive(v,atlas,legacy);
 assert.deepEqual(a,b);assert.equal(JSON.stringify(v),raw);
});
check('R12 client assets remain localized, offline and strictly no game writes',()=>{
 const html=read('index.html'),sw=read('sw.js'),ui=read('memory-expeditions.js'),css=read('memory-expeditions.css');
 for(const name of ['memory-expeditions-core.js','memory-expeditions.js','memory-expeditions.css']){
  assert.ok(html.includes('./'+name),'HTML missing '+name);
  assert.ok(sw.includes('/games/inherit/'+name),'PWA missing '+name);
 }
 assert.match(sw,/inherit-shell-v24/);
 for(const label of ['ru:','en:','zh:'])assert.ok(ui.includes(label));
 for(const forbidden of ['fetch(', 'navigator.sendBeacon(', 'localStorage.setItem(', 'InheritGame.apply(', 'innerHTML=']){
  assert.ok(!ui.includes(forbidden),'unexpected action '+forbidden);
 }
 assert.match(css,/focus-visible/);assert.match(css,/prefers-reduced-motion:reduce/);
 assert.ok(read('interface.js').includes('InheritMemoryExpeditionsUI?.refresh?.()'));
 new vm.Script(read('memory-expeditions-core.js'));new vm.Script(ui);
});
console.log('INHERIT MEMORY EXPEDITIONS:',passed,'passed');
