/* IRON PULSE WORLD / V9 — UI logic only.
   No analytics, external calls, profile scraping or invented game results.
   All mission buttons launch the actual same-origin Godot WebGL build. */
(() => {
  "use strict";
  const missions = ["blackout", "thermal", "breach"];
  const languages = ["ru", "en"];
  const dictionary = {
    ru: {
      skip: "К содержанию",
      navMissions:"Миссии",navWorld:"Мир игры",navControls:"Управление",navPlay:"Играть",
      eyebrow:"A7 / ОРИГИНАЛЬНАЯ ИНТЕРАКТИВНАЯ ИГРА",
      heroLead:"РЕАКТОР УМИРАЕТ.\nРЕШЕНИЕ — ЗА ТОБОЙ.",
      heroSummary:"Три аварии. Два контура питания. Один экипаж. Зайди внутрь разрушающегося комплекса, решай настоящие инженерные головоломки и выбирай, кого спасать.",
      heroPlay:"НАЧАТЬ ОПЕРАЦИЮ",fullCampaign:"СЮЖЕТНАЯ КАМПАНИЯ",exploreMissions:"ИЗУЧИТЬ МИССИИ",
      preview:"ПРЕДВАРИТЕЛЬНАЯ ИГРОВАЯ ВЕРСИЯ · НЕ ФИНАЛЬНЫЙ РЕЛИЗ",
      metricMissions:"РЕАЛЬНЫЕ МИССИИ",metricChoices:"СТАНЦИИ СПАСЕНИЯ",
      metricLang:"ДВА ЯЗЫКА",metricReal:"РЕАЛЬНЫЙ GODOT WEBGL",
      missionOverline:"001 / КАМПАНИЯ",missionHeading:"ТРИ ОПЕРАЦИИ.\nОДНА КАТАСТРОФА.",
      missionIntro:"Не рекламные мини-игры. Три сценария в одной настоящей 3D-системе, с различными угрозами и последствиями решений.",
      gridSmall:"ОТКЛЮЧЕНИЕ ПИТАНИЯ",heatSmall:"ТЕПЛОВАЯ КАТАСТРОФА",airSmall:"РАЗГЕРМЕТИЗАЦИЯ",
      allPlayable:"Все три операции доступны в игре. Прогресс сохраняется на вашем устройстве.",
      activeMission:"ВЫБРАННАЯ ОПЕРАЦИЯ",enterMission:"ВОЙТИ В МИССИЮ",
      worldOverline:"002 / МИР ИГРЫ",worldHeading:"ВНУТРИ\nРЕАКТОРА A7.",
      worldIntro:"Физическое игровое пространство, а не декорация в браузере. Интерактивные терминалы, меняющееся освещение, аварийные эффекты и настоящая логика ресурсов.",
      proofLabel:"КАДР ИЗ НАСТОЯЩЕЙ ИГРЫ",
      proofCaption:"Скриншот создаётся автоматически из точного исходного коммита во время CI. Это настоящий игровой кадр — без AI-генерации и ретуши.",
      feat1Title:"Настоящая система",feat1Body:"Два контура питания, температура, кислород, состояние экипажа и накопитель двери связаны одной моделью.",
      feat2Title:"Последствия решений",feat2Body:"Три станции спасения, но выбрать можно только две. Каждое решение меняет доступные ресурсы.",
      feat3Title:"История экипажа",feat3Body:"Радиопереговоры Мары, выбор между людьми и реактором, разные результаты прохождения.",
      controlsOverline:"003 / РУКОВОДСТВО",controlsHeading:"ВХОД В СИСТЕМУ.",
      controlsIntro:"Короткие команды, понятный маршрут и настраиваемая графика. Можно играть на ПК; мобильное управление также предусмотрено.",
      pcTitle:"ПК / КЛАВИАТУРА",accessTitle:"ДОСТУПНОСТЬ",
      move:"Движение",look:"Осмотр",use:"Действие / срочно",camera:"Камера / радиоархив",
      language:"Язык интерфейса",graphics:"HERO / ECO графика",
      reduceMotion:"Уменьшение движения",mute:"Звук вкл./выкл.",forecastGuide:"Прогноз распределения энергии / 30 с",operatorHelpGuide:"Контекстная помощь в действующей миссии",navGuide:"Навигация к настоящему терминалу",onboardingTitle:"НЕ ПОНЯЛ ЗАДАЧУ? ВКЛЮЧИ ПОДСКАЗКУ.",onboardingBody:"F1 открывает три уровня помощи по настоящей текущей задаче: сканирование, ремонт, питание, допуск или эвакуация. На телефоне — кнопки GUIDE и NAV. Игра не останавливается, решения за тебя не принимаются.",guideStageOne:"01 / ТЕКУЩАЯ ЦЕЛЬ",guideStageTwo:"02 / УПРАВЛЕНИЕ И МАРШРУТ",guideStageThree:"03 / РИСКИ И ПОСЛЕДСТВИЯ",fieldTitle:"ДВА ПУТИ. ОДИН ВЫБОР.",fieldLead:"После сканирования найдите один из двух физических пультов. Выбор расходует время и ресурсы; другой пульт блокируется. Последствия записываются в журнал миссии и следующую главу кампании.",fieldSinkName:"HEAT SINK / ТЕПЛОВОЙ ЯКОРЬ",fieldSinkEffect:"Снизить нагрев, пожертвовав кислородом и 9 секундами. Выбор полезен при риске перегрева.",fieldAirName:"AIR BUFFER / РЕЗЕРВ ВОЗДУХА",fieldAirEffect:"Пополнить воздух за 11 секунд, но нагреть реактор и ухудшить здоровье экипажа. Особенно важно при утечке.",fieldNote:"Эти эффекты — правила настоящей игровой симуляции, не данные реальных людей или оборудования.",blackBoxGuide:"Чёрный ящик после завершения миссии",recordsGuide:"Личный архив завершённых операций",recordsTitle:"ТВОИ РЕШЕНИЯ. ТВОЯ ИСТОРИЯ.",recordsBody:"Только реальные завершённые операции. Личный рекорд по каждой аварии, локальная история попыток и осознанное удаление без передачи данных на сервер.",recordsCapacity:"Максимум хранимых локальных прохождений, не количество игроков",adaptiveGraphicsGuide:"Автографика по реальному времени кадра",adaptiveGraphicsTitle:"ГРАФИКА, КОТОРАЯ РЕАГИРУЕТ.",adaptiveGraphicsBody:"По клавише K или в меню паузы можно включить автоматический выбор HERO/ECO на основе локально измеренного P95 времени кадра. Ручной G всегда имеет приоритет. Это не гарантия FPS и не тест реального устройства.",blackBoxProof:"Чёрный ящик открывается только после настоящего игрового результата. Данные и журнал событий берутся из Godot, не из рейтинга или демонстрационных чисел.",
      lastOverline:"A7 / АВАРИЙНАЯ ПЕРЕДАЧА",lastHeading:"СИСТЕМА ЖДЁТ\nТВОЕГО РЕШЕНИЯ.",
      lastPlay:"НАЧАТЬ ОПЕРАЦИЮ",saveNote:"Локальные сохранения. Без обязательной регистрации.",
      footerNote:"Оригинальная научно-фантастическая игра. Предварительная версия для тестирования; не финальное AAA-производство.",
      footerMissions:"Операции",footerHelp:"Управление",install:"Установить приложение",
      privacy:"БЕЗ ТРЕКЕРОВ · СОХРАНЕНИЯ НА УСТРОЙСТВЕ"
    },
    en: {
      skip:"Skip to content",
      navMissions:"Missions",navWorld:"The World",navControls:"Controls",navPlay:"Play",
      eyebrow:"A7 / ORIGINAL INTERACTIVE EXPERIENCE",
      heroLead:"THE REACTOR IS DYING.\nYOU MAKE THE CALL.",
      heroSummary:"Three emergencies. Two power buses. One crew. Enter a failing industrial complex, solve real resource-routing puzzles and decide who survives.",
      heroPlay:"BEGIN OPERATION",fullCampaign:"THREE-ACT CAMPAIGN",exploreMissions:"EXPLORE MISSIONS",
      preview:"SOFTWARE PREVIEW · NOT A FINAL RELEASE",
      metricMissions:"PLAYABLE MISSIONS",metricChoices:"RESCUE STATION CAP",
      metricLang:"TWO LANGUAGES",metricReal:"REAL GODOT WEBGL",
      missionOverline:"001 / CAMPAIGN",missionHeading:"THREE OPERATIONS.\nONE CATASTROPHE.",
      missionIntro:"Not mock mini-games. Three playable emergencies in one actual 3D simulation with different hazards and lasting consequences.",
      gridSmall:"TOTAL GRID FAILURE",heatSmall:"THERMAL CASCADE",airSmall:"OXYGEN BREACH",
      allPlayable:"All three missions are playable. Your campaign progress is stored locally on this device.",
      activeMission:"SELECTED OPERATION",enterMission:"ENTER MISSION",
      worldOverline:"002 / THE WORLD",worldHeading:"INSIDE\nREACTOR A7.",
      worldIntro:"A playable physical world, not a browser mockup. Interactive terminals, changing light, emergency effects and actual resource-driven mechanics.",
      proofLabel:"CAPTURED FROM REAL GAMEPLAY",
      proofCaption:"This exact-source screenshot is generated during CI from the Godot WebGL game. No AI images, compositing or retouching.",
      feat1Title:"A living system",feat1Body:"Two power buses, reactor heat, oxygen, crew condition and bulkhead charge share a real simulation.",
      feat2Title:"Choices have cost",feat2Body:"Three rescue stations, but only two can be activated. Every choice changes available resources.",
      feat3Title:"The crew's story",feat3Body:"MARA radio transmissions, a crew-versus-core choice and distinct endings and results.",
      controlsOverline:"003 / OPERATOR GUIDE",controlsHeading:"ENTER THE SYSTEM.",
      controlsIntro:"Short commands, useful wayfinding and scalable graphics. Play on a computer or use the implemented mobile touch controls.",
      pcTitle:"PC / KEYBOARD",accessTitle:"ACCESSIBILITY",
      move:"Move",look:"Look",use:"Interact / rapid action",camera:"Reactor camera / radio log",
      language:"Interface language",graphics:"HERO / ECO visuals",
      reduceMotion:"Reduced motion",mute:"Toggle audio",forecastGuide:"30-second power-route forecast",operatorHelpGuide:"Contextual help for the live mission",navGuide:"Wayfinding to the actual terminal",onboardingTitle:"STUCK? ASK FOR A REAL HINT.",onboardingBody:"F1 opens three progressively detailed hints for the actual current objective: scan, repair, power routing, override or evacuation. On phones, use GUIDE and NAV. The game keeps running; no action is performed for you.",guideStageOne:"01 / CURRENT OBJECTIVE",guideStageTwo:"02 / CONTROLS AND ROUTE",guideStageThree:"03 / RISKS AND CONSEQUENCES",fieldTitle:"TWO PATHS. ONE DECISION.",fieldLead:"After the real scan, find one of two physical field stations. Activating one spends time and resources and locks the other. The consequence is recorded and affects the next campaign chapter.",fieldSinkName:"HEAT SINK / SERVICE SPINE",fieldSinkEffect:"Reduce core heat by spending oxygen and 9 seconds. A strategic hedge against reactor overheat.",fieldAirName:"AIR BUFFER / EVACUATION LOCK",fieldAirEffect:"Restore oxygen at the cost of 11 seconds, higher core heat and injured crew. A real tradeoff in leaking AIR.",fieldNote:"These are fictional gameplay mechanics, not measurements of people or industrial equipment.",blackBoxGuide:"Post-mission engine black box",recordsGuide:"Local history of completed runs",recordsTitle:"YOUR DECISIONS. YOUR HISTORY.",recordsBody:"Only real completed operations. Personal bests per emergency, a private attempt history and deliberate local erasure without server telemetry.",recordsCapacity:"Maximum locally retained runs — not a player count",adaptiveGraphicsGuide:"Opt-in graphics based on local frame timing",adaptiveGraphicsTitle:"GRAPHICS THAT RESPOND.",adaptiveGraphicsBody:"Press K or use the pause menu to opt in to HERO/ECO switching based on locally measured 95th-percentile frame time. Manual G always wins. No FPS guarantee or physical-device certification is implied.",blackBoxProof:"The black box unlocks only after a real result. All telemetry and event history come from Godot, not mock scores or demonstration metrics.",
      lastOverline:"A7 / EMERGENCY TRANSMISSION",lastHeading:"THE SYSTEM AWAITS\nYOUR DECISION.",
      lastPlay:"BEGIN OPERATION",saveNote:"Local saves. No mandatory account.",
      footerNote:"An original science-fiction game. Software preview for testing, not final AAA production.",
      footerMissions:"Operations",footerHelp:"Controls",install:"Install App",
      privacy:"NO TRACKERS · ON-DEVICE SAVES"
    }
  };
  const details = {
    ru: {
      blackout:{title:"BLACKOUT",description:"Два независимых контура и три жизненно важные системы. Перераспредели питание, спаси экипаж и открой аварийный шлюз.",hazard:"GRID INSTABILITY"},
      thermal:{title:"HEAT",description:"Температура растёт. Тепловые импульсы повторяются. Ремонтируй тщательно или сбрасывай тепло ценой здоровья и кислорода.",hazard:"THERMAL CASCADE"},
      breach:{title:"AIR",description:"Кислород утекает даже при работающем жизнеобеспечении. Полная герметизация или срочная заплатка — последствия разные.",hazard:"OXYGEN CRITICAL"}
    },
    en: {
      blackout:{title:"BLACKOUT",description:"Two independent power buses, three critical systems. Reroute energy, protect your crew and unlock the evacuation airlock.",hazard:"GRID INSTABILITY"},
      thermal:{title:"HEAT",description:"Heat rises and thermal pulses repeat. Repair carefully or purge the system at the cost of oxygen and crew condition.",hazard:"THERMAL CASCADE"},
      breach:{title:"AIR",description:"Oxygen is escaping despite active life support. Permanently seal the breach or use a rapid patch with lingering consequences.",hazard:"OXYGEN CRITICAL"}
    }
  };
  const param = new URLSearchParams(window.location.search);
  const fromQuery = param.get("lang");
  let remembered = "";
  try { remembered = localStorage.getItem("iron-pulse-world-locale") || ""; } catch (_) { /* private mode */ }
  let locale = languages.includes(fromQuery) ? fromQuery : languages.includes(remembered) ? remembered : "ru";
  let scenario = missions.includes(param.get("scenario")) ? param.get("scenario") : "blackout";
  const $ = (id) => document.getElementById(id);

  function launchUrl() {
    const url = new URL("./play/index.html", window.location.href);
    url.search = new URLSearchParams({scenario,lang:locale}).toString();
    url.hash = "";
    return url.href;
  }
  function campaignUrl() {
    const url = new URL("./play/index.html",window.location.href);
    url.search = new URLSearchParams({campaign:"1",lang:locale}).toString();
    url.hash = "";
    return url.href;
  }
  function sync() {
    document.documentElement.lang = locale;
    document.title = "IRON PULSE WORLD — THREE ACTS";
    for(const node of document.querySelectorAll("[data-i18n]")) {
      const id = node.dataset.i18n;
      if(Object.prototype.hasOwnProperty.call(dictionary[locale],id)) {
        node.textContent = dictionary[locale][id];
      }
    }
    $("language-value").textContent = locale.toUpperCase();
    $("language-other").textContent = locale==="ru" ? "EN" : "RU";
    for(const btn of document.querySelectorAll("[data-scenario]")) {
      const selected = btn.dataset.scenario === scenario;
      btn.classList.toggle("is-selected",selected);
      btn.setAttribute("aria-pressed",String(selected));
    }
    const info = details[locale][scenario];
    $("mission-name").textContent = info.title;
    $("mission-description").textContent = info.description;
    $("mission-hazard").textContent = info.hazard;
    $("mission-sequence").textContent = String(missions.indexOf(scenario)+1).padStart(2,"0")+" / 03";
    for(const link of document.querySelectorAll("[data-play]")) {
      link.setAttribute("href",launchUrl());
    }
    for(const link of document.querySelectorAll("[data-campaign-play]")) {
      link.setAttribute("href",campaignUrl());
    }
    $("gameplay-shot").alt = locale==="ru" ?
      "Настоящий кадр игрового реактора Godot WebGL из текущей проверенной сборки" :
      "Original, unedited reactor screenshot from the current verified Godot WebGL build";
    document.querySelector(".mission-selector").setAttribute("aria-label",
      locale==="ru" ? "Выберите настоящую игровую миссию" : "Choose a playable mission");
  }
  for(const btn of document.querySelectorAll("[data-scenario]")) {
    btn.addEventListener("click",() => {scenario=btn.dataset.scenario;sync();});
  }
  $("language").addEventListener("click",()=>{
    locale = locale==="ru" ? "en" : "ru";
    try { localStorage.setItem("iron-pulse-world-locale",locale); } catch (_) { /* no forced cookies */ }
    sync();
    document.dispatchEvent(new Event("iron-pulse:locale"));
  });
  // Optional PWA install affordance only appears when host/browser supplies a
  // real beforeinstallprompt; no inert "Install" control for unsupported users.
  let installEvent = null;
  window.addEventListener("beforeinstallprompt",(event)=>{
    event.preventDefault();
    installEvent=event;
    $("install").hidden=false;
  });
  $("install").addEventListener("click", async()=>{
    if(!installEvent) return;
    const event=installEvent;
    installEvent=null;
    $("install").hidden=true;
    event.prompt();
    try { await event.userChoice; } catch (_) { /* browser controlled */ }
  });
  if("serviceWorker" in navigator && (location.protocol==="https:" || location.hostname==="localhost" || location.hostname==="127.0.0.1")) {
    window.addEventListener("load",()=>navigator.serviceWorker.register("./sw.js").catch(()=>{}));
  }
  sync();
  // Read-only testing handle: no hidden fake local campaign stats.
  Object.defineProperty(window,"IRON_PULSE_WORLD",{value:Object.freeze({
    get language(){return locale;},
    get scenario(){return scenario;},
    get playUrl(){return launchUrl();},
    get campaignUrl(){return campaignUrl();},
    get missionCount(){return missions.length;}
  }),writable:false,configurable:false});
})();
