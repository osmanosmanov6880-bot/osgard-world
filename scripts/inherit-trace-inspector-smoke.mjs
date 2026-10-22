/* R9 verifications: only saved traces, no imagined authors/ages or game writes. */
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import '../public/games/inherit/legacy-engine.js';
import '../public/games/inherit/trace-inspector-core.js';
const inspector=globalThis.InheritTraceInspectorCore,legacy=globalThis.InheritLegacyEngine;
const f=n=>readFileSync('public/games/inherit/'+n,'utf8');
const o=(tool,x,y)=>({tool,x,y});
const world=(objects=[],pending=[],snapshots=[],generation=174)=>({
 generation,objects,pending,snapshots,budget:100,changes:[],history:[]
});
let passed=0;
function test(name,fn){fn();passed++;console.log('PASS '+name)}
test('only real selected saved objects produce detail; empty worlds cannot fabricate a trace',()=>{
 assert.equal(inspector.inspect(world(),0,legacy).status,'no-selection');
 assert.equal(inspector.inspect(world([o('tree',25,30)]),1,legacy).status,'no-selection');
 assert.equal(inspector.inspect(world([o('tree',25,30)]),-1,legacy).status,'no-selection');
 assert.equal(inspector.inspect(world([o('tree',25,30)]),'0',legacy).status,'no-selection');
 assert.equal(inspector.inspect(null,0,legacy).status,'unavailable');
});
test('an actual tree produces exact type, coordinates and saved generation',()=>{
 const result=inspector.inspect(world([o('tree',36.5,45.25)]),0,legacy);
 assert.equal(result.status,'ok');assert.equal(result.selected.type,'tree');
 assert.equal(result.selected.x,36.5);assert.equal(result.selected.y,45.25);
 assert.equal(result.selected.index,0);assert.equal(result.generation,174);
 assert.equal(result.nearTotal,0);assert.equal(result.connectionTotal,0);
 assert.equal(result.source,'saved-world-objects-only');
});
test('a valid pending tail is a real unfinished action, never a confirmed server operation',()=>{
 const active=inspector.inspect(world([o('stone',10,10),o('tree',30,30)],[{type:'tree',x:30,y:30}]),1,legacy);
 assert.equal(active.draft,true);
 const older=inspector.inspect(world([o('stone',10,10),o('tree',30,30)],[{type:'tree',x:30,y:30}]),0,legacy);
 assert.equal(older.draft,false);
 const corrupted=inspector.inspect(world([o('stone',10,10),o('tree',30,30)],[{type:'tree',x:40,y:30}]),1,legacy);
 assert.equal(corrupted.draft,null);assert.equal(corrupted.pendingKnown,false);
});
test('real nearby tree and moss follow the legacy grove rule radius',()=>{
 const w=world([o('tree',30,30),o('moss',35,32),o('light',80,80)]);
 const x=inspector.inspect(w,0,legacy);
 assert.equal(x.connectionTotal,1);assert.equal(x.connections[0].id,'grove');
 assert.equal(x.connections[0].otherType,'moss');
 assert.equal(x.nearTotal,1);assert.equal(x.possibilities.find(v=>v.id==='grove').present,true);
 assert.equal(x.mapPoints[0].kind,'selected');
 assert.equal(x.mapPoints[1].kind,'compatible');
});
test('a type pair beyond its rule radius is not represented as activated proximity',()=>{
 const x=inspector.inspect(world([o('tree',20,20),o('moss',39,20)]),0,legacy);
 assert.equal(x.nearTotal,1);assert.equal(x.connectionTotal,0);
 assert.equal(x.possibilities[0].present,false);
});
test('the same trace can match archival type and location, without proving authorship or identity',()=>{
 const w=world([o('tree',30,30)],[],[
  {generation:171,objects:[o('tree',30,30)]},
  {generation:172,objects:[o('tree',30,30)]},
  {generation:173,objects:[o('tree',70,70)]}
 ],174);
 const r=inspector.inspect(w,0,legacy);
 assert.deepEqual({first:r.evidence.firstMatch,latest:r.evidence.latestMatch,matched:r.evidence.matchedFrames},
  {first:171,latest:172,matched:2});
 assert.equal(r.evidence.identity,'type-position-and-occurrence-only');
 assert.equal(Object.hasOwn(r,'author'),false);
 assert.equal(Object.hasOwn(r,'createdAt'),false);
 assert.equal(r.caveat,'not-author-not-creation-not-server-confirmation');
});
test('duplicate objects use occurrence ordinal instead of inventing two oldest copies',()=>{
 const x=world([o('tree',30,30),o('tree',30,30)],[],[
  {generation:172,objects:[o('tree',30,30)]},
  {generation:173,objects:[o('tree',30,30),o('tree',30,30)]}
 ]);
 const a=inspector.inspect(x,0,legacy),b=inspector.inspect(x,1,legacy);
 assert.equal(a.selected.ordinal,1);assert.equal(b.selected.ordinal,2);
 assert.equal(a.evidence.firstMatch,172);
 assert.equal(b.evidence.firstMatch,173);
});
test('future, duplicate, missing and corrupt frames never count as positive evidence',()=>{
 const data=world([o('flower',31,32)],[],[
  {generation:180,objects:[o('flower',31,32)]},
  {generation:170,objects:[o('flower',31,32)]},
  {generation:170,objects:[o('flower',31,32)]},
  {generation:171,objects:[o('stone',Infinity,1)]},
  {generation:172,objects:[o('flower',31,32)]}
 ]);
 const x=inspector.inspect(data,0,legacy);
 assert.equal(x.evidence.validFrames,2);
 assert.equal(x.evidence.rejected,3);
 assert.equal(x.evidence.firstMatch,170);
 assert.equal(x.evidence.latestMatch,172);
});
test('no snapshots means unknown history, not proof a trace was just created',()=>{
 const x=inspector.inspect(world([o('tree',20,20)]),0,legacy);
 assert.equal(x.evidence.firstMatch,null);
 assert.equal(x.evidence.latestMatch,null);
 assert.equal(x.evidence.matchedFrames,0);
 assert.equal(x.evidence.validFrames,0);
});
test('bad coordinates and unknown objects are not silently drawn or given fictional links',()=>{
 for(const invalid of [o('tree',-1,30),o('tree',101,3),o('tree',Infinity,4),o('tree','30',30),o('weapon',31,32),null]){
  assert.equal(inspector.normalize(invalid),null);
  assert.equal(inspector.inspect(world([invalid]),0,legacy).status,'invalid-trace');
 }
 const mixed=inspector.inspect(world([o('tree',45,45),o('moss',NaN,47),o('moss',47,47)]),0,legacy);
 assert.equal(mixed.connectionTotal,1);
});
test('large maps limit painted markers but retain exact nearby counts',()=>{
 const objects=[o('tree',50,50),...Array.from({length:400},(_,i)=>o('moss',49+i%10/100,49+Math.floor(i/10)/100))];
 const x=inspector.inspect(world(objects),0,legacy);
 assert.equal(x.status,'ok');
 assert.equal(x.nearTotal,400);
 assert.equal(x.connectionTotal,400);
 assert.equal(x.connections.length,inspector.maxLinks);
 assert.equal(x.mapPoints.length<=inspector.maxMarkers,true);
 assert.equal(x.mapTruncated,true);
 assert.equal(x.connectionsTruncated,true);
});
test('oversize worlds and invalid generations are rejected with no partial meaning',()=>{
 const huge=world(Array.from({length:inspector.maxObjects+1},()=>o('tree',50,50)));
 assert.equal(inspector.inspect(huge,0,legacy).status,'unavailable');
 assert.equal(inspector.inspect({...world([o('tree',50,50)]),generation:-1},0,legacy).status,'unavailable');
});
test('snapshots are bounded and missing archive coverage is explicitly marked',()=>{
 const frames=Array.from({length:inspector.maxFrames+5},(_,i)=>({generation:i,objects:[o('tree',20,20)]}));
 const x=inspector.inspect(world([o('tree',20,20)],[],frames,300),0,legacy);
 assert.equal(x.evidence.validFrames,inspector.maxFrames);
 assert.equal(x.evidence.archiveLimited,true);
 assert.equal(x.evidence.firstMatch,5);
});
test('inspecting cannot modify a save, even for duplicates, pending and malformed frames',()=>{
 const input=world([o('tree',15,20),o('moss',17,20)],[],[{generation:173,objects:[o('tree',15,20)]}]);
 const before=JSON.stringify(input);
 assert.equal(inspector.inspect(input,0,legacy).status,'ok');
 assert.equal(inspector.inspect(input,1,legacy).status,'ok');
 assert.equal(JSON.stringify(input),before);
});
test('the existing game combination rules are used without new made-up prizes',()=>{
 const x=inspector.inspect(world([o('path',25,25),o('light',27,25),o('arch',28,24)]),0,legacy);
 assert.equal(x.connections.some(c=>c.id==='waylight'),true);
 assert.equal(x.connections.some(c=>c.id==='monument'),false);
 assert.equal(x.possibilities.every(p=>legacy.rules.some(rule=>rule.id===p.id)),true);
});
test('RU EN ZH, PWA, keyboard and click capture are part of the actual game release',()=>{
 const script=f('trace-inspector.js'),css=f('trace-inspector.css'),
  html=f('index.html'),worker=f('sw.js'),locale=f('interface.js');
 for(const name of ['trace-inspector-core.js','trace-inspector.js','trace-inspector.css']){
  assert.ok(html.includes('./'+name),name);
  assert.ok(worker.includes('/games/inherit/'+name),name);
 }
 assert.match(worker,/inherit-shell-v26/);
 for(const item of ['ru:','en:','zh:','showModal','aria-labelledby','event.stopPropagation()','event.preventDefault()','inherit-trace-launcher','inherit-trace-prev','inherit-trace-next','data-game-language']){
  if(item==='data-game-language'){assert.ok(locale.includes(item));continue}
  assert.ok(script.includes(item),'missing '+item);
 }
 for(const bad of ['fetch(', 'sendBeacon', 'game.apply(', 'InheritGame.apply(', 'gameStorage.setItem(', 'localStorage.setItem(', '.innerHTML='])
  assert.ok(!script.includes(bad),'unexpected write '+bad);
 assert.match(css,/prefers-reduced-motion:reduce/);
 assert.match(css,/focus-visible/);
 assert.ok(locale.includes('window.InheritTraceInspectorUI?.refresh?.()'));
 new vm.Script(f('trace-inspector-core.js'));new vm.Script(script);
});
console.log('INHERIT TRACE INSPECTOR:',passed,'passed');
