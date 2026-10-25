import {test} from 'node:test'
import assert from 'node:assert/strict'
import {readFile,mkdtemp,writeFile,rm,symlink} from 'node:fs/promises'
import {tmpdir} from 'node:os'
import {join} from 'node:path'
import {auditDraftDirectory,captionStats,filenameForSource} from './osa-cinema-v19-caption-audit.mjs'
const manifest=JSON.parse(await readFile('docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json','utf8'))

test('Private captions require one exact real source per original edition',()=>{
 assert.equal(manifest.assets.length,4)
 assert.equal(new Set(manifest.assets.map(x=>x.id)).size,4)
 for(const x of manifest.assets)assert.ok(filenameForSource(x.id).endsWith('.vtt'))
 assert.throws(()=>filenameForSource('../../tmp/evil'),/Unsafe/)
})
test('Missing caption drafts truthfully block all four editions',async()=>{
 const root=await mkdtemp(join(tmpdir(),'osa-v19-'))
 try{
  const r=await auditDraftDirectory(root,manifest)
  assert.deepEqual(r.summary,{total:4,validTechnicalDrafts:0,missing:4,invalid:0,approvedForPublication:0})
  assert.equal(r.releaseAuthorized,false)
  assert.ok(r.assets.every(x=>x.state==='missing'&&!x.releaseAuthorized))
 }finally{await rm(root,{recursive:true,force:true})}
})
test('Real valid VTT draft does not imply rights or real audible speech review',async()=>{
 const root=await mkdtemp(join(tmpdir(),'osa-v19-'))
 try{
  const original=manifest.assets.find(x=>x.id==='osa-v15-directors-ru')
  const draft='WEBVTT\n\n00:00:05.000 --> 00:00:07.000\nРеплика для проверки\n\n00:01:19.000 --> 00:01:21.000\nТолько тестовая разметка\n'
  await writeFile(join(root,filenameForSource(original.id)),draft)
  const r=await auditDraftDirectory(root,manifest)
  assert.equal(r.summary.validTechnicalDrafts,1)
  const row=r.assets.find(x=>x.sourceId===original.id)
  assert.equal(row.details.cueCount,2)
  assert.equal(row.details.coveragePercent,1.67)
  assert.equal(row.state,'technical_draft_valid')
  assert.equal(row.spokenLanguageHumanVerified,false)
  assert.equal(row.transcriptionAccuracyApproved,false)
  assert.equal(row.rightsCleared,false)
  assert.equal(row.releaseAuthorized,false)
 }finally{await rm(root,{recursive:true,force:true})}
})
test('Invalid VTT cues or unsafe symlinks cannot pass the source gate',async()=>{
 const root=await mkdtemp(join(tmpdir(),'osa-v19-'))
 try{
  const first=manifest.assets[0],second=manifest.assets[1]
  await writeFile(join(root,filenameForSource(first.id)),'WEBVTT\n\n00:00:44.000 --> 00:00:48.000\nOver duration\n')
  await symlink(join(root,filenameForSource(first.id)),join(root,filenameForSource(second.id)))
  const r=await auditDraftDirectory(root,manifest)
  assert.equal(r.summary.invalid,2)
  assert.equal(r.summary.approvedForPublication,0)
 }finally{await rm(root,{recursive:true,force:true})}
})
test('Caption metrics flag line length and short/long cues, not claim language approval',()=>{
 const result=captionStats([{start:1,end:1.3,text:'a'.repeat(43)},{start:2,end:11,text:'Test'}],239)
 assert.equal(result.cueCount,2)
 assert.ok(result.warnings.includes('overlong_line_at_cue_0'))
 assert.ok(result.warnings.includes('very_short_cue_0'))
 assert.ok(result.warnings.includes('long_duration_cue_1'))
})
