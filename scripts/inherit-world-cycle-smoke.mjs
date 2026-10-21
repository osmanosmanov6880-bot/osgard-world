import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
const read=n=>readFileSync('public/games/inherit/'+n,'utf8');
const index=read('index.html'),sw=read('sw.js'),ui=read('world-cycle-ui.js'),css=read('world-cycle.css');
const scripts=['legacy-engine.js','world-cycle-engine.js','return-notebook.js'];
const ctx={};ctx.window=ctx;vm.createContext(ctx);
for(const f of scripts)vm.runInContext(read(f),ctx,{filename:f});
const engine=ctx.InheritWorldCycle,book=ctx.InheritReturnNotebook;
const trace=(tool,x,y)=>({tool,x,y});
const world=(generation,objects=[],pending=[],snapshots=[])=>({generation,objects,pending,snapshots,history:[],changes:[]});
let passed=0;function test(name,fn){fn();passed++;console.log('PASS',name)}
test('assets are parseable, loaded and available in offline cache v13',()=>{
 for(const name of ['world-cycle.css','world-cycle-engine.js','world-cycle-ui.js','return-notebook.js']){
  assert.ok(index.includes('./'+name),'HTML missing '+name);
  assert.ok(sw.includes('/games/inherit/'+name),'offline cache missing '+name);
 }
 new vm.Script(ui);new vm.Script(read('cosmetic-rewards.js'));assert.match(css,/prefers-reduced-motion:reduce/);
 for(const name of ['cosmetic-rewards.js','cosmetic-rewards.css']){assert.ok(index.includes('./'+name));assert.ok(sw.includes('/games/inherit/'+name));}assert.match(sw,/inherit-shell-v25/);
});
test('16 generation incidents, all with 2 real object choices and stable deterministic order',()=>{
 assert.equal(engine.events.length,16);assert.equal(new Set(engine.events.map(e=>e.id)).size,16);
 const ids=Array.from({length:32},(_,g)=>engine.evaluate(world(g)).event.id);
 assert.deepEqual(ids.slice(0,16),ids.slice(16,32));
 assert.ok(engine.events.every(e=>e.types.length===2&&e.types.every(t=>engine.types.includes(t))));
});
test('fresh, validated pending objects can resolve incident with distinct consequences',()=>{
 const light=trace('light',30,30),marker=trace('marker',34,33);
 const before=world(1,[light],[light]);
 const alternate=world(1,[marker],[marker]);
 const first=engine.evaluate(before),second=engine.evaluate(alternate);
 assert.equal(first.event.id,'tidal-flare');
 assert.equal(first.event.resolved,true);assert.equal(first.event.choice,'light');assert.equal(first.event.impact,'glow');
 assert.equal(second.event.choice,'marker');assert.equal(second.event.impact,'route');
 assert.equal(JSON.stringify(before),JSON.stringify(world(1,[light],[light])));
});
test('unsubmitted old connection does not count as a current incident',()=>{
 const old=trace('light',30,30),newStone=trace('stone',40,44);
 const result=engine.evaluate(world(1,[old,newStone],[newStone]));
 assert.equal(result.event.resolved,false);assert.equal(result.event.choice,null);
});
test('passing a generation resets incident without erasing world growth',()=>{
 const a=trace('light',30,30);
 const current=engine.evaluate(world(1,[a],[a]));
 const handedOff=engine.evaluate(world(2,[a],[]));
 assert.equal(current.event.resolved,true);assert.equal(handedOff.event.resolved,false);
 assert.equal(handedOff.metrics.objects,1);
});
test('mismatched, offmap and malformed pending never grant an incident',()=>{
 const a=trace('light',40,30);
 const cases=[
  world(1,[a],[trace('light',41,30)]),
  world(1,[a],[{tool:'light',x:-10,y:20}]),
  world(1,[a],Array.from({length:101},()=>a)),
  world(1,[a],Array.from({length:2},()=>a)),
  world(1,[a,{tool:'INVALID',x:40,y:33}],[a])
 ];
 for(const item of cases){
  const state=engine.evaluate(item);assert.equal(state.event.resolved,false);assert.equal(state.pendingValid,false);
 }
});
test('all four fictional seasons rotate with generation, independent of real weather',()=>{
 const seasons=[0,1,2,3,4].map(g=>engine.evaluate(world(g)).season);
 assert.deepEqual(seasons,['tide','sun','wind','mist','tide']);
});
test('three world growth stages and ancient stage based only on snapshot provenance',()=>{
 const bare=engine.evaluate(world(10));
 assert.equal(bare.stage,'untouched');
 const growing=engine.evaluate(world(10,[trace('tree',10,10),trace('stone',70,70),trace('light',90,90)]));
 assert.equal(growing.stage,'growing');
 const objects=[trace('tree',12,12),trace('moss',14,14),trace('path',30,30),trace('light',32,32),trace('stone',50,50),trace('arch',52,52),trace('flower',60,60),trace('chime',61,61)];
 const settled=engine.evaluate(world(10,objects));assert.equal(settled.stage,'settlement');
 const ancient=engine.evaluate(world(17,objects,[],[{generation:8,objects}]));
 assert.equal(ancient.stage,'ancient');assert.ok(ancient.metrics.ancient>=4);
});
test('12 milestones derive from real persisted objects and combinations',()=>{
 assert.equal(engine.milestones.length,12);
 assert.equal(engine.evaluate(world(1)).unlocked,0);
 const objects=[trace('tree',15,15),trace('moss',16,16),trace('path',32,32),trace('light',33,33)];
 const summary=engine.evaluate(world(1,objects));
 assert.ok(summary.unlocked>=3);assert.ok(summary.milestones.find(m=>m.id==='connected').unlocked);
 assert.equal(summary.milestones.find(m=>m.id==='collector').unlocked,false);
});
test('same world yields same result with no save mutations',()=>{
 const state=world(173,[trace('light',20,20),trace('path',22,22)],[trace('path',22,22)]);
 const serialized=JSON.stringify(state);
 const a=engine.evaluate(state),b=engine.evaluate(state);
 assert.equal(JSON.stringify(a),JSON.stringify(b));assert.equal(JSON.stringify(state),serialized);
});
test('return notebook does nothing without opt-in',()=>{
 assert.equal(book.enter(null,'2026-10-20',engine.evaluate(world(173))).record,null);
 assert.equal(book.normalize({v:1,enabled:true,last:{day:'2026-10-19'}}),null);
});
test('return notebook keeps only local numeric world summary and up to 30 dates',()=>{
 const original=engine.evaluate(world(173,[trace('light',20,20)]));
 const start=book.enable('2026-10-19',original);
 assert.equal(start.dayCount,1);assert.equal(start.last.objects,1);
 assert.ok(!JSON.stringify(start).includes('author'));assert.ok(!JSON.stringify(start).includes('email'));
 const same=book.enter(start,'2026-10-19',original);
 assert.equal(same.isNewDay,false);assert.equal(same.record.dayCount,1);
 const changed=engine.evaluate(world(174,[trace('light',20,20),trace('path',21,21)]));
 const next=book.enter(start,'2026-10-20',changed);
 assert.equal(next.isNewDay,true);assert.equal(next.record.dayCount,2);
 assert.equal(next.delta.generation,1);assert.equal(next.delta.objects,1);
 const normalized=book.normalize(next.record);
 assert.equal(normalized.last.objects,2);assert.equal(normalized.last.links,1);
 let later=next.record;
 for(let i=0;i<38;i++){const date=new Date(Date.UTC(2026,9,21+i)).toISOString().slice(0,10);later=book.enter(later,date,changed).record;}
 assert.equal(later.days.length,30);assert.equal(later.dayCount,40);
});
test('return log rejects future or malformed record and never grants game budget',()=>{
 const broken={v:2,enabled:true,dayCount:1,last:{day:'bad',generation:1,objects:1,links:0},days:['bad']};
 assert.equal(book.normalize(broken),null);
 assert.equal(book.enter(book.enable('2026-10-20',engine.evaluate(world(1))),'2026-10-19',engine.evaluate(world(2))).isNewDay,false);
 assert.ok(!/budget|score|purchase|checkout|payment/i.test(read('return-notebook.js')));
});
test('UI respects account rights, consent, accessibility and safe text-only rendering',()=>{
 for(const required of ['window.InheritAccount?.state','window.InheritUI?.getLanguage','addEventListener','MutationObserver','aria-label','dataset.inheritSeason','b.disabled=!allowed()','consent.addEventListener','erase.addEventListener','notebook.KEY'])
   assert.ok(ui.includes(required),required);
 for(const banned of ['fetch(', 'innerHTML=', 'InheritGame.apply(', 'navigator.sendBeacon','localStorage.setItem('])assert.ok(!ui.includes(banned),banned);
});
test('earned cosmetics require real milestones and never alter gameplay budgets',()=>{
 const s=read('cosmetic-rewards.js');
 for(const need of ['gardener','connected','architect','window.InheritWorldUI','aria-pressed','disabled=!available'])assert.ok(s.includes(need),need);
 for(const forbidden of ['InheritGame.apply(', 'fetch(', 'purchase', 'checkout'])assert.ok(!s.includes(forbidden),forbidden);
});
console.log('INHERIT WORLD CYCLE:',passed,'passed');
