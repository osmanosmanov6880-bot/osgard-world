/* INHERIT: accessible, human-readable game UI. Presentation only:
   never changes game saves, permissions, player events or server state. */
(()=>{
'use strict';
const d=document;
const header=d.querySelector('.app > header'),dock=d.querySelector('.dock'),world=d.querySelector('#world');
if(!header||!dock||!world)return;
const storageKey='inherit:text-preference:v1';
const copy={
 ru:{
  increase:'А+ Ещё крупнее',decrease:'А− Обычный текст',
  bigger:'Увеличить текст игры',normal:'Вернуть обычный крупный шрифт',
  heading:'Три шага к новому поколению',
  steps:[
   {title:'Выбери предмет',detail:'Дерево, камень, фонарь или тропа'},
   {title:'Поставь на остров',detail:'Нажми на свободное место'},
   {title:'Передай поколение',detail:'Нажми большую золотую кнопку'}
  ],
  choose:'Начни с выбора предмета внизу страницы.',
  place:'Теперь нажми на остров, чтобы оставить настоящий след.',
  pass:'След поставлен. Передай поколение золотой кнопкой.',
  account:'Просмотр сохранённого мира. Возможность редактирования зависит от прав аккаунта.'
 },
 en:{
  increase:'A+ Larger text',decrease:'A− Standard text',
  bigger:'Increase game text size',normal:'Restore default readable text size',
  heading:'Three steps to the next generation',
  steps:[
   {title:'Choose an object',detail:'Tree, stone, lantern or path'},
   {title:'Place it on the island',detail:'Tap an open location'},
   {title:'Pass the generation',detail:'Press the large gold button'}
  ],
  choose:'Choose an object in the toolbar below to begin.',
  place:'Now tap the island to leave a real trace.',
  pass:'Your trace is placed. Pass the generation with the gold button.',
  account:'Viewing a saved world. Editing depends on your account permissions.'
 },
 zh:{
  increase:'A+ 放大文字',decrease:'A− 标准字号',
  bigger:'放大游戏文字',normal:'恢复清晰的默认文字大小',
  heading:'三步传承下一代',
  steps:[
   {title:'选择物件',detail:'树木、石头、灯笼或小路'},
   {title:'放到岛上',detail:'点击岛上空白处'},
   {title:'传承世代',detail:'点击醒目的金色按钮'}
  ],
  choose:'先在下方选择一个物件。',
  place:'现在点击岛屿，留下真实痕迹。',
  pass:'痕迹已留下。点击金色按钮传承世代。',
  account:'正在查看已保存的世界。修改权限由账号决定。'
 }
};
const lang=()=>{const v=window.InheritUI?.getLanguage?.();return copy[v]?v:(d.documentElement.lang||'ru').slice(0,2)in copy?(d.documentElement.lang||'ru').slice(0,2):'ru'};
const t=()=>copy[lang()];
const el=(tag,cls,text)=>{
 const n=d.createElement(tag);
 if(cls)n.className=cls;
 if(text!==undefined)n.textContent=String(text);
 return n;
};
// The default stylesheet is already legible. A+ is an additional opt-in size.
let extra=false;
try{extra=window.localStorage?.getItem(storageKey)==='extra'}catch{}
const button=el('button','inherit-text-toggle');
button.type='button';button.setAttribute('aria-pressed',String(extra));
header.appendChild(button);
function applyPreference(){
 d.body.dataset.inheritTextSize=extra?'extra':'regular';
 button.setAttribute('aria-pressed',String(extra));
 const c=t();
 button.textContent=extra?c.decrease:c.increase;
 button.setAttribute('aria-label',extra?c.normal:c.bigger);
 button.title=button.getAttribute('aria-label');
}
button.addEventListener('click',()=>{
 extra=!extra;
 try{if(extra)window.localStorage?.setItem(storageKey,'extra');else window.localStorage?.removeItem(storageKey)}catch{}
 applyPreference();
});
// A factual action explanation, always next to the REAL gameplay controls.
const rail=el('section','inherit-readable-steps');
rail.setAttribute('aria-label',t().heading);
const steps=t().steps.map((_,idx)=>{
 const item=el('div','inherit-readable-step');
 item.dataset.current='false';
 const num=el('span','inherit-readable-step-number',idx+1);
 num.setAttribute('aria-hidden','true');
 const copyWrap=el('div','inherit-readable-step-copy');
 const title=el('strong'),desc=el('small');
 copyWrap.append(title,desc);item.append(num,copyWrap);
 return {item,title,desc};
});
const status=el('p','inherit-readable-status');
status.setAttribute('role','status');status.setAttribute('aria-live','polite');
rail.append(...steps.map(entry=>entry.item),status);
dock.parentElement.insertBefore(rail,dock);
let selected=false,lastGeneration=null,currentStep=1,pendingRefresh=false;
const account=()=>{
 try{return new URLSearchParams(location.search).get('mode')==='account'||
  !!window.InheritAccount?.isAccountMode?.()||!!window.InheritGame?.accountMode?.()}catch{return false}
};
function readGame(){
 try{const s=window.InheritGame?.snapshot?.();return {
  generation:Number.isSafeInteger(s?.generation)?s.generation:0,
  pending:Array.isArray(s?.pending)?s.pending.length:0,
  changes:Array.isArray(s?.changes)?s.changes.length:0
 }}catch{return {generation:0,pending:0,changes:0}}
}
function refresh(){
 applyPreference();
 const c=t(),isAccount=account(),s=readGame();
 rail.hidden=isAccount;rail.setAttribute('aria-label',c.heading);
 if(isAccount)return;
 if(lastGeneration!==null&&s.generation!==lastGeneration)selected=false;
 lastGeneration=s.generation;
 currentStep=s.pending>0||s.changes>0?3:selected?2:1;
 steps.forEach((entry,index)=>{
  entry.title.textContent=c.steps[index].title;
  entry.desc.textContent=c.steps[index].detail;
  const active=currentStep===index+1;
  entry.item.dataset.current=String(active);
  if(active)entry.item.setAttribute('aria-current','step');
  else entry.item.removeAttribute('aria-current');
 });
 status.textContent=currentStep===3?c.pass:currentStep===2?c.place:c.choose;
}
function schedule(){
 if(pendingRefresh)return;
 pendingRefresh=true;
 queueMicrotask(()=>{pendingRefresh=false;refresh()});
}
d.addEventListener('click',event=>{
 const target=event.target;
 if(!(target instanceof Element))return;
 if(target.closest('.dock .tool,[data-extra]'))selected=true;
 schedule();
},true);
for(const query of ['#objects','#budget','#gen']){
 const target=d.querySelector(query);
 if(target)new MutationObserver(schedule).observe(target,{childList:true,subtree:true,characterData:true});
}
new MutationObserver(schedule).observe(d.documentElement,{attributes:true,attributeFilter:['lang']});
window.InheritReadableUI=Object.freeze({
 refresh,
 getStep:()=>rail.hidden?0:currentStep,
 getTextSize:()=>extra?'extra':'regular'
});
refresh();
})();