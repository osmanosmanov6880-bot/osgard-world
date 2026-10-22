/* INHERIT R10 — optional planner. Only the existing game buttons and the
   player's own later island click can place a real trace. No storage or IO. */
(()=>{
'use strict';
const d=document,core=window.InheritTraceCompassCore,legacy=window.InheritLegacyEngine,
 game=window.InheritGame,island=d.querySelector('#island'),tools=d.querySelector('.tools');
if(!core||!legacy||!game?.snapshot||!island||!tools)return;
const lang=()=>{const code=window.InheritUI?.getLanguage?.();return copy[code]?code:'ru'};
const copy={
 ru:{
 trigger:'✧ Компас следов',title:'Компас следов',eyebrow:'СПЛАНИРУЙ СЛЕДУЮЩИЙ ХОД',
 intro:'Найди место, где новый предмет может дополнить уже существующие. Прогноз вычислен по реальным следам острова и тем же правилам, что в «Наследии».',
 existing:'Связей сейчас',traces:'Следов на острове',prediction:'Предложений для хода',
 starter:'Начни с дерева. Затем поставь мох рядом — так появится первая роща.',
 none:'Подходящих новых сочетаний в проверенных местах нет. Можно свободно размещать предметы в другом месте.',
 limited:'В этом сохранении слишком много или недостаточно корректных объектов для быстрого прогноза. Игра продолжает работать.',
 unavailable:'Сведения о мире пока не подходят для планирования. Сохранения не меняются.',
 budget:'Лимит изменений поколения исчерпан. Передай поколение, чтобы продолжить.',
 replay:'Сейчас открыт просмотр прошлого. Вернись в настоящий мир, чтобы планировать новый ход.',
 choose:'Выбрать инструмент и подсветить место',close:'Закрыть',point:'Точка',newLinks:'новых связей',
 estimate:'Это только пример возможного размещения, не совершённый ход. Для настоящего следа нажми на остров рядом с золотой меткой. В аккаунтном мире дополнительно действуют права сервера.',
 updated:'Мир изменился, предложения пересчитаны. Проверь выбранное место.',
 selected:'Инструмент выбран. Нажми на золотую метку на острове, чтобы оставить настоящий след.',
 rules:{grove:'Тихая роща',waylight:'Освещённая тропа',garden:'Сад ветра',monument:'Арка памяти',waymark:'Дорога открытий',landmark:'Береговой маяк'},
 types:{tree:'Дерево',stone:'Камень',light:'Фонарь',path:'Тропа',flower:'Цветы',arch:'Арка',chime:'Колокольчик',moss:'Мох',cairn:'Насыпь',marker:'Указатель'}
 },
 en:{
 trigger:'✧ Trace compass',title:'Trace compass',eyebrow:'PLAN YOUR NEXT TRACE',
 intro:'Discover positions where a new object might complement what is already on the island. Predictions use real saved traces and the same rules as the Legacy journal.',
 existing:'Connections now',traces:'Recorded traces',prediction:'Suggested placements',
 starter:'Start with a tree. Then place moss nearby to make your first grove.',
 none:'No new link was found in the inspected positions. You may still place traces freely elsewhere.',
 limited:'Too many or invalid saved objects for a quick preview. The game itself is unaffected.',
 unavailable:'The available world state cannot be used for a preview. Nothing was changed.',
 budget:'This generation has no changes left. Pass it on before placing another trace.',
 replay:'You are viewing history. Return to the present world before planning a new move.',
 choose:'Choose this tool and mark a spot',close:'Close',point:'Position',newLinks:'potential connections',
 estimate:'Preview only, not a placed trace. Click the island near the golden mark to make a real move. Account-world placement still follows server permissions.',
 updated:'The world changed; predictions were recalculated. Choose a spot again.',
 selected:'Tool selected. Click the golden marker on the island to make a real move.',
 rules:{grove:'Quiet grove',waylight:'Lantern path',garden:'Wind garden',monument:'Memory arch',waymark:'Trail of discovery',landmark:'Shore beacon'},
 types:{tree:'Tree',stone:'Stone',light:'Lantern',path:'Path',flower:'Flowers',arch:'Arch',chime:'Wind chime',moss:'Moss',cairn:'Cairn',marker:'Marker'}
 },
 zh:{
 trigger:'✧ 痕迹罗盘',title:'痕迹罗盘',eyebrow:'规划下一道痕迹',
 intro:'探索放置新物件的可能位置，让它与已有物件形成联系。预测来自真实存档和「传承」中的相同规则。',
 existing:'当前联系',traces:'岛上痕迹',prediction:'建议放置方案',
 starter:'可以先种一棵树，再在旁边放苔藓，形成第一片树林。',
 none:'在已检查的位置没有发现新的组合。仍可自由放置其他物件。',
 limited:'存档物件过多或不符合校验，无法快速预测。游戏不受影响。',
 unavailable:'当前世界状态不适合预测，存档不会改变。',
 budget:'本世代的行动额度已用完。请先传承世代。',
 replay:'当前正在查看过去。请先返回当前世界，再规划下一步。',
 choose:'选择工具并标记位置',close:'关闭',point:'位置',newLinks:'可能新增联系',
 estimate:'这只是预览，不是真实放置。点击岛上的金色标记附近，才能留下真实痕迹。账号世界仍受服务器权限控制。',
 updated:'世界已改变，预测已重新计算，请再次选择。',
 selected:'已选择工具。点击岛上的金色标记才能真正放置。',
 rules:{grove:'宁静树林',waylight:'灯光小径',garden:'风之花园',monument:'记忆拱门',waymark:'发现之路',landmark:'海岸灯标'},
 types:{tree:'树木',stone:'石头',light:'灯笼',path:'道路',flower:'花朵',arch:'拱门',chime:'风铃',moss:'苔藓',cairn:'石堆',marker:'路标'}
 }
};
const el=(tag,cls,value)=>{
 const node=d.createElement(tag);if(cls)node.className=cls;
 if(value!==undefined)node.textContent=String(value);return node;
};
const trigger=el('button','inherit-compass-trigger');trigger.type='button';trigger.dataset.noTranslate='';
tools.appendChild(trigger);
const dialog=el('dialog','inherit-compass-dialog');
dialog.dataset.noTranslate='';dialog.setAttribute('aria-labelledby','inherit-compass-title');
const top=el('div','inherit-compass-heading'),labels=el('div');
const eyebrow=el('p','inherit-compass-eyebrow'),title=el('h2','inherit-compass-title');
title.id='inherit-compass-title';
const close=el('button','inherit-compass-close','×');close.type='button';
labels.append(eyebrow,title);top.append(labels,close);
const intro=el('p','inherit-compass-intro'),stats=el('div','inherit-compass-stats');
const status=el('p','inherit-compass-status');status.setAttribute('role','status');status.setAttribute('aria-live','polite');
const candidates=el('div','inherit-compass-candidates');
const use=el('button','inherit-compass-use');use.type='button';
const note=el('p','inherit-compass-note');
dialog.append(top,intro,stats,status,candidates,use,note);
d.body.appendChild(dialog);
const ghost=el('span','inherit-compass-ghost');ghost.hidden=true;
ghost.setAttribute('aria-hidden','true');island.appendChild(ghost);
let plan=null,selected=0,signature='',armed=false;
const source=()=>game.snapshot();
const fingerprint=world=>JSON.stringify({g:world.generation,b:world.budget,objects:world.objects});
function dismiss(){dialog.close()}
function resetGhost(){ghost.hidden=true;armed=false;d.body.classList.remove('inherit-compass-armed')}
// On phones the action dock is fixed above the island. Native <dialog> returns
// focus to its dock trigger on close and can leave the chosen position beneath
// the dock. Only after the player arms a real choice do we reveal the island.
// This never clicks it, spends budget, or alters saved coordinates.
function revealArmedWorld(){
 if(!armed||ghost.hidden)return;
 const stage=d.querySelector('#world');
 if(!stage)return;
 const marker=ghost.getBoundingClientRect(),x=marker.left+marker.width/2,y=marker.top+marker.height/2;
 const top=x>=0&&x<innerWidth&&y>=0&&y<innerHeight?d.elementFromPoint(x,y):null;
 // The native dialog restores focus to its toolbar trigger, which can scroll
 // the proposed world coordinate offscreen even on desktop. Return to the
 // genuine gameplay hit region; never place an object programmatically.
 stage.scrollIntoView({block:'start',inline:'nearest',behavior:'instant'});
}
function labelFor(rule,c){return c.rules[rule.id]||rule.id}
function addStat(value,label){const item=el('div','inherit-compass-stat');item.append(el('strong','',value),el('small','',label));stats.append(item)}
function render(){
 const c=copy[lang()];
 trigger.textContent=c.trigger;title.textContent=c.title;eyebrow.textContent=c.eyebrow;
 intro.textContent=c.intro;close.setAttribute('aria-label',c.close);
 note.textContent=c.estimate;use.textContent=c.choose;
 stats.replaceChildren();candidates.replaceChildren();
 let world=source();
 if(d.body.classList.contains('replay-mode')){
  plan={status:'replay',choices:[]};status.textContent=c.replay;use.disabled=true;return;
 }
 signature=fingerprint(world);plan=core.predict(world,legacy);
 addStat(plan.objects??0,c.traces);
 addStat(plan.baseline??0,c.existing);
 const count=plan.choices.length;
 addStat(count,c.prediction);
 const emptyTexts={limited:c.limited,unavailable:c.unavailable,'budget-exhausted':c.budget,'no-synergy':c.none,'first-trace':c.starter};
 status.textContent=emptyTexts[plan.status]||'';
 if(!count){use.disabled=true;return}
 selected=Math.max(0,Math.min(selected,count-1));
 for(let n=0;n<count;n++){
  const choice=plan.choices[n],button=el('button','inherit-compass-option');
  button.type='button';button.dataset.index=String(n);button.setAttribute('aria-pressed',String(n===selected));
  const heading=el('strong','',c.types[choice.tool]||choice.tool);
  const details=el('small','',choice.rules.length?
   choice.rules.map(rule=>labelFor(rule,c)+(rule.delta>1?' ×'+rule.delta:'')).join(' · '):
   c.starter);
  const score=el('span','inherit-compass-option-score',choice.starter?'✧':'+'+choice.newLinks);
  const location=el('small','inherit-compass-coordinates',c.point+': '+choice.x.toFixed(1)+' / '+choice.y.toFixed(1));
  button.append(heading,details,location,score);
  button.addEventListener('click',()=>{selected=n;updateChoice()});
  candidates.append(button);
 }
 updateChoice();
}
function updateChoice(){
 if(!plan?.choices?.length)return;
 const choice=plan.choices[selected];
 for(const item of candidates.querySelectorAll('button'))
  item.setAttribute('aria-pressed',String(Number(item.dataset.index)===selected));
 ghost.hidden=false;ghost.style.left=choice.x+'%';ghost.style.top=choice.y+'%';
 use.disabled=false;
}
trigger.addEventListener('click',()=>{selected=0;resetGhost();render();dialog.showModal()});
close.addEventListener('click',dismiss);
dialog.addEventListener('click',event=>{if(event.target===dialog)dismiss()});
dialog.addEventListener('close',()=>{
 // A preview pin only persists if the user actually selected a tool.
 if(!armed)resetGhost();
});
use.addEventListener('click',()=>{
 const world=source();
 if(fingerprint(world)!==signature){selected=0;render();status.textContent=copy[lang()].updated;return}
 const choice=plan?.choices?.[selected];
 if(!choice)return;
 const button=d.querySelector('.tools [data-tool="'+choice.tool+'"]')||
  d.querySelector('.catalog [data-extra="'+choice.tool+'"]');
 if(!button){status.textContent=copy[lang()].unavailable;return}
 button.click();armed=true;d.body.classList.add('inherit-compass-armed');dismiss();
 d.querySelector('#world')?.focus?.({preventScroll:true});
 // Run after dialog focus restoration and the fixed mobile dock have settled.
 requestAnimationFrame(revealArmedWorld);
 game.notify?.(copy[lang()].selected);
});
const objects=d.querySelector('#objects'),gen=d.querySelector('#gen');
let queued=false;
function schedule(){
 if(queued)return;queued=true;
 queueMicrotask(()=>{
  queued=false;
  // A real world redraw supersedes the transient placement hint.
  resetGhost();if(dialog.open)render();
 });
}
const watcher=new MutationObserver(schedule);
if(objects)watcher.observe(objects,{childList:true});
if(gen)watcher.observe(gen,{childList:true,characterData:true,subtree:true});
window.InheritTraceCompassUI=Object.freeze({
 open:()=>trigger.click(),refresh:()=>{if(dialog.open)render();else trigger.textContent=copy[lang()].trigger},
 getPlan:()=>core.predict(source(),legacy),isArmed:()=>armed
});
trigger.textContent=copy[lang()].trigger;
})();
