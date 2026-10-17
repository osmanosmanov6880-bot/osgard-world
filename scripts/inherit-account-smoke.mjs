import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import vm from 'node:vm';
import { createHash } from 'node:crypto';

// This is an in-memory API fixture, never a server or a production request.
// The controller and placement handler below are the actual shipped source.
export const ids={alice:'1'.repeat(32),bob:'2'.repeat(32),carol:'3'.repeat(32)};
export const tokens={alice:'inherit-fixture-alice',bob:'inherit-fixture-bob',carol:'inherit-fixture-carol'};
export const CORE_KEY='osgard:core-session:v1';
export const API='/api/core/inherit/v1/';
const copy=value=>JSON.parse(JSON.stringify(value));
const hash=value=>createHash('sha256').update(JSON.stringify(value)).digest('hex');
const stamp='2026-10-17T12:00:00Z';
const error=(code,status)=>({status,body:{error:code,message:'Fixture '+code}});
export function serviceFixture(){
 let number=10,notificationId=0;
 const service={calls:[],worlds:new Map(),invitations:new Map(),operations:new Map(),notifications:[],revoked:new Set()};
 const uid=()=>String(++number).padStart(32,'0');
 const person=id=>({id,username:Object.keys(ids).find(name=>ids[name]===id)});
 const invitationView=value=>copy(value);
 const worldView=(w,actor,summary=false)=>{
  const invitation=w.pending?service.invitations.get(w.pending):null;
  const pending=invitation?.status==='pending'?invitation:null;
  const result={id:w.id,title:w.title,template:'quiet-reach-v1',source:w.source,sourceVerified:w.source==='template',
   creator:person(w.creator),custodian:person(w.custodian),role:actor===w.custodian?'custodian':'reader',
   canEdit:actor===w.custodian&&!pending,canOfferHandoff:actor===w.custodian&&!pending&&w.generation>w.custodyStart,
   revision:w.revision,currentGeneration:w.generation,snapshotHash:w.snapshotHash,baselineHash:w.baselineHash,
   pendingHandoff:pending?invitationView(pending):null,createdAt:stamp,updatedAt:stamp};
  if(!summary){result.objects=copy(w.objects);result.generations=copy(w.generations).map(({objects,...item})=>item)}
  return result;
 };
 function notify(userId,world,actor,kind,invitationId=null,generation=null){
  service.notifications.unshift({userId,id:++notificationId,kind,worldId:world.id,invitationId,generation,actor:person(actor),createdAt:stamp,readAt:null});
 }
 service.view=(id,actor=ids.alice)=>worldView(service.worlds.get(id),actor);
 service.handle=call=>{
  service.calls.push(copy({...call,signal:undefined}));
  const authorization=call.headers.authorization||'',username=Object.keys(tokens).find(name=>authorization==='Bearer '+tokens[name]);
  const actor=username&&!service.revoked.has(username)?ids[username]:null;
  if(call.path==='/api/core/auth/me')return actor?{status:200,body:{user:person(actor)}}:error('authentication_required',401);
  if(!call.path.startsWith(API))return error('not_found',404);
  if(!actor)return error('authentication_required',401);
  const route=call.path.slice(API.length),body=call.body||{},key=call.headers['idempotency-key'];
  if(call.method==='GET'){
   if(route==='capabilities')return {status:200,body:{schemaVersion:1,template:'quiet-reach-v1',permissions:'single-custodian-retained-history',
    limits:{worlds:32,objects:1024,generations:128,delta:100,members:64,handoffs:256,notifications:200},
    externalNotifications:false,operationRecovery:'get-only',importedHistoryVerified:false}};
   if(route==='worlds')return {status:200,body:{worlds:[...service.worlds.values()].filter(w=>w.members.has(actor)).map(w=>worldView(w,actor,true))}};
   if(route==='notifications'){const list=service.notifications.filter(n=>n.userId===actor).map(({userId,...n})=>copy(n));return {status:200,body:{notifications:list,unreadCount:list.filter(n=>n.readAt===null).length}}}
   if(route.startsWith('operations/')){const result=service.operations.get(actor+':'+route.slice(11));return result?{status:200,body:{status:'committed',operation:copy(result.operation),result:copy(result)}}:error('not_found',404)}
   const wmatch=/^worlds\/([a-f0-9]{32})(?:\/generations\/(\d+))?$/.exec(route);
   if(wmatch){const w=service.worlds.get(wmatch[1]);if(!w?.members.has(actor))return error('not_found',404);
    if(wmatch[2]){const generation=w.generations.find(g=>g.number===Number(wmatch[2]));return generation?{status:200,body:{worldId:w.id,generation:copy(generation)}}:error('not_found',404)}
    return {status:200,body:{world:worldView(w,actor)}}}
   const inv=/^handoffs\/([a-f0-9]{32})$/.exec(route);
   if(inv){const value=service.invitations.get(inv[1]);return value&&[value.from.id,value.to.id].includes(actor)?{status:200,body:{invitation:invitationView(value)}}:error('not_found',404)}
   return error('not_found',404);
  }
  if(call.method!=='POST'||!key)return error('invalid_request',400);
  if(service.operations.has(actor+':'+key))return {status:200,body:copy(service.operations.get(actor+':'+key))};
  let result,kind,worldId=null,invitationId=null;
  if(route==='worlds'){
   const id=uid(),baselineHash=hash(body.objects);
   const w={id,title:body.title,source:body.source,creator:actor,custodian:actor,members:new Set([actor]),revision:1,generation:1,custodyStart:1,
    baselineHash,snapshotHash:baselineHash,objects:copy(body.objects),generations:[],pending:null};
   service.worlds.set(id,w);kind='create';worldId=id;result={world:worldView(w,actor)};
  }else if(/^worlds\/[a-f0-9]{32}\/(generations|handoffs)$/.test(route)){
   const parts=route.split('/'),w=service.worlds.get(parts[1]);if(!w?.members.has(actor))return error('not_found',404);
   if(w.custodian!==actor)return error('forbidden',403);
   if(body.expectedRevision!==w.revision)return error('version_conflict',409);
   if(w.pending&&service.invitations.get(w.pending)?.status==='pending')return error('handoff_pending',409);
   worldId=w.id;
   if(parts[2]==='generations'){
    if(body.expectedGeneration!==w.generation)return error('generation_conflict',409);
    const generation={number:w.generation,author:person(actor),message:body.message,delta:copy(body.delta),createdAt:stamp,
     parentHash:w.snapshotHash,snapshotHash:hash([w.id,w.generation,body]),objects:w.objects.concat(copy(body.delta))};
    w.objects=copy(generation.objects);w.generations.push(generation);w.generation++;w.revision++;w.snapshotHash=generation.snapshotHash;
    kind='generation';result={world:worldView(w,actor),generation:copy(generation)};delete result.generation.objects;
    for(const member of w.members)if(member!==actor)notify(member,w,actor,'generation_created',null,generation.number);
   }else{
    if(w.generation<=w.custodyStart)return error('generation_required',409);
    if(!Object.values(ids).includes(body.targetUserId)||body.targetUserId===actor||body.sharingAcknowledged!==true)return error('invalid_request',400);
    invitationId=uid();w.revision++;w.pending=invitationId;
    const value={id:invitationId,worldId:w.id,worldTitle:w.title,from:person(actor),to:person(body.targetUserId),status:'pending',
     expectedRevision:w.revision,createdAt:stamp,expiresAt:'2026-10-24T12:00:00Z'};
    service.invitations.set(invitationId,value);notify(body.targetUserId,w,actor,'handoff_offered',invitationId);
    kind='offer';result={world:worldView(w,actor),invitation:invitationView(value)};
   }
  }else if(/^handoffs\/[a-f0-9]{32}\/(accept|cancel|decline)$/.test(route)){
   const [,id,action]=route.split('/'),value=service.invitations.get(id);
   if(!value||![value.from.id,value.to.id].includes(actor))return error('not_found',404);
   const w=service.worlds.get(value.worldId);
   if(actor!==(action==='cancel'?value.from.id:value.to.id))return error('forbidden',403);
   if(body.expectedRevision!==w.revision||value.status!=='pending')return error('handoff_conflict',409);
   value.status={accept:'accepted',cancel:'cancelled',decline:'declined'}[action];w.pending=null;w.revision++;
   if(action==='accept'){w.custodian=actor;w.custodyStart=w.generation;w.members.add(actor)}
   notify(action==='cancel'?value.to.id:value.from.id,w,actor,'handoff_'+value.status,value.id);
   invitationId=id;kind=action;result={invitation:invitationView(value)};
   if(action!=='decline'||w.members.has(actor)){result.world=worldView(w,actor);worldId=w.id}
  }else if(/^notifications\/\d+\/read$/.test(route)){
   const value=service.notifications.find(item=>item.id===Number(route.split('/')[1])&&item.userId===actor);
   if(!value)return error('not_found',404);value.readAt=stamp;const {userId,...notification}=value;
   kind='notification_read';result={notification:copy(notification)};
  }else return error('not_found',404);
  result.operation={key,kind,status:'committed',worldId,invitationId};service.operations.set(actor+':'+key,copy(result));
  return {status:200,body:result};
 };
 return service;
}
const source=readFileSync('public/games/inherit/account.js','utf8');
const html=readFileSync('public/games/inherit/index.html','utf8');
const placement=html.match(/q\('#world'\)\.onclick=function\(event\)\{[^\n]+\};/)[0];
const emptyLocal=()=>({generation:173,budget:100,objects:[],pending:[],changes:[],history:[],snapshots:[]});
const response=reply=>({ok:reply.status>=200&&reply.status<300,status:reply.status,headers:{get:()=> 'application/json'},json:async()=>copy(reply.body)});
export function deferred(){let resolve,reject;const promise=new Promise((yes,no)=>{resolve=yes;reject=no});return {promise,resolve,reject}}
let documentNumber=0;
export function harness({service=serviceFixture(),data=new Map(),tab=new Map([[CORE_KEY,tokens.alice]]),mode=false,route={},local=emptyLocal(),handler}={}){
 const serial=++documentNumber,timers=new Map(),calls=[],downloads=[],renders=[];
 let counter=0,timerId=0,clock=Date.parse(stamp),state=copy(local),selectedMode=mode,localSnapshot=copy(local),busy=false;
 const h={service,data,tab,calls,downloads,handler,denyRead:false,denyWrite:false,denySession:false,writeHook:null};
 const storage={get length(){if(h.denyRead)throw Error('denied');return data.size},key:index=>[...data.keys()][index]??null,
  getItem:key=>{if(h.denyRead)throw Error('denied');return data.get(key)??null},
  setItem(key,value){if(h.denyWrite||h.writeHook?.(key,value))throw Error('quota');data.set(key,String(value))},
  removeItem(key){if(h.denyWrite)throw Error('quota');data.delete(key)}};
 const nodes=new Map(),node=id=>{if(!nodes.has(id))nodes.set(id,{onclick:null,getBoundingClientRect:()=>({left:0,top:0,width:100,height:100})});return nodes.get(id)};
 const context={console,URL,URLSearchParams,AbortController,setTimeout,clearTimeout,
  document:{readyState:'loading',addEventListener(){}},q:node,tool:'tree',names:{tree:'tree',stone:'stone',light:'light'},render(){},notice(){}};
 context.window=context;vm.createContext(context);vm.runInContext(source,context,{filename:'shipped-inherit-account.js'});
 const game={accountMode:()=>selectedMode,snapshot:()=>copy(state),localSnapshot:()=>copy(localSnapshot),
  setMode(value){if(value&&!selectedMode)localSnapshot=copy(state);selectedMode=value;if(!value)state=copy(localSnapshot)},
  apply:value=>{state=copy(value)},busy:value=>{busy=value},notify(){},caption(){},
  download:(value,name)=>downloads.push({value:copy(value),name}),history:(values,view)=>{h.history=values;h.viewHistory=view},
  showSnapshot:(generation,objects)=>{h.snapshot={generation,objects:copy(objects)}}};
 const controller=context.InheritAccountFactory.create({game,storage,session:{getItem:key=>{if(h.denySession)throw Error('denied');return tab.get(key)||null}},
  origin:'https://osgard.world',uuid:()=>('fixture-'+serial+'-'+(++counter)).padEnd(32,'0'),route:()=>route,setRoute:value=>{route.mode=value?'account':undefined},
  now:()=>clock,setTimeout(fn,ms){const id=++timerId;timers.set(id,{at:clock+ms,fn});return id},clearTimeout:id=>timers.delete(id),
  view:{render:value=>renders.push(copy(value))},
  fetch:async(url,options)=>{
   const parsed=new URL(url),call={url,path:parsed.pathname,method:options.method||'GET',headers:Object.fromEntries(Object.entries(options.headers||{}).map(([k,v])=>[k.toLowerCase(),v])),
    body:options.body?JSON.parse(options.body):undefined,credentials:options.credentials,cache:options.cache,redirect:options.redirect,signal:options.signal};
   calls.push(call);
   if(h.handler){const intercepted=await h.handler(call,h);if(intercepted!==undefined)return intercepted}
   return response(service.handle(call));
  }});
 context.blockWhileHandoff=action=>controller.blockMutation(action)||busy;
 context.persist=()=>controller.saveDraft();
 Object.defineProperty(context,'S',{get:()=>state});
 vm.runInContext(placement,context,{filename:'shipped-inherit-placement.js'});
 h.controller=controller;h.game=game;h.current=()=>copy(state);h.ui=()=>copy(controller.state());
 h.start=()=>controller.start();h.account=()=>controller.selectMode(true);
 h.place=(type='tree')=>{context.tool=type;node('#world').onclick({target:{closest:()=>null},clientX:50,clientY:40})};
 h.operations=()=>[...data].filter(([key])=>key.startsWith('osgard:inherit-operation:v1:')).map(([key,raw])=>({key,value:JSON.parse(raw)}));
 h.drafts=()=>[...data].filter(([key])=>key.startsWith('osgard:inherit-draft:v1:')).map(([key,raw])=>({key,value:JSON.parse(raw)}));
 h.posts=()=>calls.filter(call=>call.method==='POST');
 h.flush=async()=>{for(let index=0;index<100;index++)await Promise.resolve()};
 h.advance=async ms=>{clock+=ms;for(const [id,timer]of [...timers])if(timer.at<=clock){timers.delete(id);timer.fn()}await h.flush()};
 h.response=response;return h;
}
let passed=0;
async function check(name,run){let timer;try{await Promise.race([run(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Fixture deadline: '+name)),4000)})])}finally{clearTimeout(timer)}passed++;console.log('PASS',name)}
async function create(h){await h.account();assert.equal(await h.controller.createWorld('template','Quiet fixture'),'committed');return h.ui().world.id}
async function generationOne(h){h.place();assert.equal(await h.controller.saveGeneration('One trace'),'committed')}
async function suite(){
 await check('a stored Core token never silently upgrades the local game or makes an authenticated request',async()=>{
  const h=harness();await h.start();assert.equal(h.calls.length,0);assert.equal(h.ui().mode,false);assert.deepEqual(h.current(),emptyLocal());
 });
 await check('private create, two custodians, notification return and immutable snapshot complete the actual controller loop',async()=>{
  const service=serviceFixture(),a=harness({service}),worldId=await create(a);await generationOne(a);
  const first=copy(service.worlds.get(worldId).generations[0]);
  assert.equal(await a.controller.offer(ids.bob,true),'committed');assert.equal(a.ui().canEdit,false);
  const invitationId=a.ui().invite.id,b=harness({service,tab:new Map([[CORE_KEY,tokens.bob]]),mode:true,route:{invitation:invitationId,mode:'account'}});
  await b.start();assert.equal(b.ui().world,null);assert.equal(b.current().objects.length,0);
  assert.equal(await b.controller.transition('accept'),'committed');assert.equal(b.ui().world.id,worldId);assert.equal(b.ui().canEdit,true);
  b.place('light');assert.equal(await b.controller.saveGeneration('Second keeper'),'committed');
  await a.controller.refresh();assert.equal(a.ui().world.role,'reader');assert.equal(a.ui().canEdit,false);
  const before=a.current();a.place();assert.deepEqual(a.current(),before);
  const note=a.ui().notifications.find(n=>n.kind==='generation_created');assert.ok(note);
  await a.controller.openNotification(note.id);assert.equal(a.snapshot.generation,2);assert.equal(a.snapshot.objects.length,2);
  await a.controller.viewGeneration(1);assert.deepEqual(a.snapshot.objects,first.objects);
  assert.deepEqual(service.worlds.get(worldId).generations[0],first);
  assert.notEqual(service.notifications.find(n=>n.id===note.id).readAt,null);
  assert.equal(a.operations().length,0);assert.equal(b.operations().length,0);
 });
 await check('local baseline and pending suffix transfer separately; original local state stays byte-identical',async()=>{
  const local={...emptyLocal(),objects:[{tool:'stone',x:20,y:30},{tool:'light',x:50,y:40}],pending:[{type:'light',x:50,y:40}],changes:['light'],budget:99,
   history:[{generation:173,by:'@Fiction',action:'Unverified',when:'Yesterday'}]};
  const h=harness({local});await h.account();assert.equal(await h.controller.createWorld('local-copy','Private copy'),'committed');
  const createCall=h.posts()[0];assert.deepEqual(createCall.body.objects,[{type:'stone',x:20,y:30}]);
  assert.equal(h.ui().world.currentGeneration,1);assert.equal(h.ui().world.generations.length,0);assert.equal(h.current().pending.length,1);
  await h.controller.saveGeneration('First confirmed trace');assert.equal(h.ui().world.objects.length,2);
  assert.deepEqual(h.ui().world.generations[0].delta,[{type:'light',x:50,y:40}]);
  await h.controller.selectMode(false);assert.deepEqual(h.current(),local);
 });
 await check('inconsistent or oversized local import never sends create or overwrites the local save',async()=>{
  const local={...emptyLocal(),pending:[{type:'tree',x:50,y:40}],budget:99,changes:['tree']},h=harness({local});
  await h.account();await h.controller.createWorld('local-copy','Copy');assert.equal(h.posts().length,0);
  await h.controller.selectMode(false);assert.deepEqual(h.current(),local);
 });
 await check('lost committed create is recovered only by GET after reload, including the carried draft',async()=>{
  const local={...emptyLocal(),objects:[{tool:'tree',x:50,y:40}],pending:[{type:'tree',x:50,y:40}],changes:['tree'],budget:99};
  const service=serviceFixture(),data=new Map(),a=harness({service,data,local,handler:async(call,h)=>{
   if(call.method==='POST'&&call.path===API+'worlds'){service.handle(call);throw Error('response lost')}
  }});
  await a.account();assert.equal(await a.controller.createWorld('local-copy','Lost reply'),'uncertain');
  const key=a.operations()[0].value.key;assert.equal(service.worlds.size,1);
  const b=harness({service,data,local,mode:true});await b.start();assert.equal(b.posts().length,0);
  assert.equal(await b.controller.recover(key),'committed');assert.equal(b.current().pending.length,1);assert.equal(b.current().objects.length,1);
  assert.equal(b.posts().length,0);assert.equal(b.operations().length,0);
 });
 await check('unknown operation 404 stays journaled and prevents another POST',async()=>{
  const h=harness({handler:async call=>{if(call.method==='POST')throw Error('lost before fixture')}});
  await h.account();await h.controller.createWorld('template','Unknown');const key=h.operations()[0].value.key;
  assert.equal(await h.controller.recover(key),'uncertain');await h.controller.createWorld('template','No retry');
  assert.equal(h.posts().length,1);assert.equal(h.operations()[0].value.key,key);
 });
 await check('double save and placement while a request is pending cannot alter its captured generation',async()=>{
  const h=harness();await create(h);h.place();const held=deferred();h.handler=async call=>call.method==='POST'?held.promise:undefined;
  const before=h.current(),first=h.controller.saveGeneration('Held');await h.flush();
  h.place('stone');await h.controller.saveGeneration('Again');assert.deepEqual(h.current(),before);assert.equal(h.posts().length,2);
  const call=h.posts().at(-1);held.resolve(response(h.service.handle(call)));assert.equal(await first,'committed');
  assert.equal(h.current().history.length,1);assert.equal(h.current().objects.length,1);assert.equal(h.current().pending.length,0);
 });
 await check('whole request deadline covers a held response body and ignores its late success',async()=>{
  const h=harness();await create(h);h.place();const body=deferred();
  h.handler=async call=>call.method==='POST'?{ok:true,status:200,headers:{get:()=> 'application/json'},json:()=>body.promise}:undefined;
  const pending=h.controller.saveGeneration('Timeout');await h.flush();await h.advance(12000);
  assert.equal(await pending,'uncertain');const before=h.current();const call=h.posts().at(-1);
  body.resolve(h.service.handle(call).body);await h.flush();assert.deepEqual(h.current(),before);assert.equal(h.operations().length,1);
  h.handler=null;assert.equal(await h.controller.recover(h.operations()[0].value.key),'committed');assert.equal(h.current().pending.length,0);
 });
 await check('account switch during POST keeps the original account journal and cannot expose it to another account',async()=>{
  const h=harness();await create(h);h.place();const held=deferred();h.handler=async call=>call.method==='POST'?held.promise:undefined;
  const save=h.controller.saveGeneration('Switch');await h.flush();const call=h.posts().at(-1);
  h.tab.set(CORE_KEY,tokens.bob);held.resolve(response(h.service.handle(call)));assert.equal(await save,'ignored');
  assert.equal(h.ui().account,null);assert.equal(h.ui().canEdit,false);assert.equal(h.operations()[0].value.accountId,ids.alice);
  h.handler=null;await h.controller.verify();assert.equal(h.ui().account.id,ids.bob);assert.equal(h.ui().pending.length,0);assert.equal(h.operations().length,1);
 });
 await check('revocation stops protected placement and never sends a legacy or anonymous world request',async()=>{
  const h=harness();await create(h);h.service.revoked.add('alice');await h.controller.refresh();
  const before=h.current();h.place();assert.deepEqual(h.current(),before);assert.equal(h.ui().account,null);
  assert.ok(h.calls.every(call=>call.path.startsWith(API)||call.path==='/api/core/auth/me'));
 });
 await check('a conflict preserves exact pending data and requires explicit current-version selection',async()=>{
  const h=harness();const id=await create(h);h.place();const before=h.current();
  h.service.worlds.get(id).revision++;assert.equal(await h.controller.saveGeneration('Conflict'),'rejected');
  assert.deepEqual(h.current(),before);assert.equal(h.operations().length,0);assert.equal(h.ui().canEdit,false);
  await h.controller.refresh();assert.equal(h.ui().draftConflict,true);assert.equal(h.current().pending.length,1);
  h.controller.showCurrent();assert.equal(h.current().pending.length,0);assert.equal(h.drafts()[0].value.pending.length,1);
 });
 await check('historic operation custody never enables editing before a fresh world GET',async()=>{
  const service=serviceFixture(),h=harness({service});const id=await create(h);h.place();
  h.handler=async call=>{if(call.method==='POST'&&call.path.endsWith('/generations')){service.handle(call);throw Error('lost')}};
  await h.controller.saveGeneration('Historical');const key=h.operations()[0].value.key;
  service.worlds.get(id).custodian=ids.bob;service.worlds.get(id).members.add(ids.bob);service.worlds.get(id).revision++;
  h.handler=null;assert.equal(await h.controller.recover(key),'committed');
  assert.equal(h.ui().world.role,'reader');assert.equal(h.ui().canEdit,false);
  const recovery=h.calls.findIndex(call=>call.path===API+'operations/'+key);
  assert.ok(h.calls.slice(recovery+1).some(call=>call.method==='GET'&&call.path===API+'worlds/'+id));
 });
 await check('storage refusal before intent durability sends no POST',async()=>{
  const h=harness();await h.account();h.writeHook=key=>key.startsWith('osgard:inherit-operation:');
  await h.controller.createWorld('template','No persistence');assert.equal(h.posts().length,0);assert.equal(h.ui().status,'storage');
 });
 await check('malformed operation scan fails closed without dropping the unknown record',async()=>{
  const h=harness();await h.account();const key='osgard:inherit-operation:v1:'+encodeURIComponent('https://osgard.world'+API)+':'+ids.alice+':malformed';h.data.set(key,'{broken');
  await h.controller.createWorld('template','No overwrite');assert.equal(h.posts().length,0);assert.equal(h.data.get(key),'{broken');
 });
 await check('ready create keeps its operation if writing the carried draft fails, then GET recovery preserves that draft',async()=>{
  const local={...emptyLocal(),objects:[{tool:'tree',x:50,y:40}],pending:[{type:'tree',x:50,y:40}],changes:['tree'],budget:99};
  const h=harness({local});await h.account();h.writeHook=key=>key.startsWith('osgard:inherit-draft:');
  assert.equal(await h.controller.createWorld('local-copy','Carry'),'uncertain');assert.equal(h.operations().length,1);
  h.writeHook=null;assert.equal(await h.controller.recover(h.operations()[0].value.key),'committed');assert.equal(h.current().pending.length,1);assert.equal(h.posts().length,1);
 });
 await check('pagehide and a mode switch never overwrite pending operation or draft records',async()=>{
  const h=harness();await create(h);h.place();h.handler=async call=>{if(call.method==='POST')throw Error('lost')};
  await h.controller.saveGeneration('Persist');const before=[...h.data];
  h.controller.leave();assert.deepEqual([...h.data],before);await h.controller.selectMode(false);assert.deepEqual([...h.data],before);assert.deepEqual(h.current(),emptyLocal());
 });
 await check('two documents keep their independent drafts; one accepted generation cannot delete the other draft',async()=>{
  const service=serviceFixture(),data=new Map(),a=harness({service,data});const id=await create(a);
  const b=harness({service,data,mode:true,route:{world:id}});await b.start();a.place('tree');b.place('stone');
  assert.equal(a.drafts().length,2);const other=a.drafts().find(row=>row.value.pending[0].type==='stone');
  assert.equal(await a.controller.saveGeneration('A'),'committed');
  assert.ok(data.has(other.key));assert.deepEqual(JSON.parse(data.get(other.key)).pending,[{type:'stone',x:50,y:40}]);
  await b.controller.refresh();assert.equal(b.ui().draftConflict,true);assert.equal(b.ui().canEdit,false);
 });
 await check('another document’s uncertain intent blocks a new POST without overwriting its key',async()=>{
  const service=serviceFixture(),data=new Map(),a=harness({service,data});await a.account();
  const b=harness({service,data});await b.account();a.handler=async call=>{if(call.method==='POST')throw Error('lost')};
  await a.controller.createWorld('template','A');const saved=a.operations()[0];await b.controller.createWorld('template','B');
  assert.equal(b.posts().length,0);assert.equal(data.get(saved.key),JSON.stringify(saved.value));
 });
 await check('declining grants no world contents; cancelling restores the current custodian',async()=>{
  const service=serviceFixture(),a=harness({service});await create(a);await generationOne(a);await a.controller.offer(ids.bob,true);
  const b=harness({service,tab:new Map([[CORE_KEY,tokens.bob]]),mode:true,route:{invitation:a.ui().invite.id}});await b.start();
  assert.equal(await b.controller.transition('decline'),'committed');assert.equal(b.ui().world,null);assert.equal(b.current().objects.length,0);
  await a.controller.refresh();assert.equal(a.ui().canEdit,true);await a.controller.offer(ids.bob,true);
  assert.equal(await a.controller.transition('cancel'),'committed');assert.equal(a.ui().canEdit,true);
 });
 await check('offer requires a saved generation, exact target and explicit sharing acknowledgement',async()=>{
  const h=harness();await create(h);await h.controller.offer(ids.bob,true);assert.equal(h.posts().length,1);
  await generationOne(h);await h.controller.offer(ids.bob,false);await h.controller.offer(ids.alice,true);await h.controller.offer('bob',true);
  assert.equal(h.posts().length,2);
 });
 await check('tokens are confined to fixed Core fetch headers and absent from saved records, exports and URLs',async()=>{
  const h=harness();await create(h);h.place();await h.controller.exportDraft();
  for(const call of h.calls){assert.ok(call.url.startsWith('https://osgard.world/api/core/'));assert.equal(call.credentials,'omit');assert.equal(call.redirect,'error');assert.equal(call.cache,'no-store');assert.equal(call.headers.authorization,'Bearer '+tokens.alice)}
  const stored=JSON.stringify([...h.data])+JSON.stringify(h.downloads);
  for(const token of Object.values(tokens))assert.equal(stored.includes(token),false);
 });
 await check('an inaccessible session store cannot reuse a guessed or previous credential',async()=>{
  const h=harness();h.denySession=true;await h.account();assert.equal(h.calls.length,0);assert.equal(h.ui().account,null);
 });
 await check('a quota-only memory draft survives verify, local return, account re-entry and later durable recovery',async()=>{
  const h=harness();await create(h);h.denyWrite=true;h.place('light');assert.equal(h.current().pending.length,1);assert.equal(h.drafts().length,0);
  await h.controller.verify();assert.equal(h.current().pending.length,1);assert.equal(h.current().pending[0].type,'light');
  await h.controller.exportDraft();assert.equal(h.downloads.at(-1).value.state.pending.length,1);
  await h.controller.selectMode(false);assert.deepEqual(h.current(),emptyLocal());
  await h.controller.selectMode(true);assert.equal(h.current().pending.length,1);
  h.denyWrite=false;await h.controller.verify();assert.equal(h.current().pending.length,1);assert.equal(h.drafts().length,1);
  assert.equal(await h.controller.saveGeneration('Recovered memory draft'),'committed');assert.equal(h.current().objects.length,1);
 });
 await check('forking a loaded foreign draft cannot delete that document’s later edit',async()=>{
  const service=serviceFixture(),data=new Map(),a=harness({service,data});const id=await create(a);a.place('tree');
  const original=a.drafts()[0].key,b=harness({service,data,mode:true,route:{world:id}});await b.start();
  assert.equal(b.current().pending.length,1);a.place('light');b.place('stone');
  assert.deepEqual(JSON.parse(data.get(original)).pending.map(item=>item.type),['tree','light']);
  assert.equal(a.drafts().length,2);assert.deepEqual(a.drafts().find(row=>row.key!==original).value.pending.map(item=>item.type),['tree','stone']);
 });
 await check('a stale 401 from Alice’s invitation cannot log out a newly verified Bob session',async()=>{
  const h=harness();await create(h);await generationOne(h);await h.controller.offer(ids.bob,true);
  const id=h.ui().invite.id,held=deferred();
  h.handler=async call=>call.path===API+'handoffs/'+id&&call.headers.authorization==='Bearer '+tokens.alice?held.promise:undefined;
  const older=h.controller.openInvitation(id);await h.flush();h.tab.set(CORE_KEY,tokens.bob);await h.controller.verify();
  assert.equal(h.ui().account.id,ids.bob);held.resolve(response(error('authentication_required',401)));
  assert.equal(await older,'ignored');assert.equal(h.ui().account.id,ids.bob);assert.notEqual(h.ui().status,'session_expired');
 });
 await check('reload recovery ignores a fully covered old foreign draft without deleting its mutable slot',async()=>{
  const service=serviceFixture(),data=new Map(),a=harness({service,data});const id=await create(a);a.place('tree');const oldDraft=a.drafts()[0];
  a.handler=async call=>{if(call.method==='POST'&&call.path.endsWith('/generations')){service.handle(call);throw Error('lost')}};
  await a.controller.saveGeneration('Committed once');const key=a.operations()[0].value.key;
  const b=harness({service,data,mode:true,route:{world:id}});await b.start();assert.equal(await b.controller.recover(key),'committed');
  assert.equal(b.current().pending.length,0);assert.equal(b.current().objects.length,1);assert.equal(b.ui().canEdit,true);
  assert.ok(data.has(oldDraft.key),'foreign mutable slot remains intact');
  assert.equal(b.ui().drafts.length,0,'fresh immutable history proves these exact old contents were committed');
 });
 await check('world selection during a held POST ignores success and 401, preserves its journal and unlocks navigation',async()=>{
  for(const outcome of ['committed','unauthorized']){
   const h=harness(),first=await create(h);h.place('tree');
   await h.controller.createWorld('template','Second world');const second=h.ui().world.id;await h.controller.loadWorld(first);
   const held=deferred();h.handler=async call=>call.method==='POST'?held.promise:undefined;
   const saving=h.controller.saveGeneration('Held selection');await h.flush();const call=h.posts().at(-1),saved=h.operations()[0];
   await h.controller.loadWorld(second);const before=h.current();
   held.resolve(response(outcome==='committed'?h.service.handle(call):error('authentication_required',401)));
   assert.equal(await saving,'ignored');assert.equal(h.ui().world.id,second);assert.deepEqual(h.current(),before);
   assert.equal(h.ui().account.id,ids.alice);assert.equal(h.ui().busy,false);assert.equal(h.data.get(saved.key),JSON.stringify(saved.value));
   assert.equal(h.ui().pending.length,1);h.handler=null;
   if(outcome==='committed'){
    const posts=h.posts().length;assert.equal(await h.controller.recover(saved.value.key),'committed');
    assert.equal(h.ui().world.id,first);assert.equal(h.current().pending.length,0);assert.equal(h.posts().length,posts);
   }
  }
 });
 await check('held GET-only recovery cannot replace a newly selected world or expire its session',async()=>{
  for(const outcome of ['committed','unauthorized']){
   const h=harness(),first=await create(h);await h.controller.createWorld('template','Second');const second=h.ui().world.id;
   await h.controller.loadWorld(first);h.place();
   h.handler=async call=>{if(call.method==='POST'){h.service.handle(call);throw Error('lost')}};
   await h.controller.saveGeneration('Recover after navigation');const saved=h.operations()[0],held=deferred();
   h.handler=async call=>call.path===API+'operations/'+saved.value.key?held.promise:undefined;
   const recovering=h.controller.recover(saved.value.key);await h.flush();const call=h.calls.at(-1);
   await h.controller.loadWorld(second);const before=h.current(),posts=h.posts().length;
   held.resolve(response(outcome==='committed'?h.service.handle(call):error('authentication_required',401)));
   assert.equal(await recovering,'ignored');assert.equal(h.ui().world.id,second);assert.deepEqual(h.current(),before);
   assert.equal(h.ui().account.id,ids.alice);assert.equal(h.ui().busy,false);assert.equal(h.data.get(saved.key),JSON.stringify(saved.value));
   h.handler=null;assert.equal(await h.controller.recover(saved.value.key),'committed');assert.equal(h.posts().length,posts);
  }
 });
 await check('a held invitation refresh after an operation’s own world GET stays bound to that selection',async()=>{
  for(const outcome of ['committed','unauthorized']){
   const h=harness(),first=await create(h);await generationOne(h);
   await h.controller.createWorld('template','Second');const second=h.ui().world.id;await h.controller.loadWorld(first);
   const held=deferred();h.handler=async call=>call.method==='GET'&&call.path.startsWith(API+'handoffs/')?held.promise:undefined;
   const offering=h.controller.offer(ids.bob,true);await h.flush();const call=h.calls.at(-1),saved=h.operations()[0];
   assert.ok(call.path.startsWith(API+'handoffs/'));await h.controller.loadWorld(second);
   held.resolve(response(outcome==='committed'?h.service.handle(call):error('authentication_required',401)));
   assert.equal(await offering,'ignored');assert.equal(h.ui().world.id,second);assert.equal(h.ui().invite,null);
   assert.equal(h.ui().account.id,ids.alice);assert.equal(h.ui().busy,false);assert.equal(h.data.get(saved.key),JSON.stringify(saved.value));
   const posts=h.posts().length;h.handler=null;assert.equal(await h.controller.recover(saved.value.key),'committed');
   assert.equal(h.ui().world.id,first);assert.equal(h.ui().invite.to.id,ids.bob);assert.equal(h.posts().length,posts);
  }
 });
 await check('notification navigation superseded by another world never opens its generation or marks it read',async()=>{
  const h=harness(),first=await create(h);await generationOne(h);await h.controller.createWorld('template','Second');const second=h.ui().world.id;
  const note={userId:ids.alice,id:800,kind:'generation_created',worldId:first,invitationId:null,generation:1,actor:{id:ids.bob,username:'bob'},createdAt:stamp,readAt:null};
  h.service.notifications.push(note);await h.controller.refresh();const held=deferred();
  h.handler=async call=>call.method==='GET'&&call.path===API+'worlds/'+first?held.promise:undefined;
  const opening=h.controller.openNotification(note.id);await h.flush();const call=h.calls.at(-1),posts=h.posts().length;
  await h.controller.loadWorld(second);held.resolve(response(h.service.handle(call)));assert.equal(await opening,false);
  assert.equal(h.ui().world.id,second);assert.equal(h.snapshot,undefined);assert.equal(note.readAt,null);assert.equal(h.posts().length,posts);
 });
 console.log('SUMMARY '+passed+' PASS / 0 FAIL. Shipped account controller and placement handler; in-memory transport only. No browser or live persistence asserted.');
}
if(process.argv[1]&&pathToFileURL(process.argv[1]).href===import.meta.url)await suite();
