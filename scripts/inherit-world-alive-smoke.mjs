import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
const dir='public/games/inherit/';
const read=(name)=>readFileSync(dir+name,'utf8');
const runtime={};runtime.window=runtime;
for(const file of ['legacy-engine.js','story-engine.js','world-cycle-engine.js','world-alive-engine.js'])vm.runInNewContext(read(file),runtime,{filename:file});
const core=runtime.InheritWorldAliveEngine;
const html=read('index.html'),js=read('world-alive-ui.js'),css=read('world-alive.css'),sw=read('sw.js');
let n=0;
function test(label,callback){callback();n++;console.log('PASS',label)}
const first={generation:173,budget:100,objects:[],pending:[],changes:[]};
test('New UI and engine parse without external dependencies',()=>{
 new vm.Script(read('world-alive-engine.js'));
 new vm.Script(js);
});
test('Blank world shows genuine zero counts and three unearned goals',()=>{
 const a=core.summarize(first,runtime);
 assert.equal(a.generation,173);assert.equal(a.objects,0);assert.equal(a.connections,0);
 assert.equal(a.completed,0);assert.equal(a.goalCount,3);assert.equal(a.readonly,false);
 assert.equal(a.season,'sun');
});
test('Real nearby path and light produce a genuine combination',()=>{
 const placed=[{tool:'path',x:44,y:42},{tool:'light',x:50,y:45}];
 const world={...first,budget:98,objects:placed,pending:placed,changes:['path','light']};
 const before=JSON.stringify(world);
 const a=core.summarize(world,runtime);
 assert.equal(a.objects,2);assert.equal(a.connections,1);assert.equal(a.completed,3);
 assert.equal(a.goals.every(g=>g.done),true);assert.equal(a.readonly,false);
 assert.equal(JSON.stringify(world),before,'Summary must not mutate a stored game world');
});
test('A matching pair far apart is not a connection',()=>{
 const far={...first,budget:98,objects:[{tool:'path',x:10,y:15},{tool:'light',x:88,y:75}],
   pending:[{type:'path',x:10,y:15},{type:'light',x:88,y:75}]};
 const a=core.summarize(far,runtime);
 assert.equal(a.connections,0);assert.equal(a.completed,2);
});
test('An inherited pair is not falsely credited as a new chapter goal',()=>{
 const saved={...first,budget:100,objects:[{tool:'path',x:44,y:42},{tool:'light',x:50,y:45}],pending:[]};
 const a=core.summarize(saved,runtime);
 assert.equal(a.connections,1);assert.equal(a.completed,0);
});
test('Generation change recalculates real chapter and season',()=>{
 const next=core.summarize({...first,generation:174},runtime);
 assert.equal(next.chapter,'haven');assert.equal(next.season,'wind');
 assert.equal(next.completed,0);
});
test('Invalid or truncated saved world fails safely',()=>{
 const invalid=core.summarize({generation:-2,budget:5,objects:[]},runtime);
 assert.equal(invalid.readonly,true);assert.equal(invalid.validWorld,false);
 assert.equal(invalid.next,null);
 const corrupted=core.summarize({generation:173,budget:100,objects:[{tool:'unknown',x:1,y:2}],pending:[{tool:'unknown',x:1,y:2}]},runtime);
 assert.equal(corrupted.readonly,true);
});
test('Legacy core goals and optics use the existing real engines',()=>{
 for(const k of ['InheritStoryEngine','InheritWorldCycle','InheritLegacyEngine']){
   assert.ok(read('world-alive-engine.js').includes(k));
 }
 assert.match(js,/engine\.summarize\(source\(\),window\)/);
 assert.match(js,/after\.budget===oldBudget-1/);
 assert.match(js,/after\.objects\?\.length===oldCount\+1/);
});
test('Goals select only native tools and player still performs the actual placement',()=>{
 assert.match(js,/\.tools \[data-tool=/);
 assert.match(js,/\.catalog \[data-extra=/);
 assert.match(js,/button\.click\(\)/);
 assert.doesNotMatch(js,/game\.apply\(|game\.saveDraft\(|\bpersist\(|\bfetch\(/);
});
test('Sound is opt-in, visuals are reduced-motion and throttled',()=>{
 assert.match(js,/soundEnabled=false/);
 assert.match(js,/world-alive-fx:v1/);
 assert.match(js,/now-lastFrame>=48/);
 assert.match(js,/IntersectionObserver/);
 assert.match(js,/prefers-reduced-motion: reduce/);
 assert.match(css,/@media\(prefers-reduced-motion:reduce\)/);
});
test('Original 2.5D placement remains clickable beneath decoration',()=>{
 assert.match(css,/world-alive-ocean\{[^}]*pointer-events:none/s);
 assert.match(css,/world-alive-handoff\{[^}]*pointer-events:none/s);
 assert.match(css,/world-alive-burst\{[^}]*pointer-events:none/s);
 assert.match(css,/@media\(max-width:740px\)/);
 assert.match(js,/dock\.insertAdjacentElement\('afterend',section\)/);
 assert.match(css,/\.app>\.world-alive-hub\{[^}]*order:4/s);
});
test('Exact game delivery includes the three new assets',()=>{
 for(const name of ['world-alive-engine.js','world-alive-ui.js','world-alive.css']){
   assert.ok(html.includes('./'+name),name+' missing from game HTML');
   assert.ok(sw.includes('/games/inherit/'+name),name+' missing from offline shell');
 }
 assert.match(sw,/inherit-shell-v27/);
});
console.log('INHERIT World Alive R15:',n,'passed.');
