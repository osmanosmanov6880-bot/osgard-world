(()=>{
'use strict';
const root=document;
const el=id=>root.getElementById(id);
const labels={completed:'Подтверждено',in_review:'В работе / CI',planned:'Запланировано'};
const filters={wave:'all',game:'all'};
const make=(tag,cls,text)=>{const x=root.createElement(tag);if(cls)x.className=cls;if(text!==undefined)x.textContent=String(text);return x};
function filterButtons(container,attribute,value){
  for(const button of container.querySelectorAll('button['+attribute+']'))button.setAttribute('aria-pressed',String(button.dataset[attribute.replace(/^data-/,'').replace(/-([a-z])/g,(_,c)=>c.toUpperCase())]===value));
}
function renderWaves(data){
 const host=el('waves');host.replaceChildren();
 const waves=data.waves.filter(w=>filters.wave==='all'||w.state===filters.wave);
 for(const wave of waves){
  const card=make('article','wave'),num=make('span','num',wave.id),body=make('div');
  body.append(make('h3','',wave.title),make('span','status '+wave.state,labels[wave.state]||wave.state),make('p','',wave.goal),make('p','evidence','Критерий готовности: '+wave.gate));
  if(wave.evidence)body.append(make('p','evidence','Доказательства: '+wave.evidence));
  card.append(num,body);host.append(card);
 }
 if(!waves.length)host.append(make('p','','Нет этапов с таким статусом.'));
}
function renderGames(data){
 const host=el('games');host.replaceChildren();
 const games=data.games.filter(g=>filters.game==='all'||(filters.game==='other'&&!['flagship','zion'].includes(g.group))||g.group===filters.game);
 for(const game of games){
  const card=make('article','game');
  const visual=make('a','game-visual');
  visual.href=game.route;
  visual.setAttribute('aria-label','Открыть '+game.title);
  const cover=make('img','game-cover');
  cover.alt='';
  cover.loading='lazy';
  cover.decoding='async';
  cover.width=1536;
  cover.height=864;
  cover.src=game.coverSmall;
  if(game.cover.endsWith('.webp')){
    cover.srcset=game.coverSmall+' 640w, '+game.cover+' 1536w';
    cover.sizes='(max-width:650px) 100vw, 50vw';
  }
  const emblem=make('img','game-emblem');
  emblem.src=game.icon;
  emblem.alt='';
  emblem.loading='lazy';
  emblem.decoding='async';
  emblem.width=68;
  emblem.height=68;
  visual.append(cover,emblem,make('span','art-tag','КОНЦЕПТ-АРТ'));
  card.append(visual,make('small','',game.id.toUpperCase()+' · ВОЛНА '+game.wave),make('h3','',game.title),make('p','','Цель: '+game.gameplay));
  const details=make('details'),summary=make('summary','','Художественное направление и эмблема');
  details.append(summary,make('p','','Референсы: '+game.reference),make('p','','Авторский знак: '+game.emblem),make('p','','Управление: '+game.controls),make('p','','Сохранение: '+game.saveBehavior),make('p','','Онлайн: '+game.networkBehavior));card.append(details);
  const link=make('a','','Открыть текущую игру ↗');link.href=game.route;card.append(link);host.append(card);
 }
 if(!games.length)host.append(make('p','','Нет игр в этой категории.'));
}
async function start(){
 try{
  const response=await fetch('/games/aaa-roadmap.v1.json',{cache:'no-store'});
  if(!response.ok)throw Error('HTTP '+response.status);
  const data=await response.json();
  if(data.schemaVersion!==1||data.games.length!==22||data.waves.length!==11)throw Error('Неполные данные');
  el('game-count').textContent=data.games.length;
  el('wave-count').textContent=data.waves.length;
  el('completed-count').textContent=data.waves.filter(w=>w.state==='completed').length;
  renderWaves(data);renderGames(data);
  for(const button of root.querySelectorAll('[data-wave-filter]'))button.addEventListener('click',()=>{
   filters.wave=button.dataset.waveFilter;
   for(const b of root.querySelectorAll('[data-wave-filter]'))b.setAttribute('aria-pressed',String(b===button));
   renderWaves(data);
  });
  for(const button of root.querySelectorAll('[data-game-filter]'))button.addEventListener('click',()=>{
   filters.game=button.dataset.gameFilter;
   for(const b of root.querySelectorAll('[data-game-filter]'))b.setAttribute('aria-pressed',String(b===button));
   renderGames(data);
  });
 }catch(error){el('waves').textContent='Не удалось прочитать дорожную карту: '+String(error.message||error);el('games').textContent='Игры доступны в основном каталоге /games/.'}
}
start();
})();