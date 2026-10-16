(function () {
  var page = document.querySelector('.page');
  if (!page || document.querySelector('.empire-map-open')) return;
  var style = document.createElement('style');
  style.textContent = '.empire-map-open{display:block;margin:0 auto 16px;padding:12px 18px;border:1px solid #c5a059;background:rgba(197,160,89,.08);color:#e6c068;font:500 10px JetBrains Mono,monospace;letter-spacing:.16em;text-transform:uppercase;cursor:pointer}.empire-map{position:fixed;inset:0;z-index:80;display:grid;place-items:center;padding:20px;background:rgba(3,3,5,.86);backdrop-filter:blur(14px)}.empire-map[hidden]{display:none}.empire-sheet{position:relative;width:min(720px,100%);max-height:90svh;overflow:auto;padding:30px;border:1px solid rgba(197,160,89,.55);background:linear-gradient(145deg,#15141a,#08080b);box-shadow:0 24px 100px #000}.empire-sheet h2{margin:8px 0;color:#eee8dc;font:300 clamp(36px,7vw,64px)/.85 Cormorant Garamond,serif;letter-spacing:.08em}.empire-sheet p{color:#99949a;font:500 9px/1.7 JetBrains Mono,monospace;letter-spacing:.08em}.empire-close{position:absolute;top:14px;right:16px;border:0;background:none;color:#e6c068;font-size:26px;cursor:pointer}.empire-resources{display:flex;gap:18px;flex-wrap:wrap;margin:22px 0;color:#e6c068;font:500 10px JetBrains Mono,monospace}.empire-districts{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}.empire-district{min-height:100px;padding:14px;text-align:left;border:1px solid rgba(197,160,89,.25);background:rgba(255,255,255,.025);color:#eee8dc;cursor:pointer}.empire-district.is-active{border-color:#e6c068;background:rgba(197,160,89,.13)}.empire-district b{display:block;font:400 22px Cormorant Garamond,serif}.empire-district small{color:#8f8b91;font:500 8px JetBrains Mono,monospace}.empire-event{margin-top:18px;padding:18px;border-left:2px solid #c5a059;background:rgba(197,160,89,.06)}.empire-actions{display:flex;gap:8px;flex-wrap:wrap;margin-top:14px}.empire-actions button{padding:10px 12px;border:1px solid rgba(197,160,89,.55);background:transparent;color:#e6c068;font:500 9px JetBrains Mono,monospace;cursor:pointer}.empire-actions button:hover{background:#c5a059;color:#111}@media(max-width:560px){.empire-districts{grid-template-columns:repeat(2,1fr)}}';
  document.head.appendChild(style);
  var councilStyle = document.createElement('style');
  councilStyle.textContent = '.empire-council{margin-top:24px;padding-top:18px;border-top:1px solid rgba(197,160,89,.2)}.empire-ministers{display:grid;grid-template-columns:repeat(2,1fr);gap:8px;margin:12px 0 22px}.empire-minister{padding:13px;border:1px solid rgba(197,160,89,.2);background:linear-gradient(145deg,rgba(255,255,255,.07),rgba(0,0,0,.2));text-align:left}.empire-minister i{display:grid;place-items:center;width:38px;height:38px;margin-bottom:10px;border:1px solid #c5a059;border-radius:50%;background:radial-gradient(circle at 35% 25%,#e6c068,#15110b 68%);color:#211606;font:500 11px JetBrains Mono,monospace;font-style:normal}.empire-minister b{display:block;color:#eee8dc;font:400 20px Cormorant Garamond,serif}.empire-minister small{display:block;min-height:28px;margin:4px 0 10px;color:#918c91;font:500 8px/1.4 JetBrains Mono,monospace}.empire-minister button,.empire-laws button{border:1px solid rgba(197,160,89,.45);background:transparent;color:#e6c068;padding:8px;font:500 8px JetBrains Mono,monospace;cursor:pointer}.empire-minister button:disabled,.empire-laws button:disabled{opacity:.5}.empire-laws{display:grid;gap:7px}.empire-laws button{display:flex;justify-content:space-between;gap:10px;text-align:left}.empire-laws b{font:400 17px Cormorant Garamond,serif}.empire-laws small{color:#8f8b91;font:500 8px JetBrains Mono,monospace}.empire-laws button.is-passed{border-color:#e6c068;background:rgba(197,160,89,.12)}';
  document.head.appendChild(councilStyle);
  var storyStyle = document.createElement('style');
  storyStyle.textContent = '.empire-story{margin-top:24px;padding:18px;border:1px solid rgba(197,160,89,.28);background:linear-gradient(120deg,rgba(197,160,89,.12),rgba(0,0,0,.22))}.empire-story h3{margin:8px 0;font:400 28px Cormorant Garamond,serif;color:#eee8dc}.empire-story button{padding:10px 12px;border:1px solid #c5a059;background:transparent;color:#e6c068;font:500 9px JetBrains Mono,monospace;cursor:pointer}';
  document.head.appendChild(storyStyle);
  var productionStyle = document.createElement('style');
  productionStyle.textContent = '.empire-production{margin-top:18px;padding:16px;border:1px solid rgba(197,160,89,.3);background:rgba(197,160,89,.07)}.empire-production strong{display:block;color:#eee8dc;font:400 20px Cormorant Garamond,serif}.empire-production button{margin:12px 7px 0 0;padding:10px 12px;border:1px solid #c5a059;background:transparent;color:#e6c068;font:500 9px JetBrains Mono,monospace;cursor:pointer}.empire-refinery-level{display:block;margin-top:9px;color:#8f8b91;font:500 8px JetBrains Mono,monospace}';
  document.head.appendChild(productionStyle);
  var dealStyle = document.createElement('style');
  dealStyle.textContent = '.empire-deals{margin-top:18px;padding:16px;border:1px solid rgba(197,160,89,.25);background:rgba(255,255,255,.025)}.empire-deals strong{display:block;color:#eee8dc;font:400 20px Cormorant Garamond,serif}.empire-deals div{display:flex;gap:7px;flex-wrap:wrap;margin-top:12px}.empire-deals button{padding:9px 10px;border:1px solid rgba(197,160,89,.45);background:transparent;color:#e6c068;font:500 8px JetBrains Mono,monospace;cursor:pointer}.empire-deals button:disabled{opacity:.55}';
  document.head.appendChild(dealStyle);
  var ledgerStyle = document.createElement('style');
  ledgerStyle.textContent = '.empire-ledger{margin-top:18px;padding:16px;border-top:1px solid rgba(197,160,89,.25)}.empire-ledger>div{display:grid;gap:6px}.empire-ledger span{display:flex;justify-content:space-between;gap:12px;padding:8px 0;border-bottom:1px solid rgba(255,255,255,.06)}.empire-ledger b{color:#eee8dc;font:400 16px Cormorant Garamond,serif}.empire-ledger small{color:#8f8b91;font:500 8px JetBrains Mono,monospace}';
  document.head.appendChild(ledgerStyle);
  var cityStyle = document.createElement('style');
  cityStyle.textContent = '.empire-city-map{position:relative;display:grid;grid-template-columns:repeat(3,1fr);gap:7px;margin:20px 0;padding:18px;background:linear-gradient(145deg,#11151b,#08090c);border:1px solid rgba(197,160,89,.25);overflow:hidden}.empire-city-map:before{content:"";position:absolute;left:8%;right:8%;top:48%;height:2px;background:linear-gradient(90deg,transparent,#c5a059,transparent);box-shadow:0 0 18px #c5a059}.empire-city-map button{position:relative;z-index:1;min-height:78px;padding:9px;text-align:left;border:1px solid rgba(197,160,89,.22);background:rgba(255,255,255,.035);color:#eee8dc;cursor:pointer}.empire-city-map button:hover{border-color:#e6c068;background:rgba(197,160,89,.14)}.empire-city-map i{display:block;width:20px;height:20px;margin-bottom:7px;border:1px solid #c5a059;background:linear-gradient(135deg,#e6c068,#252016);transform:skewY(-18deg)}.empire-city-map b{display:block;font:400 16px Cormorant Garamond,serif}.empire-city-map small{color:#8f8b91;font:500 7px JetBrains Mono,monospace}@media(max-width:560px){.empire-city-map{grid-template-columns:repeat(2,1fr)}}';
  document.head.appendChild(cityStyle);
  var shareStyle = document.createElement('style');
  shareStyle.textContent = '.empire-share{width:100%;margin-top:18px;padding:13px;border:1px solid #c5a059;background:linear-gradient(100deg,#8a6f3a,#e6c068,#8a6f3a);color:#120d06;font:600 9px JetBrains Mono,monospace;letter-spacing:.12em;text-transform:uppercase;cursor:pointer}';
  document.head.appendChild(shareStyle);
  var dailyStyle = document.createElement('style');
  dailyStyle.textContent = '.empire-daily{margin-top:18px;padding:16px;border:1px solid rgba(230,192,104,.4);background:linear-gradient(110deg,rgba(230,192,104,.13),rgba(0,0,0,.2))}.empire-daily strong{display:block;color:#f0e4c7;font:400 22px Cormorant Garamond,serif}.empire-daily button{margin-top:11px;padding:9px 11px;border:1px solid #c5a059;background:transparent;color:#e6c068;font:500 8px JetBrains Mono,monospace;cursor:pointer}';
  document.head.appendChild(dailyStyle);
  var resetStyle = document.createElement('style');
  resetStyle.textContent = '.empire-reset{display:block;margin:14px auto 0;border:0;background:none;color:#77717a;font:500 8px JetBrains Mono,monospace;letter-spacing:.1em;text-transform:uppercase;cursor:pointer}.empire-reset:hover{color:#e6c068}';
  document.head.appendChild(resetStyle);
  var transferStyle=document.createElement('style'); transferStyle.textContent='.empire-transfer{display:flex;gap:7px;justify-content:center;margin-top:10px}.empire-transfer button{border:0;background:none;color:#807a82;font:500 8px JetBrains Mono,monospace;cursor:pointer}.empire-transfer button:hover{color:#e6c068}'; document.head.appendChild(transferStyle);
  var crisisStyle = document.createElement('style');
  crisisStyle.textContent = '.empire-crisis{margin:16px 0;padding:16px;border:1px solid #8b2e2e;background:linear-gradient(110deg,rgba(139,46,46,.24),rgba(0,0,0,.25))}.empire-crisis strong{display:block;color:#f0d8be;font:400 24px Cormorant Garamond,serif}.empire-crisis span{display:block;margin:6px 0;color:#b8a8a0;font:500 9px/1.5 JetBrains Mono,monospace}.empire-crisis button{margin:8px 7px 0 0;padding:9px 10px;border:1px solid rgba(230,192,104,.5);background:transparent;color:#e6c068;font:500 8px JetBrains Mono,monospace;cursor:pointer}';
  document.head.appendChild(crisisStyle);
  var factionStyle = document.createElement('style');
  factionStyle.textContent = '.empire-factions{margin:18px 0;padding:16px;border:1px solid rgba(197,160,89,.22);background:rgba(255,255,255,.02)}.empire-factions>div{display:grid;gap:9px}.empire-factions span{display:grid;grid-template-columns:100px 1fr;align-items:center;gap:9px}.empire-factions b{color:#d8d1c5;font:400 16px Cormorant Garamond,serif}.empire-factions i{display:block;height:4px;background:#29262a}.empire-factions em{display:block;height:100%;background:linear-gradient(90deg,#8a6f3a,#e6c068);transition:width .4s}';
  document.head.appendChild(factionStyle);
  var button = document.createElement('button'); button.className = 'empire-map-open'; button.textContent = 'Карта города';
  var actions = page.querySelector('.actions'); (actions || page.querySelector('.scene') || page).prepend(button);
  var districts = [['Цитадель','Совет'],['Нефтяной пояс','Консорциум'],['Порт','Докеры'],['Старый рынок','Торговцы'],['Архив','Архивисты'],['Нижний город','Жители']];
  var ministers = [['Лиана Вейл','министр казны','Совет','LV'],['Ориан Кесс','директор добычи','Консорциум','OK'],['Мара Дейн','комиссар портов','Докеры','MD'],['Илар Арх','хранитель архива','Архивисты','IA']];
  var laws = [['Налог на транзит','Казна +30 / доверие -8'],['Открытый контракт','Доверие +14 / влияние -6'],['Закон о тишине','Стабильность +12 / свобода -10']];
  var state = { version: 2, oil: 40, fuel: 12, refinery: 1, treasury: 120, influence: 18, trust: 52, district: 1, chapter: 1, choices: [], factions: { council: 50, consortium: 50, dockers: 50, archivists: 50, citizens: 50 }, lastSeen: Date.now() };
  try { var stored = JSON.parse(localStorage.getItem('osgard-empire-world-v1') || '{}'); Object.assign(state, stored); } catch (e) {}
  state.oil = Number.isFinite(Number(state.oil)) ? Math.max(0, Number(state.oil)) : 40;
  state.treasury = Number.isFinite(Number(state.treasury)) ? Math.max(0, Number(state.treasury)) : 120;
  state.influence = Number.isFinite(Number(state.influence)) ? Number(state.influence) : 18;
  state.trust = Number.isFinite(Number(state.trust)) ? Number(state.trust) : 52;
  state.chapter = Math.max(1, Math.min(4, Number(state.chapter) || 1));
  state.factions = Object.assign({ council: 50, consortium: 50, dockers: 50, archivists: 50, citizens: 50 }, state.factions || {});
  state.version = 2;
  // This release stores progress only in local browser storage; no backend sync is available.
  var elapsed = Math.min(3 * 60 * 60 * 1000, Math.max(0, Date.now() - Number(state.lastSeen || Date.now())));
  var offlineCycles = Math.floor(elapsed / (10 * 60 * 1000));
  if (offlineCycles > 0) { state.oil += offlineCycles * 2; state.treasury += offlineCycles * 4; }
  var crisisTypes = [['Нефтяная авария','На нефтяном поясе остановлена одна скважина.','oil'],['Забастовка докеров','Порт остановлен. Докеры требуют долю от нового контракта.','dockers'],['Утечка архивного времени','Архив потерял один цикл памяти. Архивисты требуют немедленного решения.','archive']];
  var crisis = offlineCycles > 0 ? crisisTypes[Math.floor(Date.now() / 86400000) % crisisTypes.length] : null;
  try { Object.assign(state, JSON.parse(localStorage.getItem('osgard-empire-world-v1') || '{}')); } catch (e) {}
  var map = document.createElement('section'); map.className = 'empire-map'; map.hidden = true;
  map.innerHTML = '<div class="empire-sheet"><button class="empire-close" type="button" aria-label="Закрыть">×</button><p>OSGARD / CITY COMMAND</p><h2>Карта города</h2><p>Каждый район меняет баланс сил. Выберите место, затем примите решение.</p><div class="empire-resources"></div><div class="empire-districts"></div><div class="empire-event"><p>СОБЫТИЕ · ЧЁРНОЕ СОЛНЦЕ</p><strong>Первый нефтяной контракт определит, кто будет управлять городом.</strong><div class="empire-actions"><button type="button" data-choice="consortium">Отдать консорциуму</button><button type="button" data-choice="city">Оставить городу</button><button type="button" data-choice="workers">Передать докерам</button></div></div><div class="empire-council"><p>СОВЕТ И ЭЛИТЫ</p><div class="empire-ministers">'+ministers.map(function(m){return '<article class="empire-minister"><i>'+m[3]+'</i><b>'+m[0]+'</b><small>'+m[1]+' · '+m[2]+'</small><button type="button" data-bribe="'+m[3]+'">Предложить услугу</button></article>';}).join('')+'</div><p>ЗАКОНЫ ГОРОДА</p><div class="empire-laws">'+laws.map(function(l,i){return '<button type="button" data-law="'+i+'"><b>'+l[0]+'</b><small>'+l[1]+'</small></button>';}).join('')+'</div></div><div class="empire-story"><p>ХРОНИКА ИМПЕРИИ · АКТ <span data-chapter>1</span></p><h3 data-story-title>Город, который проснулся</h3><p data-story-copy>Под фундаментом ОSGARD найдено чёрное топливо. Совет требует порядка, а улицы — ответа.</p><button type="button" data-story-next>Продолжить хронику</button></div></div>';
  document.body.appendChild(map);
  var cityMap = document.createElement('div');
  cityMap.className = 'empire-city-map';
  cityMap.innerHTML = districts.map(function (d, i) { return '<button type="button" data-city-district="'+i+'"><i></i><b>'+d[0]+'</b><small>'+d[1]+'</small></button>'; }).join('');
  map.querySelector('.empire-sheet').insertBefore(cityMap, map.querySelector('.empire-districts'));
  var factionBox = document.createElement('div'); factionBox.className = 'empire-factions'; factionBox.innerHTML = '<p>БАЛАНС ФРАКЦИЙ</p><div></div>'; map.querySelector('.empire-sheet').insertBefore(factionBox, map.querySelector('.empire-districts'));
  function renderFactions(){ var labels={council:'Совет',consortium:'Консорциум',dockers:'Докеры',archivists:'Архивисты',citizens:'Жители'}; factionBox.querySelector('div').innerHTML=Object.keys(labels).map(function(k){return '<span><b>'+labels[k]+'</b><i><em style="width:'+Math.max(0,Math.min(100,state.factions[k]))+'%"></em></i></span>';}).join(''); }
  renderFactions();
  window.setInterval(renderFactions, 500);
  if (crisis) {
    var crisisBox = document.createElement('div'); crisisBox.className = 'empire-crisis';
    crisisBox.innerHTML = '<p>НОВЫЙ КРИЗИС ГОРОДА</p><strong>'+crisis[0]+'</strong><span>'+crisis[1]+'</span><div><button type="button">Потратить казну</button><button type="button">Скрыть аварию</button></div>';
    map.querySelector('.empire-sheet').insertBefore(crisisBox, cityMap);
    crisisBox.addEventListener('click', function (event) { var action = event.target.closest('button'); if (!action) return; if (action.textContent.indexOf('Потратить') >= 0) { state.treasury = Math.max(0, state.treasury - 40); state.trust += 10; state.factions[crisis[2] === 'dockers' ? 'dockers' : crisis[2] === 'archive' ? 'archivists' : 'citizens'] += 12; } else { state.oil = Math.max(0, state.oil - 12); state.trust -= 14; } crisisBox.remove(); save(); render(); });
  }
  cityMap.addEventListener('click', function (event) { var item = event.target.closest('[data-city-district]'); if (!item) return; var target = map.querySelector('[data-district="'+item.dataset.cityDistrict+'"]'); if (target) target.click(); });
  var production = document.createElement('div');
  production.className = 'empire-production';
  production.innerHTML = '<p>ПРОИЗВОДСТВО · НЕФТЯНОЙ ПОЯС</p><strong>Переработайте сырьё в топливо и казну.</strong><button type="button" data-refine>Запустить переработку</button><button type="button" data-upgrade>Улучшить НПЗ · 80 казны</button><small class="empire-refinery-level"></small>';
  map.querySelector('.empire-sheet').appendChild(production);
  production.querySelector('button').onclick = function () {
    var oil = Number(localStorage.getItem('osgard-oil-v1') || 40);
    if (oil < 10) { this.textContent = 'Недостаточно нефти'; return; }
    localStorage.setItem('osgard-oil-v1', String(oil - 10));
    state.fuel += 25 + state.refinery * 5; state.treasury += state.refinery * 6; save();
    this.textContent = 'Партия произведена · +' + (25 + state.refinery * 5) + ' топлива';
  };
  production.querySelector('[data-upgrade]').onclick = function () { if (state.treasury < 80) { this.textContent = 'Недостаточно казны'; return; } state.treasury -= 80; state.refinery += 1; save(); production.querySelector('.empire-refinery-level').textContent = 'Мощность НПЗ · уровень '+state.refinery; this.textContent = 'НПЗ улучшен'; this.disabled = true; };
  production.querySelector('.empire-refinery-level').textContent = 'Мощность НПЗ · уровень '+state.refinery;
  var deals = document.createElement('div');
  deals.className = 'empire-deals';
  deals.innerHTML = '<p>СДЕЛКИ ФРАКЦИЙ</p><strong>Выберите, кому дать доступ к следующей поставке.</strong><div><button type="button" data-deal="council">Совет · стабильность</button><button type="button" data-deal="consortium">Консорциум · прибыль</button><button type="button" data-deal="dockers">Докеры · доверие</button></div>';
  map.querySelector('.empire-sheet').appendChild(deals);
  deals.addEventListener('click', function (event) {
    var deal = event.target.closest('[data-deal]');
    if (!deal) return;
    var key = deal.dataset.deal;
    var current = Number(localStorage.getItem('osgard-treasury-v1') || 120);
    localStorage.setItem('osgard-treasury-v1', String(current + (key === 'consortium' ? 55 : 20)));
    deal.textContent = 'Сделка подписана'; deal.disabled = true;
  });
  var ledger = document.createElement('div');
  ledger.className = 'empire-ledger';
  ledger.innerHTML = '<p>ЖУРНАЛ РЕШЕНИЙ</p><div>Город ждёт первого приказа.</div>';
  map.querySelector('.empire-sheet').appendChild(ledger);
  var share = document.createElement('button');
  share.type = 'button'; share.className = 'empire-share'; share.textContent = 'Поделиться печатью империи';
  map.querySelector('.empire-sheet').appendChild(share);
  var reset = document.createElement('button'); reset.type='button'; reset.className='empire-reset'; reset.textContent='Начать новую кампанию'; map.querySelector('.empire-sheet').appendChild(reset);
  var transfer = document.createElement('div'); transfer.className='empire-transfer'; transfer.innerHTML='<button type="button" data-export>Экспорт кампании</button><button type="button" data-import>Импорт кампании</button><input type="file" accept="application/json" hidden>'; map.querySelector('.empire-sheet').appendChild(transfer);
  transfer.querySelector('[data-export]').onclick=function(){var blob=new Blob([JSON.stringify(state,null,2)],{type:'application/json'});var a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='osgard-campaign.json';a.click();setTimeout(function(){URL.revokeObjectURL(a.href);},1000);};
  transfer.querySelector('[data-import]').onclick=function(){transfer.querySelector('input').click();};
  transfer.querySelector('input').onchange=function(){var file=this.files&&this.files[0];if(!file)return;var reader=new FileReader();reader.onload=function(){try{var imported=JSON.parse(reader.result);if(!imported||typeof imported!=='object')throw Error();localStorage.setItem('osgard-empire-world-v1',JSON.stringify(imported));location.reload();}catch(e){alert('Файл кампании не распознан');}};reader.readAsText(file);};
  reset.onclick = function () { if (!window.confirm('Сбросить только кампанию OSGARD?')) return; localStorage.removeItem('osgard-empire-world-v1'); localStorage.removeItem('osgard-ledger-v1'); window.location.reload(); };
  var daily = document.createElement('div'); daily.className = 'empire-daily';
  var missions = ['Произведите топливо для порта','Подпишите сделку с фракцией','Примите закон для жителей'];
  var missionIndex = Math.floor(Date.now() / 86400000) % missions.length;
  daily.innerHTML = '<p>ЕЖЕДНЕВНЫЙ МАНДАТ · '+new Date().toLocaleDateString('ru-RU')+'</p><strong>'+missions[missionIndex]+'</strong><button type="button">Отметить выполнение</button>';
  map.querySelector('.empire-sheet').appendChild(daily);
  daily.querySelector('button').onclick = function () { var key='osgard-daily-'+missionIndex+'-'+Math.floor(Date.now()/86400000); if(localStorage.getItem(key)){this.textContent='Мандат уже выполнен';return;} localStorage.setItem(key,'1'); state.treasury += 35; state.influence += 5; save(); this.textContent='Мандат выполнен · +35 казны'; };
  share.onclick = function () {
    var text = 'OSGARD · Акт '+state.chapter+' · Нефть '+state.oil+' · Казна '+state.treasury+' · Доверие '+state.trust;
    if (navigator.share) navigator.share({ title: 'OSGARD: Империя времени', text: text }).catch(function () {});
    else if (navigator.clipboard) navigator.clipboard.writeText(text).then(function () { share.textContent = 'Печать скопирована'; });
  };
  function record(message) {
    var entries = []; try { entries = JSON.parse(localStorage.getItem('osgard-ledger-v1') || '[]'); } catch (e) {}
    entries.unshift({ message: message, at: new Date().toLocaleString('ru-RU') });
    entries = entries.slice(0, 8); localStorage.setItem('osgard-ledger-v1', JSON.stringify(entries));
    ledger.querySelector('div').innerHTML = entries.map(function (entry) { return '<span><b>'+entry.message+'</b><small>'+entry.at+'</small></span>'; }).join('');
  }
  ledger.addEventListener('click', function () { record('Архив перечитан'); });
  map.addEventListener('click', function (event) {
    var action = event.target.closest('[data-choice],[data-law],[data-bribe],[data-deal],[data-refine],[data-story-next]');
    if (action && action.textContent) record(action.textContent.trim());
    if (action && action.dataset.choice) { var c=action.dataset.choice; state.factions.consortium += c==='consortium'?8:-2; state.factions.citizens += c==='city'||c==='workers'?8:-5; state.factions.dockers += c==='workers'?12:-2; save(); }
    if (action && action.dataset.bribe) { state.factions.council += 6; state.factions.citizens -= 4; save(); }
    if (action && action.dataset.deal) { state.factions[action.dataset.deal==='consortium'?'consortium':action.dataset.deal==='dockers'?'dockers':'council'] += 8; save(); }
    if (action && action.dataset.law) { var lawIndex = Number(action.dataset.law); state.factions.council += lawIndex === 0 ? 8 : -2; state.factions.citizens += lawIndex === 1 ? 10 : -5; state.factions.archivists += lawIndex === 2 ? 9 : 0; save(); }
  }, true);
  map.querySelector('[data-story-next]').addEventListener('click', function () {
    if (state.chapter < 4) return;
    var title = map.querySelector('[data-story-title]');
    var copy = map.querySelector('[data-story-copy]');
    var ending = state.trust >= 65 ? ['Свободный город', 'Жители получили право голоса, а нефть стала общественным ресурсом.'] : state.influence >= 35 ? ['Железная империя', 'Совет подчинил улицы. Город богат, но память о свободе стала подпольной.'] : ['Распад часов', 'Контракт разорван, производство остановлено, и районы начали жить каждый своим временем.'];
    title.textContent = ending[0]; copy.textContent = ending[1]; this.textContent = 'Финал открыт'; this.disabled = true; record(ending[0]);
  });
  var resources = map.querySelector('.empire-resources');
  function save(){ state.lastSeen = Date.now(); try { localStorage.setItem('osgard-empire-world-v1', JSON.stringify(state)); } catch(e){} }
  save();
  function render(){ resources.textContent='Нефть '+state.oil+'  ·  Казна '+state.treasury+'  ·  Влияние '+state.influence+'  ·  Доверие '+state.trust; map.querySelector('.empire-districts').innerHTML=districts.map(function(d,i){return '<button class="empire-district '+(i===state.district?'is-active':'')+'" type="button" data-district="'+i+'"><b>'+d[0]+'</b><small>'+d[1]+'</small></button>';}).join(''); map.querySelector('[data-chapter]').textContent=state.chapter; var stories=[['Город, который проснулся','Под фундаментом OSGARD найдено чёрное топливо. Совет требует порядка, а улицы — ответа.'],['Цена стабильности','Контракт подписан. Теперь каждая фракция требует свою цену за тишину.'],['Память глубин','Архивисты утверждают: нефть — это конденсат украденного времени.'],['Последний контракт','Город ждёт решения Архитектора: машина, свобода или распад.']]; var s=stories[Math.min(state.chapter-1,stories.length-1)]; map.querySelector('[data-story-title]').textContent=s[0]; map.querySelector('[data-story-copy]').textContent=s[1]; }
  button.onclick=function(){map.hidden=false;render()}; map.querySelector('.empire-close').onclick=function(){map.hidden=true};
  map.addEventListener('click',function(e){var district=e.target.closest('[data-district]');if(district){state.district=Number(district.dataset.district);render();save();}var choice=e.target.closest('[data-choice]');if(choice){var c=choice.dataset.choice;if(c==='consortium'){state.treasury+=80;state.trust-=12;state.influence+=8;}if(c==='city'){state.treasury+=25;state.trust+=12;state.influence-=4;}if(c==='workers'){state.oil-=8;state.trust+=20;state.influence-=8;}state.chapter=Math.max(state.chapter,2);state.choices.push(c);save();render();choice.textContent='Решение принято';choice.disabled=true;}var bribe=e.target.closest('[data-bribe]');if(bribe){state.treasury=Math.max(0,state.treasury-20);state.influence+=10;save();bribe.textContent='Услуга оказана';bribe.disabled=true;}var law=e.target.closest('[data-law]');if(law){state.trust+=Number(law.dataset.law)===1?14:-4;state.influence+=6;save();law.classList.add('is-passed');law.disabled=true;law.querySelector('small').textContent='Закон принят · последствия активны';}var next=e.target.closest('[data-story-next]');if(next){state.chapter=Math.min(4,state.chapter+1);save();render();}});
})();
