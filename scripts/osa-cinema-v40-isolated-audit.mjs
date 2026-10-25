/**
 * OSA CINEMA V40: bounded, cancellable subprocess bridge for V38.
 * The parent owner desk never passes its login password to the subprocess.
 * No private paths on argv; strict stdout limit; fail closed on signals/crashes.
 */
import { spawn } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const WORKER=fileURLToPath(new URL('./osa-cinema-v40-audit-worker.mjs',import.meta.url))
const MAX_BYTES=16384
const ALLOWED=new Set(['repoRoot','receiptsDir','mastersDir','captionsDir',
  'registryPath','registrySha256','attestationsPath','evidenceDir'])
const fail = () => Error('OSA_V40_ISOLATED_HOLD: private audit was cancelled or rejected')

function limitedEnvironment() {
  // Node does not inherit NODE_OPTIONS, login credentials, tokens, SSH or CI secrets.
  const vars=['PATH','SystemRoot','WINDIR','ComSpec','PATHEXT','TEMP','TMP','TMPDIR',
    'HOME','HOMEDRIVE','HOMEPATH','LANG','LC_ALL','TZ']
  const safe={}
  for(const key of vars) if(typeof process.env[key]==='string')safe[key]=process.env[key]
  return safe
}

/** workerPath is an internal test seam only; the CLI never accepts a worker path. */
export function runIsolatedPrivateAudit(options,{signal,workerPath=WORKER}={}) {
  return new Promise((accept,reject)=>{
    if(signal?.aborted){reject(fail());return}
    if(!options || typeof options!=='object' || Array.isArray(options) ||
       Object.keys(options).some(k=>!ALLOWED.has(k))) {reject(fail());return}
    const encoded=Buffer.from(JSON.stringify(options),'utf8')
    if(encoded.length===0 || encoded.length>8192){reject(fail());return}
    let child
    try {
      child=spawn(process.execPath,[workerPath],{
        env:limitedEnvironment(),stdio:['pipe','pipe','pipe'],windowsHide:true,
      })
    } catch{reject(fail());return}
    let settled=false,output='',oversized=false,aborted=false
    const stop=()=>{aborted=true;try{child.kill('SIGKILL')}catch{}}
    const finish=(err,result)=>{
      if(settled)return
      settled=true
      signal?.removeEventListener('abort',stop)
      if(err)reject(fail());else accept(result)
    }
    signal?.addEventListener('abort',stop,{once:true})
    if(signal?.aborted)stop()
    child.stdout.on('data',chunk=>{
      if(oversized)return
      if(Buffer.byteLength(output,'utf8')+chunk.length>MAX_BYTES){
        oversized=true;stop();return
      }
      output+=chunk.toString('utf8')
    })
    // Deliberately discard any worker stderr: may contain private system errors.
    child.stderr.on('data',()=>{})
    child.stdin.on('error',()=>{})
    child.once('error',()=>finish(true))
    child.once('close',code=>{
      if(aborted || oversized || code!==0)return finish(true)
      try {
        const data=JSON.parse(output.trim())
        if(!data || typeof data!=='object' || Array.isArray(data))return finish(true)
        finish(null,data)
      }catch{finish(true)}
    })
    child.stdin.end(encoded)
  })
}
