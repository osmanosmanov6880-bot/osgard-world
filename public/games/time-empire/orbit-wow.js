(function () {
  var gate = document.querySelector('.orrery-gate');
  if (!gate || matchMedia('(prefers-reduced-motion: reduce)').matches) return;

  var style = document.createElement('style');
  style.textContent = [
    '.orrery-arrival{position:absolute;inset:0;z-index:18;pointer-events:none;overflow:hidden;background:#020203;animation:orrery-arrival-fade .5s 1.55s forwards}',
    '.orrery-arrival:before{content:"";position:absolute;left:50%;top:-12%;width:1px;height:124%;background:linear-gradient(transparent,rgba(255,232,159,.08) 18%,#ffe6a5 47%,rgba(255,232,159,.08) 78%,transparent);box-shadow:0 0 15px #f2c66a,0 0 65px rgba(242,198,106,.5);transform:translateX(-50%) scaleY(.02);transform-origin:50% 48%;animation:orrery-beam .68s cubic-bezier(.2,.8,.2,1) forwards}',
    '.orrery-arrival:after{content:"ARCHIVE AWAKENS";position:absolute;left:50%;top:calc(50% + 132px);transform:translate(-50%,8px);color:#f1d48a;font:500 8px JetBrains Mono,monospace;letter-spacing:.28em;white-space:nowrap;opacity:0;animation:orrery-whisper .42s .64s forwards}',
    '.orrery-gate .orrery-stage{animation:orrery-world-arrive 1s cubic-bezier(.16,.83,.21,1) both}',
    '.orrery-gate .orrery-brand{animation:orrery-core-arrive 1.15s cubic-bezier(.16,.83,.21,1) both}',
    '.orrery-gate .orrery-node{animation:orrery-node-arrive .9s cubic-bezier(.16,.83,.21,1) both;animation-delay:var(--arrival-delay,0ms)}',
    '.orrery-gate .orrery-node[data-world="time"]{--arrival-delay:260ms}.orrery-gate .orrery-node[data-world="protocol"]{--arrival-delay:390ms}.orrery-gate .orrery-node[data-world="archetype"]{--arrival-delay:520ms}',
    '.orrery-gate.is-world-opening:after{content:"";position:absolute;inset:0;z-index:17;background:radial-gradient(circle at 50% 49%,rgba(255,224,137,.82),rgba(255,224,137,.14) 18%,#030305 58%);animation:orrery-world-flash .66s ease forwards;pointer-events:none}',
    '@keyframes orrery-arrival-fade{to{opacity:0;visibility:hidden}}@keyframes orrery-beam{55%{transform:translateX(-50%) scaleY(1)}100%{transform:translateX(-50%) scaleY(.2);opacity:0}}@keyframes orrery-whisper{to{opacity:.78;transform:translate(-50%,0)}}@keyframes orrery-world-arrive{from{opacity:0;transform:scale(1.06)}to{opacity:1;transform:none}}@keyframes orrery-core-arrive{from{opacity:0;transform:translate(-50%,-50%) scale(.36);filter:brightness(3)}to{opacity:1;transform:translate(-50%,-50%) scale(1);filter:none}}@keyframes orrery-node-arrive{from{opacity:0;filter:blur(9px);margin-top:15px}to{filter:none;margin-top:0}}@keyframes orrery-world-flash{0%{opacity:0}26%{opacity:1}100%{opacity:0}}'
  ].join('');
  document.head.appendChild(style);

  var seenKey = 'osgard-orrery-arrival-v1';
  var shouldPlay = false;
  try { shouldPlay = !sessionStorage.getItem(seenKey); sessionStorage.setItem(seenKey, '1'); } catch (error) { shouldPlay = true; }
  if (shouldPlay) {
    var arrival = document.createElement('div');
    arrival.className = 'orrery-arrival';
    gate.appendChild(arrival);
  }

  function haptic(duration) {
    if (navigator.vibrate) navigator.vibrate(duration);
  }
  gate.querySelectorAll('.orrery-node').forEach(function (node) {
    node.addEventListener('click', function () { haptic(7); });
  });
  var enter = gate.querySelector('.orrery-enter');
  if (enter) {
    enter.addEventListener('click', function () {
      if (enter.textContent.indexOf('Импер') !== -1) {
        gate.classList.add('is-world-opening');
        haptic([12, 42, 18]);
      }
    });
  }
})();

(function () {
  if (Array.prototype.some.call(document.scripts, function (item) {
    return item.src && new URL(item.src, location.href).pathname.endsWith('/empire-world.js');
  })) return;
  var script = document.createElement('script');
  script.src = '/games/time-empire/empire-world.js?v=20261002a';
  script.defer = true;
  document.head.appendChild(script);
})();
