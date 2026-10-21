/* INHERIT R9 — inspect an existing island trace without placing or editing.
   Delegated capture protects existing game button handlers and spending. */
(()=>{
'use strict';
const d=document,engine=window.InheritTraceInspectorCore,game=window.InheritGame;
const objects=d.querySelector('#objects');
if(!engine||!game?.snapshot||!objects)return;
const content={
 ru:{
  title:'История одного следа',eyebrow:'АРХЕОЛОГИЯ ЖИВОГО ОСТРОВА',
  intro:'Нажми на след, чтобы увидеть то, что действительно известно о нём из текущего сохранения.',
  types:{tree:'Дерево',stone:'Камень',light:'Фонарь',path:'Тропа',flower:'Цветы',arch:'Арка',chime:'Колокольчик',moss:'Мох',cairn:'Каменная насыпь',marker:'Указатель'},
  rules:{grove:'Роща',waylight:'Освещённая тропа',garden:'Сад',monument:'Монумент',waymark:'Путевой знак',landmark:'Маяк'},
  launch:'Исследовать следы',prev:'Предыдущий',next:'Следующий',of:'из',
  index:'След №',generation:'Поколение',position:'Положение на острове',status:'Состояние',
  pending:'Это новое размещение ещё ожидает завершения поколения.',
  current:'Этот след присутствует в текущем сохранении. Дистанционное подтверждение здесь не проверяется.',
  uncertain:'Текущий черновик не удаётся точно соотнести с сохранёнными следами.',
  evidence:'Совпадения в сохранённых снимках',matches:'Снимков с совпадением',
  first:'Самое раннее совпадение',latest:'Последнее совпадение',none:'Сохранённые снимки пока не подтверждают совпадение этого типа и позиции.',
  unknown:'Неизвестно',warning:'Часть архива недоступна или повреждена. История может быть неполной.',
  combination:'Соседние сочетания',nearby:'Близкие предметы',noneNear:'Рядом нет других сохранённых следов в выбранном радиусе.',
  noneLink:'Совместимых пар рядом пока не найдено.',possible:'Возможные дополнения',
  nonePossible:'Для этого предмета пока нет описанных сочетаний.',
  comboNote:'Пары рассчитаны по фактической близости и правилам игры. Это не награда и не доказательство чьего-либо авторства.',
  radius:'Расстояние',limit:'Показана часть соседних следов. Подсчёт сделан по всему доступному состоянию.',
  disclosure:'Совпадение типа и координат в архиве не доказывает, что это один и тот же предмет, кто его оставил или когда он появился. Имена и даты не выдумываются. Просмотр ничего не меняет в мире.',
  atlas:'Открыть атлас',back:'Вернуться на остров',close:'Закрыть описание',
  unavailable:'Данные этого следа недоступны для проверки.',inspect:'Исследовать след: '
 },
 en:{
  title:'A trace and its history',eyebrow:'ARCHAEOLOGY OF A LIVING ISLAND',
  intro:'Select a trace to see what the currently saved world can actually establish.',
  types:{tree:'Tree',stone:'Stone',light:'Lantern',path:'Path',flower:'Flowers',arch:'Arch',chime:'Wind chime',moss:'Moss',cairn:'Stone cairn',marker:'Waymarker'},
  rules:{grove:'Grove',waylight:'Lit pathway',garden:'Garden',monument:'Monument',waymark:'Waymark',landmark:'Beacon'},
  launch:'Inspect traces',prev:'Previous',next:'Next',of:'of',
  index:'Trace #',generation:'Generation',position:'Island position',status:'State',
  pending:'This new placement is still awaiting a completed generation.',
  current:'This trace is in the current saved world. Remote confirmation is not established here.',
  uncertain:'This draft cannot be matched reliably to the stored world traces.',
  evidence:'Matches in saved snapshots',matches:'Snapshots with a match',
  first:'Earliest observed match',latest:'Most recent match',none:'No archived snapshot currently confirms this type and position.',
  unknown:'Unknown',warning:'Some archives are missing or invalid; the recorded history may be incomplete.',
  combination:'Nearby combinations',nearby:'Nearby traces',noneNear:'No other saved traces within the nearby radius.',
  noneLink:'No compatible pairing nearby yet.',possible:'Possible additions',
  nonePossible:'No pairing rule is defined for this trace type yet.',
  comboNote:'Pairs are based on actual saved proximity and existing game rules. They are not rewards or proof of authorship.',
  radius:'Distance',limit:'Only a selection of nearby traces is mapped. Counts use the available state.',
  disclosure:'Matching a type and location in two archives does not prove it is the same individual object, who left it or when it was created. No names or dates are invented. Inspection never edits the world.',
  atlas:'Open generation atlas',back:'Return to island',close:'Close trace inspector',
  unavailable:'This trace cannot be verified.',inspect:'Inspect trace: '
 },
 zh:{
  title:'一处痕迹的历史',eyebrow:'探寻真实保存的岛屿',
  intro:'选择岛上的痕迹，查看当前保存记录真正能够证明的信息。',
  types:{tree:'树木',stone:'石头',light:'灯笼',path:'小路',flower:'花朵',arch:'拱门',chime:'风铃',moss:'苔藓',cairn:'石堆',marker:'路标'},
  rules:{grove:'树林',waylight:'照亮的小路',garden:'花园',monument:'纪念碑',waymark:'路标',landmark:'灯塔'},
  launch:'查看岛屿痕迹',prev:'上一个',next:'下一个',of:'共',
  index:'痕迹编号',generation:'世代',position:'岛屿位置',status:'状态',
  pending:'这个新物件尚未完成世代传承。',
  current:'这个物件存在于当前保存的世界中，此处不能证明服务器已经确认。',
  uncertain:'无法准确匹配当前草稿与已保存的世界物件。',
  evidence:'保存快照中的匹配记录',matches:'匹配的快照数量',
  first:'最早匹配的世代',latest:'最近匹配的世代',none:'目前没有保存的快照能够确认同类型、同位置的匹配。',
  unknown:'未知',warning:'部分档案缺失或无效，历史可能不完整。',
  combination:'附近可组成的搭配',nearby:'附近的痕迹',noneNear:'附近范围内没有其他已保存物件。',
  noneLink:'附近暂时没有符合搭配规则的物件。',possible:'可尝试的搭配',
  nonePossible:'这个物件类型暂时没有相应的搭配规则。',
  comboNote:'搭配基于已保存的真实位置和游戏既有规则，不代表奖励或作者身份。',
  radius:'距离',limit:'地图仅显示部分相邻物件，统计包含所有可用记录。',
  disclosure:'两个快照中同类型、同坐标的匹配，无法证明它们是同一个物件，也无法证明是谁或何时创建的。不会虚构姓名和日期，查看不会修改世界。',
  atlas:'打开世代图鉴',back:'返回小岛',close:'关闭痕迹详情',
  unavailable:'无法验证该痕迹的信息。',inspect:'查看痕迹：'
 }
};
const lang=()=>{const x=window.InheritUI?.getLanguage?.();return content[x]?x:'ru'};
const tr=()=>content[lang()];
const el=(tag,klass,value)=>{
 const node=d.createElement(tag);
 if(klass)node.className=klass;
 if(value!==undefined)node.textContent=String(value);
 return node;
};
const launcher=el('button','inherit-trace-launcher');launcher.type='button';
const header=d.querySelector('.app > header');
const compact=typeof matchMedia==='function'?matchMedia('(max-width:740px)'):null;
function mountLauncher(){
 // The guide is created by interface.js at DOMContentLoaded. On narrow
 // screens use its visible actions row rather than crowding a no-wrap header.
 const dest=compact?.matches?(d.querySelector('.inherit-guide-actions')||header):header;
 if(dest&&launcher.parentElement!==dest)dest.appendChild(launcher);
}
mountLauncher();
d.addEventListener('DOMContentLoaded',mountLauncher,{once:true});
compact?.addEventListener?.('change',mountLauncher);
const dialog=el('dialog','inherit-trace-inspector');
dialog.dataset.noTranslate='';
dialog.setAttribute('aria-labelledby','inherit-trace-title');
dialog.setAttribute('aria-describedby','inherit-trace-intro');
const top=el('div','inherit-trace-top'),titles=el('div','inherit-trace-titles'),
 eyebrow=el('p','inherit-trace-eyebrow'),title=el('h2','inherit-trace-title'),close=el('button','inherit-trace-close','×');
title.id='inherit-trace-title';close.type='button';
titles.append(eyebrow,title);top.append(titles,close);
const intro=el('p','inherit-trace-intro');intro.id='inherit-trace-intro';
const navigation=el('div','inherit-trace-navigation');
const prev=el('button','inherit-trace-prev'),next=el('button','inherit-trace-next'),counter=el('span','inherit-trace-counter');
prev.type='button';next.type='button';navigation.append(prev,counter,next);
const summary=el('div','inherit-trace-summary'),status=el('p','inherit-trace-status');
status.setAttribute('role','status');
const layout=el('div','inherit-trace-layout'),mapPanel=el('section','inherit-trace-map-panel'),
 dataPanel=el('section','inherit-trace-data-panel');
const map=el('div','inherit-trace-map');map.setAttribute('role','img');
const legend=el('p','inherit-trace-map-caption');
const historyTitle=el('h3','inherit-trace-subtitle'),history=el('div','inherit-trace-history');
const connectionTitle=el('h3','inherit-trace-subtitle'),connections=el('div','inherit-trace-connections');
const possibilityTitle=el('h3','inherit-trace-subtitle'),possibilities=el('div','inherit-trace-possibilities');
const sourceNote=el('p','inherit-trace-disclosure');
const actions=el('div','inherit-trace-actions'),atlas=el('button','inherit-trace-atlas'),back=el('button','inherit-trace-back');
atlas.type='button';back.type='button';actions.append(atlas,back);
mapPanel.append(map,legend,historyTitle,history);
dataPanel.append(connectionTitle,connections,possibilityTitle,possibilities);
layout.append(mapPanel,dataPanel);
dialog.append(top,intro,navigation,summary,status,layout,sourceNote,actions);
d.body.appendChild(dialog);
let selectedIndex=null,selectedIdentity=null,selectedButton=null,last=null;
const label=(key,value)=>{const card=el('div','inherit-trace-fact');card.append(el('span','',key),el('strong','',value));return card};
const fmt=n=>Number(n).toFixed(1).replace(/\.0$/,'');
function paint(model){
 const c=tr(),item=model.selected;
 prev.textContent=c.prev;next.textContent=c.next;
 counter.textContent=(item.index+1)+' '+c.of+' '+model.currentTotal;
 prev.disabled=item.index===0;next.disabled=item.index>=model.currentTotal-1;
 eyebrow.textContent=c.eyebrow;
 title.textContent=c.types[item.type]+' · '+c.index+(item.index+1);
 close.setAttribute('aria-label',c.close);
 intro.textContent=c.intro;
 const state=model.draft===true?c.pending:model.draft===false?c.current:c.uncertain;
 summary.replaceChildren(
   label(c.generation,model.generation),
   label(c.position,fmt(item.x)+'% / '+fmt(item.y)+'%'),
   label(c.nearby,model.nearTotal),
   label(c.combination,model.connectionTotal)
 );
 status.textContent=state;
 historyTitle.textContent=c.evidence;connectionTitle.textContent=c.combination;possibilityTitle.textContent=c.possible;
 const e=model.evidence;
 history.replaceChildren(label(c.matches,e.matchedFrames),
   label(c.first,e.firstMatch===null?c.unknown:e.firstMatch),
   label(c.latest,e.latestMatch===null?c.unknown:e.latestMatch));
 if(e.firstMatch===null)history.append(el('p','inherit-trace-note',c.none));
 if(e.archiveLimited||e.rejected)history.append(el('p','inherit-trace-warning',c.warning));
 connections.replaceChildren();
 if(!model.connections.length)connections.append(el('p','inherit-trace-note',c.noneLink));
 else for(const result of model.connections){
  const line=el('div','inherit-trace-connection');
  line.append(el('strong','',c.rules[result.id]||result.id),
   el('span','',(c.types[result.otherType]||result.otherType)+' · '+c.radius+' '+fmt(result.distance)));
  connections.append(line);
 }
 if(model.connectionsTruncated)connections.append(el('p','inherit-trace-warning',c.limit));
 possibilities.replaceChildren();
 if(!model.possibilities.length)possibilities.append(el('p','inherit-trace-note',c.nonePossible));
 else for(const hint of model.possibilities){
  const line=el('div','inherit-trace-possibility');
  line.append(el('span','',(c.types[hint.type]||hint.type)+' · '+(c.rules[hint.id]||hint.id)),
    el('small','',c.radius+' ≤ '+fmt(hint.radius)));
  possibilities.append(line);
 }
 map.replaceChildren();
 for(const dot of model.mapPoints){
  const mark=el('i','inherit-trace-pin inherit-trace-pin--'+dot.kind);
  mark.setAttribute('aria-hidden','true');mark.style.left=dot.x+'%';mark.style.top=dot.y+'%';
  map.append(mark);
 }
 map.setAttribute('aria-label',c.position+': '+fmt(item.x)+'%, '+fmt(item.y)+'%. '+
  c.nearby+': '+model.nearTotal+'. '+c.combination+': '+model.connectionTotal);
 legend.textContent=model.mapTruncated?c.limit:c.comboNote;
 sourceNote.textContent=c.disclosure;
 atlas.textContent=c.atlas;atlas.disabled=!window.InheritAtlasUI?.open;
 back.textContent=c.back;
}
function identity(item){return item.type+'|'+item.x+'|'+item.y+'|'+item.ordinal}
function modelFor(index){return engine.inspect(game.snapshot(),index,window.InheritLegacyEngine)}
function dismiss(){if(dialog.open)dialog.close()}
function inspectIndex(index,button){
 if(typeof dialog.showModal!=='function')return false;
 const result=modelFor(index);
 if(result.status!=='ok'){game.notify?.(tr().unavailable);return false}
 if(!dialog.open)selectedButton=button||d.activeElement;
 selectedIndex=index;selectedIdentity=identity(result.selected);last=result;
 paint(result);
 if(!dialog.open)dialog.showModal();
 return true;
}
// Capture on the real objects container: the original game attaches an onclick
// to each button that opens a generic fictional memory. Stop it before it runs;
// no click reaches the world placement handler and no game state is written.
objects.addEventListener('click',event=>{
 const button=event.target?.closest?.('button.placed');
 if(!button||!objects.contains(button)||typeof dialog.showModal!=='function')return;
 const buttons=[...objects.querySelectorAll('button.placed')],index=buttons.indexOf(button);
 if(index<0)return;
 event.stopPropagation();event.preventDefault();
 inspectIndex(index,button);
},true);
launcher.addEventListener('click',()=>{
 const count=game.snapshot().objects?.length||0;if(count)inspectIndex(count-1,launcher);
});
prev.addEventListener('click',()=>{if(selectedIndex!==null&&selectedIndex>0)inspectIndex(selectedIndex-1,null)});
next.addEventListener('click',()=>{
 const size=game.snapshot().objects?.length||0;
 if(selectedIndex!==null&&selectedIndex<size-1)inspectIndex(selectedIndex+1,null);
});
function decorate(){
 const snapshot=game.snapshot(),buttons=objects.querySelectorAll('button.placed');
 const c=tr();
 for(let i=0;i<buttons.length;i++){
  const item=engine.normalize(snapshot.objects?.[i]);
  if(!item)continue;
  buttons[i].setAttribute('aria-label',c.inspect+(c.types[item.type]||item.type)+' '+(i+1));
  buttons[i].title=c.inspect+(c.types[item.type]||item.type);
 }
}
function refresh(){
 const snapshot=game.snapshot();launcher.textContent=tr().launch;
 launcher.disabled=!Array.isArray(snapshot.objects)||snapshot.objects.length===0;
 decorate();
 if(dialog.open&&selectedIndex!==null){
  const next=modelFor(selectedIndex);
  if(next.status!=='ok'||identity(next.selected)!==selectedIdentity){dismiss();return}
  last=next;paint(next);
 }
}
close.addEventListener('click',dismiss);
back.addEventListener('click',dismiss);
atlas.addEventListener('click',()=>{
 dismiss();window.InheritAtlasUI?.open?.();
});
dialog.addEventListener('click',event=>{if(event.target===dialog)dismiss()});
dialog.addEventListener('close',()=>{
 if(selectedButton?.isConnected)selectedButton.focus({preventScroll:true});
 selectedButton=null;
});
const observer=new MutationObserver(()=>queueMicrotask(refresh));
observer.observe(objects,{childList:true});
window.InheritTraceInspectorUI=Object.freeze({
 open:index=>inspectIndex(index,null),refresh,getModel:()=>selectedIndex===null?null:modelFor(selectedIndex),close:dismiss
});
refresh();
})();
