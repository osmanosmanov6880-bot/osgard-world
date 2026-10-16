(function () {
  var gate = document.querySelector('.orrery-gate');
  if (!gate) return;
  var stage = gate.querySelector('.orrery-stage');
  var frames = Array.prototype.slice.call(gate.querySelectorAll('.orrery-node__frame'));
  if (!stage || !frames.length) return;

  var style = document.createElement('style');
  style.textContent = [
    '.orrery-node__frame:before{content:"";position:absolute;inset:-30%;z-index:1;pointer-events:none;mix-blend-mode:screen;opacity:.58;transition:opacity .45s,transform .3s;transform:translate3d(calc(var(--px,0) * .32),calc(var(--py,0) * .32),0) rotate(12deg)}',
    '.orrery-node[data-world="time"] .orrery-node__frame:before{background:conic-gradient(from 45deg,transparent 0 25%,#f7ca6840 35%,transparent 48% 68%,#fff1ad36 78%,transparent 91%);animation:orrery-halo 9s linear infinite}',
    '.orrery-node[data-world="protocol"] .orrery-node__frame:before{background:repeating-linear-gradient(120deg,transparent 0 12px,#82c9ff24 13px 14px,transparent 15px 31px),radial-gradient(circle,#dc8cff45,transparent 56%);animation:orrery-signal 5.5s ease-in-out infinite}',
    '.orrery-node[data-world="archetype"] .orrery-node__frame:before{background:linear-gradient(110deg,transparent 28%,#fff2ca32 42%,transparent 56%),radial-gradient(ellipse at 50% 90%,#c8d4d740,transparent 53%);animation:orrery-water 7.2s ease-in-out infinite}',
    '.orrery-node.is-focused .orrery-node__frame:before{opacity:.92}.orrery-node .orrery-art{transform:translate3d(var(--px,0),var(--py,0),0) scale(1.06)}.orrery-node.is-focused .orrery-art{transform:translate3d(calc(var(--px,0) * 1.4),calc(var(--py,0) * 1.4),0) scale(1.16)}',
    '.orrery-particle{position:absolute;width:2px;height:2px;border-radius:50%;background:rgba(255,238,183,.78);box-shadow:0 0 9px rgba(239,203,118,.8);pointer-events:none;animation:orrery-particle var(--life) ease-in-out infinite;animation-delay:var(--delay)}',
    '@keyframes orrery-halo{to{transform:translate3d(calc(var(--px,0) * .32),calc(var(--py,0) * .32),0) rotate(372deg)}}@keyframes orrery-signal{50%{filter:hue-rotate(35deg);opacity:.88;transform:translate3d(calc(var(--px,0) * .32),calc(var(--py,0) * .32),0) scale(1.1)}}@keyframes orrery-water{50%{transform:translate3d(calc(var(--px,0) * .32),calc(var(--py,0) * .32),0) translateY(3%) scale(1.06);opacity:.8}}@keyframes orrery-particle{0%,100%{opacity:0;transform:translate3d(0,8px,0) scale(.6)}45%{opacity:.8}70%{transform:translate3d(var(--drift),-17px,0) scale(1)}}',
    '@media(prefers-reduced-motion:reduce){.orrery-node__frame:before,.orrery-particle{animation:none!important}}'
  ].join('');
  document.head.appendChild(style);

  for (var i = 0; i < 18; i += 1) {
    var particle = document.createElement('i');
    particle.className = 'orrery-particle';
    particle.style.left = (8 + Math.random() * 84) + '%';
    particle.style.top = (13 + Math.random() * 69) + '%';
    particle.style.setProperty('--life', (4.8 + Math.random() * 6.2) + 's');
    particle.style.setProperty('--delay', (-Math.random() * 7) + 's');
    particle.style.setProperty('--drift', ((Math.random() - .5) * 30) + 'px');
    stage.appendChild(particle);
  }

  stage.addEventListener('pointermove', function (event) {
    var bounds = stage.getBoundingClientRect();
    var x = (event.clientX - bounds.left) / bounds.width - .5;
    var y = (event.clientY - bounds.top) / bounds.height - .5;
    frames.forEach(function (frame) {
      frame.style.setProperty('--px', (x * -8).toFixed(2) + 'px');
      frame.style.setProperty('--py', (y * -7).toFixed(2) + 'px');
    });
  }, { passive: true });
})();
