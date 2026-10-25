#!/usr/bin/env node
// Execute the REAL exported R35 safe-area script. Native Godot geometry
// regression then proves that these values keep all nine buttons reachable.
// Synthetic safe-area values are deliberately only used for unit testing;
// they are never misrepresented as measurements from a physical iPhone.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const file = process.argv[2];
if (!file) throw new Error('usage: node scripts/test-nebula-r35-safe-area.mjs <Godot index.html>');
const html = fs.readFileSync(file,'utf8');
const tag='nebula-r35-safe-area';
assert.ok(html.indexOf(tag) >= 0 && html.indexOf(tag) < html.indexOf('</head>'),
  'safe-area probe must register before Godot Web renderer');
const match=html.match(/<script id="nebula-r35-safe-area">([\s\S]*?)<\/script>/);
assert.ok(match, 'missing embedded source for browser safe area');
const winHandlers=new Map(),docHandlers=new Map(),visualHandlers=new Map();
let geometry={left:0,top:0,right:0,bottom:0};
let removed=0,append=0;
const fakeDoc={
  hidden:false, documentElement:{appendChild(){append++;}},
  createElement(){return {style:{cssText:''},remove(){removed++;}};},
  addEventListener(name,callback){docHandlers.set(name,callback);}
};
const fakeWin={
  visualViewport:{addEventListener(name,callback){visualHandlers.set(name,callback);}},
  addEventListener(name,callback){winHandlers.set(name,callback);},
  getComputedStyle(){return {
    paddingLeft:String(geometry.left)+'px',
    paddingTop:String(geometry.top)+'px',
    paddingRight:String(geometry.right)+'px',
    paddingBottom:String(geometry.bottom)+'px'
  };}
};
vm.runInNewContext(match[1],{window:fakeWin,document:fakeDoc,console,Number,
  Object,Math}, {timeout:3000});
const safe=fakeWin.__nebulaSafeArea;
assert.deepEqual([safe.left,safe.top,safe.right,safe.bottom,safe.seq],
  [0,0,0,0,0], 'ordinary rectangular browser needs no invented insets');
geometry={left:59,top:0,right:59,bottom:21};
winHandlers.get('orientationchange')();
assert.deepEqual([safe.left,safe.top,safe.right,safe.bottom,safe.seq],
  [59,0,59,21,1], 'landscape cutout must be read from CSS env()');
winHandlers.get('resize')();
assert.equal(safe.seq,1,'unchanged insets must not trigger layout thrashing');
geometry={left:0,top:62,right:0,bottom:34};
visualHandlers.get('resize')();
assert.deepEqual([safe.left,safe.top,safe.right,safe.bottom,safe.seq],
  [0,62,0,34,2], 'portrait notch and home gesture bar detected');
geometry={left:-20,top:Infinity,right:180,bottom:0};
docHandlers.get('DOMContentLoaded')();
assert.deepEqual([safe.left,safe.top,safe.right,safe.bottom],
  [0,0,96,0], 'browser-provided values must be sanitized/clamped');
assert.equal(append,removed,'measurement probe must not leak DOM elements');
fakeDoc.hidden=true;
const lastSeq=safe.seq;
docHandlers.get('visibilitychange')();
assert.equal(safe.seq,lastSeq,'hidden tabs must not change live touch layout');
console.log('NEBULA_R35_SAFE_AREA_JS_SUCCESS CSS env measurement, notch, portrait, resize, clamp, no DOM leaks');
