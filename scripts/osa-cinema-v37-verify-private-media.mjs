/**
 * OSA CINEMA V37 - read-only, streaming byte verification of four PRIVATE final
 * MP4 and four WebVTT candidates against V28 manifest after V36 receipt audit.
 * No publication, rights clearance, payments, or editorial sign-off is possible.
 */
import { createHash } from 'node:crypto'
import { constants } from 'node:fs'
import { lstat, open, readdir } from 'node:fs/promises'
import { dirname, isAbsolute, join, resolve, sep } from 'node:path'
import { fileURLToPath } from 'node:url'
import { verifyPrivateReceiptDirectory } from './osa-cinema-v36-verify-private-receipts.mjs'

const MANIFEST = 'V28_CANDIDATE_MANIFEST.json'
const INVENTORY = 'CHECKSUMS.sha256'
const MAX_MP4 = 32 * 1024 ** 3
const MAX_VTT = 16 * 1024 ** 2
const MAX_REPORT = 2_000_000
const SHA = /^[0-9a-f]{64}$/
const FILE = /^osa-[a-z0-9-]{3,70}\.(?:mp4|vtt)$/
const NO_GO = Object.freeze({ publicationAuthorized: false, rightsCleared: false, paidCheckoutEnabled: false })
const digest = input => createHash('sha256').update(input).digest('hex')
const insist = (condition, reason) => { if (!condition) throw Error('OSA_V37_PRIVATE_MEDIA_HOLD: ' + reason) }
const exactNames = (observed, expected) => observed.length === expected.length &&
  new Set(observed).size === expected.length && expected.every(x => observed.includes(x))
const inside = (a,b) => a === b || a.startsWith(b + sep)

function checkPathInput(path, label) {
  insist(typeof path === 'string' && isAbsolute(path), label + ' requires an absolute local path')
  insist(!/^(?:[/\\]{2}|\\\\\?\\)/.test(path), label + ' cannot be a UNC/device path')
  return resolve(path)
}
async function privateDirectory(path, label) {
  const target = checkPathInput(path, label)
  for (let p=target;;p=dirname(p)) {
    const st = await lstat(p)
    insist(st.isDirectory() && !st.isSymbolicLink(), label + ' has a linked or invalid directory')
    if(p === target && process.platform !== 'win32')
      insist((st.mode & 0o077) === 0, label + ' must be owner-private (chmod 700)')
    if (p===dirname(p)) break
  }
  return target
}
async function checkedFile(path, {label, expectedSize=null, maximum, collectPrefix=0}) {
  const before = await lstat(path)
  insist(before.isFile() && !before.isSymbolicLink(), label + ' must be a regular non-linked file')
  insist(before.nlink===1, label + ' cannot be hard-linked')
  insist(before.size>0 && Number.isSafeInteger(before.size) && before.size<=maximum,
    label + ' has empty, oversized, or unsafe byte length')
  if (expectedSize !== null) insist(before.size===expectedSize,label + ' byte length differs from V28')
  if(process.platform !== 'win32') insist((before.mode & 0o077)===0,label + ' must have private file permissions')
  const fd = await open(path, constants.O_RDONLY | (constants.O_NOFOLLOW || 0))
  try {
    const initial=await fd.stat()
    insist(initial.isFile() && initial.dev===before.dev && initial.ino===before.ino &&
      initial.size===before.size && initial.nlink===1,label + ' changed before read')
    const h = createHash('sha256'), block = Buffer.allocUnsafe(128 * 1024)
    let total=0, prefix=Buffer.alloc(0)
    while(total < initial.size) {
      const count=Math.min(block.length, initial.size-total)
      const got=await fd.read(block,0,count,total)
      insist(got.bytesRead>0,label + ' truncated during verification')
      const piece=block.subarray(0,got.bytesRead)
      h.update(piece)
      if (prefix.length < collectPrefix) {
        const needed=collectPrefix-prefix.length
        prefix=Buffer.concat([prefix,piece.subarray(0,needed)])
      }
      total+=got.bytesRead
    }
    const after=await fd.stat()
    insist(total===initial.size && after.size===initial.size &&
      after.ino===initial.ino && after.dev===initial.dev && after.nlink===1 &&
      after.mtimeMs===initial.mtimeMs && after.ctimeMs===initial.ctimeMs,
      label + ' changed while hashing')
    return { sha256:h.digest('hex'),bytes:total,prefix }
  } finally { await fd.close() }
}

/** One reproducible CLI run verifies these media bytes. Returns NO_GO forever. */
export async function verifyPrivateMediaBytes({receiptsDir, mastersDir, captionsDir}) {
  const receipts=await privateDirectory(receiptsDir,'Receipt folder')
  const masters=await privateDirectory(mastersDir,'Master video folder')
  const captions=await privateDirectory(captionsDir,'Caption folder')
  insist(!inside(receipts,masters) && !inside(masters,receipts) &&
    !inside(receipts,captions) && !inside(captions,receipts) &&
    !inside(masters,captions) && !inside(captions,masters),
    'all three private roots must be separate non-nested folders')

  // Existing V36 revalidates report fingerprints, file inventory, and NO-GO.
  const receiptsCheck=await verifyPrivateReceiptDirectory({directory:receipts})
  insist(receiptsCheck.reportSelfConsistent === true && receiptsCheck.decision==='NO_GO' &&
    receiptsCheck.publicationAuthorized === false && receiptsCheck.paidCheckoutEnabled === false,
    'V36 receipt audit did not pass privately')

  const inventory=await checkedFile(join(receipts,INVENTORY),{label:'V29 checksum list',maximum:2048})
  const checksumText=inventory.prefix.length ? inventory.prefix.toString('utf8') :
    (await readStrictSmall(join(receipts,INVENTORY))).toString('utf8')
  const entry=checksumText.split(/\r?\n/).filter(Boolean)
    .map(line=>/^([0-9a-f]{64})  ([A-Z0-9_]+\.json)$/.exec(line))
    .find(x=>x?.[2]===MANIFEST)
  insist(entry && SHA.test(entry[1]), 'V28 report digest missing in validated checksum inventory')
  const raw=await readStrictSmall(join(receipts,MANIFEST))
  insist(digest(raw)===entry[1], 'V28 report changed after V36 validation')
  let v28;try{v28=JSON.parse(raw.toString('utf8'))}
  catch{throw Error('OSA_V37_PRIVATE_MEDIA_HOLD: unreadable V28 manifest')}
  const assets=v28.assets
  insist(Array.isArray(assets) && assets.length===4,'V28 must list four editions')
  const videoNames=assets.map(a=>a.masterName)
  const captionNames=assets.map(a=>a.captionName)
  insist(videoNames.every(x=>FILE.test(x) && x.endsWith('.mp4')) &&
    captionNames.every(x=>FILE.test(x) && x.endsWith('.vtt')),
    'V28 has unsafe candidate filenames')
  insist(exactNames(await readdir(masters),videoNames),'video folder must contain only the four declared MP4s')
  insist(exactNames(await readdir(captions),captionNames),'caption folder must contain only the four declared VTTs')
  const result=[]
  for(const a of assets) {
    insist(SHA.test(a.masterSha256||'') && SHA.test(a.captionSha256||'') &&
      Number.isSafeInteger(a.masterBytes) && a.masterBytes>0 && a.masterBytes<=MAX_MP4,
      'V28 contains invalid or unsafe byte targets')
    const media=await checkedFile(join(masters,a.masterName),{
      label:'Private MP4 '+a.id,expectedSize:a.masterBytes,maximum:MAX_MP4})
    insist(media.sha256===a.masterSha256,'MP4 bytes do not match V28 for '+a.id)
    const caption=await checkedFile(join(captions,a.captionName),{
      label:'Private WebVTT '+a.id,maximum:MAX_VTT,collectPrefix:32768})
    insist(caption.sha256===a.captionSha256,'WebVTT bytes do not match V28 for '+a.id)
    let head='';try{head=new TextDecoder('utf-8',{fatal:true}).decode(caption.prefix,{stream:true})}
    catch{throw Error('OSA_V37_PRIVATE_MEDIA_HOLD: invalid UTF-8 caption prefix for '+a.id)}
    insist(/^\uFEFF?WEBVTT(?:[ \t]|\r?\n)/.test(head) &&
      /\b\d{2}:\d{2}:\d{2}\.\d{3}\s+-->\s+\d{2}:\d{2}:\d{2}\.\d{3}\b/.test(head),
      'WebVTT needs a header and timed cue for '+a.id)
    result.push({id:a.id,edition:a.edition,locale:a.locale,
      mp4Bytes:media.bytes,captionBytes:caption.bytes,bytesMatched:true})
  }
  return Object.freeze({schemaVersion:1,project:'OSA CINEMA',stage:'V37_PRIVATE_MEDIA_BYTE_AUDIT',
    verifiedPrivateVideoFiles:4,verifiedPrivateCaptionFiles:4,bytesMatched:true,
    checkedWebvttHeadersAndFirstCues:true,
    reportPackageSelfConsistent:receiptsCheck.reportSelfConsistent,
    publisherIdentityIndependentlyAuthenticated:false,
    humanSpokenLanguageChecked:false,subtitleSyncHumanApproved:false,
    legalRightsIndependentlyCleared:false,productionHttpsAndDevicesVerified:false,
    privateMediaMayBeShownToOwnerOnly:true,
    publicationAuthorized:false,rightsCleared:false,paidCheckoutEnabled:false,
    publicCatalogueWriteAllowed:false,productionDeploymentPerformed:false,
    decision:'NO_GO',perEdition:result,
    notice:'Local byte agreement is not publisher authentication, editorial approval, legal rights or public release.'})
}
async function readStrictSmall(path){
  const v=await checkedFile(path,{label:'V28 historical receipt',maximum:MAX_REPORT,collectPrefix:MAX_REPORT})
  return v.prefix
}

async function main(args) {
  insist(args.length===6,'usage: --receipts-dir DIR --masters-dir DIR --captions-dir DIR')
  const options={}
  for(let i=0;i<args.length;i+=2){
    const flag=args[i],value=args[i+1]
    insist(['--receipts-dir','--masters-dir','--captions-dir'].includes(flag)&&
      typeof value==='string' && !value.startsWith('--') && !Object.hasOwn(options,flag),
      'invalid or repeated V37 CLI argument')
    options[flag]=value
  }
  insist(Object.keys(options).length===3,'three private directories required')
  const v=await verifyPrivateMediaBytes({
    receiptsDir:options['--receipts-dir'], mastersDir:options['--masters-dir'],
    captionsDir:options['--captions-dir']})
  console.log(JSON.stringify(v,null,2))
  console.log('OSA CINEMA V37: eight private files verified. PUBLIC FILM AND PAYMENT STILL NO-GO.')
}
if(process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2)).catch(e=>{console.error(e.message);process.exitCode=1})
}
