/**
 * OSA CINEMA V30: verify eight independent, exact-hash, Ed25519 attestations.
 * This checks only cryptographic integrity of owner-supplied statements and PDFs.
 * It NEVER validates legal merit, authorizes publication or triggers deployment.
 */
import { createHash, createPublicKey, verify as cryptoVerify } from 'node:crypto'
import { constants } from 'node:fs'
import { lstat, open, mkdir, writeFile } from 'node:fs/promises'
import { dirname, resolve, join, basename, sep } from 'node:path'
import { fileURLToPath } from 'node:url'
import { EXTERNAL_GATES } from './osa-cinema-v27-release-board.mjs'

const SHA = /^[a-f0-9]{64}$/
const KEYID = /^[a-z][a-z0-9-]{3,63}$/
const FILENAME = /^[A-Za-z0-9_-]{3,90}\.pdf$/
const PREFIX = 'OSA-CINEMA-V30-EXTERNAL-APPROVAL\n'
const EXACT_SLOTS = new Set(['directors-workprint:ru', 'directors-workprint:en', 'trailer-workprint:ru', 'trailer-workprint:en'])
const APPROVAL_KEYS = ['schemaVersion','project','releaseFingerprint','gate','keyId','evidenceFile','evidenceSha256','decision','signedAt','expiresAt']
const signable = a => Object.fromEntries(APPROVAL_KEYS.map(k => [k,a[k]]))
const sha256 = b => createHash('sha256').update(b).digest('hex')
const assert = (yes,msg) => { if(!yes) throw Error(msg) }
function exactly(o,keys){
  return !!o && typeof o === 'object' && !Array.isArray(o) &&
    Object.keys(o).length === keys.length && keys.every(k => Object.hasOwn(o,k))
}

export function releaseFingerprint(preflight){
  assert(preflight?.schemaVersion===1 && preflight.project==='OSA CINEMA' &&
    preflight.stage==='V29_PRIVATE_OWNER_PREFLIGHT' && preflight.result==='NO_GO',
    'Expected exact V29 private NO_GO report')
  assert(preflight.candidatePinnedToPreviousHash === true &&
    preflight.publicationAuthorized===false && preflight.rightsCleared===false &&
    preflight.paidCheckoutEnabled===false && preflight.publicCatalogueWriteAllowed===false &&
    preflight.productionDeploymentPerformed===false,
    'Unpinned or falsely approved V29 preflight')
  assert(preflight.technical?.mastersPassed===4 && preflight.technical.privateHttpPassed===4 &&
    preflight.technical.evidenceTechnicallyComplete===true &&
    Number.isSafeInteger(preflight.technical.evidenceDocumentsVerified) &&
    preflight.technical.evidenceDocumentsVerified>0,
    'Four real technical candidates and rights document bytes are required')
  assert(Array.isArray(preflight.blockers) &&
    preflight.blockers.length===EXTERNAL_GATES.length &&
    new Set(preflight.blockers).size===EXTERNAL_GATES.length &&
    preflight.blockers.every(x=>EXTERNAL_GATES.includes(x)),
    'Additional technical blockers or missing external gates')
  assert(Array.isArray(preflight.independentExternalAuthorizationsOutstanding) &&
    preflight.independentExternalAuthorizationsOutstanding.length===EXTERNAL_GATES.length &&
    preflight.independentExternalAuthorizationsOutstanding.every((x,i)=>x===EXTERNAL_GATES[i]),
    'V29 external gate registry was changed')
  assert(Array.isArray(preflight.candidateAssets) && preflight.candidateAssets.length===4,
    'Four distinct final candidates required')
  const seen = new Set(), ids = new Set(), mediaHashes = new Set(), captionHashes = new Set()
  const assets=preflight.candidateAssets.map(a=>{
    assert(exactly(a,['id','locale','edition','finalSha256','captionSha256']) &&
      /^[a-z0-9-]{7,90}$/.test(a.id) && ['ru','en'].includes(a.locale) &&
      EXACT_SLOTS.has(a.edition+':'+a.locale) && SHA.test(a.finalSha256) &&
      SHA.test(a.captionSha256), 'Invalid final MP4/VTT binding')
    seen.add(a.edition+':'+a.locale)
    assert(!ids.has(a.id),'Duplicate final edition ID')
    ids.add(a.id)
    assert(!mediaHashes.has(a.finalSha256) && !captionHashes.has(a.captionSha256), 'Duplicated MP4 or caption bytes across releases')
    mediaHashes.add(a.finalSha256);captionHashes.add(a.captionSha256)
    return {id:a.id,edition:a.edition,locale:a.locale,finalSha256:a.finalSha256,captionSha256:a.captionSha256}
  }).sort((a,b)=>a.id.localeCompare(b.id))
  assert(seen.size===4,'Incomplete RU/EN full and trailer slots')
  const fp=preflight.fingerprints
  assert(fp && ['v28','v24','v25','v27'].every(k=>SHA.test(fp[k])) &&
    Array.isArray(fp.v26) && fp.v26.length===4 && fp.v26.every(v=>SHA.test(v)),
    'Exact V28/V24/V25/V26/V27 report fingerprints required')
  return sha256(JSON.stringify({schemaVersion:1,project:'OSA CINEMA',assets,
    fingerprints:{v28:fp.v28,v24:fp.v24,v25:fp.v25,v26:fp.v26,v27:fp.v27}}))
}

export function signedMessage(attestation){
  assert(exactly(attestation,[...APPROVAL_KEYS,'signature']),'Unexpected or missing attestation fields')
  assert(attestation.schemaVersion===1 && attestation.project==='OSA CINEMA' &&
    attestation.decision==='approved' && SHA.test(attestation.releaseFingerprint) &&
    SHA.test(attestation.evidenceSha256) && EXTERNAL_GATES.includes(attestation.gate) &&
    KEYID.test(attestation.keyId) && FILENAME.test(attestation.evidenceFile) &&
    basename(attestation.evidenceFile)===attestation.evidenceFile,
    'Invalid exact-hash approval statement')
  return Buffer.from(PREFIX+JSON.stringify(signable(attestation)),'utf8')
}

function parseDate(value){
  assert(typeof value==='string' && /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$/.test(value),
    'Approval must use UTC ISO millisecond time')
  const n=Date.parse(value)
  assert(Number.isFinite(n) && new Date(n).toISOString()===value, 'Invalid UTC date')
  return n
}

export function validateTrustedRegistry(registry){
  assert(exactly(registry,['schemaVersion','project','signers']) &&
    registry.schemaVersion===1 && registry.project==='OSA CINEMA' &&
    Array.isArray(registry.signers) && registry.signers.length===8,
    'Untrusted registry must list exactly eight external roles')
  const keys=new Map(), roles=new Set(), ids=new Set(), publicKeyFingerprints=new Set()
  for(const s of registry.signers){
    assert(exactly(s,['gate','keyId','publicKeyPem']) && EXTERNAL_GATES.includes(s.gate) &&
      !roles.has(s.gate) && KEYID.test(s.keyId) && !ids.has(s.keyId) &&
      typeof s.publicKeyPem==='string' && s.publicKeyPem.length<2000,
      'Duplicate or invalid trusted public-key identity')
    let key;try{key=createPublicKey(s.publicKeyPem)}catch{throw Error('Invalid trusted signer PEM')}
    assert(key.asymmetricKeyType==='ed25519','Only Ed25519 signer keys accepted')
    const fingerprint=sha256(key.export({type:'spki',format:'der'}))
    assert(!publicKeyFingerprints.has(fingerprint),'Multiple roles cannot share one cryptographic signer')
    publicKeyFingerprints.add(fingerprint)
    roles.add(s.gate);ids.add(s.keyId);keys.set(s.gate,{keyId:s.keyId,key})
  }
  assert(roles.size===EXTERNAL_GATES.length,'All external signoff roles required')
  return keys
}

async function safeRead(path,maxBytes){
  const st=await lstat(path)
  assert(st.isFile() && !st.isSymbolicLink() && st.size>0 && st.size<=maxBytes,
    'Unsafe, empty or oversized owner-only source file')
  const fd=await open(path,constants.O_RDONLY|(constants.O_NOFOLLOW||0))
  try{
    const now=await fd.stat()
    assert(now.isFile() && now.size===st.size,'Input changed while being opened')
    const bytes=await fd.readFile()
    assert(bytes.length===now.size, 'Source truncated while reading')
    return bytes
  }finally{await fd.close()}
}
async function safeJson(path){
  const bytes=await safeRead(path,1_000_000)
  let obj;try{obj=JSON.parse(bytes.toString('utf8'))}catch{throw Error('Invalid private JSON')}
  return {bytes,obj}
}

export async function verifyExternalAttestations({preflight,registry,registrySha256,attestations,evidenceDir,now=Date.now()}){
  assert(SHA.test(registrySha256||''),'Trusted registry digest must be pinned out-of-band')
  const release=releaseFingerprint(preflight)
  const keys=validateTrustedRegistry(registry)
  assert(exactly(attestations,['schemaVersion','project','approvals']) &&
    attestations.schemaVersion===1 && attestations.project==='OSA CINEMA' &&
    Array.isArray(attestations.approvals), 'Invalid external approvals collection')
  const seen=new Set(),paths=new Set(), results=[]
  for(const a of attestations.approvals){
    signedMessage(a)
    assert(!seen.has(a.gate),'Duplicate external role approval')
    assert(!paths.has(a.evidenceFile),'Each approval requires independent evidence PDF')
    seen.add(a.gate);paths.add(a.evidenceFile)
    let reason=null
    const expected=keys.get(a.gate)
    if(a.releaseFingerprint!==release)reason='approval_refers_to_other_release'
    else if(expected.keyId!==a.keyId)reason='untrusted_role_key'
    else{
      const signedAt=parseDate(a.signedAt),expiresAt=parseDate(a.expiresAt)
      if(signedAt>now+120000 || now-signedAt>180*86400000 || expiresAt<=now ||
        expiresAt<=signedAt || expiresAt-signedAt>365*86400000)reason='expired_or_invalid_approval_window'
      else{
        const s=a.signature
        const sig=typeof s==='string'?Buffer.from(s,'base64'):Buffer.alloc(0)
        if(sig.length!==64 || sig.toString('base64')!==s || !cryptoVerify(null,signedMessage(a),expected.key,sig))
          reason='invalid_ed25519_signature'
        else{
          let file=null
          try{file=await safeRead(join(resolve(evidenceDir),a.evidenceFile),20_000_000)}
          catch{reason='missing_or_unsafe_evidence_pdf'}
          if(file){
            if(file.subarray(0,5).toString('ascii')!=='%PDF-' || sha256(file)!==a.evidenceSha256)
              reason='document_sha256_or_pdf_header_mismatch'
          }
        }
      }
    }
    results.push({gate:a.gate,keyId:a.keyId,documentSha256:a.evidenceSha256,
      releaseFingerprint:release,cryptographicallyVerified:reason===null,reason})
  }
  const missing=EXTERNAL_GATES.filter(gate=>!seen.has(gate))
  const invalid=results.filter(x=>!x.cryptographicallyVerified)
  const complete=results.length===8 && missing.length===0 && invalid.length===0
  return {schemaVersion:1,project:'OSA CINEMA',stage:'V30_INDEPENDENT_EXTERNAL_SIGNATURE_VERIFICATION',
    status:complete?'ALL_EIGHT_SIGNATURES_CRYPTOGRAPHICALLY_VERIFIED_PRIVATE_ONLY':'EXTERNAL_ATTESTATIONS_HOLD',
    releaseFingerprint:release,signerRegistrySha256:registrySha256,
    verifiedSignatures:results.length-invalid.length,requiredSignatures:8,missingRoles:missing,
    invalidRoles:invalid.map(x=>({gate:x.gate,reason:x.reason})),results,
    legalContentReviewedBySoftware:false,realProductionVerifiedBySoftware:false,
    publisherLegalAuthorityVerifiedBySoftware:false,
    publicFilmPublicationAuthorized:false,paidCheckoutEnabled:false,
    decision:'NO_GO_UNTIL_INDEPENDENT_FINAL_HUMAN_AND_PRODUCTION_RELEASE',
    note:'Ed25519 signatures only prove cryptographic control of pinned keys over claims and hashed PDF bytes; they do not establish legal sufficiency or truth.'}
}

async function main(args){
  const opts={}
  for(let i=0;i<args.length;i++){
    const k=args[i];if(!['--preflight','--registry','--registry-sha256','--attestations','--evidence-dir','--out'].includes(k))throw Error('Unknown option '+k)
    const v=args[++i];if(!v||v.startsWith('--')||opts[k])throw Error('Missing or duplicate option '+k)
    opts[k]=v
  }
  for(const k of ['--preflight','--registry','--registry-sha256','--attestations','--evidence-dir','--out'])assert(opts[k],'Missing option '+k)
  const [pf,reg,att]=await Promise.all([safeJson(opts['--preflight']),safeJson(opts['--registry']),safeJson(opts['--attestations'])])
  if(sha256(reg.bytes)!==opts['--registry-sha256'])throw Error('Trusted key registry does not match out-of-band SHA256')
  const dest=resolve(opts['--out']),evidence=resolve(opts['--evidence-dir'])
  assert(!dest.startsWith(evidence+sep),'Output must not go in private evidence directory')
  const result=await verifyExternalAttestations({preflight:pf.obj,registry:reg.obj,registrySha256:opts['--registry-sha256'],attestations:att.obj,evidenceDir:evidence})
  await mkdir(dirname(dest),{recursive:true,mode:0o700})
  await writeFile(dest,JSON.stringify(result,null,2)+'\n',{flag:'wx',mode:0o600})
  console.log('OSA_CINEMA_V30_EXTERNAL_SIGNOFF_PRIVATE '+JSON.stringify({status:result.status,verified:result.verifiedSignatures,decision:result.decision,publicationAuthorized:false}))
  if(result.status!=='ALL_EIGHT_SIGNATURES_CRYPTOGRAPHICALLY_VERIFIED_PRIVATE_ONLY')process.exitCode=2
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url))
  main(process.argv.slice(2)).catch(e=>{console.error('OSA_V30_FAILED '+e.message);process.exitCode=1})
