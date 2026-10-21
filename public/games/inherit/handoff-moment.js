/* INHERIT R7 — non-modal inheritance celebration triggered only by a
   successful game commit bridge. No storage, network, synthetic events or saves. */
(()=>{
'use strict';
const d=document,core=window.InheritHandoffMomentCore,game=window.InheritGame;
if(!core||!game?.snapshot)return;
const content={
 ru:{
  eyebrow:'ПЕРЕДАЧА ПОКОЛЕНИЯ',heading:'След остался. Мир продолжается.',
  statusAccount:'Сервер подтвердил завершение поколения в мире аккаунта. Это не означает, что другой игрок принял мир.',
  statusShared:'Сервер подтвердил передачу поколения в общем мире. Следующему человеку ещё предстоит его открыть.',
  statusLocal:'След сохранён в локальном мире. Подтверждение сервера неизвестно; это не доказанная публикация общего мира.',
  traces:'Оставлено следов',transition:'Переход',preserved:'Всего следов на острове',atlas:'Атлас поколений',
  history:'История мира',continue:'Продолжить',details:'Какие следы остались',
  close:'Закрыть сообщение',map:'Расположение новых следов',limit:'На карте показана часть следов; числа учитывают все переданные объекты.',
  note:'Данные взяты из завершённого игрового действия. Сообщение не добавляет предметы, не передаёт хранительство и не создаёт историю.',
  types:{tree:'Дерево',stone:'Камень',light:'Фонарь',path:'Тропа',flower:'Цветы',arch:'Арка',chime:'Колокольчик',moss:'Мох',cairn:'Насыпь',marker:'Указатель'}
 },
 en:{
  eyebrow:'GENERATION HANDED ON',heading:'Your traces remain. The world continues.',
  statusAccount:'The account-world generation was verified by the server. This does not mean another player has accepted custody.',
  statusShared:'The shared-world generation was confirmed by the server. A future visitor has not necessarily opened it.',
  statusLocal:'The traces are saved in your local world. Server confirmation is unknown; shared publication is not proven.',
  traces:'Traces passed',transition:'Generations',preserved:'Traces now on the island',atlas:'Generation atlas',
  history:'World history',continue:'Keep playing',details:'See the preserved traces',
  close:'Dismiss receipt',map:'New trace positions',limit:'The map shows a sample of traces; counts include all of them.',
  note:'Derived from a completed game action. This receipt does not place objects, transfer custody or create new history.',
  types:{tree:'Tree',stone:'Stone',light:'Lantern',path:'Path',flower:'Flowers',arch:'Arch',chime:'Chime',moss:'Moss',cairn:'Cairn',marker:'Marker'}
 },
 zh:{
  eyebrow:'世代传承完成',heading:'痕迹已留下，世界继续前行。',
  statusAccount:'服务器已验证账号世界的世代完成。但这并不代表另一名玩家已经接受管理权。',
  statusShared:'服务器已确认共享世界的世代传承，但下一位访客不一定已经进入。',
  statusLocal:'痕迹已在本地世界保存。服务器是否确认尚不清楚，无法证明共享世界已发布。',
  traces:'留下的痕迹',transition:'世代变化',preserved:'岛上痕迹总数',atlas:'世代图鉴',
  history:'世界历史',continue:'继续游玩',details:'查看保存的痕迹',
  close:'关闭消息',map:'新痕迹的位置',limit:'地图只显示部分痕迹；数字包含全部物件。',
  note:'仅根据已完成的游戏操作展示。不新增物件、不转让管理权，也不虚构历史。',
  types:{tree:'树木',stone:'石头',light:'灯笼',path:'小路',flower:'花朵',arch:'拱门',chime:'风铃',moss:'苔藓',cairn:'石堆',marker:'路标'}
 }
};
const language=()=>{const lang=window.InheritUI?.getLanguage?.();return content[lang]?lang:'ru'};
const tr=()=>content[language()];
const el=(tag,cls,value)=>{const node=d.createElement(tag);if(cls)node.className=cls;if(value!==undefined)node.textContent=String(value);return node};
const banner=el('aside','inherit-handoff-moment');
banner.hidden=true;banner.dataset.noTranslate='';banner.setAttribute('role','status');banner.setAttribute('aria-live','polite');
banner.setAttribute('aria-atomic','true');
const glint=el('div','inherit-handoff-glint');glint.setAttribute('aria-hidden','true');
const top=el('div','inherit-handoff-top'),eyebrow=el('p','inherit-handoff-eyebrow'),close=el('button','inherit-handoff-close','×');
close.type='button';top.append(eyebrow,close);
const heading=el('h2','inherit-handoff-title'),route=el('div','inherit-handoff-route');
const source=el('p','inherit-handoff-source'),summary=el('div','inherit-handoff-summary');
const controls=el('div','inherit-handoff-controls'),continueButton=el('button','inherit-handoff-continue');
continueButton.type='button';
const nextButton=el('button','inherit-handoff-next');nextButton.type='button';
controls.append(continueButton,nextButton);
const details=el('details','inherit-handoff-details');
const detailSummary=el('summary','inherit-handoff-details-trigger'),detailBody=el('div','inherit-handoff-detail-body');
const counts=el('div','inherit-handoff-counts'),mapTitle=el('p','inherit-handoff-map-title'),map=el('div','inherit-handoff-map');
map.setAttribute('role','img');const smallNote=el('p','inherit-handoff-map-note');
detailBody.append(counts,mapTitle,map,smallNote);details.append(detailSummary,detailBody);
const note=el('p','inherit-handoff-disclaimer');
banner.append(glint,top,heading,route,source,summary,controls,details,note);
d.body.appendChild(banner);
let current=null;
function stat(value,label){
 const block=el('div','inherit-handoff-stat');
 block.append(el('strong','',value),el('span','',label));return block;
}
function render(){
 if(!current)return;
 const c=tr(),account=current.verification==='account-server-confirmed',local=current.verification==='local-saved-server-unverified';
 banner.dataset.verification=current.verification;
 eyebrow.textContent=c.eyebrow;heading.textContent=c.heading;close.setAttribute('aria-label',c.close);
 route.textContent=c.transition+' · '+current.from+' → '+current.to;
 source.textContent=account?c.statusAccount:local?c.statusLocal:c.statusShared;
 summary.replaceChildren(stat(current.traceCount,c.traces));
 if(current.afterTotal!==null)summary.append(stat(current.afterTotal,c.preserved));
 continueButton.textContent=c.continue;nextButton.textContent=account?c.history:c.atlas;
 detailSummary.textContent=c.details;mapTitle.textContent=c.map;note.textContent=c.note;
 counts.replaceChildren(...current.counts.map(item=>{
   const chip=el('span','inherit-handoff-count');
   chip.append(el('i','',item.count),d.createTextNode(c.types[item.type]||item.type));return chip;
 }));
 map.replaceChildren(...current.markers.map(item=>{
   const point=el('i','inherit-handoff-pin');point.style.left=item.x+'%';point.style.top=item.y+'%';
   point.setAttribute('aria-hidden','true');return point;
 }));
 map.setAttribute('aria-label',c.map+': '+current.traceCount);
 smallNote.textContent=current.markersTruncated?c.limit:'';
}
function dismiss(){banner.hidden=true;details.open=false}
function committed(value){
 const receipt=core.create(value);
 if(!receipt)return false;
 current=receipt;render();details.open=false;banner.hidden=false;
 return true;
}
close.addEventListener('click',dismiss);
continueButton.addEventListener('click',()=>{
 dismiss();const world=d.querySelector('#world');world?.setAttribute('tabindex','-1');world?.focus?.({preventScroll:true});
});
nextButton.addEventListener('click',()=>{
 const account=current?.verification==='account-server-confirmed';
 dismiss();
 if(account)d.querySelector('#showHistory')?.click();
 else window.InheritAtlasUI?.open?.();
});
banner.addEventListener('keydown',event=>{if(event.key==='Escape'){dismiss();close.focus({preventScroll:true})}});
window.InheritHandoffMomentUI=Object.freeze({committed,refresh:render,dismiss,peek:()=>current});
})();
