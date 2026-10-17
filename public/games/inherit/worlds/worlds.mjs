import {createWorldClient,WorldRequestError} from './lineage-client.mjs';

const byId=id=>document.getElementById(id);
const client=createWorldClient();
const LIMIT=30;
const allowedTools={tree:'Дерево',stone:'Камень',light:'Огонь',path:'Тропа'};
const glyph={tree:'✦',stone:'◇',light:'☼',path:'⌁'};
let user=null,selected=null,tool='tree',draft=[],cursor={x:50,y:50},busy=false;
const STORE_PREFIX='inherit:core:draft:v1:';
const validId=value=>/^[a-f0-9]{32}$/.test(value||'');
const hasPending=()=>{try{return !!client.pending()}catch{return true}};
function status(message,error=false){
  byId('status').textContent=message;
  byId('status').style.color=error?'#ffad98':'';
}
function errorText(error){
  return error instanceof Error?error.message:'Не удалось выполнить запрос.';
}
function node(tag,className,textValue){
  const element=document.createElement(tag);
  if(className)element.className=className;
  if(textValue!==undefined)element.textContent=String(textValue);
  return element;
}
function showLogin(){
  byId('login').hidden=false;
  byId('dashboard').hidden=true;
  status('Сессия Core отсутствует или завершилась. Войдите снова.',true);
}
function syncRecovery(){
  if(!user)return;
  try{
    const entry=client.pending();
    byId('recovery').hidden=!entry;
    if(entry)byId('recovery-info').textContent='Есть неразрешённый запрос: '+entry.route+'. Сервер мог его принять. Используйте только восстановление с исходным ключом; новых изменений пока не отправляем.';
  }catch(error){
    byId('recovery').hidden=false;
    byId('recovery-info').textContent=errorText(error)+' Обратитесь к сохранённой записи браузера; отправка новых изменений остановлена.';
  }
  const disabled=hasPending()||busy;
  byId('create-form').querySelector('button').disabled=disabled;
  byId('pass-button').disabled=disabled||!selected?.world?.myTurn||selected?.world?.status!=='active'||draft.length===0;
  byId('cancel').disabled=disabled||!selected?.world?.myTurn;
}
function draftKey(){
  if(!selected||!user) return null;
  return STORE_PREFIX+user.id+':'+selected.world.id+':'+selected.world.generation;
}
function restoreDraft(){
  draft=[];
  const key=draftKey();
  if(!key)return;
  try{
    const input=JSON.parse(sessionStorage.getItem(key)||'[]');
    if(Array.isArray(input)&&input.length<=LIMIT&&input.every(o=>o&&allowedTools[o.type]&&
      Number.isFinite(o.x)&&Number.isFinite(o.y)&&o.x>=0&&o.x<=100&&o.y>=0&&o.y<=100)) draft=input;
  }catch{status('Черновик не удалось прочитать. Не перезаписывайте данные вкладки без резервной копии.',true)}
}
function saveDraft(next){
  const key=draftKey();
  if(!key)return false;
  try{
    sessionStorage.setItem(key,JSON.stringify(next));
    if(sessionStorage.getItem(key)!==JSON.stringify(next))throw Error('Write mismatch');
    draft=next;
    return true;
  }catch{
    status('Черновик не сохранился. Новый след отменён. Проверьте хранилище браузера.',true);
    return false;
  }
}
function renderMap(){
  const container=byId('placed');
  container.replaceChildren();
  if(!selected)return;
  const server=selected.snapshot?.objects||[];
  for(const [item,isDraft] of [...server.map(o=>[o,false]),...draft.map(o=>[o,true])]){
    const marker=node('span','trace'+(isDraft?' draft':''));
    marker.dataset.type=item.type||item.tool;
    marker.style.left=item.x+'%';
    marker.style.top=item.y+'%';
    marker.title=(isDraft?'Черновик: ':'Записано: ')+(allowedTools[item.type]||item.type);
    container.append(marker);
  }
  byId('cursor').style.left=cursor.x+'%';
  byId('cursor').style.top=cursor.y+'%';
  byId('draft-counter').textContent='Черновик: '+draft.length+' из '+LIMIT+' следов · в этой вкладке';
  syncRecovery();
}
function renderWorld(){
  const panel=byId('workbench');
  panel.hidden=!selected;
  if(!selected)return;
  const world=selected.world;
  byId('selected-name').textContent=world.title;
  byId('selected-meta').textContent='Поколение '+world.generation+' · хранитель @'+world.keeper+' · версия '+world.version;
  byId('keeper-state').textContent=world.myTurn?
    world.status==='active'?'Вы хранитель. Добавьте следы и предложите передачу другому аккаунту.':'Вы уже пригласили хранителя. Ожидаем его согласия.':
    'Вы можете изучить историю, но новые следы оставляет только текущий хранитель.';
  byId('tools').hidden=!world.myTurn||world.status!=='active';
  byId('pass-form').hidden=!world.myTurn||world.status!=='active';
  byId('cancel-zone').hidden=!world.myTurn||world.status!=='awaiting_acceptance';
  byId('undo').disabled=!world.myTurn||world.status!=='active'||draft.length===0;
  byId('map').setAttribute('aria-disabled',String(!world.myTurn||world.status!=='active'));
  const chronicle=byId('chronicle');chronicle.replaceChildren();
  if(!selected.history.length)chronicle.append(node('p','empty','Это первое поколение. История появится после подтверждённой передачи.'));
  for(const entry of [...selected.history].reverse()){
    const article=node('article');
    article.append(node('strong',null,'Поколение '+entry.number+' · @'+entry.keeper+' → @'+entry.passedTo));
    article.append(node('p',null,entry.message));
    article.append(node('small',null,'Следов: '+entry.delta.length+' · '+new Date(entry.createdAt).toLocaleString('ru-RU')));
    chronicle.append(article);
  }
  renderMap();
}
function renderWorldList(items){
  const target=byId('world-list');target.replaceChildren();
  if(!items.length)target.append(node('p','empty','Ваших миров пока нет. Создайте первый и пригласите следующего хранителя.'));
  for(const entry of items){
    if(!validId(entry.id))continue;
    const button=node('button','world-card'+(selected?.world.id===entry.id?' active':''));
    button.type='button';
    button.append(node('strong',null,entry.title));
    button.append(node('span',null,'Поколение '+entry.generation+' · @'+entry.keeper+(entry.myTurn?' · ваш ход':'')));
    button.addEventListener('click',()=>run(async()=>openWorld(entry.id)));
    target.append(button);
  }
}
function renderInbox(inbox){
  const target=byId('invitations');target.replaceChildren();
  if(!inbox.invitations.length)target.append(node('p','empty','Новых приглашений нет.'));
  for(const invite of inbox.invitations){
    if(!validId(invite.worldId))continue;
    const box=node('article','invitation');
    box.append(node('strong',null,invite.title));
    box.append(node('p',null,'От @'+invite.fromUsername+' · поколение '+invite.generation));
    const accept=node('button',null,'Принять мир');
    accept.type='button';
    accept.addEventListener('click',()=>run(async()=>{
      if(!confirm('Принять мир «'+invite.title+'» и стать хранителем следующего поколения?'))return;
      await client.mutate('inherit/worlds/'+invite.worldId+'/accept',{
        expectedVersion:invite.expectedVersion,expectedGeneration:invite.generation
      });
      status('Мир передан вам. Теперь можно оставить новые следы.');
      await reload();
      await openWorld(invite.worldId);
    }));
    box.append(accept);target.append(box);
  }
  const log=byId('notifications');log.replaceChildren();
  if(!inbox.events.length)log.append(node('p','empty','Сигналов пока нет.'));
  for(const event of inbox.events.slice(0,30)){
    const item=node('div','notification');
    const descriptions={invited:'Вас пригласили продолжить мир',new_generation:'Мир получил новое поколение',handoff_accepted:'Вам передали мир',invitation_cancelled:'Приглашение отозвано'};
    item.append(node('strong',null,(descriptions[event.kind]||event.kind)+' · №'+event.generation));
    item.append(node('p',null,new Date(event.createdAt).toLocaleString('ru-RU')));
    if(validId(event.worldId)&&event.kind!=='invited'){
      const go=node('button',null,'Посмотреть историю');
      go.type='button';go.addEventListener('click',()=>run(()=>openWorld(event.worldId)));item.append(go);
    }
    log.append(item);
  }
}
async function openWorld(id){
  if(!validId(id))throw Error('Некорректный адрес мира.');
  selected=await client.read('inherit/worlds/'+id);
  restoreDraft();
  renderWorld();
  byId('workbench').scrollIntoView({behavior:'auto',block:'start'});
}
async function reload(){
  const [worlds,inbox]=await Promise.all([client.read('inherit/worlds'),client.read('inherit/inbox')]);
  renderWorldList(worlds.worlds);
  renderInbox(inbox);
  syncRecovery();
}
async function run(work){
  if(busy)return;
  busy=true;byId('reload').disabled=true;byId('refresh').disabled=true;
  syncRecovery();
  try{await work()}
  catch(error){
    status(errorText(error),true);
    if(error instanceof WorldRequestError&&error.status===401)showLogin();
  }finally{
    busy=false;byId('reload').disabled=false;byId('refresh').disabled=false;
    syncRecovery();
  }
}
function addPoint(x,y){
  if(!selected?.world?.myTurn||selected.world.status!=='active'||hasPending())return;
  if(draft.length>=LIMIT){status('На одну передачу разрешено не более 30 следов.',true);return}
  const total=(selected.snapshot?.objects?.length||0)+draft.length;
  if(total>=500){status('Достигнут лимит следов этого мира.',true);return}
  const point={type:tool,x:Math.round(x*1000)/1000,y:Math.round(y*1000)/1000};
  if(saveDraft([...draft,point])){renderMap();status('След добавлен в черновик. Серверное сохранение происходит при принятии передачи.')}
}
byId('map').addEventListener('click',event=>{
  const rect=event.currentTarget.getBoundingClientRect();
  const x=100*(event.clientX-rect.left)/rect.width,y=100*(event.clientY-rect.top)/rect.height;
  if(x<10||x>90||y<10||y>90){status('Выберите место ближе к острову.',true);return}
  cursor={x,y};addPoint(x,y);
});
byId('map').addEventListener('keydown',event=>{
  const moves={ArrowLeft:[-2,0],ArrowRight:[2,0],ArrowUp:[0,-2],ArrowDown:[0,2]};
  if(moves[event.key]){
    event.preventDefault();cursor={x:Math.max(10,Math.min(90,cursor.x+moves[event.key][0])),
      y:Math.max(10,Math.min(90,cursor.y+moves[event.key][1]))};
    renderMap();
  }else if(event.key==='Enter'||event.key===' '){event.preventDefault();addPoint(cursor.x,cursor.y)}
});
for(const button of document.querySelectorAll('#tools [data-tool]')){
  button.addEventListener('click',()=>{
    tool=button.dataset.tool;
    for(const b of document.querySelectorAll('#tools [data-tool]')){
      b.classList.toggle('selected',b===button);b.setAttribute('aria-pressed',String(b===button));
    }
  });
}
byId('undo').addEventListener('click',()=>{
  if(!selected?.world.myTurn||!draft.length||hasPending())return;
  if(saveDraft(draft.slice(0,-1))){renderMap();status('Последний черновой след отменён.')}
});
byId('export').addEventListener('click',()=>{
  if(!selected)return;
  const data=JSON.stringify({worldId:selected.world.id,generation:selected.world.generation,draft},null,2);
  const url=URL.createObjectURL(new Blob([data],{type:'application/json'}));
  const anchor=node('a');anchor.href=url;anchor.download='inherit-draft-'+selected.world.id.slice(0,8)+'.json';
  anchor.click();setTimeout(()=>URL.revokeObjectURL(url),1500);
});
byId('create-form').addEventListener('submit',event=>{
  event.preventDefault();
  run(async()=>{
    const title=byId('world-title').value.trim();
    if(title.length<3)return;
    const created=await client.mutate('inherit/worlds',{title});
    byId('world-title').value='';
    status('Мир создан. Только ваш аккаунт имеет доступ к его истории.');
    await reload();await openWorld(created.worldId);
  });
});
byId('pass-form').addEventListener('submit',event=>{
  event.preventDefault();
  run(async()=>{
    if(!selected?.world.myTurn||selected.world.status!=='active'||!draft.length)return;
    const target=byId('to-username').value.trim().toLowerCase();
    const message=byId('pass-message').value.trim();
    if(!/^[a-z0-9_.-]{3,64}$/.test(target)||message.length<5)return;
    const state=selected.world;
    await client.mutate('inherit/worlds/'+state.id+'/pass',{
      expectedVersion:state.version,expectedGeneration:state.generation,
      toUsername:target,message,delta:draft
    });
    status('Приглашение отправлено аккаунту @'+target+'. Мир ждёт его подтверждения.');
    await reload();await openWorld(state.id);
  });
});
byId('cancel').addEventListener('click',()=>run(async()=>{
  if(!selected||!selected.world.myTurn||selected.world.status!=='awaiting_acceptance')return;
  if(!confirm('Отменить приглашение? Черновик в текущей вкладке сохранится.'))return;
  const state=selected.world;
  await client.mutate('inherit/worlds/'+state.id+'/cancel',{
    expectedVersion:state.version,expectedGeneration:state.generation
  });
  status('Приглашение отменено. Вы остаётесь хранителем.');
  await reload();await openWorld(state.id);
}));
byId('recover-button').addEventListener('click',()=>run(async()=>{
  const result=await client.recover();
  status('Исходный запрос подтверждён сервером. '+(result.replayed?'Повтор не создал новых записей.':''));
  await reload();
  if(result.worldId&&validId(result.worldId))await openWorld(result.worldId);
}));
byId('reload').addEventListener('click',()=>run(start));
byId('refresh').addEventListener('click',()=>run(async()=>{
  await reload();
  if(selected)await openWorld(selected.world.id);
  status('Сведения о мирах и приглашениях обновлены.');
}));
async function start(){
  try{
    user=await client.verify();
    byId('username').textContent='@'+user.username;
    byId('login').hidden=true;
    byId('dashboard').hidden=false;
    status('Core подтвердил аккаунт. Доступны только ваши миры.');
    await reload();
    const requested=new URL(location.href).searchParams.get('world');
    if(validId(requested))await openWorld(requested);
    syncRecovery();
  }catch(error){
    if(error instanceof WorldRequestError&&error.status===401)showLogin();
    else status(errorText(error),true);
  }
}
window.addEventListener('pageshow',event=>{if(event.persisted)run(start)});
run(start);
