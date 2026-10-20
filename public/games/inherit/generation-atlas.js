/* A real, read-only journey through stored generations.
   Uses the exact current world snapshot; no IO or game-world mutation. */
(()=>{
'use strict';
const d=document,core=window.InheritGenerationAtlas,game=window.InheritGame;
const header=d.querySelector('.app > header');
if(!core||!game?.snapshot||!header)return;
const txt={
 ru:{
  trigger:'Атлас поколений',title:'Атлас поколений',eyebrow:'ТОЛЬКО НАСТОЯЩИЕ СОХРАНЁННЫЕ СЛЕДЫ',
  intro:'Сравни два состояния острова. Всё показанное вычислено из сохранённых объектов и снимков, без придуманных игроков или событий.',
  from:'Было',to:'Стало',current:'Текущее состояние',snapshot:'Снимок',generation:'Поколение',
  added:'Новых следов',removed:'Исчезло следов',same:'Сохранилось',net:'Изменение всего',
  empty:'Для сравнения нужны хотя бы два разных состояния. Оставь настоящий след и передай поколение, чтобы появился новый снимок.',
  pick:'Выбери два разных состояния.',before:'Было',after:'Стало',delta:'Изменение',type:'След',
  limit:'Часть ранних снимков или некорректных данных недоступна для сравнения. Итоги относятся только к проверенным состояниям.',
  pins:'На схеме показана часть точек. Числа выше охватывают все проверенные объекты.',
  privacy:'Нет записи в историю, обращения к серверу, изменения бюджета или доказательства авторства. Текущее состояние может содержать незавершённые действия.',
  addedLegend:'Новые',removedLegend:'Исчезнувшие',sameLegend:'Сохранившиеся',close:'Закрыть атлас',
  types:{tree:'Дерево',stone:'Камень',light:'Свет',path:'Тропа',flower:'Цветы',arch:'Арка',chime:'Колокольчик',moss:'Мох',cairn:'Насыпь',marker:'Указатель'}
 },
 en:{
  trigger:'Generation atlas',title:'Generation atlas',eyebrow:'ONLY REAL SAVED TRACES',
  intro:'Compare two island states. Everything here is derived from saved objects and snapshots, never imagined players or events.',
  from:'Before',to:'After',current:'Current state',snapshot:'Snapshot',generation:'Generation',
  added:'Traces added',removed:'Traces gone',same:'Unchanged',net:'Net change',
  empty:'You need two different saved states to compare. Place a real trace and pass the generation to create another snapshot.',
  pick:'Choose two different states.',before:'Before',after:'After',delta:'Change',type:'Trace',
  limit:'Some older snapshots or invalid entries were excluded. Totals apply only to valid saved states.',
  pins:'The map shows a sample of markers. The totals above count every validated object.',
  privacy:'No server request, game action, budget change or verified authorship. The current state may contain unfinished actions.',
  addedLegend:'Added',removedLegend:'Removed',sameLegend:'Preserved',close:'Close atlas',
  types:{tree:'Tree',stone:'Stone',light:'Light',path:'Path',flower:'Flower',arch:'Arch',chime:'Chime',moss:'Moss',cairn:'Cairn',marker:'Marker'}
 },
 zh:{
  trigger:'世代图鉴',title:'世代图鉴',eyebrow:'只展示真实保存的痕迹',
  intro:'比较两个岛屿状态。所有变化都来自保存的物件与快照，不会虚构玩家或事件。',
  from:'之前',to:'之后',current:'当前状态',snapshot:'快照',generation:'世代',
  added:'新增痕迹',removed:'消失痕迹',same:'保留痕迹',net:'净变化',
  empty:'至少需要两个不同的状态。留下真实痕迹并传承世代，才能生成新的快照。',
  pick:'请选择两个不同的状态。',before:'之前',after:'之后',delta:'变化',type:'痕迹',
  limit:'部分较早的快照或无效数据无法比较。结果只针对有效保存的状态。',
  pins:'地图只显示部分标记，上方数字涵盖所有已验证的物件。',
  privacy:'不会连接服务器、修改世界、扣除预算或验证作者身份。当前状态可能包含未完成的操作。',
  addedLegend:'新增',removedLegend:'消失',sameLegend:'保留',close:'关闭图鉴',
  types:{tree:'树木',stone:'石头',light:'灯光',path:'小路',flower:'花朵',arch:'拱门',chime:'风铃',moss:'苔藓',cairn:'石堆',marker:'路标'}
 }
};
const lang=()=>{const value=window.InheritUI?.getLanguage?.();return txt[value]?value:'ru'};
const t=()=>txt[lang()];
function el(tag,cls,text){
 const node=d.createElement(tag);if(cls)node.className=cls;
 if(text!==undefined)node.textContent=String(text);return node;
}
const trigger=el('button','inherit-atlas-trigger');trigger.type='button';
trigger.setAttribute('aria-haspopup','dialog');header.appendChild(trigger);
const dialog=el('dialog','inherit-atlas-dialog');dialog.setAttribute('aria-labelledby','inherit-atlas-title');
dialog.dataset.noTranslate='';
const head=el('div','inherit-atlas-heading');
const titles=el('div','inherit-atlas-titles'),eyebrow=el('p','inherit-atlas-eyebrow'),title=el('h2','inherit-atlas-title');
title.id='inherit-atlas-title';const close=el('button','inherit-atlas-close','×');
close.type='button';close.setAttribute('aria-label','Close atlas');titles.append(eyebrow,title);head.append(titles,close);
const intro=el('p','inherit-atlas-intro');
const controls=el('div','inherit-atlas-controls');
const fromLabel=el('label','inherit-atlas-field'),fromCaption=el('span'),fromSelect=el('select');
const toLabel=el('label','inherit-atlas-field'),toCaption=el('span'),toSelect=el('select');
fromSelect.setAttribute('aria-label','Older saved world state');toSelect.setAttribute('aria-label','Newer saved world state');
fromLabel.append(fromCaption,fromSelect);toLabel.append(toCaption,toSelect);
controls.append(fromLabel,toLabel);
const status=el('p','inherit-atlas-status');status.setAttribute('role','status');status.setAttribute('aria-live','polite');
const main=el('div','inherit-atlas-main'),view=el('section','inherit-atlas-view'),aside=el('section','inherit-atlas-details');
const stats=el('div','inherit-atlas-stats'),legend=el('div','inherit-atlas-legend'),map=el('div','inherit-atlas-map');
map.setAttribute('role','img');
const mapNote=el('p','inherit-atlas-map-note'),table=el('table','inherit-atlas-table'),thead=el('thead'),tbody=el('tbody');
const tableTitle=el('h3','inherit-atlas-subtitle');
table.append(thead,tbody);
const note=el('p','inherit-atlas-disclosure');
const limit=el('p','inherit-atlas-limit');
view.append(stats,legend,map,mapNote);aside.append(tableTitle,table,limit);
main.append(view,aside);dialog.append(head,intro,controls,status,main,note);
d.body.appendChild(dialog);
let previousFrom=null,previousTo=null,latestWorld=null;
function renderLanguage(){
 const c=t();trigger.textContent=c.trigger;title.textContent=c.title;eyebrow.textContent=c.eyebrow;intro.textContent=c.intro;
 fromCaption.textContent=c.from;toCaption.textContent=c.to;
 tableTitle.textContent=c.title;note.textContent=c.privacy;
 close.setAttribute('aria-label',c.close);
 const items=[['added',c.addedLegend],['removed',c.removedLegend],['same',c.sameLegend]];
 legend.replaceChildren(...items.map(([kind,label])=>{
  const item=el('span','inherit-atlas-legend-item'),dot=el('i','inherit-atlas-dot inherit-atlas-dot--'+kind);
  dot.setAttribute('aria-hidden','true');item.append(dot,el('span','',label));return item;
 }));
 const row=el('tr');for(const cell of [c.type,c.before,c.after,c.delta])row.append(el('th','',cell));
 thead.replaceChildren(row);
}
function options(frames){
 const c=t(),option=frame=>{
  const label=c.generation+' '+frame.generation+' · '+(frame.source==='current'?c.current:c.snapshot);
  const item=el('option','',label);item.value=frame.id;return item;
 };
 const hasFrom=frames.some(f=>f.id===previousFrom),hasTo=frames.some(f=>f.id===previousTo);
 fromSelect.replaceChildren(...frames.map(option));toSelect.replaceChildren(...frames.map(option));
 previousFrom=hasFrom?previousFrom:(frames[0]?.id||null);
 previousTo=hasTo?previousTo:(frames[frames.length-1]?.id||null);
 if(previousFrom)fromSelect.value=previousFrom;if(previousTo)toSelect.value=previousTo;
 const disabled=frames.length<2;fromSelect.disabled=disabled;toSelect.disabled=disabled;
}
function stat(label,value){
 const item=el('div','inherit-atlas-stat');item.append(el('span','',label),el('strong','',value));return item;
}
function render(){
 renderLanguage();
 const c=t(),world=game.snapshot();
 latestWorld=world;
 const frames=core.getFrames(world);
 options(frames.frames);
 const compared=core.compare(world,previousFrom,previousTo);
 main.hidden=compared.status!=='ok';
 status.textContent=compared.status==='ok'?'':frames.frames.length<2?c.empty:c.pick;
 if(compared.status!=='ok')return;
 const n=compared.totals;
 stats.replaceChildren(stat(c.added,'+'+n.added),stat(c.removed,'−'+n.removed),stat(c.same,n.unchanged),stat(c.net,(n.net>0?'+':'')+n.net));
 map.replaceChildren();
 for(const item of compared.pins){
  const dot=el('span','inherit-atlas-pin inherit-atlas-pin--'+item.kind);
  dot.style.left=item.x+'%';dot.style.top=item.y+'%';dot.setAttribute('aria-hidden','true');map.appendChild(dot);
 }
 map.setAttribute('aria-label',c.added+': '+n.added+'. '+c.removed+': '+n.removed+'. '+c.same+': '+n.unchanged);
 mapNote.textContent=compared.pinsTruncated?c.pins:'';
 tbody.replaceChildren();
 for(const item of compared.perType){
  const row=el('tr'),delta=(item.delta>0?'+':'')+item.delta;
  for(const value of [c.types[item.type]||item.type,item.before,item.after,delta])row.append(el('td','',value));
  tbody.appendChild(row);
 }
 if(!compared.perType.length){
  const row=el('tr'),cell=el('td','',c.empty);cell.colSpan=4;row.append(cell);tbody.appendChild(row);
 }
 limit.textContent=compared.limited||compared.skipped?c.limit:'';
}
function update(){
 previousFrom=fromSelect.value||previousFrom;previousTo=toSelect.value||previousTo;
 render();
}
function open(){
 previousFrom=null;previousTo=null;
 render();if(!dialog.open)dialog.showModal();
}
trigger.addEventListener('click',open);
close.addEventListener('click',()=>dialog.close());
fromSelect.addEventListener('change',update);toSelect.addEventListener('change',update);
dialog.addEventListener('click',event=>{if(event.target===dialog)dialog.close()});
const gen=d.querySelector('#gen');
if(gen){const observer=new MutationObserver(()=>{if(dialog.open)render()});observer.observe(gen,{childList:true,characterData:true,subtree:true})}
window.InheritAtlasUI=Object.freeze({open,refresh:()=>{if(dialog.open)render();else renderLanguage()},getModel:()=>core.compare(game.snapshot(),fromSelect.value||null,toSelect.value||null)});
renderLanguage();
})();
