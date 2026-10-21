import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import '../public/games/inherit/handoff-moment-core.js';
const core=globalThis.InheritHandoffMomentCore;
const read=name=>readFileSync('public/games/inherit/'+name,'utf8');
const mark=(type,x,y)=>({type,x,y}),delta=[mark('tree',20,20),mark('light',40,45)];
const local=(outcome='local')=>({mode:'local',outcome,fromGeneration:13,toGeneration:14,
 delta,after:{generation:14,objects:[mark('stone',1,1),...delta],pending:[]}});
const account=()=>({mode:'account',outcome:'confirmed',fromGeneration:2,toGeneration:3,delta});
let n=0;function check(name,run){run();n++;console.log('PASS '+name)}
check('no receipt is created from a missing or simulated generation result',()=>{
 assert.equal(core.create(null),null);assert.equal(core.create({}),null);
 assert.equal(core.create({mode:'local',outcome:'confirmed',fromGeneration:8,toGeneration:9,delta:[],after:{generation:9,objects:[],pending:[]}}),null);
});
check('valid real local completion is explicitly not server-confirmed',()=>{
 const r=core.create(local());
 assert.equal(r.verification,'local-saved-server-unverified');assert.equal(r.from,13);
 assert.equal(r.to,14);assert.equal(r.traceCount,2);assert.equal(r.afterTotal,3);
 assert.equal(r.caveat,'no-next-player-or-verified-author-claim');
});
check('the same local completion can be server-confirmed only by a verified caller',()=>{
 const r=core.create(local('confirmed'));
 assert.equal(r.verification,'shared-server-confirmed');assert.equal(r.source,'explicit-commit-only');
});
check('an account-world receipt requires a completed server operation',()=>{
 const r=core.create(account());
 assert.equal(r.verification,'account-server-confirmed');assert.equal(r.afterTotal,null);
 assert.equal(core.create({...account(),outcome:'local'}),null);
 assert.equal(core.create({...account(),outcome:'pending'}),null);
 assert.equal(core.create({...account(),outcome:'uncertain'}),null);
});
check('generation numbers must advance by exactly one safe generation',()=>{
 for(const [from,to] of [[3,3],[3,5],[-1,0],[1.1,2.1],[9,NaN],[10000000,10000001]]){
  assert.equal(core.create({...account(),fromGeneration:from,toGeneration:to}),null);
 }
});
check('unknown types, strings and invalid positions are rejected without coercion',()=>{
 for(const item of [mark('sword',10,10),mark('tree',-1,10),mark('tree',101,10),
  mark('tree',Infinity,1),mark('tree','10',20),mark('tree',10,NaN),null]){
  assert.equal(core.create({...account(),delta:[item]}),null);
 }
});
check('a local receipt requires the exact committed generation and no pending work',()=>{
 assert.equal(core.create({...local(),after:{...local().after,generation:15}}),null);
 assert.equal(core.create({...local(),after:{...local().after,pending:[delta[0]]}}),null);
 assert.equal(core.create({...local(),after:{...local().after,objects:[mark('stone',1,1),mark('light',40,45),mark('tree',20,20)]}}),null);
 assert.equal(core.create({...local(),after:undefined}),null);
});
check('identical object instances retain exact type counts, never fabricated players',()=>{
 const two=[mark('tree',22,35),mark('tree',22,35),mark('path',70,66)];
 const r=core.create({...account(),delta:two});
 assert.equal(r.traceCount,3);
 assert.deepEqual(r.counts,[{type:'tree',count:2},{type:'path',count:1}]);
 assert.equal('author' in r,false);assert.equal('recipient' in r,false);
});
check('100 real traces count exactly while rendering a bounded sample',()=>{
 const many=Array.from({length:100},(_,i)=>mark('flower',i,50));
 const r=core.create({...account(),delta:many});
 assert.equal(r.traceCount,100);assert.equal(r.markers.length,core.maxMarkers);
 assert.equal(r.markersTruncated,true);assert.equal(r.counts[0].count,100);
 assert.equal(core.create({...account(),delta:many.concat(many[0])}),null);
});
check('a receipt never changes its input world or existing account draft',()=>{
 const raw=local('confirmed'),before=JSON.stringify(raw);
 const receipt=core.create(raw);
 assert.equal(receipt.verification,'shared-server-confirmed');
 assert.equal(JSON.stringify(raw),before);
});
check('UI is nonmodal, localized, accessible and leaves the real game controls alone',()=>{
 const h=read('index.html'),js=read('handoff-moment.js'),css=read('handoff-moment.css'),sw=read('sw.js'),lang=read('interface.js');
 for(const file of ['handoff-moment.css','handoff-moment-core.js','handoff-moment.js']){
  assert.ok(h.includes('./'+file),'HTML '+file);
  assert.ok(sw.includes('/games/inherit/'+file),'offline '+file);
 }
 for(const s of ['ru:','en:','zh:','aria-live','role','status','InheritAtlasUI?.open'])assert.ok(js.includes(s),'UI missing '+s);
 assert.ok(js.includes("banner.hidden=true"));
 assert.ok(js.includes("core.create(value)"));
 assert.ok(!js.includes('.showModal('));
 for(const bad of ['fetch(', 'sendBeacon(', 'localStorage.setItem(', 'sessionStorage.setItem(', 'InheritGame.apply(', 'innerHTML='])
  assert.ok(!js.includes(bad),'side effect '+bad);
 assert.match(css,/prefers-reduced-motion:reduce/);
 assert.match(css,/\.inherit-handoff-moment\{pointer-events:none\}/);
 assert.ok(read('index.html').includes('InheritHandoffMomentUI?.dismiss?.()'));
 assert.match(css,/focus-visible/);
 assert.match(sw,/inherit-shell-v25/);
 assert.ok(lang.includes('InheritHandoffMomentUI?.refresh?.()'));
 new vm.Script(js);new vm.Script(read('handoff-moment-core.js'));
});
check('local callback is wired only in the final successful commit branch',()=>{
 const h=read('index.html');
 const end=h.indexOf("q('#pass').onclick=async function(){\n if(inheritAccountMode)");
 const start=h.indexOf("function validHandoffResult");
 assert.ok(start>=0&&end>start);
 const section=h.slice(end,h.indexOf("}finally{setHandoffBusy(false)}",end));
 assert.ok(section.includes("persist();render();"));
 assert.ok(section.indexOf("handoffComplete?.(")>section.indexOf("persist();render();"));
 assert.ok(section.indexOf("handoffComplete?.(")>section.indexOf("if(reply.conflict)"));
 assert.ok(section.includes("outcome:confirmed?'confirmed':'local'"));
 const acct=read('account.js');
 const fn=acct.slice(acct.indexOf('async function complete('),acct.indexOf('async function mutate('));
 assert.ok(fn.includes("operationProof(saved,result)"));
 assert.ok(fn.indexOf('game.handoffComplete?.(')>fn.indexOf('operationProof(saved,result)'));
 assert.ok(fn.includes("if(saved.kind==='generation')"));
 assert.ok(fn.includes("return true;"));
});
console.log('INHERIT HANDOFF MOMENT:',n,'passed');
