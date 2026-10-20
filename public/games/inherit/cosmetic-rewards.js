/* INHERIT cosmetic rewards v1 — free unlocks derived from saved traces. */
(()=>{
'use strict';
const d=document,source=window.InheritWorldUI,store=window.InheritPersistence;
const journal=d.querySelector('.inherit-cycle-journal');
if(!source||!journal)return;
const key='inherit:cosmetic-view:v1';
const choices=[
 {id:'night',unlock:null},
 {id:'fern',unlock:'gardener'},
 {id:'aurora',unlock:'connected'},
 {id:'copper',unlock:'architect'}
];
const dict={
 ru:{title:'Внешний вид острова',desc:'Новые палитры открываются за настоящие действия. Они меняют только внешний вид на этом устройстве, не силы или права игрока.',
  locked:'Нужно открытие',active:'Выбрано',select:'Выбрать',storage:'Этот браузер не сохраняет настройки. Палитра действует только до закрытия вкладки.',
  names:{night:'Полуночный берег',fern:'Изумрудная роща',aurora:'Северное сияние',copper:'Золотые руины'}},
 en:{title:'Island appearances',desc:'Unlock new palettes through real play. They only change visuals on this device, never your powers or permissions.',
  locked:'Requires discovery',active:'Selected',select:'Choose',storage:'This browser cannot save preferences. The palette lasts for the open tab only.',
  names:{night:'Midnight coast',fern:'Emerald grove',aurora:'Northern lights',copper:'Golden ruins'}},
 zh:{title:'岛屿外观',desc:'通过真实游玩解锁新配色，仅改变此设备上的外观，不会改变能力或权限。',
  locked:'需要解锁',active:'已选择',select:'选择',storage:'当前浏览器无法保存偏好；配色仅在此标签页有效。',
  names:{night:'午夜海岸',fern:'翡翠树林',aurora:'北极光',copper:'金色遗迹'}}
};
const language=()=>{const x=window.InheritUI?.getLanguage?.();return dict[x]?x:'ru'};
const el=(tag,cls,text)=>{const x=d.createElement(tag);if(cls)x.className=cls;if(text!==undefined)x.textContent=text;return x};
const section=el('section','inherit-cosmetic-panel');section.dataset.noTranslate='';
section.setAttribute('aria-labelledby','inherit-cosmetic-heading');
const heading=el('h4','inherit-cycle-subtitle');heading.id='inherit-cosmetic-heading';
const intro=el('p','inherit-cosmetic-intro');
const grid=el('div','inherit-cosmetic-grid');
const hint=el('p','inherit-cosmetic-hint');
section.append(heading,intro,grid,hint);
const returnPanel=journal.querySelector('.inherit-return-section');
if(returnPanel)journal.insertBefore(section,returnPanel);else journal.append(section);
let preferred='night',storageDenied=false,initialized=false,scheduled=false;
try{const found=store?.getItem?.(key);if(choices.some(c=>c.id===found))preferred=found}catch{storageDenied=true}
function getEligible(state){return new Set((state?.milestones||[]).filter(m=>m.unlocked).map(m=>m.id))}
function render(){
 const state=source.getState(),unlocked=getEligible(state),c=dict[language()];
 heading.textContent=c.title;intro.textContent=c.desc;
 const selected=choices.find(o=>o.id===preferred);
 const canUse=selected&&!selected.unlock||selected&&unlocked.has(selected.unlock);
 d.body.dataset.inheritSkin=canUse?preferred:'night';
 grid.replaceChildren();
 for(const option of choices){
  const available=!option.unlock||unlocked.has(option.unlock);
  const active=d.body.dataset.inheritSkin===option.id;
  const tile=el('button','inherit-cosmetic-tile inherit-cosmetic-tile--'+option.id);tile.type='button';
  tile.disabled=!available;tile.setAttribute('aria-pressed',String(active));
  tile.setAttribute('aria-label',c.names[option.id]+(available?'':'. '+c.locked));
  tile.append(el('span','inherit-cosmetic-swatch'),el('strong','',c.names[option.id]),
   el('small','',available?(active?c.active:c.select):c.locked));
  tile.addEventListener('click',()=>{
   if(!available)return;
   preferred=option.id;
   try{if(store?.setItem?.(key,preferred)===false)storageDenied=true}
   catch{storageDenied=true}
   render();
  });
  grid.append(tile);
 }
 hint.textContent=storageDenied?c.storage:'';
}
function refresh(){if(scheduled)return;scheduled=true;queueMicrotask(()=>{scheduled=false;render()})}
const objects=d.querySelector('#objects');
if(objects)new MutationObserver(refresh).observe(objects,{childList:true});
window.InheritCosmeticUI=Object.freeze({refresh,getChoice:()=>d.body.dataset.inheritSkin});
render();
})();
