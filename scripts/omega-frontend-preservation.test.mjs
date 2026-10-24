import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync, writeFileSync, mkdirSync, mkdtempSync, rmSync, existsSync, statSync } from 'node:fs'
import { createHash } from 'node:crypto'
import { join } from 'node:path'
import { tmpdir } from 'node:os'
import { spawnSync } from 'node:child_process'

const helper='scripts/preserve-omega-native.sh'
const frontend=readFileSync('scripts/activate-frontend-remote.sh','utf8')
const direct=readFileSync('scripts/deploy-omega-native-remote.sh','utf8')
const workflow=readFileSync('.github/workflows/deploy-frontend.yml','utf8')
const required=['index.html','index.js','index.wasm','index.pck','release.json']
function sandbox(attested=true){
  const root=mkdtempSync(join(tmpdir(),'osgard-omega-preserve-'))
  const active=join(root,'live','games','omega-3d-preview')
  const candidate=join(root,'candidate','html','games','omega-3d-preview')
  mkdirSync(active,{recursive:true});mkdirSync(candidate,{recursive:true})
  for(const name of required){
    const data=name==='release.json'?JSON.stringify({engine:'Godot 4.4.1',artifact_kind:'native-Godot-HTML5-export',source_commit:'r10-trusted'}):'LIVE-R10-'+name
    writeFileSync(join(active,name),data)
    writeFileSync(join(candidate,name),'STALE-R9-'+name)
  }
  if(attested){
    const sums=required.map(name=>createHash('sha256').update(readFileSync(join(active,name))).digest('hex')+'  '+name).join('\n')+'\n'
    writeFileSync(join(active,'SHA256SUMS.txt'),sums)
  }
  return {root,active,candidate,cleanup:()=>rmSync(root,{recursive:true,force:true})}
}
function run(s){return spawnSync('sh',[helper,s.active,s.candidate],{encoding:'utf8',timeout:5000})}

test('full site keeps exactly verified running R10 instead of bundled stale R9',()=>{
 const s=sandbox()
 try{
   const process=run(s)
   assert.equal(process.status,0,process.stderr)
   assert.match(process.stdout,/PASS: preserved current SHA-attested native Omega/)
   for(const name of required)assert.deepEqual(readFileSync(join(s.candidate,name)),readFileSync(join(s.active,name)))
   assert.ok(statSync(join(s.candidate,'index.wasm')).size>0)
   assert.ok(existsSync(join(s.candidate,'SHA256SUMS.txt')))
   const check=spawnSync('sha256sum',['-c','SHA256SUMS.txt'],{cwd:s.candidate,encoding:'utf8'})
   assert.equal(check.status,0,check.stderr)
 }finally{s.cleanup()}
})
test('no previously attested game keeps the frontend candidate as provided',()=>{
 const s=sandbox(false)
 try{
   const x=run(s)
   assert.equal(x.status,0,x.stderr)
   assert.match(readFileSync(join(s.candidate,'index.pck'),'utf8'),/^STALE-R9/)
   assert.equal(existsSync(join(s.candidate,'SHA256SUMS.txt')),false)
 }finally{s.cleanup()}
})
test('tampered live WebAssembly blocks frontend activation without replacing candidate',()=>{
 const s=sandbox()
 try{
   writeFileSync(join(s.active,'index.wasm'),'MALICIOUS-WASM')
   const x=run(s)
   assert.notEqual(x.status,0,'tampered live game must fail closed')
   assert.match(readFileSync(join(s.candidate,'index.wasm'),'utf8'),/^STALE-R9/)
   assert.equal(existsSync(join(s.candidate,'SHA256SUMS.txt')),false)
 }finally{s.cleanup()}
})
test('invalid game and unsafe symlink must be rejected without data loss',()=>{
 const s=sandbox()
 try{
   rmSync(join(s.active,'index.pck'))
   const x=run(s)
   assert.notEqual(x.status,0,'invalid full game cannot be marked preserved')
   assert.match(readFileSync(join(s.candidate,'index.js'),'utf8'),/^STALE-R9/)
 }finally{s.cleanup()}
})
test('both SSH paths share one trusted host lock, and frontend seals the candidate before swap',()=>{
 assert.match(frontend,/acquire_activation_lock/)
 assert.match(frontend,/osgard-frontend-activation\.lock/)
 assert.match(direct,/osgard-frontend-activation\.lock/)
 assert.match(direct,/flock -w 600 9/)
 assert.match(direct,/exec 9>>"\$lock_path"/)
 const preserve=frontend.indexOf('sh /tmp/osgard-gh-next/preserve-omega-native.sh')
 const swap=frontend.indexOf('mv /usr/share/nginx/html /tmp/osgard-gh-previous')
 assert.ok(preserve>0 && preserve<swap,'copy latest verified game before replacing active root')
 assert.match(frontend,/sha256sum -c SHA256SUMS\.txt/)
 assert.match(workflow,/cp scripts\/preserve-omega-native\.sh osgard-release\/preserve-omega-native\.sh/)
 assert.match(workflow,/node --test scripts\/omega-frontend-preservation\.test\.mjs/)
})
