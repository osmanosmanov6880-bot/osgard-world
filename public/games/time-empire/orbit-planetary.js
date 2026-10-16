(function () {
  var gate = document.querySelector('.orrery-gate');
  if (!gate) return;

  var style = document.createElement('style');
  style.textContent = [
    '.orrery-node__frame{aspect-ratio:1!important;border-radius:50%!important;clip-path:none!important;background:#050507!important;isolation:isolate}',
    '.orrery-node__frame:before,.orrery-node__frame:after{border-radius:inherit}.orrery-node__frame:after{background:linear-gradient(138deg,#fff3,transparent 24% 68%,#000a)!important}',
    '.orrery-world-ring{position:absolute;inset:-13%;z-index:4;border:1px solid currentColor;border-radius:50%;opacity:.62;pointer-events:none;transform:rotateX(67deg) rotateZ(-18deg);box-shadow:0 0 15px currentColor;animation:orrery-planet-ring 8s linear infinite}',
    '.orrery-world-ring:after{content:"";position:absolute;inset:12%;border:1px dashed currentColor;border-radius:50%;opacity:.42}',
    '.orrery-node[data-world="time"] .orrery-world-ring{color:#e0ad52}.orrery-node[data-world="protocol"] .orrery-world-ring{color:#8eb8ff;animation-duration:6.5s}.orrery-node[data-world="archetype"] .orrery-world-ring{color:#ded8c3;animation-duration:10s}',
    '.orrery-node__meta{margin:12px 0 0!important;text-align:center}.orrery-node__meta b{letter-spacing:.02em}.orrery-node__meta small{justify-self:center}.orrery-node__meta span{justify-self:center;max-width:210px}',
    '.orrery-node.is-focused .orrery-world-ring{opacity:1;filter:brightness(1.28);animation-duration:4.4s}.orrery-node:not(.is-focused) .orrery-world-ring{opacity:.29}',
    '@keyframes orrery-planet-ring{to{transform:rotateX(67deg) rotateZ(342deg)}}'
  ].join('');
  document.head.appendChild(style);

  gate.querySelectorAll('.orrery-node__frame').forEach(function (frame) {
    var ring = document.createElement('i');
    ring.className = 'orrery-world-ring';
    frame.appendChild(ring);
  });
})();

// Keep the world portals interactive after the orbital decoration is mounted.
(function () {
  var gate = document.querySelector('.orrery-gate');
  if (!gate) return;
  var stage = gate.querySelector('.orrery-stage');
  var nodes = Array.prototype.slice.call(gate.querySelectorAll('.orrery-node'));
  if (!stage || !nodes.length) return;
  var premium = document.createElement('style');
  premium.textContent = '.orrery-preview{display:none!important}.orrery-status{color:#d8c99f!important}.orrery-game-panel{border-color:rgba(197,160,89,.5);backdrop-filter:blur(18px)}';
  document.head.appendChild(premium);
  // The stage owns drag gestures; portal buttons must always win the hit test.
  var originalDown = stage.onpointerdown;
  stage.onpointerdown = function (event) {
    if (event.target && event.target.closest && event.target.closest('.orrery-node')) return;
    if (originalDown) originalDown.call(stage, event);
  };
  nodes.forEach(function (node) {
    node.style.pointerEvents = 'auto';
    node.setAttribute('aria-pressed', node.classList.contains('is-focused') ? 'true' : 'false');
    node.addEventListener('pointerdown', function (event) { event.stopPropagation(); }, { passive: true });
    node.addEventListener('click', function () {
      nodes.forEach(function (other) {
        var active = other === node;
        other.classList.toggle('is-focused', active);
        other.setAttribute('aria-pressed', active ? 'true' : 'false');
      });
      var world = node.dataset.world || 'time';
      gate.dataset.world = world;
      var brand = gate.querySelector('.orrery-brand');
      if (brand) brand.dataset.world = world;
      var title = node.querySelector('.orrery-node__meta b');
      var status = gate.querySelector('.orrery-status');
      if (title && status) status.textContent = 'Выбран мир: ' + title.textContent + '. Нажмите кнопку, чтобы войти.';
    }, { passive: true });
  });

  var enter = gate.querySelector('.orrery-enter');
  var status = gate.querySelector('.orrery-status');
  window.setInterval(function () {
    if (status && gate.dataset.world !== 'time') status.textContent = 'Мир готов к запуску — нажмите кнопку входа.';
    if (enter && gate.dataset.world !== 'time') enter.textContent = 'Запустить мир';
  }, 120);
  if (enter) enter.addEventListener('click', function (event) {
    var world = gate.dataset.world;
    if (world === 'time') return;
    event.preventDefault();
    event.stopImmediatePropagation();
    var title = world === 'protocol' ? 'ПРОТОКОЛ' : 'АРХЕТИП';
    var subtitle = world === 'protocol' ? 'Соберите сигнальную сеть' : 'Выберите форму, которую примет мир';
    var actions = world === 'protocol' ? ['Северный узел','Орбитальный узел','Глубинный узел'] : ['Страж','Провидец','Создатель'];
    var screen = document.createElement('section');
    screen.className = 'orrery-game-screen';
    screen.dataset.world = world;
    screen.innerHTML = '<div class="orrery-game-panel"><button class="orrery-game-close" type="button" aria-label="Вернуться к мирам">×</button><small>OSGARD / '+title+'</small><h1>'+title+'</h1><p>'+subtitle+'</p><div class="orrery-game-core"><span></span></div><div class="orrery-game-actions">'+actions.map(function (label, i) { return '<button type="button" data-action="'+i+'">'+label+'</button>'; }).join('')+'</div><strong class="orrery-game-message">Выберите действие</strong></div>';
    document.body.appendChild(screen);
    requestAnimationFrame(function(){ screen.classList.add('is-open'); });
    screen.querySelector('.orrery-game-close').onclick = function(){ screen.classList.remove('is-open'); setTimeout(function(){screen.remove();}, 420); };
    screen.querySelectorAll('[data-action]').forEach(function(button){ button.onclick = function(){ screen.querySelector('.orrery-game-message').textContent = 'Синхронизация завершена: '+button.textContent; button.classList.add('is-selected'); }; });
  }, true);
})();
