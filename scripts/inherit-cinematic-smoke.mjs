import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
const read = name => readFileSync('public/games/inherit/' + name, 'utf8');
const html=read('index.html'), css=read('cinematic.css'), js=read('cinematic.js');
let tests=0;
function check(name,fn){fn();tests++;console.log('PASS',name)}
check('Cinematic modules are linked and preserve existing entrypoints',()=>{
 assert.match(html, /href="\.\/interface\.css"/);
 assert.match(html, /src="\.\/interface\.js"/);
 assert.match(html, /href="\.\/cinematic\.css"/);
 assert.match(html, /src="\.\/cinematic\.js"/);
 assert.match(html, /src="\.\/account\.js"/);
});
check('Cinematic source is valid JavaScript',()=>new vm.Script(js,{filename:'cinematic.js'}));
check('Existing gameplay mechanics remain in original HTML',()=>{
 for(const token of ['const initialWorld=','function blockWhileHandoff','function requestGenerationHandoff','window.InheritGame=','inherit-world-v1'])assert.ok(html.includes(token),token);
});
check('No remote libraries, payment changes or new persistence schema',()=>{
 assert.ok(!/https?:\/\//.test(js));
 assert.ok(!/(stripe|checkout|payments|webhook)/i.test(js));
 assert.ok(!js.includes('inherit-world-v1'));
});
check('Accessible quality toggle and closed utility panel',()=>{
 for(const token of ['aria-pressed','aria-expanded','aria-controls','aria-label','inert','Escape'])assert.ok(js.includes(token),token);
 assert.match(css,/prefers-reduced-motion:reduce/);
});
check('Responsive and power-saving renderer included',()=>{
 assert.match(css, /max-width:740px/);
 assert.match(css,/cine-eco/);
 assert.match(js,/requestAnimationFrame/);
 assert.match(js,/ResizeObserver/);
});
console.log('INHERIT cinematic static checks:',tests,'passed');
