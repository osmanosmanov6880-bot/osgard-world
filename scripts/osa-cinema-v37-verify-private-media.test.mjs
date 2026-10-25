import { test } from 'node:test'
import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { mkdtemp, mkdir, writeFile, readFile, chmod, rm, symlink, link, realpath, readdir } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { verifyPrivateMediaBytes } from './osa-cinema-v37-verify-private-media.mjs'
import { EXTERNAL_GATES } from './osa-cinema-v27-release-board.mjs'

const hash=b=>createHash('sha256').update(b).digest('hex')
const fp=x=>hash(JSON.stringify(x))
const id=['osa-v15-trailer-ru','osa-v15-trailer-en','osa-v15-directors-ru','osa-v15-directors-en']
const NAMES=['V28_CANDIDATE_MANIFEST.json','V24_MEDIA_QA.json','V26_PRIVATE_DELIVERY_QA.json']
const END='V29_OWNER_PREFLIGHT_NO_GO.json'
const rights=['V25_RIGHTS_BYTES_QA.json','V27_FINAL_NO_GO_BOARD.json']

async function fixture({withRights=false,badCaption=false}={}) {
  const root=await mkdtemp(join(await realpath(tmpdir()),'osa-v37-synthetic-only-'))
  const receipts=join(root,'receipts'),masters=join(root,'masters'),captions=join(root,'captions')
  for(const dir of [receipts,masters,captions])await mkdir(dir,{mode:0o700})
  const assets=[]
  for(const [i,name] of id.entries()) {
    // Synthetic *bytes*, not actual movie or a film clearance decision.
    const vid=Buffer.from(`synthetic-not-a-real-film|ftyp|${name}|${i}|${'x'.repeat(150+i)}`)
    const subtitle=Buffer.from(badCaption && i===0 ? 'NOT-WEBVTT\n00:00:00.000 --> 00:00:00.900\nTest\n' :
      `WEBVTT\n\n00:00:00.000 --> 00:00:00.900\nSynthetic test cue ${i}\n`)
    await writeFile(join(masters,name+'.mp4'),vid,{mode:0o600})
    await writeFile(join(captions,name+'.vtt'),subtitle,{mode:0o600})
    assets.push({id:name,edition:i<2?'trailer-workprint':'directors-workprint',locale:i%2?'en':'ru',
      sourceSha256:hash('synthetic-source'+i),masterName:name+'.mp4',masterSha256:hash(vid),
      masterBytes:vid.length,captionName:name+'.vtt',captionSha256:hash(subtitle),durationSeconds:1})
  }
  const v28={schemaVersion:1,project:'OSA CINEMA',stage:'V28_TECHNICAL_INTAKE_ONLY',publicationAuthorized:false,
    commercialRightsCleared:false,assets}
  const v24={schemaVersion:1,project:'OSA CINEMA',recordedFilmReleaseAuthorized:false,paidCheckoutAllowed:false,
    technical:{passed:4,failed:0},assets:assets.map(a=>({id:a.id,technicalCandidatePassed:true,
      originalSha256:a.sourceSha256,finalSha256:a.masterSha256,captionSha256:a.captionSha256,
      mediaVerified:true,captionVerified:true,blockers:[],humanAudioLanguageApproved:false,
      commercialRightsCleared:false,publisherAuthorized:false}))}
  const v26=assets.map(a=>({status:'LOOPBACK_RANGE_QA_PASS_NOT_PUBLIC',fullContentVerified:true,
    publicationAuthorized:false,sourceSha256:a.masterSha256}))
  const v25={schemaVersion:1,project:'OSA CINEMA',rightsCleared:false,publishAllowed:false,
    sources:[],coverage:{documentBytesVerified:2}}
  const v27={schemaVersion:1,project:'OSA CINEMA',result:'NO_GO',
    technicalCandidateEvidenceComplete:false,publicFilmPublicationAuthorized:false,
    paidCheckoutEnabled:false,productionDeploymentPerformed:false}
  const v29={schemaVersion:1,project:'OSA CINEMA',stage:'V29_PRIVATE_OWNER_PREFLIGHT',result:'NO_GO',
    publicationAuthorized:false,rightsCleared:false,paidCheckoutEnabled:false,
    publicCatalogueWriteAllowed:false,productionDeploymentPerformed:false,
    candidateAssets:assets.map(a=>({id:a.id,edition:a.edition,locale:a.locale,
      finalSha256:a.masterSha256,captionSha256:a.captionSha256})),
    fingerprints:{v28:fp(v28),v24:fp(v24),v26:v26.map(fp),
      v25:withRights?fp(v25):null,v27:withRights?fp(v27):null},
    technical:{mastersPassed:4,privateHttpPassed:4,
      evidenceDocumentsVerified:withRights?2:0,evidenceTechnicallyComplete:false},
    blockers:[...(!withRights?['rights_usage_manifest_and_real_document_ledger_missing']:[]),...EXTERNAL_GATES],
    independentExternalAuthorizationsOutstanding:[...EXTERNAL_GATES]}
  const records={[NAMES[0]]:v28,[NAMES[1]]:v24,[NAMES[2]]:v26,...(withRights?{[rights[0]]:v25,[rights[1]]:v27}:{}),[END]:v29}
  const ordered=[...NAMES,...(withRights?rights:[]),END]
  const sums=[]
  for(const name of ordered){
    const bytes=Buffer.from(JSON.stringify(records[name],null,2)+'\n')
    await writeFile(join(receipts,name),bytes,{mode:0o600})
    sums.push(hash(bytes)+'  '+name)
  }
  await writeFile(join(receipts,'CHECKSUMS.sha256'),sums.join('\n')+'\n',{mode:0o600})
  return {root,receiptsDir:receipts,mastersDir:masters,captionsDir:captions,
    assets,verify:()=>verifyPrivateMediaBytes({receiptsDir:receipts,mastersDir:masters,captionsDir:captions})}
}

test('V37: local private film bytes, release must ALWAYS remain NO_GO',async t=>{
  for(const withRights of [false,true])await t.test('private byte agreement '+(withRights?'with':'without')+' synthetic rights receipts',async()=>{
    const d=await fixture({withRights})
    try{
      const r=await d.verify()
      assert.equal(r.verifiedPrivateVideoFiles,4)
      assert.equal(r.verifiedPrivateCaptionFiles,4)
      assert.equal(r.bytesMatched,true)
      assert.equal(r.decision,'NO_GO')
      assert.equal(r.perEdition.length,4)
      for(const k of ['publicationAuthorized','rightsCleared','paidCheckoutEnabled',
        'humanSpokenLanguageChecked','legalRightsIndependentlyCleared','productionHttpsAndDevicesVerified',
        'publisherIdentityIndependentlyAuthenticated'])assert.equal(r[k],false,k)
      assert.equal(JSON.stringify(r).includes(d.root),false,'private directory path not leaked')
    }finally{await rm(d.root,{recursive:true,force:true})}
  })
  await t.test('tampered video must be rejected',async()=>{
    const d=await fixture()
    try{
      await writeFile(join(d.mastersDir,id[0]+'.mp4'),Buffer.alloc(d.assets[0].masterBytes,0x41))
      await assert.rejects(d.verify(),/MP4 bytes do not match/)
    }finally{await rm(d.root,{recursive:true,force:true})}
  })
  await t.test('tampered subtitle must be rejected',async()=>{
    const d=await fixture()
    try{
      await writeFile(join(d.captionsDir,id[0]+'.vtt'),Buffer.from('WEBVTT\n\n00:00:00.000 --> 00:00:00.900\nCorrupted\n'))
      await assert.rejects(d.verify(),/WebVTT bytes do not match/)
    }finally{await rm(d.root,{recursive:true,force:true})}
  })
  await t.test('non WebVTT bytes rejected EVEN with matching local receipt SHA',async()=>{
    const d=await fixture({badCaption:true})
    try{await assert.rejects(d.verify(),/WebVTT needs a header/)}finally{await rm(d.root,{recursive:true,force:true})}
  })
  await t.test('unexpected script inside private masters is rejected',async()=>{
    const d=await fixture()
    try{await writeFile(join(d.mastersDir,'untrusted.mjs'),'console.log(1)',{mode:0o600});await assert.rejects(d.verify(),/video folder must contain only/)}
    finally{await rm(d.root,{recursive:true,force:true})}
  })
  await t.test('one missing caption is rejected',async()=>{
    const d=await fixture()
    try{await rm(join(d.captionsDir,id[1]+'.vtt'));await assert.rejects(d.verify(),/caption folder must contain only/)}
    finally{await rm(d.root,{recursive:true,force:true})}
  })
  await t.test('linked private MP4 refused',async()=>{
    if(process.platform==='win32')return
    const d=await fixture()
    try{const old=join(d.mastersDir,id[0]+'.mp4'),target=join(d.root,'outside.mp4');
      await writeFile(target,await readFile(old),{mode:0o600});await rm(old);await symlink(target,old)
      await assert.rejects(d.verify(),/regular non-linked/)
    }finally{await rm(d.root,{recursive:true,force:true})}
  })
  await t.test('hardlinked private MP4 refused',async()=>{
    if(process.platform==='win32')return
    const d=await fixture()
    try{await link(join(d.mastersDir,id[0]+'.mp4'),join(d.root,'hardlink-copy.mp4'));
      await assert.rejects(d.verify(),/cannot be hard-linked/)
    }finally{await rm(d.root,{recursive:true,force:true})}
  })
  await t.test('world-readable subtitles refused on POSIX',async()=>{
    if(process.platform==='win32')return
    const d=await fixture()
    try{await chmod(join(d.captionsDir,id[2]+'.vtt'),0o644);await assert.rejects(d.verify(),/private file permissions/)}
    finally{await rm(d.root,{recursive:true,force:true})}
  })
  await t.test('public-readable receipt directory refused on POSIX',async()=>{
    if(process.platform==='win32')return
    const d=await fixture()
    try{await chmod(d.receiptsDir,0o755);await assert.rejects(d.verify(),/owner-private/)}
    finally{await rm(d.root,{recursive:true,force:true})}
  })
  await t.test('overlapping root directories rejected',async()=>{
    const d=await fixture()
    try{await assert.rejects(verifyPrivateMediaBytes({receiptsDir:d.receiptsDir,
      mastersDir:d.receiptsDir,captionsDir:d.captionsDir}),/three private roots/)}
    finally{await rm(d.root,{recursive:true,force:true})}
  })
  await t.test('relative directories rejected',async()=>{
    const d=await fixture()
    try{await assert.rejects(verifyPrivateMediaBytes({receiptsDir:'./reports',
      mastersDir:d.mastersDir,captionsDir:d.captionsDir}),/absolute local path/)}
    finally{await rm(d.root,{recursive:true,force:true})}
  })
  await t.test('altered V28 report after checksum must be rejected',async()=>{
    const d=await fixture()
    try{await writeFile(join(d.receiptsDir,NAMES[0]),'{}',{mode:0o600});await assert.rejects(d.verify(),/SHA-256 mismatch/)}
    finally{await rm(d.root,{recursive:true,force:true})}
  })
  await t.test('CLI without required arguments fails closed',async()=>{
    const {spawnSync}=await import('node:child_process')
    const cli=new URL('./osa-cinema-v37-verify-private-media.mjs',import.meta.url)
    const p=spawnSync(process.execPath,[cli.pathname],{encoding:'utf8'})
    assert.equal(p.status,1)
    assert.match(p.stderr,/OSA_V37_PRIVATE_MEDIA_HOLD/)
  })
})
