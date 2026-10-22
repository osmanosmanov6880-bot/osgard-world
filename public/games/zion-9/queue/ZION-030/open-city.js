/* ZION-030 OPEN CITY v27 — immersive third-person WebGL mode.
 * Uses the already-shipped local Three.js library and the original game-state API.
 * The original strategic city and its winning rules stay authoritative.
 */
(() => {
  'use strict';
  const root = document.getElementById('world-play');
  const stage = root?.querySelector('.stage');
  const game = () => window.ZION030_GAME;
  if (!root || !stage || !game()) return;

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
      <div class="oc-brand"><span class="oc-diamond">◈</span><span><strong>ТЕНЕВОЙ ПРОТОКОЛ</strong><small>OPEN CITY · АФИНЫ · ЭПИЗОД 01</small></span></div>
      <div class="oc-top-right"><span class="oc-live"><b></b> LIVE 3D</span><button type="button" id="oc-exit" class="oc-glass">✕ <span>К КАРТЕ</span></button></div>
    </header>
    <aside class="oc-objective" aria-label="Цель миссии">
      <span class="oc-eyebrow">ЗАДАНИЕ 01 / СНИЗИТЬ ПЕРЕГРЕВ</span>
      <strong>Охлади три горячие зоны</strong>
      <p>Пройди по улицам, подойди к оранжевому сигналу и установи зелёную инфраструктуру.</p>
      <div class="oc-progress"><span id="oc-progress-bar"></span></div>
      <div class="oc-progress-label"><span id="oc-score">0 / 3 ЗОНЫ</span><span id="oc-remaining">3 МОДУЛЯ</span></div>
    </aside>
    <div class="oc-right-hud"><div class="oc-map-frame"><canvas id="oc-minimap" width="230" height="230" aria-label="Миникарта трёх районов"></canvas><span>АФИНЫ · КВАРТАЛ 03</span></div>
    <div class="oc-weather">◌ <strong>27°C</strong><small>ВЕЧЕР · СИМУЛЯЦИЯ</small></div></div>
    <div class="oc-location"><span class="oc-target-icon">⌖</span><span><small>БЛИЖАЙШАЯ ЦЕЛЬ</small><strong id="oc-target">ОСМОТРИ ГОРОД</strong><em id="oc-distance">Найди оранжевую метку</em></span></div>
    <div class="oc-toolbar" role="group" aria-label="Инструмент охлаждения">
      <button type="button" data-oc-tool="tree" aria-pressed="true"><span>1</span>🌳 <b>ДЕРЕВО</b></button>
      <button type="button" data-oc-tool="shade" aria-pressed="false"><span>2</span>▤ <b>НАВЕС</b></button>
      <button type="button" data-oc-tool="water" aria-pressed="false"><span>3</span>🌿 <b>САД</b></button>
    </div>
    <div class="oc-interact" id="oc-interact" hidden><kbd>E</kbd><span id="oc-interact-text">УСТАНОВИТЬ ОХЛАЖДЕНИЕ</span></div>
    <button class="oc-action" id="oc-action" type="button" hidden>✓ УСТАНОВИТЬ</button>
    <div class="oc-controls"><span><kbd>W A S D</kbd> ИДТИ</span><span><kbd>SHIFT</kbd> БЕГ</span><span><kbd>МЫШЬ</kbd> КАМЕРА</span><span><kbd>E</kbd> ДЕЙСТВИЕ</span></div>
    <div class="oc-joystick" id="oc-joystick" aria-label="Сенсорное управление движением"><div id="oc-stick"></div></div>
    <div class="oc-start" id="oc-start"><div class="oc-start-panel"><span class="oc-eyebrow">НОВЫЙ РЕЖИМ · ЖИВОЙ 3D-ГОРОД</span>
      <h2>ГОРОД<br><em>ЖДЁТ ТЕБЯ.</em></h2>
      <p>Свободно гуляй между домами, исследуй улицы и охлаждай район прямо от лица персонажа. Карта и достижения общие с оригинальной игрой.</p>
      <div class="oc-start-grid"><span>◉ <b>ОТКРЫТЫЙ КВАРТАЛ</b><small>Живые 3D-улицы</small></span><span>↗ <b>СВОБОДА ДВИЖЕНИЯ</b><small>WASD или джойстик</small></span><span>✦ <b>ТРИ МИССИИ</b><small>Реальное игровое состояние</small></span></div>
      <button type="button" id="oc-start-play">НАЧАТЬ ПРОГУЛКУ <span>→</span></button>
      <small class="oc-start-foot">На мобильном используй левый джойстик и веди пальцем по экрану для поворота камеры.</small>
    </div></div>
    <div class="oc-complete" id="oc-complete" hidden><div><span class="oc-eyebrow">МИССИЯ ВЫПОЛНЕНА</span><h2>ГОРОД<br><em>ОХЛАЖДЁН.</em></h2><p>Все три зоны получили охлаждение. Ты можешь продолжить прогулку или начать миссию заново.</p><button type="button" id="oc-keep-walking">ПРОДОЛЖИТЬ ПРОГУЛКУ</button><button type="button" id="oc-again">НОВАЯ МИССИЯ ↗</button></div></div>`;
  stage.append(shell);

  const $ = (id) => document.getElementById(id);
  const viewport = $('oc-viewport');
  const keys = new Set();
  const joystick = { x: 0, y: 0, pointer: null, centerX: 0, centerY: 0 };
  const player = { x: 0, z: 0, y: 0, yaw: 0, cameraYaw: 0.35, pitch: 0.28, speed: 0, moving: false };
  const world = { ready: false, active: false, initialised: false, last: 0, frame: 0, assets: [], buildings: [], rings: [], dust: [], foliage: [], lamps: [], pulse: 0, fpsFrames: 0, fpsTime: 0, fpsSample: 0, quality: 'high', gpuScale: 1.35 };
  let scene, camera, renderer, avatar, legL, legR, armL, armR, sun, minimapCtx, targetIndex = -1;
  let dragId = null, dragX = 0, dragY = 0, audio, animationId = 0;
  const clamp = (v, min, max) => Math.max(min, Math.min(max, v));
  const rand = (x, z, salt = 0) => { const a = Math.sin((x + salt) * 127.1 + (z - salt) * 311.7 + 74.7) * 43758.5453; return a - Math.floor(a); };
  const terrainBuilding = (x, z) => {
    if (x < -6 || x > 6 || z < -6 || z > 6) return false;
    if (Math.abs(x) <= 2 && Math.abs(z) <= 2) return false;
    if (HOT.some(h => Math.hypot(h.x - x, h.z - z) < 1.55)) return false;
    return rand(x, z) >= .49;
  };
  const occupied = new Set();
  for (let x = -7; x <= 7; x++) for (let z = -7; z <= 7; z++) if (terrainBuilding(x, z)) occupied.add(`${x},${z}`);
  const collides = (px, pz) => {
    if (Math.abs(px) > 7.15 || Math.abs(pz) > 7.15) return true;
    const cx = Math.round(px), cz = Math.round(pz);
    for (let x = cx - 1; x <= cx + 1; x++) for (let z = cz - 1; z <= cz + 1; z++) {
      if (occupied.has(`${x},${z}`) && Math.abs(px - x) < .55 && Math.abs(pz - z) < .55) return true;
    }
    return false;
  };
  function makeMat(color, roughness = .83, metalness = .07, emissive = 0x000000, intensity = 0) {
    return new THREE.MeshStandardMaterial({ color, roughness, metalness, emissive, emissiveIntensity: intensity });
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
    const asphalt = new THREE.Mesh(new THREE.PlaneGeometry(15.8, 15.8), road);
    asphalt.rotation.x = -Math.PI / 2; asphalt.position.y = -.035; asphalt.receiveShadow = true; scene.add(asphalt);
    const plaza = new THREE.Mesh(new THREE.PlaneGeometry(5.6, 5.6), stone);
    plaza.rotation.x = -Math.PI / 2; plaza.position.y = -.018; plaza.receiveShadow = true; scene.add(plaza);
    const markerMat = new THREE.MeshBasicMaterial({ color: 0x7797a3, transparent: true, opacity: .35, depthWrite: false });
    for (let i = -7; i <= 7; i++) {
      const xMark = drawBox(scene, i + .5, -.011, 0, .009, .007, 15.1, markerMat);
      const zMark = drawBox(scene, 0, -.011, i + .5, 15.1, .007, .009, markerMat);
      xMark.receiveShadow = zMark.receiveShadow = false;
    }
    // Pedestrian routes are visually legible and remain traversable in the actual physics map.
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
    for (let x = -7; x <= 7; x++) for (let z = -7; z <= 7; z++) {
      if (!terrainBuilding(x, z)) continue;
      const r = rand(x, z); const h = 2.6 + r * 5.15;
      const w = .68 + rand(z, x) * .18, d = .68 + rand(x + 5, z - 4) * .17;
      const building = drawBox(scene, x, .015, z, w, h, d, facade[Math.floor(rand(x + 7, z) * 4)], true);
      world.buildings.push(building);
      drawBox(scene, x, h + .014, z, w + .07, .095, d + .07, crown, true);
      drawBox(scene, x, .045, z, w + .04, .11, d + .04, trim);
      if (r > .65) { drawBox(scene, x, h + .11, z, .16, .36, .16, trim); drawBox(scene, x + w * .15, h + .16, z, .11, .07, .08, redAccent); }
      if (r > .78) drawBox(scene, x, h + .2, z, .018, 1.1, .018, trim);
      if (r < .64) drawBox(scene, x, .08, z + d / 2 + .06, w * .85, .12, .18, crown);
    }
    // Non-interactive skyline outside the playable streets produces depth without expanding mission physics.
    const farMaterials = [makeMat('#111d2d'), makeMat('#152c3b'), makeMat('#1e2b3e')];
    const towerGeo = new THREE.BoxGeometry(1, 1, 1);
    for (let band = 0; band < 3; band++) {
      const matrices = [];
      for (let i = -22; i <= 22; i += 2) {
        for (const [x, z] of [[i, -12 - band * 3], [i, 12 + band * 3], [-12 - band * 3, i], [12 + band * 3, i]]) {
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
  function createCoolingProp(type, x, z) {
    const group = new THREE.Group(); group.position.set(x, 0, z);
    if (type === 'tree') {
      const trunk = makeMat('#8c6547'), leaf = [makeMat('#49ba80'), makeMat('#65d5a1'), makeMat('#2f9264')];
      const stem = new THREE.Mesh(new THREE.CylinderGeometry(.08, .12, .91, 10), trunk); stem.position.y = .46; group.add(stem);
      for (let i = 0; i < 8; i++) { const a = i * 2.399; const ball = new THREE.Mesh(new THREE.IcosahedronGeometry(.26 + (i % 3) * .06, 1), leaf[i % 3]); ball.position.set(Math.cos(a) * .29, 1.12 + (i % 3) * .17, Math.sin(a) * .27); group.add(ball); }
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
    scene.add(avatar); return avatar;
  }
  function addAtmosphere() {
    const sky = document.createElement('canvas'); sky.width = 16; sky.height = 512;
    const g = sky.getContext('2d'); const gr = g.createLinearGradient(0, 0, 0, 512);
    gr.addColorStop(0, '#030d1b'); gr.addColorStop(.45, '#0b2436'); gr.addColorStop(.73, '#40556b'); gr.addColorStop(1, '#ab7363');
    g.fillStyle = gr; g.fillRect(0, 0, 16, 512);
    const sphere = new THREE.Mesh(new THREE.SphereGeometry(84, 32, 20), new THREE.MeshBasicMaterial({ map: new THREE.CanvasTexture(sky), side: THREE.BackSide, fog: false, depthWrite: false }));
    sphere.scale.y = .77; scene.add(sphere);
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
      scene = new THREE.Scene(); scene.background = new THREE.Color(0x0b1c2c); scene.fog = new THREE.FogExp2(0x122536, .026);
      camera = new THREE.PerspectiveCamera(68, 1, .08, 100);
      renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance', alpha: false, stencil: false });
      renderer.outputColorSpace = THREE.SRGBColorSpace;
      renderer.toneMapping = THREE.ACESFilmicToneMapping;
      renderer.toneMappingExposure = 1.42;
      renderer.shadowMap.enabled = !mobile.matches;
      renderer.shadowMap.type = THREE.PCFSoftShadowMap;
      renderer.domElement.className = 'oc-render';
      renderer.domElement.setAttribute('aria-label', 'Живой 3D-мир. Иди клавишами WASD и вращай камеру мышью.');
      viewport.prepend(renderer.domElement);
      scene.add(new THREE.HemisphereLight(0xb2e6ff, 0x6e443f, 2.25));
      const key = new THREE.DirectionalLight(0xffcda3, 2.45); key.position.set(-10, 18, 6);
      key.castShadow = !mobile.matches; key.shadow.mapSize.set(1024, 1024);
      key.shadow.camera.left = key.shadow.camera.bottom = -12;
      key.shadow.camera.right = key.shadow.camera.top = 12;
      key.shadow.normalBias = .065; scene.add(key);
      const blueFill = new THREE.DirectionalLight(0x2e9fca, .9); blueFill.position.set(9, 7, -8); scene.add(blueFill);
      const plazaLight = new THREE.PointLight(0x43c9dd, 9, 9); plazaLight.position.set(0, 4, .7); scene.add(plazaLight);
      addAtmosphere(); addGround(); addCity(); makeHotMarkers(); makeAvatar();
      minimapCtx = $('oc-minimap').getContext('2d');
      world.ready = true; resize(); syncGame(); drawMiniMap();
      window.__ZION030_OPEN_CITY__ = {
        state: () => ({ ready: world.ready, active: world.active, player: { x: player.x, z: player.z }, mission: game()?.state(), quality: world.quality }),
        enter, exit, walk: (dx, dz) => { if (!collides(player.x + dx, player.z + dz)) { player.x += dx; player.z += dz; } },
        interact
      };
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
    const dpr = Math.min(window.devicePixelRatio || 1, mobile.matches ? 1.12 : world.gpuScale);
    renderer.setPixelRatio(dpr); renderer.setSize(w, h, false); camera.aspect = w / h; camera.updateProjectionMatrix();
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
    shell.querySelectorAll('[data-oc-tool]').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.ocTool === state.selected)));
    if (state.won && !$('oc-complete').dataset.dismissed) $('oc-complete').hidden = false;
    if (!state.won) { $('oc-complete').hidden = true; delete $('oc-complete').dataset.dismissed; }
    const dest = closest();
    targetIndex = dest?.i ?? -1;
    $('oc-target').textContent = dest ? dest.name.toUpperCase() : 'ВСЕ ЗОНЫ ОХЛАЖДЕНЫ';
    $('oc-distance').textContent = dest ? `${Math.max(0, Math.round(dest.dist * 12))} М ДО ЦЕЛИ` : 'Город стал зеленее';
    const near = dest && dest.dist <= 1.65 && !state.lost && !state.won;
    $('oc-interact').hidden = !near;
    $('oc-action').hidden = !near || !mobile.matches;
    if (near) $('oc-interact-text').textContent = `ОХЛАДИТЬ · ${TOOLS[state.selected].label.toUpperCase()}`;
    else if (state.lost) { $('oc-target').textContent = 'МОДУЛИ ЗАКОНЧИЛИСЬ'; $('oc-distance').textContent = 'На карте нажми «Заново»'; }
  }
  function drawMiniMap() {
    const g = minimapCtx; if (!g) return;
    const w = 230, h = 230, tile = 13.4, origin = (w - tile * 15) / 2;
    g.clearRect(0, 0, w, h);
    const grd = g.createLinearGradient(0, 0, w, h); grd.addColorStop(0, '#0b2a3b'); grd.addColorStop(1, '#041522');
    g.fillStyle = grd; g.fillRect(0, 0, w, h);
    for (let x = -7; x <= 7; x++) for (let z = -7; z <= 7; z++) {
      const px = origin + (x + 7) * tile, py = origin + (z + 7) * tile;
      g.fillStyle = occupied.has(`${x},${z}`) ? '#3b5867' : (Math.abs(x) <= 2 && Math.abs(z) <= 2 ? '#286778' : '#173b4c');
      g.fillRect(px + .5, py + .5, tile - 1, tile - 1);
    }
    const state = game()?.state();
    for (const [i, hspot] of HOT.entries()) {
      const cooled = state?.placed.some(m => Math.hypot(m.x - hspot.x, m.z - hspot.z) <= 1.35);
      const x = origin + (hspot.x + 7.5) * tile, y = origin + (hspot.z + 7.5) * tile;
      g.beginPath(); g.arc(x, y, i === targetIndex ? 7 : 5, 0, Math.PI * 2);
      g.fillStyle = cooled ? '#58ffd2' : '#ff784c'; g.fill(); g.lineWidth = 2; g.strokeStyle = '#fff'; g.stroke();
    }
    const px = origin + (player.x + 7.5) * tile, py = origin + (player.z + 7.5) * tile;
    g.save(); g.translate(px, py); g.rotate(player.yaw); g.beginPath(); g.moveTo(0, -10); g.lineTo(7, 7); g.lineTo(0, 4); g.lineTo(-7, 7); g.closePath();
    g.fillStyle = '#f2ffff'; g.shadowBlur = 10; g.shadowColor = '#60deef'; g.fill(); g.restore();
    g.fillStyle = '#86b8c4'; g.font = 'bold 12px system-ui'; g.fillText('N ↑', 10, 18);
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
    if (!world.active || !world.ready || !game()?.state()?.ready) return false;
    const s = game().state(), near = closest();
    if (!near || near.dist > 1.65 || s.won || s.lost) {
      $('oc-world-message').textContent = 'Подойди ближе к оранжевой зоне.';
      $('oc-world-message').classList.add('oc-visible');
      window.setTimeout(() => $('oc-world-message').classList.remove('oc-visible'), 1450);
      return false;
    }
    const ok = game().place(near.x, near.z, s.selected);
    if (ok) { soundSuccess(); syncGame(); drawMiniMap();
      $('oc-world-message').textContent = `✓ ${near.name}: ЗОНА ОХЛАЖДЕНА`;
      $('oc-world-message').classList.add('oc-visible');
      window.setTimeout(() => $('oc-world-message').classList.remove('oc-visible'), 1750);
      return true;
    }
    return false;
  }
  function move(dt, t) {
    let xx = ((keys.has('KeyD') || keys.has('ArrowRight')) ? 1 : 0) - ((keys.has('KeyA') || keys.has('ArrowLeft')) ? 1 : 0) + joystick.x;
    let yy = ((keys.has('KeyW') || keys.has('ArrowUp')) ? 1 : 0) - ((keys.has('KeyS') || keys.has('ArrowDown')) ? 1 : 0) - joystick.y;
    const length = Math.hypot(xx, yy);
    if (length > 1) { xx /= length; yy /= length; }
    const running = keys.has('ShiftLeft') || keys.has('ShiftRight');
    const spd = running ? 4.1 : 2.55, strafeX = Math.cos(player.cameraYaw), strafeZ = -Math.sin(player.cameraYaw);
    const fwdX = -Math.sin(player.cameraYaw), fwdZ = -Math.cos(player.cameraYaw);
    const dx = (fwdX * yy + strafeX * xx) * spd * dt;
    const dz = (fwdZ * yy + strafeZ * xx) * spd * dt;
    if (Math.abs(dx) + Math.abs(dz) > .0001) {
      const nx = player.x + dx, nz = player.z + dz;
      if (!collides(nx, player.z)) player.x = nx;
      if (!collides(player.x, nz)) player.z = nz;
      player.yaw = Math.atan2(dx, -dz);
    }
    player.speed += ((length > .12 ? 1 : 0) - player.speed) * clamp(dt * 13, 0, 1);
    player.moving = length > .12;
    const walk = Math.sin(t * (running ? 12 : 8)) * player.speed;
    legL.rotation.x = walk * .46; legR.rotation.x = -walk * .46;
    armL.rotation.x = -walk * .33; armR.rotation.x = walk * .33;
    avatar.position.set(player.x, Math.abs(Math.sin(t * 8)) * .027 * player.speed, player.z);
    avatar.rotation.y = player.yaw;
    const follow = mobile.matches ? 5.2 : 4.65;
    const dist = follow, pitch = player.pitch;
    const desired = new THREE.Vector3(player.x + Math.sin(player.cameraYaw) * Math.cos(pitch) * dist,
      1.25 + Math.sin(pitch) * dist, player.z + Math.cos(player.cameraYaw) * Math.cos(pitch) * dist);
    camera.position.lerp(desired, 1 - Math.exp(-dt * 9));
    camera.lookAt(player.x, 1.2, player.z);
    world.rings.forEach((r, i) => {
      const phase = reduceMotion.matches ? 0 : t * 2.2 + i;
      r.ring.scale.setScalar(1 + Math.sin(phase) * .06);
      r.tip.scale.setScalar(1.35 + Math.sin(phase) * .18);
      r.beacon.rotation.y = t;
      r.beacon.position.y = 1.83 + (reduceMotion.matches ? 0 : Math.sin(t * 2.4 + i) * .09);
    });
  }
  function frame(time) {
    if (!world.active || !world.ready) return;
    const dt = clamp((time - (world.last || time)) / 1000, 0, .06); world.last = time; world.frame++;
    move(dt, time * .001);
    if (world.frame % 9 === 0) { syncGame(); drawMiniMap(); }
    if (world.frame % 70 === 0) {
      if (world.fpsTime) {
        const fps = (world.frame - world.fpsFrames) * 1000 / (time - world.fpsTime);
        if (fps < 28 && world.gpuScale > .8) { world.gpuScale = Math.max(.8, world.gpuScale * .79); world.quality = 'adaptive'; resize(); }
      }
      world.fpsTime = time; world.fpsFrames = world.frame;
    }
    renderer.render(scene, camera);
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
    world.last = 0; keys.clear();
    syncGame(); resize(); drawMiniMap();
    if (animationId) window.cancelAnimationFrame(animationId);
    animationId = window.requestAnimationFrame(frame);
    $('oc-start-play').focus({ preventScroll: true });
  }
  function exit() {
    world.active = false; world.last = 0; keys.clear(); joystick.x = joystick.y = 0;
    if (animationId) window.cancelAnimationFrame(animationId); animationId = 0;
    stage.classList.remove('oc-stage-active'); document.body.classList.remove('oc-body-active');
    shell.hidden = true; button.textContent = '◈ ГУЛЯТЬ ПО ГОРОДУ · 3D';
    button.focus({ preventScroll: true });
    if (document.pointerLockElement === renderer?.domElement) document.exitPointerLock?.();
  }
  button.addEventListener('click', () => world.active ? exit() : enter());
  $('oc-exit').addEventListener('click', exit);
  $('oc-start-play').addEventListener('click', () => { $('oc-start').hidden = true; viewport.focus?.(); });
  $('oc-action').addEventListener('click', interact);
  $('oc-complete').addEventListener('click', e => { if (e.target === $('oc-complete')) $('oc-complete').hidden = true; });
  $('oc-keep-walking').addEventListener('click', () => { $('oc-complete').hidden = true; $('oc-complete').dataset.dismissed = 'true'; });
  $('oc-again').addEventListener('click', () => { game()?.reset?.(); $('oc-complete').hidden = true; delete $('oc-complete').dataset.dismissed; syncGame(); drawMiniMap(); });
  shell.querySelectorAll('[data-oc-tool]').forEach(b => b.addEventListener('click', () => { game()?.select(b.dataset.ocTool); syncGame(); }));
  window.addEventListener('keydown', e => {
    if (!world.active || $('oc-start').hidden === false || $('oc-complete').hidden === false) return;
    if (['KeyW', 'KeyA', 'KeyS', 'KeyD', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Space', 'KeyE', 'ShiftLeft', 'ShiftRight', 'Digit1', 'Digit2', 'Digit3'].includes(e.code)) {
      e.preventDefault(); e.stopImmediatePropagation();
    }
    keys.add(e.code);
    if (e.code === 'KeyE' || e.code === 'Enter' || e.code === 'Space') interact();
    if (['Digit1', 'Digit2', 'Digit3'].includes(e.code)) game().select(['tree', 'shade', 'water'][Number(e.code.slice(-1)) - 1]);
  }, true);
  window.addEventListener('keyup', e => { keys.delete(e.code); }, true);
  window.addEventListener('keydown', e => { if (world.active && e.key === 'Escape') { if ($('oc-start').hidden) exit(); else { $('oc-start').hidden = true; } } }, true);
  window.addEventListener('blur', () => keys.clear());
  viewport.addEventListener('pointerdown', e => {
    if (!world.active || !$('oc-start').hidden || !$('oc-complete').hidden) return;
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