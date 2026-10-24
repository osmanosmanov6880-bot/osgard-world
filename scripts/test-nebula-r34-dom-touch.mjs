#!/usr/bin/env node
// Unit-test the ACTUAL injected production DOM touch bridge in the generated
// Godot HTML. This covers bridge bookkeeping; the separate browser E2E proves
// real mobile touch -> actual Godot acceleration.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const filename = process.argv[2];
if (!filename) throw new Error('Expected generated Godot index.html');
const html = fs.readFileSync(filename, 'utf8');
assert.ok(html.includes('nebula-r34-touch-bridge'), 'R34 touch bridge missing');
assert.ok(html.indexOf('nebula-r34-touch-bridge') < html.indexOf('</head>'),
  'DOM touch capture must precede the Godot engine scripts');
const match = html.match(/<script id="nebula-r34-touch-bridge">([\s\S]*?)<\/script>/);
assert.ok(match, 'Cannot find embedded DOM touch source');

const listeners = new Map();
const docListeners = new Map();
const canvas = {
  id:'canvas', contains: target => target === canvas,
  getBoundingClientRect: () => ({left:10,top:25,width:390,height:844})
};
const document = {
  hidden:false,
  getElementById: key => key === 'canvas' ? canvas : null,
  addEventListener: (name,cb) => docListeners.set(name,cb)
};
const window = { addEventListener: (name,cb) => listeners.set(name,cb) };
// R36: same monotonic browser clock drives event timestamps used by Godot.
let monotonicMs = 1000;
const performance = {now:() => {monotonicMs += 7;return monotonicMs;}};
vm.runInNewContext(match[1],
  {window,document,console,Map,Array,Number,performance},
  {timeout:3000});
const state = window.__nebulaDomTouchState;
assert.equal(state.seq,0);
assert.equal(state.points.length,0);

let prevented = 0;
function touch(type,contacts,target=canvas) {
  const callback = listeners.get(type);
  assert.equal(typeof callback,'function',type+' listener');
  callback({
    target,cancelable:true,changedTouches:contacts.map(([id,x,y])=>({
      identifier:id,clientX:x+10,clientY:y+25
    })),preventDefault(){prevented++;}
  });
}
touch('touchstart',[[1,327,772]]);
assert.equal(state.last_event_ms,1007,
  'R36 real DOM touch timestamp must use monotonic performance.now');
assert.equal(state.downs,1);
assert.equal(state.points.length,1);
assert.equal(state.points[0][1],327);
assert.equal(state.points[0][2],772);
touch('touchstart',[[2,239,772]]);
assert.equal(state.downs,2);
assert.equal(state.points.length,2,'both independent fingers remain held');
touch('touchmove',[[1,319,740]]);
assert.equal(state.moves,1);
assert.ok(state.last_event_ms > 1007,
  'R36 touch drag must publish a new monotonic dispatch timestamp');
assert.equal(state.points[0][1],319,'finger drag updates current position');
touch('touchend',[[1,319,740]]);
assert.equal(state.ups,1);
assert.equal(state.points.length,1,'lifting first finger must preserve boost');
touch('touchstart',[[3,1,1]],{id:'other'});
assert.equal(state.downs,2,'do not steal browser touches outside canvas');
touch('touchcancel',[[2,239,772]]);
assert.equal(state.points.length,0,'OS touchcancel clears held controls');
assert.equal(state.cancels,1);
touch('touchstart',[[7,327,772]]);
listeners.get('blur')();
assert.equal(state.points.length,0,'focus loss cannot leave GAS stuck');
assert.equal(state.blurClears,1);
touch('touchstart',[[8,327,772]]);
listeners.get('resize')();
assert.equal(state.points.length,0,'rotation/resize clears obsolete contacts');
assert.equal(prevented,7,'recognized touch events block browser scrolling');
console.log('NEBULA_R34_DOM_TOUCH_SOURCE_SUCCESS two-finger holds, movement, release, cancel, blur, resize, scroll prevention');
