import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
const read=name=>readFileSync('public/games/inherit/'+name,'utf8');
const src=read('legacy-engine.js'),html=read('index.html'),css=read('legacy.css'),ui=read('legacy-ui.js'),sw=read('sw.js');
const context={};context.window=context;vm.runInNewContext(src,context,{filename:'legacy-engine.js'});
const engine=context.InheritLegacyEngine;
let passed=0;
const check=(name,fn)=>{fn();passed++;console.log('PASS',name)};
const root={generation:13,budget:98,changes:['planted tree','restored moss'],pending:[{type:'tree',x:50,y:50}],objects:[{tool:'tree',x:35,y:44},{tool:'moss',x:42,y:47}],history:[],snapshots:[{generation:10,objects:[{tool:'tree',x:35,y:44},{tool:'moss',x:42,y:47}]}]};
check('six complementary trace rules and shipped offline assets',()=>{
 assert.equal(engine.rules.length,6);for(const filename of ['legacy-engine.js','legacy-ui.js','legacy.css']){assert.ok(html.includes(filename));assert.ok(sw.includes(filename));}
 new vm.Script(src);new vm.Script(ui);assert.match(css,/prefers-reduced-motion:reduce/);
});
check('deterministic grove with proven age in two generations',()=>{
 const before=JSON.stringify(root);const a=engine.derive(root),b=engine.derive(root);
 assert.equal(JSON.stringify(a),JSON.stringify(b));assert.equal(JSON.stringify(root),before);
 assert.equal(a.total,1);assert.equal(a.totals.grove,1);assert.equal(a.effects[0].since,10);assert.equal(a.effects[0].age,3);
 assert.equal(a.effects[0].stage,'growing');assert.equal(a.memory.length,2);
 const later=engine.derive({...root,generation:16});assert.equal(later.effects[0].stage,'heritage');assert.equal(later.effects[0].age,6);
});
check('reversing an unsubmitted trace removes its synergy with no budget impact',()=>{
 const a=engine.derive(root);
 const undone={...root,objects:root.objects.slice(0,1),pending:[],budget:99};
 const b=engine.derive(undone);assert.equal(a.total,1);assert.equal(b.total,0);assert.equal(b.counts.tree,1);
 assert.equal(b.counts.moss,0);assert.equal(b.available[0].place,'moss');
 assert.equal(root.budget,98);
});
check('distance boundaries and six outcome categories are recognized',()=>{
 const pairs=[['grove','tree','moss',16],['waylight','path','light',17],['garden','flower','chime',15],['monument','arch','stone',17],['waymark','marker','path',15],['landmark','cairn','light',14]];
 for(const [id,a,b,d] of pairs){
  assert.equal(engine.derive({generation:1,objects:[{tool:a,x:20,y:20},{type:b,x:20+d,y:20}]}).totals[id],1,id);
  assert.equal(engine.derive({generation:1,objects:[{tool:a,x:20,y:20},{type:b,x:20+d+.1,y:20}]}).totals[id],0,id);
 }
});
check('server-shaped traces without snapshots do not invent confirmed provenance',()=>{
 const m=engine.derive({generation:900,objects:[{type:'path',x:40,y:35},{type:'light',x:42,y:36}]});
 assert.equal(m.total,1);assert.equal(m.effects[0].since,null);assert.equal(m.effects[0].age,null);
 assert.equal(m.effects[0].stage,'unknown');assert.equal(m.memory.length,0);
});
check('invalid, malformed and off-map coordinates cannot create decorations',()=>{
 const m=engine.derive({generation:-20,objects:[null,{tool:'tree',x:NaN,y:40},{type:'tree',x:-1,y:20},{tool:'stone',x:22,y:101},{tool:'__proto__',x:35,y:35},{tool:'tree',x:50,y:50}]});
 assert.equal(m.objects,1);assert.equal(m.total,0);assert.equal(m.generation,0);
});
check('many traces stay bounded; pending and account journals are not used as truth',()=>{
 const huge={generation:10,pending:[{type:'moss',x:3,y:3}],history:[{action:'moss appeared'}],objects:Array.from({length:10200},(_,i)=>({tool:'tree',x:i%100,y:Math.floor(i/100)%100}))};
 const m=engine.derive(huge);assert.equal(m.objects,10000);assert.equal(m.limited,true);assert.equal(m.total,0);
});
check('UI only reads account snapshot and observes the existing renderer',()=>{
 for(const word of ['InheritGame','snapshot','MutationObserver','getLanguage','showModal','dataset.noTranslate','aria-hidden'])assert.ok(ui.includes(word),word);
 for(const banned of ['fetch(', 'localStorage.setItem', 'sessionStorage.setItem','window.InheritGame.apply('])assert.ok(!ui.includes(banned),banned);
});
console.log('INHERIT LEGACY:',passed,'passed');
