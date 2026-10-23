/* ZION-030 OPEN CITY v29 — playable living district, driving and open-world service contracts.
 * Uses the already-shipped local Three.js library and the original game-state API.
 * The original strategic city and its winning rules stay authoritative.
 */
(() => {
  'use strict';
  const root = document.getElementById('world-play');
  const stage = root?.querySelector('.stage');
  const game = () => window.ZION030_GAME;
  const rules = window.ZION030_CITY_RULES;
  if (!root || !stage || !game() || !rules) return;
  const CONTRACTS = rules.CONTRACTS;
  const DISPATCHES = rules.DISPATCHES;

  const HOT = [
    { x: -4, z: -3, temp: 58, name: 'Жилой двор' },
    { x: 2, z: 2, temp: 56, name: 'Городская площадь' },
    { x: 4, z: -2, temp: 54, name: 'Школьный маршрут' }
  ];
  const TOOLS = {
    tree: { label: 'Дерево', icon: '🌳' },
    shade: { label: 'Навес', icon: '▤' },
    water: { label: 'Дождевой сад', icon: '🌿' }
  };
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  const mobile = window.matchMedia('(pointer: coarse)');
  const button = document.createElement('button');
  button.id = 'oc-entry';
  button.className = 'oc-entry';
  button.type = 'button';
  button.textContent = '◈ ГУЛЯТЬ ПО ГОРОДУ · 3D';
  button.setAttribute('aria-label', 'Открыть свободную прогулку по трёхмерному городу');
  stage.append(button);

  const shell = document.createElement('section');
  shell.id = 'oc-shell';
  shell.className = 'oc-shell';
  shell.hidden = true;
  shell.setAttribute('aria-label', 'Режим свободной прогулки по городу');
  shell.innerHTML = `
    <div class="oc-viewport" id="oc-viewport" aria-label="Трёхмерные улицы Афин">
      <div class="oc-grain" aria-hidden="true"></div>
      <div class="oc-vignette" aria-hidden="true"></div>
      <div class="oc-crosshair" aria-hidden="true"><i></i></div>
      <div class="oc-world-message" id="oc-world-message" aria-live="polite"></div>
    </div>
    <header class="oc-header">
      <div class="oc-brand"><span class="oc-diamond">◈</span><span><strong>ТЕНЕВОЙ ПРОТОКОЛ</strong><small>OPEN CITY · АФИНЫ · ЭПИЗОД 02</small></span></div>
      <div class="oc-top-right"><span class="oc-live"><b></b> LIVE 3D</span><button type="button" id="oc-exit" class="oc-glass">✕ <span>К КАРТЕ</span></button></div>
    </header>
    <aside class="oc-objective" aria-label="Цель миссии">
      <span class="oc-eyebrow">ЗАДАНИЕ 01 / СНИЗИТЬ ПЕРЕГРЕВ</span>
      <strong>Охлади три горячие зоны</strong>
      <p>Основная сюжетная миссия. Оранжевые маяки — перегретые зоны. Голубые маяки — городские контракты.</p>
      <div class="oc-progress"><span id="oc-progress-bar"></span></div>
      <div class="oc-progress-label"><span id="oc-score">0 / 3 ЗОНЫ</span><span id="oc-remaining">3 МОДУЛЯ</span></div>
    </aside>
    <div class="oc-right-hud"><div class="oc-map-frame"><canvas id="oc-minimap" width="230" height="230" aria-label="Миникарта трёх районов"></canvas><span>АФИНЫ · КВАРТАЛ 03</span></div>
    <div class="oc-weather"><span id="oc-weather-symbol">☀</span> <strong id="oc-weather-temp">27°C</strong><small id="oc-weather-label">ВЕЧЕР · СИМУЛЯЦИЯ</small></div></div>
    <aside class="oc-contract" aria-label="Контракты города"><div class="oc-contract-head"><span>КОНТРАКТЫ ГОРОДА</span><strong id="oc-contract-count">0 / 3</strong></div>
      <strong id="oc-contract-title">Исследуй дальние улицы</strong><p id="oc-contract-hint">Найди голубой маяк и восстанови инфраструктуру района.</p>
      <div class="oc-contract-stats"><span>◈ <b id="oc-credit">0</b> КРЕДИТОВ</span><span>★ <b id="oc-reputation">0</b> РЕПУТАЦИЯ</span></div>
      <button id="oc-upgrade" type="button" disabled>УЛУЧШИТЬ ЭЛЕКТРОМОБИЛЬ · 300 ◈</button><button id="oc-nav-mode" type="button">⌖ GPS: СЮЖЕТ</button>
    </aside>
    <div class="oc-status-bar" aria-label="Параметры симуляции"><button id="oc-time" type="button" title="Сменить время суток (T)">☼ ВЕЧЕР</button><button id="oc-rain" type="button" title="Переключить дождь (P)">☂ ДОЖДЬ</button><button id="oc-quality" type="button" title="Качество графики (Q)">◈ HIGH</button></div>
    <div class="oc-drive-hud" id="oc-drive-hud" hidden><span>ЭЛЕКТРОМОБИЛЬ · CITY RUNNER</span><strong id="oc-speed">0 <small>км/ч</small></strong><div class="oc-charge">▰▰▰▰▰ <b>100% БАТАРЕЯ</b></div><small>W — ГАЗ · S — НАЗАД · A/D — ПОВОРОТ · F — ВЫХОД</small></div>
    <div class="oc-location"><span class="oc-target-icon">⌖</span><span><small>БЛИЖАЙШАЯ ЦЕЛЬ</small><strong id="oc-target">ОСМОТРИ ГОРОД</strong><em id="oc-distance">Найди оранжевую метку</em></span></div>
    <div class="oc-toolbar" role="group" aria-label="Инструмент охлаждения">
      <button type="button" data-oc-tool="tree" aria-pressed="true"><span>1</span>🌳 <b>ДЕРЕВО</b></button>
      <button type="button" data-oc-tool="shade" aria-pressed="false"><span>2</span>▤ <b>НАВЕС</b></button>
      <button type="button" data-oc-tool="water" aria-pressed="false"><span>3</span>🌿 <b>САД</b></button>
    </div>
    <div class="oc-interact" id="oc-interact" hidden><kbd id="oc-interact-key">E</kbd><span id="oc-interact-text">УСТАНОВИТЬ ОХЛАЖДЕНИЕ</span></div>
    <button class="oc-action" id="oc-action" type="button" hidden>✓ ВЫПОЛНИТЬ</button><button class="oc-drive-action" id="oc-drive-action" type="button">🚘 СЕСТЬ В МАШИНУ</button>
    <div class="oc-controls"><span><kbd>W A S D</kbd> ИДТИ</span><span><kbd>SHIFT</kbd> БЕГ</span><span><kbd>МЫШЬ</kbd> КАМЕРА</span><span><kbd>E</kbd> ДЕЙСТВИЕ</span><span><kbd>F</kbd> МАШИНА</span><span><kbd>T / P / Q</kbd> ВРЕМЯ / ДОЖДЬ / ГРАФИКА</span><span><kbd>G</kbd> GPS</span></div>
    <div class="oc-joystick" id="oc-joystick" aria-label="Сенсорное управление движением"><div id="oc-stick"></div></div>
    <div class="oc-start" id="oc-start"><div class="oc-start-panel"><span class="oc-eyebrow">ЭПИЗОД 02 · ЖИВОЙ ОТКРЫТЫЙ РАЙОН</span>
      <h2>ГОРОД<br><em>ЖДЁТ ТЕБЯ.</em></h2>
      <p>Исследуй большой район Афин пешком или за рулём электромобиля. Выполни три контракта городской службы, меняй погоду и время суток, охлаждай перегретые кварталы. Прогресс сохраняется на устройстве.</p>
      <div class="oc-start-grid"><span>◉ <b>БОЛЬШОЙ ГОРОД</b><small>Улицы, транспорт и прохожие</small></span><span>↗ <b>АВТО И ПРОГУЛКА</b><small>WASD / F / джойстик</small></span><span>✦ <b>МИССИИ + КОНТРАКТЫ</b><small>Заработай репутацию</small></span></div>
      <button type="button" id="oc-start-play">НАЧАТЬ ПРОГУЛКУ <span>→</span></button>
      <small class="oc-start-foot">ПК: WASD — идти/управлять машиной · F — сесть/выйти · E — задание · T/P/Q — освещение/дождь/качество. Телефон: левый джойстик, пальцем по экрану — камера, кнопка 🚘 — автомобиль.</small>
    </div></div>
    <div class="oc-complete" id="oc-complete" hidden><div><span class="oc-eyebrow">МИССИЯ ВЫПОЛНЕНА</span><h2>ГОРОД<br><em>ОХЛАЖДЁН.</em></h2><p>Все три зоны получили охлаждение. Ты можешь продолжить прогулку или начать миссию заново.</p><button type="button" id="oc-keep-walking">ПРОДОЛЖИТЬ ПРОГУЛКУ</button><button type="button" id="oc-again">НОВАЯ МИССИЯ ↗</button></div></div>`;
  stage.append(shell);
  // v29: gameplay surfaces are real controls layered over the existing 3D world.
  shell.insertAdjacentHTML('beforeend', `
    <div class="oc-chapter" id="oc-chapter" aria-live="polite"><small>\u0420\u0410\u0419\u041e\u041d</small><strong id="oc-district-name">\u0426\u0415\u041d\u0422\u0420 \u0410\u0424\u0418\u041d</strong></div>
    <div class="oc-career" id="oc-career"><span>\u0421\u0422\u0410\u041c\u0418\u041d\u0410 <b id="oc-stamina-text">100%</b></span><div class="oc-meter"><i id="oc-stamina-bar"></i></div><span>\u0414\u0418\u0421\u041f\u0415\u0422\u0427\u0415\u0420 <b id="oc-dispatch-counter">0 / 5</b></span></div>
    <button class="oc-journal-trigger" id="oc-journal-button" type="button" aria-haspopup="dialog" aria-controls="oc-journal">\u2637 \u041c\u0418\u0421\u0421\u0418\u0418 <kbd>J</kbd></button>
    <button class="oc-pause-trigger" id="oc-pause-button" type="button" aria-haspopup="dialog" aria-controls="oc-pause">\u2161\u2161 \u041f\u0410\u0423\u0417\u0410</button>
    <aside class="oc-radio" id="oc-radio" role="status" aria-live="polite"><span>\u25c8 \u0414\u0418\u0421\u041f\u0415\u0422\u0427\u0415\u0420</span><p id="oc-radio-text">\u0413\u043e\u0440\u043e\u0434\u0441\u043a\u0430\u044f \u0441\u0432\u044f\u0437\u044c \u0430\u043a\u0442\u0438\u0432\u043d\u0430.</p></aside>
    <section class="oc-journal" id="oc-journal" role="dialog" aria-label="\u0416\u0443\u0440\u043d\u0430\u043b \u0437\u0430\u0434\u0430\u043d\u0438\u0439" aria-modal="true" hidden>
      <div class="oc-modal-card"><header><div><small>\u0414\u0418\u0421\u041f\u0415\u0422\u0427\u0415\u0420\u0421\u041a\u0410\u042f \u0421\u041b\u0423\u0416\u0411\u0410</small><h2>\u041a\u041e\u041d\u0422\u0420\u0410\u041a\u0422\u042b \u0413\u041e\u0420\u041e\u0414\u0410</h2></div><button type="button" id="oc-journal-close" aria-label="\u0417\u0430\u043a\u0440\u044b\u0442\u044c">\u2715</button></header>
      <p class="oc-modal-sub">\u041f\u044f\u0442\u044c \u043c\u043d\u043e\u0433\u043e\u044d\u0442\u0430\u043f\u043d\u044b\u0445 \u043c\u0438\u0441\u0441\u0438\u0439. \u0412\u044b\u0431\u0435\u0440\u0438 \u0437\u0430\u0434\u0430\u043d\u0438\u0435: GPS \u043f\u0440\u043e\u043b\u043e\u0436\u0438\u0442 \u043f\u0443\u0442\u044c. E \u2014 \u0432\u0437\u0430\u0438\u043c\u043e\u0434\u0435\u0439\u0441\u0442\u0432\u0438\u0435.</p>
      <div id="oc-journal-list" class="oc-journal-list"></div>
      <div class="oc-garage"><h3>\u0413\u0410\u0420\u0410\u0416 · CITY RUNNER</h3><p>\u0423\u043b\u0443\u0447\u0448\u0435\u043d\u0438\u044f \u043e\u043f\u043b\u0430\u0447\u0438\u0432\u0430\u044e\u0442\u0441\u044f \u043a\u0440\u0435\u0434\u0438\u0442\u0430\u043c\u0438 \u0437\u0430 \u043c\u0438\u0441\u0441\u0438\u0438, \u0431\u0435\u0437 \u0434\u043e\u043d\u0430\u0442\u0430.</p><div id="oc-garage-balance" class="oc-garage-balance" aria-live="polite"></div><div class="oc-garage-options"><button id="oc-upgrade-speed" type="button">ДВИГАТЕЛЬ · 300 ◈</button><button id="oc-upgrade-grip" type="button">\u041f\u041e\u0414\u0412\u0415\u0421\u041a\u0410 · 260 \u25c8</button><button id="oc-upgrade-battery" type="button">\u0411\u0410\u0422\u0410\u0420\u0415\u042f · 230 \u25c8</button></div></div>
      <button type="button" class="oc-modal-main" id="oc-journal-resume">\u0412\u0415\u0420\u041d\u0423\u0422\u042c\u0421\u042f \u0412 \u0413\u041e\u0420\u041e\u0414</button></div>
    </section>
    <section class="oc-pause" id="oc-pause" role="dialog" aria-modal="true" aria-label="\u041c\u0435\u043d\u044e \u043f\u0430\u0443\u0437\u044b" hidden><div class="oc-pause-card"><small>OPEN CITY · \u041f\u0410\u0423\u0417\u0410</small><h2>\u041f\u0420\u041e\u0414\u041e\u041b\u0416\u0418\u041c?</h2><p>\u0417\u0430\u0434\u0430\u043d\u0438\u044f, \u043d\u0430\u0433\u0440\u0430\u0434\u044b \u0438 \u0443\u043b\u0443\u0447\u0448\u0435\u043d\u0438\u044f \u0441\u043e\u0445\u0440\u0430\u043d\u044f\u044e\u0442\u0441\u044f \u0432 \u0431\u0440\u0430\u0443\u0437\u0435\u0440\u0435.</p><button type="button" id="oc-resume">\u041f\u0420\u041e\u0414\u041e\u041b\u0416\u0418\u0422\u042c</button><button type="button" id="oc-pause-journal">\u0416\u0423\u0420\u041d\u0410\u041b \u0418 \u0413\u0410\u0420\u0410\u0416</button><button type="button" id="oc-exit-to-map">\u0412\u042b\u0419\u0422\u0418 \u041d\u0410 \u041a\u0410\u0420\u0422\u0423</button><small>WASD \u2014 \u0445\u043e\u0434\u044c\u0431\u0430 · SPACE \u2014 \u043f\u0440\u044b\u0436\u043e\u043a · V \u2014 \u043a\u0430\u043c\u0435\u0440\u0430 · J \u2014 \u0436\u0443\u0440\u043d\u0430\u043b · M \u2014 \u043a\u0430\u0440\u0442\u0430</small></div></section>
    <div class="oc-vehicle-charge" id="oc-vehicle-charge" hidden><span>\u26a1 \u0417\u0410\u0420\u042f\u0414</span><strong id="oc-battery-readout">100%</strong><div class="oc-meter"><i id="oc-battery-bar"></i></div></div>
  `);
  shell.querySelector('.oc-start-foot').append(' · SPACE: прыжок · V: камера · J: журнал · M: карта · ESC: пауза');
  // Keep mission and pause actions inside the same responsive action bar as
  // CINEMA, FPS and Exit. The old absolute offsets could cover those controls.
  const headerActions=shell.querySelector('.oc-top-right');
  const exitButton=shell.querySelector('#oc-exit');
  for(const id of ['oc-journal-button','oc-pause-button']){
    const control=shell.querySelector('#'+id);
    if(headerActions&&exitButton&&control)headerActions.insertBefore(control,exitButton);
  }

  shell.insertAdjacentHTML('beforeend', '<button id="oc-nav-mobile" type="button" aria-label="Переключить маршрут GPS">⌖ GPS: СЮЖЕТ</button>');
  shell.insertAdjacentHTML('beforeend', '<button id="oc-view-button" class="oc-view-button" type="button" aria-label="\u0421\u043c\u0435\u043d\u0438\u0442\u044c \u043a\u0430\u043c\u0435\u0440\u0443">\u25c9 \u041a\u0410\u041c\u0415\u0420\u0410</button><button id="oc-jump-button" class="oc-jump-button" type="button" aria-label="\u041f\u0440\u044b\u0433\u043d\u0443\u0442\u044c">\u21e7 \u041f\u0420\u042b\u0416\u041e\u041a</button>');



  const $ = (id) => document.getElementById(id);
  const viewport = $('oc-viewport');
  const keys = new Set();
  const joystick = { x: 0, y: 0, pointer: null, centerX: 0, centerY: 0 };
  const player = { x: 0, z: 0, y: 0, yaw: 0, cameraYaw: 0.35, pitch: 0.28, speed: 0, moving: false, vx:0, vz:0, stamina:100, height:0, vy:0, cameraMode:'chase' };
  const world = { ready: false, active: false, initialised: false, last: 0, frame: 0, assets: [], buildings: [], rings: [], dust: [], foliage: [], lamps: [], pulse: 0, fpsFrames: 0, fpsTime: 0, fpsSample: 0, quality: 'high', gpuScale: 1.35, softwareGL: false, lastRender: 0, navMode: 'main', people: [], traffic: [], contractMarkers: [], dispatchMarkers: [], streetLife: [], jumpQueued:false, car: null, rain: null, dayMode: 0, raining: false, path: [], routeTo: '', pathCell: '' };
  let surfaceKit=null,civicKit=null,photorealKit=null,natureKit=null;
  let scene, camera, renderer, avatar, legL, legR, armL, armR, sun, minimapCtx, targetIndex = -1, hemi, keyLight, blueFill, detailKit = null, cinematicKit = null, landmarkKit = null, streetKit = null, atelierKit = null, postFxKit = null, perfKit = null, coolingKit = null;
  let dragId = null, dragX = 0, dragY = 0, audio, animationId = 0, lastDistrict = '', lastHudUpdate = 0;
  const PROFILE_KEY = 'osgard:zion030:open-city:v28';
  let profile = rules.defaultProfile();
  try { profile = rules.sanitizeProfile(JSON.parse(localStorage.getItem(PROFILE_KEY) || 'null')); } catch (_) { /* Storage may be blocked. */ }
  const persist = () => { try { localStorage.setItem(PROFILE_KEY, JSON.stringify(profile)); } catch (_) { /* Play offline without saving if storage is unavailable. */ } };
  const getDispatch = () => rules.nextDispatchStep(profile);
  const modalOpen = () => !$('oc-pause').hidden || !$('oc-journal').hidden;
  const selectedDispatch = () => DISPATCHES.find(d => d.id === profile.activeDispatch);
  function radio(message) { $('oc-radio-text').textContent = message; $('oc-radio').classList.add('oc-radio-active'); clearTimeout(radio.timer); radio.timer = window.setTimeout(() => $('oc-radio').classList.remove('oc-radio-active'), 5500); }
  function showJournal() { if (!world.active || !$('oc-start').hidden) return; $('oc-pause').hidden = true; $('oc-journal').hidden = false; keys.clear(); updateJournal(); $('oc-journal-close').focus({ preventScroll:true }); }
  function closeJournal() { $('oc-journal').hidden = true; keys.clear(); $('oc-journal-button').focus({ preventScroll:true }); world.last = 0; }
  function pauseGame() { if (!world.active || !$('oc-start').hidden) return; $('oc-journal').hidden = true; $('oc-pause').hidden = false; keys.clear(); $('oc-resume').focus({ preventScroll:true }); }
  function resumeGame() { $('oc-pause').hidden = true; world.last = 0; keys.clear(); viewport.focus?.({ preventScroll:true }); }
  function updateJournal() {
    $('oc-garage-balance').textContent = 'Баланс: ' + profile.credits + ' ◈ · Репутация: ' + profile.reputation;
    const list=$('oc-journal-list'); list.replaceChildren();
    for (const quest of DISPATCHES) {
      const done=profile.dispatchDone.includes(quest.id),stageIndex=profile.dispatchSteps[quest.id]||0;
      const row=document.createElement('button');row.type='button';row.className='oc-quest-row';
      row.setAttribute('aria-pressed',String(profile.activeDispatch===quest.id));
      const header=document.createElement('strong'); header.textContent=(done ? '\u2713 ' : '\u25c8 ')+quest.name;
      const detail=document.createElement('span'); detail.textContent=done?'\u0412\u042b\u041f\u041e\u041b\u041d\u0415\u041d\u041e':quest.steps[stageIndex].text+'  ·  '+(stageIndex+1)+' / '+quest.steps.length;
      const reward=document.createElement('small');reward.textContent='+'+quest.reward+' \u25c8'; row.append(header,detail,reward);
      row.addEventListener('click',()=>{ const result=rules.selectDispatch(profile,quest.id); profile=result.profile; persist(); world.navMode='dispatch'; world.routeTo=''; updateJournal(); syncGame(); drawMiniMap(); radio(quest.name); });
      list.append(row);
    }
    for(const [id,type,price,done] of [['oc-upgrade-speed','speed',300,profile.fastCar],['oc-upgrade-grip','grip',260,profile.grip],['oc-upgrade-battery','battery',230,profile.batteryUpgrade]]) {
      const button=$(id);button.disabled=done||profile.credits<price;button.textContent=done?'✓ УЛУЧШЕНО':type==='speed'?'ДВИГАТЕЛЬ · 300 ◈':type==='grip'?'ПОДВЕСКА · 260 ◈':'БАТАРЕЯ · 230 ◈';
    }
  }
  function upgrade(type) { const r=rules.purchaseUpgrade(profile,type);if(!r.changed){radio('\u041d\u0435\u0434\u043e\u0441\u0442\u0430\u0442\u043e\u0447\u043d\u043e \u043a\u0440\u0435\u0434\u0438\u0442\u043e\u0432');return false;}profile=r.profile;persist();updateJournal();syncGame();radio('\u0423\u043b\u0443\u0447\u0448\u0435\u043d\u0438\u0435 CITY RUNNER \u043a\u0443\u043f\u043b\u0435\u043d\u043e');return true; }

  function announce(message, time = 1800) {
    const panel = $('oc-world-message'); panel.textContent = message; panel.classList.add('oc-visible');
    clearTimeout(announce.timer); announce.timer = window.setTimeout(() => panel.classList.remove('oc-visible'), time);
  }
  const clamp = (v, min, max) => Math.max(min, Math.min(max, v));
  const rand = (x, z, salt = 0) => { const a = Math.sin((x + salt) * 127.1 + (z - salt) * 311.7 + 74.7) * 43758.5453; return a - Math.floor(a); };
  const terrainBuilding = rules.buildingAt;
  const occupied = new Set();
  for (let x = -19; x <= 19; x++) for (let z = -19; z <= 19; z++) if (terrainBuilding(x, z)) occupied.add(`${x},${z}`);
  const collides = (px, pz, radius = .25) => rules.blocked(px, pz, radius);
  function makeMat(color, roughness = .83, metalness = .07, emissive = 0x000000, intensity = 0) {
    return reduceMotion.matches || world.softwareGL
      ? new THREE.MeshLambertMaterial({ color, emissive, emissiveIntensity: intensity })
      : new THREE.MeshStandardMaterial({ color, roughness, metalness, emissive, emissiveIntensity: intensity });
  }
  const drawBox = (parent, x, y, z, w, h, d, mat, shadow = false) => {
    const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat);
    m.position.set(x, y + h / 2, z);
    m.castShadow = shadow;
    m.receiveShadow = true;
    parent.add(m); return m;
  };
  function patternTexture(pattern, emissiveOnly = false) {
    const canvas = document.createElement('canvas'); canvas.width = 256; canvas.height = 512;
    const g = canvas.getContext('2d');
    if (!g) return null;
    if (!emissiveOnly) {
      const grad = g.createLinearGradient(0, 0, 256, 0);
      for (const [p, c] of [[0, '#152736'], [.16, '#4e5868'], [.56, '#27394a'], [1, '#172d3b']]) grad.addColorStop(p, c);
      g.fillStyle = grad; g.fillRect(0, 0, 256, 512);
      for (let i = 0; i <= 7; i++) { g.fillStyle = i % 2 ? '#182b3a' : '#43505a'; g.fillRect(0, i * 72, 256, 3); }
      g.fillStyle = '#8193a1'; g.globalAlpha = .18; for (let x = 0; x <= 256; x += 63) g.fillRect(x, 0, 5, 512); g.globalAlpha = 1;
    } else { g.fillStyle = '#000'; g.fillRect(0, 0, 256, 512); }
    for (let row = 0; row < 7; row++) for (let col = 0; col < 4; col++) {
      const lit = rand(col + pattern * 7, row - pattern * 3, 4) > .47;
      const wx = 17 + col * 60, wy = 20 + row * 70;
      g.fillStyle = emissiveOnly ? (lit ? '#ffb86e' : '#000000') : (lit ? '#d2a477' : '#071824');
      g.fillRect(wx, wy, 34, 42);
      if (!emissiveOnly) { g.fillStyle = lit ? '#ffcf95' : '#203e51'; g.fillRect(wx + 16, wy, 2, 42); g.fillStyle = '#0c2435'; g.fillRect(wx, wy + 21, 34, 2); }
    }
    const t = new THREE.CanvasTexture(canvas); t.colorSpace = emissiveOnly ? THREE.NoColorSpace : THREE.SRGBColorSpace;
    t.anisotropy = Math.min(8, renderer.capabilities.getMaxAnisotropy());
    return t;
  }
  function billboardTexture(text, sub = '') {
    const c = document.createElement('canvas'); c.width = 1024; c.height = 300;
    const g = c.getContext('2d');
    g.fillStyle = '#041726'; g.fillRect(0, 0, 1024, 300);
    g.strokeStyle = '#33d9f3'; g.lineWidth = 14; g.strokeRect(8, 8, 1008, 284);
    g.font = '900 112px system-ui'; g.textAlign = 'center'; g.fillStyle = '#e2faff'; g.fillText(text, 512, 147);
    g.font = '700 36px system-ui'; g.fillStyle = '#65dfea'; g.fillText(sub, 512, 220);
    const tex = new THREE.CanvasTexture(c); tex.colorSpace = THREE.SRGBColorSpace; return tex;
  }
  function glowSprite(hex, opacity = .8) {
    const c = document.createElement('canvas'); c.width = c.height = 128;
    const g = c.getContext('2d'); const gr = g.createRadialGradient(64, 64, 3, 64, 64, 64);
    gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(.18, 'rgba(255,255,255,.8)'); gr.addColorStop(.5, 'rgba(255,255,255,.22)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = gr; g.fillRect(0, 0, 128, 128);
    return new THREE.Sprite(new THREE.SpriteMaterial({ map: new THREE.CanvasTexture(c), color: hex, opacity, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
  }
  function addGround() {
    const road = makeMat('#132433', .73, .23), stone = makeMat('#304454', .81), edge = makeMat('#73818a', .75);
    const ground = new THREE.Mesh(new THREE.PlaneGeometry(150, 150), makeMat('#0b1723'));
    ground.rotation.x = -Math.PI / 2; ground.position.y = -.075; ground.receiveShadow = true; scene.add(ground);
    const asphalt = new THREE.Mesh(new THREE.PlaneGeometry(41, 41), road); asphalt.name='ZION35 asphalt surface';
    asphalt.rotation.x = -Math.PI / 2; asphalt.position.y = -.035; asphalt.receiveShadow = true; scene.add(asphalt);
    const plaza = new THREE.Mesh(new THREE.PlaneGeometry(5.6, 5.6), stone); plaza.name='ZION35 plaza surface';
    plaza.rotation.x = -Math.PI / 2; plaza.position.y = -.018; plaza.receiveShadow = true; scene.add(plaza);
    const markerMat = new THREE.MeshBasicMaterial({ color: 0x7797a3, transparent: true, opacity: .35, depthWrite: false });
    for (let i = -7; i <= 7; i++) {
      const xMark = drawBox(scene, i + .5, -.011, 0, .009, .007, 15.1, markerMat);
      const zMark = drawBox(scene, 0, -.011, i + .5, 15.1, .007, .009, markerMat);
      xMark.receiveShadow = zMark.receiveShadow = false;
    }
    // Pedestrian routes are visually legible and remain traversable in the actual physics map.
    const street = makeMat('#192f3c', .85, .15), walk = makeMat('#354854', .82);
    // Major roads form a connected 40x40 district; strips and shoulders distinguish traffic lanes.
    const marks = [];
    const tmp = new THREE.Object3D();
    const mark = (x, z, w, d) => {
      tmp.position.set(x, -.024, z); tmp.scale.set(w, .006, d); tmp.updateMatrix(); marks.push(tmp.matrix.clone());
    };
    for (let n = -15; n <= 15; n += 5) {
      if (n !== 0) {
        drawBox(scene, n, -.036, 0, 1.12, .008, 40, street);
        drawBox(scene, 0, -.036, n, 40, .008, 1.12, street);
      }
      for (let k = -19; k <= 19; k += 2) {
        if (Math.abs(k) <= 7 && Math.abs(n) <= 7) continue;
        mark(n, k, .035, .54); mark(k, n, .54, .035);
      }
    }
    const laneMarks = new THREE.InstancedMesh(new THREE.BoxGeometry(1, 1, 1), walk, marks.length);
    marks.forEach((matrix, i) => laneMarks.setMatrixAt(i, matrix));
    laneMarks.instanceMatrix.needsUpdate = true; laneMarks.frustumCulled = false; scene.add(laneMarks);
    const stripe = makeMat('#bccacc', .57);
    for (const p of [[-3, -5], [5, 3], [0, 5], [-5, 1]]) {
      for (let a = -3; a <= 3; a++) drawBox(scene, p[0] + a * .23, .003, p[1], .13, .008, .62, stripe);
    }
    const border = new THREE.MeshBasicMaterial({ color: 0x03bed6 });
    for (const side of [-1, 1]) {
      drawBox(scene, side * 7.82, .02, 0, .055, .04, 15.8, border);
      drawBox(scene, 0, .02, side * 7.82, 15.8, .04, .055, border);
    }
    for (let n = 0; n < 28; n++) {
      const x = (rand(n, 7) - .5) * 14, z = (rand(n, 2) - .5) * 14;
      if (Math.abs(x) < 2.9 && Math.abs(z) < 2.9) continue;
      const puddle = new THREE.Mesh(new THREE.CircleGeometry(.15 + rand(n, 9) * .28, 18), new THREE.MeshBasicMaterial({ color: 0x3aa3d0, transparent: true, opacity: .05 + rand(n, 13) * .10, depthWrite: false }));
      puddle.rotation.x = -Math.PI / 2; puddle.scale.y = 2.8; puddle.position.set(x, -.007, z); scene.add(puddle);
    }
    // Raised plaza and plaza ornament.
    const center = new THREE.Mesh(new THREE.CylinderGeometry(.47, .53, .20, 32), makeMat('#718898', .37, .64));
    center.position.set(-1.1, .08, 1.0); center.receiveShadow = true; scene.add(center);
    const accent = new THREE.Mesh(new THREE.TorusGeometry(.36, .035, 6, 48), new THREE.MeshBasicMaterial({ color: 0x38dce4 }));
    accent.position.set(-1.1, .22, 1); accent.rotation.x = Math.PI / 2; scene.add(accent);
  }
  function addCity() {
    const facade = [], crown = makeMat('#192b38', .52, .36), trim = makeMat('#728493', .58, .45), redAccent = makeMat('#d96d3f', .47, .4, '#632714', .22);
    for (let i = 0; i < 4; i++) {
      const base = patternTexture(i), emissive = patternTexture(i, true);
      facade.push(new THREE.MeshStandardMaterial({ map: base, emissiveMap: emissive, emissive: '#ffbe7d', emissiveIntensity: .73, metalness: .2, roughness: .62 }));
    }
    // Identical central-block silhouettes, but one draw call per facade/roof batch
    // rather than hundreds of independent meshes: keeps street mode responsive on low-end GPUs.
    const centerUnit = new THREE.BoxGeometry(1, 1, 1);
    const centerBatches = Array.from({ length: 4 }, () => []);
    const crownBatch = [], trimBatch = [], redBatch = [];
    const centerDummy = new THREE.Object3D();
    const centerBox = (batch, x, y, z, w, h, d) => {
      centerDummy.position.set(x, y + h / 2, z);
      centerDummy.scale.set(w, h, d);
      centerDummy.updateMatrix();
      batch.push(centerDummy.matrix.clone());
    };
    for (let x = -7; x <= 7; x++) for (let z = -7; z <= 7; z++) {
      if (!terrainBuilding(x, z)) continue;
      const r = rand(x, z), h = 2.6 + r * 5.15;
      const w = .68 + rand(z, x) * .18, d = .68 + rand(x + 5, z - 4) * .17;
      centerBox(centerBatches[Math.floor(rand(x + 7, z) * 4)], x, .015, z, w, h, d);
      centerBox(crownBatch, x, h + .014, z, w + .07, .095, d + .07);
      centerBox(trimBatch, x, .045, z, w + .04, .11, d + .04);
      if (r > .65) {
        centerBox(trimBatch, x, h + .11, z, .16, .36, .16);
        centerBox(redBatch, x + w * .15, h + .16, z, .11, .07, .08);
      }
      if (r > .78) centerBox(trimBatch, x, h + .2, z, .018, 1.1, .018);
      if (r < .64) centerBox(crownBatch, x, .08, z + d / 2 + .06, w * .85, .12, .18);
    }
    [[facade[0],centerBatches[0],true],
     [facade[1],centerBatches[1],true],
     [facade[2],centerBatches[2],true],
     [facade[3],centerBatches[3],true],
     [crown,crownBatch,false], [trim,trimBatch,false], [redAccent,redBatch,false]].forEach(([mat,batch,isFacade]) => {
      if (!batch.length) return;
      const mesh = new THREE.InstancedMesh(centerUnit, mat, batch.length);
      batch.forEach((matrix, i) => mesh.setMatrixAt(i, matrix));
      mesh.instanceMatrix.needsUpdate = true;
      mesh.castShadow = true;
      mesh.receiveShadow = true;
      scene.add(mesh);
      if (isFacade) world.buildings.push(mesh);
    });
    addOuterCity(facade, crown);
    // Non-interactive skyline outside the playable streets produces depth without expanding mission physics.
    const farMaterials = [makeMat('#111d2d'), makeMat('#152c3b'), makeMat('#1e2b3e')];
    const towerGeo = new THREE.BoxGeometry(1, 1, 1);
    for (let band = 0; band < 3; band++) {
      const matrices = [];
      for (let i = -22; i <= 22; i += 2) {
        for (const [x, z] of [[i, -26 - band * 3], [i, 26 + band * 3], [-26 - band * 3, i], [26 + band * 3, i]]) {
          const h = 3 + rand(x, z) * 14; const obj = new THREE.Object3D();
          obj.position.set(x, h / 2 - .09, z); obj.scale.set(1.2 + rand(z, x) * 1.2, h, 1.2 + rand(x, z + 9)); obj.updateMatrix(); matrices.push(obj.matrix.clone());
        }
      }
      const mesh = new THREE.InstancedMesh(towerGeo, farMaterials[band], matrices.length);
      matrices.forEach((matrix, i) => mesh.setMatrixAt(i, matrix)); mesh.instanceMatrix.needsUpdate = true; mesh.frustumCulled = false; scene.add(mesh);
    }
    // Streetscape: planted sidewalk trees, benches, solar shade shelters and illuminated signs.
    const wood = makeMat('#6c4e3c', .93), metal = makeMat('#718fa4', .43, .65), treeLeaf = [makeMat('#2d9162'), makeMat('#3cba78'), makeMat('#5ca56c')];
    function treeAt(x, z) {
      const g = new THREE.Group(); g.position.set(x, 0, z);
      const trunk = new THREE.Mesh(new THREE.CylinderGeometry(.055, .095, .68, 8), wood);
      trunk.position.y = .38; trunk.castShadow = true; g.add(trunk);
      for (let i = 0; i < 6; i++) {
        const v = rand(x + i, z - i), a = i * 2.399;
        const canopy = new THREE.Mesh(new THREE.IcosahedronGeometry(.23 + v * .16, 1), treeLeaf[i % 3]);
        canopy.position.set(Math.sin(a) * .26, .90 + (i % 3) * .19, Math.cos(a) * .26);
        canopy.castShadow = true; g.add(canopy);
      }
      scene.add(g); world.foliage.push(g);
    }
    const positions = [[-1.7, -1.7], [1.65, 1.68], [-1.5, 1.65], [1.75, -1.65], [-6, 4.5], [-3.8, 4.5], [5.9, -5.4], [-5.7, -5.7], [5.7, 5.2], [3.1, -5.9]];
    for (const [x, z] of positions) if (!collides(x, z)) treeAt(x, z);
    for (const [x, z, r] of [[0, -2.1, 0], [2.15, -.5, .9], [-1.6, 2.5, .6]]) {
      const g = new THREE.Group();
      drawBox(g, 0, .26, 0, .85, .09, .22, wood); for (const dx of [-.31, .31]) drawBox(g, dx, 0, 0, .055, .28, .17, metal);
      drawBox(g, 0, .34, .09, .83, .31, .08, wood); g.position.set(x, 0, z); g.rotation.y = r; scene.add(g);
    }
    for (const [x, z] of [[-2.6, -2.6], [2.7, 2.7], [-5.6, 1.4], [5.5, -4.8], [0, 3.2], [3.2, .6], [-3.5, 5]]) {
      const pole = new THREE.Group();
      drawBox(pole, 0, 0, 0, .045, 2.4, .045, metal);
      drawBox(pole, .17, 2.32, 0, .4, .055, .055, metal);
      const bulb = new THREE.Mesh(new THREE.SphereGeometry(.09, 10, 8), new THREE.MeshBasicMaterial({ color: 0xffd5a1 }));
      bulb.position.set(.34, 2.29, 0); pole.add(bulb);
      const aura = glowSprite(0xffb96f, .56); aura.position.set(.34, 2.30, 0); aura.scale.set(1.5, 1.5, 1); pole.add(aura);
      pole.position.set(x, 0, z); scene.add(pole); world.lamps.push(pole);
    }
    const signTex = billboardTexture('NEW ATHENS', 'RECLAIM THE STREETS · 2030');
    const sign = new THREE.Mesh(new THREE.PlaneGeometry(3.4, 1), new THREE.MeshBasicMaterial({ map: signTex, transparent: true, side: THREE.DoubleSide, toneMapped: false }));
    sign.position.set(-.0, 4.7, -8.25); scene.add(sign);
    const cyanRibbon = makeMat('#178da1', .3, .4, '#00c9d5', .4);
    for (let x = -7; x <= 7; x += 2) drawBox(scene, x, .02, -7.5, 1.0, .025, .03, cyanRibbon);
    const palm = makeMat('#165441');
    for (let i = 0; i < 3; i++) {
      const x = -5.5 + i * 5.5;
      if (!collides(x, 6.7)) {
        const g = new THREE.Group(); drawBox(g, 0, .0, 0, .09, 1.35, .09, wood);
        for (let p = 0; p < 6; p++) { const leaf = new THREE.Mesh(new THREE.ConeGeometry(.18, 1.05, 4), palm); leaf.position.set(Math.cos(p) * .27, 1.35, Math.sin(p) * .27); leaf.rotation.x = Math.PI / 3; leaf.rotation.z = p * Math.PI / 3; g.add(leaf); }
        g.position.set(x, 0, 6.7); scene.add(g);
      }
    }
  }
  // V28: outer district is instanced so large streets do not create thousands of draw calls.
  function addOuterCity(facades, roofMaterial) {
    const box = new THREE.BoxGeometry(1, 1, 1);
    const batches = [[], [], [], []], roofs = [];
    const dummy = new THREE.Object3D();
    for (let x = -19; x <= 19; x++) for (let z = -19; z <= 19; z++) {
      if (Math.abs(x) <= 7 && Math.abs(z) <= 7 || !terrainBuilding(x, z)) continue;
      const height = 2.5 + rand(x, z, 4) * 7.1;
      const w = .67 + rand(z, x, 5) * .15, d = .65 + rand(x, z, 7) * .2;
      dummy.position.set(x, height / 2, z); dummy.scale.set(w, height, d); dummy.updateMatrix();
      batches[Math.floor(rand(x, z, 8) * 4)].push(dummy.matrix.clone());
      dummy.position.set(x, height + .05, z); dummy.scale.set(w + .035, .1, d + .035); dummy.updateMatrix();
      roofs.push(dummy.matrix.clone());
    }
    for (let index = 0; index < 4; index++) {
      if (!batches[index].length) continue;
      const mesh = new THREE.InstancedMesh(box, facades[index], batches[index].length);
      batches[index].forEach((matrix, i) => mesh.setMatrixAt(i, matrix));
      mesh.instanceMatrix.needsUpdate = true; mesh.castShadow = false; mesh.receiveShadow = false;
      scene.add(mesh);
    }
    const top = new THREE.InstancedMesh(box, roofMaterial, roofs.length);
    roofs.forEach((matrix, i) => top.setMatrixAt(i, matrix)); top.instanceMatrix.needsUpdate = true;
    scene.add(top);
    // Large landmark silhouettes give players navigational anchors on outer streets.
    const landmarkMat = makeMat('#255371', .52, .29, '#0d5a6b', .14);
    const glass = makeMat('#7dcfdf', .15, .55, '#37abc6', .35);
    for (const [x, z, h] of [[-16, 12, 14], [13, 14, 17], [-12, -14, 12], [16, -16, 19]]) {
      if (terrainBuilding(Math.round(x), Math.round(z))) continue;
      const tower = new THREE.Group();
      drawBox(tower, 0, 0, 0, .38, h, .38, landmarkMat);
      drawBox(tower, 0, h, 0, .55, .34, .55, glass);
      const flare = glowSprite(0x54dff5, .5); flare.position.y = h + .3; flare.scale.set(2, 2, 1); tower.add(flare);
      tower.position.set(x, 0, z); scene.add(tower);
    }
  }
  function createCar(bodyColor = '#15abc0') {
    const shellMesh = new THREE.Group();
    const body = makeMat(bodyColor, .29, .68), glass = makeMat('#071f38', .13, .75), trim = makeMat('#afcad9', .34, .77);
    const rubber = makeMat('#111b25', .97), light = new THREE.MeshBasicMaterial({ color: 0xe4f9ff });
    drawBox(shellMesh, 0, .27, 0, .81, .27, 1.55, body, true);
    drawBox(shellMesh, 0, .53, .1, .73, .42, .84, glass, true);
    drawBox(shellMesh, 0, .81, .1, .76, .055, .88, body);
    drawBox(shellMesh, 0, .26, -.77, .68, .09, .08, trim);
    for (const x of [-.39, .39]) for (const z of [-.49, .52]) {
      const wheel = new THREE.Mesh(new THREE.CylinderGeometry(.18, .18, .13, 12), rubber);
      wheel.rotation.z = Math.PI / 2; wheel.position.set(x, .20, z); wheel.castShadow = true; shellMesh.add(wheel);
    }
    for (const x of [-.26, .26]) {
      const headlight = new THREE.Mesh(new THREE.PlaneGeometry(.16, .075), light);
      headlight.position.set(x, .38, -.79); shellMesh.add(headlight);
    }
    const strip = new THREE.Mesh(new THREE.PlaneGeometry(.5, .055), new THREE.MeshBasicMaterial({ color: 0x41dbff }));
    strip.position.set(0, .42, .781); strip.rotation.y = Math.PI; shellMesh.add(strip);
    if (detailKit) detailKit.detailCar(shellMesh);
    cinematicKit?.detailCar(shellMesh);
    landmarkKit?.detailCar(shellMesh);
    streetKit?.detailCar(shellMesh);
    return shellMesh;
  }
  function makePerson(index, x, z) {
    const group = new THREE.Group(), clothes = [0x5e8392, 0x976960, 0x447d83, 0x857c9a, 0xc3a36b];
    const coat = makeMat(clothes[index % clothes.length]);
    const skin = makeMat(index % 2 ? '#bc8d6d' : '#dec19e'), dark = makeMat('#172938');
    const torso = new THREE.Mesh(new THREE.CapsuleGeometry(.13, .26, 2, 6), coat); torso.position.y = .81; group.add(torso);
    const head = new THREE.Mesh(new THREE.SphereGeometry(.13, 8, 7), skin); head.position.y = 1.22; group.add(head);
    const legs = [];
    for (const a of [-.09, .09]) {
      const pivot = new THREE.Group(); pivot.position.set(a, .6, 0);
      drawBox(pivot, 0, -.45, 0, .095, .48, .13, dark); group.add(pivot); legs.push(pivot);
    }
    group.position.set(x, 0, z); scene.add(group);
    return { group, legs, x, z, yaw: 0, index, path: [], waypoint: 0, phase: index * .7, pace: .48 + rand(index, 5) * .34 };
  }
  function updatePedestrians(dt, t) {
    for (const person of world.people) {
      if (person.waypoint >= person.path.length && t >= (person.nextPlanAt || 0)) {
        const x = person.x + Math.floor(rand(person.index, Math.floor(t / 7), 2) * 15) - 7;
        const z = person.z + Math.floor(rand(Math.floor(t / 7), person.index, 6) * 15) - 7;
        person.path = rules.route(person, rules.nearestFree(x, z));
        person.waypoint = 1;
        person.nextPlanAt = t + (person.path.length > 1 ? .8 : 4);
      }
      const next = person.path[person.waypoint];
      if (next) {
        const dx = next.x - person.x, dz = next.z - person.z, dist = Math.hypot(dx, dz);
        if (dist < .09) person.waypoint++;
        else {
          const step = Math.min(dist, dt * person.pace);
          const nx = person.x + dx / dist * step, nz = person.z + dz / dist * step;
          if (!collides(nx, nz, .12)) { person.x = nx; person.z = nz; }
          else person.waypoint++;
          person.yaw = Math.atan2(-dx, -dz);
        }
      }
      person.group.position.set(person.x, 0, person.z);
      person.group.rotation.y = person.yaw;
      const stride = reduceMotion.matches ? 0 : Math.sin(t * 6 + person.phase) * .28;
      person.legs[0].rotation.x = stride; person.legs[1].rotation.x = -stride;
    }
  }
  function createContractLandmark(contract) {
    const group = new THREE.Group(); group.position.set(contract.x, 0, contract.z);
    const silver = makeMat('#9ec1ce', .41, .75), green = makeMat('#54e0b4', .31, .5, '#1b7f78', .35);
    const panel = makeMat('#145c79', .2, .68, '#137bac', .27), dark = makeMat('#172d3c');
    const pedestal = new THREE.Mesh(new THREE.CylinderGeometry(.61, .73, .19, 12), dark);
    pedestal.position.y = .12; group.add(pedestal);
    if (contract.id === 'solar') {
      drawBox(group, 0, .24, 0, .14, 1.10, .14, silver);
      const solar = drawBox(group, 0, 1.23, 0, 1.55, .08, 1.02, panel);
      solar.rotation.x = -.31;
      for (const dx of [-.45, 0, .45]) drawBox(group, dx, 1.28, 0, .022, .021, 1.02, silver);
    } else if (contract.id === 'water') {
      const bowl = new THREE.Mesh(new THREE.CylinderGeometry(.64, .70, .3, 24), silver);
      bowl.position.y = .37; group.add(bowl);
      const water = new THREE.Mesh(new THREE.CylinderGeometry(.55, .55, .015, 24), green);
      water.position.y = .53; group.add(water);
      drawBox(group, 0, .54, 0, .10, 1.19, .10, silver);
      const emitter = glowSprite(0x54ddeb, .75); emitter.position.y = 1.75; emitter.scale.set(1.2, 1.2, 1); group.add(emitter);
    } else {
      drawBox(group, 0, .2, 0, .12, 1.8, .12, silver);
      const receiver = new THREE.Mesh(new THREE.SphereGeometry(.30, 16, 12), panel);
      receiver.position.y = 2.13; group.add(receiver);
      for (const dx of [-.32, .32]) drawBox(group, dx, 1.37, 0, .05, .23, .48, silver);
    }
    const halo = new THREE.Mesh(new THREE.RingGeometry(.85, .95, 40), new THREE.MeshBasicMaterial({ color: 0x43edff, transparent: true, opacity: .9, side: THREE.DoubleSide }));
    halo.rotation.x = -Math.PI / 2; halo.position.y = .016; group.add(halo);
    const orb = glowSprite(0x52efff, .85); orb.position.y = 2.6; orb.scale.set(1.5, 1.5, 1); group.add(orb);
    scene.add(group);
    return { contract, group, orb, halo };
  }
  // v29 urban kit: instanced streetlights, benches, parks and charging points (GPU-batched).
  function addStreetLife() {
    const unit = new THREE.BoxGeometry(1,1,1), ico = new THREE.IcosahedronGeometry(1,1);
    const mats={pole:makeMat('#627886',.63,.28), lamp:new THREE.MeshBasicMaterial({color:0xffe7aa}),
      trunk:makeMat('#775e4c'),leaf:makeMat('#2a906b'),leaf2:makeMat('#4cab79'),
      seat:makeMat('#967963'),charger:makeMat('#36c7da',.27,.48,'#046780',.28)};
    const batches={pole:[],lamp:[],trunk:[],leaf:[],leaf2:[],seat:[],charger:[]};
    const dummy=new THREE.Object3D();
    function put(key,x,y,z,w,h,d){dummy.position.set(x,y,z);dummy.scale.set(w,h,d);dummy.updateMatrix();batches[key].push(dummy.matrix.clone());}
    for(let x=-15;x<=15;x+=5)for(let z=-15;z<=15;z+=5) {
      const px=x+.58,pz=z+.58;
      if(!collides(px,pz,.12)){
        put('pole',px,1.22,pz,.058,2.44,.058);
        put('lamp',px,2.45,pz,.2,.10,.2);
        put('seat',px+.19,.23,pz+.4,.8,.13,.23);
      }
    }
    for(let x=-19;x<=19;x+=2)for(let z=-19;z<=19;z+=2) {
      if(Math.abs(x)<4&&Math.abs(z)<4)continue;
      if(rand(x,z,23)<.67)continue;
      const tx=x+.42,tz=z+.35;
      if(collides(tx,tz,.14)||HOT.some(h=>Math.hypot(tx-h.x,tz-h.z)<1.7))continue;
      const scale=.82+rand(z,x,33)*.40;
      put('trunk',tx,.46*scale,tz,.15*scale,.92*scale,.15*scale);
      put(rand(x,z,52)>.5?'leaf':'leaf2',tx,1.15*scale,tz,.55*scale,.75*scale,.53*scale);
    }
    for(const station of rules.CHARGERS) {
      put('charger',station.x+.52,.5,station.z, .26,1,.25);
      put('lamp',station.x+.52,1.05,station.z, .25,.08,.23);
      put('pole',station.x+.52,.06,station.z,.63,.09,.65);
    }
    for(const [key,mat] of Object.entries(mats)) {
      const collection=batches[key];if(!collection.length)continue;
      const geom=key==='leaf'||key==='leaf2'?ico:unit;
      const mesh=new THREE.InstancedMesh(geom,mat,collection.length);
      collection.forEach((matrix,index)=>mesh.setMatrixAt(index,matrix));
      mesh.instanceMatrix.needsUpdate=true;mesh.castShadow=false;mesh.receiveShadow=false;
      scene.add(mesh);world.streetLife.push(mesh);
    }
    // Eight readable district landmarks; these are lightweight, real 3D signboards.
    const signs=[[-15,8,'CLINIC'],[10,13,'SCHOOL'],[15,-3,'WATER'],[1,-15,'METRO'],[-10,-2,'LAB'],
      [-15,-11,'SOLAR'],[14,14,'PARK'],[-8,12,'GARDEN']];
    for(const [x,z,name] of signs){
      const tex=billboardTexture(name,'OSGARD · NEW ATHENS');
      const sign=new THREE.Mesh(new THREE.PlaneGeometry(1.55,.47),new THREE.MeshBasicMaterial({map:tex,side:THREE.DoubleSide,transparent:true}));
      sign.position.set(x,2.55,z);scene.add(sign);
    }
  }
  function addDispatchMarkers() {
    const ringMaterial = new THREE.MeshBasicMaterial({color:0x9cf1ff,transparent:true,opacity:.85,side:THREE.DoubleSide,depthWrite:false});
    const tagMaterial = new THREE.MeshBasicMaterial({color:0x8cf4ff});
    for(let i=0;i<DISPATCHES.length;i++){
      const mission=DISPATCHES[i], group=new THREE.Group();
      const ring=new THREE.Mesh(new THREE.RingGeometry(.63,.75,30),ringMaterial.clone());ring.rotation.x=-Math.PI/2;ring.position.y=.035;group.add(ring);
      const tag=new THREE.Mesh(new THREE.OctahedronGeometry(.18,0),tagMaterial.clone());tag.position.y=2.6;group.add(tag);
      const pole=new THREE.Mesh(new THREE.CylinderGeometry(.018,.018,2.0,6),new THREE.MeshBasicMaterial({color:0x65b9c6,transparent:true,opacity:.38}));pole.position.y=1.3;group.add(pole);
      scene.add(group);world.dispatchMarkers.push({mission,group,ring,tag,lastStep:-1});
    }
    syncDispatchMarkers();
  }
  function syncDispatchMarkers() {
    for(const marker of world.dispatchMarkers){
      const done=profile.dispatchDone.includes(marker.mission.id),stage=profile.dispatchSteps[marker.mission.id]||0;
      const step=marker.mission.steps[Math.min(stage,marker.mission.steps.length-1)];
      marker.group.visible=!done;
      marker.group.position.set(step.x,0,step.z);
      const active=profile.activeDispatch===marker.mission.id;
      marker.ring.material.color.setHex(active?0xffe2a0:0x5fd8e9);
      marker.tag.material.color.setHex(active?0xffcf8c:0x84f3ff);
      marker.lastStep=stage;
    }
  }
  function addRain() {
    const count = mobile.matches ? 150 : 320;
    const positions = new Float32Array(count * 3), seeds = [];
    for (let i = 0; i < count; i++) {
      const x = (rand(i, 81) - .5) * 26, y = rand(i, 42) * 12, z = (rand(i, 14) - .5) * 26;
      positions[i * 3] = x; positions[i * 3 + 1] = y; positions[i * 3 + 2] = z;
      seeds.push(.7 + rand(i, 19) * 1.5);
    }
    const geometry = new THREE.BufferGeometry(); geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    const material = new THREE.PointsMaterial({ color: 0xb9dffe, size: .052, transparent: true, opacity: .72, depthWrite: false, sizeAttenuation: true });
    const rain = new THREE.Points(geometry, material); rain.frustumCulled = false; rain.visible = false; scene.add(rain);
    world.rain = { rain, positions, seeds, attribute: geometry.getAttribute('position') };
  }
  function addLivingWorld() {
    const carMesh = createCar(); scene.add(carMesh);
    world.car = { x: .7, z: -1.65, heading: -Math.PI / 2, speed: 0, occupied: false, battery:100, mesh: carMesh };
    carMesh.position.set(world.car.x, .02, world.car.z); carMesh.rotation.y = world.car.heading;
    // Four autonomous municipal vehicles, separate from the player's driveable car.
    const routes = [
      [[-15, -15], [15, -15], [15, 15], [-15, 15]],
      [[15, 15], [15, -15], [-15, -15], [-15, 15]],
      [[-10, 10], [10, 10], [10, -10], [-10, -10]],
      [[10, -10], [10, 10], [-10, 10], [-10, -10]]
    ];
    const palette = ['#d4ac72', '#518ab9', '#617c79', '#a86d70'];
    routes.forEach((route, i) => {
      const mesh = createCar(palette[i]); scene.add(mesh);
      const a = route[i % route.length]; mesh.position.set(a[0], .02, a[1]);
      world.traffic.push({ mesh, route, segment: i % route.length, progress: (i % 3) * .19, speed: 1.6 + i * .23 });
    });
    for (let i = 0; i < (mobile.matches ? 9 : 18); i++) {
      let x = Math.round((rand(i, 35) - .5) * 34), z = Math.round((rand(i, 65) - .5) * 34);
      const safe = rules.nearestFree(x, z); x = safe.x; z = safe.z;
      world.people.push(makePerson(i, x, z));
    }
    CONTRACTS.forEach(c => world.contractMarkers.push(createContractLandmark(c)));
    addStreetLife(); addDispatchMarkers(); addRain();
  }
  function updateTraffic(dt) {
    for (const car of world.traffic) {
      let step = dt * car.speed;
      // Traffic follows fixed clear arterial routes. Never teleport through buildings.
      while (step > 0) {
        const a = car.route[car.segment], b = car.route[(car.segment + 1) % car.route.length];
        const length = Math.hypot(b[0] - a[0], b[1] - a[1]);
        const free = (1 - car.progress) * length;
        const moved = Math.min(free, step);
        car.progress += moved / length; step -= moved;
        if (car.progress >= 1 - 1e-9) { car.segment = (car.segment + 1) % car.route.length; car.progress = 0; }
      }
      const a = car.route[car.segment], b = car.route[(car.segment + 1) % car.route.length];
      const x = a[0] + (b[0] - a[0]) * car.progress, z = a[1] + (b[1] - a[1]) * car.progress;
      car.mesh.position.set(x, .02, z);
      car.mesh.rotation.y = Math.atan2(-(b[0] - a[0]), -(b[1] - a[1]));
    }
  }
  function updateRain(dt) {
    const r = world.rain;
    if (!r || !world.raining) return;
    r.rain.position.set(player.x, 0, player.z);
    for (let i = 0; i < r.seeds.length; i++) {
      const index = i * 3;
      r.positions[index + 1] -= dt * (8 + r.seeds[i] * 5);
      if (r.positions[index + 1] < .08) r.positions[index + 1] = 10.5;
    }
    r.attribute.needsUpdate = true;
  }
  function updateAtmosphere() {
    if (!scene || !renderer) return;
    const isNight = world.dayMode === 1, isDay = world.dayMode === 2;
    if (world.skySphere) world.skySphere.material.color.setHex(isNight ? 0x324063 : isDay ? 0xeaf9ff : 0xffffff);
    scene.background.setHex(isNight ? 0x030918 : isDay ? 0x698ea7 : 0x122a3a);
    scene.fog.color.setHex(isNight ? 0x08182b : isDay ? 0x8fb2c3 : 0x1e3445);
    scene.fog.density = world.raining ? .029 : isNight ? .024 : .015;
    hemi.intensity = isNight ? 1.0 : isDay ? 3.0 : 2.25;
    keyLight.intensity = isNight ? .4 : isDay ? 3.3 : 2.45;
    blueFill.intensity = isNight ? 1.5 : .8;
    renderer.toneMappingExposure = world.raining ? 1.0 : isNight ? .86 : isDay ? 1.65 : 1.42;
    if (sun) sun.visible = !isNight;
    if (world.rain) world.rain.rain.visible = world.raining;
    cinematicKit?.syncEnvironment({ raining: world.raining, dayMode: world.dayMode });
    landmarkKit?.syncEnvironment({ raining: world.raining, dayMode: world.dayMode });
    streetKit?.syncEnvironment({ raining: world.raining, dayMode: world.dayMode });
    atelierKit?.syncEnvironment({ raining: world.raining, dayMode: world.dayMode });
    surfaceKit?.syncEnvironment({ raining: world.raining, dayMode: world.dayMode });
    civicKit?.syncEnvironment({ raining: world.raining, dayMode: world.dayMode });
    photorealKit?.syncEnvironment({ raining: world.raining, dayMode: world.dayMode });
    natureKit?.syncEnvironment({ raining: world.raining, dayMode: world.dayMode });
    coolingKit?.syncEnvironment({ raining: world.raining, dayMode: world.dayMode });
    postFxKit?.syncEnvironment({ raining: world.raining, dayMode: world.dayMode });
    $('oc-time').textContent = isNight ? '☾ НОЧЬ' : isDay ? '☼ ДЕНЬ' : '◐ ВЕЧЕР';
    $('oc-rain').setAttribute('aria-pressed', String(world.raining));
    $('oc-weather-symbol').textContent = world.raining ? '☂' : isNight ? '☾' : '☀';
    $('oc-weather-temp').textContent = world.raining ? '19°C' : isNight ? '22°C' : isDay ? '33°C' : '27°C';
    $('oc-weather-label').textContent = (isNight ? 'НОЧЬ' : isDay ? 'ДЕНЬ' : 'ВЕЧЕР') + (world.raining ? ' · ДОЖДЬ' : ' · СУХО');
  }
  function toggleNavigation() { world.navMode = world.navMode === 'main' ? 'contract' : world.navMode==='contract' ? 'dispatch' : 'main';world.routeTo='';syncGame();drawMiniMap();announce(world.navMode==='main'?'GPS: \u0442\u0435\u043f\u043b\u043e\u0432\u044b\u0435 \u0437\u043e\u043d\u044b':world.navMode==='contract'?'GPS: \u043a\u043e\u043d\u0442\u0440\u0430\u043a\u0442\u044b':'GPS: \u043c\u0438\u0441\u0441\u0438\u0438 \u0434\u0438\u0441\u043f\u0435\u0442\u0447\u0435\u0440\u0430'); }
  function cycleTime() { world.dayMode = (world.dayMode + 1) % 3; updateAtmosphere(); announce('Время суток изменено'); }
  function toggleRain() { world.raining = !world.raining; updateAtmosphere(); announce(world.raining ? 'Начался дождь. Асфальт остыл.' : 'Дождь закончился.'); }
  function toggleQuality() {
    world.quality = world.quality === 'eco' ? 'high' : 'eco';
    world.gpuScale = world.quality === 'eco' ? (reduceMotion.matches ? .34 : world.softwareGL ? .4 : .55) : reduceMotion.matches ? .34 : world.softwareGL ? .4 : mobile.matches ? 1.05 : 1.35;
    renderer.shadowMap.enabled = world.quality === 'high' && !mobile.matches && !reduceMotion.matches;
    detailKit?.setQuality(world.quality);
    cinematicKit?.setQuality(world.quality);
    landmarkKit?.setQuality(world.quality);
    streetKit?.setQuality(world.quality);
    atelierKit?.setQuality(world.quality);
    surfaceKit?.setQuality(world.quality);
      civicKit?.setQuality(world.quality);
      photorealKit?.setQuality(world.quality);
      natureKit?.setQuality(world.quality);
    coolingKit?.setQuality(world.quality);
    postFxKit?.setQuality(world.quality);
    $('oc-quality').textContent = world.quality === 'eco' ? '◈ ECO' : (detailKit?.stats.tier === 'ULTRA' ? '◈ ULTRA' : '◈ HIGH');
    resize(); announce(world.quality === 'eco' ? 'Экономичный режим' : 'Улучшенная графика');
  }
  function distanceToCar() { const c = world.car; return c ? Math.hypot(player.x - c.x, player.z - c.z) : Infinity; }
  function toggleCar() {
    const c = world.car;
    if (!c || !world.active || !world.ready || !$('oc-start').hidden) return false;
    if (c.occupied) {
      for (const [dx, dz] of [[1.0, 0], [-1.0, 0], [0, 1.15], [0, -1.15], [1.15, .9]]) {
        const x = c.x + dx, z = c.z + dz;
        if (!collides(x, z) && !CONTRACTS.some(q => Math.hypot(q.x - x, q.z - z) < .3)) {
          c.occupied = false; c.speed = 0; player.x = x; player.z = z;
          avatar.visible = player.cameraMode !== 'first'; announce('Ты вышел из электромобиля'); syncGame(); return true;
        }
      }
      announce('Нет свободного места для выхода'); return false;
    }
    if (distanceToCar() > 1.65) { announce('Подойди к электромобилю и нажми F'); return false; }
    c.occupied = true; avatar.visible = false; c.speed = 0;
    player.x = c.x; player.z = c.z; player.cameraYaw = c.heading;
    announce('За рулём CITY RUNNER · W/S газ · A/D поворот · F выход'); syncGame(); return true;
  }
  function nearestContract() {
    return CONTRACTS.filter(c => !profile.completed.includes(c.id))
      .map(c => ({ ...c, dist: Math.hypot(player.x - c.x, player.z - c.z) }))
      .sort((a, b) => a.dist - b.dist)[0] || null;
  }
  function completeNearbyContract() {
    if (world.car?.occupied) { announce('Для работы с оборудованием сначала выйди из автомобиля'); return false; }
    const nearest = nearestContract();
    if (!nearest || nearest.dist > 1.7) return false;
    const result = rules.completeContract(profile, nearest.id);
    if (!result.changed) return false;
    profile = result.profile; persist();
    const marker = world.contractMarkers.find(m => m.contract.id === nearest.id);
    if (marker) { marker.halo.material.color.setHex(0x4cffc5); marker.orb.material.color.setHex(0x4cffb8); }
    soundSuccess(); announce(`✓ ${nearest.short} · +${nearest.reward} КРЕДИТОВ`, 2200);
    syncGame(); drawMiniMap(); return true;
  }
  function advanceNearbyDispatch() {
    const step=getDispatch();if(!step)return false;
    const c=world.car;
    const result=rules.advanceDispatch(profile,{x:player.x,z:player.z,inCar:Boolean(c?.occupied),speed:c?.speed||0});
    if(!result.changed){
      if(result.reason==='park'&&Math.hypot(player.x-step.x,player.z-step.z)<1.7)radio('\u0417\u0430\u043f\u0430\u0440\u043a\u0443\u0439 \u0430\u0432\u0442\u043e\u043c\u043e\u0431\u0438\u043b\u044c \u0438 \u043e\u0441\u0442\u0430\u043d\u043e\u0432\u0438\u0441\u044c');
      if(result.reason==='onfoot'&&Math.hypot(player.x-step.x,player.z-step.z)<1.7)radio('\u0412\u044b\u0439\u0434\u0438 \u0438\u0437 \u043c\u0430\u0448\u0438\u043d\u044b \u0438 \u043d\u0430\u0436\u043c\u0438 E');
      return false;
    }
    profile=result.profile;persist();syncDispatchMarkers();world.routeTo='';
    if(result.complete){ soundSuccess();radio('\u2713 '+result.mission.name+' · +'+result.mission.reward+' \u043a\u0440\u0435\u0434\u0438\u0442\u043e\u0432'); }
    else radio('\u042d\u0422\u0410\u041f '+(result.step.index+1)+' / '+result.mission.steps.length+' \u0433\u043e\u0442\u043e\u0432. \u0421\u043b\u0435\u0434\u0443\u0439 \u043d\u043e\u0432\u043e\u043c\u0443 GPS.');
    const done=profile.dispatchDone.length;
    if(done===DISPATCHES.length)radio('\u0412\u0441\u0435 \u0433\u043e\u0440\u043e\u0434\u0441\u043a\u0438\u0435 \u0437\u0430\u0434\u0430\u043d\u0438\u044f \u0437\u0430\u0432\u0435\u0440\u0448\u0435\u043d\u044b!');
    updateJournal();syncGame();drawMiniMap();return true;
  }
  function cycleCamera() {
    const values=['chase','near','first'];player.cameraMode=values[(values.indexOf(player.cameraMode)+1)%values.length];
    const first=player.cameraMode==='first';if(avatar)avatar.visible=!world.car?.occupied&&!first;
    announce(first?'\u041a\u0430\u043c\u0435\u0440\u0430 \u043e\u0442 \u043f\u0435\u0440\u0432\u043e\u0433\u043e \u043b\u0438\u0446\u0430':player.cameraMode==='near'?'\u041a\u0430\u043c\u0435\u0440\u0430 \u0437\u0430 \u043f\u043b\u0435\u0447\u043e\u043c':'\u041a\u0430\u043c\u0435\u0440\u0430 \u043e\u0442 \u0442\u0440\u0435\u0442\u044c\u0435\u0433\u043e \u043b\u0438\u0446\u0430');
  }
  function buyUpgrade() {
    const r = rules.purchaseUpgrade(profile);
    if (!r.changed) return;
    profile = r.profile; persist(); syncGame(); updateJournal(); announce('CITY RUNNER · Улучшенный двигатель разблокирован!');
  }
  function createCoolingProp(type, x, z) {
    const group = new THREE.Group(); group.position.set(x, 0, z);
    if (type === 'tree') {
      const trunk = makeMat('#8c6547'), leaf = [makeMat('#49ba80'), makeMat('#65d5a1'), makeMat('#2f9264')];
      const stem = new THREE.Mesh(new THREE.CylinderGeometry(.08, .12, .91, 10), trunk); stem.position.y = .46; group.add(stem);
      // These materials are unique to this installation, so the chase camera
      // may softly fade only the crown that crosses the player's view.
      const crown = new THREE.Group(); crown.name='cooling-tree-crown';
      for(const mat of leaf){mat.transparent=true;mat.depthWrite=false;mat.opacity=1;}
      for (let i = 0; i < 8; i++) {
        const a=i*2.399,ball=new THREE.Mesh(new THREE.IcosahedronGeometry(.26+(i%3)*.06,1),leaf[i%3]);
        ball.position.set(Math.cos(a)*.29,1.12+(i%3)*.17,Math.sin(a)*.27);
        crown.add(ball);
      }
      group.add(crown);
      group.userData.ocCrown=crown;group.userData.ocCrownMats=leaf;group.userData.ocCrownOpacity=1;
    } else if (type === 'shade') {
      const pole = makeMat('#8ca4aa', .35, .76), sheet = makeMat('#99e3eb', .32, .58, '#198a91', .15);
      for (const dx of [-.46, .46]) for (const dz of [-.46, .46]) drawBox(group, dx, 0, dz, .045, 1.60, .045, pole);
      const roof = drawBox(group, 0, 1.60, 0, 1.25, .10, 1.25, sheet);
      roof.rotation.z = -.06;
      for (let i = -2; i <= 2; i++) drawBox(group, i * .22, 1.69, 0, .022, .022, 1.2, pole);
    } else {
      const bed = new THREE.Mesh(new THREE.CylinderGeometry(.63, .71, .16, 10), makeMat('#588b73'));
      bed.position.y = .09; group.add(bed);
      const water = new THREE.Mesh(new THREE.CylinderGeometry(.48, .48, .023, 30), makeMat('#35afbd', .16, .74, '#126d7c', .3)); water.position.y = .18; group.add(water);
      const stemMat = makeMat('#7edc87');
      for (let i = 0; i < 10; i++) { const a = i * 2.399, r = .22 + (i % 2) * .16; const s = new THREE.Mesh(new THREE.CylinderGeometry(.013, .023, .25 + (i % 3) * .09, 6), stemMat); s.position.set(Math.cos(a) * r, .30, Math.sin(a) * r); s.rotation.z = .22 * Math.sin(a); group.add(s); }
    }
    const halo = new THREE.Mesh(new THREE.RingGeometry(.75, .83, 48), new THREE.MeshBasicMaterial({ color: 0x70ffe0, transparent: true, opacity: .75, side: THREE.DoubleSide, depthWrite: false }));
    halo.rotation.x = -Math.PI / 2; halo.position.y = .03; group.add(halo);
    scene.add(group); return group;
  }
  // Keep newly planted greenery immersive without blocking the third-person
  // camera. Fade crowns crossing the camera-to-player segment (or surrounding
  // the player), not unrelated trees and not the original solid gameplay.
  function updateCoolingCrownOcclusion(dt){
    if(!camera)return;
    const ax=camera.position.x,ay=camera.position.y,az=camera.position.z;
    const bx=player.x,by=1.18+player.height,bz=player.z;
    const vx=bx-ax,vy=by-ay,vz=bz-az;
    const lengthSq=Math.max(.0001,vx*vx+vy*vy+vz*vz);
    const speed=1-Math.exp(-Math.max(0,dt)*13);
    let faded=0;
    for(const rec of world.rings){
      const prop=rec.prop,crown=prop?.userData?.ocCrown;
      if(!crown)continue;
      const x=prop.position.x,y=1.31,z=prop.position.z;
      const param=clamp(((x-ax)*vx+(y-ay)*vy+(z-az)*vz)/lengthSq,0,1);
      const dx=ax+vx*param-x,dy=ay+vy*param-y,dz=az+vz*param-z;
      const inSight=dx*dx+dy*dy+dz*dz<.64;
      const onTop=Math.hypot(bx-x,bz-z)<.90;
      const target=(inSight||onTop)? .035 : 1;
      const prev=prop.userData.ocCrownOpacity??1;
      const opacity=prev+(target-prev)*speed;
      prop.userData.ocCrownOpacity=opacity;
      for(const material of prop.userData.ocCrownMats)material.opacity=opacity;
      if(opacity<.50)faded++;
    }
    world.coolingCrownsFaded=faded;
  }
  function makeHotMarkers() {
    for (const [i, h] of HOT.entries()) {
      const group = new THREE.Group(); group.position.set(h.x, 0, h.z);
      const ring = new THREE.Mesh(new THREE.RingGeometry(.58, .72, 48), new THREE.MeshBasicMaterial({ color: 0xff763b, side: THREE.DoubleSide, transparent: true, opacity: .90, depthWrite: false }));
      ring.rotation.x = -Math.PI / 2; ring.position.y = .046; group.add(ring);
      const inner = new THREE.Mesh(new THREE.RingGeometry(.31, .34, 48), new THREE.MeshBasicMaterial({ color: 0xffd3a1, side: THREE.DoubleSide, transparent: true, opacity: .82, depthWrite: false }));
      inner.rotation.x = -Math.PI / 2; inner.position.y = .049; group.add(inner);
      const pole = new THREE.Mesh(new THREE.CylinderGeometry(.012, .012, 1.42, 6), new THREE.MeshBasicMaterial({ color: 0xeaa66d, transparent: true, opacity: .57 }));
      pole.position.y = .95; group.add(pole);
      const tip = glowSprite(0xff7848, .95); tip.position.y = 1.77; tip.scale.set(1.45, 1.45, 1); group.add(tip);
      const beacon = new THREE.Mesh(new THREE.OctahedronGeometry(.18, 0), new THREE.MeshBasicMaterial({ color: 0xffab65 }));
      beacon.position.y = 1.84; group.add(beacon);
      const disc = new THREE.Mesh(new THREE.CircleGeometry(1.2, 48), new THREE.MeshBasicMaterial({ color: 0xff5b35, transparent: true, opacity: .09, side: THREE.DoubleSide, depthWrite: false }));
      disc.rotation.x = -Math.PI / 2; disc.position.y = .04; group.add(disc);
      scene.add(group); world.rings.push({ group, ring, inner, tip, beacon, disc, i, cooled: false, prop: null });
    }
  }
  function makeAvatar() {
    avatar = new THREE.Group();
    const jacket = makeMat('#183b59', .5, .35), accents = makeMat('#29d4e3', .3, .65, '#0899ad', .8);
    const trousers = makeMat('#131f32'), shoes = makeMat('#637483'), face = makeMat('#d49e79', .9), hair = makeMat('#101820'), bag = makeMat('#283a45');
    const torso = new THREE.Mesh(new THREE.CapsuleGeometry(.23, .56, 4, 10), jacket); torso.position.y = 1.02; torso.castShadow = true; avatar.add(torso);
    const chest = drawBox(avatar, 0, .93, -.205, .32, .17, .028, accents);
    const neck = new THREE.Mesh(new THREE.CylinderGeometry(.095, .11, .12, 8), face); neck.position.y = 1.52; avatar.add(neck);
    const head = new THREE.Mesh(new THREE.SphereGeometry(.19, 16, 12), face); head.position.y = 1.71; head.castShadow = true; avatar.add(head);
    const hat = new THREE.Mesh(new THREE.SphereGeometry(.19, 16, 9, 0, Math.PI * 2, 0, Math.PI * .49), hair); hat.position.y = 1.74; avatar.add(hat);
    drawBox(avatar, 0, .96, .18, .35, .45, .18, bag);
    const buildLimb = (material, x, y, z, w, h, d, foot = false) => {
      const pivot = new THREE.Group(); pivot.position.set(x, y, z);
      drawBox(pivot, 0, -h, 0, w, h, d, material);
      if (foot) drawBox(pivot, 0, -h - .06, -.055, w + .04, .12, .28, shoes);
      avatar.add(pivot); return pivot;
    };
    legL = buildLimb(trousers, -.115, .79, 0, .15, .66, .17, true);
    legR = buildLimb(trousers, .115, .79, 0, .15, .66, .17, true);
    armL = buildLimb(jacket, -.31, 1.39, 0, .13, .59, .14);
    armR = buildLimb(jacket, .31, 1.39, 0, .13, .59, .14);
    const shade = new THREE.Mesh(new THREE.CircleGeometry(.35, 28), new THREE.MeshBasicMaterial({ color: 0x020d16, transparent: true, opacity: .28, depthWrite: false }));
    shade.rotation.x = -Math.PI / 2; shade.position.y = .018; avatar.add(shade);
    if (detailKit) detailKit.detailAvatar(avatar);
    cinematicKit?.detailAvatar(avatar);
    landmarkKit?.detailAvatar(avatar);
    streetKit?.detailAvatar(avatar);
    scene.add(avatar); return avatar;
  }
  function addAtmosphere() {
    const sky = document.createElement('canvas'); sky.width = 16; sky.height = 512;
    const g = sky.getContext('2d'); const gr = g.createLinearGradient(0, 0, 0, 512);
    gr.addColorStop(0, '#030d1b'); gr.addColorStop(.45, '#0b2436'); gr.addColorStop(.73, '#40556b'); gr.addColorStop(1, '#ab7363');
    g.fillStyle = gr; g.fillRect(0, 0, 16, 512);
    const sphere = new THREE.Mesh(new THREE.SphereGeometry(84, 32, 20), new THREE.MeshBasicMaterial({ map: new THREE.CanvasTexture(sky), side: THREE.BackSide, fog: false, depthWrite: false }));
    sphere.scale.y = .77; scene.add(sphere); world.skySphere = sphere;
    const sunGlow = glowSprite(0xff9873, .66); sunGlow.scale.set(24, 24, 1); sunGlow.position.set(-29, 14, -45); scene.add(sunGlow); sun = sunGlow;
    const haze = new THREE.Mesh(new THREE.PlaneGeometry(38, 7), new THREE.MeshBasicMaterial({ color: 0x5c85a1, transparent: true, opacity: .055, side: THREE.DoubleSide, depthWrite: false }));
    haze.position.set(0, 3, -14); scene.add(haze);
    const speckGeo = new THREE.SphereGeometry(.018, 5, 4), speckMat = new THREE.MeshBasicMaterial({ color: 0xa6d4e4, transparent: true, opacity: .25, depthWrite: false });
    const particles = new THREE.InstancedMesh(speckGeo, speckMat, 115);
    const dummy = new THREE.Object3D();
    for (let i = 0; i < 115; i++) { const x = (rand(i, 1) - .5) * 15, z = (rand(i, 2) - .5) * 15, y = .2 + rand(i, 3) * 6;
      dummy.position.set(x, y, z); dummy.scale.setScalar(.5 + rand(i, 5)); dummy.updateMatrix(); particles.setMatrixAt(i, dummy.matrix);
      world.dust.push({ x, y, z }); }
    particles.instanceMatrix.needsUpdate = true; scene.add(particles);
  }
  function bootThree() {
    if (world.initialised || !window.THREE) return;
    if (!game()?.state()?.ready) { window.setTimeout(bootThree, 140); return; }
    world.initialised = true;
    try {
      scene = new THREE.Scene(); scene.background = new THREE.Color(0x0b1c2c); scene.fog = new THREE.FogExp2(0x122536, .015);
      camera = new THREE.PerspectiveCamera(68, 1, .08, 160);
      renderer = new THREE.WebGLRenderer({ antialias: !mobile.matches && !reduceMotion.matches, powerPreference: 'high-performance', alpha: false, stencil: false });
      // Detect software-only WebGL and prefer low-cost lighting/resolution. Gameplay stays fully interactive.
      const gl = renderer.getContext();
      const debugGL = gl.getExtension('WEBGL_debug_renderer_info');
      const glName = String(debugGL ? gl.getParameter(debugGL.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER) || '').toLowerCase();
      world.softwareGL = /swiftshader|llvmpipe|software|softpipe|lavapipe|basic render driver|warp|virtualbox|vmware svga/.test(glName);
      renderer.outputColorSpace = THREE.SRGBColorSpace;
      renderer.toneMapping = THREE.ACESFilmicToneMapping;
      renderer.toneMappingExposure = 1.42;
      renderer.shadowMap.enabled = !mobile.matches && !reduceMotion.matches;
      renderer.shadowMap.type = THREE.PCFSoftShadowMap;
      renderer.domElement.className = 'oc-render';
      renderer.domElement.setAttribute('aria-label', 'Живой 3D-мир. Иди клавишами WASD и вращай камеру мышью.');
      viewport.prepend(renderer.domElement);
      hemi = new THREE.HemisphereLight(0xb2e6ff, 0x6e443f, 2.25); scene.add(hemi);
      const key = new THREE.DirectionalLight(0xffcda3, 2.45); key.position.set(-10, 18, 6);
      key.castShadow = !mobile.matches && !reduceMotion.matches; key.shadow.mapSize.set(1024, 1024); keyLight = key;
      key.shadow.camera.left = key.shadow.camera.bottom = -12;
      key.shadow.camera.right = key.shadow.camera.top = 12;
      key.shadow.normalBias = .065; scene.add(key);
      blueFill = new THREE.DirectionalLight(0x2e9fca, .9); blueFill.position.set(9, 7, -8); scene.add(blueFill);
      const plazaLight = new THREE.PointLight(0x43c9dd, 9, 9); plazaLight.position.set(0, 4, .7); scene.add(plazaLight);
      addAtmosphere(); addGround(); addCity();
      // Detail kit is optional when a legacy browser cache loads; the puzzle remains playable.
      try {
        if (window.ZION030_DETAIL_KIT) detailKit = window.ZION030_DETAIL_KIT.install({
          THREE, scene, rules, softwareGL: world.softwareGL,
          reducedMotion: reduceMotion.matches, mobile: mobile.matches
        });
      } catch (error) { console.warn('ZION-030 high-detail asset fallback', error); }
      try {
        if (window.ZION030_CINEMATIC_KIT) cinematicKit = window.ZION030_CINEMATIC_KIT.install({
          THREE, scene, rules, detailKit, softwareGL: world.softwareGL,
          reducedMotion: reduceMotion.matches, mobile: mobile.matches
        });
      } catch (error) { console.warn('ZION-030 cinematic material fallback', error); }
      try {
        if (window.ZION030_LANDMARK_KIT) landmarkKit = window.ZION030_LANDMARK_KIT.install({
          THREE, scene, rules, softwareGL: world.softwareGL,
          reducedMotion: reduceMotion.matches, mobile: mobile.matches
        });
      } catch (error) { console.warn('ZION-030 landmark asset fallback', error); }
      try {
        if (window.ZION030_STREET_ATELIER) streetKit = window.ZION030_STREET_ATELIER.install({
          THREE, scene, rules, softwareGL: world.softwareGL,
          reducedMotion: reduceMotion.matches, mobile: mobile.matches
        });
      } catch (error) { console.warn('ZION-030 street-level asset fallback', error); }
      try {
        if (window.ZION030_ATELIER_PBR) atelierKit = window.ZION030_ATELIER_PBR.install({
          THREE, scene, rules, softwareGL: world.softwareGL,
          reducedMotion: reduceMotion.matches, mobile: mobile.matches
        });
      } catch (error) { console.warn('ZION-030 PBR surface fallback', error); }
      try {
        if (window.ZION030_POSTFX) postFxKit = window.ZION030_POSTFX.create({
          THREE, renderer, scene, camera, softwareGL: world.softwareGL,
          reducedMotion: reduceMotion.matches, mobile: mobile.matches
        });
      } catch (error) { console.warn('ZION-030 postFX fallback', error); }
      try {
        if (window.ZION030_HARDWARE_PERF) perfKit = window.ZION030_HARDWARE_PERF.create({
          THREE, renderer, scene, shell, softwareGL: world.softwareGL, mobile: mobile.matches
        });
      } catch (error) { console.warn('ZION-030 hardware profiler unavailable', error); }
      try {
        if (window.ZION030_COOLING_FX) coolingKit = window.ZION030_COOLING_FX.install({
          THREE, scene, softwareGL: world.softwareGL,
          reducedMotion: reduceMotion.matches, mobile: mobile.matches
        });
      } catch (error) { console.warn('ZION-030 microclimate transformation fallback', error); }
      try {if(window.ZION030_SURFACES35)surfaceKit=window.ZION030_SURFACES35.install({THREE,scene,rules,softwareGL:world.softwareGL,reducedMotion:reduceMotion.matches,mobile:mobile.matches});}
      catch(error){console.warn('ZION-030 v35 street material fallback',error);}
      try {if(window.ZION030_CIVIC36)civicKit=window.ZION030_CIVIC36.install({THREE,scene,rules,softwareGL:world.softwareGL,reducedMotion:reduceMotion.matches,mobile:mobile.matches});}
      catch(error){console.warn('ZION-030 v36 civic architecture fallback',error);}
      makeHotMarkers(); makeAvatar(); addLivingWorld();
      // Install v37 after the real car/avatar/lighting and all facade meshes exist.
      try {
        if(window.ZION030_PHOTOREAL37)photorealKit=window.ZION030_PHOTOREAL37.install({
          THREE,scene,renderer,rules,car:world.car,avatar,keyLight,hemi,blueFill,
          softwareGL:world.softwareGL,reducedMotion:reduceMotion.matches,mobile:mobile.matches
        });
      }catch(error){console.warn('ZION-030 v37 physically based visual fallback',error);}
      try{
        if(window.ZION030_NATURE38)natureKit=window.ZION030_NATURE38.install({
          THREE,scene,rules,foliage:world.foliage,mobile:mobile.matches,
          softwareGL:world.softwareGL,reducedMotion:reduceMotion.matches
        });
      }catch(error){console.warn('ZION-030 v38 environment fallback',error);}
      updateAtmosphere();
      minimapCtx = $('oc-minimap').getContext('2d');
      world.gpuScale = reduceMotion.matches ? .34 : world.softwareGL ? .4 : mobile.matches ? 1.05 : 1.35;
      if (reduceMotion.matches || world.softwareGL) { world.quality = 'adaptive'; $('oc-quality').textContent = '◈ AUTO'; }
      else if (detailKit?.stats.tier === 'ULTRA') $('oc-quality').textContent = '◈ ULTRA';
      detailKit?.setQuality(world.quality);
      cinematicKit?.setQuality(world.quality);
    landmarkKit?.setQuality(world.quality);
    streetKit?.setQuality(world.quality);
    atelierKit?.setQuality(world.quality);
    surfaceKit?.setQuality(world.quality);
      civicKit?.setQuality(world.quality);
      photorealKit?.setQuality(world.quality);
      natureKit?.setQuality(world.quality);
    coolingKit?.setQuality(world.quality);
    postFxKit?.setQuality(world.quality);
      world.ready = true; resize(); syncGame(); drawMiniMap();
      atelierKit?.setQuality(world.quality);
    surfaceKit?.setQuality(world.quality);
      civicKit?.setQuality(world.quality);
      photorealKit?.setQuality(world.quality);
      natureKit?.setQuality(world.quality);
    coolingKit?.setQuality(world.quality);
      postFxKit?.setQuality(world.quality);
      coolingKit?.setQuality(world.quality);
      // Read-only diagnostics and an explicit, opt-in benchmark controller.
      window.__ZION030_PERFORMANCE__=perfKit||null;
      window.__ZION030_OPEN_CITY__ = {
        state: () => ({ ready: world.ready, active: world.active, player: { x: player.x, z: player.z, stamina:player.stamina, height:player.height, cameraMode:player.cameraMode }, mission: game()?.state(), quality: world.quality, driving: Boolean(world.car?.occupied), vehicle: world.car ? { x: world.car.x, z: world.car.z, speed: world.car.speed, battery: world.car.battery } : null, contracts: [...profile.completed], credits: profile.credits, raining: world.raining, dayMode: world.dayMode, dispatch:{done:[...profile.dispatchDone],steps:{...profile.dispatchSteps},active:profile.activeDispatch}, garage:{speed:profile.fastCar,grip:profile.grip,battery:profile.batteryUpgrade}, district:rules.districtAt(player.x,player.z), detail: detailKit?.stats ?? null, cinematic: cinematicKit?.stats ?? null, landmarks: landmarkKit?.stats ?? null, street: streetKit?.stats ?? null, atelier: atelierKit?.stats ?? null, surfaces:surfaceKit?.stats ?? null, civic:civicKit?.stats ?? null, photoreal:photorealKit?.stats ?? null, nature:natureKit?.stats ?? null, postfx: postFxKit?.stats ?? null, coolingFx: coolingKit?.stats ?? null, coolingCrownsFaded: world.coolingCrownsFaded||0, cameraOcclusionFallback:Boolean(world.cameraOcclusionFallback), perf: perfKit?.snapshot() ?? null }),
        enter, exit, walk: (dx, dz) => { if (!collides(player.x + dx, player.z + dz)) { player.x += dx; player.z += dz; } },
        drive: toggleCar, time: cycleTime, rain: toggleRain, quality: toggleQuality, gps: toggleNavigation, contract: completeNearbyContract,
        interact, camera:cycleCamera, journal:showJournal, pause:pauseGame, resume:resumeGame, dispatch:advanceNearbyDispatch
      };
      // Diagnostics exist only under the explicitly opted-in ?test=1 route.
      if (new URLSearchParams(location.search).has('test')) {
        // Freeze only the test-only animation loop before screenshot evidence:
        // no synthetic pixels, no interruption of real gameplay state.
        window.__ZION030_OPEN_CITY__.freezeForCapture = () => {
          if(animationId)window.cancelAnimationFrame(animationId);
          animationId=0;return true;
        };
        window.__ZION030_OPEN_CITY__.resumeAfterCapture = () => {
          if(world.active&&!animationId){
            world.last=0;animationId=window.requestAnimationFrame(frame);
          }
          return Boolean(animationId);
        };
        window.__ZION030_OPEN_CITY__.teleport = (x, z) => {
          if (world.car?.occupied) { world.car.occupied = false; world.car.speed = 0; avatar.visible = true; }
          const safe = rules.nearestFree(x, z);
          player.x=safe.x;player.z=safe.z;player.vx=player.vz=0;player.height=player.vy=0;
          avatar.position.set(player.x, 0, player.z); syncGame(); drawMiniMap();
          return { x: player.x, z: player.z };
        };
      }
      button.disabled = false;
    } catch (err) {
      console.error('ZION-030 Open City WebGL startup failed', err);
      world.ready = false;
      button.disabled = true; button.textContent = '3D-ГОРОД НЕДОСТУПЕН · КАРТА РАБОТАЕТ';
      shell.hidden = true;
    }
  }
  function resize() {
    if (!world.ready) return;
    const w = Math.max(1, viewport.clientWidth), h = Math.max(1, viewport.clientHeight);
    const cap = world.quality === 'eco' ? Math.min(.55, world.gpuScale) : reduceMotion.matches ? Math.min(.34, world.gpuScale) : world.softwareGL ? Math.min(.4, world.gpuScale) : mobile.matches ? Math.min(1.05, world.gpuScale) : world.gpuScale;
    const dpr = Math.min(window.devicePixelRatio || 1, cap);
    renderer.setPixelRatio(dpr); renderer.setSize(w, h, false); camera.aspect = w / h; camera.updateProjectionMatrix();
    postFxKit?.resize();
  }
  function closest() {
    const s = game().state();
    const uncovered = HOT.map((p, i) => ({ ...p, i, dist: Math.hypot(player.x - p.x, player.z - p.z) }))
      .filter(h => !s.placed.some(m => Math.hypot(m.x - h.x, m.z - h.z) <= 1.35)).sort((a, b) => a.dist - b.dist);
    return uncovered[0] || null;
  }
  function syncGame() {
    if (!world.ready) return;
    const state = game().state();
    coolingKit?.syncProgress(state.placed);
    $('oc-score').textContent = `${state.score} / 3 ЗОНЫ`;
    $('oc-remaining').textContent = `${Math.max(0, 3 - state.placed.length)} МОДУЛЯ`;
    $('oc-progress-bar').style.width = `${state.score / 3 * 100}%`;
    for (const record of world.rings) {
      const h = HOT[record.i];
      const placement = state.placed.find(m => Math.hypot(m.x - h.x, m.z - h.z) <= 1.35);
      const cooled = Boolean(placement);
      if (cooled !== record.cooled) {
        record.cooled = cooled;
        if (cooled && placement) record.prop = createCoolingProp(placement.type, placement.x, placement.z);
        else if (record.prop) { scene.remove(record.prop); record.prop = null; }
        record.ring.material.color.setHex(cooled ? 0x57e6bd : 0xff763b);
        record.inner.material.color.setHex(cooled ? 0x95ffe0 : 0xffd3a1);
        record.tip.material.color.setHex(cooled ? 0x65e9cf : 0xff7848);
        record.beacon.material.color.setHex(cooled ? 0x65e9cf : 0xffab65);
        record.disc.material.color.setHex(cooled ? 0x20e6bd : 0xff5b35);
      }
    }
    for (const marker of world.contractMarkers) {
      const done = profile.completed.includes(marker.contract.id);
      marker.halo.material.color.setHex(done ? 0x4cffc5 : 0x43edff);
      marker.orb.material.color.setHex(done ? 0x4cffb8 : 0x52efff);
    }
    shell.querySelectorAll('[data-oc-tool]').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.ocTool === state.selected)));
    if (state.won && !$('oc-complete').dataset.dismissed) $('oc-complete').hidden = false;
    if (!state.won) { $('oc-complete').hidden = true; delete $('oc-complete').dataset.dismissed; }
    $('oc-contract-count').textContent = `${profile.completed.length} / ${CONTRACTS.length}`;
    $('oc-credit').textContent = String(profile.credits);
    $('oc-reputation').textContent = String(profile.reputation);
    $('oc-upgrade').disabled = profile.credits < 300 || profile.fastCar;
    $('oc-upgrade').textContent = profile.fastCar ? '✓ CITY RUNNER · ДВИГАТЕЛЬ УЛУЧШЕН' : 'УЛУЧШИТЬ ЭЛЕКТРОМОБИЛЬ · 300 ◈';
    const contract = nearestContract();
    $('oc-contract-title').textContent = contract ? contract.name : 'Все городские контракты выполнены!';
    $('oc-contract-hint').textContent = contract ? `Ищи голубой маяк. ${Math.round(contract.dist * 12)} м до точки · +${contract.reward} кредитов` : 'Район восстановлен. Продолжай исследование и охлаждение.';
    const c = world.car;
    $('oc-drive-hud').hidden = !c?.occupied;
    if(c?.occupied)$('oc-speed').innerHTML=`${Math.round(Math.abs(c.speed)*12)} <small>км/ч</small>`;
    const dest = closest();
    targetIndex = dest?.i ?? -1;
    const navGoal=navigationGoal();
    $('oc-target').textContent = navGoal ? (navGoal.text || navGoal.short || navGoal.name || '').toUpperCase() : 'МИССИИ ВЫПОЛНЕНЫ';
    $('oc-nav-mode').textContent = world.navMode==='dispatch'?'⌖ GPS: МИССИИ':world.navMode === 'contract' ? '⌖ GPS: КОНТРАКТЫ' : '⌖ GPS: СЮЖЕТ';
    $('oc-nav-mobile').textContent = $('oc-nav-mode').textContent;
    $('oc-distance').textContent = navGoal ? `${Math.round(Math.hypot(player.x - navGoal.x, player.z - navGoal.z) * 12)} М ДО ЦЕЛИ` : 'Весь город открыт для прогулки';
    const nearHeat = dest && dest.dist <= 1.65 && !state.lost && !state.won && !c?.occupied;
    const nearSide = contract && contract.dist <= 1.7 && !c?.occupied;
    const nearCar = !c?.occupied && distanceToCar() <= 1.65;
    const dispatch=getDispatch(),nearDispatch=dispatch&&Math.hypot(player.x-dispatch.x,player.z-dispatch.z)<1.65;
    const canInteract=Boolean(nearHeat||nearSide||nearDispatch);
    $('oc-interact').hidden = !canInteract && !nearCar && !c?.occupied;
    $('oc-action').hidden = !canInteract || !mobile.matches;
    $('oc-action').textContent = nearHeat ? '✓ ОХЛАДИТЬ' : nearSide?'✓ КОНТРАКТ':'✓ ЭТАП МИССИИ';
    $('oc-interact-key').textContent = canInteract?'E':'F';
    $('oc-interact-text').textContent=nearHeat?'ОХЛАДИТЬ':nearSide?'ГОРОДСКОЙ КОНТРАКТ':nearDispatch?'ЭТАП МИССИИ':c?.occupied?'ВЫЙТИ ИЗ АВТО':'СЕСТЬ В АВТО';
    const driveButton = $('oc-drive-action');
    driveButton.hidden = !mobile.matches || (!c?.occupied && !nearCar);
    driveButton.textContent = c?.occupied ? '↩ ВЫЙТИ ИЗ АВТО' : '🚘 СЕСТЬ В МАШИНУ';
    if (state.lost) { $('oc-target').textContent = 'МОДУЛИ ЗАКОНЧИЛИСЬ'; $('oc-distance').textContent = 'На карте нажми «Заново»'; }
    $('oc-dispatch-counter').textContent=profile.dispatchDone.length+' / '+DISPATCHES.length;
    $('oc-stamina-text').textContent=Math.round(player.stamina)+'%';
    $('oc-stamina-bar').style.width=player.stamina+'%';
    const charge=c?.battery??100;
    $('oc-battery-readout').textContent=Math.ceil(charge)+'%';
    $('oc-battery-bar').style.width=charge+'%';
    $('oc-vehicle-charge').hidden=!c?.occupied;
    const district=rules.districtAt(player.x,player.z);
    $('oc-district-name').textContent=district;
    if(lastDistrict && district!==lastDistrict)radio(district);
    lastDistrict=district;

  }
  function navigationGoal() {
    const dispatch=getDispatch(),side=nearestContract(),heat=closest();
    if(world.navMode==='dispatch')return dispatch || side || heat;
    if(world.navMode==='contract')return side || dispatch || heat;
    return heat || dispatch || side;
  }
  function drawMiniMap() {
    const g = minimapCtx; if (!g) return;
    const w = 230, h = 230, tile = 13, radius = 8.7;
    const centerX = player.x, centerZ = player.z;
    const point = (x, z) => ({ x: w / 2 + (x - centerX) * tile, y: h / 2 + (z - centerZ) * tile });
    g.clearRect(0, 0, w, h);
    const bg = g.createLinearGradient(0, 0, w, h); bg.addColorStop(0, '#082335'); bg.addColorStop(1, '#04131f');
    g.fillStyle = bg; g.fillRect(0, 0, w, h);
    for (let x = Math.floor(centerX - radius); x <= Math.ceil(centerX + radius); x++) {
      for (let z = Math.floor(centerZ - radius); z <= Math.ceil(centerZ + radius); z++) {
        const p = point(x, z);
        g.fillStyle = occupied.has(`${x},${z}`) ? '#446072' : (Math.abs(x) <= 2 && Math.abs(z) <= 2 ? '#245868' : '#18374a');
        g.fillRect(p.x - tile / 2 + .5, p.y - tile / 2 + .5, tile - 1, tile - 1);
      }
    }
    const goal=navigationGoal();
    const destination = goal ? goal.x + ',' + goal.z : '';
    const origin = Math.round(centerX) + ',' + Math.round(centerZ);
    if (destination !== world.routeTo || origin !== world.pathCell) {
      world.routeTo = destination; world.pathCell = origin;
      world.path = goal ? rules.route({ x: centerX, z: centerZ }, goal) : [];
    }
    if (world.path.length > 1) {
      g.beginPath();
      world.path.forEach((step, i) => { const p = point(step.x, step.z); i ? g.lineTo(p.x, p.y) : g.moveTo(p.x, p.y); });
      g.strokeStyle = 'rgba(86,233,242,.76)'; g.lineWidth = 2.4; g.stroke();
    }
    function blip(x, z, fill, size = 5) {
      const p = point(x, z), px = rules.clamp(p.x, 9, w - 9), py = rules.clamp(p.y, 9, h - 9);
      g.beginPath(); g.arc(px, py, size, 0, Math.PI * 2); g.fillStyle = fill; g.fill();
      g.lineWidth = 1.5; g.strokeStyle = '#edfaff'; g.stroke();
    }
    const state = game()?.state();
    for (const item of HOT) {
      const cooled = state?.placed.some(m => Math.hypot(m.x - item.x, m.z - item.z) <= 1.35);
      blip(item.x, item.z, cooled ? '#58ffd2' : '#ff784c', 5.5);
    }
    for (const q of CONTRACTS) blip(q.x, q.z, profile.completed.includes(q.id) ? '#65bc97' : '#4ee5ff', 4.5);
    const step=getDispatch();if(step)blip(step.x,step.z,'#ffde9c',6.0);
    for(const dock of rules.CHARGERS)blip(dock.x,dock.z,'#7dffd0',2.7);
    for (const t of world.traffic) blip(t.mesh.position.x, t.mesh.position.z, '#7b9aa9', 2);
    if (world.car && !world.car.occupied) blip(world.car.x, world.car.z, '#f3d989', 4);
    g.save(); g.translate(w / 2, h / 2); g.rotate(player.yaw);
    g.beginPath(); g.moveTo(0, -10); g.lineTo(7, 7); g.lineTo(0, 4); g.lineTo(-7, 7); g.closePath();
    g.fillStyle = '#f2ffff'; g.shadowBlur = 10; g.shadowColor = '#60deef'; g.fill(); g.restore();
    g.fillStyle = '#a5ced9'; g.font = 'bold 12px system-ui'; g.fillText('N ↑', 10, 18);
    g.strokeStyle = '#6edbdc75'; g.lineWidth = 1; g.strokeRect(.5, .5, w - 1, h - 1);
  }
  function soundSuccess() {
    try {
      const Ctx = window.AudioContext || window.webkitAudioContext;
      if (!Ctx) return; audio ||= new Ctx(); if (audio.state === 'suspended') audio.resume();
      [392, 523, 659].forEach((hz, i) => {
        const o = audio.createOscillator(), g = audio.createGain(), t = audio.currentTime + i * .085;
        o.type = 'sine'; o.frequency.value = hz; g.gain.setValueAtTime(.0001, t); g.gain.exponentialRampToValueAtTime(.065, t + .02); g.gain.exponentialRampToValueAtTime(.0001, t + .25);
        o.connect(g); g.connect(audio.destination); o.start(t); o.stop(t + .28);
      });
    } catch (_err) { /* Browsers may block audio: gameplay remains unaffected. */ }
  }
  function interact() {
    if (!world.active || !world.ready || !game()?.state()?.ready || modalOpen()) return false;
    const state = game().state(), dest = closest();
    if (world.car?.occupied) { if(advanceNearbyDispatch())return true;announce('\u0412\u044b\u0439\u0434\u0438 \u0438\u0437 \u043c\u0430\u0448\u0438\u043d\u044b \u0438\u043b\u0438 \u0437\u0430\u043f\u0430\u0440\u043a\u0443\u0439 \u0430\u0432\u0442\u043e'); return false; }
    if (dest && dest.dist <= 1.65 && !state.won && !state.lost) {
      const ok = game().place(dest.x, dest.z, state.selected);
      if (ok) { soundSuccess(); syncGame(); drawMiniMap(); announce(`✓ ${dest.name}: ЗОНА ОХЛАЖДЕНА`); return true; }
    }
    if (completeNearbyContract()) return true;
    if(advanceNearbyDispatch())return true;
    if (distanceToCar() <= 1.65) { announce('Нажми F, чтобы сесть в электромобиль'); return false; }
    announce('Подойди к оранжевой цели или голубому маяку задания.');
    return false;
  }
  function move(dt, t) {
    const c=world.car;
    let xx=((keys.has('KeyD')||keys.has('ArrowRight'))?1:0)-((keys.has('KeyA')||keys.has('ArrowLeft'))?1:0)+joystick.x;
    let yy=((keys.has('KeyW')||keys.has('ArrowUp'))?1:0)-((keys.has('KeyS')||keys.has('ArrowDown'))?1:0)-joystick.y;
    const magnitude=Math.hypot(xx,yy);if(magnitude>1){xx/=magnitude;yy/=magnitude;}
    if(c?.occupied){
      const powered=c.battery>.1;
      const control={throttle:powered?yy:Math.min(0,yy),steer:xx,brake:keys.has('Space')};
      const result=rules.drivingStep(c,control,dt,profile.fastCar,{rain:world.raining,grip:profile.grip});
      const trafficBlock=world.traffic.some(other=>Math.hypot(result.x-other.mesh.position.x,result.z-other.mesh.position.z)<.83);
      if(trafficBlock){result.x=c.x;result.z=c.z;result.speed=0;result.collision=true;}
      Object.assign(c,result);
      const nearStation=rules.CHARGERS.some(q=>Math.hypot(q.x-c.x,q.z-c.z)<1.7);
      c.battery=rules.vehicleEnergy(c.battery,c,control,dt,profile.batteryUpgrade,nearStation);
      c.mesh.position.set(c.x,.02,c.z);c.mesh.rotation.y=c.heading;
      player.x=c.x;player.z=c.z;player.yaw=c.heading;
      let delta=c.heading-player.cameraYaw;
      while(delta>Math.PI)delta-=Math.PI*2;
      while(delta< -Math.PI)delta+=Math.PI*2;
      player.cameraYaw+=delta*(1-Math.exp(-dt*2.9));
      if(result.collision&&Math.abs(yy)>.1&&t-(world.lastCollisionToast||0)>1.25){world.lastCollisionToast=t;announce('\u041f\u0440\u0435\u043f\u044f\u0442\u0441\u0442\u0432\u0438\u0435 · \u0441\u0434\u0430\u0439 \u043d\u0430\u0437\u0430\u0434',900);}
      if(!powered&&!nearStation&&t-(world.lastEnergyToast||0)>7){world.lastEnergyToast=t;radio('\u0411\u0430\u0442\u0430\u0440\u0435\u044f \u043f\u0443\u0441\u0442\u0430. \u0421\u0442\u0430\u043d\u0446\u0438\u044f \u0437\u0430\u0440\u044f\u0434\u043a\u0438 \u043e\u0442\u043c\u0435\u0447\u0435\u043d\u0430 \u0437\u0435\u043b\u0451\u043d\u044b\u043c.');}
    } else {
      const fwdX=-Math.sin(player.cameraYaw),fwdZ=-Math.cos(player.cameraYaw);
      const strafeX=Math.cos(player.cameraYaw),strafeZ=-Math.sin(player.cameraYaw);
      const step=rules.walkStep(player,{x:fwdX*yy+strafeX*xx,z:fwdZ*yy+strafeZ*xx,
        sprint:keys.has('ShiftLeft')||keys.has('ShiftRight'),jump:world.jumpQueued},dt,collides);
      world.jumpQueued=false;
      Object.assign(player,step);
      player.moving=magnitude>.12;
      player.speed=Math.min(1,step.speed/2.85);
      if(step.speed>.12)player.yaw=Math.atan2(player.vx,-player.vz);
      const stride=reduceMotion.matches?0:Math.sin(t*(step.sprinting?12:8))*player.speed;
      legL.rotation.x=stride*.47;legR.rotation.x=-stride*.47;
      armL.rotation.x=-stride*.36;armR.rotation.x=stride*.36;
      avatar.position.set(player.x,player.height+(reduceMotion.matches?0:Math.abs(Math.sin(t*8))*.023*player.speed),player.z);
      avatar.rotation.y=player.yaw;
      avatar.visible=player.cameraMode!=='first';
    }
    const eyeHeight=c?.occupied?1.17:1.65+player.height;
    if(player.cameraMode==='first'){
      world.cameraOcclusionFallback=false;
      camera.position.set(player.x,eyeHeight,player.z);
      camera.lookAt(player.x-Math.sin(player.cameraYaw)*13,
        eyeHeight-Math.tan(player.pitch-.25)*13,player.z-Math.cos(player.cameraYaw)*13);
    }else{
      let distance=c?.occupied?6.5:player.cameraMode==='near'?2.55:mobile.matches?5.2:4.65;
      const pitch=c?.occupied?Math.max(.32,player.pitch):player.pitch;
      for(let d=.6;d<=distance;d+=.27){
        const tx=player.x+Math.sin(player.cameraYaw)*Math.cos(pitch)*d;
        const tz=player.z+Math.cos(player.cameraYaw)*Math.cos(pitch)*d;
        if(collides(tx,tz,.12)){distance=Math.max(.7,d-.35);break;}
      }
      // In narrow lanes, a 0.7m chase arm produces a close-up of the
      // character's head rather than the city. Seamlessly prefer a forward
      // first-person viewpoint until there is room behind the player again.
      if(distance<1.45){
        world.cameraOcclusionFallback=true;
        avatar.visible=false;
        const eye=c?.occupied?1.36:1.65+player.height;
        camera.position.set(player.x,eye,player.z);
        camera.lookAt(player.x-Math.sin(player.cameraYaw)*13,
          eye-Math.tan(player.pitch-.25)*13,
          player.z-Math.cos(player.cameraYaw)*13);
      }else{
        world.cameraOcclusionFallback=false;
        avatar.visible=player.cameraMode!=='first';
        const lookHeight=c?.occupied?.9:1.2+player.height;
        const desired=new THREE.Vector3(player.x+Math.sin(player.cameraYaw)*Math.cos(pitch)*distance,
          lookHeight+Math.sin(pitch)*distance,player.z+Math.cos(player.cameraYaw)*Math.cos(pitch)*distance);
        if(collides(desired.x,desired.z,.16))desired.set(player.x,lookHeight+.65,player.z);
        camera.position.lerp(desired,1-Math.exp(-dt*9));
        if(collides(camera.position.x,camera.position.z,.16))camera.position.copy(desired);
        camera.lookAt(player.x,lookHeight,player.z);
      }
    }
    updateCoolingCrownOcclusion(dt);
    const desiredFov=player.cameraMode==='first'?64:c?.occupied?74:player.moving&&player.stamina<99?72:68;
    const fov= camera.fov+(desiredFov-camera.fov)*(1-Math.exp(-dt*4));
    if(Math.abs(fov-camera.fov)>.025){camera.fov=fov;camera.updateProjectionMatrix();}
    updateTraffic(dt);updatePedestrians(dt,t);updateRain(dt);
    streetKit?.update(dt);
    atelierKit?.update(dt);
    surfaceKit?.update(dt);
    civicKit?.update(dt);
    photorealKit?.update(dt);
    natureKit?.update(dt);
    coolingKit?.update(dt);
    world.rings.forEach((r,i)=>{
      const phase=reduceMotion.matches?0:t*2.2+i;
      r.ring.scale.setScalar(1+Math.sin(phase)*.06);
      r.tip.scale.setScalar(1.35+Math.sin(phase)*.18);
      r.beacon.rotation.y=t;
      r.beacon.position.y=1.83+(reduceMotion.matches?0:Math.sin(t*2.4+i)*.09);
    });
    world.contractMarkers.forEach((marker,i)=>{
      marker.orb.scale.setScalar(1.3+(reduceMotion.matches?0:Math.sin(t*1.6+i)*.15));
    });
    world.dispatchMarkers.forEach((marker,i)=>{
      marker.tag.rotation.y=t*.7;
      marker.tag.position.y=2.6+(reduceMotion.matches?0:Math.sin(t*1.8+i)*.18);
    });
  }
  function frame(time) {
    if (!world.active || !world.ready) return;
    // Photo textures begin only after the player enters the interactive city.
    // This prevents six CDN downloads from competing with initial page load.
    if (!world.photoMaterialsRequested) { world.photoMaterialsRequested = true; photorealKit?.activate?.(); }
    const dt = clamp((time - (world.last || time)) / 1000, 0, .06); world.last = time; world.frame++;
    if(!modalOpen())move(dt,time*.001);else world.jumpQueued=false;
    if (world.frame % 9 === 0) { syncGame(); drawMiniMap(); }
    if (world.frame % 70 === 0 && !world.softwareGL && !reduceMotion.matches) {
      if (world.fpsTime) {
        const fps = ((world.renderedFrameCount||0) - (world.fpsFrames||0)) * 1000 / (time - world.fpsTime);
        if (fps < (mobile.matches ? 16 : 28) && world.gpuScale > .36) {
          world.gpuScale = Math.max(.36, world.gpuScale * .78);
          world.quality = 'adaptive';
          // LOD downgrade must affect the entire city, not just the new art layer.
          detailKit?.setQuality('adaptive');
          cinematicKit?.setQuality('adaptive');
          landmarkKit?.setQuality('adaptive');
          streetKit?.setQuality('adaptive');
          atelierKit?.setQuality('adaptive');
          surfaceKit?.setQuality('adaptive');
          civicKit?.setQuality('adaptive');
          photorealKit?.setQuality('adaptive');
          natureKit?.setQuality('adaptive');
          coolingKit?.setQuality('adaptive');
          postFxKit?.setQuality('adaptive');
          resize();
        }
      }
      world.fpsTime = time; world.fpsFrames = world.renderedFrameCount||0;
    }
    // Reduced-motion mode keeps gameplay responsive on software WebGL; render at a bounded cadence.
    const renderEvery = reduceMotion.matches || world.softwareGL ? 500 : mobile.matches ? 50 : 16;
    if (!world.lastRender || time - world.lastRender >= renderEvery) {
      world.lastRender = time;
      world.renderedFrameCount=(world.renderedFrameCount||0)+1;
      const frameMark=perfKit?.beginRender() ?? null;
      try { if(postFxKit)postFxKit.render(time*.001); else renderer.render(scene,camera); }
      finally {perfKit?.endRender(frameMark);}
    }
    animationId = window.requestAnimationFrame(frame);
  }
  function enter() {
    if (!world.ready || !game()?.state()?.ready) {
      button.textContent = '◌ ЗАГРУЖАЕТСЯ 3D-ГОРОД…';
      window.setTimeout(() => { if (world.ready) button.textContent = '◈ ГУЛЯТЬ ПО ГОРОДУ · 3D'; }, 900);
      return;
    }
    world.active = true;
    stage.classList.add('oc-stage-active');
    document.body.classList.add('oc-body-active');
    shell.hidden = false;
    $('oc-start').hidden = false;
    button.textContent = '← ВЕРНУТЬСЯ НА КАРТУ';
    world.last=0; keys.clear(); lastDistrict='';
    syncGame(); updateJournal(); resize(); drawMiniMap();
    if (animationId) window.cancelAnimationFrame(animationId);
    // The scene is paused behind the start overlay so the Start button never competes with a heavy WebGL frame.
    animationId = 0;
    $('oc-start-play').focus({ preventScroll: true });
  }
  function exit() {
    world.active = false;world.last=0;keys.clear();world.jumpQueued=false;joystick.x=joystick.y=0;$('oc-pause').hidden=true;$('oc-journal').hidden=true;
    if (world.car?.occupied) {world.car.occupied=false;world.car.speed=0;avatar.visible=player.cameraMode!=='first';player.x=world.car.x;player.z=world.car.z;}
    if (animationId) window.cancelAnimationFrame(animationId); animationId = 0;
    stage.classList.remove('oc-stage-active'); document.body.classList.remove('oc-body-active');
    shell.hidden = true; button.textContent = '◈ ГУЛЯТЬ ПО ГОРОДУ · 3D';
    button.focus({ preventScroll: true });
    if (document.pointerLockElement === renderer?.domElement) document.exitPointerLock?.();
  }
  button.addEventListener('click', () => world.active ? exit() : enter());
  $('oc-exit').addEventListener('click', exit);
  $('oc-start-play').addEventListener('click', () => { $('oc-start').hidden = true; viewport.focus?.(); if (world.active && !animationId) animationId = window.requestAnimationFrame(frame); });
  $('oc-action').addEventListener('click', interact);
  $('oc-drive-action').addEventListener('click', toggleCar);
  $('oc-time').addEventListener('click', cycleTime);
  $('oc-rain').addEventListener('click', toggleRain);
  $('oc-quality').addEventListener('click', toggleQuality);
  $('oc-upgrade').addEventListener('click', buyUpgrade);
  $('oc-nav-mode').addEventListener('click', toggleNavigation);
  $('oc-nav-mobile').addEventListener('click', toggleNavigation);
  $('oc-journal-button').addEventListener('click',showJournal);
  $('oc-journal-close').addEventListener('click',closeJournal);
  $('oc-journal-resume').addEventListener('click',closeJournal);
  $('oc-pause-button').addEventListener('click',pauseGame);
  $('oc-resume').addEventListener('click',resumeGame);
  $('oc-pause-journal').addEventListener('click',showJournal);
  $('oc-exit-to-map').addEventListener('click',exit);
  $('oc-upgrade-speed').addEventListener('click',()=>upgrade('speed'));
  $('oc-upgrade-grip').addEventListener('click',()=>upgrade('grip'));
  $('oc-upgrade-battery').addEventListener('click',()=>upgrade('battery'));
  $('oc-view-button').addEventListener('click',cycleCamera);
  $('oc-jump-button').addEventListener('click',()=>{if(!world.car?.occupied)world.jumpQueued=true;});

  $('oc-complete').addEventListener('click', e => { if (e.target === $('oc-complete')) $('oc-complete').hidden = true; });
  $('oc-keep-walking').addEventListener('click', () => { $('oc-complete').hidden = true; $('oc-complete').dataset.dismissed = 'true'; });
  $('oc-again').addEventListener('click', () => { game()?.reset?.(); $('oc-complete').hidden = true; delete $('oc-complete').dataset.dismissed; syncGame(); drawMiniMap(); });
  shell.querySelectorAll('[data-oc-tool]').forEach(b => b.addEventListener('click', () => { game()?.select(b.dataset.ocTool); syncGame(); }));
  window.addEventListener('keydown', e => {
    if (!world.active || !$('oc-start').hidden || !$('oc-complete').hidden || modalOpen()) return;
    const gameplayCodes = ['KeyW','KeyA','KeyS','KeyD','ArrowUp','ArrowDown','ArrowLeft','ArrowRight','Space','KeyE','KeyF','KeyH','KeyT','KeyP','KeyQ','KeyG','KeyV','KeyJ','KeyM','ShiftLeft','ShiftRight','Digit1','Digit2','Digit3','KeyB'];
    if (gameplayCodes.includes(e.code)) { e.preventDefault(); e.stopImmediatePropagation(); }
    keys.add(e.code);
    if (e.repeat) return;
    if(e.code==='Space'&&!world.car?.occupied)world.jumpQueued=true;
    if (e.code === 'KeyF') toggleCar();
    else if (e.code === 'KeyE' || e.code === 'Enter') interact();
    else if (e.code === 'KeyV') cycleCamera();
    else if (e.code === 'KeyJ') showJournal();
    else if (e.code === 'KeyM') shell.classList.toggle('oc-map-expanded');
    else if (e.code === 'KeyG') toggleNavigation();
    else if (e.code === 'KeyT') cycleTime();
    else if (e.code === 'KeyP') toggleRain();
    else if (e.code === 'KeyQ') toggleQuality();
    else if (e.code === 'KeyH') window.__ZION030_FOCUS_HUD__?.toggle?.();
    else if (e.code === 'KeyB') perfKit?.toggle?.();
    else if (['Digit1', 'Digit2', 'Digit3'].includes(e.code)) game().select(['tree', 'shade', 'water'][Number(e.code.slice(-1)) - 1]);
  }, true);
  window.addEventListener('keyup', e => { keys.delete(e.code); }, true);
  window.addEventListener('keydown',e=>{if(!world.active||e.key!=='Escape')return;e.preventDefault();e.stopImmediatePropagation();if(!$('oc-journal').hidden)closeJournal();else if(!$('oc-pause').hidden)resumeGame();else if(!$('oc-start').hidden){$('oc-start').hidden=true;world.last=0;animationId=window.requestAnimationFrame(frame);}else pauseGame();},true);
  window.addEventListener('blur', () => keys.clear());
  viewport.addEventListener('pointerdown', e => {
    if (!world.active || !$('oc-start').hidden || !$('oc-complete').hidden || modalOpen()) return;
    if (e.target.closest('button')) return;
    if (dragId !== null) return;
    dragId = e.pointerId; dragX = e.clientX; dragY = e.clientY;
    try { viewport.setPointerCapture(e.pointerId); } catch (_err) {}
  });
  viewport.addEventListener('pointermove', e => {
    if (dragId !== e.pointerId || !world.active) return;
    const dx = e.clientX - dragX, dy = e.clientY - dragY;
    dragX = e.clientX; dragY = e.clientY;
    player.cameraYaw -= dx * (mobile.matches ? .006 : .0047);
    player.pitch = clamp(player.pitch + dy * .0034, .05, .85);
  });
  for (const ev of ['pointerup', 'pointercancel', 'lostpointercapture']) viewport.addEventListener(ev, e => { if (dragId === e.pointerId) dragId = null; });
  viewport.addEventListener('wheel', e => { if (world.active) { e.preventDefault(); player.pitch = clamp(player.pitch + e.deltaY * .0003, .07, .72); } }, { passive: false });
  const joy = $('oc-joystick'), stick = $('oc-stick');
  function joyMove(e) {
    const dx = e.clientX - joystick.centerX, dy = e.clientY - joystick.centerY;
    const a = Math.atan2(dy, dx), magnitude = Math.min(1, Math.hypot(dx, dy) / 43);
    joystick.x = Math.cos(a) * magnitude; joystick.y = Math.sin(a) * magnitude;
    stick.style.transform = `translate(${joystick.x * 39}px, ${joystick.y * 39}px)`;
  }
  joy.addEventListener('pointerdown', e => { e.preventDefault(); e.stopPropagation(); joystick.pointer = e.pointerId; const rect = joy.getBoundingClientRect(); joystick.centerX = rect.left + rect.width / 2; joystick.centerY = rect.top + rect.height / 2; joy.setPointerCapture(e.pointerId); joyMove(e); });
  joy.addEventListener('pointermove', e => { if (joystick.pointer === e.pointerId) { e.preventDefault(); joyMove(e); } });
  for (const event of ['pointerup', 'pointercancel', 'lostpointercapture']) joy.addEventListener(event, e => { if (joystick.pointer !== e.pointerId) return; joystick.pointer = null; joystick.x = joystick.y = 0; stick.style.transform = 'translate(0,0)'; });
  window.addEventListener('resize', resize);
  window.addEventListener('zion-three-ready', bootThree, { once: true });
  window.addEventListener('zion-three-failed', () => { button.disabled = true; button.textContent = '3D НЕДОСТУПЕН — ИГРАЙ НА КАРТЕ'; }, { once: true });
  if (window.THREE) bootThree();
})();
