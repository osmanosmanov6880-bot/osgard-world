/* INHERIT R13 — an optional, non-paying route through actual game actions.
 * A step completes ONLY after the player's own native island click changes
 * the checked world. Generation handoff stays behind the existing #pass.
 * All progress is ephemeral: reload/other device never fabricates a finish. */
(()=>{
'use strict';
const d=document,game=window.InheritGame,core=window.InheritGuidedJourney;
const compass=window.InheritTraceCompassCore,legacy=window.InheritLegacyEngine;
const tools=d.querySelector('.tools'),island=d.querySelector('#island'),pass=d.querySelector('#pass');
if(!core||!compass||!legacy||!game?.snapshot||!tools||!island||!pass)return;
const translations={
 ru:{
  trigger:'✧ Маршрут поколений',eyebrow:'ТВОЙ СЛЕДУЮЩИЙ ИГРОВОЙ ПУТЬ',
  title:'Маршрут поколений',intro:'План из настоящих игровых ходов: сначала оставь один или два следа, затем сам заверши поколение. Подсказки используют правила острова, но ничего не строят автоматически.',
  steps:'План действий',step:'Шаг',place:'Оставь след',pass:'Передай поколение',tool:'Инструмент',
  point:'Точка',links:'Возможные новые сочетания',start:'Начать маршрут',cancel:'Завершить просмотр',close:'Закрыть',
  noSafe:'В проверенных местах пока нет безопасного маршрута. Можешь свободно играть и вернуться позже.',
  budget:'В этом поколении нет доступных ходов. Если есть ожидающие следы, заверши поколение обычной кнопкой.',
  unavailable:'Текущее состояние мира нельзя надёжно проверить. Маршрут не создан.',
  account:'Режим аккаунта: маршрут доступен для просмотра, но запуск здесь отключён. Права и передача остаются у сервера.',
  replay:'Сейчас показана история. Вернись к текущему острову, чтобы начать маршрут.',
  note:'Все координаты — предложения. Прогресс показывается только после реального размещения с обычным расходом бюджета. Маршрут не хранится, не даёт наград и не подтверждает действия других игроков.',
  placeAction:'Выбрать инструмент и показать точку',handoffAction:'Найти кнопку завершения',
  hudAwaiting:'Нажми «Выбрать инструмент», затем сам нажми на остров возле золотой отметки.',
  hudArmed:'Инструмент выбран. Поставь предмет рядом с золотой меткой.',
  hudReady:'Все предложенные следы оставлены. Заверши поколение обычной игровой кнопкой.',
  hudDone:'Поколение подтверждено ответом сервера. Это не означает, что мир принял следующий игрок.',
  hudLocal:'Поколение сохранено локально. Подтверждение сервера неизвестно.',
  hudInvalid:'Мир изменился не по плану. Маршрут остановлен, сохранения не затронуты.',
  hudNoTool:'Нужный инструмент сейчас недоступен; маршрут можно пересоздать позднее.',
  waiting:'Ожидаем настоящего хода',complete:'Подтверждено локальными изменениями',handoff:'Ожидает подтверждения передачи',
  newPlan:'Новый маршрут',dismiss:'Закрыть',short:'На острове доступен короткий маршрут — передача не создаётся автоматически.',
  kindStarter:'Первый след',kindPair:'Реальное сочетание',types:{tree:'Дерево',stone:'Камень',light:'Фонарь',path:'Тропа',flower:'Цветы',arch:'Арка',chime:'Колокольчик',moss:'Мох',cairn:'Насыпь',marker:'Указатель'}
 },
 en:{
  trigger:'✧ Generation route',eyebrow:'YOUR NEXT REAL PLAY ROUTE',
  title:'Generation route',intro:'A path of real moves: place one or two traces yourself, then explicitly pass the generation. Suggestions use the actual island rules but never build anything automatically.',
  steps:'Your route',step:'Step',place:'Leave a trace',pass:'Pass the generation',tool:'Tool',
  point:'Position',links:'Possible new combinations',start:'Start route',cancel:'Stop following',close:'Close',
  noSafe:'No safe suggested route in the inspected positions. Continue playing freely and try again later.',
  budget:'No moves remain in this generation. If a trace is pending, use the normal generation handoff.',
  unavailable:'The current saved world cannot be validated; no route was created.',
  account:'Account world: this route is a read-only preview. The server still controls placement and handoff permissions.',
  replay:'You are viewing an earlier generation. Return to the present to start.',
  note:'Coordinates are only proposals. Progress advances only after real placement and the usual budget cost. The route is not stored, grants no rewards and cannot prove another player’s actions.',
  placeAction:'Choose tool and show marker',handoffAction:'Focus handoff button',
  hudAwaiting:'Select the tool, then click the island near the gold marker yourself.',
  hudArmed:'Tool selected. Place the object near the golden mark on the island.',
  hudReady:'Suggested traces were placed. Finish the generation with the existing game button.',
  hudDone:'The generation was confirmed by a server response. No next-player acceptance is implied.',
  hudLocal:'The generation was saved locally. Server confirmation is unknown.',
  hudInvalid:'The world changed outside the planned route. Guidance stopped, and no save was modified.',
  hudNoTool:'This tool is currently unavailable; create a new route later.',
  waiting:'Waiting for a real move',complete:'Observed in the world',handoff:'Awaiting explicit handoff',
  newPlan:'New route',dismiss:'Dismiss',short:'Only a short route is available. Handoff never happens automatically.',
  kindStarter:'First trace',kindPair:'Compatible pair',types:{tree:'Tree',stone:'Stone',light:'Lantern',path:'Path',flower:'Flowers',arch:'Arch',chime:'Chime',moss:'Moss',cairn:'Cairn',marker:'Marker'}
 },
 zh:{
  trigger:'✧ 世代路线',eyebrow:'下一段真实的游戏旅程',
  title:'世代路线',intro:'通过真实操作完成路线：自己放置一至两道痕迹，然后手动完成世代传承。建议来自真实岛屿规则，不会自动建造。',
  steps:'行动路线',step:'步骤',place:'留下痕迹',pass:'传承世代',tool:'工具',
  point:'位置',links:'可能的新组合',start:'开始路线',cancel:'停止跟随',close:'关闭',
  noSafe:'已检查的区域没有安全的推荐路线。可以自由游玩，稍后再试。',
  budget:'本世代没有可用操作次数。如有待保存痕迹，请使用原有世代传承按钮。',
  unavailable:'无法验证当前世界，因此没有生成路线。',
  account:'账号世界：路线只供预览，物件放置与世代传承仍由服务器权限控制。',
  replay:'正在查看过去，请先返回当前岛屿。',
  note:'坐标仅为建议。必须真正放置物件并花费正常预算才会记录进度。路线不保存、不提供奖励，也无法证明其他玩家的行为。',
  placeAction:'选择工具并显示位置',handoffAction:'定位世代传承按钮',
  hudAwaiting:'先选择工具，再亲自点击岛上金色标记附近的位置。',
  hudArmed:'已选择工具。请在金色标记附近放置物件。',
  hudReady:'建议的痕迹已经放置，请使用原有按钮完成世代传承。',
  hudDone:'服务器回应已确认世代完成，但不代表下一位玩家已经接手。',
  hudLocal:'世代已在本地保存，服务器是否确认未知。',
  hudInvalid:'世界发生了计划外变化。路线已停止，存档没有被修改。',
  hudNoTool:'当前无法选择此工具，稍后可制定新路线。',
  waiting:'等待真实操作',complete:'已在世界中观察到',handoff:'等待手动传承',
  newPlan:'新的路线',dismiss:'关闭',short:'当前只有较短的路线，传承不会自动发生。',
  kindStarter:'第一道痕迹',kindPair:'规则组合',types:{tree:'树木',stone:'石头',light:'灯笼',path:'小路',flower:'花朵',arch:'拱门',chime:'风铃',moss:'苔藓',cairn:'石堆',marker:'路标'}
 }
};
const lang=()=>{const val=window.InheritUI?.getLanguage?.();return translations[val]?val:'ru'};
const t=()=>translations[lang()];
const el=(tag,cls,value)=>{const n=d.createElement(tag);if(cls)n.className=cls;if(value!==undefined)n.textContent=String(value);return n};
const trigger=el('button','inherit-journey-trigger');trigger.type='button';trigger.dataset.noTranslate='';
trigger.setAttribute('aria-haspopup','dialog');tools.appendChild(trigger);
const dialog=el('dialog','inherit-journey-dialog');dialog.dataset.noTranslate='';
dialog.setAttribute('aria-labelledby','inherit-journey-title');
const head=el('div','inherit-journey-head'),names=el('div');
const eyebrow=el('p','inherit-journey-eyebrow'),title=el('h2','inherit-journey-title');
title.id='inherit-journey-title';const close=el('button','inherit-journey-close','×');close.type='button';
names.append(eyebrow,title);head.append(names,close);
const intro=el('p','inherit-journey-intro'),status=el('p','inherit-journey-status');
status.setAttribute('role','status');
const timeline=el('ol','inherit-journey-timeline');
const note=el('p','inherit-journey-note'),start=el('button','inherit-journey-start');start.type='button';
dialog.append(head,intro,status,timeline,note,start);d.body.appendChild(dialog);
const ghost=el('span','inherit-journey-ghost');ghost.hidden=true;ghost.setAttribute('aria-hidden','true');
island.appendChild(ghost);
const hud=el('aside','inherit-journey-hud');hud.dataset.noTranslate='';hud.hidden=true;
hud.setAttribute('aria-label','Guided generation journey');
const hudTop=el('div','inherit-journey-hud-top'),hudStage=el('strong'),stop=el('button','inherit-journey-stop','×');
stop.type='button';hudTop.append(hudStage,stop);
const hudText=el('p','inherit-journey-hud-text');hudText.setAttribute('role','status');hudText.setAttribute('aria-live','polite');
const hudAction=el('button','inherit-journey-hud-action');hudAction.type='button';
hud.append(hudTop,hudText,hudAction);d.body.appendChild(hud);
const source=()=>game.snapshot();
let proposal=null,session=null,receipt=null,armed=-1,readyWorld=null,invalid=null,queued=false;
function reachable(x,y){
 const box=island.getBoundingClientRect();
 if(!box.width||!box.height)return false;
 const px=box.left+box.width*x/100,py=box.top+box.height*y/100;
 for(const node of d.querySelectorAll('#world button,#world [data-memory]')){
  if(node.hidden)continue;
  const style=getComputedStyle(node);
  if(style.display==='none'||style.visibility==='hidden'||style.pointerEvents==='none')continue;
  const r=node.getBoundingClientRect();
  if(r.width&&r.height&&px>=r.left-6&&px<=r.right+6&&py>=r.top-6&&py<=r.bottom+6)return false;
 }
 return true;
}
function displayPlan(){
 const c=t();trigger.textContent=c.trigger;title.textContent=c.title;eyebrow.textContent=c.eyebrow;
 intro.textContent=c.intro;note.textContent=c.note;start.textContent=c.start;
 close.setAttribute('aria-label',c.close);
 const world=source();proposal=core.plan(world,compass,legacy,reachable);
 timeline.replaceChildren();status.textContent='';
 const disabled=!!game.accountMode?.()||d.body.classList.contains('replay-mode')||
  pass.disabled||!['ready','handoff-only'].includes(proposal.status);
 if(game.accountMode?.())status.textContent=c.account;
 else if(d.body.classList.contains('replay-mode'))status.textContent=c.replay;
 else if(proposal.status==='budget-exhausted')status.textContent=c.budget;
 else if(proposal.status==='no-suitable-route')status.textContent=c.noSafe;
 else if(proposal.status==='unavailable'||proposal.status==='limited')status.textContent=c.unavailable;
 else if(proposal.steps.length<2)status.textContent=c.short;
 start.disabled=disabled||!!session;
 const steps=[...proposal.steps,{handoff:true}];
 for(let i=0;i<steps.length;i++){
  const step=steps[i],item=el('li','inherit-journey-task');
  item.append(el('span','inherit-journey-index',String(i+1).padStart(2,'0')));
  const info=el('div');
  info.append(el('strong','',step.handoff?c.pass:c.place+': '+(c.types[step.tool]||step.tool)));
  info.append(el('small','',step.handoff?c.handoff: c.point+': '+step.x.toFixed(1)+' / '+step.y.toFixed(1)+
   ' · '+c.links+': +'+step.expectedNewLinks));
  item.append(info);timeline.append(item);
 }
}
function hideMarker(){ghost.hidden=true;armed=-1;d.body.classList.remove('inherit-journey-armed')}
function end(){session=null;receipt=null;readyWorld=null;invalid=null;hideMarker();hud.hidden=true;start.disabled=false}
function progress(){return session?core.progress(session,source(),legacy):null}
function showHud(){
 if(!session&&!receipt&&!invalid){hud.hidden=true;hideMarker();return}
 const c=t();hud.hidden=false;stop.setAttribute('aria-label',c.cancel);
 if(receipt){
  hudStage.textContent=c.complete;
  hudText.textContent=receipt.status==='confirmed-server-response'?c.hudDone:c.hudLocal;
  hudAction.textContent=c.newPlan;hudAction.disabled=false;hideMarker();return;
 }
 if(invalid){
  hudStage.textContent=c.waiting;hudText.textContent=c.hudInvalid;
  hudAction.textContent=c.newPlan;hudAction.disabled=false;hideMarker();return;
 }
 const state=progress();
 if(state?.status==='invalidated'||state?.status==='unavailable'){
  invalid=state?.reason||'world-changed';session=null;showHud();return;
 }
 if(state.status==='ready-for-handoff'){
  hideMarker();readyWorld=source();
  hudStage.textContent=c.step+' '+(session.steps.length+1)+' / '+(session.steps.length+1);
  hudText.textContent=c.hudReady;hudAction.textContent=c.handoffAction;
  hudAction.disabled=false;return;
 }
 const i=state.completed,step=session.steps[i];if(!step){invalid='no-step';session=null;showHud();return}
 if(armed!==i)hideMarker();
 readyWorld=null;
 hudStage.textContent=c.step+' '+(i+1)+' / '+(session.steps.length+1);
 hudText.textContent=armed===i?c.hudArmed:c.hudAwaiting;
 hudAction.textContent=c.placeAction+' · '+(c.types[step.tool]||step.tool);
 hudAction.disabled=false;
}
function revealMarker(){
 if(!window.matchMedia?.('(max-width:740px)').matches)return;
 const stage=d.querySelector('#world'),r=ghost.getBoundingClientRect();
 const x=r.left+r.width/2,y=r.top+r.height/2;
 if(x<0||y<0||x>=innerWidth||y>=innerHeight||!d.elementFromPoint(x,y)?.closest('#world'))
  stage?.scrollIntoView({block:'start',behavior:'auto'});
}
function armNext(){
 if(!session)return;
 if(game.accountMode?.()||d.body.classList.contains('replay-mode')||pass.disabled){end();return}
 const state=progress();
 if(state?.status!=='awaiting-placement'){showHud();return}
 const step=session.steps[state.completed];
 const tool=d.querySelector('.tools [data-tool="'+step.tool+'"]')||
  d.querySelector('.catalog [data-extra="'+step.tool+'"]');
 if(!tool||tool.disabled){
  invalid='missing-tool';session=null;showHud();hudText.textContent=t().hudNoTool;return;
 }
 tool.click();
 // Selecting a tool must not spend a game action.
 if(progress()?.status!=='awaiting-placement'){end();return}
 armed=state.completed;
 ghost.style.left=step.x+'%';ghost.style.top=step.y+'%';ghost.hidden=false;
 d.body.classList.add('inherit-journey-armed');
 d.querySelector('#world')?.setAttribute('tabindex','-1');
 d.querySelector('#world')?.focus?.({preventScroll:true});
 requestAnimationFrame(revealMarker);showHud();
}
function open(){
 displayPlan();if(!dialog.open)dialog.showModal();
}
trigger.addEventListener('click',open);close.addEventListener('click',()=>dialog.close());
dialog.addEventListener('click',event=>{if(event.target===dialog)dialog.close()});
start.addEventListener('click',()=>{
 const current=source(),latest=core.plan(current,compass,legacy,reachable);
 if(game.accountMode?.()||d.body.classList.contains('replay-mode')||pass.disabled||
    latest.fingerprint!==proposal?.fingerprint){displayPlan();return}
 const started=core.begin(current,latest);
 if(!started){displayPlan();return}
 session=started;receipt=null;invalid=null;readyWorld=null;
 dialog.close();showHud();
});
stop.addEventListener('click',end);
hudAction.addEventListener('click',()=>{
 if(receipt||invalid){end();open();return}
 const state=progress();
 if(state?.status==='ready-for-handoff'){
  hideMarker();pass.focus({preventScroll:true});return;
 }
 armNext();
});
function check(){
 if(!session)return;
 if(game.accountMode?.()||d.body.classList.contains('replay-mode')){
  invalid='mode-changed';session=null;showHud();return;
 }
 const state=progress();
 if(state?.status==='invalidated'||state?.status==='unavailable'){
  invalid=state.reason||'world-changed';session=null;showHud();return;
 }
 if(state.status==='awaiting-placement'&&armed!==state.completed)hideMarker();
 showHud();
}
function schedule(){
 if(queued)return;queued=true;
 queueMicrotask(()=>{queued=false;check()});
}
const mutation=new MutationObserver(schedule);
const objects=d.querySelector('#objects'),gen=d.querySelector('#gen');
if(objects)mutation.observe(objects,{childList:true});
if(gen)mutation.observe(gen,{childList:true,subtree:true,characterData:true});
function committed(event){
 // Called by the existing trusted game handoff bridge only after the game
 // has already saved a generation; this display cannot influence its outcome.
 if(!session||!readyWorld)return false;
 const result=core.finish(session,readyWorld,source(),event,legacy);
 if(result.status==='unverified'){invalid='handoff-unverified';session=null;showHud();return false}
 receipt=result;session=null;readyWorld=null;hideMarker();showHud();return true;
}
window.InheritJourneyUI=Object.freeze({
 open,committed,refresh:()=>{trigger.textContent=t().trigger;if(dialog.open)displayPlan();if(!hud.hidden)showHud()},
 getPlan:()=>core.plan(source(),compass,legacy,reachable),
 getProgress:()=>receipt||progress()||(invalid?{status:'invalidated',reason:invalid}:null),
 isArmed:()=>!ghost.hidden
});
trigger.textContent=t().trigger;
})();
