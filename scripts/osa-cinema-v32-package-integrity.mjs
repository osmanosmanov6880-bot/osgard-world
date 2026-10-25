/** Offline archive integrity checks. These checks detect accidental/tampered bytes;
 * they do not authenticate the publisher of a newly obtained ZIP.
 */
import { createHash } from 'node:crypto'
import { constants } from 'node:fs'
import { readFile, lstat, open, readdir } from 'node:fs/promises'
import { resolve, join, dirname, sep } from 'node:path'
import { fileURLToPath } from 'node:url'
const HASH_LINE=/^([a-f0-9]{64})  ([A-Za-z0-9._/-]+)$/
const isSafePath=path=>!path.startsWith('/')&&!path.endsWith('/')&&!path.includes('\\')&&
  path.split('/').every(seg=>seg&&seg!=='.'&&seg!=='..')
const digest=bytes=>createHash('sha256').update(bytes).digest('hex')
export async function verifyPackage({root,minFiles=40}={}){
  if(!root)throw Error('Package root is required')
  const base=resolve(root)
  // An apparently real extraction folder may live below a symlinked parent.
  for(let part=base;;part=dirname(part)){
    const st=await lstat(part)
    if(st.isSymbolicLink()||!st.isDirectory())throw Error('Symlinked or unsafe package ancestor: '+part)
    if(dirname(part)===part)break
  }
  const baseStat=await lstat(base)
  if(!baseStat.isDirectory()||baseStat.isSymbolicLink())throw Error('Package root must be a real directory')
  const manifest=join(base,'CHECKSUMS.sha256')
  const stat=await lstat(manifest)
  if(!stat.isFile()||stat.isSymbolicLink()||stat.size===0||stat.size>200_000)throw Error('Unsafe SHA256 manifest')
  const lines=(await readFile(manifest,'utf8')).trim().split(/\r?\n/)
  if(lines.length<minFiles||lines.length>500)throw Error('Incomplete or implausible package inventory')
  const paths=new Set(), knownDirs=new Set()
  let totalBytes=0
  for(const line of lines){
    const found=line.match(HASH_LINE)
    if(!found||!isSafePath(found[2])||found[2]==='CHECKSUMS.sha256'||paths.has(found[2]))
      throw Error('Unsafe, repeated or invalid checksum manifest path')
    paths.add(found[2])
    const parts=found[2].split('/')
    for(let k=1;k<parts.length;k++)knownDirs.add(parts.slice(0,k).join('/'))
    let folder=base
    for(const segment of parts.slice(0,-1)){
      folder=join(folder,segment)
      const dir=await lstat(folder)
      if(!dir.isDirectory()||dir.isSymbolicLink())throw Error('Unsafe package directory: '+found[2])
    }
    const file=join(base,...parts)
    const st=await lstat(file)
    if(!st.isFile()||st.isSymbolicLink()||st.size>50_000_000)throw Error('Unsafe package file: '+found[2])
    const fd=await open(file,constants.O_RDONLY|(constants.O_NOFOLLOW||0))
    let bytes=0
    const hash=createHash('sha256')
    try{
      const stream=fd.createReadStream({autoClose:false,highWaterMark:256*1024})
      for await (const chunk of stream){hash.update(chunk);bytes+=chunk.length}
      const after=await fd.stat()
      if(!after.isFile()||after.size!==st.size||bytes!==st.size||st.mtimeMs!==after.mtimeMs)
        throw Error('Package file changed during verification: '+found[2])
    }finally{await fd.close()}
    if(hash.digest('hex')!==found[1])throw Error('SHA256 mismatch: '+found[2])
    totalBytes+=bytes
  }
  // A modified archive may carry an injected file outside CHECKSUMS.sha256, even when all
  // listed files still match. Refuse unlisted files and links before launching Node scripts.
  async function inventory(dir,prefix=''){
    for(const ent of await readdir(dir,{withFileTypes:true})){
      const relativePath=prefix?prefix+'/'+ent.name:ent.name
      if(relativePath==='CHECKSUMS.sha256')continue
      if(ent.isSymbolicLink() || (!ent.isFile()&&!ent.isDirectory()))
        throw Error('Unsafe or unlisted package entry: '+relativePath)
      if(ent.isDirectory()){
        if(!knownDirs.has(relativePath))throw Error('Unlisted package directory: '+relativePath)
        await inventory(join(dir,ent.name),relativePath)
      }
      else if(!paths.has(relativePath))throw Error('Unlisted package entry: '+relativePath)
    }
  }
  await inventory(base)
  return {verifiedFiles:paths.size,verifiedBytes:totalBytes,integrityVerified:true,
    publicationAuthorized:false,rightsCleared:false,paidCheckoutEnabled:false,
    note:'Checksum verification does not establish legal rights or software publisher identity.'}
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  const root=process.argv.length===3?process.argv[2]:new URL('..',import.meta.url).pathname
  verifyPackage({root}).then(r=>{
    console.log('OSA CINEMA PACKAGE OK: '+r.verifiedFiles+' files / '+r.verifiedBytes+' bytes. PRIVATE ONLY / NO-GO')
  }).catch(err=>{console.error('OSA CINEMA PACKAGE VERIFICATION FAILED: '+err.message);process.exitCode=1})
}
