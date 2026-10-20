/* INHERIT: research is entirely optional, local-only, never automatically uploaded. */
(()=>{
'use strict';
const d=document,core=window.InheritResearchCore,copy=window.InheritResearchCopy,game=window.InheritGame;
const journal=d.querySelector('.inherit-legacy-dialog');
if(!core||!copy||!game||!journal)return;
const lang=()=>{const v=window.InheritUI?.getLanguage?.();return copy[v]?v:'ru'};
const t=()=>copy[lang()];
const el=(tag,cls,value)=>{const n=d.createElement(tag);if(cls)n.className=cls;if(value!==undefined)n.textContent=value;return n};
const about=el('a','inherit-research-about');about.href='/games/inherit/pilot/index.html?lang=ru';
const panel=el('section','inherit-research-panel');panel.id='inherit-research-section';panel.dataset.noTranslate='';
panel.setAttribute('aria-labelledby','inherit-research-title');
const title=el('h3','inherit-research-title');title.id='inherit-research-title';
const intro=el('p','inherit-research-intro'),legacy=el('p','inherit-research-note');
const status=el('p','inherit-research-status');status.setAttribute('role','status');
const consent=el('div','inherit-research-consent'),consentLabel=el('label');
const checkbox=el('input');checkbox.type='checkbox';checkbox.checked=false;
const consentCaption=el('span');consentLabel.append(checkbox,consentCaption);
const enable=el('button','inherit-research-primary');enable.type='button';enable.disabled=true;
consent.append(consentLabel,enable);
const active=el('div','inherit-research-active');active.hidden=true;
const stats=el('div','inherit-research-stats'),scope=el('p','inherit-research-note');
const surveyHeading=el('h4','inherit-research-subtitle'),scale=el('p','inherit-research-note');
const survey=el('form','inherit-research-survey');const inputs={};
function addSelect(name,values){
 const label=el('label','inherit-research-field'),caption=el('span'),select=el('select');
 select.required=true;select.name=name;label.append(caption,select);survey.append(label);
 inputs[name]={caption,select,values};
}
for(const k of ['clarity','returnIntent','meaning'])addSelect(k,[1,2,3,4,5]);
addSelect('reason',core.REASONS);addSelect('priceCents',core.PRICE_OPTIONS);
const priceNote=el('p','inherit-research-note');
const submit=el('button','inherit-research-primary');submit.type='submit';
const message=el('p','inherit-research-status');message.setAttribute('role','status');
survey.append(priceNote,submit,message);
const actions=el('div','inherit-research-actions');
const exportBtn=el('button','inherit-research-export');exportBtn.type='button';
const erase=el('button','inherit-research-erase');erase.type='button';
actions.append(exportBtn,erase);
active.append(stats,scope,surveyHeading,scale,survey,actions);
panel.append(title,intro,legacy,about,status,consent,active);journal.appendChild(panel);
const nav=journal.querySelector('.inherit-cycle-nav');
const tab=el('button','inherit-cycle-nav-button');tab.type='button';
tab.addEventListener('click',()=>{panel.setAttribute('tabindex','-1');panel.scrollIntoView?.({block:'start',behavior:'instant'});panel.focus?.({preventScroll:true})});
nav?.appendChild(tab);
let storage=null,denied=false,record=null,previous=null,queued=false;
try{storage=window.localStorage}catch{denied=true}
const now=()=>new Date().toISOString(),today=()=>now().slice(0,10);
const local=()=>!game.accountMode?.();
function load(){
 if(!storage)return null;
 try{const raw=storage.getItem(core.KEY);return raw&&raw.length<=100000?core.normalize(JSON.parse(raw)):null}
 catch{denied=true;return null}
}
function save(next){
 if(!storage||!next)return false;
 try{storage.setItem(core.KEY,JSON.stringify(next));return true}
 catch{denied=true;return false}
}
function remove(){
 if(!storage)return false;
 try{storage.removeItem(core.KEY);return true}
 catch{denied=true;return false}
}
function id(){
 if(globalThis.crypto?.randomUUID)return crypto.randomUUID();
 if(!globalThis.crypto?.getRandomValues)return null;
 const a=new Uint8Array(20);crypto.getRandomValues(a);
 return Array.from(a,n=>n.toString(16).padStart(2,'0')).join('');
}
function emit(type,data){
 if(!record||denied||!local())return false;
 const next=core.record(record,type,now(),data);
 if(next&&save(next)){record=next;return true}
 return false;
}
function gameState(){
 const v=game.snapshot?.()||{};
 return {objects:Array.isArray(v.objects)?v.objects.length:0,pending:Array.isArray(v.pending)?v.pending.length:0,
 generation:Number.isSafeInteger(v.generation)?v.generation:0};
}
function observe(){
 const next=gameState(),prev=previous;previous=next;
 if(!prev||!record||!local())return;
 if(next.pending>prev.pending&&next.objects>prev.objects){
   if(emit('trace_placed',{pendingCount:Math.min(next.pending,100)})&&!record.events.some(e=>e.type==='first_trace_placed'))
     emit('first_trace_placed');
 }
 if(next.generation>prev.generation)
   emit('generation_advanced_observed',{generation:Math.min(next.generation,100000)});
}
function schedule(){if(queued)return;queued=true;queueMicrotask(()=>{queued=false;observe();render()})}
const observer=new MutationObserver(schedule);
const objects=d.querySelector('#objects'),generation=d.querySelector('#gen');
if(objects)observer.observe(objects,{childList:true});
if(generation)observer.observe(generation,{childList:true,subtree:true,characterData:true});
d.addEventListener('click',event=>{
 const target=event.target;if(!target?.closest||!record||!local())return;
 if(target.closest('.inherit-legacy-trigger'))emit('journal_opened');
 if(target.closest('.founder-preview-button'))emit('founder_preview_opened');
 const tile=target.closest('.inherit-cosmetic-tile:not(:disabled)');
 if(tile){
  const skin=['night','fern','aurora','copper'].find(s=>tile.classList.contains('inherit-cosmetic-tile--'+s));
  if(skin)emit('cosmetic_selected',{skin});
 }
},{capture:true});
checkbox.addEventListener('change',()=>{enable.disabled=!checkbox.checked||denied||!local()});
enable.addEventListener('click',()=>{
 if(!checkbox.checked||denied||!local())return;
 const code=id(),draft=core.create(code,now());
 if(!draft||!save(draft)){render();return}
 record=draft;previous=gameState();emit('session_opened');render();
});
erase.addEventListener('click',()=>{
 if(!remove()){render();return}
 record=null;previous=gameState();checkbox.checked=false;message.textContent=t().off;render();
});
exportBtn.addEventListener('click',()=>{
 if(!record)return;
 try{
  const result=core.exportConsent(record,now());
  const url=URL.createObjectURL(new Blob([JSON.stringify(result,null,2)],{type:'application/json'}));
  const link=el('a');link.href=url;link.download='inherit-pilot-'+today()+'.json';
  link.hidden=true;d.body.appendChild(link);link.click();link.remove();
  setTimeout(()=>URL.revokeObjectURL(url),1300);
 }catch{message.textContent=t().error}
});
survey.addEventListener('submit',event=>{
 event.preventDefault();if(!record||!local())return;
 const data={};
 for(const [key,item] of Object.entries(inputs)){
  if(!item.select.value){message.textContent=t().invalid;return}
  data[key]=key==='reason'?item.select.value:Number(item.select.value);
 }
 message.textContent=emit('survey_submitted',data)?t().saved:t().error;
 render();
});
function renderInputs(){
 const c=t(),labels={clarity:c.clarity,returnIntent:c.intent,meaning:c.meaning,reason:c.reason,priceCents:c.price};
 for(const [key,item] of Object.entries(inputs)){
  const old=item.select.value;item.caption.textContent=labels[key];item.select.replaceChildren();
  item.select.appendChild(new Option(c.choose,''));
  for(const v of item.values){
   const label=key==='reason'?c.reasons[v]:key==='priceCents'?c.prices[v]:String(v);
   item.select.appendChild(new Option(label,String(v)));
  }
  item.select.value=old;
 }
}
function counter(value,label){const row=el('div','inherit-research-stat');row.append(el('strong','',String(value)),el('small','',label));stats.append(row)}
function render(){
 const c=t(),account=!local(),s=record?core.summarize(record,today()):null;
 tab.textContent=c.tab;title.textContent=c.title;intro.textContent=c.intro;legacy.textContent=c.legacy;
 about.textContent=c.about;about.href='/games/inherit/pilot/index.html?lang='+lang();
 consentCaption.textContent=c.consent;enable.textContent=c.enable;
 status.textContent=account?c.account:denied?c.unavailable:record?c.on:c.off;
 consent.hidden=account||denied||!!record;
 enable.disabled=!checkbox.checked||denied||account;
 active.hidden=account||!record;
 if(!s||account)return;
 stats.replaceChildren();counter(s.days,c.days);counter(s.sessions,c.sessions);
 counter(s.counts.trace_placed,c.traces);counter(s.counts.generation_advanced_observed,c.generations);
 const d1=s.d1.eligible?(s.d1.returned?c.returned:c.notReturned):c.pending;
 const d7=s.d7.eligible?(s.d7.returned?c.returned:c.notReturned):c.pending;
 stats.append(el('p','inherit-research-retention',c.d1+': '+d1),el('p','inherit-research-retention',c.d7+': '+d7));
 scope.textContent=c.scope;surveyHeading.textContent=c.survey;scale.textContent=c.scale;
 renderInputs();priceNote.textContent=c.priceNote;submit.textContent=c.submit;
 exportBtn.textContent=c.export;erase.textContent=c.delete;
}
record=load();previous=gameState();if(record&&local())emit('session_opened');
window.InheritResearchUI=Object.freeze({refresh:render,enabled:()=>!!record,
 getSummary:()=>record?core.summarize(record,today()):null,
 getExport:()=>record?core.exportConsent(record,now()):null});
render();
// The public invitation opens the journal at the consent section, but never opts in.
try{
 if(new URLSearchParams(location.search).get('pilot')==='1'&&local()){
  const openJournal=d.querySelector('.inherit-legacy-trigger');
  if(openJournal&&!journal.open)openJournal.click();
  if(journal.open){panel.setAttribute('tabindex','-1');panel.scrollIntoView?.({block:'nearest',behavior:'instant'});panel.focus?.({preventScroll:true})}
 }
}catch{}
})();
