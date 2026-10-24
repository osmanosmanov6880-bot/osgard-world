#!/usr/bin/env node
// R21: patch the *generated* Godot HTML on every CI export. Never hand-edit
// production index.html, because the native exporter overwrites it.
import fs from 'node:fs';
import path from 'node:path';

const folder = process.argv[2];
if (!folder) throw new Error('Expected Web export directory');
const file = path.join(folder, 'index.html');
let html = fs.readFileSync(file,'utf8');
if (!html.includes('<canvas id="canvas">')) throw new Error('Godot canvas missing');
html = html.replace(
  /<meta name="viewport" content="[^"]*">/,
  '<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover, maximum-scale=1.0, user-scalable=no">'
);
const mobileCss = `
/* R21 mobile: real full-viewport WebGL game rather than letterboxed desktop
   canvas. Godot canvasResizePolicy=2 still owns its internal pixel resolution. */
html,body{width:100%;height:100%;height:100dvh;overscroll-behavior:none}
#canvas{display:block;width:100vw;height:100vh;height:100dvh;touch-action:none;outline:none}
@supports(height:100svh){#canvas{height:100svh}}
body{padding:0;overflow:hidden;-webkit-user-select:none;user-select:none}
#status{font-family:Inter,system-ui,-apple-system,"Segoe UI",sans-serif}
`;
if (!html.includes('R21 mobile: real full-viewport WebGL game')) {
  if (!html.includes('</style>')) throw new Error('Godot export CSS missing');
  html = html.replace('</style>', mobileCss + '\n</style>');
}
html = html.replace('<canvas id="canvas">',
 '<canvas id="canvas" tabindex="0" aria-label="NEBULA: пилотирование космического корабля">');
// R22: a browser canvas with tabIndex is not *focused* automatically by
// tabindex. Without focus, W/A/S/D can appear nonfunctional even when the
// underlying Godot physical spacecraft correctly moves during native tests.
// Focus after loader is visible, on first pointer event, and after tab resume.
const focusScript = `
<script id="nebula-r22-keyboard-focus">
(() => {
  const canvas = document.getElementById("canvas");
  if (!canvas) return;
  const takeFocus = () => {
    if (document.visibilityState === 'visible' &&
        document.activeElement !== canvas) {
      try { canvas.focus({preventScroll: true}); }
      catch (_) { canvas.focus(); }
    }
  };
  canvas.addEventListener('pointerdown', takeFocus, {passive: true});
  canvas.addEventListener('touchstart', takeFocus, {passive: true});
  window.addEventListener('load', takeFocus, {once: true});
  document.addEventListener('visibilitychange', () => {
    if (!document.hidden && document.hasFocus()) takeFocus();
  });
  if (document.readyState === 'complete') takeFocus();
})();
</script>`;
// R23: capture physical KeyboardEvent.code at WINDOW level so Russian/other
// letter layouts and Godot WebGL canvas focus cannot silently disable thrust.
// Godot reads this single bitfield once per physics tick. Never synthesize
// fake key events; this is a direct, stable real-user keyboard bridge.
const pilotScript = `
<script id="nebula-r23-physical-keyboard">
(() => {
  const bits = {
    KeyW:1, KeyS:2, KeyA:4, KeyD:8, KeyE:16, KeyQ:32,
    ArrowUp:64, ArrowDown:128, ShiftLeft:256, ShiftRight:256,
    Space:512
  };
  window.__nebulaPilotMask = 0;
  window.__nebulaKeyDebug = {downs:0, ups:0, lastCode:'', lastTarget:'', blurCount:0};
  const wantsTyping = (event) => {
    const el = event.target;
    return el && (el.isContentEditable ||
      ['INPUT','TEXTAREA','SELECT'].includes(el.tagName));
  };
  const onKey = (event, pressed) => {
    if (wantsTyping(event)) return;
    const bit = bits[event.code];
    if (!bit) return;
    if (pressed) window.__nebulaKeyDebug.downs++;
    else window.__nebulaKeyDebug.ups++;
    window.__nebulaKeyDebug.lastCode = event.code;
    window.__nebulaKeyDebug.lastTarget = event.target?.tagName || 'unknown';
    if (pressed) window.__nebulaPilotMask |= bit;
    else window.__nebulaPilotMask &= ~bit;
    // Prevent WASD and the space bar moving the web page instead of the ship.
    if (document.visibilityState === 'visible') event.preventDefault();
    if (pressed && document.activeElement?.id !== 'canvas') {
      document.getElementById('canvas')?.focus({preventScroll:true});
    }
  };
  window.addEventListener('keydown', (e) => onKey(e,true), {capture:true});
  window.addEventListener('keyup', (e) => onKey(e,false), {capture:true});
  window.addEventListener('blur', () => {
    window.__nebulaKeyDebug.blurCount++;
    window.__nebulaPilotMask = 0;
  });
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) window.__nebulaPilotMask = 0;
  });
})();
</script>`;
if (!html.includes('nebula-r23-physical-keyboard')) {
  // The previous bridge was added at </body>, *after* index.js registered
  // Godot/engine keyboard listeners. If those capture/stop the event first,
  // even a window-level handler added later never sees W on the Web canvas.
  // Install before the first Godot script while the parser is still in head.
  const openHead = html.match(/<head(?:\\s[^>]*)?>/i);
  if (!openHead) throw new Error('Godot HTML head missing');
  html = html.replace(openHead[0],openHead[0] + '\n' + pilotScript);
}
if (!html.includes('nebula-r22-keyboard-focus')) {
  if (!html.includes('</body>')) throw new Error('Godot export body missing');
  html = html.replace('</body>', focusScript + '\n</body>');
}
if (!html.includes('touch-action:none') ||
    !html.includes('viewport-fit=cover') ||
    !html.includes('nebula-r22-keyboard-focus') ||
    !html.includes('nebula-r23-physical-keyboard') ||
    !html.includes('nebulaKeyDebug') ||
    html.indexOf('nebula-r23-physical-keyboard') > html.indexOf('</head>')) {
  throw new Error('R21 mobile CSS or responsive viewport not installed');
}
fs.writeFileSync(file,html);
console.log('NEBULA_R23_WEB_INPUT_SUCCESS physical keycode capture, WASD Cyrillic-independent + mobile fullscreen shell');
