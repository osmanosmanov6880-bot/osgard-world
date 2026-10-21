/* Private INHERIT worlds. Credentials stay in the Core tab session; journals never contain them. */
(()=>{
'use strict';
const PREFIX='/api/core/inherit/v1/', CORE_KEY='osgard:core-session:v1';
const ID=/^[a-f0-9]{32}$/, KEY=/^[A-Za-z0-9_-]{16,100}$/, HASH=/^[a-f0-9]{64}$/;
const TYPES=new Set(['tree','stone','light','path','flower','arch','chime','moss','cairn','marker']);
const clone=value=>JSON.parse(JSON.stringify(value));
const equal=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
const record=value=>value!==null&&typeof value==='object'&&!Array.isArray(value);
class AccountError extends Error{constructor(code,status=0){super(code);this.code=code;this.status=status}}
function need(condition,code='invalid_response'){if(!condition)throw new AccountError(code)}
function person(value){return record(value)&&ID.test(value.id)&&typeof value.username==='string'&&/^[a-z0-9_.-]{3,64}$/.test(value.username)}
function marks(value,max=1024,min=0){
 return Array.isArray(value)&&value.length>=min&&value.length<=max&&value.every(item=>record(item)&&TYPES.has(item.type)&&Number.isFinite(item.x)&&Number.isFinite(item.y)&&item.x>=0&&item.x<=100&&item.y>=0&&item.y<=100);
}
function typed(items){return items.map(item=>({type:item.type||item.tool,x:item.x,y:item.y}))}
function invitation(value){
 return record(value)&&ID.test(value.id)&&ID.test(value.worldId)&&typeof value.worldTitle==='string'&&value.worldTitle.length<=120
  &&person(value.from)&&person(value.to)&&value.from.id!==value.to.id
  &&['pending','accepted','cancelled','declined','expired'].includes(value.status)
  &&Number.isSafeInteger(value.expectedRevision)&&value.expectedRevision>0&&typeof value.expiresAt==='string';
}
function generation(value){
 return record(value)&&Number.isSafeInteger(value.number)&&value.number>=1&&value.number<=128&&person(value.author)
  &&typeof value.message==='string'&&value.message.length<=1000&&marks(value.delta,100,1)
  &&typeof value.createdAt==='string'&&HASH.test(value.snapshotHash)&&HASH.test(value.parentHash);
}
function validWorld(value,accountId,summary=false){
 if(!record(value)||!ID.test(value.id)||typeof value.title!=='string'||!value.title.length||value.title.length>120
  ||value.template!=='quiet-reach-v1'||!['template','local-copy'].includes(value.source)
  ||value.sourceVerified!==(value.source==='template')||!person(value.creator)||!person(value.custodian)
  ||value.role!==(value.custodian.id===accountId?'custodian':'reader')
  ||typeof value.canEdit!=='boolean'||typeof value.canOfferHandoff!=='boolean'
  ||!Number.isSafeInteger(value.revision)||value.revision<1
  ||!Number.isSafeInteger(value.currentGeneration)||value.currentGeneration<1||value.currentGeneration>129
  ||!HASH.test(value.baselineHash)||!HASH.test(value.snapshotHash)
  ||!(value.pendingHandoff===null||invitation(value.pendingHandoff)&&value.pendingHandoff.worldId===value.id
    &&value.pendingHandoff.from.id===value.custodian.id&&value.pendingHandoff.status==='pending'
    &&value.pendingHandoff.expectedRevision===value.revision)
  ||value.canEdit!==(value.role==='custodian'&&value.pendingHandoff===null)
  ||value.canOfferHandoff&&(!value.canEdit||value.currentGeneration<2))return false;
 if(summary)return true;
 if(!marks(value.objects)||!Array.isArray(value.generations)||value.generations.length!==value.currentGeneration-1
  ||!value.generations.every((item,index)=>generation(item)&&item.number===index+1))return false;
 const deltas=value.generations.flatMap(item=>item.delta);
 return deltas.length<=value.objects.length&&equal(value.objects.slice(value.objects.length-deltas.length),deltas);
}
function notification(value){
 return record(value)&&Number.isSafeInteger(value.id)&&value.id>0&&ID.test(value.worldId)
  &&(value.invitationId===null||ID.test(value.invitationId))
  &&(value.generation===null||Number.isSafeInteger(value.generation)&&value.generation>0&&value.generation<=128)
  &&person(value.actor)&&['generation_created','handoff_offered','handoff_accepted','handoff_declined','handoff_cancelled'].includes(value.kind)
  &&typeof value.createdAt==='string'&&(value.readAt===null||typeof value.readAt==='string');
}
function createController(options){
 const game=options.game,view=options.view||{render(){}},storage=options.storage,session=options.session;
 const origin=options.origin,api=origin+PREFIX,fetcher=options.fetch,uuid=options.uuid;
 const now=options.now||Date.now,delay=options.setTimeout||setTimeout,cancel=options.clearTimeout||clearTimeout;
 const documentId=uuid(), requests=new Set(),memoryDrafts=new Map();
 let mode=game.accountMode(),account=null,credential='',epoch=0,selection=0;
 let world=null,worldVerified=false,selectedId='',invite=null,worlds=[],notifications=[];
 let capabilities=null,busy=null,loading=false,status='local_mode',storageFailed=false;
 let draft=null,drafts=[],draftConflict=false,choiceRequired=false,pending=[];
 let currentDraftRaw=null,ownDraftId=null,localCopy=game.localSnapshot();
 const opRoot='osgard:inherit-operation:v1:'+encodeURIComponent(api)+':';
 const draftRoot='osgard:inherit-draft:v1:'+encodeURIComponent(api)+':';
 const pointerRoot='osgard:inherit-last-world:v1:'+encodeURIComponent(api)+':';
 function readToken(){try{return session.getItem(CORE_KEY)||''}catch{throw new AccountError('session_storage')}}
 function current(ticket){
  if(!mode||ticket.epoch!==epoch||ticket.accountId!==account?.id||ticket.credential!==credential)return false;
  try{if(readToken()===credential)return true}catch{}
  pause('session_changed');return false;
 }
 function ticket(){return {epoch,accountId:account?.id,credential,selection}}
 function currentSelection(context){return current(context)&&context.selection===selection}
 function clearRequests(){for(const controller of requests)controller.abort();requests.clear()}
 function pause(reason){
  epoch++;selection++;clearRequests();credential='';account=null;worldVerified=false;loading=false;busy=null;
  status=reason;game.busy(false);render();
 }
 function authenticated(){
  if(!mode||!account||!credential)return false;
  try{if(readToken()===credential)return true}catch{}
  pause('session_changed');return false;
 }
 function fail(error){
  if(error?.status===401)pause('session_expired');
  else{status=error?.code||'unavailable';if(['storage','session_storage'].includes(status))storageFailed=true;render()}
  return 'failed';
 }
 function get(key){try{return storage.getItem(key)}catch{throw new AccountError('storage')}}
 function write(key,value){
  const raw=JSON.stringify(value);
  try{storage.setItem(key,raw);need(storage.getItem(key)===raw,'storage');return raw}catch{throw new AccountError('storage')}
 }
 function removeExact(key,raw){
  try{if(storage.getItem(key)!==raw)return false;storage.removeItem(key);need(storage.getItem(key)===null,'storage');return true}catch{throw new AccountError('storage')}
 }
 function scan(prefix){
  try{
   const count=storage.length;need(Number.isSafeInteger(count)&&count<=10000,'storage');
   const found=[];
   for(let index=0;index<count;index++){const key=storage.key(index);if(typeof key==='string'&&key.startsWith(prefix)){const raw=storage.getItem(key);need(typeof raw==='string'&&raw.length<=500000,'storage');found.push({key,raw,value:JSON.parse(raw)})}}
   return found;
  }catch{throw new AccountError('storage')}
 }
 function draftKey(value){return draftRoot+value.accountId+':'+value.worldId+':'+value.id}
 function opKey(value){return opRoot+value.accountId+':'+value.key}
 function validDraft(value){
  return record(value)&&value.version===1&&value.api===api&&ID.test(value.accountId)&&ID.test(value.worldId)&&KEY.test(value.id)
   &&typeof value.documentId==='string'&&Number.isSafeInteger(value.baseRevision)&&value.baseRevision>0
   &&Number.isSafeInteger(value.baseGeneration)&&value.baseGeneration>0&&value.baseGeneration<=129
   &&HASH.test(value.baseHash)&&marks(value.baseObjects)&&marks(value.pending,100)
   &&value.baseObjects.length+value.pending.length<=1024&&Number.isSafeInteger(value.updatedAt);
 }
 function routeFor(value){
  if(value.kind==='create')return 'worlds';
  if(value.kind==='generation')return 'worlds/'+value.worldId+'/generations';
  if(value.kind==='offer')return 'worlds/'+value.worldId+'/handoffs';
  if(['accept','cancel','decline'].includes(value.kind))return 'handoffs/'+value.invitationId+'/'+value.kind;
  if(value.kind==='notification_read')return 'notifications/'+value.notificationId+'/read';
  return '';
 }
 function validOperation(value){
  if(!record(value)||value.version!==1||value.api!==api||!ID.test(value.accountId)||!KEY.test(value.key)
   ||!record(value.body)||!Number.isSafeInteger(value.createdAt)||value.path!==routeFor(value)||!value.path
   ||!(value.worldId===null||ID.test(value.worldId))||!(value.invitationId===null||ID.test(value.invitationId)))return false;
  const b=value.body;
  if(value.kind==='create')return Object.keys(b).sort().join(',')==='objects,source,template,title'
   &&b.template==='quiet-reach-v1'&&['template','local-copy'].includes(b.source)&&marks(b.objects)
   &&typeof b.title==='string'&&b.title.length>0&&b.title.length<=120
   &&(b.source!=='template'||b.objects.length===0)&&marks(value.carry,100)&&b.objects.length+value.carry.length<=1024;
  if(value.kind==='generation')return ID.test(value.worldId)&&Object.keys(b).sort().join(',')==='delta,expectedGeneration,expectedRevision,message'
   &&Number.isSafeInteger(b.expectedRevision)&&b.expectedRevision>0&&Number.isSafeInteger(b.expectedGeneration)&&b.expectedGeneration>0
   &&typeof b.message==='string'&&b.message.length>0&&b.message.length<=1000&&marks(b.delta,100,1)
   &&record(value.draft)&&validDraft(value.draft)&&value.draft.accountId===value.accountId&&value.draft.worldId===value.worldId
   &&value.draft.baseRevision===b.expectedRevision&&value.draft.baseGeneration===b.expectedGeneration&&equal(value.draft.pending,b.delta);
  if(value.kind==='offer')return ID.test(value.worldId)&&Object.keys(b).sort().join(',')==='expectedRevision,sharingAcknowledged,targetUserId'
   &&Number.isSafeInteger(b.expectedRevision)&&b.expectedRevision>0&&ID.test(b.targetUserId)&&b.targetUserId!==value.accountId&&b.sharingAcknowledged===true;
  if(['accept','cancel','decline'].includes(value.kind))return ID.test(value.invitationId)&&Object.keys(b).join(',')==='expectedRevision'&&Number.isSafeInteger(b.expectedRevision)&&b.expectedRevision>0;
  return value.kind==='notification_read'&&Number.isSafeInteger(value.notificationId)&&value.notificationId>0&&Object.keys(b).length===0;
 }
 function readOperations(){
  need(account,'sign_in');
  const values=scan(opRoot+account.id+':');
  for(const row of values)need(validOperation(row.value)&&row.value.accountId===account.id&&row.key===opKey(row.value),'storage');
  return values;
 }
 function readDrafts(worldId){
  const values=scan(draftRoot+account.id+':'+worldId+':');
  for(const row of values)need(validDraft(row.value)&&row.value.accountId===account.id&&row.value.worldId===worldId&&row.key===draftKey(row.value),'storage');
  return values.filter(row=>row.value.pending.length&&!coveredDraft(row.value)).sort((a,b)=>b.value.updatedAt-a.value.updatedAt||a.key.localeCompare(b.key));
 }
 function coveredDraft(value){
  // A foreign tab's slot remains untouched. An authoritative immutable generation may
  // establish that its exact old contents are already committed; a later edit won't match.
  if(!worldVerified||world?.id!==value.worldId)return false;
  const entry=world.generations.find(item=>item.number===value.baseGeneration);
  if(!entry||entry.author.id!==value.accountId||entry.parentHash!==value.baseHash||!equal(entry.delta,value.pending))return false;
  const prefix=world.objects.length-world.generations.filter(item=>item.number>entry.number).flatMap(item=>item.delta).length;
  return equal(world.objects.slice(0,prefix),value.baseObjects.concat(value.pending));
 }
 function refreshJournals(){pending=readOperations();storageFailed=!!memoryDrafts.get(account.id+':'+selectedId)}
 function mutationAllowed(){
  if(!authenticated()){status='sign_in';render();return false}
  if(busy||loading){status='working';render();return false}
  try{refreshJournals()}catch(error){fail(error);return false}
  if(pending.length){status='check_operation';render();return false}
  return true;
 }
 function canEdit(){
  return mode&&!!account&&worldVerified&&world?.canEdit===true&&!busy&&!loading&&!draftConflict&&!choiceRequired&&!storageFailed&&!pending.length;
 }
 function blockMutation(action){
  if(!mode)return false;
  if(!authenticated()){status='sign_in';render();return true}
  try{refreshJournals()}catch(error){fail(error);return true}
  if(!canEdit()){status=pending.length?'check_operation':draftConflict?'draft_conflict':choiceRequired?'choose_draft':'read_only';render();return true}
  if(action==='place'&&game.snapshot().objects.length>=1024||world.currentGeneration>128){status='world_limit';render();return true}
  return false;
 }
 async function json(path,{method='GET',body,key,token=credential}={}){
  need(path==='/api/core/auth/me'&&method==='GET'||path.startsWith(PREFIX)&&/^(capabilities|worlds|notifications|worlds\/[a-f0-9]{32}(?:\/(?:generations(?:\/[1-9][0-9]{0,2})?|handoffs))?|handoffs\/[a-f0-9]{32}(?:\/(?:accept|cancel|decline))?|operations\/[A-Za-z0-9_-]{16,100}|notifications\/[1-9][0-9]{0,17}\/read)$/.test(path.slice(PREFIX.length)),'invalid_route');
  need(typeof token==='string'&&token.length>0&&token.length<=8192,'sign_in');
  const url=new URL(path,origin);need(url.origin===origin&&!url.search&&!url.hash&&!url.username&&!url.password,'invalid_route');
  const controller=new AbortController();requests.add(controller);
  let timer;const expires=now()+12000;
  try{
   return await Promise.race([(async()=>{
    const response=await fetcher(url.href,{method,headers:{Accept:'application/json',Authorization:'Bearer '+token,...(body!==undefined?{'Content-Type':'application/json'}:{}),...(key?{'Idempotency-Key':key}:{})},...(body!==undefined?{body:JSON.stringify(body)}:{}),credentials:'omit',cache:'no-store',redirect:'error',signal:controller.signal});
    if(response.headers?.get&&!(response.headers.get('content-type')||'').includes('application/json'))throw new AccountError('invalid_response');
    const value=await response.json();need(now()<expires,'timeout');need(record(value)&&JSON.stringify(value).length<=2000000);
    if(!response.ok){need(typeof value.error==='string'&&typeof value.message==='string');throw new AccountError(value.error,response.status)}
    return value;
   })(),new Promise((_,reject)=>{timer=delay(()=>{reject(new AccountError('timeout'));controller.abort()},12000)})]);
  }finally{cancel(timer);requests.delete(controller)}
 }
 function snapshotState(base,selectedDraft=null){
  const pendingMarks=selectedDraft?.pending||[],objects=(selectedDraft?.baseObjects||base.objects).concat(pendingMarks);
  return {generation:selectedDraft?.baseGeneration||base.currentGeneration,budget:100-pendingMarks.length,
   objects:objects.map(item=>({tool:item.type,x:item.x,y:item.y})),pending:clone(pendingMarks),
   changes:pendingMarks.map(item=>item.type),history:base.generations.map(item=>({generation:item.number,by:'@'+item.author.username,action:item.message,when:item.createdAt})),snapshots:[]};
 }
 function installDraft(row){
  draft=row?clone(row.value):null;currentDraftRaw=row?.raw||null;ownDraftId=draft?.documentId===documentId?draft.id:null;
  choiceRequired=false;
  draftConflict=!!draft&&(draft.baseRevision!==world.revision||draft.baseGeneration!==world.currentGeneration||draft.baseHash!==world.snapshotHash||!equal(draft.baseObjects,world.objects));
  game.apply(snapshotState(world,draft));render();
 }
 function saveDraft(){
  if(!mode||!authenticated()||!worldVerified||!world)return false;
  try{
   const snapshot=game.snapshot(),traces=typed(snapshot.pending||[]);
   need(marks(traces,100)&&snapshot.generation===(draft?.baseGeneration||world.currentGeneration),'invalid_draft');
   const base=draft?.baseObjects||world.objects;
   need(equal(typed(snapshot.objects),base.concat(traces)),'invalid_draft');
   const previous=draft&&{key:draftKey(draft),raw:currentDraftRaw};
   const value={version:1,api,accountId:account.id,worldId:world.id,id:ownDraftId||uuid(),documentId,
    baseRevision:draft?.baseRevision||world.revision,baseGeneration:draft?.baseGeneration||world.currentGeneration,
    baseHash:draft?.baseHash||world.snapshotHash,baseObjects:clone(base),pending:traces,updatedAt:now()};
   need(validDraft(value),'invalid_draft');
   memoryDrafts.set(account.id+':'+world.id,clone(value));
   const all=readDrafts(world.id);
   need(all.length<32||all.some(row=>row.key===draftKey(value)),'draft_limit');
   if(previous&&previous.key===draftKey(value)&&get(previous.key)!==previous.raw){value.id=uuid();ownDraftId=null}
   // Keep the only copy even if persistent storage refuses this edit.
   memoryDrafts.set(account.id+':'+world.id,clone(value));
   const raw=write(draftKey(value),value);
   // Other documents own mutable slots. A read/remove pair is not a cross-tab CAS.
   if(previous&&draft.documentId===documentId&&previous.key!==draftKey(value)&&previous.raw!==null)removeExact(previous.key,previous.raw);
   draft=value;ownDraftId=value.id;currentDraftRaw=raw;storageFailed=false;
   memoryDrafts.delete(account.id+':'+world.id);
   drafts=readDrafts(world.id);render();return true;
  }catch(error){storageFailed=true;status=error.code||'storage';render();return false}
 }
 async function loadWorld(id,{choose=true,keepStatus=false}={}){
  need(authenticated(),'sign_in');need(ID.test(id),'invalid_world');
  const context=ticket(),requestSelection=++selection;
  selectedId=id;loading=true;worldVerified=false;render();
  try{
   const result=await json(PREFIX+'worlds/'+id);
   if(!current(context)||requestSelection!==selection)return false;
   need(validWorld(result.world,account.id)&&result.world.id===id);
   world=clone(result.world);invite=world.pendingHandoff;worldVerified=true;
   drafts=readDrafts(id);
   const memory=memoryDrafts.get(account.id+':'+id);
   const retained=draft&&draft.worldId===id&&drafts.find(row=>row.key===draftKey(draft));
   if(memory){
    let raw=null;
    try{raw=write(draftKey(memory),memory);memoryDrafts.delete(account.id+':'+id);storageFailed=false}catch{storageFailed=true}
    installDraft({value:memory,raw});
   }
   else if(choose&&retained)installDraft(retained);
   else if(choose&&drafts.length===1)installDraft(drafts[0]);
   else{draft=null;currentDraftRaw=null;ownDraftId=null;draftConflict=false;choiceRequired=choose&&drafts.length>1;game.apply(snapshotState(world))}
   write(pointerRoot+account.id,{version:1,accountId:account.id,worldId:id});
   if(!keepStatus)status=storageFailed?'storage':draftConflict?'draft_conflict':choiceRequired?'choose_draft':world.canEdit?'world_ready':'read_only';
   return true;
  }catch(error){if(current(context)&&requestSelection===selection){worldVerified=false;throw error}return false}
  finally{if(current(context)&&requestSelection===selection){loading=false;render()}}
 }
 async function refreshLists(){
  need(authenticated(),'sign_in');const context=ticket();
  const [listing,inbox]=await Promise.all([json(PREFIX+'worlds'),json(PREFIX+'notifications')]);
  if(!current(context))return false;
  need(Array.isArray(listing.worlds)&&listing.worlds.length<=256&&listing.worlds.every(item=>validWorld(item,account.id,true)));
  need(Array.isArray(inbox.notifications)&&inbox.notifications.length<=200&&inbox.notifications.every(notification)
   &&Number.isSafeInteger(inbox.unreadCount)&&inbox.unreadCount===inbox.notifications.filter(item=>item.readAt===null).length);
  worlds=clone(listing.worlds);notifications=clone(inbox.notifications);refreshJournals();render();return true;
 }
 async function openInvitation(id){
  need(authenticated(),'sign_in');need(ID.test(id),'invalid_invitation');
  const context=ticket(),requestSelection=++selection;loading=true;worldVerified=false;render();
  try{
   const result=await json(PREFIX+'handoffs/'+id);
   if(!current(context)||requestSelection!==selection)return false;
   need(invitation(result.invitation)&&result.invitation.id===id&&[result.invitation.from.id,result.invitation.to.id].includes(account.id));
   invite=clone(result.invitation);world=null;selectedId='';draft=null;drafts=[];choiceRequired=false;draftConflict=false;
   game.apply({generation:1,budget:100,changes:[],objects:[],pending:[],history:[],snapshots:[]});
   status=invite.status==='pending'?'invitation_ready':'invitation_closed';return true;
  }finally{if(current(context)&&requestSelection===selection){loading=false;render()}}
 }
 async function verify(){
  if(!mode)return false;
  epoch++;selection++;clearRequests();const expectedEpoch=epoch;
  account=null;credential='';world=null;worldVerified=false;draft=null;drafts=[];pending=[];invite=null;worlds=[];notifications=[];busy=null;
  loading=true;status='checking_account';game.busy(false);render();
  try{
   const token=readToken();need(token,'sign_in');
   const me=await json('/api/core/auth/me',{token});
   if(!mode||epoch!==expectedEpoch||readToken()!==token)return false;
   need(person(me.user));account=clone(me.user);credential=token;
   const context=ticket(),caps=await json(PREFIX+'capabilities');
   if(!current(context))return false;
   need(caps.schemaVersion===1&&caps.template==='quiet-reach-v1'&&caps.permissions==='single-custodian-retained-history'
    &&caps.operationRecovery==='get-only'&&caps.externalNotifications===false&&caps.importedHistoryVerified===false
    &&record(caps.limits)&&caps.limits.objects===1024&&caps.limits.generations===128&&caps.limits.delta===100);
   capabilities=clone(caps);await refreshLists();if(!current(context))return false;
   loading=false;
   const route=options.route(),saved=get(pointerRoot+account.id);
   if(ID.test(route.invitation||''))await openInvitation(route.invitation);
   else if(ID.test(route.world||''))await loadWorld(route.world);
   else if(saved){let pointer;try{pointer=JSON.parse(saved)}catch{throw new AccountError('storage')}
    need(pointer?.version===1&&pointer.accountId===account.id&&ID.test(pointer.worldId),'storage');await loadWorld(pointer.worldId)}
   else{game.apply({generation:1,budget:100,changes:[],objects:[],pending:[],history:[],snapshots:[]});status='choose_world'}
   if(current(context)){refreshJournals();if(pending.length)status='check_operation';render()}
   return true;
  }catch(error){if(epoch===expectedEpoch&&mode){loading=false;fail(error)}return false}
  finally{if(epoch===expectedEpoch&&mode){loading=false;render()}}
 }
 function operationProof(saved,result){
  need(record(result)&&record(result.operation));
  const op=result.operation;
  need(op.key===saved.key&&op.kind===saved.kind&&op.status==='committed'
   &&(op.worldId===null||ID.test(op.worldId))&&(op.invitationId===null||ID.test(op.invitationId)));
  if(saved.worldId)need(op.worldId===saved.worldId);
  if(saved.invitationId)need(op.invitationId===saved.invitationId);
  if(result.world)need(validWorld(result.world,saved.accountId)&&result.world.id===op.worldId);
  if(result.invitation)need(invitation(result.invitation)&&result.invitation.id===op.invitationId&&result.invitation.worldId===(op.worldId||saved.worldId||result.invitation.worldId));
  if(saved.kind==='create')need(result.world&&result.world.currentGeneration===1&&result.world.revision===1
   &&result.world.creator.id===saved.accountId&&result.world.source===saved.body.source&&equal(result.world.objects,saved.body.objects));
  if(saved.kind==='generation')need(result.world&&generation(result.generation)&&result.generation.number===saved.body.expectedGeneration
   &&result.generation.author.id===saved.accountId&&equal(result.generation.delta,saved.body.delta)&&result.generation.message===saved.body.message
   &&result.world.currentGeneration===saved.body.expectedGeneration+1&&result.world.revision===saved.body.expectedRevision+1
   &&equal(result.world.objects,saved.draft.baseObjects.concat(saved.body.delta)));
  if(saved.kind==='offer')need(result.world&&result.invitation&&result.invitation.from.id===saved.accountId&&result.invitation.to.id===saved.body.targetUserId&&result.invitation.status==='pending');
  if(['accept','cancel','decline'].includes(saved.kind))need(result.invitation&&result.invitation.status===({accept:'accepted',cancel:'cancelled',decline:'declined'}[saved.kind])
   &&(saved.kind==='cancel'?result.invitation.from.id:result.invitation.to.id)===saved.accountId);
  if(saved.kind==='notification_read')need(notification(result.notification)&&result.notification.id===saved.notificationId&&result.notification.readAt!==null);
 }
 async function complete(saved,result,context){
  if(!currentSelection(context))return false;operationProof(saved,result);
  if(saved.kind==='create'&&saved.carry.length){
   const value={version:1,api,accountId:saved.accountId,worldId:result.world.id,id:saved.key,documentId:'operation-'+saved.key,
    baseRevision:1,baseGeneration:1,baseHash:result.world.snapshotHash,baseObjects:clone(saved.body.objects),pending:clone(saved.carry),updatedAt:saved.createdAt};
   const existing=get(draftKey(value));
   if(existing!==null)need(equal(JSON.parse(existing),value),'storage');else write(draftKey(value),value);
  }
  if(saved.kind==='generation'){
   const key=draftKey(saved.draft),raw=get(key);
   if(raw!==null&&equal(JSON.parse(raw),saved.draft)&&saved.draft.documentId===documentId)removeExact(key,raw);
   if(draft&&draftKey(draft)===key){draft=null;ownDraftId=null;currentDraftRaw=null}
  }
  // The stored response proves the operation, not current custody. Always read the live world.
  if(result.world){
   const opening=loadWorld(result.world.id,{keepStatus:true});context.selection=selection;
   if(!await opening||!currentSelection(context))return false;
  }
  if(result.invitation){
   const fresh=await json(PREFIX+'handoffs/'+result.invitation.id);if(!currentSelection(context))return false;
   need(invitation(fresh.invitation)&&fresh.invitation.id===result.invitation.id);invite=clone(fresh.invitation);
  }
  await refreshLists();if(!currentSelection(context))return false;
  const raw=get(opKey(saved));
  need(raw!==null&&equal(JSON.parse(raw),saved),'storage');removeExact(opKey(saved),raw);
  refreshJournals();status='operation_confirmed';render();
  // Only a verified committed generation, never an uncertain POST or draft,
  // can display the account server-confirmed receipt.
  if(saved.kind==='generation')try{
   game.handoffComplete?.({mode:'account',outcome:'confirmed',
    fromGeneration:saved.body.expectedGeneration,toGeneration:saved.body.expectedGeneration+1,
    delta:saved.body.delta});
  }catch{}
  return true;
 }
 async function mutate(kind,body,metadata={}){
  if(!mutationAllowed())return 'blocked';
  const saved={version:1,api,accountId:account.id,key:uuid(),kind,worldId:metadata.worldId||null,invitationId:metadata.invitationId||null,
   notificationId:metadata.notificationId||null,body:clone(body),carry:clone(metadata.carry||[]),draft:metadata.draft?clone(metadata.draft):null,createdAt:now()};
  saved.path=routeFor(saved);need(validOperation(saved),'invalid_operation');
  need(readOperations().length<32,'operation_limit');
  write(opKey(saved),saved);refreshJournals();
  const context=ticket();busy=saved.key;status='saving';game.busy(true);render();
  try{
   let result;
   try{result=await json(PREFIX+saved.path,{method:'POST',body:saved.body,key:saved.key})}
   catch(error){
    if(!currentSelection(context))return 'ignored';
    // Only a parsed, definitive client error closes this exact attempt. Lost/5xx replies remain journaled.
    if([400,401,403,404,409,422].includes(error.status)){
     const raw=get(opKey(saved));if(raw&&equal(JSON.parse(raw),saved))removeExact(opKey(saved),raw);
     refreshJournals();if(error.status===401)pause('session_expired');
     else{worldVerified=false;status=error.status===409?'server_conflict':'operation_rejected';render()}
     return 'rejected';
    }
    status='operation_unknown';render();return 'uncertain';
   }
   if(!currentSelection(context))return 'ignored';
   try{return await complete(saved,result,context)?'committed':'ignored'}
   catch(error){
    if(!currentSelection(context))return 'ignored';
    if(error.status===401)pause('session_expired');
    else{status=error.code==='storage'?'storage':'operation_unknown';storageFailed=error.code==='storage';render()}
    return 'uncertain';
   }
  }finally{if(current(context)&&busy===saved.key){busy=null;game.busy(false);render()}}
 }
 async function recover(key){
  need(authenticated(),'sign_in');need(!busy&&!loading,'working');
  refreshJournals();const row=pending.find(item=>item.value.key===key);need(row,'invalid_operation');
  const context=ticket();busy=key;status='checking_operation';game.busy(true);render();
  try{
   let result;
   try{result=await json(PREFIX+'operations/'+key)}catch(error){if(!currentSelection(context))return 'ignored';if(error.status===401)pause('session_expired');else status=error.status===404?'operation_unknown':'unavailable';return 'uncertain'}
   if(!currentSelection(context))return 'ignored';
   need(result.status==='committed'&&record(result.operation)&&equal(result.operation,result.result?.operation));
   return await complete(row.value,result.result,context)?'committed':'ignored';
  }catch(error){if(!currentSelection(context))return 'ignored';return fail(error)
  }finally{if(current(context)&&busy===key){busy=null;game.busy(false);render()}}
 }
 async function createWorld(source,title){
  need(source==='template'||source==='local-copy','invalid_operation');title=String(title||'').trim();need(title.length>0&&title.length<=120,'title_required');
  let baseline=[],carry=[];
  if(source==='local-copy'){
   const local=clone(localCopy),all=typed(local.objects||[]);carry=typed(local.pending||[]);
   need(marks(all,10000)&&marks(carry,100)&&local.budget===100-carry.length&&Array.isArray(local.changes)&&local.changes.length===carry.length,'invalid_local_copy');
   need(equal(all.slice(all.length-carry.length),carry),'invalid_local_copy');
   baseline=all.slice(0,all.length-carry.length);need(baseline.length+carry.length<=1024,'world_limit');
  }
  return mutate('create',{title,template:'quiet-reach-v1',source,objects:baseline},{carry});
 }
 async function saveGeneration(message){
  if(blockMutation())return 'blocked';
  need(world&&game.snapshot().pending.length>0,'leave_trace');need(saveDraft(),'storage');
  const value=String(message||options.message?.()||('Generation '+world.currentGeneration)).trim();need(value.length>0&&value.length<=1000,'message_required');
  return mutate('generation',{expectedRevision:world.revision,expectedGeneration:world.currentGeneration,message:value,delta:clone(draft.pending)},{worldId:world.id,draft});
 }
 async function offer(target,acknowledged){
  need(authenticated()&&worldVerified&&world?.canOfferHandoff,'generation_required');need(!game.snapshot().pending.length,'finish_draft');
  need(ID.test(target)&&target!==account.id,'target_required');need(acknowledged===true,'sharing_required');
  return mutate('offer',{expectedRevision:world.revision,targetUserId:target,sharingAcknowledged:true},{worldId:world.id});
 }
 async function transition(action){
  need(authenticated()&&invitation(invite)&&invite.status==='pending','invitation_closed');
  need(action==='cancel'?invite.from.id===account.id:['accept','decline'].includes(action)&&invite.to.id===account.id,'read_only');
  return mutate(action,{expectedRevision:invite.expectedRevision},{worldId:action==='decline'?null:invite.worldId,invitationId:invite.id});
 }
 async function viewGeneration(number){
  need(authenticated()&&world&&Number.isSafeInteger(number),'sign_in');
  const context=ticket(),id=world.id,selected=selection;
  const result=await json(PREFIX+'worlds/'+id+'/generations/'+number);
  if(!current(context)||selected!==selection||world?.id!==id)return false;
  const known=world.generations.find(item=>item.number===number);
  need(result.worldId===id&&generation(result.generation)&&marks(result.generation.objects)&&known
   &&result.generation.number===number&&result.generation.snapshotHash===known.snapshotHash&&equal(result.generation.delta,known.delta));
  const baseLength=world.objects.length-world.generations.flatMap(item=>item.delta).length;
  const expected=world.objects.slice(0,baseLength+world.generations.filter(item=>item.number<=number).flatMap(item=>item.delta).length);
  need(equal(result.generation.objects,expected));game.showSnapshot(number,result.generation.objects);status='snapshot_verified';render();return true;
 }
 async function openNotification(id){
  const item=notifications.find(value=>value.id===id);need(item&&authenticated(),'invalid_notification');const context=ticket();
  let opening,showGeneration=false;
  if(item.kind==='handoff_offered')opening=openInvitation(item.invitationId);
  else if(worlds.some(value=>value.id===item.worldId)){opening=loadWorld(item.worldId);showGeneration=!!item.generation}
  else if(item.invitationId)opening=openInvitation(item.invitationId);
  else return false;
  context.selection=selection;
  if(!await opening||!currentSelection(context))return false;
  if(showGeneration&&(!await viewGeneration(item.generation)||!currentSelection(context)))return false;
  if(item.readAt===null&&!busy&&!loading&&!readOperations().length)await mutate('notification_read',{}, {notificationId:item.id});
  return true;
 }
 async function refresh(){
  if(!authenticated())return verify();
  await refreshLists();if(selectedId)await loadWorld(selectedId);else if(invite)await openInvitation(invite.id);
 }
 function selectMode(accountMode){
  if(accountMode===mode)return accountMode?verify():true;
  if(accountMode)localCopy=game.localSnapshot();
  epoch++;selection++;clearRequests();busy=null;loading=false;game.busy(false);
  mode=accountMode;game.setMode(mode);account=null;credential='';world=null;worldVerified=false;invite=null;draft=null;drafts=[];pending=[];storageFailed=false;
  status=mode?'checking_account':'local_mode';options.setRoute?.(mode);render();
  return mode?verify():true;
 }
 function exportDraft(){
  let savedOperations=[],storageReadable=true;
  try{if(account)savedOperations=readOperations().map(row=>clone(row.value))}catch{storageReadable=false}
  const value={product:'INHERIT',schemaVersion:2,scope:'Local backup. It grants no server access and is not proof of a committed generation.',
   worldId:world?.id||selectedId||null,state:game.snapshot(),operations:savedOperations,storageReadable};
  game.download(value,'inherit-account-backup.json');status='exported';render();
 }
 function showHistory(){if(authenticated()&&world)game.history(clone(world.generations),number=>apiObject.viewGeneration(number))}
 function chooseDraft(id){need(worldVerified&&world,'choose_world');drafts=readDrafts(world.id);const row=drafts.find(item=>item.value.id===id);need(row,'invalid_draft');installDraft(row);status=draftConflict?'draft_conflict':'draft_restored';render()}
 function showCurrent(){need(worldVerified&&world,'choose_world');installDraft(null);status='world_ready';render()}
 function render(){
  view.render({mode,account:account&&clone(account),world:world&&clone(world),invite:invite&&clone(invite),worlds:clone(worlds),notifications:clone(notifications),
   busy:!!busy,loading,status,canEdit:canEdit(),pending:pending.map(row=>({key:row.value.key,kind:row.value.kind,worldId:row.value.worldId})),
   drafts:drafts.map(row=>({id:row.value.id,count:row.value.pending.length,generation:row.value.baseGeneration})),draftConflict,choiceRequired,storageFailed});
 }
 const safe=fn=>(...args)=>{
  try{
   const result=fn(...args),callEpoch=epoch,callSelection=selection;
   return result&&typeof result.then==='function'?result.catch(error=>{
    if(callEpoch!==epoch||callSelection!==selection)return 'ignored';
    return fail(error);
   }):result;
  }catch(error){return fail(error)}
 };
 const apiObject={isAccountMode:()=>mode,blockMutation,saveDraft,render,renderStorage:()=>view.storage?.(),
  verify:safe(verify),selectMode:safe(selectMode),loadWorld:safe(loadWorld),openInvitation:safe(openInvitation),refresh:safe(refresh),
  createWorld:safe(createWorld),saveGeneration:safe(saveGeneration),offer:safe(offer),transition:safe(transition),recover:safe(recover),
  viewGeneration:safe(viewGeneration),openNotification:safe(openNotification),exportDraft:safe(exportDraft),showHistory:safe(showHistory),
  chooseDraft:safe(chooseDraft),showCurrent:safe(showCurrent),
  accountChanged(){if(mode&&!authenticated())return false;return true},
  leave(){if(mode){epoch++;selection++;clearRequests();worldVerified=false;busy=null;loading=false;game.busy(false)}},
  state(){let value;const previous=view.render;view.render=result=>{value=result};render();view.render=previous;return value},
  start(){if(mode){game.setMode(true);return apiObject.verify()}render();return Promise.resolve(true)}};
 return apiObject;
}
window.InheritAccountFactory={create:createController};
const translations={
 'Account worlds':'Миры аккаунта','Local world':'Локальный мир','Return to the local world':'Вернуться к локальному миру',
 'Save in an account':'Сохранение в аккаунте','Sign in to Core':'Войти в Core','Check account and updates':'Проверить аккаунт и обновления',
 'Core account ID':'ID аккаунта Core','World title':'Название мира','Create an empty world':'Создать новый мир',
 'Copy my local island':'Скопировать локальный остров','My worlds':'Мои миры','Generation message':'Запись поколения',
 'Next keeper’s Core ID':'ID следующего хранителя в Core','Offer this world':'Предложить мир хранителю',
 'I agree to share this world and its complete history with this keeper. Previous keepers retain read access.':'Я согласен открыть этому хранителю мир и всю его историю. Предыдущие хранители сохраняют доступ к чтению.',
 'Accept the world':'Принять мир','Decline':'Отклонить','Cancel handoff':'Отменить передачу','Invitation':'Приглашение',
 'Notifications':'Уведомления','Check saved operation':'Проверить сохранение','Export account backup':'Экспортировать аккаунтную копию',
 'Preserved drafts':'Сохранённые черновики','Open the current server world':'Открыть актуальный серверный мир',
 'Open':'Открыть','Restore draft':'Открыть черновик','Read only':'Только чтение','Current keeper':'Текущий хранитель',
 'No server worlds yet.':'Серверных миров пока нет.','No notifications.':'Уведомлений пока нет.',
 'Account mode is explicit. Your original local save is kept separately.':'Аккаунтный режим включается отдельно. Исходный локальный мир сохраняется отдельно.',
 'A local copy starts a new private history at generation 1. Its earlier names and history are not verified or published. Pending traces stay a separate draft.':'Локальная копия начинает новую личную историю с поколения 1. Прежние имена и история не подтверждаются и не публикуются. Незавершённые следы остаются отдельным черновиком.',
 'Only the current keeper can add traces. A handoff pauses changes until accepted, declined, cancelled or expired.':'Следы добавляет только текущий хранитель. Во время передачи изменения приостановлены до принятия, отказа, отмены или истечения приглашения.',
 'The invitation is for this account only. Accepting opens the island and grants custody.':'Приглашение адресовано только указанному аккаунту. Принятие откроет остров и передаст роль хранителя.',
 'This is an imported local baseline; earlier authorship is unverified.':'Основа импортирована из локального мира; её прежнее авторство не подтверждено.',
 'The server preserves each generation and its author. Local backups do not grant account access.':'Сервер сохраняет поколения и их авторов. Локальная копия не предоставляет доступ к аккаунту.',
 'A preserved trace':'Сохранённый след','Open the generation history to see its confirmed author.':'Откройте историю поколения, чтобы увидеть подтверждённого автора.',
 'Template memory':'Память шаблона','These landmarks belong to the fictional island template. Confirmed authors and generations are listed in this account world’s history.':'Эти ориентиры относятся к художественному шаблону острова. Подтверждённые авторы и поколения указаны в истории аккаунтного мира.',
 'Local play is active. Your original save remains on this device.':'Открыт локальный мир. Исходное сохранение остаётся на этом устройстве.',
 'Sign in or verify the Core account to open private worlds.':'Войдите или проверьте аккаунт Core, чтобы открыть личные миры.',
 'Checking the Core session…':'Проверяем сессию Core…','Choose a world or create a private branch.':'Выберите мир или создайте личную ветку.',
 'The current server world is ready. Unsaved traces remain a local draft.':'Актуальный серверный мир открыт. Незавершённые следы остаются локальным черновиком.',
 'This world is read only for you, or a handoff is pending.':'Этот мир доступен вам только для чтения, либо ожидается передача.',
 'Saving once. Changes are paused until the response or deadline.':'Сохраняем одной операцией. Изменения приостановлены до ответа или завершения ожидания.',
 'The server confirmed the operation; current access was checked again.':'Сервер подтвердил операцию; актуальные права проверены повторно.',
 'The result is unknown. Use Check saved operation. No POST is retried.':'Результат неизвестен. Нажмите «Проверить сохранение». POST повторно не отправляется.',
 'An unfinished operation is preserved. Check it before another server change.':'Незавершённая операция сохранена. Проверьте её перед следующим изменением на сервере.',
 'Checking the same saved operation…':'Проверяем ту же сохранённую операцию…',
 'The server version changed. Your draft is preserved; refresh or export it.':'Серверная версия изменилась. Черновик сохранён; обновите мир или экспортируйте копию.',
 'This draft belongs to an earlier revision. It is preserved separately and will not overwrite the current world.':'Черновик относится к прежней версии. Он сохранён отдельно и не перезапишет актуальный мир.',
 'Several drafts are preserved. Choose one explicitly; they are never merged automatically.':'Сохранено несколько черновиков. Выберите нужный; автоматического объединения нет.',
 'Draft restored.':'Черновик открыт.','The session changed. Verify the account again; protected data was not converted to a local world.':'Сессия изменилась. Проверьте аккаунт снова; защищённый мир не превращён в локальный.',
 'The session expired. Sign in again; saved operations and drafts are retained.':'Сессия истекла. Войдите снова; операции и черновики сохранены.',
 'Persistent storage is unavailable. No new server change will be sent. Export before leaving.':'Постоянное сохранение недоступно. Новые изменения на сервер не отправляются. Экспортируйте копию перед уходом.',
 'The service is unavailable. Your local world and saved account draft remain separate.':'Сервис недоступен. Локальный мир и сохранённый аккаунтный черновик остаются раздельными.',
 'The server rejected this operation. The draft is unchanged; refresh before continuing.':'Сервер отклонил операцию. Черновик не изменён; обновите мир перед продолжением.',
 'Invitation ready. Check the sender and recipient before accepting.':'Приглашение открыто. Проверьте отправителя и получателя перед принятием.',
 'This invitation is closed or expired.':'Приглашение закрыто или срок его действия истёк.',
 'The immutable generation snapshot was loaded and matched to its history entry.':'Снимок поколения загружен и сопоставлен с записью в истории.',
 'The account backup was downloaded. It is not proof of a server commit.':'Аккаунтная копия скачана. Она не является подтверждением серверной записи.',
 'Enter a world title.':'Введите название мира.','Leave at least one trace before saving a generation.':'Оставьте хотя бы один след перед сохранением поколения.',
 'Save a generation during your custody before offering the world.':'Сначала сохраните поколение во время своего хранительства.',
 'Finish the pending draft before offering the world.':'Завершите черновик перед передачей мира.',
 'Enter the exact Core ID of another account.':'Введите точный Core ID другого аккаунта.',
 'Confirm sharing of the world and its history.':'Подтвердите передачу мира и доступ к его истории.',
 'This world reached a trace or generation limit. Export the world or create a new private branch.':'Достигнут лимит следов или поколений. Экспортируйте мир или создайте новую личную ветку.',
 'The local draft is inconsistent. Export the original before creating a server copy.':'Локальный черновик несогласован. Экспортируйте исходный мир перед созданием серверной копии.',
 'Too many preserved drafts or operations. Resolve existing records; nothing was removed.':'Слишком много сохранённых черновиков или операций. Проверьте существующие; ничего не удалено.',
 'New generation':'Новое поколение','World offered':'Предложена передача мира','World accepted':'Мир принят',
 'World declined':'Передача отклонена','Handoff cancelled':'Передача отменена',
 'pending':'ожидается ответ','accepted':'принято','cancelled':'отменено','declined':'отклонено','expired':'срок истёк',
 'Save: private account world; unfinished traces are stored on this device.':'Сохранение: личный мир аккаунта; незавершённые следы хранятся на этом устройстве.',
 'Account access is paused. Drafts and operations keep their protected identity.':'Доступ аккаунта приостановлен. Черновики и операции сохраняют защищённую принадлежность.'
};
const statusText={
 local_mode:'Local play is active. Your original save remains on this device.',
 sign_in:'Sign in or verify the Core account to open private worlds.',checking_account:'Checking the Core session…',
 choose_world:'Choose a world or create a private branch.',world_ready:'The current server world is ready. Unsaved traces remain a local draft.',
 read_only:'This world is read only for you, or a handoff is pending.',saving:'Saving once. Changes are paused until the response or deadline.',
 working:'Saving once. Changes are paused until the response or deadline.',
 operation_confirmed:'The server confirmed the operation; current access was checked again.',
 operation_unknown:'The result is unknown. Use Check saved operation. No POST is retried.',check_operation:'An unfinished operation is preserved. Check it before another server change.',
 checking_operation:'Checking the same saved operation…',server_conflict:'The server version changed. Your draft is preserved; refresh or export it.',
 draft_conflict:'This draft belongs to an earlier revision. It is preserved separately and will not overwrite the current world.',
 choose_draft:'Several drafts are preserved. Choose one explicitly; they are never merged automatically.',draft_restored:'Draft restored.',
 session_changed:'The session changed. Verify the account again; protected data was not converted to a local world.',
 session_expired:'The session expired. Sign in again; saved operations and drafts are retained.',
 storage:'Persistent storage is unavailable. No new server change will be sent. Export before leaving.',
 session_storage:'Persistent storage is unavailable. No new server change will be sent. Export before leaving.',
 operation_rejected:'The server rejected this operation. The draft is unchanged; refresh before continuing.',
 invitation_ready:'Invitation ready. Check the sender and recipient before accepting.',invitation_closed:'This invitation is closed or expired.',
 snapshot_verified:'The immutable generation snapshot was loaded and matched to its history entry.',
 exported:'The account backup was downloaded. It is not proof of a server commit.',
 title_required:'Enter a world title.',leave_trace:'Leave at least one trace before saving a generation.',
 generation_required:'Save a generation during your custody before offering the world.',finish_draft:'Finish the pending draft before offering the world.',
 target_required:'Enter the exact Core ID of another account.',sharing_required:'Confirm sharing of the world and its history.',
 world_limit:'This world reached a trace or generation limit. Export the world or create a new private branch.',
 invalid_local_copy:'The local draft is inconsistent. Export the original before creating a server copy.',
 invalid_draft:'The local draft is inconsistent. Export the original before creating a server copy.',
 draft_limit:'Too many preserved drafts or operations. Resolve existing records; nothing was removed.',
 operation_limit:'Too many preserved drafts or operations. Resolve existing records; nothing was removed.'
};
function mount(){
 if(!window.InheritGame||!window.InheritUI)return;
 window.InheritUI.addTranslations(translations);
 const t=value=>window.InheritUI.t(value),q=selector=>document.querySelector(selector);
 const container=document.createElement('section');container.className='inherit-account';container.id='inherit-account';container.setAttribute('aria-label',t('Account worlds'));
 container.innerHTML='<div class="inherit-account-modes" role="group" aria-label="Account worlds"><button id="inherit-local-mode" type="button">Local world</button><button id="inherit-account-mode" type="button">Save in an account</button></div><p id="inherit-account-status" role="status" aria-live="polite"></p><div id="inherit-account-body" hidden><p>Account mode is explicit. Your original local save is kept separately.</p><div class="inherit-account-actions"><a id="inherit-account-signin">Sign in to Core</a><button id="inherit-account-refresh" type="button">Check account and updates</button><button id="inherit-account-export" type="button">Export account backup</button></div><p id="inherit-account-identity"></p><ul id="inherit-account-operations"></ul><div id="inherit-account-authorized" hidden><details><summary>Create an empty world</summary><label for="inherit-account-title">World title</label><input id="inherit-account-title" maxlength="120" value="The Quiet Reach"><p> A local copy starts a new private history at generation 1. Its earlier names and history are not verified or published. Pending traces stay a separate draft.</p><div class="inherit-account-actions"><button id="inherit-account-new" type="button">Create an empty world</button><button id="inherit-account-copy" type="button">Copy my local island</button></div></details><details open><summary>My worlds</summary><ul id="inherit-account-worlds"></ul></details><div id="inherit-account-selected" hidden><h3 id="inherit-account-world-title"></h3><p id="inherit-account-world-access"></p><p id="inherit-account-provenance"></p><label for="inherit-account-message">Generation message</label><textarea id="inherit-account-message" maxlength="1000" rows="2"></textarea><details><summary>Offer this world</summary><p>Only the current keeper can add traces. A handoff pauses changes until accepted, declined, cancelled or expired.</p><label for="inherit-account-target">Next keeper’s Core ID</label><input id="inherit-account-target" maxlength="32" autocomplete="off" spellcheck="false" pattern="[a-f0-9]{32}"><label class="inherit-sharing"><input id="inherit-account-sharing" type="checkbox"><span>I agree to share this world and its complete history with this keeper. Previous keepers retain read access.</span></label><button id="inherit-account-offer" type="button">Offer this world</button></details><div id="inherit-account-drafts"></div><button id="inherit-account-current" type="button" hidden>Open the current server world</button></div><section id="inherit-account-invitation" hidden><h3>Invitation</h3><p id="inherit-account-invitation-copy"></p><p>The invitation is for this account only. Accepting opens the island and grants custody.</p><div class="inherit-account-actions"><button id="inherit-account-accept" type="button">Accept the world</button><button id="inherit-account-decline" type="button">Decline</button><button id="inherit-account-cancel" type="button">Cancel handoff</button></div></section><details open><summary>Notifications</summary><ul id="inherit-account-notifications"></ul></details></div></div>';
 q('.inherit-guide').appendChild(container);
 let controller,state;
 const button=(label,handler)=>{const value=document.createElement('button');value.type='button';value.textContent=t(label);value.onclick=handler;return value};
 const list=(id,values,build,empty)=>{const node=q(id);node.replaceChildren();if(!values.length&&empty){const row=document.createElement('li');row.textContent=t(empty);node.appendChild(row)}for(const value of values)node.appendChild(build(value))};
 function storageStatus(){
  if(!state?.mode)return;
  q('#inherit-save-state').textContent=t(state.storageFailed?statusText.storage:'Save: private account world; unfinished traces are stored on this device.');
  q('#inherit-online-state').textContent=t(state.account?statusText[state.status]||'The service is unavailable. Your local world and saved account draft remain separate.':'Account access is paused. Drafts and operations keep their protected identity.');
 }
 function render(value){
  state=value;
  q('#inherit-local-mode').setAttribute('aria-pressed',String(!state.mode));q('#inherit-account-mode').setAttribute('aria-pressed',String(state.mode));
  q('#inherit-local-mode').textContent=t(state.mode?'Return to the local world':'Local world');
  q('#inherit-account-body').hidden=!state.mode;
  q('#inherit-account-status').textContent=t(statusText[state.status]||'The service is unavailable. Your local world and saved account draft remain separate.');
  q('#inherit-account-authorized').hidden=!state.account;
  q('#inherit-account-signin').hidden=!!state.account;
  const route=new URL(location.href),params=new URLSearchParams({mode:'account',lang:window.InheritUI.getLanguage()});
  for(const name of ['world','invitation'])if(ID.test(route.searchParams.get(name)||''))params.set(name,route.searchParams.get(name));
  q('#inherit-account-signin').href='/workspace?returnTo='+encodeURIComponent('/games/inherit/?'+params);
  q('#inherit-account-identity').textContent=state.account?'@'+state.account.username+' · '+t('Core account ID')+': '+state.account.id:'';
  const locked=state.busy||state.loading||!!state.pending.length||state.storageFailed;
  for(const id of ['#inherit-account-new','#inherit-account-copy'])q(id).disabled=locked;
  q('#inherit-account-offer').disabled=locked||!state.world?.canOfferHandoff||!state.canEdit;
  q('#inherit-account-refresh').disabled=state.busy||state.loading;
  q('#inherit-account-selected').hidden=!state.world;
  q('#inherit-account-world-title').textContent=state.world?.title||'';
  q('#inherit-account-world-access').textContent=state.world?t('Generation '+state.world.currentGeneration)+' · '+t('Current keeper')+': @'+state.world.custodian.username+' · '+(state.canEdit?t('YOUR TURN'):t('Read only')):'';
  q('#inherit-account-provenance').textContent=t(state.world?.source==='local-copy'?'This is an imported local baseline; earlier authorship is unverified.':'The server preserves each generation and its author. Local backups do not grant account access.');
  q('#inherit-account-current').hidden=!(state.draftConflict||state.choiceRequired);
  list('#inherit-account-operations',state.pending,item=>{const row=document.createElement('li');row.textContent=item.kind+' · ';row.appendChild(button('Check saved operation',()=>controller.recover(item.key)));return row});
  list('#inherit-account-worlds',state.worlds,item=>{const row=document.createElement('li');const open=button('Open',()=>controller.loadWorld(item.id));open.dataset.inheritWorld=item.id;const label=document.createElement('span');label.textContent=item.title+' · '+t('Generation '+item.currentGeneration);row.append(label,open);return row},'No server worlds yet.');
  list('#inherit-account-drafts',state.drafts,item=>{const row=document.createElement('div');row.textContent=t('Generation '+item.generation)+' · '+item.count+' · ';row.appendChild(button('Restore draft',()=>controller.chooseDraft(item.id)));return row});
  q('#inherit-account-invitation').hidden=!state.invite;
  q('#inherit-account-invitation-copy').textContent=state.invite?state.invite.worldTitle+' · @'+state.invite.from.username+' → @'+state.invite.to.username+' · '+t(state.invite.status)+' · '+state.invite.expiresAt:'';
  for(const action of ['accept','decline','cancel']){
   const allowed=state.invite?.status==='pending'&&(action==='cancel'?state.invite.from.id===state.account?.id:state.invite.to.id===state.account?.id);
   q('#inherit-account-'+action).hidden=!allowed;q('#inherit-account-'+action).disabled=locked;
  }
  const kinds={generation_created:'New generation',handoff_offered:'World offered',handoff_accepted:'World accepted',handoff_declined:'World declined',handoff_cancelled:'Handoff cancelled'};
  list('#inherit-account-notifications',state.notifications,item=>{const row=document.createElement('li');row.dataset.notificationId=String(item.id);row.dataset.unread=String(item.readAt===null);const text=document.createElement('span');text.textContent=(item.readAt===null?'● ':'')+t(kinds[item.kind])+' · @'+item.actor.username;row.append(text,button('Open',()=>controller.openNotification(item.id)));return row},'No notifications.');
  for(const selector of ['#reset','#inherit-import','#inherit-import-file','#profile']){const node=q(selector);if(node)node.disabled=state.mode}
  q('#pass').disabled=state.mode?!state.canEdit:false;
  if(state.mode){q('#pass').textContent=t(state.busy?'Passing generation…':'Pass this world on →');q('.inherit-truth').textContent=t('The server preserves each generation and its author. Local backups do not grant account access.');storageStatus()}
  else{q('.inherit-truth').textContent=t('The first four entries are a fictional introduction. Names in local history do not mean other people are online. An invitation shares the route, not your local save.');window.InheritUI.updateStorage()}
 }
 // Access can itself throw (for example an opaque/sandboxed origin). Keep it inside controller guards.
 const storage={get length(){return window.localStorage.length},key:index=>window.localStorage.key(index),getItem:key=>window.localStorage.getItem(key),
  setItem:(key,value)=>window.localStorage.setItem(key,value),removeItem:key=>window.localStorage.removeItem(key)};
 controller=createController({game:window.InheritGame,view:{render,storage:storageStatus},storage,session:{getItem:key=>window.sessionStorage.getItem(key)},
  origin:location.origin,fetch:(...args)=>fetch(...args),uuid:()=>crypto.randomUUID(),message:()=>q('#inherit-account-message').value,
  route:()=>Object.fromEntries(new URLSearchParams(location.search)),
  setRoute(account){const url=new URL(location.href);if(account)url.searchParams.set('mode','account');else{url.searchParams.delete('mode');url.searchParams.delete('world');url.searchParams.delete('invitation')}history.replaceState(null,'',url.href)}
 });
 window.InheritAccount=controller;
 q('#inherit-local-mode').onclick=()=>controller.selectMode(false);
 q('#inherit-account-mode').onclick=()=>controller.selectMode(true);
 q('#inherit-account-refresh').onclick=()=>controller.verify();
 q('#inherit-account-export').onclick=()=>controller.exportDraft();
 q('#inherit-account-new').onclick=()=>controller.createWorld('template',q('#inherit-account-title').value);
 q('#inherit-account-copy').onclick=()=>controller.createWorld('local-copy',q('#inherit-account-title').value);
 q('#inherit-account-offer').onclick=()=>controller.offer(q('#inherit-account-target').value.trim(),q('#inherit-account-sharing').checked);
 q('#inherit-account-current').onclick=()=>controller.showCurrent();
 for(const action of ['accept','decline','cancel'])q('#inherit-account-'+action).onclick=()=>controller.transition(action);
 window.addEventListener('pagehide',()=>controller.leave());
 window.addEventListener('pageshow',event=>{if(event.persisted&&controller.isAccountMode())controller.verify()});
 window.addEventListener('focus',()=>controller.accountChanged());
 window.addEventListener('storage',event=>{if(controller.isAccountMode()&&(event.key===CORE_KEY||event.key?.startsWith('osgard:inherit-operation:v1:')))controller.accountChanged()});
 controller.start();
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',mount,{once:true});else mount();
})();
