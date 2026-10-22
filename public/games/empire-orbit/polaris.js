/* OSGARD EMPIRE — POLARIS COMMAND v26.
   UI only: no modification to currency, progress, saves, room commands, or server. */
(() => {
  'use strict';
  const root=document.documentElement,scene=document.querySelector('.command-grid .scene');
  const headline=document.querySelector('main>.headline'),planet=document.getElementById('planet');
  const harvest=document.getElementById('harvest'),lang=document.getElementById('lang');
  const tools=document.querySelector('.top-tools');
  if(!scene||!headline||!planet||!harvest||!tools)return;
  const wording={
    ru:{steps:[['Пробуди ядро','Нажми на сферу и накопи первые 50 ◈','К ядру'],['Усиль производство','Купи модуль, чтобы получать больше времени','К улучшениям'],['Открой новый сектор','Расширь империю на звёздной карте','К карте'],['Управляй будущим','Выбирай стратегию, дипломатию и новые миры','К галактике']],fxOn:'Эффекты включены — уменьшить анимацию',fxOff:'Эффекты снижены — включить',guide:'Твой следующий шаг'},
    en:{steps:[['Wake the core','Tap the sphere to collect your first 50 ◈','To the core'],['Grow production','Buy an upgrade to earn time faster','To upgrades'],['Unlock a sector','Expand your empire on the star map','Open the map'],['Rule the future','Choose strategy, diplomacy and new worlds','To the galaxy']],fxOn:'Visual effects on — reduce motion',fxOff:'Visual effects reduced — enable',guide:'Your next move'},
    zh:{steps:[['唤醒核心','点击星球，收集前 50 点时间能量','前往核心'],['提升产量','购买升级，加快时间能量生产','前往升级'],['解锁新星区','在星图中扩大帝国疆域','打开地图'],['掌控未来','选择战略、外交与新世界','打开星系']],fxOn:'特效已开启，点击降低动画',fxOff:'特效已降低，点击开启',guide:'下一步行动'}
  };
  const tr=()=>wording[lang?.value]||wording.ru,ql=s=>document.querySelector(s);
  const reduced=matchMedia('(prefers-reduced-motion: reduce)');
  let light=reduced.matches;
  try{const value=localStorage.getItem('osgard-empire-polaris-motion');if(value==='lite')light=true;else if(value==='full'&&!reduced.matches)light=false;}catch{}
  const fx=document.createElement('button');fx.type='button';fx.id='polarisFx';fx.textContent='FX';
  fx.className='tool-button prem-display-switch';tools.prepend(fx);
  function updateFx(){root.classList.toggle('prem-lite',light);fx.setAttribute('aria-pressed',String(!light));fx.setAttribute('aria-label',light?tr().fxOff:tr().fxOn);fx.title=fx.getAttribute('aria-label');}
  fx.addEventListener('click',()=>{light=!light;try{localStorage.setItem('osgard-empire-polaris-motion',light?'lite':'full')}catch{}updateFx();});
  updateFx();
  const guide=document.createElement('section');guide.className='prem-guide';guide.setAttribute('aria-label',tr().guide);
  guide.innerHTML='<b class="prem-guide-index" aria-hidden="true">01</b><div class="prem-guide-copy"><strong></strong><span></span></div><button class="prem-guide-action" type="button"></button>';
  headline.insertAdjacentElement('afterend',guide);
  const number=guide.querySelector('.prem-guide-index'),title=guide.querySelector('strong'),desc=guide.querySelector('.prem-guide-copy span'),action=guide.querySelector('button');
  let lastStage=-1,lastLang='';
  function count(sel){const el=ql(sel);if(!el)return 0;const m=el.textContent.replace(/[\s\u00a0\u202f]/g,'').replace(',','.').match(/\d+(?:\.\d+)?/);return m?Number(m[0]):0;}
  function stage(){if(count('#territories')>=2)return 3;if(count('#balance')<50)return 0;return ql('#modules .module-buy')?1:2;}
  function refresh(force=false){const v=stage(),language=lang?.value||'ru';if(!force&&v===lastStage&&language===lastLang)return;lastStage=v;lastLang=language;const w=tr().steps[v];number.textContent=String(v+1).padStart(2,'0');title.textContent=w[0];desc.textContent=w[1];action.textContent=w[2]+' ↗';guide.setAttribute('aria-label',tr().guide);updateFx();}
  action.addEventListener('click',()=>{const targets=[planet,ql('.side-right'),ql('[data-wave-go="sectors"]'),ql('[data-wave-go="galaxy"]')];const target=targets[lastStage];if(!target)return;if(lastStage>=2){target.click();return;}target.scrollIntoView({behavior:light||reduced.matches?'auto':'smooth',block:lastStage===0?'center':'start'});if(lastStage===0)planet.focus({preventScroll:true});});
  let pending=0;function schedule(){if(pending)return;pending=setTimeout(()=>{pending=0;refresh();},380);}
  for(const id of ['balance','territories','modules']){const node=document.getElementById(id);if(node)new MutationObserver(schedule).observe(node,{subtree:true,childList:true,characterData:true});}
  lang?.addEventListener('change',()=>refresh(true));refresh(true);
  let flash;
  function impact(){if(light||reduced.matches||document.hidden)return;planet.classList.remove('prem-hit');void planet.offsetWidth;planet.classList.add('prem-hit');
    const world=document.getElementById('sceneWorld');if(world){const ring=document.createElement('span');ring.className='prem-impact';world.appendChild(ring);ring.addEventListener('animationend',()=>ring.remove(),{once:true});setTimeout(()=>ring.remove(),800);}
    clearTimeout(flash);flash=setTimeout(()=>planet.classList.remove('prem-hit'),180);
  }
  planet.addEventListener('click',impact,{passive:true});harvest.addEventListener('click',impact,{passive:true});
  let pendingMove=false,pX=0,pY=0;
  scene.addEventListener('pointermove',event=>{if(light||reduced.matches||event.pointerType==='touch'||pendingMove)return;const rect=scene.getBoundingClientRect();pX=(event.clientX-rect.left-rect.width/2)/rect.width;pY=(event.clientY-rect.top-rect.height/2)/rect.height;pendingMove=true;requestAnimationFrame(()=>{scene.style.setProperty('--prem-x',Math.round(pX*22)+'px');scene.style.setProperty('--prem-y',Math.round(pY*18)+'px');pendingMove=false;});},{passive:true});
  scene.addEventListener('pointerleave',()=>{scene.style.setProperty('--prem-x','0px');scene.style.setProperty('--prem-y','0px');});
})();