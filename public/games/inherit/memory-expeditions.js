/* INHERIT R12 — optional real-snapshot restoration expeditions.
 * Never places a trace by itself, spends budget, edits saves, connects to APIs,
 * grants rewards or asserts someone else's actions. */
(()=>{
'use strict';
const d=document,core=window.InheritMemoryExpeditions,atlas=window.InheritGenerationAtlas;
const legacy=window.InheritLegacyEngine,game=window.InheritGame;
const tools=d.querySelector('.tools'),island=d.querySelector('#island');
if(!core||!atlas||!legacy||!game?.snapshot||!tools||!island)return;
const copy={
 ru:{
  trigger:'✧ Экспедиции памяти',title:'Экспедиции памяти',eyebrow:'ВОССТАНОВИ ИСТОРИЮ НАСТОЯЩИМ ХОДОМ',
  intro:'Найди след из реального снимка прошлого. Можно вернуть похожий предмет в прежнее место или дополнить сохранившийся исторический след. Сама подсказка ничего не создаёт.',
  snapshot:'Последний подтверждённый снимком след: поколение',kindRestore:'Место из старого снимка',kindHonor:'Дополнить сохранившийся след',
  restore:'Раньше здесь был {type}. В текущем состоянии предмета такого типа рядом нет.',honor:'Снимок сохранил {anchor}. {tool} рядом может создать связь «{rule}».',
  labelTool:'Поставить',point:'Точка острова',take:'Выбрать инструмент и отметить место',
  open:'Изучить следы',none:'Все проверенные исторические места сейчас представлены. Новых выполнимых целей не найдено.',
  empty:'Пока нет настоящего снимка с историческими объектами. Оставь след и передай поколение, чтобы начать историю.',
  unavailable:'Состояние мира или архив не удаётся надёжно проверить. Никаких изменений не сделано.',
  limited:'История слишком велика для безопасного быстрого анализа на этом устройстве. Мир не изменён.',
  noBudget:'Бюджет поколения исчерпан. Продолжить можно после настоящей передачи поколения.',
  replay:'Открыт просмотр прошлого. Вернись к сегодняшнему острову перед размещением.',
  changed:'Мир изменился. Старую подсказку отменили; выбери новую цель.',
  noTool:'Такой предмет пока недоступен среди инструментов. Выбери другую экспедицию.',
  armed:'Инструмент выбран. Нажми на остров возле золотой отметки — только этот ход добавит предмет.',
  success:'Похожий след появился рядом с историческим местом. Это текущий игровой ход; передача поколения ещё не подтверждена.',
  focusPass:'Найти кнопку передачи',dismiss:'Понятно',close:'Закрыть экспедиции',
  manual:'Показана точка для настоящего игрового хода, не автоматическое размещение и не награда.',
  provenance:'История восстановлена только по сохранённым кадрам. Нельзя установить, кто оставил старый объект, когда он исчез и является ли новый объект тем же самым. В режиме аккаунта действуют серверные права.',
  limitNote:'Некоторые старые кадры отклонены или ограничены. Это не полная история всех игроков.',
  types:{tree:'Дерево',stone:'Камень',light:'Фонарь',path:'Тропа',flower:'Цветы',arch:'Арка',chime:'Колокольчик',moss:'Мох',cairn:'Насыпь',marker:'Указатель'},
  rules:{grove:'Тихая роща',waylight:'Освещённая тропа',garden:'Сад ветра',monument:'Арка памяти',waymark:'Дорога открытий',landmark:'Береговой маяк'}
 },
 en:{
  trigger:'✧ Memory expeditions',title:'Memory expeditions',eyebrow:'RECOVER THE PAST WITH A REAL MOVE',
  intro:'Find a trace from a genuinely saved earlier frame. Bring a similar object back to its old location or add a companion to a preserved historical trace. A preview never creates an object.',
  snapshot:'Last observed in a saved frame, generation',kindRestore:'A place in an earlier frame',kindHonor:'Complement a surviving trace',
  restore:'A {type} was recorded here. No matching trace is currently recorded nearby.',honor:'A saved frame contains {anchor}. A nearby {tool} could form the “{rule}” combination.',
  labelTool:'Place',point:'Island position',take:'Choose tool and mark the location',
  open:'Explore saved traces',none:'The inspected historic places are already represented. No eligible expeditions were found.',
  empty:'No genuine snapshot with historic objects is available yet. Place a trace and pass a real generation to begin an archive.',
  unavailable:'The world or archive could not be validated. No changes were made.',
  limited:'This archive is too large for safe quick analysis on this device. The world has not changed.',
  noBudget:'This generation has no budget left. Complete a real handoff before adding a trace.',
  replay:'You are viewing history. Return to today’s island before placing a trace.',
  changed:'The saved world changed; the preview was canceled. Choose an updated expedition.',
  noTool:'That object is not available among the current tools. Choose another expedition.',
  armed:'Tool selected. Click the island near the gold marker. Only a real move can create an object.',
  success:'A similar trace now appears near the saved site. This is a current move, not a confirmed generation handoff.',
  focusPass:'Find handoff button',dismiss:'Got it',close:'Close expeditions',
  manual:'The marker is a suggestion for a real player click, not an automatic placement or reward.',
  provenance:'Evidence comes only from saved world frames. Who placed an old trace, when it disappeared, or whether a new trace is the very same object is unknown. Account-world rights still apply.',
  limitNote:'Some old frames were limited or invalid. This is not a complete history of all players.',
  types:{tree:'Tree',stone:'Stone',light:'Lantern',path:'Path',flower:'Flowers',arch:'Arch',chime:'Chime',moss:'Moss',cairn:'Cairn',marker:'Marker'},
  rules:{grove:'Quiet grove',waylight:'Lit pathway',garden:'Wind garden',monument:'Memory arch',waymark:'Discovery road',landmark:'Shore beacon'}
 },
 zh:{
  trigger:'✧ 记忆远征',title:'记忆远征',eyebrow:'用真实的行动回应过去',
  intro:'从真实保存的旧快照里寻找痕迹。可以在旧地点放置类似的物件，或为保留下来的历史痕迹添加伙伴。预览不会创建物件。',
  snapshot:'最后出现在保存快照中的世代',kindRestore:'旧快照的地点',kindHonor:'补充保留的历史痕迹',
  restore:'过去这里保存过{type}，当前状态附近没有相同类型的痕迹。',honor:'旧快照中有{anchor}，附近的{tool}可能形成「{rule}」组合。',
  labelTool:'放置',point:'岛屿位置',take:'选择工具并标记位置',
  open:'浏览真实痕迹',none:'已检查的历史地点都已在当前世界中体现，暂无可执行的远征。',
  empty:'尚无包含历史物件的真实快照。留下痕迹并完成世代传承，才能建立档案。',
  unavailable:'无法可靠验证世界或档案数据，未修改任何内容。',
  limited:'历史数据过大，无法在当前设备上安全快速地分析。世界未改变。',
  noBudget:'当前世代的行动预算已用完，完成真实传承后再继续。',
  replay:'正在浏览过去，请先返回当前岛屿。',
  changed:'世界发生了变化，旧建议已撤销。请重新选择远征。',
  noTool:'当前工具中没有此物件，请选择另一项远征。',
  armed:'已选择工具。请点击金色标记附近的岛屿，只有真实行动才会放置物件。',
  success:'保存地点附近出现了类似的新痕迹。这只是当前行动，并非已确认的世代传承。',
  focusPass:'定位世代传承按钮',dismiss:'知道了',close:'关闭远征',
  manual:'这是建议的真实放置地点，不会自动放置，也不会给予奖励。',
  provenance:'证据仅来自已保存的世界快照。无法确定旧痕迹的作者、消失时间或新旧物件是否同一件。账号世界的权限规则仍然有效。',
  limitNote:'部分旧快照缺失或不符合要求，不能当作所有玩家的完整历史。',
  types:{tree:'树木',stone:'石头',light:'灯笼',path:'道路',flower:'花朵',arch:'拱门',chime:'风铃',moss:'苔藓',cairn:'石堆',marker:'路标'},
  rules:{grove:'宁静树林',waylight:'照明小径',garden:'风之花园',monument:'记忆之门',waymark:'探索之路',landmark:'海岸灯塔'}
 }
};
const lang=()=>{const x=window.InheritUI?.getLanguage?.();return copy[x]?x:'ru'};
const tr=()=>copy[lang()];
const format=(s,values={})=>String(s).replace(/\{(\w+)\}/g,(_,k)=>String(values[k]??''));
const el=(tag,cls,label)=>{
 const n=d.createElement(tag);if(cls)n.className=cls;
 if(label!==undefined)n.textContent=label;return n;
};
const trigger=el('button','inherit-expedition-trigger');
trigger.type='button';trigger.dataset.noTranslate='';trigger.setAttribute('aria-haspopup','dialog');
tools.appendChild(trigger);
const dialog=el('dialog','inherit-expedition-dialog');dialog.dataset.noTranslate='';
dialog.setAttribute('aria-labelledby','inherit-expedition-title');
const title=el('h2','inherit-expedition-title');title.id='inherit-expedition-title';
const eyebrow=el('p','inherit-expedition-eyebrow'),close=el('button','inherit-expedition-close','×');
close.type='button';const top=el('div','inherit-expedition-top'),titles=el('div');
titles.append(eyebrow,title);top.append(titles,close);
const intro=el('p','inherit-expedition-intro');
const status=el('p','inherit-expedition-status');status.setAttribute('role','status');
const content=el('div','inherit-expedition-layout');
const list=el('div','inherit-expedition-choices');list.setAttribute('role','group');
const preview=el('div','inherit-expedition-preview');
const site=el('div','inherit-expedition-site');site.setAttribute('role','img');
const anchor=el('span','inherit-expedition-site-anchor');const target=el('span','inherit-expedition-site-target');
anchor.setAttribute('aria-hidden','true');target.setAttribute('aria-hidden','true');site.append(anchor,target);
const goalTitle=el('h3','inherit-expedition-goal-title');
const goalText=el('p','inherit-expedition-goal-text');
const provenance=el('p','inherit-expedition-provenance'),subnote=el('p','inherit-expedition-subnote');
const use=el('button','inherit-expedition-use');use.type='button';
preview.append(goalTitle,site,goalText,use,subnote);
content.append(list,preview);
dialog.append(top,intro,status,content,provenance);d.body.appendChild(dialog);
const ghost=el('span','inherit-expedition-ghost');ghost.setAttribute('aria-hidden','true');
ghost.hidden=true;island.appendChild(ghost);
const confirm=el('aside','inherit-expedition-confirm');confirm.hidden=true;confirm.dataset.noTranslate='';
confirm.setAttribute('role','status');
const confirmText=el('p'),actions=el('div','inherit-expedition-confirm-actions');
const focusPass=el('button'),dismiss=el('button');
focusPass.type='button';dismiss.type='button';actions.append(focusPass,dismiss);
confirm.append(confirmText,actions);d.body.appendChild(confirm);
const snapshot=()=>game.snapshot();
const signature=world=>JSON.stringify({
 generation:world.generation,budget:world.budget,objects:world.objects,pending:world.pending
});
let plan=null,selected=0,plannedSignature='',armed=null,queued=false,lastResult=null;
function clearGhost(){
 armed=null;ghost.hidden=true;d.body.classList.remove('inherit-expedition-armed');
}
function options(){
 const c=tr(),goals=plan.goals||[];list.replaceChildren();
 for(let i=0;i<goals.length;i++){
  const goal=goals[i],item=el('button','inherit-expedition-option');item.type='button';
  item.dataset.index=String(i);item.setAttribute('aria-pressed',String(i===selected));
  const heading=el('strong','',goal.kind==='restore'?c.kindRestore:c.kindHonor);
  const label=el('span','',c.types[goal.anchor.tool]||goal.anchor.tool);
  const source=el('small','',c.snapshot+' '+goal.lastSeenGeneration);
  const detail=el('small','',c.labelTool+': '+(c.types[goal.tool]||goal.tool));
  item.append(heading,label,source,detail);
  item.addEventListener('click',()=>{selected=i;chooseView()});
  list.append(item);
 }
}
function chooseView(){
 const c=tr(),goal=plan?.goals?.[selected];
 if(!goal){preview.hidden=true;return}
 preview.hidden=false;
 for(const row of list.querySelectorAll('button'))row.setAttribute('aria-pressed',String(Number(row.dataset.index)===selected));
 goalTitle.textContent=goal.kind==='restore'?c.kindRestore:c.kindHonor;
 goalText.textContent=goal.kind==='restore'?
  format(c.restore,{type:c.types[goal.tool]||goal.tool}):
  format(c.honor,{anchor:c.types[goal.anchor.tool]||goal.anchor.tool,
   tool:c.types[goal.tool]||goal.tool,rule:c.rules[goal.rule]||goal.rule});
 site.setAttribute('aria-label',c.point+': '+goal.x.toFixed(1)+' / '+goal.y.toFixed(1));
 anchor.style.left=goal.anchor.x+'%';anchor.style.top=goal.anchor.y+'%';
 target.style.left=goal.x+'%';target.style.top=goal.y+'%';
 use.textContent=c.take;
 use.disabled=!plan.canPlace||d.body.classList.contains('replay-mode')||d.querySelector('#pass')?.disabled;
 subnote.textContent=c.manual;
}
function render(){
 const c=tr();trigger.textContent=c.trigger;
 title.textContent=c.title;eyebrow.textContent=c.eyebrow;intro.textContent=c.intro;
 provenance.textContent=c.provenance;close.setAttribute('aria-label',c.close);
 const world=snapshot();plannedSignature=signature(world);plan=core.derive(world,atlas,legacy);
 list.replaceChildren();preview.hidden=true;
 const msgs={'no-archive':c.empty,'no-opportunities':c.none,limited:c.limited,unavailable:c.unavailable};
 status.textContent=msgs[plan.status]||'';
 content.hidden=plan.status!=='opportunities';
 if(!content.hidden){
  selected=Math.max(0,Math.min(selected,plan.goals.length-1));
  if(d.body.classList.contains('replay-mode'))status.textContent=c.replay;
  else if(!plan.canPlace)status.textContent=c.noBudget;
  else if(plan.inspectionLimited||plan.rejectedFrames||plan.archiveLimited)status.textContent=c.limitNote;
  options();chooseView();
 }
 confirmText.textContent=c.success;focusPass.textContent=c.focusPass;dismiss.textContent=c.dismiss;
}
function revealWorld(){
 if(!window.matchMedia?.('(max-width:740px)').matches)return;
 const stage=d.querySelector('#world');
 const rect=ghost.getBoundingClientRect(),x=rect.left+rect.width/2,y=rect.top+rect.height/2;
 if(x<0||y<0||x>=innerWidth||y>=innerHeight||
  !d.elementFromPoint(x,y)?.closest('#world'))stage?.scrollIntoView({block:'start',behavior:'auto'});
}
function arm(){
 const current=snapshot(),goal=plan?.goals?.[selected],c=tr();
 if(!goal||plan.status!=='opportunities')return;
 if(signature(current)!==plannedSignature){selected=0;render();status.textContent=c.changed;return}
 if(current.budget===0){status.textContent=c.noBudget;return}
 if(d.body.classList.contains('replay-mode')||d.querySelector('#pass')?.disabled){
  status.textContent=d.body.classList.contains('replay-mode')?c.replay:c.unavailable;return;
 }
 const button=d.querySelector('.tools [data-tool="'+goal.tool+'"]')||
  d.querySelector('.catalog [data-extra="'+goal.tool+'"]');
 if(!button||button.disabled){status.textContent=c.noTool;return}
 button.click();
 // The only actual write must come from a separate click handled by INHERIT.
 const afterSelection=snapshot();
 if(signature(afterSelection)!==plannedSignature){render();status.textContent=c.changed;return}
 clearGhost();confirm.hidden=true;lastResult=null;
 armed={goal,before:afterSelection,signature:plannedSignature};
 ghost.style.left=goal.x+'%';ghost.style.top=goal.y+'%';ghost.hidden=false;
 d.body.classList.add('inherit-expedition-armed');
 dialog.close();
 d.querySelector('#world')?.focus?.({preventScroll:true});
 requestAnimationFrame(revealWorld);
 game.notify?.(c.armed);
}
trigger.addEventListener('click',()=>{clearGhost();selected=0;render();if(!dialog.open)dialog.showModal()});
close.addEventListener('click',()=>dialog.close());
dialog.addEventListener('click',event=>{if(event.target===dialog)dialog.close()});
use.addEventListener('click',arm);
focusPass.addEventListener('click',()=>d.querySelector('#pass')?.focus?.({preventScroll:true}));
dismiss.addEventListener('click',()=>{confirm.hidden=true});
function check(){
 if(armed){
  const current=snapshot();
  if(signature(current)!==armed.signature){
   const verified=core.verify(armed.goal,armed.before,current,legacy);
   clearGhost();
   if(verified.status==='observed-placement'){
    lastResult=verified;confirm.hidden=false;
    confirmText.textContent=tr().success;
    focusPass.textContent=tr().focusPass;dismiss.textContent=tr().dismiss;
   }else{
    lastResult=null;
    if(dialog.open){render();status.textContent=tr().changed}
   }
  }
 }
 if(dialog.open)render();else trigger.textContent=tr().trigger;
}
function schedule(){
 if(queued)return;queued=true;
 queueMicrotask(()=>{queued=false;check()});
}
const observer=new MutationObserver(schedule);
const objects=d.querySelector('#objects'),gen=d.querySelector('#gen');
if(objects)observer.observe(objects,{childList:true});
if(gen)observer.observe(gen,{childList:true,characterData:true,subtree:true});
window.InheritMemoryExpeditionsUI=Object.freeze({
 open:()=>trigger.click(),refresh:()=>{if(dialog.open)render();else{trigger.textContent=tr().trigger;if(!confirm.hidden){confirmText.textContent=tr().success;focusPass.textContent=tr().focusPass;dismiss.textContent=tr().dismiss}}},
 getPlan:()=>core.derive(snapshot(),atlas,legacy),getResult:()=>lastResult,isArmed:()=>!!armed
});
trigger.textContent=tr().trigger;
})();
