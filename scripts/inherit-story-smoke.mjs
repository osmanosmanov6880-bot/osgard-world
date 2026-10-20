import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const read=name=>readFileSync('public/games/inherit/'+name,'utf8');
const base=read('legacy-engine.js'),engineSource=read('story-engine.js');
const ui=read('story-ui.js'),css=read('story.css'),html=read('index.html'),sw=read('sw.js');
const context={};context.window=context;
vm.runInNewContext(base,context,{filename:'legacy-engine.js'});
vm.runInNewContext(engineSource,context,{filename:'story-engine.js'});
const story=context.InheritStoryEngine;
let total=0;function check(name,fn){fn();total++;console.log('PASS',name);}
const l=(type,x,y)=>({tool:type,x,y});
const world=(generation,objects,pending=[])=>({generation,budget:100-pending.length,objects,pending,changes:pending.map(p=>p.tool),history:[],snapshots:[]});

check('three chapter assets are shipped and available in offline shell',()=>{
 for(const file of ['story.css','story-engine.js','story-ui.js']){
  assert.ok(html.includes('./'+file),file);
  assert.ok(sw.includes('/games/inherit/'+file),file);
 }
 new vm.Script(engineSource);new vm.Script(ui);
 assert.match(css,/prefers-reduced-motion:reduce/);
});
check('four stable chapters and three possible missions per generation',()=>{
 assert.equal(story.chapters.length,4);
 const chapters=[0,1,2,3,4,5,173].map(n=>story.evaluate(world(n,[])));
 assert.deepEqual(chapters.map(x=>x.chapter),['shore','signal','haven','memory','shore','signal','signal']);
 assert.ok(chapters.every(x=>x.objectives.length===3&&x.done===0&&x.dataConsistent));
});
check('real current-generation light and path create completed signal chapter',()=>{
 const objects=[l('light',30,30),l('path',38,38)];
 const original=world(173,objects,objects);
 const before=JSON.stringify(original);
 const a=story.evaluate(original),b=story.evaluate(original);
 assert.equal(JSON.stringify(a),JSON.stringify(b));
 assert.equal(JSON.stringify(original),before);
 assert.equal(a.chapter,'signal');assert.equal(a.done,3);
 assert.equal(a.complete,true);assert.equal(a.mood,'routes');
 assert.deepEqual(a.objectives.map(o=>o.done),[true,true,true]);
 assert.equal(a.pendingCount,2);
});
check('handoff clears quests but preserves inherited island consequences',()=>{
 const objects=[l('light',30,30),l('path',38,38)];
 const passed=story.evaluate(world(174,objects,[]));
 assert.equal(passed.chapter,'haven');
 assert.equal(passed.done,0);
 assert.equal(passed.complete,false);
 assert.equal(passed.mood,'routes');
 assert.ok(passed.legacyTotals.waylight>0);
});
check('new connection can form with an old retained trace',()=>{
 const old=l('light',30,30),latest=l('path',39,39);
 const answer=story.evaluate(world(173,[old,latest],[latest]));
 assert.deepEqual(answer.objectives.map(o=>o.done),[false,true,true]);
 assert.equal(answer.done,2);
});
check('an existing old connection is never awarded as a new chapter quest',()=>{
 const old=[l('path',40,40),l('light',42,42)];
 const latest=l('stone',89,88);
 const answer=story.evaluate(world(173,[...old,latest],[latest]));
 assert.equal(answer.done,0);
 assert.equal(answer.legacyTotals.waylight,1);
});
check('distance controls actual quest completion',()=>{
 const first=l('light',10,10);
 const far=l('path',35,10);
 const near=l('path',27,10);
 const distant=story.evaluate(world(173,[first,far],[first,far]));
 const connected=story.evaluate(world(173,[first,near],[first,near]));
 assert.equal(distant.done,2);
 assert.equal(connected.done,3);
});
check('every branch can be completed by its named traces',()=>{
 const recipes=[
  [172,[l('tree',20,20),l('moss',21,21),l('path',80,80)]],
  [173,[l('light',20,20),l('path',23,23)]],
  [174,[l('tree',20,20),l('moss',21,21),l('flower',80,80)]],
  [175,[l('arch',20,20),l('stone',21,21),l('cairn',80,80)]]
 ];
 for(const [generation,objects] of recipes){
  const result=story.evaluate(world(generation,objects,objects));
  assert.equal(result.complete,true,generation+' '+JSON.stringify(result.objectives));
 }
});
check('invalid or forged current-generation pending data cannot award story progress',()=>{
 const objects=[l('light',20,20),l('path',22,22)];
 const forged=story.evaluate(world(173,objects,[l('path',90,90)]));
 assert.equal(forged.dataConsistent,false);
 assert.equal(forged.done,0);
 const oversized=story.evaluate(world(173,objects,Array.from({length:101},()=>l('tree',1,1))));
 assert.equal(oversized.dataConsistent,false);
 assert.equal(oversized.done,0);
});
check('quiet, nature and memory consequences are determined by retained traces',()=>{
 assert.equal(story.evaluate(world(1,[])).mood,'quiet');
 assert.equal(story.evaluate(world(1,[l('tree',20,20),l('moss',21,21)])).mood,'nature');
 assert.equal(story.evaluate(world(1,[l('stone',20,20),l('arch',21,21)])).mood,'memory');
});
check('chapter UI uses no new persistence schema or payment/network effects',()=>{
 for(const banned of ['fetch(', 'localStorage.setItem', 'sessionStorage.setItem','InheritGame.apply(', 'innerHTML='])assert.ok(!ui.includes(banned),banned);
 for(const required of ['dataConsistent','MutationObserver','getLanguage','inherit-chapter-goal','aria-label','disabled=!editable'])assert.ok(ui.includes(required),required);
});
console.log('INHERIT STORY:',total,'passed');
