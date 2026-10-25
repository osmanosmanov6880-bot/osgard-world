import { test } from 'node:test'
import assert from 'node:assert/strict'
import { generateKeyPairSync, createHash, sign } from 'node:crypto'
import { mkdtemp, mkdir, readFile, writeFile, symlink, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { archiveSigningMessage, verifyDetachedArchive } from './osa-cinema-v34-detached-signature.mjs'

const sha = bytes => createHash('sha256').update(bytes).digest('hex')
const makeData = (name,bytes,key) => ({schemaVersion:1,algorithm:'Ed25519',purpose:'OSA_CINEMA_CODE_ARCHIVE_ONLY',
  archiveName:name,sha256:sha(bytes),signature:sign(null,archiveSigningMessage(name,sha(bytes)),key).toString('base64'),
  publicationAuthorized:false,rightsCleared:false,paidCheckoutEnabled:false,releaseDecision:'NO_GO'})

test('V34 detached publisher signature: authentic code-only package and independent trust pin',async t=>{
 const folder=await mkdtemp(join(tmpdir(),'osa-v34-signature-'))
 const archivePath=join(folder,'OSA_CINEMA_CODE.zip'),signaturePath=join(folder,'OSA_CINEMA_CODE.sig.json'),publicKeyPath=join(folder,'publisher-public.pem')
 const original=Buffer.from('UEsDBBQAAAAIAMycWV2Oxh89OAAAADgAAAAKAAAAUkVBRE1FLnR4dAvJyCxWAKL8vJxKheT8lFTd4tKCgpxK3eSMxMw8hZLU4hKF3MSS1KLMxBw9Bb98hdz8ssxUPS4AUEsBAhQDFAAAAAgAzJxZXY7GHz04AAAAOAAAAAoAAAAAAAAAAAAAAIABAAAAAFJFQURNRS50eHRQSwUGAAAAAAEAAQA4AAAAYAAAAAAA','base64')
 const {publicKey,privateKey}=generateKeyPairSync('ed25519')
 const {publicKey:otherKey,privateKey:otherPrivate}=generateKeyPairSync('ed25519')
 const pub=publicKey.export({type:'spki',format:'pem'})
 const pin=sha(publicKey.export({type:'spki',format:'der'}))
 const options={archivePath,signaturePath,publicKeyPath,trustedKeySha256:pin}
 const writeSignature=async doc=>writeFile(signaturePath,JSON.stringify(doc))
 try{
   await writeFile(archivePath,original)
   await writeFile(publicKeyPath,pub)
   await writeSignature(makeData('OSA_CINEMA_CODE.zip',original,privateKey))
   await t.test('valid independently trusted code signature still cannot permit premiere or payment',async()=>{
     const v=await verifyDetachedArchive(options)
     assert.equal(v.signatureVerified,true)
     assert.equal(v.archiveSha256,sha(original))
     assert.equal(v.publicationAuthorized,false)
     assert.equal(v.rightsCleared,false)
     assert.equal(v.paidCheckoutEnabled,false)
     assert.equal(v.releaseDecision,'NO_GO')
   })
   await t.test('missing or self-reported key pin is not accepted',async()=>{
     await assert.rejects(verifyDetachedArchive({...options,trustedKeySha256:undefined}),/independent.*fingerprint/)
     await assert.rejects(verifyDetachedArchive({...options,trustedKeySha256:sha(Buffer.from('fake'))}),/pin mismatch/)
   })
   await t.test('wrong archive bytes are rejected despite a matching signed metadata JSON',async()=>{
     const altered=Buffer.from(original);altered[altered.length-1]^=1;await writeFile(archivePath,altered)
     await assert.rejects(verifyDetachedArchive(options),/SHA256 mismatch/)
     await writeFile(archivePath,original)
   })
   await t.test('signature with another Ed25519 private key is rejected',async()=>{
     await writeSignature(makeData('OSA_CINEMA_CODE.zip',original,otherPrivate))
     await assert.rejects(verifyDetachedArchive(options),/signature did not verify/)
     await writeSignature(makeData('OSA_CINEMA_CODE.zip',original,privateKey))
     assert.notEqual(sha(otherKey.export({type:'spki',format:'der'})),pin)
   })
   await t.test('forged release approvals and foreign JSON keys are rejected',async()=>{
     const good=makeData('OSA_CINEMA_CODE.zip',original,privateKey)
     for(const [key,value] of [['publicationAuthorized',true],['rightsCleared',true],['paidCheckoutEnabled',true],['releaseDecision','GO'],['purpose','FILM_PUBLIC_RELEASE'],['evilGo',true]]){
       await writeSignature({...good,[key]:value})
       await assert.rejects(verifyDetachedArchive(options),/metadata fields|code integrity only/)
     }
     await writeSignature(good)
   })
   await t.test('renamed archive and invalid noncanonical signature fail',async()=>{
     const valid=makeData('OSA_CINEMA_CODE.zip',original,privateKey)
     await writeSignature({...valid,archiveName:'ELSEWHERE.zip'})
     await assert.rejects(verifyDetachedArchive(options),/archive identity/)
     await writeSignature({...valid,signature:(valid.signature[0]==='A'?'B':'A')+valid.signature.slice(1)})
     await assert.rejects(verifyDetachedArchive(options),/signature did not verify|noncanonical/)
     await writeSignature(valid)
   })
   await t.test('rejects symlinked signature and archive before reading them',async()=>{
     if(process.platform==='win32')return
     const alias=join(folder,'link.sig.json'),aliasDir=join(folder,'alias-dir'),archiveAlias=join(aliasDir,'OSA_CINEMA_CODE.zip')
     await mkdir(aliasDir);await symlink(signaturePath,alias)
     await symlink(archivePath,archiveAlias)
     try{
       await assert.rejects(verifyDetachedArchive({...options,signaturePath:alias}),/symlinked/)
       await assert.rejects(verifyDetachedArchive({...options,archivePath:archiveAlias}),/symlinked/)
     }finally{await rm(alias);await rm(archiveAlias)}
   })
   await t.test('archive byte ceiling is strict',async()=>{
     await assert.rejects(verifyDetachedArchive({...options,maxArchiveBytes:original.length-1}),/oversized/)
     await assert.rejects(verifyDetachedArchive({...options,maxArchiveBytes:512*1024*1024+1}),/size limit/)
   })
 }finally{await rm(folder,{recursive:true,force:true})}
})
