import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtemp, mkdir, writeFile, symlink, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { createHash } from 'node:crypto'
import { inspectWebVtt, secondsFromTimestamp, inspectPrivateCaption } from './osa-cinema-v19-caption-qc.mjs'

const good = 'WEBVTT\n\n1\n00:00:00.300 --> 00:00:02.700\nA readable caption.\n\n2\n00:00:03.000 --> 00:00:05.500\nAnother caption.\n'
const sha = text => createHash('sha256').update(text).digest('hex')
const manifest = bytes => ({ schemaVersion: 1, assets: [{
  id:'osa-test-directors-ru', locale:'ru', edition:'directors-workprint',
  file:'OSA_CINEMA_TEST_RU.mp4', sizeBytes:Buffer.byteLength(bytes), sha256:sha(bytes), durationSeconds:239
}] })

test('valid numbered cues, BOM/CRLF, and supported WebVTT clocks', () => {
  assert.equal(inspectWebVtt(good,239).captionCandidatePass,true)
  assert.equal(inspectWebVtt('\uFEFF'+good.replace(/\n/g,'\r\n'),239).valid,true)
  assert.equal(inspectWebVtt('WEBVTT\n\n00:01.200 --> 00:02.400\nA caption.\n',239).valid,true)
  assert.equal(secondsFromTimestamp('00:00:05.000'),5)
  assert.equal(secondsFromTimestamp('01:01.000'),61)
  assert.equal(secondsFromTimestamp('00:61.000'),null)
})

test('rejects missing text, overlaps, malformed clocks and out of duration cues', () => {
  for (const source of [
    'WEBVTT\n\n00:00:00.000 --> 00:00:01.000\n',
    'WEBVTT\n\n00:00:00.000 --> 00:00:02.000\nOne\n\n00:00:01.500 --> 00:00:03.000\nTwo\n',
    'WEBVTT\n\n00:00:60.000 --> 00:00:61.000\nInvalid clock\n',
    'WEBVTT\n\n00:03:59.000 --> 00:04:01.000\nOver runtime\n',
    'NOT_WEBVTT\n\n00:00:00.000 --> 00:00:02.000\nWrong header\n',
    'WEBVTT\n\nSTYLE\n::cue { color: red }\n'
  ]) assert.equal(inspectWebVtt(source,239).valid,false,source)
})

test('flags unsafe markup, directional override and duplicate cue IDs', () => {
  assert.equal(inspectWebVtt('WEBVTT\n\n00:00:00.000 --> 00:00:02.000\n<script>alert(1)</script>\n',239).valid,false)
  assert.equal(inspectWebVtt('WEBVTT\n\n00:00:00.000 --> 00:00:02.000\nAbc\u202Edef\n',239).valid,false)
  assert.ok(inspectWebVtt('WEBVTT\n\nID\n00:00:00.000 --> 00:00:01.000\nA\n\nID\n00:00:02.000 --> 00:00:04.000\nB\n',239).errors.includes('duplicate_cue_identifier'))
})

test('quality warnings are visible and never counted as full human approval', () => {
  const rushed = inspectWebVtt('WEBVTT\n\n00:00:00.000 --> 00:00:00.300\nThis is far too fast to read safely.\n',239)
  assert.equal(rushed.valid,true)
  assert.equal(rushed.captionCandidatePass,false)
  assert.ok(rushed.warnings.includes('reading_speed_over_22_cps'))
  assert.ok(rushed.warnings.includes('cue_below_half_second'))
  assert.equal(inspectWebVtt(good,239).summary.reviewRequired,true)
})

test('private file QC validates exact original hash, but never grants publication', async t => {
  const root = await mkdtemp(join(tmpdir(),'osa-v19-test-'))
  t.after(() => rm(root,{recursive:true,force:true}))
  const bytes = 'synthetic-test-only';
  await mkdir(join(root,'captions'))
  await writeFile(join(root,'OSA_CINEMA_TEST_RU.mp4'),bytes)
  await writeFile(join(root,'captions','ru.vtt'),good)
  const report = await inspectPrivateCaption(root,manifest(bytes),'osa-test-directors-ru','captions/ru.vtt')
  assert.equal(report.captionCandidatePass,true)
  assert.equal(report.mediaVerified,true)
  assert.equal(report.publicationAuthorized,false)
  assert.ok(report.blockers.includes('commercial_rights_and_delivery_unverified'))
  assert.equal(report.captionSha256,sha(good))
  await writeFile(join(root,'OSA_CINEMA_TEST_RU.mp4'),'altered')
  const altered = await inspectPrivateCaption(root,manifest(bytes),'osa-test-directors-ru','captions/ru.vtt')
  assert.equal(altered.mediaVerified,false)
  assert.ok(altered.blockers.includes('original_media_missing_or_hash_mismatch'))
})

test('path traversal, symlinked media/captions and forged identities are rejected',async t => {
  const root = await mkdtemp(join(tmpdir(),'osa-v19-path-'))
  t.after(() => rm(root,{recursive:true,force:true}))
  await mkdir(join(root,'captions'))
  await writeFile(join(root,'captions','real.vtt'),good)
  await symlink(join(root,'captions','real.vtt'),join(root,'captions','link.vtt'))
  await assert.rejects(inspectPrivateCaption(root,manifest('a'),'osa-test-directors-ru','captions/link.vtt'),/symlink/)
  await assert.rejects(inspectPrivateCaption(root,manifest('a'),'osa-test-directors-ru','../bad.vtt'),/direct file/)
  await assert.rejects(inspectPrivateCaption(root,manifest('a'),'forged','captions/real.vtt'),/Unknown/)
})
