/**
 * OSA CINEMA V30: signer-controlled, OFFLINE Ed25519 approval statement creation.
 * A signature proves key control, never legal correctness or film release approval.
 */
import { createPrivateKey, sign } from 'node:crypto'
import { readFile, lstat, open, writeFile, mkdir } from 'node:fs/promises'
import { constants } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { signedMessage } from './osa-cinema-v30-external-attestations.mjs'

async function privateRead(path,limit){
  const stat=await lstat(path)
  if(!stat.isFile()||stat.isSymbolicLink()||stat.size<1||stat.size>limit)throw Error('Unsafe file for offline signature')
  const fd=await open(path,constants.O_RDONLY|(constants.O_NOFOLLOW||0))
  try{return await fd.readFile()}finally{await fd.close()}
}
export function makeSignedApproval(statement,privateKeyPem){
  if(!statement||typeof statement!=='object'||Array.isArray(statement)||
    Object.hasOwn(statement,'signature'))throw Error('Provide an unsigned statement only')
  const a={...statement,signature:''}
  const bytes=signedMessage(a)
  let key;try{key=createPrivateKey(privateKeyPem)}catch{throw Error('Invalid private Ed25519 key')}
  if(key.asymmetricKeyType!=='ed25519')throw Error('Only Ed25519 private keys supported')
  a.signature=sign(null,bytes,key).toString('base64')
  return a
}
async function main(args){
  const opts={}
  for(let i=0;i<args.length;i++){
    const k=args[i],v=args[++i]
    if(!['--statement','--private-key','--out'].includes(k)||!v||opts[k])throw Error('Expected --statement --private-key --out')
    opts[k]=v
  }
  if(!['--statement','--private-key','--out'].every(x=>opts[x]))throw Error('Required flags missing')
  const statement=JSON.parse((await privateRead(opts['--statement'],8192)).toString('utf8'))
  const key=await privateRead(opts['--private-key'],8192)
  const signed=makeSignedApproval(statement,key)
  const target=resolve(opts['--out'])
  if([opts['--statement'],opts['--private-key']].some(x=>resolve(x)===target))throw Error('Cannot overwrite unsigned statement or private key')
  await mkdir(dirname(target),{recursive:true,mode:0o700})
  await writeFile(target,JSON.stringify(signed,null,2)+'\n',{flag:'wx',mode:0o600})
  console.log('OSA_V30_OFFLINE_SIGNATURE_CREATED '+JSON.stringify({keyId:signed.keyId,gate:signed.gate,publicationAuthorized:false}))
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url))
  main(process.argv.slice(2)).catch(e=>{console.error('OSA_V30_SIGN_FAILED '+e.message);process.exitCode=1})
