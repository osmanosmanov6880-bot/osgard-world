/* REMIX // RUN: honest, offline-only playable training mode.
   This engine never submits results to REMIX API and never claims server verification. */
(()=>{
"use strict";
const W=960,H=420,FLOOR=354,WORLD=2520,G=1800,SPEED=304,JUMP=-685,STEP=1/60;
const TEXT={
 ru:{eyebrow:"REMIX / ИГРОВАЯ АРЕНА",title:"Играй сейчас. Без ожидания Unity.",intro:"Проходи трассу, перепрыгивай препятствия и собирай кристаллы. Это полноценная локальная тренировка; официальный результат создаётся только сервисом REMIX.",offline:"Локальная тренировка",start:"Начать забег",pause:"Пауза",resume:"Продолжить",restart:"Заново",share:"Поделиться трассой",audio:"Включить звук",mute:"Выключить звук",time:"Время",gems:"Кристаллы",deaths:"Ошибки",best:"Лучший результат",tip:"A/D или ←/→ — движение. W, ↑ или пробел — прыжок. На телефоне используй кнопки под полем. Esc — пауза.",disclaimer:"Результаты сохраняются только в этом браузере и не участвуют в серверном рейтинге. Ссылки передают только номер трассы, а не подтверждённый счёт.",idle:"Готово к запуску. Изучи управление и нажми «Начать забег».",playing:"Вперёд! Избегай красных препятствий и доберись до портала.",paused:"Забег приостановлен.",finished:"Финиш! Очки: {score}. Кристаллы: {gems}. Ошибки: {deaths}.",saved:"Рекорд этой трассы",copy:"Ссылка на тренировочную трассу скопирована.",copyError:"Не удалось скопировать ссылку. Открой адрес из строки браузера.",restarted:"Начни новый забег.",stage:"ТРЕНИРОВКА // НЕ СЕРВЕРНЫЙ МАТЧ",help:"ДО ФИНИША",finish:"ФИНИШ",ready:"НАЖМИ «НАЧАТЬ ЗАБЕГ»",over:"ТРЕНИРОВКА ЗАВЕРШЕНА",pausedCard:"ПАУЗА",portal:"ПОРТАЛ",record:"НОВЫЙ РЕКОРД",left:"Налево",right:"Направо",jump:"Прыжок"},
 en:{eyebrow:"REMIX / PLAYABLE ARENA",title:"Play now. No Unity wait.",intro:"Dash through the course, clear obstacles and collect crystals. This is a fully playable local practice; only the REMIX service can issue an official match result.",offline:"Local practice",start:"Start run",pause:"Pause",resume:"Resume",restart:"Restart",share:"Share this course",audio:"Enable sound",mute:"Mute",time:"Time",gems:"Crystals",deaths:"Mistakes",best:"Best score",tip:"A/D or ←/→ to move. W, ↑ or Space to jump. Use on-screen buttons on phones. Esc pauses.",disclaimer:"Scores are stored only in this browser, not the server rankings. Shared links carry only the course seed, never a verified score.",idle:"Ready. Learn the controls and press Start run.",playing:"Go! Avoid red hazards and reach the portal.",paused:"Run paused.",finished:"Finished! Score: {score}. Crystals: {gems}. Mistakes: {deaths}.",saved:"Course personal best",copy:"Practice course link copied.",copyError:"Could not copy link. Use the browser address bar.",restarted:"Start a fresh run.",stage:"PRACTICE // NOT A SERVER MATCH",help:"TO FINISH",finish:"FINISH",ready:"PRESS START RUN",over:"PRACTICE FINISHED",pausedCard:"PAUSED",portal:"PORTAL",record:"NEW RECORD",left:"Left",right:"Right",jump:"Jump"},
 zh:{eyebrow:"REMIX / 可玩训练场",title:"立即开玩，无需等待 Unity。",intro:"冲过赛道、跳过障碍并收集水晶。这是可实际游玩的本地练习；只有 REMIX 服务才能确认正式比赛结果。",offline:"本地训练",start:"开始挑战",pause:"暂停",resume:"继续",restart:"重新开始",share:"分享赛道",audio:"开启声音",mute:"关闭声音",time:"时间",gems:"水晶",deaths:"失误",best:"最高分",tip:"A/D 或 ←/→ 移动，W、↑ 或空格跳跃。手机可使用屏幕按钮，Esc 暂停。",disclaimer:"成绩仅保存在本浏览器，不计入服务器排行榜。分享链接仅包含赛道编号，不代表认证成绩。",idle:"准备就绪。了解操作后点击“开始挑战”。",playing:"出发！避开红色障碍，到达传送门。",paused:"挑战已暂停。",finished:"到达终点！得分：{score}；水晶：{gems}；失误：{deaths}。",saved:"本赛道最佳成绩",copy:"已复制练习赛道链接。",copyError:"无法复制链接，请使用浏览器地址栏。",restarted:"开始新的挑战。",stage:"训练模式 // 非服务器比赛",help:"距离终点",finish:"终点",ready:"点击开始挑战",over:"训练完成",pausedCard:"已暂停",portal:"传送门",record:"新纪录",left:"向左",right:"向右",jump:"跳跃"}
};
const host=document.querySelector("#live-growth-console");if(!host)return;
const root=document.createElement("section");root.className="rx-practice";root.id="rx-practice";root.setAttribute("data-no-translate","");
root.innerHTML='<div class="rx-headline"><div><span class="rx-eyebrow" data-rx="eyebrow"></span><h2 data-rx="title"></h2><p data-rx="intro"></p></div><span class="rx-pill" data-rx="offline"></span></div><canvas id="rx-game" width="960" height="420" tabindex="0" role="img" aria-label="REMIX training course"></canvas><div class="rx-bar"><button type="button" id="rx-start" class="rx-primary" data-rx="start"></button><button type="button" id="rx-pause" data-rx="pause" disabled></button><button type="button" id="rx-share" data-rx="share"></button><button type="button" id="rx-audio" data-rx="audio" aria-pressed="false"></button><div class="rx-hud"><span><span data-rx="time"></span>: <strong id="rx-time">0.0s</strong></span><span><span data-rx="gems"></span>: <strong id="rx-gems">0</strong></span><span><span data-rx="deaths"></span>: <strong id="rx-deaths">0</strong></span></div></div><div class="rx-touch" role="group"><button type="button" data-rx-action="left" data-rx="left"></button><button type="button" data-rx-action="right" data-rx="right"></button><button type="button" data-rx-action="jump" data-rx="jump"></button></div><p class="rx-tip" data-rx="tip"></p><div id="rx-message" class="rx-result" role="status" aria-live="polite"></div><p class="rx-legal" data-rx="disclaimer"></p>';
host.insertAdjacentElement("beforebegin",root);
const canvas=root.querySelector("#rx-game"),ctx=canvas.getContext("2d",{alpha:false});if(!ctx)return;
const B=root.querySelector("#rx-start"),P=root.querySelector("#rx-pause"),A=root.querySelector("#rx-audio"),M=root.querySelector("#rx-message");
const K={left:false,right:false,jump:false},query=new URLSearchParams(location.search);
let seed=Number(query.get("practice"));if(!Number.isSafeInteger(seed)||seed<1||seed>999999999)seed=Number(new Date().toISOString().slice(0,10).replace(/-/g,""));
let locale="ru",phase="idle",elapsed=0,deaths=0,gems=0,record=0,newRecord=false,sound=false,audio=null;
let player=null,platforms=[],hazards=[],crystals=[],stars=[],camera=0,last=0,accumulator=0,raf=0,visibilityPaused=false,shake=0;
let jumpQueued=false,prevBottom=0,coyote=0,buffer=0,checkpoint=54,score=0;
const prefersReduced=matchMedia("(prefers-reduced-motion: reduce)").matches;
let sparkles=[];
function tr(k){return (TEXT[locale]||TEXT.ru)[k]||k}
function fromTemplate(k,values){return tr(k).replace(/\{(\w+)\}/g,(_,name)=>String(values[name]??""))}
function getLocale(){const value=window.RemixUI?.getLanguage?.()||"ru";return value==="zh"?"zh":value==="en"?"en":"ru"}
function language(){
 locale=getLocale();
 root.querySelectorAll("[data-rx]").forEach(node=>node.textContent=tr(node.dataset.rx));
 B.textContent=phase==="running"?tr("restart"):phase==="paused"?tr("restart"):tr("start");
 P.textContent=phase==="paused"?tr("resume"):tr("pause");
 A.textContent=sound?tr("mute"):tr("audio");
 canvas.setAttribute("aria-label",tr("title"));
 if(phase==="idle")message("idle");else if(phase==="paused")message("paused");else if(phase==="running")message("playing");else if(phase==="finished")finishMessage();
 render(performance.now());
}
function message(key){M.textContent=tr(key)}
function readRecord(){try{return Math.max(0,Math.min(100000,Number(JSON.parse(localStorage.getItem("rx-practice-best:"+seed)||"null")?.score||0)))}catch{return 0}}
function writeRecord(value){try{localStorage.setItem("rx-practice-best:"+seed,JSON.stringify({score:value,seed,at:new Date().toISOString()}))}catch{/* Storage may be disabled. */}}
function rng(input){let s=(input>>>0)||1;return ()=>{s^=s<<13;s^=s>>>17;s^=s<<5;return(s>>>0)/4294967296}}
function build(){
 const random=rng(seed);checkpoint=54;stars=Array.from({length:75},()=>({x:random()*1600,y:random()*210,r:random()*1.7+.3,s:random()*.65+.25}));
 const variant=()=>Math.round((random()-.5)*60);
 platforms=[{x:235,y:274,w:160,h:16},{x:610,y:255,w:155,h:16},{x:930,y:275,w:178,h:16},{x:1320,y:254,w:175,h:16},{x:1660,y:268,w:185,h:16},{x:2080,y:273,w:175,h:16}];
 hazards=[390,750,1110,1520,1900,2280].map(x=>({x:x+variant(),y:FLOOR-31,w:52,h:31}));
 crystals=[{x:300,y:218},{x:668,y:200},{x:987,y:214},{x:1380,y:193},{x:1715,y:209},{x:2142,y:215},{x:1240,y:307},{x:2010,y:307}].map((it,i)=>({x:it.x+variant()/2,y:it.y,taken:false,id:i}));
}
function start(){
 build();player={x:54,y:FLOOR-44,w:28,h:44,vx:0,vy:0,onGround:true};camera=0;elapsed=0;deaths=0;gems=0;newRecord=false;score=0;
 coyote=.08;buffer=0;shake=0;sparkles=[];Object.keys(K).forEach(k=>K[k]=false);jumpQueued=false;
 phase="running";B.textContent=tr("restart");P.disabled=false;P.textContent=tr("pause");message("playing");last=performance.now();accumulator=0;
 canvas.focus({preventScroll:true});beep(520,.08);drawHUD();runLoop();
}
function drawHUD(){root.querySelector("#rx-time").textContent=elapsed.toFixed(1)+"s";root.querySelector("#rx-gems").textContent=String(gems);root.querySelector("#rx-deaths").textContent=String(deaths)}
function togglePause(){
 if(phase==="running"){phase="paused";P.textContent=tr("resume");message("paused");Object.keys(K).forEach(k=>K[k]=false)}
 else if(phase==="paused"){phase="running";last=performance.now();accumulator=0;P.textContent=tr("pause");message("playing");canvas.focus({preventScroll:true});runLoop()}
 render(performance.now());
}
function die(){
 deaths++;shake=.22;beep(150,.22);sparkles=[];player.x=checkpoint;player.y=FLOOR-44;player.vx=player.vy=0;player.onGround=true;coyote=.06;buffer=0;drawHUD();
}
function finish(){
 phase="finished";P.disabled=true;Object.keys(K).forEach(k=>K[k]=false);
 score=Math.max(0,Math.floor(6000-elapsed*40-deaths*340+gems*225));
 newRecord=score>record;
 if(newRecord){record=score;writeRecord(score)}
 finishMessage();B.textContent=tr("restart");beep(950,.27);render(performance.now());
}
function finishMessage(){M.textContent=fromTemplate("finished",{score,gems,deaths})+" "+tr("saved")+": "+record+"."+(newRecord?" ✦ "+tr("record")+"!":"")}
function intersect(a,b){return a.x<b.x+b.w&&a.x+a.w>b.x&&a.y<b.y+b.h&&a.y+a.h>b.y}
function simulate(dt){
 elapsed+=dt;const oldY=player.y;const direction=Number(K.right)-Number(K.left);
 player.vx=direction*SPEED;player.x=Math.min(WORLD-40,Math.max(0,player.x+player.vx*dt));
 coyote=player.onGround?.085:Math.max(0,coyote-dt);
 if(jumpQueued){buffer=.115;jumpQueued=false}buffer=Math.max(0,buffer-dt);
 if(buffer>0&&coyote>0){player.vy=JUMP;player.onGround=false;coyote=0;buffer=0;beep(420,.06)}
 player.vy=Math.min(970,player.vy+G*dt);player.y+=player.vy*dt;
 let landed=false;
 if(player.vy>=0){
  if(oldY+player.h<=FLOOR+2&&player.y+player.h>=FLOOR){player.y=FLOOR-player.h;player.vy=0;landed=true}
  for(const p of platforms){if(player.x+player.w>p.x+4&&player.x<p.x+p.w-4&&oldY+player.h<=p.y+6&&player.y+player.h>=p.y&&player.vy>=0){player.y=Math.min(player.y,p.y-player.h);player.vy=0;landed=true}}
 }
 player.onGround=landed;
 if(player.y>H+150||hazards.some(h=>intersect(player,{x:h.x+8,y:h.y+7,w:h.w-16,h:h.h-7})))die();
 for(const crystal of crystals){if(crystal.taken)continue;const dx=player.x+player.w/2-crystal.x,dy=player.y+player.h/2-crystal.y;if(dx*dx+dy*dy<33*33){crystal.taken=true;gems++;beep(790,.055);drawHUD();if(!prefersReduced)sparkles.push({x:crystal.x,y:crystal.y,t:0})}}
 if(player.x>890&&checkpoint<890)checkpoint=870;
 if(player.x>1750&&checkpoint<1750)checkpoint=1720;
 if(player.x>WORLD-160)finish();
 camera+=((Math.max(0,Math.min(WORLD-W,player.x-W*.28)))-camera)*Math.min(1,dt*8);
 shake=Math.max(0,shake-dt);sparkles=sparkles.filter(p=>(p.t+=dt)<.55);
 drawHUD();
}
function roundRect(x,y,w,h,r,fill){ctx.beginPath();ctx.roundRect(x,y,w,h,r);ctx.fillStyle=fill;ctx.fill()}
function glow(x,y,r,c){const g=ctx.createRadialGradient(x,y,0,x,y,r);g.addColorStop(0,c);g.addColorStop(1,"transparent");ctx.fillStyle=g;ctx.fillRect(x-r,y-r,r*2,r*2)}
function render(now){
 const logicalWidth=W,logicalHeight=H;
 const gradient=ctx.createLinearGradient(0,0,0,H);gradient.addColorStop(0,"#07162b");gradient.addColorStop(.57,"#112845");gradient.addColorStop(1,"#260e2d");
 ctx.fillStyle=gradient;ctx.fillRect(0,0,W,H);
 ctx.save();
 if(shake&&!prefersReduced)ctx.translate((Math.sin(now*.093)*5)*shake,(Math.cos(now*.11)*3)*shake);
 for(const s of stars){const x=(s.x-camera*.09+W*6)%W;ctx.fillStyle="rgba(215,237,255,"+(s.s*(.8+(prefersReduced?0:.2*Math.sin(now*.001+s.x))))+")";ctx.beginPath();ctx.arc(x,s.y,s.r,0,Math.PI*2);ctx.fill()}
 glow(770-camera*.015,105,215,"#e4667545");glow(170-camera*.008,198,125,"#7bb5ff2b");
 ctx.fillStyle="#13263a";ctx.beginPath();ctx.moveTo(0,300);for(let x=0;x<=W;x+=40){const k=x+camera*.12;ctx.lineTo(x,275+Math.sin(k*.012)*25+Math.sin(k*.04)*9)}ctx.lineTo(W,H);ctx.lineTo(0,H);ctx.fill();
 const left=-camera;
 const lineG=ctx.createLinearGradient(0,FLOOR,0,H);lineG.addColorStop(0,"#182d3e");lineG.addColorStop(1,"#060e18");
 ctx.fillStyle=lineG;ctx.fillRect(0,FLOOR,W,H-FLOOR);
 ctx.strokeStyle="#75abc533";ctx.lineWidth=1;
 const gridShift=((-camera%52)+52)%52;for(let x=gridShift;x<W;x+=52){ctx.beginPath();ctx.moveTo(x,FLOOR);ctx.lineTo(x+((x-W/2)/W)*54,H);ctx.stroke()}
 for(let y=FLOOR+14;y<H;y+=19){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(W,y);ctx.stroke()}
 ctx.strokeStyle="#a8c3df55";ctx.beginPath();ctx.moveTo(0,FLOOR);ctx.lineTo(W,FLOOR);ctx.stroke();
 for(const p of platforms){const x=p.x+left;if(x<-p.w||x>W+10)continue;glow(x+p.w/2,p.y+9,p.w*.55,"#5dabd51b");roundRect(x,p.y,p.w,p.h,4,"#476684");roundRect(x,p.y,p.w,3,2,"#9bd5ed");for(let i=14;i<p.w;i+=28){ctx.fillStyle="#b5edff55";ctx.fillRect(x+i,p.y+7,12,1)}}
 for(const h of hazards){const x=h.x+left;if(x<-h.w||x>W+10)continue;glow(x+26,h.y+10,55,"#ec436859");ctx.fillStyle="#8b263d";ctx.fillRect(x,FLOOR-5,h.w,5);ctx.fillStyle="#f06478";for(let i=0;i<3;i++){ctx.beginPath();ctx.moveTo(x+i*18,h.y+h.h);ctx.lineTo(x+i*18+9,h.y);ctx.lineTo(x+i*18+18,h.y+h.h);ctx.closePath();ctx.fill()}}
 for(const p of crystals){if(p.taken)continue;const x=p.x+left;if(x<-60||x>W+60)continue;const y=p.y+(prefersReduced?0:Math.sin(now*.003+p.id)*4);glow(x,y,27,"#e4c57b77");ctx.save();ctx.translate(x,y);ctx.rotate(prefersReduced?.3:now*.0008+p.id);ctx.fillStyle="#f6d89f";ctx.beginPath();ctx.moveTo(0,-11);ctx.lineTo(10,0);ctx.lineTo(0,12);ctx.lineTo(-10,0);ctx.closePath();ctx.fill();ctx.strokeStyle="#fff4d2";ctx.stroke();ctx.restore()}
 const finishX=WORLD-140+left;if(finishX>-100&&finishX<W+100){glow(finishX,265,95,"#86a8ff6f");ctx.strokeStyle="#f1c881";ctx.lineWidth=7;ctx.beginPath();ctx.ellipse(finishX,281,31,67,0,0,Math.PI*2);ctx.stroke();ctx.strokeStyle="#b5e9ff99";ctx.lineWidth=3;ctx.beginPath();ctx.ellipse(finishX,281,23,60,0,0,Math.PI*2);ctx.stroke()}
 for(const p of sparkles){const x=p.x+left,y=p.y;glow(x,y,20+p.t*120,"#f3d17a"+(Math.round((1-p.t/.55)*80)).toString(16).padStart(2,"0"))}
 if(player){
  const x=player.x+left,y=player.y;
  glow(x+14,y+22,45,"#54b7e85c");roundRect(x+2,y+12,24,32,6,"#e9c586");
  roundRect(x,y,28,23,9,"#d8e8f1");roundRect(x+6,y+6,18,9,4,"#122c47");
  ctx.fillStyle="#91e3ff";ctx.fillRect(x+12,y+9,11,3);
  ctx.fillStyle="#c0e3ec";ctx.fillRect(x-2,y+23,5,16);ctx.fillRect(x+25,y+23,5,16);
  if(player.vy<0){glow(x+13,y+46,30,"#df8d524c")}
 }
 ctx.restore();
 const progress=player?Math.min(1,player.x/(WORLD-140)):0;
 roundRect(20,20,206,9,4,"#2f4058");roundRect(20,20,206*progress,9,4,"#e8c789");
 ctx.font="600 12px RXMono,monospace";ctx.fillStyle="#dcecfb";ctx.fillText(tr("stage"),20,48);
 ctx.textAlign="right";ctx.fillStyle="#d7e1ef";ctx.fillText(Math.round(progress*100)+"%",W-20,29);ctx.textAlign="left";
 if(phase!=="running"){
  ctx.fillStyle="#030a16ba";ctx.fillRect(0,0,W,H);
  ctx.fillStyle="#e9c381";ctx.font="700 32px RXInter,system-ui,sans-serif";ctx.textAlign="center";
  ctx.fillText(phase==="finished"?tr("over"):phase==="paused"?tr("pausedCard"):tr("ready"),W/2,H/2-20);
  ctx.font="500 15px RXInter,system-ui,sans-serif";ctx.fillStyle="#c9d7e5";ctx.fillText(phase==="finished"?tr("saved")+": "+record:tr("stage"),W/2,H/2+19);ctx.textAlign="left";
 }
}
function resize(){
 const width=Math.max(280,canvas.getBoundingClientRect().width);const dpr=Math.min(window.devicePixelRatio||1,1.75);canvas.width=Math.min(1680,Math.round(width*dpr));canvas.height=Math.round(canvas.width*H/W);
 ctx.setTransform(canvas.width/W,0,0,canvas.height/H,0,0);render(performance.now());
}
function runLoop(){if(raf)return;const frame=now=>{raf=0;if(phase!=="running"||document.hidden)return;
 const dt=Math.min(.05,(now-last)/1000||0);last=now;accumulator+=dt;
 let steps=0;while(accumulator>=STEP&&steps<4&&phase==="running"){simulate(STEP);accumulator-=STEP;steps++}
 render(now);if(phase==="running")raf=requestAnimationFrame(frame)};
 raf=requestAnimationFrame(frame)}
function beep(frequency,duration){if(!sound)return;try{audio=audio||new (window.AudioContext||window.webkitAudioContext)();const osc=audio.createOscillator(),gain=audio.createGain();osc.type="sine";osc.frequency.value=frequency;gain.gain.setValueAtTime(.035,audio.currentTime);gain.gain.exponentialRampToValueAtTime(.0001,audio.currentTime+duration);osc.connect(gain);gain.connect(audio.destination);osc.start();osc.stop(audio.currentTime+duration)}catch{/* Audio is optional. */}}
B.addEventListener("click",start);P.addEventListener("click",togglePause);
A.addEventListener("click",()=>{sound=!sound;A.setAttribute("aria-pressed",String(sound));A.textContent=sound?tr("mute"):tr("audio");if(sound)beep(620,.08)});
root.querySelector("#rx-share").addEventListener("click",async()=>{
 const url=new URL(location.href);url.searchParams.set("practice",String(seed));url.hash="rx-practice";
 try{if(navigator.share){await navigator.share({title:"REMIX // PRACTICE",text:tr("disclaimer"),url:url.href});return}if(navigator.clipboard?.writeText){await navigator.clipboard.writeText(url.href);message("copy");return}throw Error("clipboard unavailable")}catch(e){if(e.name!=="AbortError"){window.prompt?.(tr("copyError"),url.href);message("copyError")}}
});
function onKey(e,down){
 if(phase!=="running"||e.altKey||e.ctrlKey||e.metaKey||e.target.closest?.("input,textarea,select,[contenteditable=true]")||document.activeElement?.id==="arena")return;
 const key=e.key.toLowerCase();if(["a","arrowleft","d","arrowright","w","arrowup"," "].includes(key))e.preventDefault();
 if(key==="a"||key==="arrowleft")K.left=down;
 if(key==="d"||key==="arrowright")K.right=down;
 if(key==="w"||key==="arrowup"||key===" "){if(down&&!K.jump)jumpQueued=true;K.jump=down}
}
window.addEventListener("keydown",e=>{if(e.key==="Escape"&&["running","paused"].includes(phase)){togglePause();return}onKey(e,true)});
window.addEventListener("keyup",e=>onKey(e,false));window.addEventListener("blur",()=>{Object.keys(K).forEach(k=>K[k]=false);if(phase==="running")togglePause()});
root.querySelectorAll("[data-rx-action]").forEach(button=>{
 const action=button.dataset.rxAction;
 const release=e=>{if(e.cancelable)e.preventDefault();K[action]=false};
 button.addEventListener("pointerdown",e=>{if(phase!=="running")return;e.preventDefault();button.setPointerCapture?.(e.pointerId);if(action==="jump"&&!K.jump)jumpQueued=true;K[action]=true});
 button.addEventListener("pointerup",release);button.addEventListener("pointercancel",release);button.addEventListener("lostpointercapture",release);
});
document.addEventListener("visibilitychange",()=>{if(document.hidden&&phase==="running"){visibilityPaused=true;togglePause()}else if(!document.hidden&&visibilityPaused){visibilityPaused=false;render(performance.now())}});
window.addEventListener("remix:language",language);
window.addEventListener("resize",resize,{passive:true});
if(window.ResizeObserver)new ResizeObserver(resize).observe(canvas);
record=readRecord();build();language();resize();drawHUD();
window.RemixPractice={getState:()=>({phase,seed,elapsed,deaths,gems,score,record,serverVerified:false}),restart:start};
})();