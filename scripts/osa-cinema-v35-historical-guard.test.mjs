import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtemp, mkdir, writeFile, rm, symlink, realpath } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join, dirname } from 'node:path'
import { auditEvidenceSnapshot, gitBlobSha, PINNED_ORIGINAL_BLOBS,
  verifyHistoricalEvidence } from './osa-cinema-v35-historical-guard.mjs'

const [v16Path,v18Path,v20Path]=Object.keys(PINNED_ORIGINAL_BLOBS)
const ids=['osa-v15-trailer-ru','osa-v15-trailer-en','osa-v15-directors-ru','osa-v15-directors-en']
const decisions=['spoken_language','commercial_rights','final_cut_sound','synced_webvtt',
  'durable_delivery','live_browser_acceptance','publisher_authorization']
function baseline(){
  const assets=ids.map(id=>({id,locale:id.endsWith('-ru')?'ru':'en',
    edition:id.includes('-trailer-')?'trailer-workprint':'directors-workprint',sha256:'1'.repeat(64)}))
  return {
    [v16Path]:{schemaVersion:1,status:'PRIVATE_EDITORIAL_WORKPRINTS_NOT_APPROVED_FOR_PUBLICATION',assets},
    [v18Path]:{schemaVersion:1,status:'PRIVATE_FOUR_AUDIO_TRACK_EDITORIAL_MASTER_NOT_LICENSED_FOR_RELEASE',
      publicationAuthorized:false,rightsCleared:false,audioTracks:[{},{},{},{}]},
    [v20Path]:{schemaVersion:1,status:'PRIVATE_ONLY_RELEASE_NOT_AUTHORIZED',publicationAuthorized:false,
      rightsCleared:false,paidCheckoutEnabled:false,mandatoryHumanDecisions:[...decisions],
      assets:ids.map(sourceId=>({sourceId,originalSha256:'1'.repeat(64),voiceApproved:false,
        captionsApproved:false,rightsApproved:false,deliveryVerified:false}))},
  }
}
const encode=data=>Object.fromEntries(Object.entries(data).map(([path,value])=>[path,Buffer.from(JSON.stringify(value))]))
const selfPins=encoded=>Object.fromEntries(Object.entries(encoded).map(([name,bytes])=>[name,gitBlobSha(bytes)]))
function audit(data,pins){const encoded=encode(data);return auditEvidenceSnapshot(encoded,pins||selfPins(encoded))}

test('V35 genuine editorial history: independent byte pin plus NO-GO policy',async t=>{
  await t.test('legitimate private-only fixture is structurally accepted but never licenses the film',()=>{
    const v=audit(baseline())
    assert.equal(v.verifiedHistoricalSnapshot,false)
    assert.equal(v.testOrCustomPinMode,true)
    assert.equal(v.verifiedFilmBytes,false)
    assert.equal(v.filmRightsVerified,false)
    assert.equal(v.publicationAuthorized,false)
    assert.equal(v.paidCheckoutEnabled,false)
    assert.equal(v.releaseDecision,'NO_GO')
    assert.equal(v.originalDocuments.length,3)
  })
  await t.test('byte modification fails even when JSON semantics are unchanged',()=>{
    const d=baseline(),encoded=encode(d),pins=selfPins(encoded)
    encoded[v16Path]=Buffer.concat([encoded[v16Path],Buffer.from(' ')])
    assert.throws(()=>auditEvidenceSnapshot(encoded,pins),/Git blob SHA mismatch/)
  })
  await t.test('Windows CRLF checkout is accepted only if the exact original Git blob is recovered',()=>{
    const data=baseline()
    const lf=Object.fromEntries(Object.entries(data).map(([p,v])=>[p,Buffer.from(JSON.stringify(v,null,2)+'\n')]))
    const pins=selfPins(lf)
    const crlf=Object.fromEntries(Object.entries(lf).map(([p,v])=>[p,Buffer.from(v.toString('utf8').replace(/\n/g,'\r\n'))]))
    assert.throws(()=>auditEvidenceSnapshot(crlf,pins),/Git blob SHA mismatch/)
    const valid=auditEvidenceSnapshot(crlf,pins,{allowCheckoutCrlf:true})
    assert.equal(valid.originalDocuments.length,3)
    assert.ok(valid.originalDocuments.every(x=>x.checkoutLineEndingsNormalized===true))
    assert.equal(valid.verifiedHistoricalSnapshot,false)
    assert.equal(valid.releaseDecision,'NO_GO')
    crlf[v20Path]=Buffer.from(crlf[v20Path].toString('utf8').replace('false','true'))
    assert.throws(()=>auditEvidenceSnapshot(crlf,pins,{allowCheckoutCrlf:true}),/Git blob SHA mismatch/)
  })
  await t.test('must use immutable real GitHub blobs in production, not convenient local fixture pins',()=>{
    assert.throws(()=>auditEvidenceSnapshot(encode(baseline())),/Git blob SHA mismatch/)
  })
  await t.test('re-pinning a forged right or public release still cannot cause GO',()=>{
    for(const [which,field,value] of [[v18Path,'rightsCleared',true],[v18Path,'publicationAuthorized',true],
      [v20Path,'paidCheckoutEnabled',true],[v20Path,'publicationAuthorized',true],
      [v20Path,'rightsCleared',true]]){
      const d=baseline();d[which][field]=value
      assert.throws(()=>audit(d),/V18 genuine historical|V20 private release/)
    }
  })
  await t.test('missing and duplicate required human decisions block even if document is re-pinned',()=>{
    for(const list of [decisions.slice(0,-1),[...decisions.slice(0,6),decisions[0]]]){
      const d=baseline();d[v20Path].mandatoryHumanDecisions=list
      assert.throws(()=>audit(d),/mandatory NO-GO/)
    }
  })
  await t.test('a forged media approval cannot match genuine historical manifest',()=>{
    for(const field of ['voiceApproved','rightsApproved','captionsApproved','deliveryVerified']){
      const d=baseline();d[v20Path].assets[0][field]=true
      assert.throws(()=>audit(d),/unapproved rights/)
    }
  })
  await t.test('source SHA, source IDs and audio track count are invariant',()=>{
    const a=baseline();a[v20Path].assets[0].originalSha256='b'.repeat(64)
    assert.throws(()=>audit(a),/evidence mismatches/)
    const b=baseline();b[v16Path].assets[0].id='forged-new-source'
    assert.throws(()=>audit(b),/V16 original/)
    const c=baseline();c[v18Path].audioTracks.pop()
    assert.throws(()=>audit(c),/V18 genuine/)
  })
  await t.test('unlisted historical source and malformed JSON are rejected',()=>{
    const docs=encode(baseline()),pins=selfPins(docs)
    docs['docs/unlisted.json']=Buffer.from('{}')
    assert.throws(()=>auditEvidenceSnapshot(docs,pins),/source set differs/)
    delete docs['docs/unlisted.json'];docs[v18Path]=Buffer.from('{invalid')
    pins[v18Path]=gitBlobSha(docs[v18Path])
    assert.throws(()=>auditEvidenceSnapshot(docs,pins),/invalid historical JSON/)
  })
})

test('V35 file reader refuses replacement and linked historical source',async t=>{
  const folder=await mkdtemp(join(await realpath(tmpdir()),'osa-v35-history-'))
  try{
    for(const path of Object.keys(PINNED_ORIGINAL_BLOBS)){
      const full=join(folder,...path.split('/'))
      await mkdir(dirname(full),{recursive:true,mode:0o700})
      await writeFile(full,JSON.stringify(baseline()[path]))
    }
    await t.test('test fixture cannot become genuine historical evidence by changing local bytes',async()=>{
      await assert.rejects(verifyHistoricalEvidence({root:folder}),/Git blob SHA mismatch/)
    })
    await t.test('symbolic link substitution of a real historical file is refused',async()=>{
      if(process.platform==='win32')return
      const filename=join(folder,...v16Path.split('/'))
      const replacement=join(folder,'alternate.json')
      await writeFile(replacement,JSON.stringify(baseline()[v16Path]))
      await rm(filename)
      await symlink(replacement,filename)
      await assert.rejects(verifyHistoricalEvidence({root:folder}),/linked or nonregular/)
    })
  }finally{await rm(folder,{recursive:true,force:true})}
})
