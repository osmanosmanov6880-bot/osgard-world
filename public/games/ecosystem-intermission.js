/* OSGARD PLAY — owned-project cross-promotion, not third-party ad inventory. */
(() => {
'use strict';
const services=[
{id:'studio',name:'OSGARD BEW WORLD',mark:'OW',kind:'DIGITAL STUDIO',desc:'Превратим идею в сайт, приложение или игровой продукт.',url:'https://osgardbewworld.com',cta:'Обсудить свой продукт'},
{id:'o2',name:'O2 SYSTEM',mark:'O₂',kind:'BUSINESS SYSTEMS',desc:'Цифровой учёт для касс обменных пунктов.',url:'https://o2system.art',cta:'Посмотреть O2 SYSTEM'},
{id:'senjor',name:'SENJORIO',mark:'SJ',kind:'PREMIUM MOBILITY',desc:'Премиальный формат персональных поездок.',url:'https://senjorio.com',cta:'Изучить SENJORIO'},
{id:'superday',name:'SUPER DAY',mark:'SD',kind:'TIME / PLANNING',desc:'Собери день из приоритетов, маршрутов и задач.',url:'https://superday.run',cta:'Открыть SUPER DAY'},
{id:'marcosa',name:'MARCOSA CLUB',mark:'MC',kind:'SOCIAL UNIVERSE',desc:'Пространство для общения, историй и новых связей.',url:'https://marcosa.club',cta:'Исследовать MARCOSA'},
{id:'myosa',name:'MYOSA WORLD',mark:'MW',kind:'AI / ASSISTANCE',desc:'Изучи AI-направление экосистемы OSGARD.',url:'https://myosa.world',cta:'Открыть MYOSA'},
{id:'gold-glamour',name:'GOLD GLAMOUR',mark:'GG',kind:'LUXURY SERVICES',desc:'Премиальное сервисное направление Gold Glamour.',url:'https://gold-glamour.online',cta:'Посмотреть услуги'},
{id:'gardvpn',name:'GARD VPN',mark:'GV',kind:'PRIVACY / NETWORK',desc:'Узнай условия сервиса приватного подключения.',url:'https://gardvpn.is',cta:'Изучить GARD VPN'},
{id:'osgardos',name:'OSGARD OS',mark:'OS',kind:'BUSINESS GROWTH',desc:'Направления развития цифрового бизнеса.',url:'https://osgardos.com',cta:'Открыть OSGARD OS'},
{id:'vanguard',name:'OSGARD VANGUARD',mark:'OV',kind:'VIDEO / PRODUCTION',desc:'Кинематографичные видео и материалы для брендов.',url:'https://osgardvanguard.studio',cta:'Посмотреть студию'}
];
const did='osgard-ecosystem-intermission';
if(document.getElementById(did))return;
const read=k=>{try{return localStorage.getItem(k)}catch{return null}};
let selected='',activeSession=false,lastGame='games',showTimer=0;
function log(name,props){if(read('osgard.games.analytics-consent.v1')!=='yes')return;const token=read('osgard.auth.accessToken');if(!token)return;const event={id:crypto.randomUUID?crypto.randomUUID():name+'-'+Date.now(),name,world:'play',game:lastGame,payload:Object.assign({source:'ecosystem_intermission',placement:'between_games'},props||{}),occurredAt:new Date().toISOString(),schemaVersion:1};fetch('/api/v1/player/events',{method:'POST',credentials:'same-origin',keepalive:true,headers:{authorization:'Bearer '+token,'content-type':'application/json'},body:JSON.stringify({event})}).catch(()=>{})}
const css=[
'#'+did+'{width:min(1100px,calc(100% - 24px));max-width:1100px;max-height:92svh;padding:0;border:1px solid #74603b;border-radius:18px;background:#080a0f;color:#f3eee1;box-shadow:0 35px 150px #000d;overflow:auto}',
'#'+did+'::backdrop{background:#020307e8;backdrop-filter:blur(14px)}',
'#'+did+' *{box-sizing:border-box}',
'#'+did+' .ogw-top{padding:18px 22px;border-bottom:1px solid #b69a5b30;display:flex;align-items:center;justify-content:space-between;gap:16px}',
'#'+did+' .ogw-brand{font-size:10px;letter-spacing:.23em;color:#d9c28f;font-weight:800}',
'#'+did+' .ogw-brand small{display:block;margin-top:5px;color:#79776f;font-size:8px;letter-spacing:.18em}',
'#'+did+' .ogw-top-right{font:9px ui-monospace,monospace;color:#8a836f;letter-spacing:.12em}',
'#'+did+' .ogw-hero{display:grid;grid-template-columns:1fr auto;align-items:end;gap:20px;padding:28px 28px 19px;background:radial-gradient(ellipse at 85% 0,#54452a26,transparent 48%),linear-gradient(125deg,#15130f,#0b0d12 65%)}',
'#'+did+' .ogw-eyebrow{font:9px ui-monospace,monospace;letter-spacing:.24em;color:#d9b96e}',
'#'+did+' h2{font:400 clamp(28px,4vw,46px)/.98 Georgia,serif;letter-spacing:-.03em;margin:12px 0 9px;color:#f5efe2}',
'#'+did+' .ogw-hero p{max-width:660px;color:#a5a092;font:12px/1.8 system-ui,sans-serif;margin:0}',
'#'+did+' .ogw-count{min-width:93px;border-left:1px solid #a68b5845;padding-left:16px;color:#9e9278;font:9px/1.8 ui-monospace,monospace}',
'#'+did+' .ogw-count strong{display:block;color:#f0cf89;font:32px/1 Georgia,serif}',
'#'+did+' .ogw-grid{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:9px;padding:18px 22px 13px}',
'#'+did+' .ogw-option{min-width:0;text-align:left;border:1px solid #302d26;border-radius:11px;background:linear-gradient(155deg,#14140f,#0c0e12);color:#eee8d8;padding:12px;cursor:pointer;min-height:144px;transition:border-color .15s,background .15s,transform .15s}',
'#'+did+' .ogw-option:hover{transform:translateY(-2px);border-color:#7e6b43}',
'#'+did+' .ogw-option[aria-pressed=true]{border-color:#d6b46c;background:linear-gradient(145deg,#30271a,#11121a);box-shadow:inset 0 0 0 1px #d6b46c30}',
'#'+did+' .ogw-mark{display:grid;place-items:center;width:33px;height:33px;border:1px solid #77603a;border-radius:9px;color:#efcf8d;background:#17150f;font:700 10px ui-monospace,monospace}',
'#'+did+' .ogw-kind{display:block;color:#91856e;font:7px/1.5 ui-monospace,monospace;letter-spacing:.12em;margin-top:10px;min-height:11px}',
'#'+did+' .ogw-option strong{display:block;font:700 10px/1.45 system-ui,sans-serif;margin-top:5px;overflow-wrap:anywhere}',
'#'+did+' .ogw-option p{font:9px/1.6 system-ui,sans-serif;color:#969184;margin:6px 0 0}',
'#'+did+' .ogw-bottom{padding:13px 22px 20px;border-top:1px solid #ae92502a;display:flex;justify-content:space-between;align-items:center;gap:16px;flex-wrap:wrap}',
'#'+did+' .ogw-note{max-width:530px;color:#817d70;font:9px/1.7 system-ui,sans-serif}',
'#'+did+' .ogw-actions{display:flex;gap:8px;align-items:center;flex-wrap:wrap}',
'#'+did+' .ogw-cta{border:1px solid #e5c477;border-radius:9px;min-height:41px;padding:0 15px;background:linear-gradient(120deg,#e9d39c,#c7a760);color:#17130b;font:800 10px system-ui,sans-serif;cursor:pointer}',
'#'+did+' .ogw-cta:disabled{opacity:.35;cursor:not-allowed}',
'#'+did+' .ogw-skip{border:1px solid #3a392f;border-radius:9px;min-height:41px;padding:0 13px;background:#111217;color:#d4cdbd;font:10px system-ui,sans-serif;cursor:pointer}',
'#'+did+' .ogw-skip:focus-visible,#'+did+' .ogw-cta:focus-visible,#'+did+' .ogw-option:focus-visible{outline:2px solid #b7a3ff;outline-offset:3px}',
'#'+did+' .ogw-foot{display:flex;justify-content:space-between;gap:10px;padding:0 22px 13px;color:#625e53;font:8px ui-monospace,monospace;letter-spacing:.08em}',
'@media(max-width:840px){#'+did+' .ogw-grid{grid-template-columns:repeat(2,minmax(0,1fr));padding:14px}#'+did+' .ogw-option{min-height:132px}#'+did+' .ogw-hero{padding:22px 18px 16px}#'+did+' .ogw-top,#'+did+' .ogw-bottom,#'+did+' .ogw-foot{padding-left:17px;padding-right:17px}}',
'@media(max-width:430px){#'+did+' .ogw-grid{gap:7px}#'+did+' .ogw-option{padding:10px;min-height:130px}#'+did+' .ogw-hero{grid-template-columns:1fr}#'+did+' .ogw-count{display:none}#'+did+' .ogw-top-right{font-size:7px}#'+did+' .ogw-actions{width:100%}#'+did+' .ogw-cta,#'+did+' .ogw-skip{flex:1}}',
'@media(prefers-reduced-motion:reduce){#'+did+' *{transition:none!important}}'
].join('');
const style=document.createElement('style');style.textContent=css;document.head.append(style);
const dialog=document.createElement('dialog');dialog.id=did;dialog.setAttribute('aria-labelledby','ogw-intermission-title');
dialog.innerHTML='<div class="ogw-top"><div class="ogw-brand">OSGARD WORLD<small>OWNED ECOSYSTEM / BETWEEN WORLDS</small></div><div class="ogw-top-right">INTERMISSION / OPTIONAL</div></div><section class="ogw-hero"><div><div class="ogw-eyebrow">YOUR NEXT WORLD IS CLOSER THAN YOU THINK</div><h2 id="ogw-intermission-title">Выбери следующий<br>мир OSGARD.</h2><p>Короткая пауза между игровыми сессиями. Выбери проект, который тебе интересен, — или пропусти и возвращайся в игру.</p></div><div class="ogw-count"><strong>10</strong>PROJECTS<br>ONE ECOSYSTEM</div></section><div class="ogw-grid" role="group" aria-label="Выбери проект экосистемы OSGARD"></div><div class="ogw-bottom"><div class="ogw-note">Собственные проекты OSGARD, а не сторонние рекламодатели. Переход необязателен. Никакие рекламные показы здесь не заявляются.</div><div class="ogw-actions"><button class="ogw-skip" type="button" data-skip>Продолжить игру ↗</button><button class="ogw-cta" type="button" data-open disabled>Открыть выбранный проект ↗</button></div></div><div class="ogw-foot"><span>CURATED / OWNED PROJECTS</span><span>YOU CHOOSE · YOU SKIP</span></div>';
document.body.append(dialog);
const grid=dialog.querySelector('.ogw-grid'),cta=dialog.querySelector('[data-open]');
services.forEach(s=>{const b=document.createElement('button');b.type='button';b.className='ogw-option';b.dataset.service=s.id;b.setAttribute('aria-pressed','false');const mark=document.createElement('span');mark.className='ogw-mark';mark.textContent=s.mark;const kind=document.createElement('span');kind.className='ogw-kind';kind.textContent=s.kind;const title=document.createElement('strong');title.textContent=s.name;const desc=document.createElement('p');desc.textContent=s.desc;b.append(mark,kind,title,desc);b.addEventListener('click',()=>select(s.id));grid.append(b)});
function select(id){selected=id;grid.querySelectorAll('[data-service]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.service===id)));const s=services.find(x=>x.id===id);cta.disabled=!s;cta.textContent=s?s.cta+' ↗':'Открыть выбранный проект ↗';log('ecosystem_promo_selected',{project:id})}
function utm(s){const u=new URL(s.url);u.searchParams.set('utm_source','osgard_games');u.searchParams.set('utm_medium','intermission');u.searchParams.set('utm_campaign','ecosystem_cross_promo');u.searchParams.set('utm_content',s.id);return u.href}
cta.addEventListener('click',()=>{const s=services.find(x=>x.id===selected);if(!s)return;log('ecosystem_promo_clicked',{project:s.id,url:s.url});window.open(utm(s),'_blank','noopener,noreferrer');dialog.close('opened')});
dialog.querySelector('[data-skip]').addEventListener('click',()=>{log('ecosystem_intermission_skipped',{source:'skip_button'});dialog.close('skip')});
const player=document.getElementById('player-dialog');
document.addEventListener('click',e=>{const a=e.target.closest('a[data-play]');if(a){activeSession=true;lastGame=a.dataset.play||a.textContent.trim().slice(0,80)}},true);
function show(){if(dialog.open)return;selected='';grid.querySelectorAll('[data-service]').forEach(b=>b.setAttribute('aria-pressed','false'));cta.disabled=true;cta.textContent='Открыть выбранный проект ↗';try{dialog.showModal();log('ecosystem_intermission_shown',{projectCount:services.length});grid.querySelector('[data-service]')?.focus({preventScroll:true})}catch{}}
if(player)player.addEventListener('close',()=>{if(!activeSession)return;activeSession=false;clearTimeout(showTimer);showTimer=setTimeout(show,320)});
document.addEventListener('osgard:game-session-ended',()=>{activeSession=false;clearTimeout(showTimer);showTimer=setTimeout(show,320)});
})();