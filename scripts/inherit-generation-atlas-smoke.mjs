/* INHERIT R6: deterministic saved-world atlas tests. No mock player analytics. */
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import '../public/games/inherit/generation-atlas-core.js';
const atlas=globalThis.InheritGenerationAtlas;
const read=name=>readFileSync('public/games/inherit/'+name,'utf8');
const obj=(type,x,y)=>({tool:type,x,y});
let passed=0;
function test(name,fn){fn();passed++;console.log('PASS '+name)}
test('atlas begins with a factual empty state, not invented earlier generations',()=>{
 const state=atlas.getFrames({generation:173,objects:[]});
 assert.equal(state.frames.length,1);assert.equal(state.frames[0].source,'current');
 assert.equal(atlas.compare({generation:173,objects:[]}).status,'insufficient');
 assert.equal(atlas.compare(null).status,'insufficient');
 assert.equal(atlas.compare({generation:-1,objects:[]}).status,'insufficient');
});
test('real saved snapshots and live state are distinct generations',()=>{
 const w={generation:5,objects:[obj('tree',20,24),obj('stone',42,49)],
 snapshots:[{generation:3,objects:[obj('tree',20,24)]},{generation:4,objects:[obj('tree',20,24),obj('stone',42,49)]}]};
 const model=atlas.getFrames(w);
 assert.deepEqual(model.frames.map(f=>f.id),['s:3','s:4','current:5']);
 const result=atlas.compare(w,'s:3','current:5');
 assert.equal(result.status,'ok');
 assert.deepEqual(result.totals,{added:1,removed:0,unchanged:1,net:1,from:1,to:2});
 assert.equal(result.source,'saved-frames-only');
 assert.equal(result.caveat.includes('no verified authorship'),true);
});
test('added, removed and preserved traces are correctly counted as multisets',()=>{
 const w={generation:9,snapshots:[{generation:7,objects:[obj('tree',30,30),obj('tree',30,30),obj('light',70,60)]}],
 objects:[obj('tree',30,30),obj('moss',65,56),obj('moss',65,56)]};
 const r=atlas.compare(w,'s:7','current:9');
 assert.deepEqual(r.totals,{added:2,removed:2,unchanged:1,net:0,from:3,to:3});
 const trees=r.perType.find(x=>x.type==='tree');
 assert.deepEqual(trees,{type:'tree',before:2,after:1,delta:-1});
 assert.equal(r.pins.filter(x=>x.kind==='added').length,2);
 assert.equal(r.pins.filter(x=>x.kind==='removed').length,2);
});
test('island coordinates are validated, never fixed by silently inventing positions',()=>{
 for(const entry of [obj('tree',-1,2),obj('stone',101,9),obj('arch',Infinity,2),obj('tree','20',20),obj('sword',10,10)]){
  assert.equal(atlas.normalizeObject(entry),null);
 }
 const world={generation:2,snapshots:[{generation:1,objects:[obj('tree',20,20)]},{generation:2,objects:[obj('tree',111,5)]}],
 objects:[obj('stone',25,25)]};
 const state=atlas.getFrames(world);
 assert.deepEqual(state.frames.map(x=>x.id),['s:1','current:2']);
 assert.equal(state.skipped,1);
});
test('invalid future snapshots and repeated generation archives are never presented as events',()=>{
 const world={generation:4,objects:[obj('tree',21,25)],snapshots:[
 {generation:4,objects:[]},{generation:9,objects:[]},{generation:4,objects:[obj('tree',60,40)]},
 {generation:3,objects:[obj('stone',40,41)]}]};
 const r=atlas.getFrames(world);
 assert.deepEqual(r.frames.map(x=>x.id),['s:3','s:4','current:4']);
 assert.equal(r.skipped,2);
});
test('current-generation archived and live states can be compared without asserting a transfer',()=>{
 const w={generation:12,snapshots:[{generation:12,objects:[obj('tree',5,7)]}],
 objects:[obj('tree',5,7),obj('flower',34,55)],pending:[obj('flower',34,55)]};
 const r=atlas.compare(w,'s:12','current:12');
 assert.equal(r.status,'ok');
 assert.equal(r.from.source,'snapshot');assert.equal(r.to.source,'current');
 assert.equal(r.totals.added,1);
 assert.equal(r.caveat.includes('server event attribution'),true);
});
test('original saved world and nested object arrays remain byte-for-byte unchanged',()=>{
 const w={generation:16,objects:[obj('tree',23.3,12.2)],snapshots:[{generation:15,objects:[obj('stone',21,42)]}]};
 const before=JSON.stringify(w);
 const a=atlas.getFrames(w),b=atlas.compare(w,'s:15','current:16');
 assert.equal(b.status,'ok');assert.equal(a.frames.length,2);
 assert.equal(JSON.stringify(w),before);
});
test('large maps render a bounded pin sample but retain exact change totals',()=>{
 const old=Array.from({length:500},(_,i)=>obj('stone',i%100,Math.floor(i/100)));
 const newer=Array.from({length:800},(_,i)=>obj('tree',i%100,Math.floor(i/100)));
 const w={generation:2,snapshots:[{generation:1,objects:old}],objects:newer};
 const r=atlas.compare(w,'s:1','current:2');
 assert.equal(r.totals.added,800);assert.equal(r.totals.removed,500);
 assert.equal(r.pins.length<=atlas.maxMarkers,true);assert.equal(r.pinsTruncated,true);
});
test('oversized and non-archive objects are excluded, not partially accepted',()=>{
 const oversized=Array.from({length:atlas.maxObjects+1},()=>obj('tree',25,25));
 const w={generation:19,objects:oversized,snapshots:[{generation:18,objects:[]}]};
 const r=atlas.getFrames(w);
 assert.equal(r.frames.length,1);assert.equal(r.skipped,1);
 assert.equal(r.frames[0].source,'snapshot');
});
test('timeline archive cap is bounded and explicitly disclosed to users',()=>{
 const frames=Array.from({length:atlas.maxFrames+20},(_,i)=>({generation:i,objects:[]}));
 const r=atlas.getFrames({generation:200,objects:[],snapshots:frames});
 assert.equal(r.frames.length,atlas.maxFrames+1);
 assert.equal(r.limited,true);assert.equal(r.frames[0].generation,20);
});
test('atlas is local-only, localized, keyboard navigable and cached for offline use',()=>{
 const ui=read('generation-atlas.js'),css=read('generation-atlas.css'),
  html=read('index.html'),sw=read('sw.js'),interfaceScript=read('interface.js');
 for(const file of ['generation-atlas-core.js','generation-atlas.js','generation-atlas.css']){
  assert.ok(html.includes('./'+file),'HTML '+file);
  assert.ok(sw.includes('/games/inherit/'+file),'offline '+file);
 }
 assert.match(sw,/inherit-shell-v23/);
 assert.match(css,/prefers-reduced-motion:reduce/);
 assert.match(css,/focus-visible/);
 for(const word of ['ru:','en:','zh:','showModal','textContent','aria-labelledby'])assert.ok(ui.includes(word));
 for(const forbidden of ['fetch(', 'sendBeacon', 'localStorage.setItem(', 'sessionStorage.setItem(', 'innerHTML=', 'InheritGame.apply(','.saveDraft(','.setItem('])
   assert.ok(!ui.includes(forbidden),'unexpected side effect: '+forbidden);
 assert.ok(interfaceScript.includes('window.InheritAtlasUI?.refresh?.()'));
 new vm.Script(ui);new vm.Script(read('generation-atlas-core.js'));
});
console.log('INHERIT GENERATION ATLAS: '+passed+' passed');
