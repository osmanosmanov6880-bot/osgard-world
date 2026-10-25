/**
 * OSA CINEMA V34: offline publisher-authenticity verification for a CODE-ONLY ZIP.
 * A SHA256 inside a ZIP is not a signature. This verifier requires an Ed25519
 * signature and an independently known SHA256 pin of the publisher's public key.
 * Film rights, identity vetting, human approvals and public release stay NO-GO.
 */
import { constants } from 'node:fs'
import { lstat, open } from 'node:fs/promises'
import { createHash, createPublicKey, verify } from 'node:crypto'
import { basename, dirname, isAbsolute, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const HASH = /^[0-9a-f]{64}$/
const BASE64_SIG = /^[A-Za-z0-9+/]{86}==$/
const KEY_MAX = 8192
const DOCUMENT_MAX = 8192
const ARCHIVE_MAX = 512 * 1024 * 1024
const PURPOSE = 'OSA_CINEMA_CODE_ARCHIVE_ONLY'
const STRICT_FIELDS = new Set([
  'schemaVersion','algorithm','purpose','archiveName','sha256','signature',
  'publicationAuthorized','rightsCleared','paidCheckoutEnabled','releaseDecision',
])
const digest = bytes => createHash('sha256').update(bytes).digest('hex')
function requireThat(ok,why){if(!ok)throw Error('OSA_V34_VERIFY_REJECTED: '+why)}

async function safeOrdinaryFile(filename,label,limit){
  requireThat(typeof filename==='string'&&isAbsolute(filename)&&!filename.includes('\0'),label+': absolute local path required')
  const target=resolve(filename)
  for(let current=target;;current=dirname(current)){
    const stat=await lstat(current)
    requireThat(!stat.isSymbolicLink(),label+': symlinked path rejected')
    requireThat(current===target?stat.isFile():stat.isDirectory(),label+': expected regular file and parent folders')
    if(dirname(current)===current)break
  }
  const st=await lstat(target)
  requireThat(st.size>0&&st.size<=limit,label+': empty or oversized input')
  const fd=await open(target,constants.O_RDONLY|(constants.O_NOFOLLOW||0))
  return {target,fd,stat:st}
}
function sameFile(a,b){
  return a.dev===b.dev&&a.ino===b.ino&&a.size===b.size&&a.mtimeMs===b.mtimeMs&&a.ctimeMs===b.ctimeMs
}
async function readSmall(filename,label,max){
  const source=await safeOrdinaryFile(filename,label,max)
  try{
    const before=await source.fd.stat()
    requireThat(sameFile(before,source.stat),label+': changed before read')
    const contents=await source.fd.readFile()
    const after=await source.fd.stat()
    requireThat(sameFile(before,after)&&contents.length===before.size,label+': modified during read')
    return contents
  }finally{await source.fd.close()}
}
async function hashArchive(filename,maxBytes){
  const source=await safeOrdinaryFile(filename,'ZIP archive',maxBytes)
  try{
    const before=await source.fd.stat()
    requireThat(sameFile(before,source.stat),'ZIP archive changed before read')
    const sha=createHash('sha256')
    let read=0
    let header='' 
    const stream=source.fd.createReadStream({autoClose:false,highWaterMark:256*1024})
    for await(const chunk of stream){
      if(!header)header=chunk.subarray(0,4).toString('hex')
      read+=chunk.length;requireThat(read<=maxBytes,'ZIP exceeds safe bound');sha.update(chunk)
    }
    requireThat(header==='504b0304','not a nonempty ZIP local-file archive')
    const after=await source.fd.stat()
    requireThat(sameFile(before,after)&&read===before.size,'ZIP changed during verification')
    return {sha256:sha.digest('hex'),size:read}
  }finally{await source.fd.close()}
}

/** Testable signing message. ONLY the digest of the separately supplied ZIP is signed. */
export function archiveSigningMessage(archiveName,sha256){
  requireThat(typeof archiveName==='string'&&archiveName.endsWith('.zip')&&
    archiveName===basename(archiveName)&&/^[A-Za-z0-9][A-Za-z0-9._-]{1,179}\.zip$/.test(archiveName)&&!archiveName.includes('\\')&&
    !/[\r\n]/.test(archiveName)&&HASH.test(sha256), 'invalid archive signing message')
  return Buffer.from(`OSA-CINEMA-CODE-ARCHIVE-V1\n${archiveName}\n${sha256}\n`,'utf8')
}
/**
 * trustedKeySha256 MUST come from an independent owner-approved channel.
 * Taking it from a ZIP, its README, or the same signature JSON defeats trust.
 */
export async function verifyDetachedArchive({archivePath,signaturePath,publicKeyPath,trustedKeySha256,maxArchiveBytes=ARCHIVE_MAX}={}){
  requireThat(typeof trustedKeySha256==='string'&&HASH.test(trustedKeySha256),
    'independent 64-character lowercase publisher key fingerprint is mandatory')
  requireThat(Number.isSafeInteger(maxArchiveBytes)&&maxArchiveBytes>0&&maxArchiveBytes<=ARCHIVE_MAX,
    'invalid archive size limit')
  const pem=await readSmall(publicKeyPath,'Publisher public key',KEY_MAX)
  requireThat(/^-----BEGIN PUBLIC KEY-----\r?\n/.test(pem.toString('ascii'))&&
    /-----END PUBLIC KEY-----\s*$/.test(pem.toString('ascii')),
    'only public PEM may be supplied; private key files are prohibited')
  let key
  try{key=createPublicKey(pem)}catch{throw Error('OSA_V34_VERIFY_REJECTED: invalid publisher public key')}
  requireThat(key.asymmetricKeyType==='ed25519','only Ed25519 publisher public keys are accepted')
  const pubDer=key.export({type:'spki',format:'der'})
  const actualPin=digest(pubDer)
  requireThat(actualPin===trustedKeySha256,'publisher key is not independently trusted (pin mismatch)')
  let doc
  try{doc=JSON.parse((await readSmall(signaturePath,'Detached signature JSON',DOCUMENT_MAX)).toString('utf8'))}
  catch(e){if(String(e.message).startsWith('OSA_V34_VERIFY_REJECTED'))throw e;throw Error('OSA_V34_VERIFY_REJECTED: invalid signature JSON')}
  requireThat(doc&&typeof doc==='object'&&!Array.isArray(doc)&&Object.keys(doc).length===STRICT_FIELDS.size&&
    Object.keys(doc).every(k=>STRICT_FIELDS.has(k)), 'invalid or extra signature metadata fields')
  requireThat(doc.schemaVersion===1&&doc.algorithm==='Ed25519'&&doc.purpose===PURPOSE&&
    doc.publicationAuthorized===false&&doc.rightsCleared===false&&
    doc.paidCheckoutEnabled===false&&doc.releaseDecision==='NO_GO',
    'detached signature is for code integrity only, never public release')
  requireThat(doc.archiveName===basename(archivePath)&&HASH.test(doc.sha256),'wrong archive identity or SHA256 field')
  requireThat(typeof doc.signature==='string'&&BASE64_SIG.test(doc.signature),
    'Ed25519 signature must be strict padded base64')
  const signature=Buffer.from(doc.signature,'base64')
  requireThat(signature.length===64&&signature.toString('base64')===doc.signature,
    'noncanonical Ed25519 signature encoding')
  const archive=await hashArchive(archivePath,maxArchiveBytes)
  requireThat(archive.sha256===doc.sha256,'archive SHA256 mismatch')
  requireThat(verify(null,archiveSigningMessage(doc.archiveName,doc.sha256),key,signature),
    'digital signature did not verify with trusted publisher key')
  return Object.freeze({schemaVersion:1,archiveName:doc.archiveName,archiveBytes:archive.size,
    archiveSha256:archive.sha256,trustedPublisherKeySha256:actualPin,signatureVerified:true,
    packageAuthenticityVerified:true,publicationAuthorized:false,rightsCleared:false,
    paidCheckoutEnabled:false,releaseDecision:'NO_GO',
    note:'Publisher authenticity is for code ZIP only. It does NOT prove film rights, production readiness, or authority to launch.'})
}

function parseArgs(argv){
  requireThat(argv[0]==='verify','use: verify --archive ZIP --signature SIG_JSON --public-key PUB_PEM --trusted-key-sha256 HEX')
  const options={}
  for(let i=1;i<argv.length;i+=2){
    const key=argv[i],value=argv[i+1]
    requireThat(['--archive','--signature','--public-key','--trusted-key-sha256'].includes(key)&&
      value&&!options[key],'invalid or duplicate argument')
    options[key]=value
  }
  requireThat(Object.keys(options).length===4,'all four verification arguments are required')
  return {archivePath:options['--archive'],signaturePath:options['--signature'],
    publicKeyPath:options['--public-key'],trustedKeySha256:options['--trusted-key-sha256']}
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  (async()=>{
    const result=await verifyDetachedArchive(parseArgs(process.argv.slice(2)))
    console.log(JSON.stringify(result,null,2))
    console.log('OSA CINEMA: authentic code archive. Public film and payment: NO-GO.')
  })().catch(err=>{console.error(err.message);process.exitCode=1})
}
