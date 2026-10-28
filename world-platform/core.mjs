// W76 LAST FRONTIER WORLD / deterministic, dependency-free pure product model.
// No artificial live game state, fake player counts or unconsented analytics.
export const SOURCE_SHA="73ef81b54cb42831cafd9ac8fa69c5807cd8dc8d";
export const CI_RUN="https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40650956529";
export const MAX_EVENTS=160;
export const STORAGE_KEY="lf-world-player-lab-v1";

export const WORDS={
  ru:{
    skip:"Перейти к содержимому",navigation:"НАВИГАЦИЯ",navCommand:"Командный центр",
    navMissions:"Протокол миссии",navLab:"Лаборатория игроков",navSystem:"Система и файлы",
    localPrivacy:"ПРИВАТНО ПО УМОЛЧАНИЮ",offlineDetails:"Без аккаунтов и аналитических серверов",
    verifying:"Проверка сборки",verified:"МАНИФЕСТ ЗАГРУЖЕН",bytesVerified:"ФАЙЛЫ SHA-256 ПРОВЕРЕНЫ",unverified:"МАНИФЕСТ НЕДОСТУПЕН",
    eyebrow:"СЕКТОР А7 · ОПЕРАЦИОННАЯ СТАНЦИЯ",
    heroTitle:"ЗА ПОСЛЕДНИМ<br><em>РУБЕЖОМ.</em>",
    heroDescription:"Здесь начинается настоящее прохождение. Вы управляете реактором, перемещаетесь по объекту и принимаете решения, которые изменяют исход миссии.",
    verifiedSoftware:"ПРОВЕРЕНО ПРОГРАММНО",notRetail:"Не является коммерческим релизом",
    liveModule:"01 / LIVE SIMULATION",playTitle:"Реактор А7 <span>· Реальная игровая сцена</span>",
    gameIdle:"НЕ ЗАПУЩЕНО",gameBoot:"ЗАГРУЗКА",gameReady:"ИГРА АКТИВНА",gameFail:"ОШИБКА ЗАПУСКА",
    posterDesc:"Не видео. Не макет. Игровой движок запускается прямо здесь.",
    launch:"ЗАПУСТИТЬ ИГРУ",focus:"Фокус в игре",fullscreen:"На весь экран",
    booting:"ЗАГРУЗКА НАСТОЯЩЕГО ИГРОВОГО ДВИЖКА",loadingFiles:"Проверяем игровые ресурсы...",
    controlsMove:"ПЕРЕДВИЖЕНИЕ",controlsUse:"МЕХАНИЗМ",controlsSave:"СОХРАНИТЬ",
    metricHeat:"ТЕМПЕРАТУРА",metricIntegrity:"ЦЕЛОСТНОСТЬ",metricCycle:"ЦИКЛ РЕАКТОРА",
    metricFrame:"P95 / КАДР",engineSource:"Из движка, без имитации",
    frameDisclaimer:"Программный замер, не GPU-тест",
    disclaimer:"Экспериментальная локальная игра. Реальных промышленных систем здесь нет. Проверенная программа ≠ проверенный коммерческий AAA-релиз.",
    missionPrelude:"ПЯТЬ ФИЗИЧЕСКИХ ЦЕЛЕЙ",missionTitle:"ОТ РЕАКТОРА<br><em>К РЕШЕНИЮ.</em>",
    missionDesc:"Статусы обновляются только по фактическим событиям внутри Godot. Пока игра не запущена, выполнение не предполагается.",
    missionFact:"В движке действительно существуют",
    missionFactDesc:"Шесть игровых циклов, три физических механизма и двенадцать решений. Для завершения необходимо решить задачи, а не нажать кнопку на этом сайте.",
    goPlay:"ПЕРЕЙТИ К ИГРЕ",missionAwaiting:"НЕ НАЧАТО",missionActive:"В ПРОЦЕССЕ",missionDone:"ВЫПОЛНЕНО",missionLater:"ОЖИДАНИЕ",
    labPrelude:"РЕАЛЬНЫЕ ПРОХОЖДЕНИЯ. НИКАКИХ ВЫДУМАННЫХ ДАННЫХ.",
    labTitle:"КАЖДОЕ РЕШЕНИЕ<br><em>ИМЕЕТ ВЕС.</em>",
    labDesc:"Запишите настоящую игровую сессию на своём устройстве. Данные остаются здесь, пока вы сами не экспортируете отчёт. Это не независимое исследование с 12 участниками.",
    sessionTitle:"Локальная сессия",sessionIdle:"Сессия не запущена",
    sessionRunning:"Идёт запись времени и реальных событий игры",
    sessionFinished:"Сессия завершена · можно экспортировать результат",
    consent:"Я согласен записать игровые действия и длительность локально на этом устройстве. Личные данные не требуются.",
    sessionStart:"НАЧАТЬ ЗАМЕР",sessionStop:"ЗАВЕРШИТЬ",sessionFacts:"ФАКТИЧЕСКИЕ СОБЫТИЯ",
    feedbackTitle:"Что мешало играть?",confusionLabel:"Количество моментов затруднения",
    feedbackLabel:"Необязательная заметка (до 500 символов)",feedbackPlaceholder:"Какая механика оказалась непонятной?",
    exportReport:"ЭКСПОРТИРОВАТЬ РЕАЛЬНЫЙ ОТЧЁТ JSON",
    labWarning:"Самостоятельная сессия не считается независимым тестированием. Результат автоматически не отправляется разработчикам.",
    labGateTitle:"Коммерческий релиз остаётся закрытым",
    labGateDesc:"Нужны 12 независимых игроков, физические тесты PC/Android/iOS, проверка прав на материалы, оригинальный арт и явное решение владельца. Эта панель не утверждает выполнение этих условий.",
    systemPrelude:"ПРОЗРАЧНАЯ ПРОВЕРКА СБОРКИ",systemTitle:"ДОВЕРИЕ<br><em>НА УРОВНЕ БАЙТА.</em>",
    systemDesc:"Платформа запускает оригинальный Godot WebAssembly. При желании можно проверить SHA-256 каждого файла и сохранить ресурсы для автономного использования.",
    notChecked:"Не проверено",verifiedFile:"SHA-256 совпадает",badFile:"ПРОВЕРКА НЕ ПРОШЛА",
    externalNone:"Нет обязательного облачного аккаунта",
    verifyFiles:"ПРОВЕРИТЬ SHA-256 ФАЙЛОВ",makeOffline:"СОХРАНИТЬ ИГРУ ДЛЯ ОФЛАЙН",
    waitingManifest:"Ожидание манифеста сборки...",manifestLoaded:"Список игровых файлов получен. Проверка SHA-256 запускается по запросу.",
    verifyingFile:"Проверка файла",verifiedAll:"Все игровые файлы прошли SHA-256.",
    offlinePreparing:"Сохранение игровых файлов на этом устройстве...",
    offlineReady:"Игра сохранена локально для офлайн-режима на этом устройстве.",
    offlineUnavailable:"Офлайн-кэш недоступен в этом браузере.",
    error:"Ошибка",
    platformBoundaries:"Границы платформы",
    platformBoundariesText:"В этом выпуске нет глобальных аккаунтов, облачных сохранений, мультиплеера или монетизации. Прогресс остаётся в сохранении Godot на текущем устройстве; исследовательские записи находятся только в браузере.",
    footerNote:"НЕЗАВИСИМЫЙ ИГРОВОЙ ПРОТОТИП · НЕ ДЛЯ ПРОДАЖИ",
    sessionNeedGame:"Сначала запустите реальную игру и подтвердите согласие.",
    sessionNeedConsent:"Нужно согласие на локальную запись событий.",
    sessionExported:"Отчёт создан на вашем устройстве. Автоматической отправки нет.",
    noGame:"Игра ещё не готова. Проверьте локальный сервер.",
    storageNote:"Наблюдения хранятся только локально. Это не независимая аттестация.",
    launchError:"Не удалось получить состояние движка. Проверьте встроенный запуск."
  },
  en:{
    skip:"Skip to content",navigation:"NAVIGATION",navCommand:"Command center",
    navMissions:"Mission protocol",navLab:"Player research lab",navSystem:"System & files",
    localPrivacy:"PRIVATE BY DEFAULT",offlineDetails:"No accounts or analytics servers",
    verifying:"Verifying build",verified:"SOURCE MANIFEST LOADED",bytesVerified:"GAME BYTES VERIFIED",unverified:"MANIFEST UNAVAILABLE",
    eyebrow:"SECTOR A7 · FIELD OPERATIONS STATION",
    heroTitle:"BEYOND THE<br><em>LAST FRONTIER.</em>",
    heroDescription:"The mission begins in a real game. Stabilize the reactor, walk the facility and make decisions that genuinely affect the outcome.",
    verifiedSoftware:"SOFTWARE VERIFIED",notRetail:"Not a commercial game release",
    liveModule:"01 / LIVE SIMULATION",playTitle:"Reactor A7 <span>· Actual playable game scene</span>",
    gameIdle:"NOT STARTED",gameBoot:"BOOTING ENGINE",gameReady:"GAME IS LIVE",gameFail:"BOOT FAILED",
    posterDesc:"Not a video. Not a mockup. The genuine Godot engine starts right here.",
    launch:"LAUNCH GAME",focus:"Focus game",fullscreen:"Fullscreen",
    booting:"STARTING THE ACTUAL GAME ENGINE",loadingFiles:"Loading verified game assets...",
    controlsMove:"MOVEMENT",controlsUse:"MACHINE",controlsSave:"SAVE",
    metricHeat:"HEAT",metricIntegrity:"INTEGRITY",metricCycle:"REACTOR CYCLE",
    metricFrame:"FRAME / P95",engineSource:"Read from the real engine",
    frameDisclaimer:"Software timing, not a GPU benchmark",
    disclaimer:"Experimental, offline game. No real industrial machinery is connected. Software acceptance is not certification for a commercial AAA launch.",
    missionPrelude:"FIVE PHYSICAL OBJECTIVES",missionTitle:"FROM THE REACTOR<br><em>TO THE ANSWER.</em>",
    missionDesc:"Milestones update from actual in-game Godot events only. Nothing is marked complete before gameplay.",
    missionFact:"Already implemented in the actual engine",
    missionFactDesc:"Six reactor cycles, three physical machine puzzles and twelve original decisions. Progress cannot be forged by clicking on this website.",
    goPlay:"OPEN LIVE GAME",missionAwaiting:"NOT STARTED",missionActive:"IN PROGRESS",missionDone:"COMPLETE",missionLater:"PENDING",
    labPrelude:"REAL PLAYTHROUGHS. NO FABRICATED HUMAN DATA.",
    labTitle:"EVERY CHOICE<br><em>HAS WEIGHT.</em>",
    labDesc:"Capture your real, local play session. All data stays on this device until you export it yourself. This does not count as an independent 12-person study.",
    sessionTitle:"Local play session",sessionIdle:"No session started",
    sessionRunning:"Recording elapsed time and real engine events",
    sessionFinished:"Session ended · report is ready for export",
    consent:"I consent to saving gameplay events and elapsed duration on this device. No personal details are required.",
    sessionStart:"START OBSERVATION",sessionStop:"END SESSION",sessionFacts:"ACTUAL ENGINE EVENTS",
    feedbackTitle:"What felt difficult?",confusionLabel:"Number of confusing moments",
    feedbackLabel:"Optional note (max 500 characters)",feedbackPlaceholder:"Which mechanic was unclear?",
    exportReport:"EXPORT REAL JSON OBSERVATION",
    labWarning:"Self-reported sessions are not independently verified playtests. No data is sent automatically.",
    labGateTitle:"Commercial release remains blocked",
    labGateDesc:"Twelve independent players, physical Win/Android/iOS tests, original art and licensing, cleared name and explicit owner signoff are still needed. This page never invents those results.",
    systemPrelude:"TRANSPARENT SOURCE VERIFICATION",systemTitle:"TRUST<br><em>DOWN TO THE BYTE.</em>",
    systemDesc:"Runs the actual Godot WebAssembly export. Verify every game file against SHA-256, then optionally cache resources for offline play.",
    notChecked:"Not verified",verifiedFile:"SHA-256 matches",badFile:"VERIFICATION FAILED",
    externalNone:"No mandatory cloud account",
    verifyFiles:"VERIFY GAME FILES / SHA-256",makeOffline:"PREPARE OFFLINE PLAY",
    waitingManifest:"Waiting for build manifest...",manifestLoaded:"Authentic game manifest loaded. Verify individual bytes when ready.",
    verifyingFile:"Verifying file",verifiedAll:"All original game files match SHA-256.",
    offlinePreparing:"Caching the real game on this device...",
    offlineReady:"Original game is available offline on this device.",
    offlineUnavailable:"Offline game caching is not available in this browser.",
    error:"Error",
    platformBoundaries:"Platform scope",
    platformBoundariesText:"This release has no global accounts, cloud sync, multiplayer or payment system. Game progress is local Godot storage; playtest notes never leave this browser unless exported.",
    footerNote:"INDEPENDENT GAME PROTOTYPE · NOT FOR SALE",
    sessionNeedGame:"Start the real game and explicitly consent before recording.",
    sessionNeedConsent:"Local observation requires explicit consent.",
    sessionExported:"Report saved on this device; nothing was transmitted.",
    noGame:"Game is not ready. Check the local web server.",
    storageNote:"Observation stays on this device; this is not independent attestation.",
    launchError:"Unable to read the live game. Check the game export and local server."
  }
};

export const MISSIONS={
  ru:[
    ["Доступ к термоконтролю","Найти реактор, настроить физический клапан и осмотреть пульт."],
    ["Две критические операции","Выполнить реальные решения PUMP, VENT, SEAL, SCAN или POWER."],
    ["Маршрутизация питания","Пройти по объекту к релейному залу и выстроить электрическую цепь."],
    ["Последний инцидент","Пройти оригинальную цепочку из шести циклов и двенадцати решений."],
    ["Синхронизация контура","Вернуться к реактору и активировать три контакта в правильном порядке."]
  ],
  en:[
    ["Thermal control access","Approach the reactor, align the physical valve and inspect the console."],
    ["Two critical operations","Make real PUMP, VENT, SEAL, SCAN or POWER decisions."],
    ["Power routing","Walk to the relay hall and correctly route the electricity."],
    ["Final incident","Finish the original six-cycle game with twelve accepted choices."],
    ["Containment synchronization","Return to the reactor and activate the three contacts in the real order."]
  ]
};

export function t(locale,key){return WORDS[locale]?.[key]||WORDS.ru[key]||key;}
export function translate(locale, key){return t(locale,key);}
export function formatClock(ms){
  if(!Number.isFinite(ms)||ms<0)return "00:00";
  const total=Math.floor(ms/1000);
  const m=Math.floor(total/60),s=total%60;
  return String(m).padStart(2,"0")+":"+String(s).padStart(2,"0");
}
export function isDigest(value){return typeof value==="string"&&/^[a-f0-9]{64}$/.test(value);}
export function validateManifest(value){
  if(!value||typeof value!=="object"||value.schema!=="LAST_FRONTIER_WORLD_PLATFORM_V1")return false;
  if(value.sourceSha!==SOURCE_SHA||value.releaseStatus!=="PRODUCTION_HOLD")return false;
  if(value.softwareCiUrl!==CI_RUN||value.gameEngine!=="Godot 4.4.1")return false;
  if(!Array.isArray(value.gameFiles)||value.gameFiles.length<8||value.gameFiles.length>24)return false;
  let hasWasm=false,hasPck=false,total=0;const seen=new Set();
  for(const file of value.gameFiles){
    if(!file||typeof file.path!=="string"||!/^game\/index\.[a-zA-Z0-9.-]+$/.test(file.path))return false;
    if(!Number.isInteger(file.bytes)||file.bytes<=0||file.bytes>95_000_000||!isDigest(file.sha256))return false;
    if(seen.has(file.path))return false;
    seen.add(file.path);total+=file.bytes;
    if(file.path==="game/index.wasm")hasWasm=true;
    if(file.path==="game/index.pck")hasPck=true;
  }
  return hasWasm&&hasPck&&total<130_000_000;
}
export function validGameState(state){
  return Boolean(state&&typeof state==="object"&&state.real_native_3d===true&&
    state.w73_real_native_world_raycast===true&&
    typeof state.status==="string"&&
    typeof state.metrics==="object"&&state.metrics!==null&&
    Number.isFinite(Number(state.metrics.heat))&&
    Number.isFinite(Number(state.metrics.integrity)));
}
export function readGameState(iframe){
  try{
    const doc=iframe.contentDocument;
    const node=doc?.getElementById("a7-cascade-native-state");
    if(!node)return null;
    const raw=node.getAttribute("data-state");
    if(!raw||raw.length>48_000)return null;
    const parsed=JSON.parse(raw);
    return validGameState(parsed)?parsed:null;
  }catch{return null;}
}
function finiteClamp(v,min,max){
  const n=Number(v);return Number.isFinite(n)?Math.min(max,Math.max(min,n)):0;
}
export function metricsFrom(state){
  if(!validGameState(state))return null;
  const heat=finiteClamp(state.metrics.heat,0,100);
  const integrity=finiteClamp(state.metrics.integrity,0,100);
  const shift=finiteClamp(state.shift,0,6);
  const p95=finiteClamp(state.w74_real_frame_time_p95_ms,0,500);
  return {heat,integrity,cycle:Math.min(6,shift+1),phase:Number(state.w71_mission_phase)||0,p95,
    filledCycle:shift/6*100,heatPct:heat,integrityPct:integrity,framePct:Math.min(100,p95/50*100)};
}
export function missionState(state,locale){
  const rows=MISSIONS[locale]||MISSIONS.ru;
  if(!validGameState(state)||!state.w71_mission_active){
    return rows.map(([name,description],i)=>({index:i,name,description,status:"awaiting"}));
  }
  const phase=finiteClamp(state.w71_mission_phase,0,6);
  const trulyDone=state.w71_mission_complete===true&&state.status==="won";
  // Malformed or failed final states must NEVER mark the full campaign
  // complete. The fifth phase stays active until the *actual* game wins.
  const displayPhase=trulyDone?5:Math.min(4,phase);
  return rows.map(([name,description],i)=>({index:i,name,description,
    status:trulyDone||i<displayPhase?"done":i===displayPhase?"active":"later"}));
}
export function captureEngineEvent(state,elapsedMs){
  if(!validGameState(state))return null;
  return {
    t_ms:Math.max(0,Math.floor(Number(elapsedMs)||0)),
    shift:finiteClamp(state.shift,0,6),
    history_count:finiteClamp(state.history_count,0,12),
    mission_phase:finiteClamp(state.w71_mission_phase,-1,6),
    last_event:String(state.last_event||"").slice(0,90),
    valve_index:finiteClamp(state.w72_valve_index,0,20),
    relay_mask:finiteClamp(state.w72_relay_mask,0,7),
    sync_step:finiteClamp(state.w72_sync_step,0,3),
    raycast_uses:finiteClamp(state.w73_real_raycast_uses,0,160),
    engine_status:String(state.status).slice(0,30)
  };
}
export function appendObservedEvent(events,state,elapsedMs){
  const next=captureEngineEvent(state,elapsedMs);
  if(!next||events.length>=MAX_EVENTS)return events;
  const last=events[events.length-1];
  if(last&&Object.keys(next).every(k=>k==="t_ms"||next[k]===last[k]))return events;
  return events.concat([next]);
}
export function completedFromEngine(state){
  return validGameState(state)&&state.status==="won"&&state.w71_mission_complete===true;
}
export function createPrivateSession({id,sourceSha,startIso,endIso,elapsedMs,events,lastState,confusion,note}){
  if(sourceSha!==SOURCE_SHA)throw new Error("Original source does not match verified game");
  if(!Array.isArray(events)||events.length>MAX_EVENTS)throw new Error("Event count exceeded");
  return {
    schema:"LAST_FRONTIER_WORLD_SELF_OBSERVED_SESSION_V1",
    source_sha:SOURCE_SHA,
    session_code:String(id).slice(0,80),
    started_at:String(startIso),
    ended_at:String(endIso),
    observed_elapsed_seconds:Math.max(0,Math.floor(Number(elapsedMs)/1000)),
    completed_in_actual_engine:completedFromEngine(lastState),
    engine_observation_available:validGameState(lastState),
    confusion_events:Math.max(0,Math.min(10,Math.floor(Number(confusion)||0))),
    player_note:String(note||"").slice(0,500),
    event_count:events.length,
    real_engine_event_journal:events.map(x=>({...x})),
    was_recorded_locally_with_explicit_consent:true,
    observed_by_independent_human:false,
    claimed_as_part_of_independent_12_player_study:false,
    verified_real_device_benchmark:false,
    commercial_release_approved:false,
    synthetic_fixture:false,
    no_automatic_network_transmission:true
  };
}
