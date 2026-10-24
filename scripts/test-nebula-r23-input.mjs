#!/usr/bin/env node
// Test the actual JavaScript emitted into the generated Godot HTML, not a
// disconnected mockup script. No WebGL renderer required to validate key
// translation, window capture, focus recovery and mobile viewport CSS.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const file = process.argv[2];
if (!file) throw new Error('usage: node scripts/test-nebula-r23-input.mjs <export/index.html>');
const html = fs.readFileSync(file,'utf8');
assert.match(html, /nebula-r23-physical-keyboard/);
assert.ok(html.indexOf('nebula-r23-physical-keyboard') < html.indexOf('</head>'),
  'R26 browser keyboard capture must register BEFORE the game engine JS');
assert.match(html, /touch-action:none/);
assert.match(html, /viewport-fit=cover/);
const match = html.match(/<script id="nebula-r23-physical-keyboard">([\s\S]*?)<\/script>/);
assert.ok(match, 'production HTML missing actual flight JS');
const listeners = new Map();
const node = {id:'canvas',focus(){doc.activeElement = this;}};
const doc = {
  visibilityState:'visible',hidden:false,
  activeElement:{id:'other'},
  getElementById(id){return id==='canvas'?node:null;},
  addEventListener(name,cb){listeners.set('document:'+name,cb);}
};
const win = {
  __nebulaPilotMask:0,
  addEventListener(name,cb){listeners.set('window:'+name,cb);}
};
vm.runInNewContext(match[1],{window:win,document:doc,console}, {timeout:2500});
function send(name,code,key,target={tagName:'CANVAS',isContentEditable:false}) {
  let prevented=false;
  const fn = listeners.get('window:'+name);
  assert.equal(typeof fn,'function');
  fn({code,key,target,preventDefault(){prevented=true;}});
  return prevented;
}
assert.equal(win.__nebulaPilotMask,0);
assert.equal(send('keydown','KeyW','ц'),true,'non-Latin layout must be handled by physical code');
assert.equal(win.__nebulaPilotMask,1,'pressed Russian W must feed positive thrust');
assert.equal(win.__nebulaKeyDebug.downs,1);
assert.equal(win.__nebulaKeyDebug.lastCode,'KeyW');
assert.equal(doc.activeElement,node,'window-level input must recover Godot canvas focus');
assert.equal(send('keydown','KeyD','в'),true);
assert.equal(win.__nebulaPilotMask,9,'W+D must work concurrently');
assert.equal(send('keyup','KeyW','ц'),true);
assert.equal(win.__nebulaPilotMask,8,'releasing W must preserve D');
send('keydown','Space',' ');
assert.equal(win.__nebulaPilotMask,520,'Space should trigger real firing bit');
send('keyup','KeyD','в');
send('keyup','Space',' ');
assert.equal(win.__nebulaPilotMask,0,'all key releases must stop steering/firing');
assert.equal(send('keydown','KeyW','w',{tagName:'INPUT',isContentEditable:false}),false);
assert.equal(win.__nebulaPilotMask,0,'do not steal keys while user types in an input');
send('keydown','KeyS','ы');
assert.equal(win.__nebulaPilotMask,2);
listeners.get('window:blur')();
assert.equal(win.__nebulaPilotMask,0,'window blur must stop thrust');
assert.equal(win.__nebulaKeyDebug.blurCount,1);
console.log('NEBULA_R23_DOM_INPUT_SUCCESS Cyrillic KeyW thrust, key combos, keyup, blur and input focus');
