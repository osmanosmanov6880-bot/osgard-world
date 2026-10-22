// Byte-identical production verification for the INHERIT Living Legacy release.
// Run only after the SSH activation step, never as a mock success assertion.
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {join} from 'node:path';
const root='public/games/inherit';
const items=['index.html','living-legacy.js','living-legacy.css','living-legacy-sprites.svg'];
const origin=(process.env.OSGARD_BASE_URL||'https://osgard.world').replace(/\/+$/,'');
const version=(process.env.GITHUB_SHA||'release').slice(0,12);
const sha=b=>createHash('sha256').update(b).digest('hex');
function pause(ms){return new Promise(resolve=>setTimeout(resolve,ms))}
async function verify(name){
  const local=readFileSync(join(root,name));
  const expected=sha(local);
  const url=origin+'/games/inherit/'+name+'?release='+encodeURIComponent(version);
  let reason='No successful response';
  for(let attempt=1;attempt<=4;attempt++){
    try{
      const response=await fetch(url,{cache:'no-store',headers:{'cache-control':'no-cache'},signal:AbortSignal.timeout(15000)});
      if(!response.ok)throw Error('HTTP '+response.status+' '+url);
      const body=Buffer.from(await response.arrayBuffer());
      const got=sha(body);
      if(got!==expected)throw Error(name+' mismatch: expected '+expected+', published '+got);
      console.log('PASS',name,'sha256='+got);
      return;
    }catch(error){reason=error.message;console.error('ATTEMPT '+attempt+' '+name+': '+reason);if(attempt<4)await pause(3000)}
  }
  throw Error('R14 public file validation failed: '+reason);
}
for(const name of items)await verify(name);
console.log('INHERIT Living Legacy: all original release files byte-identical on production.');
