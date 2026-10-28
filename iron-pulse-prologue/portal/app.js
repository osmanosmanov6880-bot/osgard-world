/* IRON PULSE V9: international software-preview portal.
 * Offline first. Zero cookies, analytics, external fonts or tracking calls.
 * Only local same-origin build.json is requested to show VERIFIED source SHA. */
(() => {
  "use strict";
  const dictionary = Object.freeze({
    ru: {
      skip:"Перейти к игре",navMission:"Миссия",navSystems:"Системы",navProof:"Проверки",navPlay:"Играть ↗",
      heroEyebrow:"ПРОИЗВОДСТВЕННЫЙ ПРЕВЬЮ / SECTOR A7",
      heroSub:"Три аварии. Два контура питания. Один экипаж. Реактор не подождёт, пока ты примешь решение.",
      playBrowser:"Запустить в браузере",downloadWin:"Скачать для Windows",
      releaseNote:"Демо-версия. Не коммерческий релиз. Игровые системы работают офлайн.",
      statCrisis:"сценария аварии",statZones:"опасных сектора",statSeals:"защитных контура",
      realScreenshot:"НАСТОЯЩИЙ КАДР ИЗ ИГРЫ",noMock:"Снято прямо из игрового WebGL, без концепт-рендера.",
      missionLabel:"01 / МИССИЯ",missionTitle:"Каждое решение<br>имеет цену.",
      missionLead:"Не наблюдай за катастрофой. Иди через работающий 3D-комплекс, восстанови контуры и выведи экипаж. Температура, кислород и прочность твоего костюма меняются по-настоящему.",
      step1:"Найди неисправность",step1Text:"Исследуй реакторный зал и получи настоящие показания аварии.",
      step2:"Выбери жертву",step2Text:"Два контура питают три системы. Защити экипаж или стабилизируй ядро.",
      step3:"Пройди через опасность",step3Text:"Герметизируй два из трёх секторов. Третий придётся пересечь под угрозой костюму.",
      systemsLabel:"02 / АВАРИЙНЫЕ ПРОТОКОЛЫ",systemsTitle:"Три пути.<br>Три вида угрозы.",
      systemsLead:"Переключи сценарий, чтобы увидеть, как меняется задача. В самой игре это настоящие разные системы расчёта.",
      proofLabel:"03 / ИНЖЕНЕРНАЯ ПРОЗРАЧНОСТЬ",proofTitle:"Не обещания.<br>Проверяемый билд.",
      proofLead:"Игра экспортируется из одного Git-коммита, проверяется автоматическими тестами и запускается в настоящем Chromium. Аппаратная и художественная приёмка ещё обязательны.",
      proofEngine:"Настоящая нативная 3D-сцена, игровые механики и сохранения.",
      proofHash:"Проверенные файлы Windows и WebGL из одного исходника.",
      proofBrowser:"Браузерные тесты управления на ПК и сенсорной эмуляции.",
      holdTitle:"SOFTWARE PREVIEW",
      holdText:"Не готово к коммерческому выпуску: требуется QA реального GPU, телефонов и независимых игроков.",
      ctaLabel:"REACTOR A7 / SYSTEM ONLINE",ctaTitle:"Ты управляешь<br>последними минутами.",
      ctaPlay:"Войти в комплекс",footer:"Нет учётных записей, аналитики и сетевой игры. Все сохранения локальные.",
      backTop:"Наверх ↑",
      scenarios:{
        grid:{tag:"A7 / GRID DISCONNECT",title:"BLACKOUT",description:"Система питания отказала. Выбери, какой контур отключить временно, чтобы зарядить эвакуационный шлюз.",risk:"POWER ALLOCATION",objective:"02 BUSES / 03 LOADS"},
        heat:{tag:"A7 / THERMAL CASCADE",title:"HEAT",description:"Повторные температурные импульсы усиливают повреждения. Быстрый сброс спасает ядро ценой кислорода и здоровья.",risk:"CRITICAL TEMPERATURE",objective:"CORE STABILITY"},
        air:{tag:"A7 / PRESSURE LOSS",title:"AIR",description:"Кислород утекает даже при включённом жизнеобеспечении. Устранить пробоину можно быстро или надёжно.",risk:"CREW OXYGEN",objective:"LEAK CONTAINMENT"}
      }
    },
    en: {
      skip:"Skip to the game",navMission:"Mission",navSystems:"Systems",navProof:"Verification",navPlay:"Play ↗",
      heroEyebrow:"SOFTWARE PREVIEW / SECTOR A7",
      heroSub:"Three emergencies. Two power buses. One crew. The reactor won't wait for your next decision.",
      playBrowser:"Play in browser",downloadWin:"Download for Windows",
      releaseNote:"Software preview, not a commercial release. Gameplay works offline.",
      statCrisis:"emergency scenarios",statZones:"hazard sectors",statSeals:"available field seals",
      realScreenshot:"REAL IN-GAME SCREENSHOT",noMock:"Captured directly from playable Godot WebGL. Not a concept render.",
      missionLabel:"01 / YOUR MISSION",missionTitle:"Every decision<br>has a price.",
      missionLead:"Don't watch a disaster. Move through a real 3D industrial complex, restore critical circuits and evacuate the crew. Heat, oxygen and your suit integrity all change during play.",
      step1:"Find the failure",step1Text:"Investigate the reactor hall and scan the damaged core.",
      step2:"Choose the sacrifice",step2Text:"Two power buses feed three systems. Protect the crew or stabilize the core.",
      step3:"Cross the danger",step3Text:"Seal two of three hazardous corridors. Cross the third with your suit at risk.",
      systemsLabel:"02 / EMERGENCY PROTOCOLS",systemsTitle:"Three paths.<br>Three different threats.",
      systemsLead:"Select a scenario to explore how its failure mode differs. Each is a real distinct gameplay simulation.",
      proofLabel:"03 / ENGINEERING TRANSPARENCY",proofTitle:"Not promises.<br>A verified build.",
      proofLead:"The game is built from one Git commit, checked by automated tests and played in real Chromium. Physical hardware and human art reviews are still required.",
      proofEngine:"Actual native 3D scene, gameplay mechanics and local checkpoints.",
      proofHash:"Windows and WebGL files verified against one exact-source build.",
      proofBrowser:"Browser control tests on desktop and touch emulation.",
      holdTitle:"SOFTWARE PREVIEW",
      holdText:"Not production ready: physical GPU, real phone and independent player QA remain open.",
      ctaLabel:"REACTOR A7 / SYSTEM ONLINE",ctaTitle:"You control<br>the final minutes.",
      ctaPlay:"Enter the complex",footer:"No accounts, analytics or online multiplayer. Checkpoints remain local.",
      backTop:"Back to top ↑",
      scenarios:{
        grid:{tag:"A7 / GRID DISCONNECT",title:"BLACKOUT",description:"The power distribution system has failed. Decide which load to shed temporarily to charge the evacuation bulkhead.",risk:"POWER ALLOCATION",objective:"02 BUSES / 03 LOADS"},
        heat:{tag:"A7 / THERMAL CASCADE",title:"HEAT",description:"Recurring thermal pulses increase the damage. A rapid purge can save the core at the cost of oxygen and crew health.",risk:"CRITICAL TEMPERATURE",objective:"CORE STABILITY"},
        air:{tag:"A7 / PRESSURE LOSS",title:"AIR",description:"Oxygen is leaking even with life support powered. Seal the breach quickly, or repair it properly at the cost of time.",risk:"CREW OXYGEN",objective:"LEAK CONTAINMENT"}
      }
    }
  });
  const localeButton = document.getElementById("locale-toggle");
  const tabs = [...document.querySelectorAll("[data-scenario]")];
  const scenarioTag = document.getElementById("scenario-tag");
  const scenarioTitle = document.getElementById("scenario-title");
  const scenarioDescription = document.getElementById("scenario-description");
  const scenarioRisk = document.getElementById("scenario-risk");
  const scenarioObjective = document.getElementById("scenario-objective");
  let locale = "ru";
  let scenario = "grid";
  const safeText = (id, value) => { const element = document.getElementById(id); if (element) element.textContent = value; };
  function render() {
    const data = dictionary[locale];
    document.documentElement.lang = locale;
    for (const node of document.querySelectorAll("[data-i18n]")) {
      const key = node.dataset.i18n;
      const value = data[key];
      if (typeof value === "string") {
        if (key === "missionTitle" || key === "systemsTitle" || key === "proofTitle" || key === "ctaTitle") {
          // The only approved markup is a static typographic newline.
          node.innerHTML = value.replaceAll("<br>", "<br>");
        } else node.textContent = value;
      }
    }
    const current = data.scenarios[scenario];
    scenarioTag.textContent = current.tag;
    scenarioTitle.textContent = current.title;
    scenarioDescription.textContent = current.description;
    scenarioRisk.textContent = current.risk;
    scenarioObjective.textContent = current.objective;
    for (const tab of tabs) {
      const selected = tab.dataset.scenario === scenario;
      tab.classList.toggle("active", selected);
      tab.setAttribute("aria-pressed", String(selected));
    }
    localeButton.setAttribute("aria-pressed",String(locale === "en"));
    localeButton.setAttribute("aria-label",locale === "ru" ? "Switch to English" : "Переключить на русский");
  }
  localeButton.addEventListener("click", () => { locale = locale === "ru" ? "en" : "ru"; render(); });
  for (const tab of tabs) {
    tab.addEventListener("click", () => { scenario = tab.dataset.scenario; render(); });
  }
  render();
  fetch("./build.json",{cache:"no-store"})
    .then(response => {
      if (!response.ok) throw new Error("Build metadata missing");
      return response.json();
    })
    .then(meta => {
      if (typeof meta.source_sha !== "string" || !/^[a-f0-9]{40}$/.test(meta.source_sha)) throw new Error("Unverified source id");
      safeText("build-sha",meta.source_sha.slice(0,12));
      safeText("short-sha","SHA " + meta.source_sha.slice(0,8));
    })
    .catch(() => {
      safeText("build-sha","UNVERIFIED PREVIEW");
      safeText("short-sha","CHECK BUILD METADATA");
    });
})();
