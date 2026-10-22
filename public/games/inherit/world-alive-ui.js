/* INHERIT R15 — WORLD ALIVE.
 * Unifies existing genuine chapters, combos and world state. All placements,
 * permissions, persistence and generation handoffs stay in the original game.
 * Effects are decorative, optional, and never count as saved activity. */
(()=>{
'use strict';
const d=document,engine=window.InheritWorldAliveEngine,game=window.InheritGame;
if(!engine||!game?.snapshot)return;
const q=(s,base=d)=>base.querySelector(s);
const make=(tag,cls,txt)=>{
 const node=d.createElement(tag);if(cls)node.className=cls;
 if(txt!==undefined)node.textContent=String(txt);return node;
};
const lang=()=>{
 const value=window.InheritUI?.getLanguage?.()||d.documentElement.lang?.slice(0,2)||'ru';
 return ['ru','en','zh'].includes(value)?value:'ru';
};
const text={
 ru:{
  eyebrow:'ЖИВОЙ МИР • ГЛАВА ПОКОЛЕНИЯ',
  title:'Твоя история создаётся сейчас',
  chapter:{shore:'После прилива',signal:'Огонь на берегу',haven:'Остров для жизни',memory:'Голоса камней'},
  season:{tide:'Прилив',sun:'Солнечный день',wind:'Тёплый ветер',mist:'Утренний туман'},
  stage:{untouched:'Тихий берег',growing:'Мир оживает',settlement:'Обжитый остров',ancient:'Древнее наследие'},
  traces:'Предметов',links:'Связей',quests:'Цели главы',
  done:'Выполнено',next:'Выбрать',open:'Открой остров',progress:'Выполнено',
  goals:{
   shelter:['Создай укрытие','Оставь дерево, мох или цветы'],
   route:['Проложи путь','Помоги следующему поколению найти дорогу'],
   meeting:['Соедини предметы','Расположи дополняющие предметы рядом'],
   flame:['Оставь свет','Размести фонарь или колокольчик'],
   guidance:['Покажи дорогу','Проложи тропу или поставь указатель'],
   beacon:['Создай ориентир','Соедини свет и путь в одном месте'],
   roots:['Пусти корни','Добавь дерево или мох'],
   color:['Добавь красок','Посади цветы или поставь колокольчик'],
   refuge:['Создай живую рощу','Соедини природные предметы'],
   foundation:['Оставь память','Поставь камень или арку'],
   waystone:['Оставь знак','Добавь насыпь или указатель'],
   monument:['Создай памятное место','Соедини каменные предметы']
  },
  tools:{tree:'дерево',stone:'камень',light:'фонарь',path:'тропу',flower:'цветы',arch:'арку',chime:'колокольчик',moss:'мох',cairn:'насыпь',marker:'указатель'},
  hint:'Выбирай предмет в задании. Размещение происходит только после твоего нажатия на остров.',
  readonly:'Только просмотр. Сохранения и права владельца не меняются.',
  incomplete:'Данные мира неполные: новые достижения не засчитываются.',
  more:'Как устроен мир',story:'Все задания и история',audioOn:'Включить звук',audioOff:'Выключить звук',
  effectsOn:'Включить атмосферу',effectsOff:'Упростить эффекты',
  sound:'Звук',atmosphere:'Атмосфера',disabled:'Недоступно для этого мира',
  success:'Новый след на острове',link:'Новая связь между предметами',
  completed:'Глава выполнена настоящими действиями',passed:'Следующее поколение началось',
  wait:'Выбери место на острове — этот шаг сделаешь ты',
  truth:'Цели и связи рассчитаны из сохранённых объектов. Сезон и свет — художественные эффекты, не реальные погодные данные.',
  blocked:'Сначала открой доступное действие игры.', unavailable:'Сейчас этот предмет нельзя выбрать',
  continue:'Продолжить строительство'
 },
 en:{
  eyebrow:'LIVING WORLD • GENERATION CHAPTER',title:'Your story is taking shape',
  chapter:{shore:'After the tide',signal:'Fire by the shore',haven:'An island to live on',memory:'Voices in stone'},
  season:{tide:'High tide',sun:'Golden sun',wind:'Gentle wind',mist:'Morning mist'},
  stage:{untouched:'Quiet shore',growing:'Coming to life',settlement:'Familiar places',ancient:'Ancient legacy'},
  traces:'Traces',links:'Connections',quests:'Chapter goals',done:'Completed',next:'Choose',
  progress:'Completed',open:'Open the island',
  goals:{
   shelter:['Build shelter','Place a tree, moss or flower'],route:['Mark a route','Show the next keeper a way'],
   meeting:['Connect objects','Place matching objects nearby'],flame:['Leave a light','Place a lantern or a chime'],
   guidance:['Guide the way','Add a path or marker'],beacon:['Create a beacon','Connect light and path'],
   roots:['Put down roots','Add a tree or moss'],color:['Bring some color','Plant flowers or add a chime'],
   refuge:['Create a grove','Connect living objects'],foundation:['Leave a memory','Place a stone or arch'],
   waystone:['Mark a memory','Add a cairn or a marker'],monument:['Build a monument','Connect stone objects']
  },
  tools:{tree:'tree',stone:'stone',light:'lantern',path:'path',flower:'flowers',arch:'arch',chime:'chime',moss:'moss',cairn:'cairn',marker:'marker'},
  hint:'Choose an item in a goal, then personally click the island to place it.',
  readonly:'View only. No saved world or account rights are changed.',
  incomplete:'World data is incomplete: no achievements can be credited.',
  more:'How this world works',story:'All objectives and history',audioOn:'Enable sound',audioOff:'Mute sound',
  effectsOn:'Enable atmosphere',effectsOff:'Simplify effects',sound:'Sound',atmosphere:'Atmosphere',disabled:'Unavailable here',
  success:'A new trace on the island',link:'A new connection has formed',completed:'Chapter completed by real actions',
  passed:'A new generation begins',wait:'Choose a place on the island yourself',
  truth:'Goals and connections are calculated from saved traces. Seasons and light are fictional effects, not actual weather.',
  blocked:'Select an available game action first.',unavailable:'This item is not currently available',
  continue:'Continue building'
 },
 zh:{
  eyebrow:'生机世界 • 世代篇章',title:'你的故事正在展开',
  chapter:{shore:'潮汐之后',signal:'岸边之光',haven:'宜居岛屿',memory:'石头的记忆'},
  season:{tide:'潮汐',sun:'晴日',wind:'暖风',mist:'晨雾'},
  stage:{untouched:'寂静海岸',growing:'万物生长',settlement:'熟悉的地方',ancient:'古老传承'},
  traces:'痕迹',links:'连接',quests:'篇章目标',done:'已完成',next:'选择',
  progress:'已完成',open:'查看岛屿',
  goals:{
   shelter:['建造庇护所','添加树木、苔藓或鲜花'],route:['标记道路','为下一代指引方向'],
   meeting:['连接物件','将相配的物件放在附近'],flame:['留下光亮','放置灯笼或风铃'],
   guidance:['指引方向','添加小路或路标'],beacon:['创建灯塔','连接灯光与道路'],
   roots:['扎下根基','添加树木或苔藓'],color:['增添色彩','种植鲜花或加入风铃'],
   refuge:['建造树林','连接自然物件'],foundation:['留下记忆','放置石头或拱门'],
   waystone:['留下标记','添加石堆或路标'],monument:['建造纪念地','连接石头物件']
  },
  tools:{tree:'树木',stone:'石头',light:'灯笼',path:'小路',flower:'鲜花',arch:'拱门',chime:'风铃',moss:'苔藓',cairn:'石堆',marker:'路标'},
  hint:'在目标中选择物件，再亲自点击岛屿放置。',
  readonly:'仅供查看，存档和账号权限不会改变。',
  incomplete:'世界数据不完整，无法计算新的成就。',
  more:'世界规则',story:'全部目标与历史',audioOn:'开启音效',audioOff:'关闭音效',
  effectsOn:'开启动画',effectsOff:'简化效果',sound:'音效',atmosphere:'氛围',disabled:'当前世界不可用',
  success:'岛上留下了新痕迹',link:'物件之间形成了新联系',completed:'真实行动完成了篇章',
  passed:'新世代开始',wait:'请亲自点击岛屿选择位置',
  truth:'目标与连接由保存的痕迹计算。季节与光线是艺术效果，而非真实天气。',
  blocked:'请先选择可用的操作',unavailable:'暂时无法选择此物件',
  continue:'继续建设'
 }
};
function init(){
 const world=q('#world'),island=q('#island'),objects=q('#objects'),journey=q('.living-journey');
 if(!world||!island||!objects||!journey)return;
 const source=()=>game.snapshot();
 const model=()=>engine.summarize(source(),window);
 const section=make('section','world-alive-hub');
 section.dataset.noTranslate='';
 section.setAttribute('aria-label','Generation goals');
 const header=make('div','world-alive-hub-head'),heading=make('div','world-alive-heading');
 const eyebrow=make('span','world-alive-overline'),title=make('h2','world-alive-title');
 const meta=make('div','world-alive-meta');
 const mood=make('span','world-alive-season'),scene=make('span','world-alive-stage');
 meta.append(mood,scene);heading.append(eyebrow,title);header.append(heading,meta);
 const stats=make('div','world-alive-metrics');
 const statsValues=Array.from({length:3},()=>{
   const box=make('div','world-alive-metric'),value=make('strong'),label=make('small');
   box.append(value,label);stats.append(box);return {box,value,label};
 });
 const gameRow=make('div','world-alive-goal-row');
 const goalItems=Array.from({length:3},(_,i)=>{
   const card=make('article','world-alive-goal');
   const mark=make('span','world-alive-goal-index',String(i+1));
   const inner=make('div','world-alive-goal-copy');
   const name=make('h3','world-alive-goal-title'),description=make('p','world-alive-goal-description');
   inner.append(name,description);
   const action=make('button','world-alive-goal-action');
   action.type='button';
   action.addEventListener('click',()=>{
     const current=model(),goal=current.goals[i],c=text[lang()];
     if(!goal||goal.done||!goal.tool||!canEdit(current)){announce(c.blocked);return;}
     const type=goal.tool;
     const button=q('.tools [data-tool="'+type+'"]')||q('.catalog [data-extra="'+type+'"]');
     if(!button||button.disabled){announce(c.unavailable);return;}
     button.click();world.setAttribute('tabindex','-1');
     world.focus?.({preventScroll:true});
     world.scrollIntoView?.({block:'center',inline:'nearest',behavior:'auto'});
     announce(c.wait);
   });
   card.append(mark,inner,action);gameRow.append(card);
   return {card,mark,name,description,action};
 });
 const footer=make('div','world-alive-footer'),message=make('p','world-alive-help');
 const audio=make('button','world-alive-setting'),effects=make('button','world-alive-setting');
 const detail=make('small','world-alive-truth');
 message.textContent='';detail.textContent='';
 footer.append(message,effects,audio);
 section.append(header,stats,gameRow,footer,detail);
 // Keep the island visible in the first viewport on desktop and mobile.
 // The extended goals hub follows the actual controls, never pushes the playfield below the fold.
 const dock=q('.app > .dock');
 if(!dock)return;
 dock.insertAdjacentElement('afterend',section);
 const feedback=make('span','world-alive-feedback');feedback.setAttribute('role','status');
 feedback.setAttribute('aria-live','polite');
 feedback.setAttribute('aria-atomic','true');section.append(feedback);
 const flash=make('div','world-alive-handoff');
 flash.setAttribute('aria-hidden','true');world.append(flash);

 const fx=make('canvas','world-alive-ocean');
 fx.setAttribute('aria-hidden','true');
 world.prepend(fx);
 const ctx=fx.getContext('2d',{alpha:true});
 const reduced=window.matchMedia?.('(prefers-reduced-motion: reduce)');
 let fxEnabled=true,soundEnabled=false;
 try{fxEnabled=localStorage.getItem('inherit:world-alive-fx:v1')!=='off';}catch{}
 const audioClass=window.AudioContext||window.webkitAudioContext;
 let audioContext=null,activatedAudio=false;
 function playTone(event){
   if(!soundEnabled||!audioContext||audioContext.state!=='running')return;
   const now=audioContext.currentTime;
   const notes=event==='handoff'?[329.63,440,659.25]:event==='link'?[392,523.25,783.99]:[392,523.25];
   notes.forEach((frequency,i)=>{
     const osc=audioContext.createOscillator(),gain=audioContext.createGain();
     osc.type='sine';osc.frequency.setValueAtTime(frequency,now+i*.045);
     const start=now+i*.045;
     gain.gain.setValueAtTime(0.0001,start);
     gain.gain.exponentialRampToValueAtTime(.035,start+.035);
     gain.gain.exponentialRampToValueAtTime(0.0001,start+.34);
     osc.connect(gain);gain.connect(audioContext.destination);
     osc.start(start);osc.stop(start+.36);
   });
 }
 function announce(msg){
   feedback.textContent=msg;
 }
 effects.addEventListener('click',()=>{
   fxEnabled=!fxEnabled;
   try{localStorage.setItem('inherit:world-alive-fx:v1',fxEnabled?'on':'off');}catch{}
   updateSettings();manageAnimation();
 });
 audio.addEventListener('click',async()=>{
   if(soundEnabled){soundEnabled=false;await audioContext?.suspend?.().catch(()=>{});updateSettings();return;}
   if(!audioClass)return;
   try{
     if(!audioContext)audioContext=new audioClass();
     await audioContext.resume();
     soundEnabled=audioContext.state==='running';activatedAudio=soundEnabled;
     updateSettings();
     if(soundEnabled)playTone('place');
   }catch{soundEnabled=false;updateSettings();}
 });
 let last=null,queued=false,lastGeneration=null;
 function canEdit(status){
   if(status.readonly||d.body.classList.contains('replay-mode')||d.body.classList.contains('past')||
      q('#pass')?.disabled||q('#pass')?.getAttribute('aria-busy')==='true'||status.budget<=0)return false;
   if(game.accountMode?.()){
     const acc=window.InheritAccount?.state?.();
     return !!acc?.canEdit&&!acc?.busy&&!acc?.loading&&!acc?.pending?.length;
   }
   return true;
 }
 function updateSettings(){
   const c=text[lang()];
   audio.textContent=c.sound+' · '+(soundEnabled?c.audioOff:c.audioOn);
   audio.setAttribute('aria-pressed',String(soundEnabled));
   audio.disabled=!audioClass;
   effects.textContent=c.atmosphere+' · '+(fxEnabled?c.effectsOff:c.effectsOn);
   effects.setAttribute('aria-pressed',String(fxEnabled));
   effects.disabled=!!reduced?.matches;
   world.classList.toggle('world-alive-fx-off',!fxEnabled||!!reduced?.matches);
 }
 function changeWorld(status){
   const c=text[lang()];
   world.dataset.livingSeason=status.season;world.dataset.livingStage=status.stage;
   eyebrow.textContent=c.eyebrow;
   title.textContent=c.chapter[status.chapter]||c.title;
   mood.textContent=c.season[status.season];scene.textContent=c.stage[status.stage];
   statsValues.forEach((item,i)=>{
     item.value.textContent=String([status.objects,status.connections,status.completed+'/'+status.goalCount][i]);
     item.label.textContent=[c.traces,c.links,c.quests][i];
   });
   for(const [i,item] of goalItems.entries()){
     const goal=status.goals[i];
     item.card.hidden=!goal;
     if(!goal)continue;
     const copy=c.goals[goal.id]||[goal.id,''];
     item.name.textContent=copy[0];item.description.textContent=copy[1];
     item.card.classList.toggle('is-complete',goal.done);
     item.mark.textContent=goal.done?'✓':String(i+1);
     item.action.hidden=goal.done||!goal.tool;
     item.action.textContent=goal.done?c.done:(c.next+': '+c.tools[goal.tool]);
     item.action.disabled=!canEdit(status);
   }
   message.textContent=status.readonly?(status.limited?c.incomplete:c.readonly):c.hint;
   detail.textContent=c.truth;
   section.setAttribute('aria-label',c.eyebrow);
   updateSettings();
 }
 function refresh(){
   const current=model(),c=text[lang()];
   if(last && last.generation!==current.generation&&current.generation>last.generation&&last.pending>0&&current.pending===0){
     if(!reduced?.matches){flash.classList.remove('is-active');void flash.offsetWidth;flash.classList.add('is-active');}
     announce(c.passed);playTone('handoff');
   }else if(last&&last.generation===current.generation&&last.completed<current.completed&&current.completed===current.goalCount&&current.goalCount>0){
     announce(c.completed);playTone('link');
   }
   changeWorld(current);
   last=current;lastGeneration=current.generation;
   manageAnimation();
 }
 function schedule(){
   if(queued)return;queued=true;
   queueMicrotask(()=>{queued=false;refresh()});
 }
 new MutationObserver(schedule).observe(objects,{childList:true});
 const gen=q('#gen');
 if(gen)new MutationObserver(schedule).observe(gen,{childList:true,subtree:true,characterData:true});
 new MutationObserver(schedule).observe(d.documentElement,{attributes:true,attributeFilter:['lang']});
 const pass=q('#pass');
 if(pass)new MutationObserver(schedule).observe(pass,{attributes:true,attributeFilter:['disabled','aria-busy']});

 // Visual confirmation only when the untouched native world click actually spends
 // one budget point and places one saved object. A preview or imported save cannot.
 world.addEventListener('click',event=>{
   const target=event.target;
   if(!(target instanceof Element)||target.closest('button,[data-memory],.dock,.panel'))return;
   const before=source();
   const generation=before.generation,oldCount=before.objects?.length||0;
   const oldBudget=before.budget;
   const pending=before.pending?.length||0,changes=before.changes?.length||0;
   queueMicrotask(()=>{
     const after=source();
     const valid=after.generation===generation&&after.objects?.length===oldCount+1&&
       after.budget===oldBudget-1&&
       ((Array.isArray(after.pending)&&after.pending.length===pending+1)||
        (Array.isArray(after.changes)&&after.changes.length===changes+1));
     if(!valid)return;
     const placed=after.objects[after.objects.length-1];
     const c=text[lang()];
     const beforeLinked=window.InheritLegacyEngine?.derive?.(before)?.total||0;
     const afterLinked=window.InheritLegacyEngine?.derive?.(after)?.total||0;
     if(!reduced?.matches&&fxEnabled)burst(placed);
     announce(afterLinked>beforeLinked?c.link:c.success);
     playTone(afterLinked>beforeLinked?'link':'place');
   });
 },true);
 function burst(object){
   if(!object||!Number.isFinite(object.x)||!Number.isFinite(object.y))return;
   const wr=world.getBoundingClientRect(),ir=island.getBoundingClientRect();
   const px=ir.left+ir.width*object.x/100-wr.left,py=ir.top+ir.height*object.y/100-wr.top;
   if(!Number.isFinite(px)||!Number.isFinite(py))return;
   const spark=make('div','world-alive-burst');
   spark.style.left=px+'px';spark.style.top=py+'px';spark.setAttribute('aria-hidden','true');
   for(let i=0;i<8;i++){const ray=make('i');ray.style.setProperty('--i',String(i));spark.append(ray);}
   world.append(spark);
   window.setTimeout(()=>spark.remove(),1050);
 }

 // Lightweight local 2D atmosphere: capped pixel ratio and 20 FPS, no network,
 // no canvas input interception, paused off-screen and under reduced-motion.
 let seen=true,raf=0,lastFrame=0,cw=0,ch=0;
 function dimension(){
   if(!ctx)return;
   const w=Math.max(1,Math.round(world.clientWidth)),h=Math.max(1,Math.round(world.clientHeight));
   const ratio=Math.min(1.5,window.devicePixelRatio||1);
   cw=w;ch=h;
   fx.width=Math.round(w*ratio);fx.height=Math.round(h*ratio);
   ctx.setTransform(ratio,0,0,ratio,0,0);
 }
 function draw(time){
   if(!ctx||!cw||!ch)return;
   ctx.clearRect(0,0,cw,ch);
   const state=last||model(),season=state.season;
   const glow=season==='sun'?0.35:season==='mist'?.11:.22;
   const t=time*.00035;
   const horizon=ch*.54;
   const light=ctx.createRadialGradient(cw*.70,ch*.28,10,cw*.70,ch*.28,cw*.45);
   light.addColorStop(0,'rgba(245,227,158,'+glow+')');
   light.addColorStop(1,'rgba(245,227,158,0)');
   ctx.fillStyle=light;ctx.fillRect(0,0,cw,ch);
   const rows=season==='mist'?11:season==='wind'?25:19;
   ctx.lineWidth=1.25;
   for(let n=0;n<rows;n++){
     const y=horizon+(n/rows)*(ch-horizon);
     const phase=t*1.2+n*.91;
     const start=(Math.sin(n*28.7+phase)*.16+.20)*cw;
     const width=(.08+(n%7)*.022)*cw;
     ctx.strokeStyle='rgba(238,247,208,'+(season==='mist'?.10:.11+(n%4)*.027)+')';
     ctx.beginPath();
     ctx.moveTo(start,y);
     ctx.bezierCurveTo(start+width*.25,y-Math.sin(phase)*4,start+width*.65,y+Math.cos(phase)*3,start+width,y);
     ctx.stroke();
   }
   const count=season==='wind'?22:season==='mist'?9:season==='sun'?15:17;
   for(let k=0;k<count;k++){
     const x=((k*137.51+time*(season==='wind'?.023:.008))%(cw+50)+cw+50)%(cw+50)-25;
     const y=((k*97.13+Math.sin(t*1.2+k)*16)%(ch*.68))+(ch*.09);
     const radius=season==='mist'?3+(k%4):1.4+(k%3)*.35;
     ctx.beginPath();ctx.arc(x,y,radius,0,Math.PI*2);
     ctx.fillStyle=season==='sun'?'rgba(255,243,177,.33)':season==='mist'?'rgba(235,255,238,.13)':'rgba(226,246,214,.25)';
     ctx.fill();
   }
 }
 function shouldAnimate(){
   return !!ctx&&fxEnabled&&!reduced?.matches&&!d.hidden&&seen&&!d.body.classList.contains('cine-eco');
 }
 function tick(now){
   raf=0;
   if(!shouldAnimate()){ctx?.clearRect(0,0,cw,ch);return;}
   if(now-lastFrame>=48){lastFrame=now;draw(now);}
   raf=requestAnimationFrame(tick);
 }
 function manageAnimation(){
   if(!shouldAnimate()){if(raf)cancelAnimationFrame(raf);raf=0;ctx?.clearRect(0,0,cw,ch);return;}
   if(!raf)raf=requestAnimationFrame(tick);
 }
 if(ctx){dimension();
   if('ResizeObserver' in window)new ResizeObserver(()=>{dimension();manageAnimation()}).observe(world);
   else window.addEventListener('resize',()=>{dimension();manageAnimation()},{passive:true});
   if('IntersectionObserver' in window)new IntersectionObserver(entries=>{seen=!!entries[0]?.isIntersecting;manageAnimation()},{threshold:0}).observe(world);
   d.addEventListener('visibilitychange',manageAnimation);
   reduced?.addEventListener?.('change',manageAnimation);
 }
 window.InheritWorldAliveUI=Object.freeze({
  getState:model,refresh:schedule,getEffectsEnabled:()=>fxEnabled,
  getSoundEnabled:()=>soundEnabled&&activatedAudio
 });
 refresh();
}
if(d.readyState==='loading')d.addEventListener('DOMContentLoaded',init,{once:true});
else init();
})();
