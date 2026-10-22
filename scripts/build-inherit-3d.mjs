// Self-contained, reproducible Three.js bundle for /games/inherit.
// No runtime CDN. `npm run build` generates this before Vite copies public assets.
// --check validates the complete WebGL source graph without writing to public/.
import {build} from 'esbuild';
import {statSync} from 'node:fs';
const check=process.argv.includes('--check');
const outfile='public/games/inherit/aaa-three.bundle.js';
const result=await build({
 entryPoints:['scripts/inherit-3d/aaa-three-entry.mjs'],
 outfile,
 bundle:true,
 minify:true,
 platform:'browser',
 format:'iife',
 target:['es2022'],
 treeShaking:true,
 legalComments:'none',
 sourcemap:false,
 write:!check,
 logLevel:'warning'
});
const size=check?(result.outputFiles?.[0]?.contents?.byteLength||0):statSync(outfile).size;
if(size<100000||size>2500000)throw Error('Unexpected offline WebGL engine size '+size+' bytes');
console.log(check?'PASS INHERIT R16 Three.js bundle validation':'BUILT INHERIT R16 standalone WebGL bundle',size,'bytes; no external imports');
