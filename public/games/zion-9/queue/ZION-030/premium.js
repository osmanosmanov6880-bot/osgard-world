/* ZION-030 Premium UX v22: real interactive canvas and UI, not a screenshot. */
(function(){
'use strict';
const $=id=>document.getElementById(id);
const game=()=>window.ZION030_GAME;
const hot=[{x:-4,z:-3,temp:58},{x:2,z:2,temp:56},{x:4,z:-2,temp:54}];
const names={tree:"Городское дерево",shade:"Охлаждающий навес",water:"Дождевой сад"};
const desc={tree:"Создаёт тень и охлаждает пространство.",shade:"Затеняет поверхность и снижает нагрев.",water:"Растения и вода охлаждают город."};
const symbols={
tree:'<svg viewBox="0 0 110 110" aria-hidden="true"><defs><radialGradient id="leaf"><stop stop-color="#94FCA9"/><stop offset="1" stop-color="#21844D"/></radialGradient></defs><ellipse cx="55" cy="93" rx="32" ry="9" fill="#0F343D"/><path d="M54 52V88M54 70 35 52m19 10 19-16" stroke="#946D50" stroke-width="9" stroke-linecap="round"/><circle cx="55" cy="40" r="29" fill="#2A9556"/><circle cx="33" cy="48" r="23" fill="url(#leaf)"/><circle cx="77" cy="49" r="22" fill="#2E9F5A"/><circle cx="55" cy="21" r="21" fill="url(#leaf)"/><circle cx="72" cy="28" r="17" fill="#63D785"/><circle cx="46" cy="47" r="18" fill="#49BB6F"/></svg>',
shade:'<svg viewBox="0 0 110 110" aria-hidden="true"><ellipse cx="55" cy="94" rx="38" ry="9" fill="#123343"/><g stroke="#B9DDEC" stroke-width="5"><path d="M24 47V89M86 47V89M35 50V85M76 50V85"/></g><path d="m14 40 32-22 49 11-29 24-52-13Z" fill="#E6F5FD"/><path d="m14 40 52 13v9L14 49Z" fill="#80B9D4"/><path d="m66 53 29-24v9L66 62Z" fill="#579BBA"/><path d="m25 38 30-18M42 43l30-18" stroke="#FFF" stroke-opacity=".62" stroke-width="3"/></svg>',
water:'<svg viewBox="0 0 110 110" aria-hidden="true"><ellipse cx="55" cy="95" rx="40" ry="9" fill="#0F303D"/><path d="m11 79 44-17 44 17-44 18Z" fill="#7F969A"/><path d="m17 77 38-12 38 13-38 14Z" fill="#26767B"/><path d="M29 79Q30 39 22 27M44 78Q37 35 48 19M60 77Q75 35 69 21M74 79Q79 40 90 31M55 74Q55 29 58 15" stroke="#6DD878" stroke-width="5" stroke-linecap="round"/><path d="M31 74Q13 55 17 45M65 78Q91 59 90 46" stroke="#A6E57D" stroke-width="5" stroke-linecap="round"/><path d="M22 29h5m41-10h5m18 11h4" stroke="#F7CF95" stroke-width="4" stroke-linecap="round"/></svg>'
};
function element(tag,cls,html){const n=document.createElement(tag);if(cls)n.className=cls;if(html!==undefined)n.innerHTML=html;return n;}
const root=$('world-play'),stage=root?.querySelector('.stage'),layout=root?.querySelector('.layout'),panel=root?.querySelector('.panel'),hero=root?.querySelector('.hero');
if(!root||!stage||!layout||!panel||!hero)return;
document.documentElement.lang='ru';
document.title='Теневой протокол — охлади город | OSGARD PLAY';
root.classList.add('premium-mode');
hero.innerHTML=`<div class="premium-hero-copy"><div class="premium-kicker">АФИНЫ · ГОРОДСКАЯ СТРАТЕГИЯ</div><h1>ТЕНЕВОЙ <em>ПРОТОКОЛ</em></h1><strong>Охлади город за три хода.</strong><p>Выбери дерево, навес или сад. Нажми на красную зону и размести охлаждение рядом.</p></div><div class="premium-goal"><div><h2>◎ &nbsp; ЦЕЛЬ МИССИИ</h2><p>Охлади <b>3 горячие зоны</b> за <b>3 размещения</b>.</p><small>Условная цель игры: <b class="orange">60°C</b> → <b class="aqua">30°C</b></small></div><div class="goal-thermometers" aria-hidden="true"><span>♨<b>60°C</b></span><i>→</i><span>❄<b>30°C</b></span></div></div>`;
const left=element('aside','premium-mission',`<div class="mission-loc"><span>⌖</span> АФИНЫ, ГРЕЦИЯ <small>МИССИЯ 1/3</small></div><div class="athens-illustration" role="img" aria-label="Панорама вечерних Афин"></div>
<section class="mission-block"><h2><span class="sun">☀</span> ПОЧЕМУ ЖАРКО?</h2><p>Бетон нагревается. Деревьев и тени мало.</p></section>
<section class="mission-block"><h2><span class="cyan">◎</span> ТВОЯ ЗАДАЧА</h2><p>Охлади <b>все три красные точки</b>. У тебя только <b>три модуля</b>.</p></section>
<section class="mission-block"><h2>ТВОЙ ПРОГРЕСС</h2><div class="premium-progress"><div id="premiumRing" class="ring" aria-hidden="true"></div><div><strong id="premiumProgress">0 / 3</strong><small>Зон охлаждено</small></div></div></section>`);
layout.insertBefore(left,stage);
const toolList=panel.querySelector('.modules');
const heading=panel.querySelector('h2');
if(heading)heading.textContent='♧  ВЫБЕРИ ИНСТРУМЕНТ';
const sub=panel.querySelector('.sub');
if(sub)sub.textContent='Нажми на одну из трёх карточек.';
for(const button of toolList.querySelectorAll('.module')){
 const type=button.dataset.type;
 button.innerHTML='<span class="module-icon">'+symbols[type]+'</span><span class="module-info"><strong>'+names[type]+'</strong><small>'+desc[type]+'</small><span class="module-detail"><b>✓ Выбрать</b><i>Охлаждает соседние клетки</i></span></span>';
}
const stats=panel.querySelector('.stats');
const metrics=element('section','premium-metrics','<h3>◈ ТЕКУЩЕЕ СОСТОЯНИЕ</h3><div class="metric-row"><div><span>♨</span><strong id="premiumHeat">56°C</strong><small>Условный<br>индекс</small></div><div><span>⬡</span><strong id="premiumLeft">3</strong><small>Доступно<br>модулей</small></div><div><span>◎</span><strong id="premiumZones">0 / 3</strong><small>Зон<br>охлаждено</small></div></div>');
panel.insertBefore(metrics,stats);
const status=element('div','premium-guidance','<strong id="premiumStatusTitle">ШАГ 2 · ВЫБЕРИ МЕСТО</strong><p id="premiumStatusText">Дерево уже выбрано. Нажми на красную метку на карте.</p>');status.setAttribute('aria-live','polite');
panel.insertBefore(status,panel.querySelector('.status'));
const advice=element('div','premium-map-advice','<span>◉ ТЕПЛОВАЯ КАРТА</span><div class="view-modes"><button id="premium3d" type="button" aria-pressed="true">3D</button><button id="premiumMap" type="button" aria-pressed="false">КАРТА</button></div>');
stage.append(advice);
const overlay=element('div','premium-hotspots','');
stage.append(overlay);
const spotPrompt=element('div','premium-spot-prompt','НАЖМИ НА КРАСНУЮ МЕТКУ, ЧТОБЫ ВЫБРАТЬ ЦЕЛЬ');
stage.append(spotPrompt);
const selectionGuide=element('div','premium-selection-guide','<strong id="premiumSelectionTitle">ТВОЙ СЛЕДУЮЩИЙ ШАГ</strong><span id="premiumSelectionText">Нажми на красный маркер</span>');selectionGuide.setAttribute('aria-live','polite');stage.append(selectionGuide);
const legend=element('div','premium-legend','<small>УСЛОВНАЯ ТЕМПЕРАТУРА ПОВЕРХНОСТИ</small><div class="temperature-gradient"></div><div class="legend-values"><b>30°C</b><b>60°C</b></div>');
stage.append(legend);
const zoomCtrl=element('div','premium-zoom','<button type="button" id="premiumZoomIn" aria-label="Увеличить">＋</button><button type="button" id="premiumZoomOut" aria-label="Уменьшить">−</button><button type="button" id="premiumZoomReset" aria-label="Вернуть камеру">⌖</button>');
stage.append(zoomCtrl);
const canvas=document.createElement('canvas');canvas.id='premiumCity';canvas.className='premium-city';canvas.tabIndex=0;
canvas.setAttribute('role','application');canvas.setAttribute('aria-label','Интерактивный изометрический квартал. Клик выберет клетку, кнопка размещения установит модуль.');
stage.append(canvas);
const ctx=canvas.getContext('2d',{alpha:false});
const nav=root.querySelector('header');
if(nav){nav.classList.add('premium-topbar');const fontToggle=element('button','premium-font-toggle','А+ &nbsp; ЕЩЁ КРУПНЕЕ');fontToggle.type='button';fontToggle.setAttribute('aria-pressed','false');fontToggle.addEventListener('click',()=>{const big=root.classList.toggle('premium-extra-readable');fontToggle.setAttribute('aria-pressed',String(big));fontToggle.textContent=big?'А−  ОБЫЧНЫЙ ТЕКСТ':'А+  ЕЩЁ КРУПНЕЕ';});nav.append(fontToggle);}
const how=element('section','premium-how',`<div class="how-caption"><b>КАК ИГРАТЬ</b><small>Три понятных шага</small></div>
<div class="how-step is-done"><b>1</b><span><strong>Выбери модуль</strong><small>Дерево уже выбрано</small></span></div>
<div class="how-step is-active"><b>2</b><span><strong>Найди место</strong><small>Нажми красную точку</small></span></div>
<div class="how-step"><b>3</b><span><strong>Размести</strong><small>Нажми большую кнопку</small></span></div>
<button type="button" class="premium-place" id="premiumPlace" disabled>⌖ Сначала выбери место</button>`);
layout.after(how);
const help=element('div','premium-hint','<strong>ⓘ СОВЕТ</strong><span>Начни с одного модуля рядом с каждой красной точкой.</span>');
how.after(help);
const originalIntro=document.querySelector('.z9-entry');if(originalIntro)originalIntro.setAttribute('data-visual-collapsed','true');
const oldStatus=panel.querySelector('.status');if(oldStatus)oldStatus.classList.add('premium-underlying-status');
const oldStats=panel.querySelector('.stats');if(oldStats)oldStats.classList.add('premium-underlying-stats');
const oldMeter=panel.querySelector('.meter');if(oldMeter)oldMeter.classList.add('premium-underlying-stats');
const oldStageTop=stage.querySelector('.stage-top');if(oldStageTop)oldStageTop.classList.add('premium-underlying-stats');
const oldStageBottom=stage.querySelector('.stage-bottom');if(oldStageBottom)oldStageBottom.classList.add('premium-underlying-stats');
const buttons=panel.querySelectorAll('.controls .btn');
if(buttons[0])buttons[0].textContent='♫ ЗВУК';if(buttons[1])buttons[1].textContent='◈ AR';
if(buttons[2])buttons[2].textContent='↺ ЗАНОВО';if(buttons[3])buttons[3].textContent='О МИССИИ ↗';
const foot=panel.querySelector('.footnote');if(foot)foot.textContent='Игра использует условные показатели, а не реальные измерения температуры.';
const instructions=document.querySelector('#board-controls-help');if(instructions)instructions.textContent='Стрелки — выбор клетки, Enter — размещение, 1–3 — выбор модуля, R — заново. Красные точки: X −4 / Z −3, X 2 / Z 2, X 4 / Z −2.';
const placeOriginal=$('place-keyboard');if(placeOriginal)placeOriginal.textContent='Разместить здесь';
const state={mode:'3d',zoom:1,hover:null,cell:{x:0,z:0},hasSelectedPlace:false,scale:1,w:900,h:560,refresh:false};
root.dataset.premiumVersion='24';
const S=(x,z,h=0)=>{
 if(state.mode==='map'){const u=Math.min(state.w-30,state.h-65)*state.zoom/15;return {x:state.w/2+x*u,y:state.h*.49+z*u-h*u};}
 return {x:state.w*.5+(x-z)*state.scale*1.1,y:state.h*.49+(x+z)*state.scale*.52-h*state.scale*1.63};
};
function seed(x,z){let v=Math.sin(x*127.1+z*311.7+74.7)*43758.5453;return v-Math.floor(v);}
function building(x,z){
 if(Math.abs(x)<=2&&Math.abs(z)<=2)return false;
 if(Math.abs(x)>6||Math.abs(z)>6||seed(x,z)<.49)return false;
 if(hot.some(p=>Math.hypot(p.x-x,p.z-z)<1.55))return false;
 return true;
}
function poly(points,fill,stroke,width=1){
 ctx.beginPath();ctx.moveTo(points[0].x,points[0].y);for(let i=1;i<points.length;i++)ctx.lineTo(points[i].x,points[i].y);ctx.closePath();
 if(fill){ctx.fillStyle=fill;ctx.fill();}if(stroke){ctx.lineWidth=width;ctx.strokeStyle=stroke;ctx.stroke();}
}
function cellCorners(x,z,h=0,w=.49){return [S(x-w,z-w,h),S(x+w,z-w,h),S(x+w,z+w,h),S(x-w,z+w,h)];}
function circ(x,y,r,color){ctx.beginPath();ctx.arc(x,y,Math.max(.5,r),0,Math.PI*2);ctx.fillStyle=color;ctx.fill();}
function glowing(x,y,scale,color){
 if(!ctx.createRadialGradient)return;
 const gradient=ctx.createRadialGradient(x,y,0,x,y,scale);gradient.addColorStop(0,color);gradient.addColorStop(1,'rgba(0,0,0,0)');ctx.fillStyle=gradient;ctx.fillRect(x-scale,y-scale,scale*2,scale*2);
}
function coverage(s,p){return s.placed.some(m=>Math.hypot(m.x-p.x,m.z-p.z)<=1.35);}
function placeArt(x,z,type){
 const c=S(x,z,.06),size=state.scale;
 if(type==='tree'){
  circ(c.x+2,c.y+1,size*.38,'#0a3040');
  ctx.strokeStyle='#9e7957';ctx.lineWidth=Math.max(2,size*.16);ctx.beginPath();ctx.moveTo(c.x,c.y);ctx.lineTo(c.x,c.y-size*1.15);ctx.stroke();
  glowing(c.x,c.y-size*1.2,size*1.1,'rgba(39,236,175,.34)');
  for(const [a,b,r] of [[-.35,-1.12,.46],[.35,-1.05,.47],[0,-1.54,.49]]){circ(c.x+a*size,c.y+b*size,r*size,'#18563d');circ(c.x+a*size-2,c.y+b*size-3,r*size*.75,'#4dce7d');}
 }else if(type==='shade'){
  poly(cellCorners(x,z,1.05,.54),'#d7effb','#5ca6bb',1);
  for(const dx of [-.45,.45])for(const dz of [-.45,.45]){const from=S(x+dx,z+dz,1.05),to=S(x+dx,z+dz,0);ctx.strokeStyle='#a3c9d8';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(from.x,from.y);ctx.lineTo(to.x,to.y);ctx.stroke();}
 }else{
  poly(cellCorners(x,z,.1,.6),'#256974','#6cf4c1',1);
  for(let i=0;i<9;i++){const a=i*2.399,p=S(x+Math.sin(a)*.33,z+Math.cos(a)*.33,.20+seed(i,x)*.5);ctx.strokeStyle=i%3?'#60c975':'#9be58d';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(p.x,p.y+7);ctx.lineTo(p.x-3,p.y-10);ctx.stroke();}
 }
}
function drawBuilding(x,z){
 const b=seed(x,z),height=1+b*3.45;const width=.38+seed(z,x)*.05;
 const base=cellCorners(x,z,0,width),roof=cellCorners(x,z,height,width);
 const isHot=seed(x-11,z+6)>.4;
 const north=isHot?'#765046':'#2d4155',east=isHot?'#4f3435':'#223448';
 poly([roof[3],roof[2],base[2],base[3]],north,'#17293b',.5);
 poly([roof[1],roof[2],base[2],base[1]],east,'#162a3a',.5);
 poly(roof,isHot?'#786361':'#475c6d','#5e7987',.6);
 const inset=cellCorners(x,z,height+.045,width*.79);poly(inset,'#1a3348','#568497',.6);
 if(b>.67){const up=S(x-.15,z-.12,height+.08),down=S(x+.19,z+.1,height+.08);
  ctx.strokeStyle='#9dbbcb';ctx.lineWidth=Math.max(1,state.scale*.09);
  ctx.strokeRect(Math.min(up.x,down.x),Math.min(up.y,down.y),Math.max(3,Math.abs(up.x-down.x)),Math.max(3,Math.abs(up.y-down.y)));
 }
 for(let floor=0.32;floor<height-.16;floor+=.43){
  for(const fraction of [-.59,-.19,.21,.61]){
   const u=(fraction+1)/2;
   const a=S(x-width+u*width*2,z+width+.014,floor),bb=S(x-width+u*width*2,z+width+.014,floor+.14);
   const lit=seed(x+floor*.1,z+u*9)>.25;
   ctx.strokeStyle=lit?'rgba(255,187,111,.74)':'rgba(57,126,158,.72)';ctx.lineWidth=Math.max(1,state.scale*.09);
   ctx.beginPath();ctx.moveTo(a.x,a.y);ctx.lineTo(bb.x,bb.y);ctx.stroke();
  }
 }
}
function paint(){
 if(!ctx)return;const r=stage.getBoundingClientRect();if(r.width<10||r.height<10)return;
 const ratio=Math.min(2,window.devicePixelRatio||1),w=r.width,h=r.height;
 state.w=w;state.h=h;state.scale=Math.min(w/33,h/23)*state.zoom;
 if(canvas.width!==Math.round(w*ratio)||canvas.height!==Math.round(h*ratio)){canvas.width=Math.round(w*ratio);canvas.height=Math.round(h*ratio);}
 ctx.setTransform(ratio,0,0,ratio,0,0);ctx.clearRect(0,0,w,h);
 const sky=ctx.createLinearGradient(0,0,0,h);sky.addColorStop(0,'#09182b');sky.addColorStop(.45,'#0b1f32');sky.addColorStop(1,'#03121f');
 ctx.fillStyle=sky;ctx.fillRect(0,0,w,h);
 const s=game()?.state?.()||{placed:[],score:0,selected:'tree'};
 glowing(w*.5,h*.41,Math.max(w,h)*.48,'rgba(35,108,142,.24)');
 const floor=cellCorners(0,0,-.07,7.55);poly(floor,'#091b29','#23506a',2);
 // The heat field is a live, game-state-dependent glow underneath real buildings.
 for(const p of hot){const c=S(p.x,p.z,-.04),cooled=coverage(s,p);
  glowing(c.x,c.y,Math.max(54,state.scale*5.7),cooled?'rgba(17,239,210,.27)':'rgba(255,74,28,.32)');
  if(!cooled)glowing(c.x,c.y,Math.max(28,state.scale*2.9),'rgba(255,139,60,.26)');
 }
 for(let depth=-14;depth<=14;depth++){
  for(let x=-7;x<=7;x++){const z=depth-x;if(z< -7||z>7)continue;
   const dist=Math.min(...hot.map(p=>Math.hypot(p.x-x,p.z-z)));
   const isCool=hot.some(p=>coverage(s,p)&&Math.hypot(p.x-x,p.z-z)<2.6);
   const heat=dist<3.5&&!isCool;
   let c=heat?(dist<1.5?'#773f32':'#443740'):isCool?'#105b62':'#152d3e';
   const isRoad=(x+7)%3===0||(z+7)%3===0;
   if(isRoad)c=heat?'#92523f':isCool?'#13727a':'#1b3d51';
   poly(cellCorners(x,z,.001,.49),c,'rgba(76,128,151,.22)',.5);
   if(isRoad&&(x+z)%2===0){const lane=S(x,z,.008);circ(lane.x,lane.y,Math.max(.9,state.scale*.065),heat?'#ffb17e':'#83bed1');}
   if((x+z)%3===0){const center=S(x,z,.02);circ(center.x,center.y,Math.max(.65,state.scale*.05),'rgba(91,164,192,.45)');}
  }
  for(let x=-7;x<=7;x++){const z=depth-x;if(z< -7||z>7)continue;
   if(building(x,z))drawBuilding(x,z);
   else if(seed(x+19,z-24)>.85&&!hot.some(p=>Math.hypot(p.x-x,p.z-z)<.8)){
    const c=S(x,z,0);const size=state.scale;
    ctx.strokeStyle='#765e3f';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(c.x,c.y);ctx.lineTo(c.x,c.y-size*.4);ctx.stroke();
    circ(c.x,c.y-size*.58,size*.25,'#135847');circ(c.x-2,c.y-size*.66,size*.17,'#33a675');
   }
   const item=s.placed.find(p=>p.x===x&&p.z===z);
   if(item)placeArt(x,z,item.type);
  }
 }
 for(const [i,p] of hot.entries()){
  const c=S(p.x,p.z,.05),covered=coverage(s,p);
  glowing(c.x,c.y,Math.max(24,state.scale*3.2),covered?'rgba(36,250,210,.21)':'rgba(255,80,38,.31)');
  ctx.beginPath();ctx.ellipse(c.x,c.y,Math.max(8,state.scale*.65),Math.max(5,state.scale*.27),0,0,Math.PI*2);
  ctx.strokeStyle=covered?'#72ffe3':'#ffa36b';ctx.lineWidth=2.5;ctx.stroke();
  circ(c.x,c.y,Math.max(2,state.scale*.12),covered?'#85ffe5':'#ffb088');
 }
 const hover=state.hover||state.cell;
 if(hover){poly(cellCorners(hover.x,hover.z,.06,.5),'rgba(66,222,246,.16)','#a6fcff',2);}
 const markers=overlay.querySelectorAll('.premium-hot-marker');
 hot.forEach((p,i)=>{
  const pos=S(p.x,p.z,2.5),covered=coverage(s,p),marker=markers[i];if(!marker)return;
  marker.style.left=pos.x+'px';marker.style.top=pos.y+'px';marker.classList.toggle('cool',covered);
  marker.querySelector('strong').textContent=covered?'✓':p.temp+'°C';
 });
}
for(const [i,p] of hot.entries()){
 const marker=element('button','premium-hot-marker','<strong>'+p.temp+'°C</strong><i aria-hidden="true"></i>');
 marker.type='button';marker.setAttribute('aria-label','Выбрать горячую зону '+(i+1));
 marker.addEventListener('click',()=>{select(p.x,p.z);canvas.focus();});
 overlay.append(marker);
}
function refresh(){
 const b=game();if(!b)return;const s=b.state();
 $('premiumProgress').textContent=s.score+' / 3';
 $('premiumHeat').textContent=[56,47,39,30][s.score]+'°C';
 $('premiumLeft').textContent=String(Math.max(0,3-s.placed.length));
 $('premiumZones').textContent=s.score+' / 3';
 $('premiumRing').style.setProperty('--progress',String(s.score/3*100)+'%');
 spotPrompt.textContent=s.won?'✓ МИССИЯ ВЫПОЛНЕНА':s.lost?'ПОПРОБУЙ ЕЩЁ РАЗ':s.score?'ОСТАЛОСЬ '+(3-s.score)+' ГОРЯЧИХ ЗОНЫ · НАЖМИ НА КРАСНЫЙ МАРКЕР':'НАЖМИ НА КРАСНЫЙ МАРКЕР И ВЫБЕРИ МЕСТО';
 for(const [i,marker] of overlay.querySelectorAll('.premium-hot-marker').entries()){
  const zone=hot[i],covered=coverage(s,zone);
  marker.setAttribute('aria-label',(covered?'Охлаждена зона ':'Выбрать горячую зону ')+(i+1)+(covered?'':', '+zone.temp+' градусов'));
  marker.classList.toggle('selected',state.hasSelectedPlace&&!covered&&state.cell.x===zone.x&&state.cell.z===zone.z);
  marker.disabled=covered||s.won||s.lost;
 }
 const occupied=s.placed.some(p=>p.x===state.cell.x&&p.z===state.cell.z);
 const allowed=s.ready&&state.hasSelectedPlace&&!occupied&&!s.won&&!s.lost;
 $('premiumPlace').disabled=!allowed;
 $('premiumPlace').textContent=s.won?'✓ ГОРОД ОХЛАЖДЁН':s.lost?'↺ НАЧНИ ЗАНОВО':allowed?'✓ РАЗМЕСТИТЬ '+names[s.selected].toUpperCase():'⌖ СНАЧАЛА ВЫБЕРИ МЕСТО';
 for(const [i,step] of [...how.querySelectorAll('.how-step')].entries()){
  step.classList.toggle('is-active',!s.won&&!s.lost&&(state.hasSelectedPlace?3:2)===i+1);
  step.classList.toggle('is-done',s.won||(state.hasSelectedPlace?3:2)>i+1);
 }
 for(const button of toolList.querySelectorAll('.module')){
  const active=button.dataset.type===s.selected;
  button.setAttribute('aria-pressed',String(active));
  button.setAttribute('aria-label',(active?'Выбрано: ':'Выбрать: ')+names[button.dataset.type]);
 }
 $('premiumStatusTitle').textContent=s.won?'✓ ПОБЕДА':s.lost?'↺ ПОПРОБУЙ ЕЩЁ РАЗ':allowed?'ШАГ 3 · РАЗМЕСТИ МОДУЛЬ':state.hasSelectedPlace?'ЭТА КЛЕТКА НЕДОСТУПНА':'ШАГ 2 · ВЫБЕРИ МЕСТО';
 $('premiumStatusText').textContent=s.won?'Все три зоны охлаждены!':s.lost?'Модули закончились. Нажми «ЗАНОВО».':occupied?'Клетка уже занята. Нажми на свободную рядом.':state.hasSelectedPlace?'Выбрано: '+names[s.selected]+'. Клетка X '+state.cell.x+' / Z '+state.cell.z+'. Нажми большую кнопку.':'Выбран модуль «'+names[s.selected]+'». Нажми на красную метку в городе.';
 $('premiumSelectionTitle').textContent=s.won?'✓ МИССИЯ ПРОЙДЕНА':s.lost?'↺ НОВАЯ ПОПЫТКА':allowed?'МЕСТО ВЫБРАНО':'ШАГ 2 ИЗ 3 · НАЙДИ ГОРЯЧУЮ ЗОНУ';
 $('premiumSelectionText').textContent=s.won?'3 / 3 охлаждено':s.lost?'Нажми «ЗАНОВО»':allowed?'X '+state.cell.x+' / Z '+state.cell.z+' · '+names[s.selected]:'Нажми красный маркер на карте';
 paint();
}
function at(clientX,clientY){
 const bounds=canvas.getBoundingClientRect(),mx=clientX-bounds.left,my=clientY-bounds.top;
 if(state.mode==='map'){
  const u=Math.min(state.w-30,state.h-65)*state.zoom/15;
  return {x:Math.max(-7,Math.min(7,Math.round((mx-state.w/2)/u))),z:Math.max(-7,Math.min(7,Math.round((my-state.h*.49)/u)))};
 }
 const sx=(mx-state.w*.5)/(state.scale*1.1),sy=(my-state.h*.49)/(state.scale*.52);
 return {x:Math.max(-7,Math.min(7,Math.round((sx+sy)/2))),z:Math.max(-7,Math.min(7,Math.round((sy-sx)/2)))};
}
function select(x,z){
 state.cell={x,z};state.hasSelectedPlace=true;const b=game();if(b?.cursor)b.cursor(x,z);
 refresh();
}
function place(){
 const b=game();if(!b||!b.state().ready)return;
 const outcome=b.place(state.cell.x,state.cell.z,b.state().selected);if(outcome?.ok)state.hasSelectedPlace=false;refresh();
}
canvas.addEventListener('pointerdown',e=>{const p=at(e.clientX,e.clientY);select(p.x,p.z);canvas.focus();});
let hoverFrame=0;
const scheduleHoverPaint=()=>{if(!hoverFrame)hoverFrame=requestAnimationFrame(()=>{hoverFrame=0;paint();});};
canvas.addEventListener('pointermove',e=>{if(e.pointerType==='touch')return;const p=at(e.clientX,e.clientY);
 if(state.hover&&p.x===state.hover.x&&p.z===state.hover.z)return;
 state.hover=p;scheduleHoverPaint();});
canvas.addEventListener('pointerleave',()=>{state.hover=null;scheduleHoverPaint();});
canvas.addEventListener('keydown',e=>{
 const k=e.key.toLowerCase();
 if(k==='arrowleft')state.cell.x=Math.max(-7,state.cell.x-1);
 else if(k==='arrowright')state.cell.x=Math.min(7,state.cell.x+1);
 else if(k==='arrowup')state.cell.z=Math.max(-7,state.cell.z-1);
 else if(k==='arrowdown')state.cell.z=Math.min(7,state.cell.z+1);
 else if(k==='enter'||k===' '){place();e.preventDefault();return;}
 else if(k==='r'){const reset=$('reset');if(reset)reset.click();refresh();return;}
 else if(['1','2','3'].includes(k)){const button=toolList.querySelectorAll('.module')[Number(k)-1];button?.click();refresh();return;}
 else return;
 e.preventDefault();select(state.cell.x,state.cell.z);
});
$('premiumPlace').addEventListener('click',place);
for(const button of toolList.querySelectorAll('.module'))button.addEventListener('click',()=>{refresh();});
$('reset')?.addEventListener('click',()=>{state.cell={x:0,z:0};state.hasSelectedPlace=false;requestAnimationFrame(refresh);});
$('premium3d').addEventListener('click',()=>{state.mode='3d';$('premium3d').setAttribute('aria-pressed','true');$('premiumMap').setAttribute('aria-pressed','false');refresh();});
$('premiumMap').addEventListener('click',()=>{state.mode='map';$('premium3d').setAttribute('aria-pressed','false');$('premiumMap').setAttribute('aria-pressed','true');refresh();});
$('premiumZoomIn').addEventListener('click',()=>{state.zoom=Math.min(1.6,state.zoom+.15);refresh();});
$('premiumZoomOut').addEventListener('click',()=>{state.zoom=Math.max(.7,state.zoom-.15);refresh();});
$('premiumZoomReset').addEventListener('click',()=>{state.zoom=1;state.mode='3d';$('premium3d').click();});
for(const id of ['score','left','statusTitle','statusText']){
 const node=$(id);if(node)new MutationObserver(()=>{if(!state.refresh){state.refresh=true;requestAnimationFrame(()=>{state.refresh=false;refresh();});}}).observe(node,{subtree:true,childList:true,characterData:true});
}
new ResizeObserver(()=>refresh()).observe(stage);
window.addEventListener('zion-three-ready',()=>requestAnimationFrame(refresh));
window.addEventListener('zion-three-failed',()=>requestAnimationFrame(refresh));
window.addEventListener('resize',()=>refresh());
refresh();
})();
