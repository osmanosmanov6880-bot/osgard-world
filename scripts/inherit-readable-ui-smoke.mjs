/* Readable INHERIT is part of the game, not a decorative mockup. */
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
const read=name=>readFileSync('public/games/inherit/'+name,'utf8');
const css=read('readable-ui.css'),js=read('readable-ui.js'),
  html=read('index.html'),sw=read('sw.js');
let passed=0;
function check(label,fn){fn();passed++;console.log('PASS '+label)}
check('new presentation JS parses without touching the game engine',()=>{
 new vm.Script(js,{filename:'readable-ui.js'});
 for(const forbidden of ['fetch(', 'navigator.sendBeacon', 'InheritGame.apply(', '.saveDraft(',
 'gameStorage.setItem(', 'innerHTML=', 'window.InheritGame.place(', '#pass).click(']){
   assert.ok(!js.includes(forbidden),'side effect: '+forbidden);
 }
});
check('the readable styles load last, after all optional game art/UI modules',()=>{
 const link='<link rel="stylesheet" href="./readable-ui.css">';
 const script='<script defer src="./readable-ui.js"></script>';
 assert.equal(html.split(link).length,2);
 assert.equal(html.split(script).length,2);
 assert.ok(html.indexOf(link)>html.indexOf('memory-expeditions.css'));
 assert.ok(html.indexOf(script)>html.indexOf('memory-expeditions.js'));
});
check('offline cache v25 includes both readability files and old game features',()=>{
 assert.match(sw,/inherit-shell-v25/);
 for(const file of ['readable-ui.css','readable-ui.js','index.html','first-steps.js','generation-atlas.js']){
   assert.ok(sw.includes('/games/inherit/'+file),'missing offline resource '+file);
 }
});
check('critical buttons are at least 16px and pass CTA 18px by default',()=>{
 assert.match(css,/font-size:calc\(16px \* var\(--inherit-readable-scale\)\)!important/);
 assert.match(css,/\.dock #pass/);
 assert.match(css,/font-size:calc\(18px \* var\(--inherit-readable-scale\)\)!important/);
 assert.match(css,/min-height:60px/);
});
check('cinematic title and caption are visibly bigger than microtext',()=>{
 assert.match(css,/\.world>.hero h1/);
 assert.match(css,/49px \* var\(--inherit-readable-scale\)/);
 assert.match(css,/\.world>.hero p/);
 assert.match(css,/19px \* var\(--inherit-readable-scale\)/);
 assert.match(css,/\.world>.hint/);
});
check('default readable mode and additional 118% A+ mode are both explicit',()=>{
 assert.match(css,/:root\{--inherit-readable-scale:1/);
 assert.match(css,/data-inherit-text-size="extra"/);
 assert.match(css,/--inherit-readable-scale:1\.18/);
 assert.ok(js.includes("const storageKey='inherit:text-preference:v1'"));
});
check('A+ is an accessible keyboard-native, opt-in button with local-only preference',()=>{
 assert.ok(js.includes("el('button','inherit-text-toggle')"));
 assert.ok(js.includes("button.type='button'"));
 assert.ok(js.includes("aria-pressed"));
 assert.ok(js.includes("window.localStorage?.setItem(storageKey,'extra')"));
 assert.ok(!js.includes('sessionStorage'));
});
check('game instructions remain linked to real pending/changes/generation state',()=>{
 for(const fragment of [
  "window.InheritGame?.snapshot?.()","s.pending>0||s.changes>0?3:selected?2:1",
  "s.generation!==lastGeneration","query of ['#objects','#budget','#gen']",
  "aria-current","dataset.current"
 ])assert.ok(js.includes(fragment),'missing real UI state: '+fragment);
 assert.ok(!js.includes("setInterval"));
});
check('account world cannot be mistaken for permission to place',()=>{
 assert.ok(js.includes("get('mode')==='account'"));
 assert.ok(js.includes("window.InheritAccount?.isAccountMode?.()"));
 assert.ok(js.includes("rail.hidden=isAccount"));
});
check('RU EN ZH labels are complete and map to three actual actions',()=>{
 for(const lang of ['ru:{','en:{','zh:{'])assert.ok(js.includes(lang));
 for(const text of ['Выбери предмет','Поставь на остров','Передай поколение',
 'Choose an object','Place it on the island','Pass the generation',
 '选择物件','放到岛上','传承世代'])assert.ok(js.includes(text));
 assert.ok(read('interface.js').includes('window.InheritReadableUI?.refresh?.()'));
});
check('mobile rules do not rely on tiny controls or a hidden call to action',()=>{
 for(const media of ['max-width:1240px','max-width:850px','max-width:740px','max-width:460px'])
   assert.ok(css.includes(media));
 assert.match(css,/\.dock\.cine-dock #pass/);
 assert.match(css,/min-height:64px/);
 assert.match(css,/\.inherit-readable-step:not\(\[data-current=true\]\)\{display:none\}/);
});
check('all dialogs, onboarding, status and menus get large text and visible focus',()=>{
 for(const selector of ['body dialog','body .inherit-first-steps','body .cine-utility',
 'body .inherit-cycle-journal','body .inherit-guide','focus-visible','prefers-reduced-motion:reduce'])
   assert.ok(css.includes(selector));
 assert.match(css,/dialog:not\(\[open\]\)\{display:none!important\}/);
});
console.log('INHERIT READABLE UI:',passed,'passed');