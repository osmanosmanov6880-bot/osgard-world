/* INHERIT R11 — verified local rule-compatible network tests. */
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import '../public/games/inherit/legacy-engine.js';
import '../public/games/inherit/legacy-network-core.js';
const legacy=globalThis.InheritLegacyEngine,net=globalThis.InheritLegacyNetwork;
const file=name=>readFileSync('public/games/inherit/'+name,'utf8');
const obj=(tool,x=40,y=42)=>({tool,x,y});
const world=(objects,budget=100)=>({generation:173,budget,objects,pending:[],changes:[],snapshots:[]});
let passed=0;
function test(name,fn){fn();passed++;console.log('PASS '+name)}
test('an empty island has zero graph nodes, no fabricated journeys',()=>{
 const r=net.analyze(world([]),legacy);
 assert.equal(r.status,'empty');assert.equal(r.links,0);
 assert.equal(r.components.length,0);assert.equal(r.largest,0);
 assert.equal(net.route(r,0,1).status,'invalid-selection');
 assert.equal(net.suggestBridge(r,0,1).status,'invalid-selection');
 assert.equal(r.source,'geometric-rule-compatible-pairs-only');
});
test('two complementary real traces make one compatible pair and a shortest path',()=>{
 const r=net.analyze(world([obj('tree',35,40),obj('moss',42,40)]),legacy);
 assert.equal(r.status,'ok');assert.equal(r.links,1);assert.equal(r.components.length,1);
 assert.deepEqual(r.edges,[{a:0,b:1,rule:'grove'}]);
 assert.deepEqual(net.route(r,0,1).path,[0,1]);
 assert.equal(net.route(r,0,1).hops,1);
 assert.equal(net.suggestBridge(r,0,1).status,'already-connected');
});
test('all six shipped recipes connect exactly their real geometry',()=>{
 for(const rule of legacy.rules){
  const near=net.analyze(world([obj(rule.first,40,40),obj(rule.second,40+rule.radius-1,40)]),legacy);
  assert.equal(near.links,1,rule.id);assert.equal(near.edges[0].rule,rule.id);
  const far=net.analyze(world([obj(rule.first,20,40),obj(rule.second,20+rule.radius+1,40)]),legacy);
  assert.equal(far.links,0,rule.id);
 }
});
test('connected paths use deterministic shortest chains, not speculative story events',()=>{
 const w=world([obj('path',30,40),obj('light',40,40),obj('cairn',50,40),obj('stone',80,40)]);
 const g=net.analyze(w,legacy),r=net.route(g,0,2);
 assert.equal(g.components.length,2);assert.equal(g.isolated,1);
 assert.deepEqual(r.path,[0,1,2]);assert.equal(r.hops,2);
 assert.deepEqual(r.edges.map(x=>x.rule),['waylight','landmark']);
 assert.equal(r.source,'geometric-rule-compatible-pairs-only');
 assert.equal(net.route(g,0,0).status,'same');
 assert.equal(net.route(g,0,3).status,'disconnected');
 assert.equal(g.caveat.includes('not saved discoveries'),true);
});
test('each duplicate placed object remains an independent actual graph node',()=>{
 const g=net.analyze(world([obj('path',35,40),obj('path',35,40),obj('light',43,40)]),legacy);
 assert.equal(g.nodes.length,3);assert.equal(g.links,2);
 assert.equal(g.components[0].size,3);
 assert.deepEqual(net.route(g,0,1).path,[0,2,1]);
});
test('one hypothetical lantern can bridge a real path component to a cairn component',()=>{
 const s=world([obj('path',30,40),obj('cairn',49,40)],98);
 const frozen=JSON.stringify(s),g=net.analyze(s,legacy);
 assert.equal(g.components.length,2);
 const bridge=net.suggestBridge(g,0,1);
 assert.equal(bridge.status,'suggested');assert.equal(bridge.tool,'light');
 assert.ok(bridge.x>8&&bridge.x<91&&bridge.y>12&&bridge.y<77);
 assert.deepEqual([...new Set(bridge.via)].sort(),['landmark','waylight']);
 assert.equal(JSON.stringify(s),frozen);
 assert.equal(s.budget,98);
 const actual=net.analyze({...s,objects:[...s.objects,obj(bridge.tool,bridge.x,bridge.y)]},legacy);
 assert.equal(net.route(actual,0,1).status,'connected');
 assert.equal(net.route(actual,0,1).hops,2);
 const before=legacy.derive(s),after=legacy.derive({...s,objects:[...s.objects,obj(bridge.tool,bridge.x,bridge.y)]});
 assert.equal(after.total-before.total,2,'preview must also create two real legacy links');
});
test('one-move bridge cannot be invented where neither complementary type exists',()=>{
 const g=net.analyze(world([obj('tree',25,40),obj('flower',33,40)]),legacy);
 assert.equal(net.route(g,0,1).status,'disconnected');
 const r=net.suggestBridge(g,0,1);
 assert.equal(r.status,'not-found');
});
test('far-away groups and edge-clipped proposals report no bridge',()=>{
 const g=net.analyze(world([obj('path',9,15),obj('cairn',90,76)]),legacy);
 assert.equal(net.suggestBridge(g,0,1).status,'not-found');
});
test('budget exhaustion blocks all bridge suggestions but does not block exploration',()=>{
 const g=net.analyze(world([obj('path',35,41),obj('cairn',51,41)],0),legacy);
 assert.equal(g.status,'ok');assert.equal(g.components.length,2);
 assert.equal(net.suggestBridge(g,0,1).status,'budget-exhausted');
});
test('invalid coordinates, unknown type and malformed rules are never coerced into real events',()=>{
 assert.equal(net.analyze(world([obj('tree',NaN,42)]),legacy).status,'unavailable');
 assert.equal(net.analyze(world([{tool:'moss',x:'40',y:42}]),legacy).status,'unavailable');
 assert.equal(net.analyze(world([obj('gun',43,42)]),legacy).status,'unavailable');
 assert.equal(net.analyze({...world([]),generation:-1},legacy).status,'unavailable');
 assert.equal(net.analyze(world([]),{rules:[{id:'grove',first:'tree',second:'moss',radius:Infinity}]}).status,'unavailable');
 assert.equal(net.analyze(world([]),null).status,'unavailable');
 assert.equal(net.route(net.analyze(world([obj('tree')]),legacy),0,99).status,'invalid-selection');
});
test('large worlds and complete dense graphs fail closed instead of presenting partial conclusions',()=>{
 assert.equal(net.analyze(world(Array.from({length:net.maxObjects+1},()=>obj('path'))),legacy).status,'limited');
 const paths=Array.from({length:115},()=>obj('path',40,40));
 const lights=Array.from({length:115},()=>obj('light',40,40));
 const dense=net.analyze(world([...paths,...lights]),legacy);
 assert.equal(dense.status,'limited');assert.equal(dense.maxEdges,net.maxEdges);
});
test('bridge model is deterministic and never modifies archived or pending world data',()=>{
 const s={...world([obj('path',31,42),obj('cairn',48,42)]),pending:[obj('cairn',48,42)],
  snapshots:[{generation:170,objects:[obj('path',31,42)]}],history:[{by:'unknown'}]};
 const before=JSON.stringify(s);
 const a=net.analyze(s,legacy),b=net.analyze(s,legacy);
 assert.deepEqual(a,b);
 assert.deepEqual(net.suggestBridge(a,0,1),net.suggestBridge(b,0,1));
 assert.equal(JSON.stringify(s),before);
});
test('UI has localized, accessible read-only graph and separate manual placement action',()=>{
 const html=file('index.html'),sw=file('sw.js'),ui=file('legacy-network.js'),css=file('legacy-network.css');
 for(const asset of ['legacy-network-core.js','legacy-network.js','legacy-network.css']){
  assert.ok(html.includes('./'+asset),asset);
  assert.ok(sw.includes('/games/inherit/'+asset),asset);
 }
 assert.match(sw,/inherit-shell-v26/);
 for(const needed of ['ru:','en:','zh:','showModal','aria-labelledby','createElementNS','pointer-events:none','requestAnimationFrame']){
  assert.ok((ui+css).includes(needed),needed);
 }
 for(const forbidden of ['navigator.sendBeacon','fetch(', 'InheritGame.apply(', 'localStorage.setItem(', 'innerHTML=']){
  assert.ok(!ui.includes(forbidden),'side-effecting API '+forbidden);
 }
 assert.match(css,/prefers-reduced-motion:reduce/);
 assert.match(css,/focus-visible/);
 assert.ok(file('interface.js').includes('window.InheritLegacyNetworkUI?.refresh?.()'));
 new vm.Script(ui);new vm.Script(file('legacy-network-core.js'));
});
console.log('INHERIT LEGACY NETWORK:',passed,'passed');
