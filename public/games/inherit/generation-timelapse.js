/* INHERIT R8 — player-driven, read-only saved-generation time lapse.
 * No extra gameplay clicks, network requests, research logs, saves or purchases.
 * Autoplay is voluntary, pauses when hidden and respects reduced motion.
 */
(()=>{
'use strict';
const d=document,atlas=window.InheritGenerationAtlas,engine=window.InheritTimeLapseCore;
const game=window.InheritGame,dialog=d.querySelector('.inherit-atlas-dialog');
if(!atlas||!engine||!game?.snapshot||!dialog)return;
const copy={
 ru:{
  eyebrow:'ЖИВАЯ ИСТОРИЯ',title:'Остров сквозь поколения',
  intro:'Пролистай только те состояния, которые действительно сохранены. Между снимками нет выдуманных кадров.',
  previous:'Назад',next:'Вперёд',play:'Смотреть историю',pause:'Пауза',present:'К настоящему',
  sequence:'Кадр',of:'из',generation:'Поколение',snapshot:'Сохранённый снимок',current:'Текущее состояние (может содержать незавершённые ходы)',
  total:'Следов в состоянии',added:'Новых',removed:'Исчезло',same:'Сохранилось',
  first:'Первый доступный кадр: сравнивать пока не с чем.',
  one:'Доступно только одно настоящее состояние. Передай поколение, чтобы в сохранении появились другие кадры.',
  empty:'Исторические снимки отсутствуют. Игра не будет придумывать их.',
  adjacent:'Изменение между двумя соседними сохранёнными поколениями.',
  gap:'Между этими снимками отсутствуют сохранённые поколения: {n}. Промежуточная история неизвестна.',
  sameGen:'Архив и текущее состояние одного поколения могут различаться. Передача следующему игроку этим не подтверждается.',
  unavailable:'Некоторые старые снимки не вошли в архив или были отклонены как некорректные.',
  markers:'На карте показана выборка точек; числа учитывают все проверенные следы.',
  addedLegend:'Новые',removedLegend:'Исчезли',stableLegend:'Сохранились',
  baseLegend:'Сохранённые',quiet:'Автоматическое воспроизведение отключено настройкой уменьшения движения. Кадры можно листать вручную.',
  disclosure:'Это последовательность сохранённых состояний, не видеозапись чужих действий. Даты, авторы и промежуточные события не подтверждены.',
  stepAria:'Выберите сохранённый кадр истории',mapAria:'Карта реально сохранённых следов'
 },
 en:{
  eyebrow:'LIVING ARCHIVE',title:'The island through generations',
  intro:'Step through only the states that were actually saved. No intermediate moments are invented.',
  previous:'Previous',next:'Next',play:'Play history',pause:'Pause',present:'Jump to present',
  sequence:'Frame',of:'of',generation:'Generation',snapshot:'Saved snapshot',current:'Current state (may contain unfinished moves)',
  total:'Traces in frame',added:'Added',removed:'Gone',same:'Preserved',
  first:'Earliest available frame; no earlier evidence to compare.',
  one:'Only one genuine state is available. Pass a generation to make more saved frames.',
  empty:'No real frames available. The game will not invent a past.',
  adjacent:'Change between adjacent saved generations.',
  gap:'Saved frames are missing between these generations: {n}. Intermediate history is unknown.',
  sameGen:'The archived and current state can differ within the same generation. No handoff is established.',
  unavailable:'Some older frames are missing from the archive or were rejected as invalid.',
  markers:'Only a sample of points is drawn; counts include all validated traces.',
  addedLegend:'New',removedLegend:'Removed',stableLegend:'Unchanged',baseLegend:'Recorded',
  quiet:'Autoplay is disabled by your reduced-motion preference. You can step through manually.',
  disclosure:'A sequence of saved states, not a recording of another person’s actions. Dates, authors and intermediate events are unverified.',
  stepAria:'Choose a recorded generation frame',mapAria:'Map of genuinely saved traces'
 },
 zh:{
  eyebrow:'真实历史',title:'世代中的岛屿',
  intro:'仅浏览真实保存的岛屿状态，不会虚构中间画面。',
  previous:'上一个',next:'下一个',play:'播放历史',pause:'暂停',present:'返回当前',
  sequence:'画面',of:'共',generation:'世代',snapshot:'保存的快照',current:'当前状态（可能包含未完成的操作）',
  total:'此画面的痕迹',added:'新增',removed:'消失',same:'保留',
  first:'这是最早可用的画面，没有更早的记录可比较。',
  one:'目前只有一个真实状态。完成世代传承后才可能出现更多快照。',
  empty:'没有历史快照。游戏不会虚构过去。',
  adjacent:'两个相邻保存世代之间的变化。',
  gap:'中间缺少保存的世代：{n}。无法确定中间发生了什么。',
  sameGen:'同一世代的快照和当前状态可能不同；不能据此证明已传承给其他人。',
  unavailable:'部分较早的快照缺失或因数据无效而被排除。',
  markers:'地图只显示部分标记，数字包含全部已验证的痕迹。',
  addedLegend:'新增',removedLegend:'消失',stableLegend:'保留',baseLegend:'已保存',
  quiet:'根据减少动态效果的设置，自动播放已禁用。可以手动逐帧查看。',
  disclosure:'这是保存状态的顺序展示，不是他人操作的录像。日期、作者和中间事件尚未验证。',
  stepAria:'选择已保存的世代画面',mapAria:'真实保存的痕迹位置图'
 }
};
const language=()=>{const v=window.InheritUI?.getLanguage?.();return copy[v]?v:'ru'};
const words=()=>copy[language()];
const el=(tag,cls,value)=>{
 const node=d.createElement(tag);if(cls)node.className=cls;
 if(value!==undefined)node.textContent=String(value);
 return node;
};
const section=el('section','inherit-timelapse'),header=el('div','inherit-timelapse-head');
section.setAttribute('aria-labelledby','inherit-timelapse-title');
section.dataset.noTranslate='';
const titleBlock=el('div','inherit-timelapse-heading');
const eyebrow=el('p','inherit-timelapse-eyebrow'),title=el('h3','inherit-timelapse-title');
title.id='inherit-timelapse-title';
titleBlock.append(eyebrow,title);
const progress=el('span','inherit-timelapse-progress');
header.append(titleBlock,progress);
const intro=el('p','inherit-timelapse-intro'),toolbar=el('div','inherit-timelapse-toolbar');
const prev=el('button','inherit-timelapse-prev'),play=el('button','inherit-timelapse-play');
const next=el('button','inherit-timelapse-next'),present=el('button','inherit-timelapse-present');
for(const button of [prev,play,next,present])button.type='button';
toolbar.append(prev,play,next,present);
const control=el('label','inherit-timelapse-scrubber'),controlCaption=el('span'),range=el('input');
range.type='range';range.min='0';range.max='0';range.step='1';range.value='0';
control.append(controlCaption,range);
const info=el('div','inherit-timelapse-info'),frameTitle=el('strong','inherit-timelapse-frame');
const subtitle=el('p','inherit-timelapse-subtitle'),metrics=el('div','inherit-timelapse-metrics');
const warning=el('p','inherit-timelapse-warning');warning.setAttribute('role','status');
const legends=el('div','inherit-timelapse-legend'),map=el('div','inherit-timelapse-map');
map.setAttribute('role','img');
const mapNote=el('p','inherit-timelapse-map-note'),disclosure=el('p','inherit-timelapse-disclosure');
info.append(frameTitle,subtitle,metrics,warning);
section.append(header,intro,toolbar,control,info,legends,map,mapNote,disclosure);
const atlasStatus=dialog.querySelector('.inherit-atlas-status');
if(!atlasStatus)return;
dialog.insertBefore(section,atlasStatus);
let index=0,playing=false,timer=null,model=null,staleID=null;
const reducedMedia=typeof matchMedia==='function'?matchMedia('(prefers-reduced-motion: reduce)'):null;
const reduced=()=>!!reducedMedia?.matches;
const duration=1700;
function stop(){
 playing=false;
 if(timer!==null){clearTimeout(timer);timer=null}
}
function badge(value,label){
 const cell=el('div','inherit-timelapse-metric');cell.append(el('strong','',value),el('small','',label));return cell;
}
function paint(){
 const c=words();
 model=engine.create(game.snapshot(),index,atlas);
 const valid=model.status==='ok',last=Math.max(0,(model.frameCount||0)-1);
 if(valid)index=model.index;else index=0;
 eyebrow.textContent=c.eyebrow;title.textContent=c.title;intro.textContent=c.intro;
 progress.textContent=valid?c.sequence+' '+(index+1)+' '+c.of+' '+model.frameCount:'';
 controlCaption.textContent=c.stepAria;
 range.setAttribute('aria-label',c.stepAria);
 range.min='0';range.max=String(last);range.value=String(index);
 range.disabled=!valid||model.frameCount<2;
 prev.textContent='‹ '+c.previous;next.textContent=c.next+' ›';
 play.textContent=playing?c.pause:'▶ '+c.play;
 present.textContent=c.present;
 prev.disabled=!valid||index===0;next.disabled=!valid||index>=last;
 play.disabled=!valid||model.frameCount<2||reduced();
 present.disabled=!valid||index===last;
 play.setAttribute('aria-pressed',String(playing));
 disclosure.textContent=c.disclosure;
 if(!valid){
  frameTitle.textContent='';subtitle.textContent='';
  warning.textContent=c.empty;
  metrics.replaceChildren();legends.replaceChildren();map.replaceChildren();
  mapNote.textContent='';
  return;
 }
 frameTitle.textContent=c.generation+' '+model.frame.generation;
 subtitle.textContent=model.frame.source==='current'?c.current:c.snapshot;
 const change=model.changes;
 metrics.replaceChildren(
  badge(model.frame.total,c.total),
  badge(change?('+'+change.added):'—',c.added),
  badge(change?('−'+change.removed):'—',c.removed),
  badge(change?change.unchanged:'—',c.same)
 );
 const notices=[];
 if(model.frameCount<2)notices.push(c.one);
 if(model.transition==='first-available')notices.push(c.first);
 if(model.transition==='adjacent-saved-frames')notices.push(c.adjacent);
 if(model.transition==='same-generation')notices.push(c.sameGen);
 if(model.transition==='archive-gap')notices.push(c.gap.replace('{n}',String(model.missingGenerationCount)));
 if(model.unavailableRecords||model.archiveLimited)notices.push(c.unavailable);
 if(reduced())notices.push(c.quiet);
 warning.textContent=notices.join(' ');
 const parts=change?[
  ['added',c.addedLegend],['removed',c.removedLegend],['same',c.stableLegend]
 ]:[['baseline',c.baseLegend]];
 legends.replaceChildren(...parts.map(([kind,label])=>{
  const chip=el('span','inherit-timelapse-legend-item');
  const dot=el('i','inherit-timelapse-legend-dot inherit-timelapse-legend-dot--'+kind);
  dot.setAttribute('aria-hidden','true');chip.append(dot,el('span','',label));return chip;
 }));
 map.replaceChildren(...model.markers.map(point=>{
  const pin=el('i','inherit-timelapse-pin inherit-timelapse-pin--'+point.kind);
  pin.style.left=point.x+'%';pin.style.top=point.y+'%';
  pin.setAttribute('aria-hidden','true');return pin;
 }));
 map.setAttribute('aria-label',c.mapAria+' · '+c.generation+' '+model.frame.generation+
  ' · '+c.total+' '+model.frame.total);
 mapNote.textContent=model.markersTruncated?c.markers:'';
}
function schedule(){
 if(!playing)return;
 if(!dialog.open||d.hidden||reduced()){stop();paint();return}
 timer=setTimeout(()=>{
  timer=null;
  if(!playing||!dialog.open||d.hidden||reduced()){stop();paint();return}
  if(index>=model.frameCount-1){stop();paint();return}
  index++;
  if(index>=model.frameCount-1){stop();paint();return}
  paint();schedule();
 },duration);
}
function move(destination){
 stop();index=destination;paint();
}
prev.addEventListener('click',()=>move(index-1));
next.addEventListener('click',()=>move(index+1));
present.addEventListener('click',()=>move(Number.MAX_SAFE_INTEGER));
range.addEventListener('input',()=>move(Number(range.value)));
play.addEventListener('click',()=>{
 if(reduced()||!dialog.open)return;
 if(playing){stop();paint();return}
 const fresh=engine.create(game.snapshot(),index,atlas);
 if(fresh.status!=='ok'||fresh.frameCount<2)return;
 if(index>=fresh.frameCount-1)index=0;
 playing=true;paint();schedule();
});
dialog.addEventListener('close',()=>{stop();paint()});
d.addEventListener('visibilitychange',()=>{if(d.hidden){stop();paint()}});
window.addEventListener('pagehide',()=>{stop()});
if(reducedMedia?.addEventListener)reducedMedia.addEventListener('change',()=>{if(reduced())stop();paint()});
const gen=d.querySelector('#gen');
if(gen){
 const observer=new MutationObserver(()=>{
  if(dialog.open){stop();paint()}
 });
 observer.observe(gen,{childList:true,characterData:true,subtree:true});
}
function refresh(){
 if(!dialog.open){stop();index=0}
 paint();
}
window.InheritTimeLapseUI=Object.freeze({
 refresh,stop,selectFrame:value=>{move(value);return model},
 getModel:()=>engine.create(game.snapshot(),index,atlas),
 getState:()=>({index,playing,open:dialog.open})
});
paint();
})();
