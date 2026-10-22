import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
const read=name=>readFileSync('public/games/inherit/'+name,'utf8');
const html=read('index.html'),script=read('living-legacy.js'),style=read('living-legacy.css'),art=read('living-legacy-sprites.svg'),sw=read('sw.js');
let checks=0;
function check(title,fn){fn();checks++;console.log('PASS',title);}
check('Game entrypoint loads living UI after previous systems',()=>{
 assert.match(html,/<link rel="stylesheet" href="\.\/living-legacy\.css"/);
 assert.match(html,/<script defer src="\.\/living-legacy\.js"/);
 assert.ok(html.indexOf('living-legacy.js')>html.indexOf('generation-atlas.js'));
});
check('New renderer parses as JavaScript',()=>new vm.Script(script,{filename:'living-legacy.js'}));
check('Native tools are all illustrated with original sprites',()=>{
 for(const type of ['tree','stone','light','path','flower','arch','chime','moss','cairn','marker']){
  assert.ok(art.includes('id="'+type+'"'),type);
 }
});
check('No game world, account data, or payment writes in UI',()=>{
 assert.doesNotMatch(script,/\.apply\s*\(|\.saveDraft\s*\(|\bpersist\s*\(|\.setMode\s*\(|\.pending\.push\s*\(|\bfetch\s*\(/);
 assert.doesNotMatch(script,/stripe|checkout|payment|telemetry/i);
});
check('Native gameplay handlers and primary pass button preserved',()=>{
 for(const token of ['id="world"','id="island"','id="pass"','id="budget"','id="gen"','window.InheritGame=','function requestGenerationHandoff'])assert.ok(html.includes(token),token);
});
check('Readable touch controls and small screen layout',()=>{
 for(const token of ['max-width:740px','max-width:420px','min-height:66px','font-size:calc','focus-visible'])assert.ok(style.includes(token),token);
});
check('Accessible menu, fonts, reduced motion and placement preview',()=>{
 for(const token of ['aria-live','aria-current','aria-pressed','Escape','pointermove','living-placement-preview'])assert.ok(script.includes(token),token);
 assert.match(style,/prefers-reduced-motion:reduce/);
});
check('Offline shell contains every new game resource',()=>{
 for(const file of ['living-legacy.js','living-legacy.css','living-legacy-sprites.svg'])assert.ok(sw.includes(file),file);
 assert.match(sw,/inherit-shell-v26/);
 assert.match(sw,/webmanifest\|mjs\|js\|css\|svg\|woff2\?/);
});
check('New presentation remains multilingual',()=>{for(const lang of ['ru:','en:','zh:'])assert.ok(script.includes(lang),lang)});
check('Original saving and gameplay modes remain independent',()=>{
 assert.ok(script.includes('window.InheritGame.snapshot()'));
 assert.ok(script.includes('accountMode?.()'));
 assert.ok(script.includes('replay-mode'));
});
console.log('INHERIT living legacy static smoke checks:',checks,'passed');
