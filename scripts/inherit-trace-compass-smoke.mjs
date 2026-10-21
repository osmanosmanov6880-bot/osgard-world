import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import '../public/games/inherit/legacy-engine.js';
import '../public/games/inherit/trace-compass-core.js';
const legacy=globalThis.InheritLegacyEngine,compass=globalThis.InheritTraceCompassCore;
const read=name=>readFileSync('public/games/inherit/'+name,'utf8');
const t=(tool,x=43,y=42)=>({tool,x,y});
const world=(objects,budget=99)=>({generation:173,budget,objects,pending:[],changes:[],snapshots:[]});
let passed=0;
function test(name,fn){fn();passed++;console.log('PASS',name)}
test('game state is required and the planner creates no phantom saved objects',()=>{
 assert.equal(compass.predict(null,legacy).status,'limited');
 assert.equal(compass.predict({generation:173,objects:[],budget:99},null).status,'unavailable');
 assert.equal(compass.predict(world([]),legacy).status,'first-trace');
 const option=compass.predict(world([]),legacy).choices[0];
 assert.equal(option.tool,'tree');assert.equal(option.newLinks,0);
 assert.equal(option.starter,true);
 assert.ok(option.x>8&&option.x<91&&option.y>12&&option.y<77);
});
test('six actual Legacy engine relationships all yield at least one exact prediction',()=>{
 for(const rule of legacy.rules){
  const current=world([t(rule.first)]);
  const plan=compass.predict(current,legacy);
  assert.equal(plan.status,'opportunities',rule.id);
  const candidate=plan.choices.find(c=>c.tool===rule.second&&c.rules.some(k=>k.id===rule.id));
  assert.ok(candidate,rule.id);
  const before=legacy.derive(current).total;
  const after=legacy.derive({...current,objects:[...current.objects,t(candidate.tool,candidate.x,candidate.y)]}).total;
  assert.equal(candidate.newLinks,after-before,rule.id);
  assert.ok(candidate.newLinks>0,rule.id);
 }
});
test('relationships work regardless of whether first or second complementary object was placed',()=>{
 for(const rule of legacy.rules){
  const s=world([t(rule.second,52,40)]);
  const r=compass.predict(s,legacy);
  const option=r.choices.find(x=>x.tool===rule.first&&x.rules.some(y=>y.id===rule.id));
  assert.ok(option,rule.id);
 }
});
test('a suggested lantern links two genuine paths with an exact +2 preview',()=>{
 const s=world([t('path',32,42),t('path',36,42)]);
 const p=compass.predict(s,legacy),option=p.choices.find(x=>x.tool==='light');
 assert.ok(option);
 assert.equal(option.newLinks,2);
 assert.ok(option.rules.some(x=>x.id==='waylight'&&x.delta===2));
});
test('predicting links never changes the actual island world, including pending changes',()=>{
 const s={...world([t('tree',30,40),t('stone',65,50)],98),
  snapshots:[{generation:171,objects:[t('tree',30,40)]}],
  pending:[t('stone',65,50)],changes:['a stone'],history:[{by:'@Example',action:'a trace'}]};
 const saved=JSON.stringify(s);
 const a=compass.predict(s,legacy),b=compass.predict(s,legacy);
 assert.equal(JSON.stringify(s),saved);
 assert.deepEqual(a,b);
 assert.equal(s.budget,98);assert.equal(s.pending.length,1);
});
test('an already linked anchor is not counted as a new discovery twice',()=>{
 const s=world([t('tree',31,44),t('moss',36,44)]);
 const baseline=legacy.derive(s);
 assert.equal(baseline.totals.grove,1);
 const plan=compass.predict(s,legacy);
 assert.ok(!plan.choices.some(item=>item.tool==='moss'&&item.rules.some(k=>k.id==='grove')));
 const anotherTree=plan.choices.find(item=>item.tool==='tree');
 assert.ok(anotherTree);assert.equal(anotherTree.newLinks,1);
});
test('candidate points stay inside the real game placement bounds, even near an island edge',()=>{
 const s=world([t('moss',90,76)]);
 const p=compass.predict(s,legacy);
 assert.ok(p.choices.length>0);
 for(const candidate of p.choices){
  assert.ok(candidate.x>8&&candidate.x<91,candidate.x);
  assert.ok(candidate.y>12&&candidate.y<77,candidate.y);
  assert.equal(compass.valid(t(candidate.tool,candidate.x,candidate.y))!==null,true);
 }
});
test('out-of-range, invalid, spoofed and oversized worlds fail closed',()=>{
 for(const fake of [
  {generation:-1,objects:[],budget:100},
  {generation:173,objects:[t('tree','40',40)],budget:100},
  {generation:173,objects:[t('tree',101,40)],budget:100},
  {generation:173,objects:[t('impossible',40,40)],budget:100},
  {generation:173,objects:[],budget:1000},
  {generation:173,objects:Array.from({length:compass.maxObjects+1},()=>t('tree')),budget:100}
 ]){
  const output=compass.predict(fake,legacy);
  assert.ok(['limited','unavailable'].includes(output.status));
  assert.deepEqual(output.choices,[]);
 }
});
test('a completed move budget cannot advertise a real new move',()=>{
 const result=compass.predict(world([t('tree')],0),legacy);
 assert.equal(result.status,'budget-exhausted');
 assert.equal(result.choices.length,0);
});
test('unsupported positions do not generate fictitious synergies',()=>{
 const s=world([t('tree',0,0)]);
 const r=compass.predict(s,legacy);
 assert.equal(r.status,'no-synergy');
 assert.deepEqual(r.choices,[]);
});
test('dense islands inspect all six genuine recipes before spending the preview budget',()=>{
 const all=compass.types.flatMap((type,i)=>Array.from({length:3},(_,n)=>
  t(type,22+i*5+n*0.2,30+n*7)));
 const plan=compass.predict(world(all),legacy);
 assert.equal(plan.inspectedRules.length,legacy.rules.length);
 assert.deepEqual(new Set(plan.inspectedRules),new Set(legacy.rules.map(rule=>rule.id)));
 assert.ok(plan.evaluated<=compass.maxEvaluations);
});
test('bounded prediction work and finite suggestions on a busy 600-trace island',()=>{
 const objects=Array.from({length:compass.maxObjects},(_,i)=>t('tree',30+(i%8),42+Math.floor(i/8)/8));
 const r=compass.predict(world(objects),legacy);
 assert.ok(r.evaluated<=compass.maxEvaluations);
 assert.ok(r.choices.length<=compass.maxChoices);
 assert.equal(r.objects,compass.maxObjects);
});
test('only the shipped six Legacy rules can appear as predicted links',()=>{
 const s=world([t('tree'),t('stone'),t('light'),t('path')]);
 const choices=compass.predict(s,legacy).choices,known=new Set(legacy.rules.map(r=>r.id));
 for(const item of choices){
  assert.ok(compass.types.includes(item.tool));
  for(const rule of item.rules)assert.ok(known.has(rule.id));
 }
});
test('all required assets, offline shell and localization hooks are shipped',()=>{
 const html=read('index.html'),sw=read('sw.js'),lang=read('interface.js');
 for(const p of ['trace-compass-core.js','trace-compass.js','trace-compass.css']){
  assert.ok(html.includes('./'+p),'HTML: '+p);
  assert.ok(sw.includes('/games/inherit/'+p),'PWA: '+p);
 }
 assert.match(sw,/inherit-shell-v24/);
 assert.ok(lang.includes('window.InheritTraceCompassUI?.refresh?.()'));
 const ui=read('trace-compass.js'),css=read('trace-compass.css');
 for(const word of ['ru:','en:','zh:','showModal','aria-pressed','ghost.hidden','copy[lang()]'])
  assert.ok(ui.includes(word),word);
 for(const banned of ['fetch(', 'sendBeacon(', 'localStorage.setItem(', 'sessionStorage.setItem(', 'InheritGame.apply(', 'innerHTML=']){
  assert.ok(!ui.includes(banned),'unexpected side effect: '+banned);
 }
 assert.match(css,/pointer-events:none/);
 assert.match(css,/inherit-compass-armed .inherit-first-steps/);
 assert.ok(ui.includes("d.body.classList.add('inherit-compass-armed')"));
 assert.ok(ui.includes("d.body.classList.remove('inherit-compass-armed')"));
 assert.match(css,/prefers-reduced-motion:reduce/);
 const inspector=read('trace-inspector.js');
 assert.ok(inspector.includes('inherit-trace-compass-plan'));
 assert.ok(inspector.includes('window.InheritTraceCompassUI?.open?.()'));

 assert.match(css,/inherit-compass-armed #island\{bottom:-35px\}/);
 assert.match(css,/focus-visible/);
 new vm.Script(ui);new vm.Script(read('trace-compass-core.js'));
});
console.log('INHERIT TRACE COMPASS:',passed,'passed');
