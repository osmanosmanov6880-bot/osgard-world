/** Offline caption intake for private OSA CINEMA workprints. Not release approval. */
import { createHash } from 'node:crypto'
import { createReadStream } from 'node:fs'
import { lstat, readFile, writeFile, mkdir } from 'node:fs/promises'
import { resolve, join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const SHA = /^[0-9a-f]{64}$/
const VTT_PATH = /^captions\/[A-Za-z0-9][A-Za-z0-9_.-]{0,110}\.vtt$/i
const CUE_TIME = /^(\d{2,}):(\d{2}):(\d{2})\.(\d{3})$/
const SHORT_TIME = /^(\d{2}):(\d{2})\.(\d{3})$/
const DEFAULT_DURATION = 239

export function secondsFromTimestamp(value) {
  const full = CUE_TIME.exec(value)
  if (full) {
    if (Number(full[2]) >= 60 || Number(full[3]) >= 60) return null
    return Number(full[1]) * 3600 + Number(full[2]) * 60 + Number(full[3]) + Number(full[4]) / 1000
  }
  const short = SHORT_TIME.exec(value)
  if (short) {
    if (Number(short[1]) >= 60 || Number(short[2]) >= 60) return null
    return Number(short[1]) * 60 + Number(short[2]) + Number(short[3]) / 1000
  }
  return null
}

export function inspectWebVtt(source, durationSeconds = DEFAULT_DURATION) {
  const errors = [], warnings = [], cues = []
  if (typeof source !== 'string' || Buffer.byteLength(source, 'utf8') > 2_000_000) {
    return { valid: false, captionCandidatePass: false, errors: ['unreadable_or_oversized_vtt'], warnings, cues: [], summary: { count: 0 } }
  }
  if (!Number.isFinite(durationSeconds) || durationSeconds <= 0) throw new Error('Invalid target film duration')
  const content = source.replace(/^\uFEFF/, '').replace(/\r\n?/g, '\n')
  const blocks = content.split(/\n[\t ]*\n+/)
  if (!/^WEBVTT(?:[ \t].*)?$/.test((blocks[0] || '').split('\n')[0] || '')) errors.push('missing_webvtt_header')
  const first = (blocks[0] || '').split('\n').slice(1).filter(Boolean)
  if (first.length) errors.push('malformed_header')
  let lastEnd = 0
  const seenIDs = new Set()
  for (const block of blocks.slice(1)) {
    const lines = block.split('\n').map(line => line.trimEnd()).filter(line => line.length)
    if (!lines.length) continue
    if (/^NOTE(?:\s|$)/.test(lines[0])) continue
    if (/^(?:STYLE|REGION)(?:\s|$)/.test(lines[0])) { errors.push('unsupported_style_or_region'); continue }
    const timeIndex = lines.findIndex(line => line.includes('-->'))
    if (timeIndex > 1 || timeIndex < 0 || (timeIndex === 1 && !lines[0].trim())) { errors.push('invalid_cue_block'); continue }
    if (timeIndex === 1) {
      if (seenIDs.has(lines[0])) errors.push('duplicate_cue_identifier')
      seenIDs.add(lines[0])
    }
    const match = /^([^\s]+)\s+-->\s+([^\s]+)(?:\s+(.*))?$/.exec(lines[timeIndex])
    if (!match || match[3]) { errors.push('invalid_or_unsupported_cue_timing'); continue }
    const start = secondsFromTimestamp(match[1]), end = secondsFromTimestamp(match[2])
    if (start === null || end === null || start >= end || end > durationSeconds + 0.02 || start < lastEnd - .001) {
      errors.push('overlapping_or_out_of_range_cue'); continue
    }
    const textLines = lines.slice(timeIndex + 1)
    if (!textLines.length || textLines.every(line => !line.trim())) { errors.push('empty_cue_text'); continue }
    if (textLines.some(line => /[<>\u0000-\u0008\u000B\u000C\u000E-\u001F\u202A-\u202E\u2066-\u2069]/u.test(line))) {
      errors.push('unsafe_caption_markup_or_control'); continue
    }
    if (textLines.length > 2) warnings.push('more_than_two_lines')
    if (textLines.some(line => [...line].length > 42)) warnings.push('line_over_42_chars')
    const text = textLines.join(' ').trim()
    const duration = end - start
    const cps = [...text].length / duration
    if (duration < .5) warnings.push('cue_below_half_second')
    if (duration > 7) warnings.push('cue_over_seven_seconds')
    if (cps > 22) warnings.push('reading_speed_over_22_cps')
    cues.push({ index: cues.length + 1, startSeconds: start, endSeconds: end, durationSeconds: Number(duration.toFixed(3)), charsPerSecond: Number(cps.toFixed(1)), lines: textLines.length })
    lastEnd = end
  }
  if (!cues.length) errors.push('no_cues')
  const uniqueWarnings = [...new Set(warnings)]
  return {
    valid: errors.length === 0,
    captionCandidatePass: errors.length === 0 && uniqueWarnings.length === 0,
    errors: [...new Set(errors)], warnings: uniqueWarnings, cues,
    summary: { count: cues.length, firstStart: cues[0]?.startSeconds ?? null, lastEnd: cues.at(-1)?.endSeconds ?? null, maxCps: Math.max(0,...cues.map(c => c.charsPerSecond)), durationSeconds, reviewRequired: true }
  }
}

async function fileHash(path) {
  const hash = createHash('sha256')
  for await (const chunk of createReadStream(path)) hash.update(chunk)
  return hash.digest('hex')
}

async function regularFile(path, maxSize) {
  try { const stat = await lstat(path); return stat.isFile() && !stat.isSymbolicLink() && stat.size > 0 && stat.size <= maxSize ? stat : null } catch { return null }
}

export async function inspectPrivateCaption(root, manifest, assetId, relativeVtt) {
  if (!VTT_PATH.test(relativeVtt || '') || relativeVtt.includes('..')) throw new Error('VTT must be a direct file under local captions/')
  if (manifest?.schemaVersion !== 1 || !Array.isArray(manifest.assets)) throw new Error('Invalid source manifest')
  const asset = manifest.assets.find(a => a.id === assetId)
  if (!asset || !['ru','en'].includes(asset.locale) || !SHA.test(asset.sha256 || '') || !/^[A-Za-z0-9_.-]+\.mp4$/.test(asset.file || '')) throw new Error('Unknown or invalid original asset')
  const rootPath = resolve(root)
  const captionDir = join(rootPath, 'captions')
  const dirStat = await lstat(captionDir).catch(() => null)
  if (!dirStat?.isDirectory() || dirStat.isSymbolicLink()) throw new Error('Private captions/ directory is missing or a symlink')
  const captionPath = join(rootPath, relativeVtt)
  const captionStat = await regularFile(captionPath, 2_000_000)
  if (!captionStat) throw new Error('VTT is missing, oversized or a symlink')
  const raw = await readFile(captionPath, 'utf8')
  const validation = inspectWebVtt(raw, asset.durationSeconds)
  const masterPath = join(rootPath, asset.file)
  const sourceStat = await regularFile(masterPath, 2_000_000_000)
  const observedMediaSha256 = sourceStat ? await fileHash(masterPath) : null
  const mediaVerified = Boolean(sourceStat && sourceStat.size === asset.sizeBytes && observedMediaSha256 === asset.sha256)
  const blockers = [
    ...validation.errors.map(v => 'caption_' + v),
    ...validation.warnings.map(v => 'caption_review_' + v),
    ...(!mediaVerified ? ['original_media_missing_or_hash_mismatch'] : []),
    'human_spoken_language_and_transcript_unverified',
    'human_caption_timing_approval_missing',
    'commercial_rights_and_delivery_unverified'
  ]
  return {
    schemaVersion: 1, kind: 'OSA_CINEMA_V19_PRIVATE_CAPTION_INTAKE', assetId: asset.id, locale: asset.locale,
    originalFile: asset.file, originalSha256: asset.sha256, observedMediaSha256,
    mediaVerified, captionFile: relativeVtt, captionSha256: createHash('sha256').update(raw).digest('hex'),
    captionCandidatePass: validation.captionCandidatePass, subtitleQc: { ...validation, cues: validation.cues },
    blockers, publicationAuthorized: false, released: false,
    warning: 'Syntax and timing measurements are NOT a transcript review, language approval, copyright clearance, or deploy authorization.'
  }
}

function readArgs(argv) {
  const opts = { root: 'osa-media-staging', manifest: 'docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json', asset: '', vtt: '', report: '', strict: false }
  for (let i = 0; i < argv.length; i++) {
    const key = argv[i]
    if (key === '--strict-caption-qc') opts.strict = true
    else if (key === '--root') opts.root = argv[++i]
    else if (key === '--manifest') opts.manifest = argv[++i]
    else if (key === '--asset-id') opts.asset = argv[++i]
    else if (key === '--vtt') opts.vtt = argv[++i]
    else if (key === '--report') opts.report = argv[++i]
    else throw new Error('Unknown argument ' + key)
  }
  if (!opts.asset || !opts.vtt) throw new Error('Both --asset-id and --vtt are required')
  return opts
}

export async function main(argv = process.argv.slice(2)) {
  const opts = readArgs(argv)
  const manifest = JSON.parse(await readFile(opts.manifest, 'utf8'))
  const report = await inspectPrivateCaption(opts.root, manifest, opts.asset, opts.vtt)
  if (opts.report) { await mkdir(dirname(resolve(opts.report)), {recursive:true}); await writeFile(opts.report, JSON.stringify(report, null, 2) + '\n', {mode:0o600}) }
  console.log('OSA_CINEMA_V19_PRIVATE_CAPTION_QC ' + JSON.stringify({assetId:report.assetId,mediaVerified:report.mediaVerified,captionCandidatePass:report.captionCandidatePass,blockers:report.blockers,publicationAuthorized:false}))
  if (opts.strict && !report.captionCandidatePass) process.exitCode = 1
  return report
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(e => { console.error(e.message); process.exitCode = 2 })
