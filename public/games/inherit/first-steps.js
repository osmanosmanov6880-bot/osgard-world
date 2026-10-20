/* The first trace is a real gameplay action, not a simulated onboarding reward. */
(()=>{
'use strict';
const d=document,game=window.InheritGame,world=d.querySelector('#world');
if(!game||!world)return;
const KEY='inherit:welcome-completed:v2';
const copy={
 ru:{title:'Первый след',one:'1. Выберите предмет',two:'2. Оставьте след на острове',three:'3. Передайте след следующему поколению',
 select:'Выбрать дерево',place:'Перейти к острову',pass:'Перейти к передаче',skip:'Пропустить',
 detail:'Нажмите на остров или используйте Enter. Это настоящий игровой ход.',hint:'Передача происходит только после вашего подтверждения.'},
 en:{title:'Your first trace',one:'1. Choose an object',two:'2. Place a trace on the island',three:'3. Pass it to the next generation',
 select:'Choose a tree',place:'Focus the island',pass:'Go to pass control',skip:'Skip guide',
 detail:'Click the island or press Enter. This is a real game action.',hint:'A generation is passed only when you confirm it.'},
 zh:{title:'第一道痕迹',one:'1. 选择物件',two:'2. 在岛上留下痕迹',three:'3. 传承给下一代',
 select:'选择树',place:'定位到小岛',pass:'定位传承按钮',skip:'跳过引导',
 detail:'点击岛屿或按 Enter，才会真正留下痕迹。',hint:'只有你确认后，世代才会传承。'}
};
const language=()=>{const value=window.InheritUI?.getLanguage?.();return copy[value]?value:'ru'};
const el=(tag,cls,value)=>{const n=d.createElement(tag);if(cls)n.className=cls;if(value!==undefined)n.textContent=value;return n};
const panel=el('aside','inherit-first-steps');panel.dataset.noTranslate='';panel.setAttribute('aria-labelledby','inherit-first-steps-title');
const title=el('h2','inherit-first-steps-title');title.id='inherit-first-steps-title';
const progress=el('div','inherit-first-steps-progress'),desc=el('p','inherit-first-steps-description');
const actions=el('div','inherit-first-steps-actions');
const primary=el('button','inherit-first-steps-primary');primary.type='button';
const skip=el('button','inherit-first-steps-skip');skip.type='button';
actions.append(primary,skip);panel.append(title,progress,desc,actions);world.appendChild(panel);
let stored=false,selected=false,started=false,previousGeneration=null,hidden=false,queued=false;
try{stored=window.localStorage?.getItem(KEY)==='yes'}catch{}
function persist(){
 hidden=true;
 try{window.localStorage?.setItem(KEY,'yes')}catch{}
}
function state(){const v=game.snapshot?.()||{};return {generation:Number.isSafeInteger(v.generation)?v.generation:0,
 pending:Array.isArray(v.pending)?v.pending.length:0,objects:Array.isArray(v.objects)?v.objects.length:0}}
function step(v){return v.pending>0?3:selected?2:1}
function action(){
 const v=state();
 if(step(v)===1){
  const tool=d.querySelector('.tools [data-tool="tree"]');
  tool?.click();selected=true;render();return;
 }
 if(step(v)===2){
  world.setAttribute('tabindex','-1');world.focus?.({preventScroll:true});return;
 }
 const pass=d.querySelector('#pass');pass?.focus?.({preventScroll:true});
}
primary.addEventListener('click',action);
skip.addEventListener('click',()=>{persist();render()});
function render(){
 const v=state(),c=copy[language()];
 if(previousGeneration===null)previousGeneration=v.generation;
 if(v.pending>0)started=true;
 if(started&&v.generation>previousGeneration&&v.pending===0)persist();
 previousGeneration=v.generation;
 // A pre-existing world or an account world is not a first-time blank island.
 panel.hidden=stored||hidden||!!game.accountMode?.()||(!started&&v.objects>0);
 if(panel.hidden)return;
 const n=step(v);
 title.textContent=c.title;progress.textContent=n===1?c.one:n===2?c.two:c.three;
 desc.textContent=n===3?c.hint:c.detail;
 primary.textContent=n===1?c.select:n===2?c.place:c.pass;
 skip.textContent=c.skip;
 panel.dataset.step=String(n);
}
function update(){if(queued)return;queued=true;queueMicrotask(()=>{queued=false;render()})}
const mutation=new MutationObserver(update);
const objects=d.querySelector('#objects'),gen=d.querySelector('#gen');
if(objects)mutation.observe(objects,{childList:true});
if(gen)mutation.observe(gen,{childList:true,subtree:true,characterData:true});
window.InheritOnboarding=Object.freeze({refresh:render,getStep:()=>panel.hidden?0:step(state())});
render();
})();
