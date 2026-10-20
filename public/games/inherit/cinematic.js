/* INHERIT CINEMATIC v1. Enhances, never replaces, the verified world runtime. */
(() => {
  'use strict';
  const doc = document;
  const storage = window.InheritPersistence;
  const ui = () => window.InheritUI;
  const qualityKey = 'inherit:visual-quality:v1';
  const copy = {
    ru: {
      rules: 'Правила игры', hideRules: 'Свернуть правила', menu: 'Все функции',
      menuTitle: 'История, сохранения и возможности', quality: 'Режим экономии',
      cinema: 'Кинематографический режим', chapter: 'МИР, КОТОРЫЙ ТЫ ПРОДОЛЖАЕШЬ',
      chapterPrefix: 'ПОКОЛЕНИЕ', stage: 'ТИХАЯ ГАВАНЬ',
      guideOpen: 'Развернуть правила и сведения о сохранении',
      menuOpen: 'Открыть дополнительные действия',
      performance: 'Переключить качество графики',
    },
    en: {
      rules: 'How to play', hideRules: 'Hide guide', menu: 'All options',
      menuTitle: 'History, saves & features', quality: 'Eco graphics',
      cinema: 'Cinematic graphics', chapter: 'THE WORLD YOU CONTINUE',
      chapterPrefix: 'GENERATION', stage: 'THE QUIET REACH',
      guideOpen: 'Expand guide and save information',
      menuOpen: 'Open additional actions',
      performance: 'Switch graphics quality',
    },
    zh: {
      rules: '游戏指南', hideRules: '收起指南', menu: '更多功能',
      menuTitle: '历史、存档与更多功能', quality: '节能画质',
      cinema: '电影级画质', chapter: '由你延续的世界',
      chapterPrefix: '世代', stage: '寂静之境',
      guideOpen: '展开游戏指南与存档说明',
      menuOpen: '打开其他操作',
      performance: '切换画质',
    },
  };
  const lang = () => copy[ui()?.getLanguage?.()] ? ui().getLanguage() : 'ru';
  const label = name => copy[lang()][name];
  const reduced = window.matchMedia?.('(prefers-reduced-motion: reduce)');
  const world = doc.querySelector('#world');
  if (!world) return;

  let quality = 'cinema', animation = 0, lastPaint = 0, width = 1, height = 1, stars = [];
  try {
    quality = storage?.getItem(qualityKey) === 'eco' || reduced?.matches ? 'eco' : 'cinema';
  } catch {}
  const sky = doc.createElement('canvas');
  sky.id = 'inherit-cosmos';
  sky.setAttribute('aria-hidden', 'true');
  world.prepend(sky);
  const ctx = sky.getContext('2d', { alpha: false });
  const controls = doc.createElement('div');
  controls.className = 'cine-scene-controls';
  const qualityButton = doc.createElement('button');
  qualityButton.type = 'button';
  qualityButton.className = 'cine-scene-mode';
  qualityButton.setAttribute('aria-label', label('performance'));
  controls.appendChild(qualityButton);
  world.appendChild(controls);

  const chapter = doc.createElement('span');
  chapter.className = 'cine-chapter';
  chapter.textContent = label('chapter');
  world.appendChild(chapter);
  const guide = doc.querySelector('.inherit-guide');
  let guideButton = null, menuButton = null, menuPanel = null, menuOpen = false;
  const accountMode = new URLSearchParams(location.search).get('mode') === 'account';
  const compactAllowed = !accountMode && !storage?.recovered && !storage?.ephemeral;

  function updateLabels() {
    if (guideButton) {
      const compact = guide?.classList.contains('cine-compact');
      guideButton.textContent = compact ? label('rules') : label('hideRules');
      guideButton.setAttribute('aria-label', label('guideOpen'));
      guideButton.setAttribute('aria-expanded', String(!compact));
    }
    if (menuButton) {
      menuButton.textContent = (menuOpen ? '✕  ' : '☰  ') + label('menu');
      menuButton.setAttribute('aria-label', label('menuOpen'));
    }
    if (menuPanel) {
      const heading = menuPanel.querySelector('.cine-utility-heading');
      if (heading) heading.textContent = label('menuTitle');
    }
    qualityButton.textContent = quality === 'eco' ? '◉  ' + label('quality') : '✧  ' + label('cinema');
    qualityButton.setAttribute('aria-label', label('performance'));
    qualityButton.setAttribute('aria-pressed', String(quality === 'eco'));
    chapter.textContent = label('chapter');
  }

  window.InheritCinematic = { updateLabels, getQuality: () => quality };

  function guideControls() {
    if (!guide) return;
    guideButton = doc.createElement('button');
    guideButton.type = 'button';
    guideButton.id = 'cine-guide-toggle';
    guideButton.className = 'cine-guide-toggle';
    guideButton.setAttribute('aria-controls', 'inherit-guide-details');
    const heading = guide.querySelector('.inherit-guide-heading');
    if (heading) heading.appendChild(guideButton);
    const details = guide;
    details.id = 'inherit-guide-details';
    if (compactAllowed) details.classList.add('cine-compact');
    guideButton.addEventListener('click', () => {
      details.classList.toggle('cine-compact');
      updateLabels();
    });
    // Enter the island is always visible, so new players don't have to read a long manual.
    updateLabels();
  }

  function closeMenu(focus) {
    if (!menuPanel || !menuButton) return;
    menuOpen = false;
    menuPanel.hidden = true;
    menuPanel.inert = true;
    menuButton.setAttribute('aria-expanded', 'false');
    updateLabels();
    if (focus) menuButton.focus();
  }
  function dockControls() {
    const dock = doc.querySelector('.dock');
    if (!dock) return;
    // The shared-account browser journey uses directly visible history, export and refresh actions.
    // Keep those controls discoverable instead of trapping them in a collapsed utility menu.
    if (accountMode) {
      dock.classList.add('cine-account-dock');
      return;
    }
    dock.classList.add('cine-dock');
    const panel = doc.createElement('section');
    panel.className = 'cine-utility';
    panel.id = 'cine-utility-menu';
    panel.hidden = true;
    panel.inert = true;
    panel.setAttribute('aria-label', label('menuTitle'));
    const heading = doc.createElement('strong');
    heading.className = 'cine-utility-heading';
    panel.appendChild(heading);
    // Moving the already-bound elements preserves their handlers, IDs, and live game state.
    for (const child of [...dock.children]) {
      if (child.matches('.turn,.tools,#pass,#showHistory,.cine-utility,.cine-menu-toggle')) continue;
      panel.appendChild(child);
    }
    const button = doc.createElement('button');
    button.type = 'button';
    button.className = 'cine-menu-toggle';
    button.setAttribute('aria-controls', panel.id);
    button.setAttribute('aria-expanded', 'false');
    dock.appendChild(button);
    dock.appendChild(panel);
    menuButton = button; menuPanel = panel;
    button.addEventListener('click', () => {
      menuOpen = !menuOpen;
      panel.hidden = !menuOpen;
      panel.inert = !menuOpen;
      button.setAttribute('aria-expanded', String(menuOpen));
      updateLabels();
      if (menuOpen) panel.querySelector('button,a')?.focus();
    });
    panel.addEventListener('click', event => {
      if (event.target.closest('button,a')) closeMenu(false);
    });
    doc.addEventListener('pointerdown', event => {
      if (menuOpen && !panel.contains(event.target) && !button.contains(event.target)) closeMenu(false);
    });
    doc.addEventListener('keydown', event => {
      if (menuOpen && event.key === 'Escape') closeMenu(true);
    });
    updateLabels();
  }

  // Seeded star positions avoid flicker during resize, language changes and recovery.
  function seeded(seed) { let n = seed >>> 0; return () => {
    n += 0x6D2B79F5;
    let x = Math.imul(n ^ n >>> 15, 1 | n);
    x ^= x + Math.imul(x ^ x >>> 7, 61 | x);
    return ((x ^ x >>> 14) >>> 0) / 4294967296;
  }; }
  const rand = seeded(173204);
  const allStars = Array.from({length: 230}, () => ({
    x: rand(), y: rand() * .70, r: .35 + rand() * 1.4,
    phase: rand() * Math.PI * 2, tone: rand(), a: .19 + rand() * .52,
  }));
  function resize() {
    if (!ctx) return;
    const rect = world.getBoundingClientRect();
    width = Math.max(1, Math.round(rect.width));
    height = Math.max(1, Math.round(rect.height));
    const scale = quality === 'eco' ? 1 : Math.min(1.6, window.devicePixelRatio || 1);
    sky.width = Math.max(1, Math.round(width * scale));
    sky.height = Math.max(1, Math.round(height * scale));
    ctx.setTransform(scale, 0, 0, scale, 0, 0);
    stars = allStars.slice(0, quality === 'eco' ? 85 : width < 620 ? 125 : 230);
    paint(0);
  }
  function glow(x, y, radius, rgb, power) {
    const g = ctx.createRadialGradient(x, y, 0, x, y, radius);
    g.addColorStop(0, 'rgba(' + rgb + ',' + power + ')');
    g.addColorStop(.42, 'rgba(' + rgb + ',' + (power * .26) + ')');
    g.addColorStop(1, 'rgba(' + rgb + ',0)');
    ctx.fillStyle = g;
    ctx.fillRect(x-radius, y-radius, radius*2, radius*2);
  }
  function horizon() {
    const y = height * .59;
    const water = ctx.createLinearGradient(0, y, 0, height);
    water.addColorStop(0, '#1d4350');
    water.addColorStop(.24, '#143944');
    water.addColorStop(1, '#071923');
    ctx.fillStyle = water;
    ctx.fillRect(0, y, width, height-y);
    ctx.strokeStyle = 'rgba(171,203,196,.11)';
    ctx.lineWidth = 1;
    const random = seeded(2081);
    for (let i = 0; i < 90; i++) {
      const px = random() * width, py = y + random() * (height - y);
      const len = (9 + random() * 48) * (.55 + (py-y) / (height-y));
      ctx.beginPath();ctx.moveTo(px, py);ctx.lineTo(px + len, py);ctx.stroke();
    }
    const distant = [[0,.53],[.09,.58],[.16,.53],[.23,.61],[.33,.51],[.46,.64],[.52,.56],[.61,.61],[.72,.51],[.81,.6],[.93,.53],[1,.58]];
    ctx.beginPath();ctx.moveTo(0,height);ctx.lineTo(0,distant[0][1]*height);
    for(const p of distant.slice(1))ctx.lineTo(p[0]*width,p[1]*height);
    ctx.lineTo(width,height);ctx.closePath();
    const hill = ctx.createLinearGradient(0,height*.5,0,height);
    hill.addColorStop(0,'#17343c');hill.addColorStop(1,'#081a22');
    ctx.fillStyle=hill;ctx.fill();
  }
  function paint(t) {
    if (!ctx) return;
    const bg = ctx.createLinearGradient(0, 0, 0, height);
    bg.addColorStop(0, '#030d1b');bg.addColorStop(.5,'#0b2433');bg.addColorStop(1,'#19353c');
    ctx.fillStyle=bg;ctx.fillRect(0,0,width,height);
    glow(width*.72,height*.22,Math.min(width*.35,height*.59),'111,159,170',.19);
    glow(width*.24,height*.35,Math.min(width*.43,height*.62),'50,98,120',.17);
    glow(width*.83,height*.43,Math.min(width*.35,height*.58),'179,158,113',.09);
    const moonX = width * .73, moonY = height * .19;
    const radius = Math.min(56, Math.max(26,width*.047));
    glow(moonX,moonY,radius*5,'200,212,186',.13);
    const moon = ctx.createRadialGradient(moonX-radius*.42,moonY-radius*.5,radius*.04,moonX,moonY,radius);
    moon.addColorStop(0,'#cbd9cf');moon.addColorStop(.57,'#91aea7');moon.addColorStop(1,'#405e67');
    ctx.fillStyle=moon;ctx.beginPath();ctx.arc(moonX,moonY,radius,0,Math.PI*2);ctx.fill();
    ctx.strokeStyle='rgba(235,239,221,.22)';ctx.lineWidth=1.2;ctx.stroke();
    ctx.fillStyle='rgba(20,40,50,.16)';
    ctx.beginPath();ctx.arc(moonX+radius*.24,moonY+radius*.21,radius*.72,0,Math.PI*2);ctx.fill();
    stars.forEach(s=>{
      const pulse=quality==='eco'?1:.75+.25*Math.sin(t*.00065+s.phase);
      const a=s.a*pulse;
      ctx.fillStyle=s.tone>.82?'rgba(238,210,150,'+a+')':'rgba(209,232,237,'+a+')';
      ctx.beginPath();ctx.arc(s.x*width,s.y*height,s.r,0,Math.PI*2);ctx.fill();
    });
    if(quality!=='eco'){
      const rand2=seeded(81191);
      for(let i=0;i<75;i++){const x=rand2()*width,y=rand2()*height*.58;ctx.fillStyle='rgba(208,225,229,.075)';ctx.fillRect(x,y,1,1)}
    }
    horizon();
    glow(width*.51,height*.68,Math.min(width*.58,height*.58),'126,173,154',.13);
  }
  function frame(now) {
    animation = 0;
    if (quality !== 'cinema' || reduced?.matches || doc.hidden) return;
    if (now-lastPaint >= 33) { paint(now);lastPaint=now; }
    animation = requestAnimationFrame(frame);
  }
  function schedule() {
    if (animation) cancelAnimationFrame(animation);
    animation = 0;
    if (quality === 'cinema' && !reduced?.matches && !doc.hidden && ctx) animation = requestAnimationFrame(frame);
  }
  function setQuality(value) {
    quality = value === 'eco' ? 'eco' : 'cinema';
    doc.body.classList.toggle('cine-eco',quality==='eco');
    try { storage?.setItem(qualityKey,quality); } catch {}
    resize();schedule();updateLabels();
  }
  qualityButton.addEventListener('click', () => setQuality(quality === 'eco' ? 'cinema' : 'eco'));
  reduced?.addEventListener?.('change', () => {resize();schedule()});
  doc.addEventListener('visibilitychange',schedule);
  if(typeof ResizeObserver !== 'undefined') new ResizeObserver(resize).observe(world);
  else window.addEventListener('resize',resize,{passive:true});

  // This small animated ripple never grants resources or modifies any saved data.
  const hasMotion = () => quality === 'cinema' && !reduced?.matches;
  world.addEventListener('click', event => {
    if (!hasMotion() || !event.isTrusted || event.target.closest('button,a,[data-memory]')) return;
    const island = doc.querySelector('#island');
    const rect = island?.getBoundingClientRect();
    if (!rect || !rect.width || !rect.height) return;
    const x=(event.clientX-rect.left)/rect.width, y=(event.clientY-rect.top)/rect.height;
    if(x<.08||x>.91||y<.12||y>.77)return;
    const mark=doc.createElement('span');
    mark.className='cine-click-ripple';
    mark.style.left=(event.clientX-world.getBoundingClientRect().left)+'px';
    mark.style.top=(event.clientY-world.getBoundingClientRect().top)+'px';
    world.appendChild(mark);
    setTimeout(()=>mark.remove(),800);
  });
  function attach() {
    guideControls();
    dockControls();
    doc.addEventListener('click', event => {
      if(event.target.closest('[data-game-language]'))updateLabels();
    });
    updateLabels();resize();schedule();
  }
  if(doc.readyState==='loading')doc.addEventListener('DOMContentLoaded',attach,{once:true});
  else attach();
})();