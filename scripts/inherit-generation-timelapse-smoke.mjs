import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import '../public/games/inherit/generation-atlas-core.js';
import '../public/games/inherit/generation-timelapse-core.js';

const atlas=globalThis.InheritGenerationAtlas,film=globalThis.InheritTimeLapseCore;
const read=name=>readFileSync('public/games/inherit/'+name,'utf8');
const item=(type,x,y)=>({tool:type,x,y});
let count=0;
function check(name,run){run();count++;console.log('PASS',name)}
check('an absent save has no fabricated historical frames',()=>{
 const empty=film.create(null,0);
 assert.equal(empty.status,'empty');assert.equal(empty.frameCount,0);
 assert.equal(empty.frames.length,0);
});
check('a single real current frame is a baseline, not a historical transition',()=>{
 const state=film.create({generation:173,objects:[item('tree',20,30)],snapshots:[]},0);
 assert.equal(state.status,'ok');assert.equal(state.frameCount,1);
 assert.equal(state.transition,'first-available');
 assert.equal(state.changes,null);
 assert.equal(state.frame.total,1);
 assert.equal(state.markers[0].kind,'baseline');
});
check('sorted real frames retain their exact generation IDs and provenances',()=>{
 const world={generation:15,objects:[item('tree',35,40)],snapshots:[
 {generation:14,objects:[item('stone',40,40)]},{generation:11,objects:[]},
 {generation:13,objects:[item('tree',35,40)]}
 ]};
 const r=film.create(world,2);
 assert.deepEqual(r.frames.map(x=>x.generation),[11,13,14,15]);
 assert.deepEqual(r.frames.map(x=>x.source),['snapshot','snapshot','snapshot','current']);
 assert.equal(r.frame.generation,14);
 assert.equal(r.previous.generation,13);
 assert.equal(r.transition,'adjacent-saved-frames');
});
check('missing saved generations are disclosed as gaps, never interpolated',()=>{
 const world={generation:15,objects:[item('tree',35,40)],
 snapshots:[{generation:10,objects:[item('stone',35,40)]}]};
 const r=film.create(world,1);
 assert.equal(r.transition,'archive-gap');
 assert.equal(r.missingGenerationCount,4);
 assert.deepEqual(r.frames.map(x=>x.generation),[10,15]);
 assert.equal(r.frameCount,2);
});
check('archived and current states from the same generation are not called a handoff',()=>{
 const world={generation:13,objects:[item('tree',40,40),item('stone',80,80)],
 snapshots:[{generation:13,objects:[item('tree',40,40)]}]};
 const result=film.create(world,1);
 assert.equal(result.transition,'same-generation');
 assert.equal(result.frame.source,'current');
 assert.equal(result.changes.added,1);
 assert.equal(result.changes.removed,0);
 assert.equal(result.changes.unchanged,1);
});
check('delta uses multiset semantics, preserving repeated objects at the same point',()=>{
 const w={generation:3,
 snapshots:[{generation:2,objects:[item('tree',20,30),item('tree',20,30),item('stone',40,50)]}],
 objects:[item('tree',20,30),item('light',40,50),item('light',40,50)]};
 const model=film.create(w,1);
 assert.deepEqual(model.changes,{added:2,removed:2,unchanged:1,net:0});
 assert.equal(model.markers.filter(p=>p.kind==='added').length,2);
 assert.equal(model.markers.filter(p=>p.kind==='removed').length,2);
 assert.equal(model.markers.filter(p=>p.kind==='same').length,1);
});
check('invalid saved snapshots are excluded and never shown as a generation',()=>{
 const w={generation:10,objects:[item('tree',35,40)],snapshots:[
 {generation:4,objects:[item('stone',20,20)]},
 {generation:5,objects:[item('tree',-1,25)]},
 {generation:20,objects:[]},
 {generation:4,objects:[item('light',30,30)]}
 ]};
 const r=film.create(w,1);
 assert.equal(r.frameCount,2);assert.equal(r.unavailableRecords,3);
 assert.deepEqual(r.frames.map(x=>x.generation),[4,10]);
});
check('time selection clamps negative, excessive and noninteger indices',()=>{
 const w={generation:3,objects:[item('tree',30,30)],
 snapshots:[{generation:1,objects:[]},{generation:2,objects:[]}]};
 for(const index of [-50,0,0.9,NaN,'2',undefined])
   assert.equal(film.create(w,index).index,0);
 assert.equal(film.create(w,10000).index,2);
 assert.equal(film.create(w,1).index,1);
});
check('a large island displays a bounded sample while keeping all exact totals',()=>{
 const older=Array.from({length:240},(_,i)=>item('stone',i%100,Math.floor(i/100)));
 const current=Array.from({length:450},(_,i)=>item('tree',i%100,Math.floor(i/100)));
 const r=film.create({generation:2,objects:current,snapshots:[{generation:1,objects:older}]},1);
 assert.equal(r.changes.added,450);assert.equal(r.changes.removed,240);
 assert.equal(r.frame.total,450);
 assert.equal(r.markers.length,film.maxPoints);
 assert.equal(r.markersTruncated,true);
});
check('an initial frame samples its own saved objects rather than inventing additions',()=>{
 const a=Array.from({length:240},(_,i)=>item('tree',i%100,Math.floor(i/100)));
 const w={generation:10,objects:[item('stone',30,40)],snapshots:[{generation:1,objects:a}]};
 const r=film.create(w,0);
 assert.equal(r.frame.total,240);assert.equal(r.markers.length,film.maxPoints);
 assert.equal(r.changes,null);assert.equal(r.markersTruncated,true);
 assert.ok(r.markers.every(p=>p.kind==='baseline'));
});
check('a bounded archive explicitly reports missing early saved frames',()=>{
 const snapshots=Array.from({length:atlas.maxFrames+4},(_,i)=>({generation:i,objects:[]}));
 const r=film.create({generation:200,objects:[],snapshots},0);
 assert.equal(r.archiveLimited,true);
 assert.equal(r.frameCount,atlas.maxFrames+1);
 assert.equal(r.frames[0].generation,4);
});
check('comparison never mutates world, account draft, revision or budget',()=>{
 const w={generation:81,budget:73,revision:43,pending:[item('tree',20,10)],
 snapshots:[{generation:80,objects:[item('stone',30,40)]}],
 objects:[item('stone',30,40),item('tree',20,10)]};
 const before=JSON.stringify(w);
 const r=film.create(w,1);
 assert.equal(r.frame.total,2);
 assert.equal(JSON.stringify(w),before);
});
check('all frame metadata and pins come only from validated saved objects',()=>{
 const raw={generation:2,objects:[item('tree',20,40)],snapshots:[{generation:1,objects:[item('stone',40,70)]}]};
 const r=film.create(raw,1);
 assert.equal('author' in r.frame,false);assert.equal('timestamp' in r.frame,false);
 assert.equal('recipient' in r.frame,false);
 for(const p of r.markers){assert.ok(Number.isFinite(p.x));assert.ok(Number.isFinite(p.y))}
 assert.equal(r.source,'local-or-account-saved-frame');
 assert.ok(/not verified/.test(r.caveat));
});
check('UI has pause-on-hide, manual controls and no synthetic network/storage writes',()=>{
 const ui=read('generation-timelapse.js'),css=read('generation-timelapse.css');
 for(const text of ['window.InheritTimeLapseUI','visibilitychange','pagehide',"dialog.addEventListener('close'",'matchMedia','aria-label','input','setTimeout','clearTimeout']){
  assert.ok(ui.includes(text),text);
 }
 for(const banned of ['fetch(', 'sendBeacon(', 'localStorage.setItem(', 'sessionStorage.setItem(', 'InheritGame.apply(', 'innerHTML=']){
  assert.ok(!ui.includes(banned),'Unexpected side effect '+banned);
 }
 assert.ok(ui.includes('dialog.open'));
 assert.match(css,/prefers-reduced-motion:reduce/);
 assert.match(css,/focus-visible/);
 for(const lang of ['ru:', 'en:', 'zh:'])assert.ok(ui.includes(lang));
 new vm.Script(ui);new vm.Script(read('generation-timelapse-core.js'));
});
check('R8 is cached, translated on change, and opened with Atlas only',()=>{
 const html=read('index.html'),sw=read('sw.js'),ui=read('interface.js'),atlasUI=read('generation-atlas.js');
 for(const file of ['generation-timelapse-core.js','generation-timelapse.js','generation-timelapse.css']){
  assert.ok(html.includes('./'+file));assert.ok(sw.includes('/games/inherit/'+file));
 }
 assert.match(sw,/inherit-shell-v20/);
 assert.ok(ui.includes('window.InheritTimeLapseUI?.refresh?.()'));
 assert.ok(atlasUI.includes('window.InheritTimeLapseUI?.refresh?.()'));
 assert.ok(atlasUI.includes("dialog.showModal()"));
});
console.log('INHERIT REAL TIMELAPSE:',count,'passed');
