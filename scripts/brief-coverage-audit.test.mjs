import assert from 'node:assert/strict'
import crypto from 'node:crypto'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { spawnSync } from 'node:child_process'

const directory=fs.mkdtempSync(path.join(os.tmpdir(),'osgard-brief-validator-'))
try {
  const file=path.join(directory,'brief.txt')
  const content=Array.from({length:255},(_,i)=>'# '+(i+1)+'. Section '+(i+1)).join('\n')
  const run=(value,options=[])=>{
    fs.writeFileSync(file,value)
    const job=spawnSync(process.execPath,['scripts/brief-coverage-audit.mjs',file,...options],{encoding:'utf8',timeout:8000})
    assert.ok([0,1,2].includes(job.status),'unexpected process failure: '+job.stderr)
    return {code:job.status,report:job.stdout?JSON.parse(job.stdout):null,stderr:job.stderr}
  }
  let tests=0
  const check=(name,fn)=>{fn();tests++;console.log('PASS '+name)}
  check('exact 255 numbered sections passes coverage without provenance',()=>{
    const x=run(content)
    assert.equal(x.code,0)
    assert.equal(x.report.numberedSections,255)
    assert.equal(x.report.provenanceVerified,false)
    assert.equal(x.report.preambleSections.length,0)
  })
  check('optional #0 preamble and dated #242 are accepted',()=>{
    const lines=content.split('\n')
    lines[241]='[2026-10-17 21:00] # 242. Dated section'
    const d='# 0. Preamble\n'+lines.join('\n')
    const x=run(d)
    assert.equal(x.code,0)
    assert.deepEqual(x.report.preambleSections,[0])
    assert.equal(x.report.numberedSections,255)
  })
  check('repeated section is rejected even if all 255 are present',()=>{
    const x=run(content+'\n# 242. Duplicate')
    assert.equal(x.code,1)
    assert.deepEqual(x.report.duplicate,[242])
  })
  check('missing section is rejected',()=>{
    const x=run(content.replace('# 250. Section 250',''))
    assert.equal(x.code,1)
    assert.deepEqual(x.report.missing,[250])
  })
  check('extra 256th section is rejected',()=>{
    const x=run(content+'\n# 256. Unapproved')
    assert.equal(x.code,1)
    assert.deepEqual(x.report.extra,[256])
  })
  check('matching SHA and counts certify exact bytes',()=>{
    const sha=crypto.createHash('sha256').update(content).digest('hex')
    const options=['--expect-sha256',sha,'--expect-bytes',String(Buffer.byteLength(content)),'--expect-lines','255']
    const x=run(content,options)
    assert.equal(x.code,0)
    assert.equal(x.report.provenanceVerified,true)
    assert.deepEqual(x.report.fingerprintMatch,{sha256:true,bytes:true,lines:true})
  })
  check('different content with identical headings fails SHA',()=>{
    const sha=crypto.createHash('sha256').update(content).digest('hex')
    const other=content.replace('Section 1','Different 1')
    const x=run(other,['--expect-sha256',sha])
    assert.equal(x.code,1)
    assert.equal(x.report.fingerprintMatch.sha256,false)
  })
  check('wrong line count fails without pretending source verification',()=>{
    const x=run(content,['--expect-lines','254'])
    assert.equal(x.code,1)
    assert.equal(x.report.provenanceVerified,false)
    assert.equal(x.report.fingerprintMatch.lines,false)
  })
  check('invalid SHA is a usage error',()=>{
    const x=run(content,['--expect-sha256','not-a-sha'])
    assert.equal(x.code,2)
    assert.equal(x.report,null)
  })
  check('unknown flag is rejected',()=>{
    const x=run(content,['--ignore-differences','yes'])
    assert.equal(x.code,2)
  })
  console.log('Brief validator: '+tests+' isolated tests passed.')
} finally {
  fs.rmSync(directory,{recursive:true,force:true})
}
