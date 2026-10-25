import { test } from 'node:test'
import assert from 'node:assert/strict'
import { createHash, generateKeyPairSync, sign } from 'node:crypto'
import { spawnSync } from 'node:child_process'
import { mkdtemp, mkdir, writeFile, readFile, chmod, rm, realpath } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { buildPrivateCandidatePlan } from './osa-cinema-v28-final-intake.mjs'
import { runOwnerPreflight } from './osa-cinema-v29-owner-preflight.mjs'
import { verifyHistoricalEvidence } from './osa-cinema-v35-historical-guard.mjs'
import { verifyPrivateReceiptDirectory } from './osa-cinema-v36-verify-private-receipts.mjs'
import { verifyPrivateMediaBytes } from './osa-cinema-v37-verify-private-media.mjs'
import { auditPrivateOwnerDossier } from './osa-cinema-v38-owner-release-dossier.mjs'
import { releaseFingerprint, signedMessage } from './osa-cinema-v30-external-attestations.mjs'
import { EXTERNAL_GATES } from './osa-cinema-v27-release-board.mjs'

const repoRoot = dirname(fileURLToPath(new URL('../docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json',import.meta.url)))
const projectRoot = dirname(repoRoot)
const originals = new URL('../docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json',import.meta.url)
const sha = bytes => createHash('sha256').update(bytes).digest('hex')
function ffmpeg(args) { return spawnSync('ffmpeg',args,{encoding:'utf8',timeout:60000,maxBuffer:1_000_000}) }

/** Synthetic-only media / fake PDF documents, never a publisher's materials or a license. */
test('V38 offline one-command V35+V36+V37+optional V30 integration remains NO_GO',
  {timeout:240000}, async t => {
  const genuine=await verifyHistoricalEvidence({root:projectRoot})
  assert.equal(genuine.verifiedHistoricalSnapshot,true)
  const original=JSON.parse(await readFile(originals,'utf8'))
  const root=await mkdtemp(join(await realpath(tmpdir()),'osa-v38-ffmpeg-synthetic-'))
  const filmRoot=join(root,'film'), masters=join(filmRoot,'masters'),captions=join(filmRoot,'captions')
  const receiptA=join(root,'receipts-no-rights'),receiptB=join(root,'receipts-synthetic-docs')
  const rightsDir=join(filmRoot,'rights'), signaturePdfs=join(root,'fake-signed-claims')
  try {
    await mkdir(masters,{recursive:true,mode:0o700});await mkdir(captions,{mode:0o700})
    await mkdir(rightsDir,{mode:0o700});await mkdir(signaturePdfs,{mode:0o700})
    for(const [i,a] of original.assets.entries()) {
      const path=join(masters,a.id+'.mp4')
      const response=ffmpeg(['-nostdin','-hide_banner','-loglevel','error','-filter_threads','1',
        '-f','lavfi','-i','testsrc2=s=640x360:r=10:d=1.5',
        '-f','lavfi','-i',`sine=frequency=${400+100*i}:sample_rate=48000:duration=1.5`,
        '-map','0:v:0','-map','1:a:0','-c:v','libx264','-threads','1','-preset','ultrafast',
        '-pix_fmt','yuv420p','-c:a','aac','-shortest','-movflags','+faststart','-y',path])
      assert.equal(response.status,0,response.stderr||String(response.error))
      if(process.platform!=='win32')await chmod(path,0o600)
      await writeFile(join(captions,a.id+'.vtt'),
        `WEBVTT\n\n00:00:00.000 --> 00:00:01.400\nSynthetic fake example ${i}\n`,{mode:0o600})
    }
    await t.test('V29 receipts with no rights: 8 real synthetic media files verified, no payment',async()=>{
      const pre=await runOwnerPreflight({root:filmRoot,originals,outputDir:receiptA})
      assert.equal(pre.summary.result,'NO_GO')
      const out=await auditPrivateOwnerDossier({repoRoot:projectRoot,receiptsDir:receiptA,mastersDir:masters,captionsDir:captions})
      assert.equal(out.status,'TECHNICAL_EVIDENCE_VERIFIED_FOR_PRIVATE_REVIEW')
      assert.equal(out.evidence.checkedPrivateReceiptReports,4)
      assert.equal(out.evidence.signedClaimCount,0)
      assert.equal(out.releaseDecision,'NO_GO')
      assert.equal(out.paidCheckoutEnabled,false)
    })
    await t.test('V29 with synthetic rights PDF *hash receipts* but no legal permission',async()=>{
      const plan=await buildPrivateCandidatePlan(filmRoot,original)
      const pin=join(root,'pinned.json'),usage=join(root,'usage.json')
      await writeFile(pin,JSON.stringify(plan),{mode:0o600})
      const rights={schemaVersion:1,project:'OSA CINEMA',releaseAuthorized:false,editions:[],sources:[]}
      for(const [i,a] of plan.assets.entries()){
        const id='fake-rights-source-'+(i+1),file=`synthetic_receipt_${i+1}.pdf`
        const bytes=Buffer.from(`%PDF-1.7\nFAKE FOR INTEGRATION ONLY ${i}\n%%EOF\n`)
        await writeFile(join(rightsDir,file),bytes,{mode:0o600})
        rights.editions.push({finalId:a.id,finalSha256:a.masterSha256,sourceIds:[id]})
        rights.sources.push({id,type:'video',sourceSha256:sha('synthetic'+i),
          evidenceFile:file,evidenceSha256:sha(bytes),commercialRightsApproved:false,evidenceHumanReviewed:false})
      }
      await writeFile(usage,JSON.stringify(rights),{mode:0o600})
      const pre=await runOwnerPreflight({root:filmRoot,originals,outputDir:receiptB,rightsUsage:usage,pinnedPlan:pin})
      assert.equal(pre.summary.result,'NO_GO')
      const r=await auditPrivateOwnerDossier({repoRoot:projectRoot,receiptsDir:receiptB,mastersDir:masters,captionsDir:captions})
      assert.equal(r.evidence.checkedPrivateReceiptReports,6)
      assert.equal(r.evidence.signedClaimsStatus,'NOT_PROVIDED')
      assert.equal(r.legalRightsIndependentReviewComplete,false)
    })
    await t.test('eight synthetic signed claims verify cryptographically but NEVER license a film',async()=>{
      const preflight=JSON.parse(await readFile(join(receiptB,'V29_OWNER_PREFLIGHT_NO_GO.json'),'utf8'))
      const release=releaseFingerprint(preflight)
      const signedAt=new Date(Date.now()-86400000).toISOString()
      const expiresAt=new Date(Date.now()+7*86400000).toISOString()
      const signers=[],approvals=[]
      for(const [i,gate] of EXTERNAL_GATES.entries()){
        const {privateKey,publicKey}=generateKeyPairSync('ed25519')
        const id='example-signing-role-'+(i+1),evidenceFile=`fake_approval_${i+1}.pdf`
        const pdf=Buffer.from(`%PDF-1.7\nSYNTHETIC SIGNED CLAIM IS NOT VALID LEGAL RIGHT\n${gate}\n%%EOF\n`)
        await writeFile(join(signaturePdfs,evidenceFile),pdf,{mode:0o600})
        const statement={schemaVersion:1,project:'OSA CINEMA',releaseFingerprint:release,gate,
          keyId:id,evidenceFile,evidenceSha256:sha(pdf),decision:'approved',signedAt,expiresAt,signature:''}
        statement.signature=sign(null,signedMessage(statement),privateKey).toString('base64')
        approvals.push(statement)
        signers.push({gate,keyId:id,publicKeyPem:publicKey.export({format:'pem',type:'spki'})})
      }
      const registry={schemaVersion:1,project:'OSA CINEMA',signers}
      const registryPath=join(root,'test-registry.json'),attestationsPath=join(root,'test-approvals.json')
      const registryBytes=Buffer.from(JSON.stringify(registry))
      await writeFile(registryPath,registryBytes,{mode:0o600})
      await writeFile(attestationsPath,JSON.stringify({schemaVersion:1,project:'OSA CINEMA',approvals}),{mode:0o600})
      const options={repoRoot:projectRoot,receiptsDir:receiptB,mastersDir:masters,captionsDir:captions,
        registryPath,attestationsPath,evidenceDir:signaturePdfs,registrySha256:sha(registryBytes)}
      const result=await auditPrivateOwnerDossier(options)
      assert.equal(result.evidence.signedClaimCount,8)
      assert.equal(result.legalRightsIndependentReviewComplete,false)
      assert.equal(result.publisherLegalAuthorityEstablishedBySoftware,false)
      assert.equal(result.publicationAuthorized,false)
      assert.equal(result.paidCheckoutEnabled,false)
      assert.equal(result.releaseDecision,'NO_GO')
      await assert.rejects(auditPrivateOwnerDossier({...options,registrySha256:'0'.repeat(64)}),
        /registry public keys differ/)
      const bad=structuredClone({schemaVersion:1,project:'OSA CINEMA',approvals})
      bad.approvals[0].evidenceSha256='0'.repeat(64)
      await writeFile(attestationsPath,JSON.stringify(bad),{mode:0o600})
      await assert.rejects(auditPrivateOwnerDossier(options),/V30 signer evidence/)
    })
    await t.test('tamper after receipts created: altered WebVTT must fail combined audit',async()=>{
      const first=original.assets[0].id
      await writeFile(join(captions,first+'.vtt'),
        'WEBVTT\n\n00:00:00.000 --> 00:00:01.400\nTAMPERED\n',{mode:0o600})
      await assert.rejects(auditPrivateOwnerDossier({repoRoot:projectRoot,receiptsDir:receiptA,
        mastersDir:masters,captionsDir:captions}),/WebVTT bytes do not match/)
    })
  } finally {await rm(root,{recursive:true,force:true})}
})
