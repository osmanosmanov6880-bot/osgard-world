#!/usr/bin/env node
// Synthetic contract tests. NEVER submit these values as physical device evidence.
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { mkdtemp, writeFile, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { createHash } from 'node:crypto'
import { collectSessions } from './r135-device-matrix-assemble.mjs'
import { summarizeRafIntervalsMs } from './r135-frame-metrics.mjs'
import {
  REQUIRED_RELEASE, detectSupportedDevice, summarizeIntervals,
  verifySoftwareSamples, createEvidenceRecord
} from '../public/games/r135-device-capture/device-capture.js'
const chrome = 'Mozilla/5.0 (Linux; Android 15; Pixel 8) AppleWebKit/537.36 Chrome/145.0.0.0 Mobile Safari/537.36'
const safari = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile Safari/604.1'
const sample = mode => Array.from({length:120},()=>({
  visible:true,quality:mode==='ECO'?0:2,fps:60,viewport:[390,780]
}))
const intervals=Array.from({length:350},(_,i)=>i===349?31:16.667)
const base = {
  ua:safari,mode:'ECO',orientation:'portrait',release:{
    version:REQUIRED_RELEASE.version,
    source_commit:REQUIRED_RELEASE.source_commit,engine:'Godot 4.4.1'},
  manifestSha256:REQUIRED_RELEASE.manifest_sha256,samples:sample('ECO'),
  intervals,durationSeconds:65,screenshotSha256:'a'.repeat(64),
  screenshotName:'original-test-fixture.png',sessionId:'synthetic-test-0001',
  physicalAttested:true,visibilityBreaks:0,startedAt:'2026-10-25T00:00:00Z'
}
assert.equal(detectSupportedDevice(chrome),'android-chrome')
assert.equal(detectSupportedDevice(safari),'iphone-safari')
assert.throws(()=>detectSupportedDevice('Mozilla/5.0 Windows Chrome/145'),/нужен настоящий/)
assert.throws(()=>detectSupportedDevice('Mozilla/5.0 iPhone CriOS/145 Mobile Safari/604'),/нужен настоящий/)
assert.equal(verifySoftwareSamples(sample('ECO'),'ECO','portrait'),60)
assert.equal(summarizeIntervals(intervals).p99_interval_ms,summarizeRafIntervalsMs(intervals).p99_interval_ms)
assert.equal(summarizeIntervals(intervals).callback_pacing_one_percent_low_fps,
  summarizeRafIntervalsMs(intervals).callback_pacing_one_percent_low_fps)
const result=createEvidenceRecord(base)
assert.equal(result.platform,'iphone-safari')
assert.equal(result.orientation,'portrait')
assert.equal(result.mode,'ECO')
assert.equal(result.capture.raw_godot_fps_samples.length,120)
assert.equal(result.capture.browser_raf_callback_pacing_NOT_GPU_frametime.raw_interval_samples_ms.length,350)
assert.equal(result.capture.sampled_render_fps_not_frame_time_one_percent_low.median,60)
assert.equal(result.capture.release.raw_manifest_sha256,REQUIRED_RELEASE.manifest_sha256)
assert.equal(result.capture.status,'CAPTURED_NOT_HARDWARE_CERTIFIED')
assert.equal(result.user_reviewed_touch,false)
assert.equal(result.original_frame_reviewed,false)
assert.equal(result.capture.thermal_measurement_c,null)
assert.equal(result.capture.touch_latency_measured,false)
assert.throws(()=>createEvidenceRecord({...base,physicalAttested:false}),/подтверждённая/)
assert.throws(()=>createEvidenceRecord({...base,release:{...base.release,source_commit:'0'.repeat(40)}}),/Другая сборка/)
assert.throws(()=>createEvidenceRecord({...base,manifestSha256:'0'.repeat(64)}),/Другая сборка/)
assert.throws(()=>createEvidenceRecord({...base,durationSeconds:59}),/минимум 60/)
assert.throws(()=>createEvidenceRecord({...base,visibilityBreaks:2}),/прервало|скрыта/)
assert.throws(()=>createEvidenceRecord({...base,samples:sample('HERO')}),/Сэмплы/)
assert.throws(()=>createEvidenceRecord({...base,samples:sample('ECO').map((s,i)=>i===17?{...s,visible:false}:s)}),/Сэмплы/)
assert.throws(()=>createEvidenceRecord({...base,intervals:[16.667]}),/минимум 300/)
assert.throws(()=>createEvidenceRecord({...base,screenshotName:'../fake.png'}),/оригинальный PNG/)
assert.throws(()=>createEvidenceRecord({...base,screenshotSha256:'garbage'}),/оригинальный PNG/)
const html=readFileSync('public/games/r135-device-capture/index.html','utf8')
const ui=readFileSync('public/games/r135-device-capture/device-capture-ui.js','utf8')
assert.match(html,/src="\.\/device-capture-ui\.js"/)
assert.doesNotMatch(html,/<script[^>]*>[^<]*import\s/m)
assert.match(ui,/65_000/)
assert.match(ui,/\/games\/r135-service\/release\.json/)
assert.match(ui,/fetch\([^\n]*cache:'no-store'/)
assert.match(ui,/createEvidenceRecord/)
assert.match(html,/original_frame_reviewed/)
assert.doesNotMatch(ui,/\bmethod\s*:\s*['"]POST['"]/)
// Synthetic original-file pairing tests. The bytes below are NOT actual PNG
// image captures and may never be used for hardware certification.
const directory=await mkdtemp(join(tmpdir(),'r135-w16-synthetic-'))
try {
  for (let i=0;i<2;i++) {
    const name='synthetic-'+i+'.png'
    const png=Buffer.alloc(21000, i+1)
    Buffer.from([137,80,78,71,13,10,26,10]).copy(png)
    await writeFile(join(directory,name),png)
    const record=createEvidenceRecord({...base,
      screenshotSha256:createHash('sha256').update(png).digest('hex'),
      screenshotName:name,sessionId:'synthetic-file-'+i})
    await writeFile(join(directory,'r135-w16-synthetic-'+i+'.json'),
      JSON.stringify({sessions:[record]}))
  }
  const paired=await collectSessions(directory)
  assert.equal(paired.length,2)
  assert.equal(paired.every(r=>r.user_reviewed_touch===false &&
    r.original_frame_reviewed===false),true)
  const tampered=await readFileSync(join(directory,'synthetic-1.png'))
  tampered[100]^=1
  await writeFile(join(directory,'synthetic-1.png'),tampered)
  await assert.rejects(()=>collectSessions(directory),/Screenshot was changed/)
} finally {
  await rm(directory,{recursive:true,force:true})
}

console.log('R135 W16 same-origin portable Android/Safari capture contracts PASS (synthetic test ONLY). No physical devices tested.')
