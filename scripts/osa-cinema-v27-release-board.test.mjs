import test from 'node:test'
import assert from 'node:assert/strict'
import { buildGoNoGoBoard } from './osa-cinema-v27-release-board.mjs'
const ids=['osa-v15-trailer-ru','osa-v15-trailer-en','osa-v15-directors-ru','osa-v15-directors-en']
const sha=i=>String((i%9)+1).repeat(64)
const rows=ids.map((id,i)=>({id,locale:i%2?'en':'ru',edition:i<2?'trailer-workprint':'directors-workprint',originalSha256:sha(i+1),finalSha256:sha(i+2),captionSha256:sha(i+3),technicalCandidatePassed:true,mediaVerified:true,captionVerified:true,blockers:[]}))
const v24={schemaVersion:1,project:'OSA CINEMA',recordedFilmReleaseAuthorized:false,publicCatalogueWriteAllowed:false,paidCheckoutAllowed:false,assets:rows,technical:{passed:4,failed:0}}
const sources=rows.map(a=>({sourceId:'source-'+a.id,usedIn:[a.id],evidenceBytesVerified:true}))
const v25={schemaVersion:1,project:'OSA CINEMA',rightsCleared:false,publishAllowed:false,sources,coverage:{registeredSources:4,documentBytesVerified:4,missing:0,coveredEditions:4}}
const v26=rows.map(a=>({schemaVersion:1,sourceSha256:a.finalSha256,safeLoopbackVerified:true,status:'LOOPBACK_RANGE_QA_PASS_NOT_PUBLIC',tests:{head:200,firstRange:{status:206},fullGet:{status:200,sha256:a.finalSha256,byteCount:1000},invalidRange:416},bytes:1000,fullContentVerified:true,errors:[],productionDeploymentVerified:false,publicationAuthorized:false}))
test('perfect synthetic technical evidence still yields NO_GO, no checkout and eight external gates',()=>{
 const board=buildGoNoGoBoard(v24,v25,v26)
 assert.equal(board.technicalCandidateEvidenceComplete,true)
 assert.equal(board.result,'NO_GO')
 assert.equal(board.externalAuthorizationsNotProvided.length,8)
 assert.equal(board.paidCheckoutEnabled,false)
 assert.equal(board.editions.length,4)
})
test('no V24 technical caption success => release board detects asset-specific blocker',()=>{
 const x=structuredClone(v24);x.assets[0].captionVerified=false
 const r=buildGoNoGoBoard(x,v25,v26)
 assert.equal(r.technicalCandidateEvidenceComplete,false)
 assert.ok(r.technicalBlockers.some(t=>t.includes(rows[0].id)))
})
test('missing legal PDF file or last-mile Range response yields NO_GO technical blocker',()=>{
 const x=structuredClone(v25);x.sources[0].evidenceBytesVerified=false
 const y=structuredClone(v26);y[0].tests.firstRange.status=200
 assert.ok(buildGoNoGoBoard(v24,x,v26).technicalBlockers.some(t=>t.includes('v25')))
 assert.ok(buildGoNoGoBoard(v24,v25,y).technicalBlockers.some(t=>t.includes('v26')))
})
test('falsely authorized V24 or V25 data is a hard exception',()=>{
 const x=structuredClone(v25);x.rightsCleared=true
 assert.throws(()=>buildGoNoGoBoard(v24,x,v26),/falsely cleared/)
 const y=structuredClone(v24);y.recordedFilmReleaseAuthorized=true
 assert.throws(()=>buildGoNoGoBoard(y,v25,v26),/fraudulently released/)
})
test('duplicate V26 receipt cannot stand in for different film',()=>{
 const x=structuredClone(v26);x[1]=structuredClone(x[0])
 const r=buildGoNoGoBoard(v24,v25,x)
 assert.equal(r.technicalCandidateEvidenceComplete,false)
 assert.ok(r.technicalBlockers.some(t=>t.includes('v26')))
})

test('V27 refuses a receipt with correct first/last Range but wrong full movie digest',()=>{
 const wrong=structuredClone(v26)
 wrong[0].tests.fullGet.sha256='f'.repeat(64)
 assert.equal(buildGoNoGoBoard(v24,v25,wrong).technicalCandidateEvidenceComplete,false)
})
