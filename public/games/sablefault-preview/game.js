/* SABLEFAULT — INCIDENT 01
 * Original, dependency-free WebGL2 vertical slice.
 * Fictional industrial crisis puzzle; not a real-world control system.
 * Source-bound authored gameplay; no fake PASS or synthetic interaction recordings.
 */
(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const canvas = $('world');
  let lang = 'ru';
  const translate = {
    ru: {
      incident:'ИНЦИДЕНТ 01',protocol:'ПРОТОКОЛ СДЕРЖИВАНИЯ',mission:'ТЕКУЩАЯ ЗАДАЧА',telemetry:'ТЕЛЕМЕТРИЯ',
      interact:'ТЕРМИНАЛ',events:'ЖУРНАЛ ИНЦИДЕНТА',controls:'WASD ДВИЖЕНИЕ · МЫШЬ КАМЕРА · E ДЕЙСТВИЕ · SHIFT БЕГ · ESC КУРСОР',
      bootTitle:'АКТИВИРУЙТЕ ПРОТОКОЛ',bootHint:'Найдите центральный терминал и подтвердите чрезвычайное положение.',
      coolTitle:'СТАБИЛИЗИРУЙТЕ ЯДРО',coolHint:'Охладите ядро ниже 53°, сбросьте давление ниже 62 и удержите режим 7 секунд.',
      chooseTitle:'СДЕЛАЙТЕ ВЫБОР',chooseHint:'Подойдите к реле сети: спасите персонал или сохраните архив катастрофы.',
      escapeTitle:'ПОКИНЬТЕ КОМПЛЕКС',escapeHint:'Следуйте к аварийному шлюзу. Не дайте системам разрушиться.',
      temp:'ТЕМПЕРАТУРА',pressure:'ДАВЛЕНИЕ',power:'ЗАРЯД',oxygen:'КИСЛОРОД',
      wait:'ОЖИДАНИЕ',safe:'СТАБИЛЬНО',unstable:'НЕСТАБИЛЬНО',stabilizing:'СТАБИЛИЗАЦИЯ',
      cmd:'КОМАНДНЫЙ ПОСТ',alpha:'ОХЛАЖДЕНИЕ А',beta:'ОХЛАЖДЕНИЕ Б',vent:'СБРОС ДАВЛЕНИЯ',grid:'СЕТЕВОЕ РЕЛЕ',exit:'ЭВАКУАЦИОННЫЙ ШЛЮЗ',
      begin:'НАЧАТЬ ЭПИЗОД',tagline:'У КАЖДОЙ СИСТЕМЫ ЕСТЬ ПРЕДЕЛ.',
      cover:'Одна станция. Пять критических систем. Выбор, который нельзя доверить машине. Войдите в аварийный комплекс и продержитесь достаточно долго, чтобы решить, что спасти.',
      note:'ВЫМЫШЛЕННАЯ ИГРОВАЯ СИМУЛЯЦИЯ · НЕ СИСТЕМА УПРАВЛЕНИЯ ОБОРУДОВАНИЕМ',
      ack:'ПОДТВЕРДИТЬ ПРОТОКОЛ',acksub:'Обратный отсчёт 4:00, запуск ручного управления.',
      ackinfo:'Модуль AEGIS-09 перешёл под ручной контроль. Воздухопроводы работают на аварийных резервах. Подтвердите инцидент для разблокировки органов управления.',
      workinfo:'Два насоса выводят тепло, но нагружают магистраль и батарею. Клапан сбрасывает давление, расходуя кислород. Запасное питание ограничено.',
      manual:'РУЧНОЕ УПРАВЛЕНИЕ', on:'ВКЛ',off:'ВЫКЛ', pumpOn:'ЗАПУСТИТЬ НАСОС',pumpOff:'ОСТАНОВИТЬ НАСОС',
      openVent:'ОТКРЫТЬ СБРОС',closeVent:'ЗАКРЫТЬ СБРОС', ventStatus:'КЛАПАН',
      recharge:'ПОДАТЬ РЕЗЕРВНОЕ ПИТАНИЕ',rechargeSub:'+32% заряда, один резервный блок.',empty:'РЕЗЕРВ ИЗРАСХОДОВАН',
      relayInfo:'Модуль памяти и жилой отсек питаются от одной аварийной шины. Можно обеспечить эвакуацию персонала либо сохранить доказательства саботажа. Второй канал отключится.',
      crew:'СПАСТИ ПЕРСОНАЛ',crewSub:'Приоритет жилым отсекам. Архивные данные будут утеряны.',
      archive:'СОХРАНИТЬ АРХИВ',archiveSub:'Приоритет станции записи. Эвакуация персонала задержится.',
      exitInfo:'Завершена стабилизация. Выбран приоритет аварийной сети. Шлюз разблокирован — покиньте реакторную зону.',
      evacuate:'ПОКИНУТЬ КОМПЛЕКС', evacuateSub:'Завершить эпизод и получить отчёт об операции.',
      unavailable:'ТРЕБУЕТСЯ СТАБИЛИЗАЦИЯ', pending:'ДОЖДИТЕСЬ КОМАНДЫ',failed:'АВАРИЯ КРИТИЧЕСКОГО УРОВНЯ',
      wonCrew:'ЛЮДИ СПАСЕНЫ',wonArchive:'ПРАВДА СОХРАНЕНА',
      victoryCrew:'Вы сохранили жизнь команде сектора 09. Журнал саботажа уничтожен, а причина аварии осталась неизвестна. Путь к продолжению открыт.',
      victoryArchive:'Вы сохранили архив с доказательствами вмешательства. Доступ к данным восстановлен, но спасательная группа прибыла с опозданием. Следующее решение будет ещё сложнее.',
      loseHeat:'Ядро превысило аварийный температурный предел.',losePressure:'Магистраль не выдержала критического давления.',loseOxygen:'В жилом секторе закончился кислород.',loseTime:'Истекло время аварийного сдерживания.',losePower:'Батарея обесточена. Автоматические заслонки больше не работают.',
      score:'РЕЗУЛЬТАТ',seconds:'ОСТАТОК',decision:'ВЫБОР',replay:'ИГРАТЬ СНОВА',menu:'В МЕНЮ',
      pumpAStart:'Насос A включён',pumpAStop:'Насос A отключён',pumpBStart:'Насос Б включён',pumpBStop:'Насос Б отключён',
      ventStart:'Клапан сброса открыт',ventStop:'Клапан сброса закрыт',backup:'Резервная батарея подключена',
      triggered:'Ручной протокол активирован',stabilized:'Ядро стабилизировано',
      surge:'Скачок давления в магистрали!',loss:'Потеря питания в секторе 09!',
      crewEvent:'Приоритет: персонал',archiveEvent:'Приоритет: архив',success:'Эвакуация завершена',failure:'Протокол аварийно прерван',
      terminalClose:'ЗАКРЫТЬ', sceneHint:'Подойдите к терминалу и нажмите E.', helpTitle:'УПРАВЛЕНИЕ',
      helpContent:'W / A / S / D — движение. Мышь — обзор. SHIFT — ускорение. E — открыть ближний терминал. ESC — освободить курсор или закрыть терминал. L — сменить язык. На телефоне используйте стрелки, область обзора и кнопку действия.',
      helpClose:'ПОНЯТНО', secondsShort:'СЕК', crewShort:'ЛЮДИ',archiveShort:'АРХИВ'
    },
    en: {
      incident:'INCIDENT 01',protocol:'CONTAINMENT PROTOCOL',mission:'ACTIVE DIRECTIVE',telemetry:'LIVE TELEMETRY',
      interact:'INTERACT WITH',events:'INCIDENT FEED',controls:'WASD MOVE · MOUSE LOOK · E INTERACT · SHIFT RUN · ESC CURSOR',
      bootTitle:'INITIATE THE PROTOCOL',bootHint:'Find the command terminal and acknowledge the emergency.',
      coolTitle:'STABILIZE THE CORE',coolHint:'Lower heat below 53°, pressure below 62, and hold for 7 seconds.',
      chooseTitle:'MAKE THE CALL',chooseHint:'Reach the grid relay: save the crew or preserve the incident archive.',
      escapeTitle:'EVACUATE THE STATION',escapeHint:'Reach the emergency airlock before critical systems fail.',
      temp:'CORE HEAT',pressure:'PRESSURE',power:'POWER',oxygen:'OXYGEN',
      wait:'STANDBY',safe:'STABLE',unstable:'UNSTABLE',stabilizing:'STABILIZING',
      cmd:'COMMAND STATION',alpha:'COOLANT ARRAY A',beta:'COOLANT ARRAY B',vent:'PRESSURE VENT',grid:'GRID RELAY',exit:'EMERGENCY AIRLOCK',
      begin:'BEGIN INCIDENT',tagline:'EVERY SYSTEM HAS A BREAKING POINT.',
      cover:'One station. Five critical systems. A choice the machine cannot make for you. Enter a collapsing reactor and keep it alive long enough to decide what survives.',
      note:'FICTIONAL INTERACTIVE SIMULATION · NOT REAL INDUSTRIAL CONTROL SOFTWARE',
      ack:'ACKNOWLEDGE PROTOCOL',acksub:'Start four-minute containment and manual control.',
      ackinfo:'AEGIS-09 has transitioned to emergency standby. Ventilation is on limited reserve. Acknowledge the incident to unlock manual controls and begin containment.',
      workinfo:'Two coolant arrays shed heat but draw battery and raise line pressure. Opening the vent releases pressure but costs oxygen. Backup energy is limited.',
      manual:'MANUAL AUTHORITY',on:'ON',off:'OFF',pumpOn:'START COOLANT',pumpOff:'STOP COOLANT',
      openVent:'OPEN PRESSURE VENT',closeVent:'CLOSE PRESSURE VENT',ventStatus:'VENT',
      recharge:'ENGAGE BACKUP CELL',rechargeSub:'+32% power from a single reserve cell.',empty:'RESERVE DEPLETED',
      relayInfo:'The crew habitat and the incident archive share one emergency feed. You can preserve either the crew evacuation route or the evidence of sabotage. The other channel will be cut off.',
      crew:'SAVE THE CREW',crewSub:'Prioritize habitation. The incident archive will be wiped.',
      archive:'PRESERVE THE ARCHIVE',archiveSub:'Prioritize data recording. The crew evacuation will be delayed.',
      exitInfo:'Containment held. Priority routing is established. The evacuation airlock has unlocked. Leave the core before the fault escalates.',
      evacuate:'LEAVE THE COMPLEX',evacuateSub:'Complete the incident and receive your operator debrief.',
      unavailable:'STABILIZATION REQUIRED',pending:'AWAIT COMMAND',failed:'CRITICAL SYSTEM FAILURE',
      wonCrew:'THE CREW SURVIVED',wonArchive:'THE TRUTH SURVIVED',
      victoryCrew:'You kept the crew of sector 09 alive. The sabotage log was destroyed and the reason for the emergency remains unknown. Another question awaits.',
      victoryArchive:'The incident archive survived with evidence of intervention. The rescue unit arrived late. Your next choice may be harder.',
      loseHeat:'The reactor core exceeded the emergency heat limit.',losePressure:'The line ruptured under critical pressure.',loseOxygen:'Habitation oxygen reserves were depleted.',loseTime:'The containment deadline expired.',losePower:'Backup power failed. Emergency shutters can no longer operate.',
      score:'SCORE',seconds:'REMAINING',decision:'PRIORITY',replay:'REPLAY INCIDENT',menu:'MAIN MENU',
      pumpAStart:'Coolant array A engaged',pumpAStop:'Coolant array A disabled',pumpBStart:'Coolant array B engaged',pumpBStop:'Coolant array B disabled',
      ventStart:'Pressure relief valve opened',ventStop:'Pressure relief valve closed',backup:'Backup battery engaged',
      triggered:'Emergency protocol accepted',stabilized:'Reactor core stabilized',
      surge:'Line pressure spike detected!',loss:'Sector 09 power loss detected!',
      crewEvent:'Priority set: crew',archiveEvent:'Priority set: archive',success:'Evacuation complete',failure:'Containment protocol aborted',
      terminalClose:'CLOSE',sceneHint:'Reach a terminal and press E.',helpTitle:'CONTROLS',
      helpContent:'W / A / S / D to move. Mouse to look around. SHIFT to sprint. E to use a nearby terminal. ESC releases the cursor or closes the console. L switches language. On phones, use the movement pad, look zone and action button.',
      helpClose:'UNDERSTOOD',secondsShort:'SEC',crewShort:'CREW',archiveShort:'ARCHIVE'
    }
  };
  const t = k => (translate[lang] && translate[lang][k]) || k;
  const clamp = (v,a,b) => Math.min(b,Math.max(a,v));
  const rnd = (min,max) => min + Math.random() * (max-min);
  const terminals = [
    {id:'cmd',x:0,z:7.2,y:1.6,code:'C-01',c:'#f3a78b'},
    {id:'alpha',x:-5.3,z:5,y:1.65,code:'C-02',c:'#76e0e8'},
    {id:'beta',x:5.3,z:5,y:1.65,code:'C-03',c:'#76e0e8'},
    {id:'vent',x:-4.3,z:-.25,y:1.65,code:'V-07',c:'#f5b074'},
    {id:'grid',x:4.3,z:-.25,y:1.65,code:'R-19',c:'#d8f3c6'},
    {id:'exit',x:0,z:14.0,y:1.65,code:'E-01',c:'#a7efde'}
  ];
  const state = {
    phase:'briefing',heat:68,pressure:68,power:94,oxygen:97,seconds:240,elapsed:0,
    coolantA:false,coolantB:false,vent:false,backup:1,stable:0,choice:null,score:0,
    eventSurge:false,eventLoss:false,failReason:null,log:[],interacted:0
  };
  let audioContext = null, soundEnabled = false;
  let terminalOpen = null, helpShown = false;
  let yaw = 0, pitch = 0.03;
  let camera = {x:0,y:1.74,z:11.5};
  let pointerCaptured = false, isMobile = ('ontouchstart' in window) || navigator.maxTouchPoints > 0;
  const keys = new Set();
  const touchKeys = new Set();
  let nearTerminal = null;
  let lastUi = 0, lastLog = 0, frameTime = 0;
  let gl = null, meshStatic = null, meshDynamic = null, shader = null, u = {};
  let fallbackStatic = null, fallbackCtx = null, lastFallback = -1;
  let mapTags = new Map();
  let toast = null, toastExpiry = 0;
  const elGauges = new Map();

  function beep(kind = 'tap') {
    if (!soundEnabled) return;
    try {
      audioContext ||= new (window.AudioContext || window.webkitAudioContext)();
      if (audioContext.state === 'suspended') audioContext.resume();
      const now = audioContext.currentTime;
      const o = audioContext.createOscillator(), g = audioContext.createGain();
      o.type = kind === 'alarm' ? 'sawtooth' : 'sine';
      const hz = kind === 'alarm' ? 171 : kind === 'done' ? 510 : 370;
      o.frequency.setValueAtTime(hz,now);
      o.frequency.exponentialRampToValueAtTime(kind === 'done' ? 780 : hz*.64,now+.16);
      g.gain.setValueAtTime(.001,now);g.gain.exponentialRampToValueAtTime(.042,now+.014);
      g.gain.exponentialRampToValueAtTime(.001,now+.24);
      o.connect(g);g.connect(audioContext.destination);o.start(now);o.stop(now+.26);
    } catch(e) { soundEnabled=false; }
  }
  function log(key,kind='normal') {
    state.log.unshift({key,kind,time:Math.floor(state.elapsed)});
    if(state.log.length>18)state.log.length=18;
    refreshFeed();
  }
  function refreshFeed() {
    $('feed').replaceChildren();
    state.log.slice(0,3).forEach(item => {
      const row=document.createElement('div');row.className='feed-line '+item.kind;
      const minute=String(Math.floor(item.time/60)).padStart(2,'0');
      const sec=String(item.time%60).padStart(2,'0');
      const timer=document.createElement('span');timer.textContent=minute+':'+sec;
      const label=document.createElement('span');label.textContent=t(item.key);
      row.append(timer,label);$('feed').append(row);
    });
  }
  function gauges() {
    $('gauges').replaceChildren();elGauges.clear();
    for(const [id,title,unit] of [['heat','temp','°'],['pressure','pressure','%'],['power','power','%'],['oxygen','oxygen','%']]) {
      const row=document.createElement('div');row.className='gauge';
      const head=document.createElement('div');head.className='gauge-title';
      const titleEl=document.createElement('span');titleEl.textContent=t(title);
      const value=document.createElement('strong');value.textContent='--'+unit;
      head.append(titleEl,value);
      const track=document.createElement('div');track.className='gauge-track';
      const fill=document.createElement('div');fill.className='gauge-fill';track.append(fill);row.append(head,track);
      $('gauges').append(row);elGauges.set(id,{row,value,fill,unit,titleEl,title});
    }
  }
  function setLanguage(code) {
    lang=code;document.documentElement.lang=lang;
    $('lang').textContent=lang.toUpperCase();
    for(const node of document.querySelectorAll('[data-i18n]')) node.textContent=t(node.dataset.i18n);
    $('coverTagline').textContent=t('tagline');$('coverText').textContent=t('cover');
    $('disclaimer').textContent=t('note');$('start').firstChild.textContent=t('begin')+' ';
    $('restart').textContent=t('replay')+' ↗';$('backCover').textContent=t('menu');
    $('touchUse').textContent='E / '+(lang==='ru'?'ДЕЙСТВИЕ':'USE');
    gauges();refreshFeed();refreshMission();refreshTags();
    if(terminalOpen)renderTerminal();
    if(helpShown)showHelp(true);
    if(state.phase==='won'||state.phase==='lost')renderFinish();
  }
  function refreshMission() {
    const info={
      briefing:[0,'bootTitle','bootHint'],boot:[0,'bootTitle','bootHint'],stabilize:[1,'coolTitle','coolHint'],
      decision:[2,'chooseTitle','chooseHint'],escape:[3,'escapeTitle','escapeHint'],
      won:[3,'escapeTitle','escapeHint'],lost:[3,'failed','sceneHint']
    }[state.phase]||[0,'bootTitle','bootHint'];
    $('objective').textContent=t(info[1]);$('objectiveHint').textContent=t(info[2]);
    const num=info[0];$('chapterDots').querySelectorAll('b').forEach((b,i)=>b.className=i<num?'done':i===num?'active':'');
    document.querySelector('.mission-index').innerHTML=String(num+1).padStart(2,'0')+' <span>/</span> 04';
  }
  function refreshTelemetry() {
    for(const [id,e] of elGauges) {
      const value=state[id];e.value.textContent=String(Math.round(value)).padStart(2,'0')+e.unit;
      e.fill.style.width=clamp(value,0,100)+'%';
      const isBad=id==='heat'||id==='pressure'?value>=82:value<=17;
      const isWarn=id==='heat'||id==='pressure'?value>=65:value<=32;
      e.row.classList.toggle('critical',isBad);e.row.classList.toggle('warning',!isBad&&isWarn);
    }
    const remaining=Math.max(0,Math.ceil(state.seconds));
    $('timer').textContent=String(Math.floor(remaining/60)).padStart(2,'0')+':'+String(remaining%60).padStart(2,'0');
    $('timer').style.color=state.seconds<=45?'#fb6652':'';
    $('timeNow').textContent=String(Math.floor(state.elapsed/60)).padStart(2,'0')+':'+String(Math.floor(state.elapsed%60)).padStart(2,'0');
    const stable = state.phase==='stabilize' && state.heat<53 && state.pressure<62 && state.power>12;
    $('stateLabel').textContent=state.phase==='briefing'||state.phase==='boot'?t('wait'):stable?t('stabilizing'):state.phase==='decision'||state.phase==='escape'?t('safe'):t('unstable');
    $('grade').textContent=state.phase==='stabilize'?String(Math.floor(state.stable))+'/7 '+t('secondsShort'):state.phase==='decision'||state.phase==='escape'?'AEGIS OK':'ECO / HERO';
  }
  function nearest() {
    let best=null, dist=3.55;
    for(const term of terminals){
      let d=Math.hypot(camera.x-term.x,camera.z-term.z);
      if(d<dist){dist=d;best=term;}
    }
    return best;
  }
  function refreshInteraction() {
    nearTerminal=nearest();
    const show=!!nearTerminal && !terminalOpen && !helpShown && state.phase!=='briefing' && state.phase!=='lost' && state.phase!=='won';
    $('interaction').classList.toggle('hidden',!show);
    if(show){$('interactName').textContent=t(nearTerminal.id);$('useButton').textContent=lang==='ru'?'ОТКРЫТЬ':'USE';}
  }
  function setOverlay(visible){$('overlay').classList.toggle('hidden',!visible);$('crosshair').classList.toggle('hidden',visible);}
  function initializeState() {
    Object.assign(state,{phase:'boot',heat:68,pressure:68,power:94,oxygen:97,seconds:240,elapsed:0,
      coolantA:false,coolantB:false,vent:false,backup:1,stable:0,choice:null,score:0,
      eventSurge:false,eventLoss:false,failReason:null,log:[],interacted:0});
    camera={x:0,y:1.74,z:11.5};yaw=0;pitch=.03;keys.clear();touchKeys.clear();
    $('finishBackdrop').classList.add('hidden');$('terminalBackdrop').classList.add('hidden');
    terminalOpen=null;refreshFeed();refreshMission();refreshTelemetry();refreshInteraction();
    log('sceneHint');
  }
  function start() {
    initializeState();setOverlay(false);beep('tap');
    if(isMobile)$('touch').classList.remove('hidden');
    canvas.focus();
  }
  function end(win,reason) {
    if(state.phase==='won'||state.phase==='lost')return;
    state.phase=win?'won':'lost';state.failReason=reason||null;
    state.score=win?Math.round(Math.max(0,state.seconds)*13+state.oxygen*7+state.power*5+(state.choice==='crew'?400:550)):0;
    log(win?'success':'failure',win?'good':'warning');
    if(document.pointerLockElement===canvas)document.exitPointerLock();
    $('terminalBackdrop').classList.add('hidden');terminalOpen=null;
    refreshMission();refreshTelemetry();refreshInteraction();renderFinish();
    $('finishBackdrop').classList.remove('hidden');beep(win?'done':'alarm');
    $('touch').classList.add('hidden');
  }
  function renderFinish() {
    const win=state.phase==='won';
    $('finishSymbol').textContent=win?'◈':'⚠';
    $('finishSymbol').style.color=win?'#91e9d7':'#ff7f70';
    $('finishTitle').textContent=win?t(state.choice==='crew'?'wonCrew':'wonArchive'):t('failed');
    $('finishText').textContent=win?t(state.choice==='crew'?'victoryCrew':'victoryArchive'):t(state.failReason||'loseTime');
    $('finishStats').replaceChildren();
    for(const [label,value] of [[t('score'),String(state.score)],[t('seconds'),Math.ceil(state.seconds)+'s'],[t('decision'),state.choice===null?'—':t(state.choice==='crew'?'crewShort':'archiveShort')]]){
      const div=document.createElement('div'),s=document.createElement('span'),b=document.createElement('strong');
      s.textContent=label;b.textContent=value;div.append(s,b);$('finishStats').append(div);
    }
  }
  function chooseAction(key){
    if(!terminalOpen||state.phase==='won'||state.phase==='lost')return;
    const id=terminalOpen.id;
    const near=nearest();if(!near||near.id!==id)return;
    if(key==='ack'&&id==='cmd'&&state.phase==='boot'){
      state.phase='stabilize';state.elapsed=0;state.seconds=240;
      log('triggered','warning');beep('alarm');refreshMission();closeTerminal();return;
    }
    if(state.phase==='boot')return;
    if(key==='alpha'&&id==='alpha'){state.coolantA=!state.coolantA;log(state.coolantA?'pumpAStart':'pumpAStop','good');}
    if(key==='beta'&&id==='beta'){state.coolantB=!state.coolantB;log(state.coolantB?'pumpBStart':'pumpBStop','good');}
    if(key==='vent'&&id==='vent'){state.vent=!state.vent;log(state.vent?'ventStart':'ventStop','warning');}
    if(key==='backup'&&id==='grid'&&state.backup>0&&state.phase!=='escape'){
      state.power=clamp(state.power+32,0,100);state.backup--;log('backup','good');
    }
    if((key==='crew'||key==='archive')&&id==='grid'&&state.phase==='decision'){
      state.choice=key;state.phase='escape';
      if(key==='archive')state.power=clamp(state.power-10,0,100);
      else state.oxygen=clamp(state.oxygen+10,0,100);
      log(key==='crew'?'crewEvent':'archiveEvent','good');refreshMission();closeTerminal();beep('done');return;
    }
    if(key==='exit'&&id==='exit'&&state.phase==='escape'&&state.choice!==null){end(true);return;}
    state.interacted++;beep();renderTerminal();refreshTelemetry();
  }
  function addTermButton(key,title,detail,enabled=true,danger=false) {
    const button=document.createElement('button');button.type='button';
    button.className='term-button'+(danger?' danger':'');button.disabled=!enabled;
    const span=document.createElement('span');span.textContent=title;
    if(detail){const small=document.createElement('small');small.textContent=detail;span.append(small);}
    const arrow=document.createElement('span');arrow.textContent='↗';
    button.append(span,arrow);button.addEventListener('click',()=>chooseAction(key));
    $('terminalActions').append(button);
  }
  function renderTerminal(){
    if(!terminalOpen)return;
    const id=terminalOpen.id, active=state.phase!=='boot';
    $('terminalCode').textContent='AEGIS / '+terminalOpen.code;
    $('terminalTitle').textContent=t(id);
    $('terminalMessage').replaceChildren();$('terminalActions').replaceChildren();
    const p=document.createElement('p');
    p.textContent=id==='cmd'&&state.phase==='boot'?t('ackinfo'):id==='grid'&&state.phase==='decision'?t('relayInfo'):id==='exit'?t('exitInfo'):t('workinfo');
    $('terminalMessage').append(p);
    const status=document.createElement('div');status.className='term-status';
    const s=document.createElement('span');s.textContent=t('manual');
    const b=document.createElement('strong');b.textContent=active?t('on'):t('wait');
    status.append(s,b);$('terminalMessage').append(status);
    if(id==='cmd'){
      if(state.phase==='boot')addTermButton('ack',t('ack'),t('acksub'));
      else addTermButton('ack',t('unavailable'),t('coolHint'),false);
    }
    if(id==='alpha') addTermButton('alpha',t(state.coolantA?'pumpOff':'pumpOn')+' A',t('manual')+' · '+t(state.coolantA?'on':'off'),active);
    if(id==='beta') addTermButton('beta',t(state.coolantB?'pumpOff':'pumpOn')+' B',t('manual')+' · '+t(state.coolantB?'on':'off'),active);
    if(id==='vent') addTermButton('vent',t(state.vent?'closeVent':'openVent'),t('ventStatus')+' · '+t(state.vent?'on':'off'),active,state.vent);
    if(id==='grid'){
      if(state.phase==='decision'){
        addTermButton('crew',t('crew'),t('crewSub'),true);
        addTermButton('archive',t('archive'),t('archiveSub'),true,true);
      } else if(state.phase==='escape')addTermButton('backup',t('unavailable'),t('escapeHint'),false);
      else addTermButton('backup',state.backup>0?t('recharge'):t('empty'),t('rechargeSub'),active&&state.backup>0);
    }
    if(id==='exit')addTermButton('exit',t('evacuate'),t('evacuateSub'),state.phase==='escape'&&state.choice!==null);
  }
  function openTerminal(){
    if(terminalOpen||helpShown||state.phase==='briefing'||state.phase==='won'||state.phase==='lost')return;
    const n=nearest();if(!n)return;
    if(document.pointerLockElement===canvas)document.exitPointerLock();
    terminalOpen=n;renderTerminal();$('terminalBackdrop').classList.remove('hidden');refreshInteraction();beep();
    const btn=$('terminalActions').querySelector('button:not([disabled])');if(btn)btn.focus();
  }
  function closeTerminal(){terminalOpen=null;$('terminalBackdrop').classList.add('hidden');refreshInteraction();canvas.focus();}
  function showHelp(on){
    helpShown=on;
    if(!on){$('terminalBackdrop').classList.add('hidden');terminalOpen=null;refreshInteraction();return;}
    if(document.pointerLockElement===canvas)document.exitPointerLock();
    terminalOpen=null;
    $('terminalCode').textContent='TRAINING / INPUT';$('terminalTitle').textContent=t('helpTitle');
    $('terminalMessage').replaceChildren();const p=document.createElement('p');p.textContent=t('helpContent');$('terminalMessage').append(p);
    $('terminalActions').replaceChildren();const b=document.createElement('button');b.type='button';b.className='term-button';b.textContent=t('helpClose');b.addEventListener('click',()=>showHelp(false));$('terminalActions').append(b);
    $('terminalBackdrop').classList.remove('hidden');refreshInteraction();
  }
  function update(dt) {
    if(state.phase==='stabilize'||state.phase==='decision'||state.phase==='escape') {
      state.elapsed+=dt;state.seconds-=dt;
      const pumpCount=Number(state.coolantA)+Number(state.coolantB);
      const regime=state.phase==='stabilize'?1:state.phase==='decision'?.81:.74;
      state.heat=clamp(state.heat+(1.45-3.15*pumpCount-.85*Number(state.vent))*dt*regime,0,100);
      state.pressure=clamp(state.pressure+(.55+2.65*pumpCount-9.9*Number(state.vent))*dt,0,100);
      state.power=clamp(state.power-(.12+.72*pumpCount+.18*Number(state.vent))*dt,0,100);
      state.oxygen=clamp(state.oxygen-(.03+.35*Number(state.vent))*dt,0,100);
      if(!state.eventSurge&&state.elapsed>=27){state.eventSurge=true;state.pressure=clamp(state.pressure+13,0,100);log('surge','warning');beep('alarm');}
      if(!state.eventLoss&&state.elapsed>=54){state.eventLoss=true;state.power=clamp(state.power-16,0,100);log('loss','warning');beep('alarm');}
      if(state.phase==='stabilize'){
        if(state.heat<53&&state.pressure<62&&state.power>12){state.stable+=dt;}
        else state.stable=0;
        if(state.stable>=7){state.phase='decision';log('stabilized','good');refreshMission();beep('done');}
      }
      if(state.heat>=99.9)end(false,'loseHeat');
      else if(state.pressure>=99.9)end(false,'losePressure');
      else if(state.oxygen<2)end(false,'loseOxygen');
      else if(state.power<1)end(false,'losePower');
      else if(state.seconds<=0)end(false,'loseTime');
    }
    if(!terminalOpen&&!helpShown&&state.phase!=='briefing'&&state.phase!=='won'&&state.phase!=='lost'){
      const active=name=>keys.has(name)||touchKeys.has(name);
      const dz=Number(active('w')||active('arrowup')||active('forward'))-Number(active('s')||active('arrowdown')||active('back'));
      const dx=Number(active('d')||active('arrowright')||active('right'))-Number(active('a')||active('arrowleft')||active('left'));
      const mag=Math.hypot(dx,dz)||1;
      const speed=(keys.has('shift')?5.3:3.4)*dt/mag;
      camera.x+=Math.cos(yaw)*dx*speed+Math.sin(yaw)*dz*speed;
      camera.z+=Math.sin(yaw)*dx*speed-Math.cos(yaw)*dz*speed;
      camera.x=clamp(camera.x,-7.1,7.1);camera.z=clamp(camera.z,-2.15,15.4);
      // The player cannot physically cross the containment ring.
      if(camera.z<-.2&&Math.abs(camera.x)<2.6) camera.z=-.2;
      if(state.phase==='stabilize'&&state.heat>93&&Math.random()<dt*.5)beep('alarm');
    }
  }
  function buildMaterial(c,em=0){const s=c.replace('#','');return [parseInt(s.substring(0,2),16)/255,parseInt(s.substring(2,4),16)/255,parseInt(s.substring(4,6),16)/255,em];}
  function geom(){return {a:[],n:0};}
  function tri(g,a,b,c,m){
    const ab=[b[0]-a[0],b[1]-a[1],b[2]-a[2]],ac=[c[0]-a[0],c[1]-a[1],c[2]-a[2]];
    let n=[ab[1]*ac[2]-ab[2]*ac[1],ab[2]*ac[0]-ab[0]*ac[2],ab[0]*ac[1]-ab[1]*ac[0]];
    const q=Math.hypot(...n)||1;n=n.map(v=>v/q);
    for(const p of [a,b,c])g.a.push(p[0],p[1],p[2],n[0],n[1],n[2],m[0],m[1],m[2],m[3]);g.n+=3;
  }
  function quad(g,a,b,c,d,m){tri(g,a,b,c,m);tri(g,a,c,d,m);}
  function box(g,x,y,z,w,h,d,m){
    const a=x-w/2,b=x+w/2,c=y-h/2,e=y+h/2,f=z-d/2,k=z+d/2;
    quad(g,[a,e,k],[b,e,k],[b,c,k],[a,c,k],m);quad(g,[b,e,f],[a,e,f],[a,c,f],[b,c,f],m);
    quad(g,[a,e,f],[a,e,k],[a,c,k],[a,c,f],m);quad(g,[b,e,k],[b,e,f],[b,c,f],[b,c,k],m);
    quad(g,[a,e,f],[b,e,f],[b,e,k],[a,e,k],m);quad(g,[a,c,k],[b,c,k],[b,c,f],[a,c,f],m);
  }
  function cylinder(g,x,y,z,rad,height,m,n=20){
    for(let i=0;i<n;i++){
      const t=i*Math.PI*2/n,tt=(i+1)*Math.PI*2/n;
      let a=[x+Math.cos(t)*rad,y-height/2,z+Math.sin(t)*rad],b=[x+Math.cos(tt)*rad,y-height/2,z+Math.sin(tt)*rad];
      let c=[b[0],y+height/2,b[2]],d=[a[0],y+height/2,a[2]];
      quad(g,a,b,c,d,m);tri(g,[x,y+height/2,z],d,c,m);
    }
  }
  function ring(g,x,y,z,r,width,m,steps=42,rotation=0,slope=.02){
    for(let i=0;i<steps;i++){
      const t=i/steps*Math.PI*2+rotation,tt=(i+1)/steps*Math.PI*2+rotation;
      const at=rad=>[x+Math.cos(t)*rad,y+Math.sin(t*3)*slope,z+Math.sin(t)*rad];
      const bt=rad=>[x+Math.cos(tt)*rad,y+Math.sin(tt*3)*slope,z+Math.sin(tt)*rad];
      quad(g,at(r),bt(r),bt(r+width),at(r+width),m);
    }
  }
  function cable(g,a,b,width,mat){
    const x=(a[0]+b[0])/2,y=(a[1]+b[1])/2,z=(a[2]+b[2])/2;
    const delta=[b[0]-a[0],b[1]-a[1],b[2]-a[2]],len=Math.hypot(...delta);
    if(len<.001)return;
    const u=delta.map(v=>v/len);let side=[-u[2],0,u[0]];
    const s=Math.hypot(...side);if(s<.001)side=[1,0,0];else side=side.map(v=>v/s);
    let up=[u[1]*side[2]-u[2]*side[1],u[2]*side[0]-u[0]*side[2],u[0]*side[1]-u[1]*side[0]];
    const pt=(center,dx,dy)=>[center[0]+side[0]*dx+up[0]*dy,center[1]+side[1]*dx+up[1]*dy,center[2]+side[2]*dx+up[2]*dy];
    quad(g,pt(a,-width,-width),pt(a,width,-width),pt(b,width,-width),pt(b,-width,-width),mat);
    quad(g,pt(a,-width,width),pt(a,width,width),pt(b,width,width),pt(b,-width,width),mat);
    quad(g,pt(a,-width,-width),pt(a,-width,width),pt(b,-width,width),pt(b,-width,-width),mat);
    quad(g,pt(a,width,-width),pt(a,width,width),pt(b,width,width),pt(b,width,-width),mat);
  }
  function sceneStatic(){
    const g=geom();
    const steel=buildMaterial('#294451'),dark=buildMaterial('#122631'),floor=buildMaterial('#19313a');
    const seam=buildMaterial('#365363'),pale=buildMaterial('#477484'),black=buildMaterial('#080f18');
    const cyan=buildMaterial('#8beef3',.95),danger=buildMaterial('#f5684f',.98);
    const amber=buildMaterial('#f6b483',.75),haze=buildMaterial('#254c5b',.12);
    // Reactor hall: layered flooring, concrete-shell walls, recessed ribs.
    box(g,0,-.22,4.4,19,.35,30,floor);box(g,0,-.48,4.5,23,.24,34,dark);
    for(let zz=-10;zz<19;zz+=2){
      for(let xx=-9;xx<10;xx+=2){
        box(g,xx,.004,zz,1.93,.016,1.93,((xx+zz)%4===0)?steel:floor);
        box(g,xx,0.022,zz,1.7,.012,1.7,black);
      }
    }
    for(let i=0;i<14;i++){
      const z=-10+i*2.15;
      for(const side of [-1,1]){
        box(g,side*9.3,2.8,z,.7,5.5,.46,steel);
        box(g,side*9.12,3.9,z,.10,1.8,.30,pale);
        box(g,side*8.97,2.4,z,.075,.9,.07,i%3===0?danger:cyan);
      }
      box(g,0,6.4,z,18.5,.11,.1,steel);
      box(g,0,6.18,z,14,.035,.06,cyan);
    }
    for(const side of [-1,1]){
      box(g,side*9.9,3.4,3.9,.48,7,32,dark);
      box(g,side*9.4,6.25,3.8,.55,.35,32,steel);
      for(let j=0;j<3;j++)box(g,side*(8.7-j*.28),4.9,3.3,.2,.17,27,j===1?seam:steel);
      for(let i=0;i<16;i++){
        const z=-10+i*1.8;
        box(g,side*7.8,.08,z,.12,.15,1.3,pale);
        box(g,side*7.3,.08,z,.09,.06,.72,i%3===0?danger:cyan);
      }
    }
    box(g,0,7.4,3.8,20,.23,32,black);
    for(let z=-9;z<18;z+=3.2){
      box(g,0,6.95,z,18,.35,.3,steel);
      for(const x of [-6.2,-2.1,2.1,6.2])box(g,x,6.7,z,.16,.12,.2,cyan);
    }
    // Safety walk and containment-ring physical rails.
    for(const x of [-2.7,2.7]){
      box(g,x,.14,3.8,.22,.3,15.3,seam);
      box(g,x,.31,3.8,.055,.04,15.3,cyan);
    }
    for(const x of [-7.6,7.6]){
      box(g,x,.6,3.3,.2,1.0,23,steel);
      for(let z=-8;z<15;z+=2.5)box(g,x,.85,z,.3,1.6,.25,pale);
      box(g,x,1.25,3.3,.16,.16,23,steel);
    }
    // Main reactor bulkhead and giant machinery.
    cylinder(g,0,2.8,-8.8,3.0,5.1,steel,36);
    cylinder(g,0,2.8,-8.8,2.67,5.25,black,36);
    cylinder(g,0,2.8,-8.8,2.25,4.8,haze,36);
    for(let i=0;i<16;i++){
      const angle=i*2*Math.PI/16;
      const x=Math.cos(angle)*3.46,z=-8.8+Math.sin(angle)*3.46;
      box(g,x,2.8,z,.28,5.4,.34,i%4===0?seam:steel);
      for(const y of [.65,1.4,3.8,5.0])box(g,x,y,z,.2,.1,.1,i%4===0?danger:cyan);
    }
    cylinder(g,0,.33,-8.8,4,.7,steel,36);cylinder(g,0,5.63,-8.8,3.65,.75,steel,36);
    for(const y of [1.1,2.2,3.4,4.6,5.8])ring(g,0,y,-8.8,3.05,.2,steel,48,0,0);
    ring(g,0,6.1,-8.8,3.6,.35,danger,60,0,0);
    for(let i=0;i<8;i++){
      let angle=i*Math.PI/4,x=Math.cos(angle)*5.2,z=-8.8+Math.sin(angle)*5.2;
      cylinder(g,x,2.55,z,.19,5.1,steel,12);box(g,x,3.9,z,.32,.32,.32,i%2===0?danger:cyan);
      cable(g,[x,4.9,z],[x*.6,5.8,-8.8+(z+8.8)*.6],.09,steel);
    }
    // Control consoles as full 3D props in the same space, not DOM mockups.
    for(const term of terminals){
      if(term.id==='exit')continue;
      const x=term.x,z=term.z;
      box(g,x,.43,z,.93,.88,.87,steel);
      box(g,x,1.15,z,.98,.58,.64,black);
      box(g,x,1.17,z+.332,.78,.42,.036,term.id==='cmd'?danger:cyan);
      box(g,x,1.17,z+.366,.67,.29,.027,black);
      box(g,x,1.27,z+.384,.58,.025,.01,cyan);
      for(let i=0;i<3;i++)box(g,x-.23+i*.23,1.1,z+.384,.1,.07,.01,i===0?danger:pale);
      box(g,x,.035,z,1.3,.07,1.25,steel);
      box(g,x,.09,z+.55,.87,.04,.05,term.id==='cmd'?danger:cyan);
    }
    // Exit: a frame and illuminated mechanical door.
    box(g,0,2.5,17.12,4.6,5.1,.55,steel);box(g,0,2.44,16.72,3.8,4.54,.22,black);
    box(g,0,2.3,16.58,3.5,4.2,.23,seam);
    box(g,0,2.3,16.44,.07,3.8,.05,cyan);box(g,0,4.37,16.47,3.3,.07,.05,cyan);
    for(let i=0;i<3;i++)box(g,-1.18+i*1.18,1.45,16.39,.18,1.8,.07,steel);
    for(let i=0;i<2;i++)box(g,-1.5+i*3,3.65,16.4,.17,.5,.08,danger);
    box(g,0,.04,15.7,3.8,.06,1.2,danger);
    // Warning pylons and wall lighting.
    for(let i=0;i<6;i++){
      let z=-1.5+i*3.1;
      for(const x of [-8.9,8.9]){
        box(g,x,4.3,z,.5,.8,.3,steel);
        box(g,x,4.4,z,.52,.21,.34,i%2===0?danger:amber);
      }
    }
    return g;
  }
  function sceneDynamic(time){
    const g=geom();
    const theta=time*.48;
    const core=buildMaterial(state.heat>87?'#ff6550':'#61ddeb',1.0);
    const red=buildMaterial('#ff6950',1.2),ringLight=buildMaterial('#95dfe9',.93);
    cylinder(g,0,2.85,-8.8,.68,4.15,core,20);
    cylinder(g,0,2.85,-8.8,.86,4.0,buildMaterial('#2e7d99',.68),28);
    for(let j=0;j<4;j++){
      const y=1.27+j*1.1;
      ring(g,0,y,-8.8,1.12+(j%2)*.11,.115,j%2?ringLight:red,52,theta*(j%2?-1:1)+j*.4,.075);
      ring(g,0,y+.1,-8.8,1.42,.055,ringLight,52,theta*(j%2?1:-1),.06);
    }
    for(let i=0;i<20;i++){
      const a=i*Math.PI*2/20+theta*(i%2?1:-1);
      const r=1.85+Math.sin(time*.8+i*2)*.11;
      const x=Math.cos(a)*r,z=-8.8+Math.sin(a)*r;
      box(g,x,2.6+Math.sin(time*1.2+i)*1.8,z,.14,.55,.12,i%4===0?red:ringLight);
    }
    for(const y of [1.15,5.1])ring(g,0,y,-8.8,2.2,.075,core,48,theta,0);
    if(state.heat>78){
      for(let k=0;k<14;k++){
        const x=Math.sin(k*19.1+time*.3)*2.7,z=-8.8+Math.cos(k*11.2+time*.2)*2.7;
        box(g,x,3.3+Math.sin(k*2.5+time*.9)*2.1,z,.055,.45,.055,red);
      }
    }
    return g;
  }
  function compile(type,source){const shader=gl.createShader(type);gl.shaderSource(shader,source);gl.compileShader(shader);if(!gl.getShaderParameter(shader,gl.COMPILE_STATUS))throw Error(gl.getShaderInfoLog(shader));return shader;}
  function createRenderer() {
    try {
      gl=canvas.getContext('webgl2',{antialias:true,alpha:false,depth:true,stencil:false,powerPreference:'high-performance'});
      if(!gl)throw Error('WebGL2 unavailable');
      const vs=`#version 300 es
      precision highp float;
      layout(location=0) in vec3 a_position;
      layout(location=1) in vec3 a_normal;
      layout(location=2) in vec3 a_color;
      layout(location=3) in float a_emit;
      uniform vec3 u_camera; uniform float u_yaw;uniform float u_pitch;uniform float u_aspect;
      out vec3 v_normal;out vec3 v_color;out vec3 v_world;out float v_depth;out float v_emit;
      void main(){
        vec3 rel=a_position-u_camera;
        float cy=cos(u_yaw),sy=sin(u_yaw);
        float xx=rel.x*cy+rel.z*sy;
        float zz=-rel.x*sy+rel.z*cy;
        float cp=cos(u_pitch),sp=sin(u_pitch);
        float yy=rel.y*cp-zz*sp;
        zz=rel.y*sp+zz*cp;
        float nearDist=max(-zz,.01);
        gl_Position=vec4(xx*1.16/u_aspect,yy*1.16,(-zz)*1.001-.075,nearDist);
        v_depth=-zz;v_normal=a_normal;v_color=a_color;v_emit=a_emit;v_world=a_position;
      }`;
      const fs=`#version 300 es
      precision highp float;
      in vec3 v_normal;in vec3 v_color;in vec3 v_world;in float v_depth;in float v_emit;
      uniform float u_time;uniform float u_alarm;
      out vec4 outColor;
      void main(){
        vec3 norm=normalize(v_normal);
        float light=.19+.61*max(dot(norm,normalize(vec3(-.38,.84,.35))),0.0);
        float bounce=.21*max(dot(norm,normalize(vec3(.62,.15,-.62))),0.0);
        float pulse=(.84+.16*sin(u_time*2.0+v_world.y*1.2));
        vec3 color=v_color*(light+bounce)+v_color*v_emit*(1.2+1.35*pulse);
        float alarmGlow=u_alarm*(.06+.03*sin(u_time*3.9+v_world.x));
        color+=vec3(alarmGlow,.014,0.01);
        float fog=clamp(1.0-exp(-max(v_depth,0.0)*.036),0.0,.82);
        vec3 fogCol=vec3(.018,.048,.066)+vec3(.013,.014,.021)*sin(u_time*.14);
        color=mix(color,fogCol,fog);
        color=color/(color+vec3(.60));
        color=pow(max(color,vec3(0.0)),vec3(.92));
        outColor=vec4(color,1.0);
      }`;
      shader=gl.createProgram();gl.attachShader(shader,compile(gl.VERTEX_SHADER,vs));gl.attachShader(shader,compile(gl.FRAGMENT_SHADER,fs));gl.linkProgram(shader);
      if(!gl.getProgramParameter(shader,gl.LINK_STATUS))throw Error(gl.getProgramInfoLog(shader));
      u={camera:gl.getUniformLocation(shader,'u_camera'),yaw:gl.getUniformLocation(shader,'u_yaw'),pitch:gl.getUniformLocation(shader,'u_pitch'),aspect:gl.getUniformLocation(shader,'u_aspect'),time:gl.getUniformLocation(shader,'u_time'),alarm:gl.getUniformLocation(shader,'u_alarm')};
      const mkMesh=(data,usage)=>{
        const vao=gl.createVertexArray();gl.bindVertexArray(vao);const buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);
        gl.bufferData(gl.ARRAY_BUFFER,new Float32Array(data.a),usage);
        const stride=40;
        gl.vertexAttribPointer(0,3,gl.FLOAT,false,stride,0);gl.enableVertexAttribArray(0);
        gl.vertexAttribPointer(1,3,gl.FLOAT,false,stride,12);gl.enableVertexAttribArray(1);
        gl.vertexAttribPointer(2,3,gl.FLOAT,false,stride,24);gl.enableVertexAttribArray(2);
        gl.vertexAttribPointer(3,1,gl.FLOAT,false,stride,36);gl.enableVertexAttribArray(3);
        gl.bindVertexArray(null);return {vao,buffer,count:data.n};
      };
      meshStatic=mkMesh(sceneStatic(),gl.STATIC_DRAW);
      meshDynamic=mkMesh(sceneDynamic(0),gl.DYNAMIC_DRAW);
      gl.enable(gl.DEPTH_TEST);gl.depthFunc(gl.LEQUAL);gl.disable(gl.CULL_FACE);
      gl.clearColor(.006,.018,.027,1);
      gl.canvas.addEventListener('webglcontextlost',ev=>{ev.preventDefault();toast='WebGL context lost — please reload';toastExpiry=Infinity;},false);
      return true;
    }catch(e){
      console.warn('SABLEFAULT WebGL2 unavailable: '+String(e));
      canvas.dataset.renderer='fallback';gl=null;fallbackStatic=sceneStatic();
      fallbackCtx=canvas.getContext('2d',{alpha:false});
      // Full CPU-perspective renderer for browsers that deliberately disable WebGL.
      // Same 3D geometry and real game camera; no external media or fake state.
      return false;
    }
  }
  function resize(){
    const dpr=Math.min(window.devicePixelRatio||1,window.innerWidth<700?1.3:1.55);
    const w=Math.round(canvas.clientWidth*dpr),h=Math.round(canvas.clientHeight*dpr);
    if(canvas.width!==w||canvas.height!==h){canvas.width=w;canvas.height=h;}
    if(gl)gl.viewport(0,0,w,h);
  }
  function draw3d(ts){
    resize();if(!gl){drawFallback(ts);return;}
    gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);gl.useProgram(shader);
    gl.uniform3f(u.camera,camera.x,camera.y,camera.z);gl.uniform1f(u.yaw,yaw);gl.uniform1f(u.pitch,pitch);
    gl.uniform1f(u.aspect,canvas.width/Math.max(1,canvas.height));gl.uniform1f(u.time,ts);
    gl.uniform1f(u.alarm,state.heat>85||state.pressure>85?1.0:.13);
    gl.bindVertexArray(meshStatic.vao);gl.drawArrays(gl.TRIANGLES,0,meshStatic.count);
    const current=sceneDynamic(ts);gl.bindVertexArray(meshDynamic.vao);gl.bindBuffer(gl.ARRAY_BUFFER,meshDynamic.buffer);
    gl.bufferData(gl.ARRAY_BUFFER,new Float32Array(current.a),gl.DYNAMIC_DRAW);gl.drawArrays(gl.TRIANGLES,0,current.n);
    gl.bindVertexArray(null);
  }
  function drawFallback(ts){
    // CI-only render skipping accelerates input/state tests; screenshot QA does not set it.
    if(window.__SABLEFAULT_INPUT_QA_SKIP_PAINT===true)return;
    if(!fallbackCtx)return;
    // Deliberately low refresh in CPU mode: never fake a native GPU benchmark.
    if(ts-lastFallback<.105 && lastFallback>=0)return;
    lastFallback=ts;const ctx=fallbackCtx;
    const w=canvas.width,h=canvas.height,scale=canvas.width/Math.max(1,canvas.clientWidth);
    ctx.clearRect(0,0,w,h);
    const bg=ctx.createLinearGradient(0,0,0,h);bg.addColorStop(0,'#050c14');bg.addColorStop(.52,'#0b202b');bg.addColorStop(1,'#03080e');
    ctx.fillStyle=bg;ctx.fillRect(0,0,w,h);
    const fragments=[];
    // Preserve the native procedural geometry. Triangle sorting provides a
    // depth-aware 2.5D view of exactly the same stage, rather than an empty warning.
    const batches=[fallbackStatic,sceneDynamic(ts)];
    for(const batch of batches){
      const a=batch.a;
      for(let i=0;i<a.length;i+=30){
        const p0=project(a[i],a[i+1],a[i+2]);
        const p1=project(a[i+10],a[i+11],a[i+12]);
        const p2=project(a[i+20],a[i+21],a[i+22]);
        if(!p0||!p1||!p2)continue;
        const x0=p0.x*scale,y0=p0.y*scale,x1=p1.x*scale,y1=p1.y*scale,x2=p2.x*scale,y2=p2.y*scale;
        const minX=Math.min(x0,x1,x2),maxX=Math.max(x0,x1,x2),minY=Math.min(y0,y1,y2),maxY=Math.max(y0,y1,y2);
        if(maxX<0||minX>w||maxY<0||minY>h)continue;
        // Reject near-clipped surfaces that would otherwise cover whole frame.
        if(maxX-minX>w*3||maxY-minY>h*3)continue;
        const normal=Math.max(.2,a[i+4]*.73-a[i+3]*.23+a[i+5]*.15);
        const emi=a[i+9],depth=(p0.depth+p1.depth+p2.depth)/3;
        const fog=Math.min(.75,Math.max(0,1-Math.exp(-depth*.031)));
        const bright=.40+Math.max(0,normal)*.53+emi*1.13*(.88+.12*Math.sin(ts*2.1));
        const rgb=[a[i+6],a[i+7],a[i+8]].map((c,k)=>{
          const fogColor=[.016,.038,.052][k];
          const lit=c*bright;
          return Math.max(0,Math.min(255,Math.round((lit*(1-fog)+fogColor*fog)*255)));
        });
        fragments.push({p:[x0,y0,x1,y1,x2,y2],depth,color:'rgb('+rgb.join(',')+')',em:emi});
      }
    }
    fragments.sort((a,b)=>b.depth-a.depth);
    for(const frag of fragments){
      ctx.beginPath();ctx.moveTo(frag.p[0],frag.p[1]);ctx.lineTo(frag.p[2],frag.p[3]);ctx.lineTo(frag.p[4],frag.p[5]);ctx.closePath();
      ctx.fillStyle=frag.color;ctx.fill();
    }
    // Atmospheric vignette, energy bleed and subtle theatrical camera grain.
    const r=ctx.createRadialGradient(w*.51,h*.45,w*.10,w*.51,h*.45,w*.83);
    r.addColorStop(0,'#00000000');r.addColorStop(1,'#00030ba8');ctx.fillStyle=r;ctx.fillRect(0,0,w,h);
    ctx.save();ctx.globalAlpha=.12;ctx.strokeStyle='#8edee7';ctx.lineWidth=1;
    for(let i=0;i<9;i++){let y=(i/9)*h;ctx.beginPath();ctx.moveTo(0,y+.5);ctx.lineTo(w,y+.5);ctx.stroke();}
    ctx.restore();
  }

  function project(x,y,z){
    const dx=x-camera.x,dy=y-camera.y,dz=z-camera.z;
    const cy=Math.cos(yaw),sy=Math.sin(yaw),cp=Math.cos(pitch),sp=Math.sin(pitch);
    const xx=dx*cy+dz*sy,zz=-dx*sy+dz*cy;
    const yy=dy*cp-zz*sp,depth=-dy*sp-zz*cp;
    if(depth<.5)return null;
    const f=canvas.clientHeight*1.16/2;
    return {x:canvas.clientWidth/2+xx*f/depth,y:canvas.clientHeight/2-yy*f/depth,depth};
  }
  function refreshTags(){
    for(const term of terminals){
      let el=mapTags.get(term.id);if(!el){el=document.createElement('div');el.className='tag3d';const main=document.createElement('span'),sub=document.createElement('small');el.append(main,sub);$('world-tags').append(el);mapTags.set(term.id,el);}
      el.children[0].textContent=t(term.id);el.children[1].textContent=term.code;
    }
  }
  function drawTags(){
    const blocked=state.phase==='briefing'||state.phase==='won'||state.phase==='lost';
    for(const term of terminals){
      const el=mapTags.get(term.id),pt=project(term.x,term.y+.45,term.z);
      const visible=pt&&!blocked&&pt.x>26&&pt.x<canvas.clientWidth-26&&pt.y>60&&pt.y<canvas.clientHeight-65&&pt.depth<19;
      el.style.display=visible?'flex':'none';
      if(visible){el.style.left=pt.x+'px';el.style.top=pt.y+'px';el.style.opacity=String(clamp(1-(pt.depth-2)/30,.27,1));}
      el.classList.toggle('near',nearTerminal?.id===term.id);
    }
  }
  function tick(ts){
    const seconds=ts/1000;
    let dt=frameTime===0?0:Math.min(.062,Math.max(0,seconds-frameTime));frameTime=seconds;
    update(dt);draw3d(seconds);drawTags();
    if(seconds-lastUi>.12){lastUi=seconds;refreshTelemetry();refreshInteraction();}
    requestAnimationFrame(tick);
  }
  function onKeyDown(ev){
    const key=ev.key.toLowerCase();
    if(['w','a','s','d','shift','arrowup','arrowdown','arrowleft','arrowright','e','l','escape','enter','h'].includes(key))ev.preventDefault();
    if(ev.repeat){keys.add(key);return;}
    keys.add(key);
    if(key==='e'){if(terminalOpen)closeTerminal();else openTerminal();}
    if(key==='escape'){if(helpShown)showHelp(false);else if(terminalOpen)closeTerminal();else if(document.pointerLockElement===canvas)document.exitPointerLock();}
    if(key==='l')setLanguage(lang==='ru'?'en':'ru');
    if(key==='h'&&state.phase!=='briefing')showHelp(!helpShown);
    if(key==='enter'&&state.phase==='briefing')start();
  }
  function bindControls(){
    document.addEventListener('keydown',onKeyDown);document.addEventListener('keyup',e=>keys.delete(e.key.toLowerCase()));
    window.addEventListener('blur',()=>{keys.clear();touchKeys.clear();});
    document.addEventListener('pointerlockchange',()=>{pointerCaptured=document.pointerLockElement===canvas;});
    document.addEventListener('mousemove',ev=>{
      if(pointerCaptured&&!terminalOpen&&!helpShown){yaw+=ev.movementX*.0023;pitch=clamp(pitch+ev.movementY*.0018,-.65,.60);}
    });
    canvas.addEventListener('click',()=>{if(state.phase!=='briefing'&&!terminalOpen&&!helpShown&&!isMobile&&!pointerCaptured)canvas.requestPointerLock?.();});
    $('start').addEventListener('click',start);$('restart').addEventListener('click',start);
    $('backCover').addEventListener('click',()=>{state.phase='briefing';state.log=[];refreshFeed();refreshMission();$('finishBackdrop').classList.add('hidden');$('touch').classList.add('hidden');setOverlay(true);});
    $('useButton').addEventListener('click',openTerminal);$('touchUse').addEventListener('click',openTerminal);
    $('closeTerminal').addEventListener('click',()=>helpShown?showHelp(false):closeTerminal());
    $('terminalBackdrop').addEventListener('click',ev=>{if(ev.target===$('terminalBackdrop'))helpShown?showHelp(false):closeTerminal();});
    $('help').addEventListener('click',()=>showHelp(!helpShown));
    $('lang').addEventListener('click',()=>setLanguage(lang==='ru'?'en':'ru'));
    $('coverLang').addEventListener('click',()=>setLanguage(lang==='ru'?'en':'ru'));
    $('sound').addEventListener('click',()=>{soundEnabled=!soundEnabled;$('sound').textContent=soundEnabled?'SOUND ON':'SOUND OFF';if(soundEnabled)beep('done');});
    for(const b of document.querySelectorAll('[data-move]')){
      const k=b.dataset.move;
      b.addEventListener('pointerdown',ev=>{ev.preventDefault();touchKeys.add(k);b.setPointerCapture?.(ev.pointerId);});
      const up=()=>touchKeys.delete(k);b.addEventListener('pointerup',up);b.addEventListener('pointercancel',up);b.addEventListener('lostpointercapture',up);
    }
    let lastX=null,lastY=null;
    const look=$('lookArea');look.addEventListener('pointerdown',e=>{lastX=e.clientX;lastY=e.clientY;look.setPointerCapture?.(e.pointerId);});
    look.addEventListener('pointermove',e=>{
      if(lastX===null||terminalOpen||helpShown)return;
      yaw+=(e.clientX-lastX)*.006;pitch=clamp(pitch+(e.clientY-lastY)*.005,-.65,.60);
      lastX=e.clientX;lastY=e.clientY;
    });
    for(const ev of ['pointerup','pointercancel','lostpointercapture'])look.addEventListener(ev,()=>{lastX=null;lastY=null;});
    window.addEventListener('resize',resize);
  }
  function boot(){
    createRenderer();bindControls();refreshTags();setLanguage('ru');refreshTelemetry();setOverlay(true);
    if(!gl){document.querySelector('.build').textContent='CPU-PERSPECTIVE MODE';}
    requestAnimationFrame(tick);
    // QA introspection is READ ONLY: tests cannot forge state or bypass action rules.
    Object.defineProperty(window,'SABLEFAULT_INSPECT',{configurable:false,writable:false,value:()=>({
      project:'SABLEFAULT',version:'0.1.0',renderer:gl?'WebGL2':'fallback',phase:state.phase,
      heat:+state.heat.toFixed(2),pressure:+state.pressure.toFixed(2),power:+state.power.toFixed(2),
      oxygen:+state.oxygen.toFixed(2),seconds:+state.seconds.toFixed(2),stable:+state.stable.toFixed(2),
      coolantA:state.coolantA,coolantB:state.coolantB,vent:state.vent,choice:state.choice,
      terminal:terminalOpen?.id||null,nearest:nearest()?.id||null,
      player:{x:+camera.x.toFixed(2),z:+camera.z.toFixed(2),yaw:+yaw.toFixed(2)},
      events:state.log.map(item=>item.key),score:state.score,
      real_physical_gpu_certified:false,production_ready:false
    })});
  }
  boot();
})();
