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
if (!html.includes('touch-action:none') || !html.includes('viewport-fit=cover')) {
  throw new Error('R21 mobile CSS or responsive viewport not installed');
}
fs.writeFileSync(file,html);
console.log('NEBULA_R21_MOBILE_SHELL_SUCCESS touch-action canvas 100dvh viewport-fit=cover');
