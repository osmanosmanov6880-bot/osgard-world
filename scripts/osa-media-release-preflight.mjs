import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { existsSync } from 'node:fs'
import { resolve, join } from 'node:path'

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
      cells.push(value)
      value = ''
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
  if (['mp3','wav','m4a','aac','ogg','flac'].includes(extension)) return 'audio'
  if (['mp4','webm','mov','m4v'].includes(extension)) return 'video'
  if (['png','jpg','jpeg','webp','svg','avif'].includes(extension)) return 'image'
  return null
}
function isDurableMediaUrl(value) {
  if (typeof value !== 'string' || !value.trim()) return false
  const candidate = value.trim()
  if (candidate.startsWith('//') || candidate.includes(String.fromCharCode(92))) return false
  if (candidate.startsWith('/')) {
    if (!candidate.startsWith('/osa-library/media/')) return false
    if (candidate.includes('/../') || candidate.includes('/./')) return false
    const params = new URLSearchParams(candidate.includes('?') ? candidate.slice(candidate.indexOf('?') + 1) : '')
    for (const key of params.keys()) if (/jwt|token|signature|expires|credential|policy/i.test(key)) return false
    return true
  }
  try {
    const url = new URL(candidate)
    if (url.protocol !== 'https:' || url.username || url.password) return false
    if (/runwayml\.com|cloudfront\.net$/i.test(url.hostname)) return false
    for (const key of url.searchParams.keys()) if (/jwt|token|signature|expires|credential|policy/i.test(key)) return false
    return true
  } catch {
    return false
  }
}
function deriveBlockers(row, extensionKind) {
  const blockers = []
  if (!row.permanent_url) blockers.push('permanent_url_missing')
  if (['audio','video'].includes(row.kind) && !(Number(row.duration_seconds) > 0)) blockers.push('duration_unmeasured')
  if (['audio','video'].includes(row.kind) && !row.language) blockers.push('language_not_verified')
  if (row.kind === 'audio' && row.role !== 'score' && !row.transcript_path && !row.subtitle_url) blockers.push('transcript_or_subtitles_missing')
  if (row.rights_status !== 'cleared') blockers.push('rights_not_cleared')
  if (row.qc_status !== 'passed') blockers.push('quality_check_pending')
  if (row.status === 'NOT_FOUND_IN_RECENT_RUNWAY_LIST') blockers.push('source_not_found_in_current_workspace_list')
  if (extensionKind && extensionKind !== row.kind) blockers.push('declared_kind_mismatch')
  if (extensionKind && row.provider_kind && extensionKind !== row.provider_kind) blockers.push('provider_kind_mismatch')
  return blockers.sort()
}

const sourceRoot = resolve('public/osa-library')
const csv = await readFile(join(sourceRoot, 'media-inventory.csv'), 'utf8')
const manifest = JSON.parse(await readFile(join(sourceRoot, 'media-manifest.json'), 'utf8'))
const html = await readFile(join(sourceRoot, 'index.html'), 'utf8')
const rows = parseCsv(csv)
const requiredColumns = [
  'kind','slug','role','asset_id','permanent_url','status','source_repository',
  'provider_kind','source_extension','source_name','source_created_at','duration_seconds',
  'language','subtitle_url','transcript_path','rights_status','qc_status','publication_status','notes',
]
const headers = parseCsvLine(csv.trim().split(/\r?\n/)[0])
for (const column of requiredColumns) assert.ok(headers.includes(column), 'Media inventory is missing column: ' + column)
assert.ok(rows.length > 0, 'Media inventory must not be empty')
assert.equal(manifest.schemaVersion, 1, 'Unsupported media manifest schema')
assert.equal(manifest.assets.length, rows.length, 'Manifest and CSV record counts differ')
assert.equal(manifest.sourceOfTruth, 'public/osa-library/media-inventory.csv', 'Manifest source-of-truth path is stale')

const ids = new Set()
const calculated = { total: rows.length, sourceFound: 0, sourceMissing: 0, permanentUrls: 0, readyForPublication: 0, providerKindMismatches: 0 }
const blockersById = {}
for (const row of rows) {
  assert.ok(['audio','video','image'].includes(row.kind), 'Invalid declared media kind for ' + row.slug)
  assert.match(row.asset_id, /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i, 'Invalid source asset ID for ' + row.slug)
  assert.ok(!ids.has(row.asset_id), 'Duplicate asset ID: ' + row.asset_id)
  ids.add(row.asset_id)
  assert.ok(['FOUND_IN_RUNWAY_NOT_PERMANENTLY_HOSTED','NOT_FOUND_IN_RECENT_RUNWAY_LIST'].includes(row.status), 'Unknown source discovery status: ' + row.status)
  if (row.status === 'FOUND_IN_RUNWAY_NOT_PERMANENTLY_HOSTED') calculated.sourceFound += 1
  else calculated.sourceMissing += 1
  assert.ok(['unverified','cleared','restricted','rejected'].includes(row.rights_status), 'Unknown rights status for ' + row.slug)
  assert.ok(['pending','passed','failed'].includes(row.qc_status), 'Unknown QC status for ' + row.slug)
  assert.ok(['blocked','approved','ready','published'].includes(row.publication_status), 'Unknown publication status for ' + row.slug)

  if (row.permanent_url) {
    assert.ok(isDurableMediaUrl(row.permanent_url), 'Refusing temporary or unsafe URL for ' + row.slug)
    calculated.permanentUrls += 1
  }
  const extensionKind = expectedKindFromExtension(row.source_extension)
  if (extensionKind) assert.equal(extensionKind, row.kind, 'Declared media kind conflicts with file extension for ' + row.slug)
  if (extensionKind && row.provider_kind && extensionKind !== row.provider_kind) calculated.providerKindMismatches += 1

  const expectedBlockers = deriveBlockers(row, extensionKind)
  const media = manifest.assets.find(item => item.assetId === row.asset_id)
  assert.ok(media, 'Manifest is missing asset ' + row.asset_id)
  assert.equal(media.kind, row.kind, 'Kind differs between manifest and CSV for ' + row.slug)
  assert.equal(media.slug, row.slug, 'Slug differs between manifest and CSV for ' + row.slug)
  assert.equal(media.role, row.role, 'Role differs between manifest and CSV for ' + row.slug)
  assert.equal(media.sourceSnapshot.status, row.status, 'Source status differs for ' + row.slug)
  assert.equal(media.sourceSnapshot.providerReportedKind || '', row.provider_kind || '', 'Provider kind differs for ' + row.slug)
  assert.equal(media.sourceSnapshot.extension || '', row.source_extension || '', 'Extension differs for ' + row.slug)
  assert.equal(media.publication.permanentUrl, row.permanent_url || null, 'Permanent URL differs for ' + row.slug)
  assert.equal(media.publication.durationSeconds, row.duration_seconds ? Number(row.duration_seconds) : null, 'Duration differs for ' + row.slug)
  assert.equal(media.publication.language, row.language || null, 'Language differs for ' + row.slug)
  assert.equal(media.publication.subtitleUrl, row.subtitle_url || null, 'Subtitle URL differs for ' + row.slug)
  assert.equal(media.publication.transcriptPath, row.transcript_path || null, 'Transcript path differs for ' + row.slug)
  assert.equal(media.publication.rightsStatus, row.rights_status, 'Rights state differs for ' + row.slug)
  assert.equal(media.publication.qualityStatus, row.qc_status, 'QC state differs for ' + row.slug)
  assert.equal(media.publication.status, row.publication_status, 'Publication status differs for ' + row.slug)
  assert.deepEqual([...media.blockers].sort(), expectedBlockers, 'Blocker list is stale for ' + row.slug)
  blockersById[row.asset_id] = expectedBlockers

  if (['ready','published'].includes(row.publication_status)) {
    assert.deepEqual(expectedBlockers, [], 'Media marked ready/published still has blockers: ' + row.slug)
    calculated.readyForPublication += 1
  }
}
for (const [key,value] of Object.entries(calculated)) assert.equal(manifest.metrics[key], value, 'Manifest metric drift: ' + key)
assert.equal(manifest.metrics.total, rows.length, 'Total asset count is stale')
assert.ok(manifest.policy.temporaryRunwayUrlsAllowed === false, 'Temporary Runway URLs must remain forbidden')
const serializedManifest = JSON.stringify(manifest)
assert.ok(!/cloudfront\.net|_jwt=|signed_url|temporary_url/i.test(serializedManifest), 'Manifest must not contain temporary source URLs')
for (const row of rows) assert.ok(html.includes(row.asset_id), 'Public audit page omits asset ID ' + row.asset_id)
assert.ok(html.includes('data-media-count="' + calculated.total + '"'), 'Public audit page total is stale')
assert.ok(html.includes('data-source-found="' + calculated.sourceFound + '"'), 'Public audit page source-found count is stale')
assert.ok(html.includes('data-source-missing="' + calculated.sourceMissing + '"'), 'Public audit page missing-source count is stale')
assert.ok(html.includes('data-published-media="' + calculated.readyForPublication + '"'), 'Public audit page publication count is stale')

const checkDist = process.argv.includes('--check-dist')
if (checkDist) {
  for (const name of ['media-inventory.csv','media-manifest.json','index.html']) {
    const distPath = resolve('dist/osa-library/' + name)
    assert.ok(existsSync(distPath), 'Built site is missing osa-library/' + name)
    assert.equal(await readFile(distPath, 'utf8'), await readFile(join(sourceRoot, name), 'utf8'), 'Built static asset differs from source: ' + name)
  }
}
if (process.argv.includes('--strict-ready')) {
  const blocked = rows.filter(row => !['ready','published'].includes(row.publication_status) || (blockersById[row.asset_id]||[]).length > 0)
  assert.equal(blocked.length, 0, 'Strict media launch gate blocked: ' + blocked.length + ' of ' + rows.length + ' assets are not ready. Do not enable media until the manifest is cleared.')
  assert.equal(calculated.readyForPublication, rows.length, 'Not all registered assets are published')
}
console.log(JSON.stringify({
  status: calculated.readyForPublication === rows.length ? 'ready-for-media-publication' : 'inventory-validated-publication-blocked',
  metrics: calculated,
  blockersByCategory: rows.reduce((totals,row) => {
    const media = manifest.assets.find(item => item.assetId === row.asset_id)
    for (const blocker of media.blockers) totals[blocker] = (totals[blocker]||0)+1
    return totals
  }, {}),
  strictReadyRequested: process.argv.includes('--strict-ready'),
  checkedBuiltArtifacts: checkDist,
  note: 'The check validates inventory, metadata, policy and build copies. It does not convert temporary Runway URLs into durable hosting or claim that playback works.',
}, null, 2))
