import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { readdir, readFile, mkdir, writeFile } from 'node:fs/promises'
import { spawnSync } from 'node:child_process'
import { basename, dirname, extname, join, resolve, sep } from 'node:path'

function parseCsvLine(line) {
  const cells = []
  let value = ''
  let quoted = false
  for (let i = 0; i < line.length; i += 1) {
    const ch = line[i]
    if (ch === '"') {
      if (quoted && line[i + 1] === '"') { value += '"'; i += 1 }
      else quoted = !quoted
    } else if (ch === ',' && !quoted) {
      cells.push(value); value = ''
    } else value += ch
  }
  cells.push(value)
  return cells
}
function parseCsv(source) {
  const lines = source.trim().split(/\r?\n/)
  const headers = parseCsvLine(lines.shift() || '')
  return lines.map(line => {
    const values = parseCsvLine(line)
    return Object.fromEntries(headers.map((name, index) => [name, values[index] ?? '']))
  })
}
function expectedKindFromExtension(extension) {
  const ext = extension.toLowerCase().replace(/^\./, '')
  if (['mp3','wav','m4a','aac','ogg','flac'].includes(ext)) return 'audio'
  if (['mp4','webm','mov','m4v'].includes(ext)) return 'video'
  if (['png','jpg','jpeg','webp','svg','avif','gif'].includes(ext)) return 'image'
  return null
}
function mimeFromExtension(extension) {
  const ext = extension.toLowerCase().replace(/^\./, '')
  const values = {
    mp3: 'audio/mpeg', wav: 'audio/wav', m4a: 'audio/mp4', aac: 'audio/aac',
    ogg: 'audio/ogg', flac: 'audio/flac',
    mp4: 'video/mp4', webm: 'video/webm', mov: 'video/quicktime', m4v: 'video/mp4',
    png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg', webp: 'image/webp',
    svg: 'image/svg+xml', avif: 'image/avif', gif: 'image/gif',
  }
  return values[ext] || 'application/octet-stream'
}
function detectMediaKind(buffer) {
  if (!Buffer.isBuffer(buffer) || buffer.length < 4) return null
  if (buffer.length >= 8 && buffer.subarray(0, 8).equals(Buffer.from([0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a]))) return 'image'
  if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) return 'image'
  if (buffer.length >= 12 && buffer.toString('ascii',0,4) === 'RIFF' && buffer.toString('ascii',8,12) === 'WEBP') return 'image'
  if (buffer.toString('ascii',0,3) === 'GIF') return 'image'
  if (buffer.toString('ascii',0,3) === 'ID3') return 'audio'
  if (buffer[0] === 0xff && (buffer[1] & 0xe0) === 0xe0) return 'audio'
  if (buffer.length >= 12 && buffer.toString('ascii',4,8) === 'ftyp') return 'video'
  if (buffer.length >= 4 && buffer[0] === 0x1a && buffer[1] === 0x45 && buffer[2] === 0xdf && buffer[3] === 0xa3) return 'video'
  if (buffer.length >= 12 && buffer.toString('ascii',0,4) === 'RIFF' && buffer.toString('ascii',8,12) === 'WAVE') return 'audio'
  return null
}
function assertSignature(extension, buffer, expectedKind) {
  const extKind = expectedKindFromExtension(extension)
  const actualKind = detectMediaKind(buffer)
  return {
    actualKind,
    extKind,
    signatureKnown: actualKind !== null,
    signatureMatchesExtension: extKind !== null && actualKind === extKind,
    signatureMatchesDeclaredKind: expectedKind !== null && actualKind === expectedKind,
  }
}
function parseArgs(argv) {
  const result = { selfTest: argv.includes('--self-test'), strict: argv.includes('--strict'), root: 'osa-media-staging', report: null }
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === '--root') result.root = argv[++i]
    else if (argv[i] === '--write-report') result.report = argv[++i]
  }
  return result
}
function probeWithFfprobe(file) {
  const result = spawnSync('ffprobe', [
    '-v','error',
    '-show_entries','format=duration,format_name:stream=codec_type,codec_name,width,height:stream_tags=language',
    '-of','json', file,
  ], { encoding: 'utf8', timeout: 30000, maxBuffer: 2 * 1024 * 1024 })
  if (result.error && result.error.code === 'ENOENT') return { available: false, durationSeconds: null, streams: [], error: 'ffprobe_not_installed' }
  if (result.error) return { available: true, durationSeconds: null, streams: [], error: String(result.error.message || result.error) }
  if (result.status !== 0) return { available: true, durationSeconds: null, streams: [], error: (result.stderr || 'ffprobe_failed').trim() }
  try {
    const parsed = JSON.parse(result.stdout || '{}')
    const duration = Number(parsed.format?.duration)
    return {
      available: true,
      durationSeconds: Number.isFinite(duration) && duration > 0 ? Number(duration.toFixed(3)) : null,
      formatName: parsed.format?.format_name || null,
      streams: (parsed.streams || []).map(stream => ({
        kind: stream.codec_type || null,
        codec: stream.codec_name || null,
        width: Number.isFinite(Number(stream.width)) ? Number(stream.width) : null,
        height: Number.isFinite(Number(stream.height)) ? Number(stream.height) : null,
        language: stream.tags?.language || null,
      })),
      error: null,
    }
  } catch {
    return { available: true, durationSeconds: null, streams: [], error: 'ffprobe_returned_invalid_json' }
  }
}
function sha256(buffer) {
  return createHash('sha256').update(buffer).digest('hex')
}
function getPublicationBlockers(row) {
  const blockers = []
  if (!row.permanent_url) blockers.push('permanent_url_missing')
  if (['audio','video'].includes(row.kind) && !(Number(row.duration_seconds) > 0)) blockers.push('duration_unmeasured_in_inventory')
  if (['audio','video'].includes(row.kind) && !row.language) blockers.push('language_not_verified')
  if (row.kind === 'audio' && row.role !== 'score' && !row.transcript_path && !row.subtitle_url) blockers.push('transcript_or_subtitles_missing')
  if (row.rights_status !== 'cleared') blockers.push('rights_not_cleared')
  if (row.qc_status !== 'passed') blockers.push('quality_check_pending')
  if (row.status === 'NOT_FOUND_IN_RECENT_RUNWAY_LIST') blockers.push('source_not_resolved')
  if (!['ready','published'].includes(row.publication_status)) blockers.push('publication_status_not_ready')
  return blockers
}
function runSelfTest() {
  const fixtures = [
    { extension: 'mp3', bytes: Buffer.from([0x49,0x44,0x33,0x04,0x00,0x00,0x00,0x00,0x00,0x00]), expected: 'audio' },
    { extension: 'mp4', bytes: Buffer.from([0,0,0,24,0x66,0x74,0x79,0x70,0x69,0x73,0x6f,0x6d]), expected: 'video' },
    { extension: 'png', bytes: Buffer.from([0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a]), expected: 'image' },
    { extension: 'jpg', bytes: Buffer.from([0xff,0xd8,0xff,0xe0]), expected: 'image' },
    { extension: 'webp', bytes: Buffer.from('RIFF0000WEBP', 'ascii'), expected: 'image' },
  ]
  for (const fixture of fixtures) {
    const detected = assertSignature(fixture.extension, fixture.bytes, fixture.expected)
    assert.equal(detected.actualKind, fixture.expected, 'Signature detector failed for .' + fixture.extension)
    assert.equal(detected.signatureMatchesExtension, true, 'Extension check failed for .' + fixture.extension)
    assert.equal(detected.signatureMatchesDeclaredKind, true, 'Declared-kind check failed for .' + fixture.extension)
  }
  const impostor = assertSignature('mp4', Buffer.from([0x49,0x44,0x33,0x04,0x00,0x00]), 'video')
  assert.equal(impostor.signatureMatchesExtension, false, 'MP3 bytes must not pass an MP4 extension')
  assert.equal(expectedKindFromExtension('unknown'), null, 'Unknown extension must not be trusted')
  assert.equal(mimeFromExtension('mp3'), 'audio/mpeg', 'MP3 MIME contract failed')
  console.log('OSA_MEDIA_FILE_AUDIT_SELF_TEST_PASS: MP3/MP4/PNG/JPEG/WebP magic bytes, extension and MIME mismatch cases verified.')
}
async function main() {
  const args = parseArgs(process.argv.slice(2))
  if (args.selfTest) { runSelfTest(); return }

  const inventory = parseCsv(await readFile('public/osa-library/media-inventory.csv','utf8'))
  const root = resolve(args.root || 'osa-media-staging')
  const rootEntries = await readdir(root, { withFileTypes: true })
  const regularFiles = rootEntries.filter(entry => entry.isFile()).map(entry => entry.name)
  const assets = []

  for (const row of inventory) {
    const blockers = []
    const warnings = []
    if (!/^[0-9a-f-]{36}$/i.test(row.asset_id || '')) {
      assets.push({ assetId: row.asset_id || null, slug: row.slug, status: 'blocked', blockers: ['invalid_asset_id'] })
      continue
    }
    const candidates = regularFiles.filter(name => name.startsWith(row.asset_id + '.'))
    if (candidates.length === 0) {
      blockers.push('staging_file_missing')
      assets.push({
        assetId: row.asset_id, slug: row.slug, kind: row.kind, status: 'blocked',
        file: null, bytes: null, sha256: null, detectedKind: null, mimeType: null, durationSeconds: null,
        signatureStatus: 'not_checked', ffprobeStatus: 'not_checked', blockers,
        publicationBlockers: getPublicationBlockers(row),
      })
      continue
    }
    if (candidates.length > 1) blockers.push('multiple_staging_files_for_asset_id')
    const filename = candidates[0]
    if (filename.includes(sep) || basename(filename) !== filename) blockers.push('unsafe_staging_filename')
    const extension = extname(filename).slice(1).toLowerCase()
    const filePath = join(root, filename)
    const bytes = await readFile(filePath)
    const detected = assertSignature(extension, bytes, row.kind)
    if (!detected.signatureKnown) blockers.push('file_signature_unrecognized')
    if (!detected.signatureMatchesExtension) blockers.push('file_signature_extension_mismatch')
    if (!detected.signatureMatchesDeclaredKind) blockers.push('file_kind_differs_from_inventory')
    if (row.source_extension && extension !== row.source_extension.toLowerCase()) warnings.push('staging_extension_differs_from_source_hint')
    const probed = ['audio','video'].includes(detected.actualKind) ? probeWithFfprobe(filePath) : { available: true, durationSeconds: null, streams: [], error: null }
    if (['audio','video'].includes(detected.actualKind)) {
      if (!probed.available) blockers.push('ffprobe_not_installed_duration_unverifiable')
      else if (!(probed.durationSeconds > 0)) blockers.push('duration_unmeasured_or_probe_failed')
      if (probed.available && !probed.streams.some(stream => stream.kind === detected.actualKind)) blockers.push('expected_media_stream_missing')
    }
    assets.push({
      assetId: row.asset_id, slug: row.slug, kind: row.kind,
      status: blockers.length ? 'blocked' : 'file_verified',
      file: filename, bytes: bytes.length, sha256: sha256(bytes),
      detectedKind: detected.actualKind, mimeType: mimeFromExtension(extension), extension,
      signatureStatus: detected.signatureKnown && detected.signatureMatchesExtension && detected.signatureMatchesDeclaredKind ? 'passed' : 'failed',
      ffprobeStatus: ['audio','video'].includes(detected.actualKind) ? (probed.available && probed.durationSeconds ? 'passed' : 'failed') : 'not_required',
      durationSeconds: probed.durationSeconds, streams: probed.streams || [], warnings, blockers,
      publicationBlockers: getPublicationBlockers(row),
    })
  }
  const report = {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    stagingRootLabel: basename(root),
    strict: args.strict,
    totals: {
      registeredAssets: inventory.length,
      stagingFilesFound: assets.filter(asset => asset.file).length,
      filesWithValidSignatures: assets.filter(asset => asset.signatureStatus === 'passed').length,
      filesWithMeasuredDuration: assets.filter(asset => asset.durationSeconds > 0).length,
      fullyPublishable: assets.filter(asset => asset.status === 'file_verified' && asset.publicationBlockers.length === 0).length,
      blocked: assets.filter(asset => asset.status !== 'file_verified' || asset.publicationBlockers.length > 0).length,
    },
    assets,
    note: 'This local audit validates staged bytes and publication metadata. It does not upload, publish or make media playable on production.',
  }
  if (args.report) {
    const reportPath = resolve(args.report)
    await mkdir(dirname(reportPath), { recursive: true })
    await writeFile(reportPath, JSON.stringify(report, null, 2) + '\n', 'utf8')
  }
  console.log(JSON.stringify(report, null, 2))
  if (args.strict && report.totals.blocked > 0) {
    console.error('OSA_MEDIA_FILE_AUDIT_BLOCKED: ' + report.totals.blocked + ' of ' + inventory.length + ' registered assets need more work.')
    process.exitCode = 1
  }
}
await main()
