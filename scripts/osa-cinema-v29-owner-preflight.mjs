/**
 * OSA CINEMA V29 -- one-command PRIVATE owner-side film preflight.
 * This composes the existing V28/V24/V21/V26/V25/V27 implementations.
 * Only local 127.0.0.1 services and owner-controlled files are used.
 * There is deliberately NO action that enables public distribution or payment.
 */
import { createHash, randomBytes } from 'node:crypto'
import { constants } from 'node:fs'
import { lstat, open, mkdir, realpath, writeFile } from 'node:fs/promises'
import { basename, dirname, join, resolve, sep } from 'node:path'
import { fileURLToPath } from 'node:url'
import { buildPrivateCandidatePlan } from './osa-cinema-v28-final-intake.mjs'
import { inspectFinalMasters } from './osa-cinema-v24-final-master-qc.mjs'
import { startPrivateReviewServer } from './osa-cinema-v21-private-review-server.mjs'
import { checkLoopbackDelivery } from './osa-cinema-v26-loopback-delivery-qc.mjs'
import { auditRightsEvidence } from './osa-cinema-v25-rights-evidence.mjs'
import { buildGoNoGoBoard, EXTERNAL_GATES } from './osa-cinema-v27-release-board.mjs'

const hash = x => createHash('sha256').update(JSON.stringify(x)).digest('hex')
const ZERO_RELEASE = Object.freeze({
  publicationAuthorized: false, rightsCleared: false, paidCheckoutEnabled: false,
  publicCatalogueWriteAllowed: false, productionDeploymentPerformed: false,
})

/** Read a small trusted local JSON report, never a symlink or a network URL. */
async function readPrivateJson(path) {
  const stat = await lstat(path)
  if (!stat.isFile() || stat.isSymbolicLink() || stat.size < 2 || stat.size > 2_000_000)
    throw Error('Unsafe, empty, or oversized private JSON input')
  const fd = await open(path, constants.O_RDONLY | constants.O_NOFOLLOW)
  try {
    const content = await fd.readFile({ encoding: 'utf8' })
    return JSON.parse(content)
  } finally { await fd.close() }
}

/** An optional frozen V28 manifest prevents silently accepting a swapped candidate. */
export function assertPinnedCandidates(generated, pinned) {
  if (pinned?.schemaVersion !== 1 || pinned?.project !== 'OSA CINEMA' ||
      pinned.publicationAuthorized !== false || pinned.commercialRightsCleared !== false ||
      !Array.isArray(pinned.assets) || pinned.assets.length !== 4)
    throw Error('Invalid or falsely approved frozen candidate manifest')
  const actual = new Map(generated.assets.map(x => [x.id, x]))
  if (actual.size !== 4 || new Set(pinned.assets.map(x => x.id)).size !== 4)
    throw Error('Incomplete or repeated pinned film identity')
  const fields = ['id','edition','locale','sourceSha256','masterName','masterSha256',
    'masterBytes','captionName','captionSha256','durationSeconds','width','height']
  for (const expected of pinned.assets) {
    const candidate = actual.get(expected.id)
    if (!candidate || fields.some(key => candidate[key] !== expected[key]))
      throw Error('Frozen release candidate differs from actual MP4/WebVTT bytes or metadata')
  }
  return true
}

function requireResponse(res, status, action) {
  if (res.status !== status) throw Error('Private screening ' + action + ' did not return ' + status)
}

/** Obtain a real single-use CSRF challenge, an HttpOnly editor session, then log out. */
export async function verifyAuthenticatedCandidate({ root, candidate }) {
  const asset = {
    id: candidate.id, edition: candidate.edition, locale: candidate.locale,
    file: candidate.masterName, sha256: candidate.masterSha256,
    sizeBytes: candidate.masterBytes, durationSeconds: candidate.durationSeconds,
    width: candidate.width, height: candidate.height,
    videoCodec: 'h264', audioCodec: 'aac',
  }
  const password = randomBytes(32).toString('hex')
  const service = await startPrivateReviewServer({
    sourceDir: join(resolve(root), 'masters'), asset, password, port: 0, cutTimes: [],
  })
  try {
    const base = service.url
    if (!/^http:\/\/127\.0\.0\.1:[0-9]+$/.test(base)) throw Error('Review escaped 127.0.0.1')
    const loginPage = await fetch(base + '/', { redirect: 'manual' })
    requireResponse(loginPage, 200, 'login page')
    const challenge = /name="csrf" value="([a-f0-9]{64})"/.exec(await loginPage.text())?.[1]
    if (!challenge) throw Error('Private screening login has no single-use challenge')
    const response = await fetch(base + '/login', {
      method: 'POST', redirect: 'manual',
      headers: { Origin: base, 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ csrf: challenge, password }).toString(),
    })
    requireResponse(response, 303, 'challenge-bound login')
    const cookie = response.headers.get('set-cookie')?.split(';')[0] || ''
    if (!/^osa_private_session=[a-f0-9]{64}$/.test(cookie))
      throw Error('Private screening session cookie missing or malformed')
    const headers = { Cookie: cookie }
    const statusResponse = await fetch(base + '/status', { headers })
    requireResponse(statusResponse, 200, 'private status')
    const status = await statusResponse.json()
    if (status.sha256 !== candidate.masterSha256 || status.sourceId !== candidate.id ||
        status.publicationAuthorized !== false || status.rightsCleared !== false)
      throw Error('Private server status does not match the locked candidate')
    const delivery = await checkLoopbackDelivery({
      url: base + '/media', source: join(resolve(root), 'masters', candidate.masterName),
      sha256: candidate.masterSha256, cookie,
    })
    if (delivery.status !== 'LOOPBACK_RANGE_QA_PASS_NOT_PUBLIC' ||
        !delivery.fullContentVerified || delivery.errors.length)
      throw Error('Private candidate full-file HTTP Range/SHA verification failed')
    const review = await fetch(base + '/review', { headers })
    requireResponse(review, 200, 'review page')
    const logoutChallenge = /name="csrf" value="([a-f0-9]{64})"/.exec(await review.text())?.[1]
    if (!logoutChallenge) throw Error('Private screening logout challenge missing')
    const logout = await fetch(base + '/logout', {
      method: 'POST', redirect: 'manual',
      headers: { ...headers, Origin: base, 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ csrf: logoutChallenge }).toString(),
    })
    requireResponse(logout, 303, 'challenge-bound logout')
    const denied = await fetch(base + '/media', { headers: { ...headers, Range: 'bytes=0-15' } })
    requireResponse(denied, 401, 'revoked session video access')
    await denied.body?.cancel()
    return delivery // Does not contain session tokens, URLs or the private password.
  } finally { await service.close() }
}

function privateSummary({ generated, masters, rights, delivery, board, pinned }) {
  const masterCount = masters.technical.passed
  const deliveryCount = delivery.filter(x => x.status === 'LOOPBACK_RANGE_QA_PASS_NOT_PUBLIC' && x.fullContentVerified).length
  const rightsCount = rights?.coverage.documentBytesVerified ?? 0
  const technicallyComplete = masterCount === 4 && deliveryCount === 4 &&
    Boolean(board?.technicalCandidateEvidenceComplete)
  const blockers = [
    ...(!pinned ? ['frozen_exact_candidate_manifest_missing'] : []),
    ...(masterCount !== 4 ? ['four_video_and_caption_masters_not_verified'] : []),
    ...(deliveryCount !== 4 ? ['four_private_http_byte_checks_not_verified'] : []),
    ...(!rights ? ['rights_usage_manifest_and_real_document_ledger_missing'] : []),
    ...(rights && !board?.technicalCandidateEvidenceComplete ? ['evidence_coverage_incomplete'] : []),
    ...EXTERNAL_GATES,
  ]
  return {
    schemaVersion: 1, project: 'OSA CINEMA', stage: 'V29_PRIVATE_OWNER_PREFLIGHT',
    result: 'NO_GO', candidatePinnedToPreviousHash: pinned,
    candidateAssets: generated.assets.map(a => ({
      id: a.id, locale: a.locale, edition: a.edition,
      finalSha256: a.masterSha256, captionSha256: a.captionSha256,
    })),
    technical: { mastersPassed: masterCount, privateHttpPassed: deliveryCount,
      evidenceDocumentsVerified: rightsCount, evidenceTechnicallyComplete: technicallyComplete },
    fingerprints: { v28: hash(generated), v24: hash(masters),
      v25: rights ? hash(rights) : null, v26: delivery.map(hash),
      v27: board ? hash(board) : null },
    blockers, independentExternalAuthorizationsOutstanding: EXTERNAL_GATES,
    ...ZERO_RELEASE,
    notice: 'LOCAL technical evidence only. No human speech, rights, creative approval, physical-device or production validation was performed.',
  }
}

/** Writes a fresh private evidence directory only after the entire preflight is complete. */
export async function runOwnerPreflight({ root, originals, outputDir, rightsUsage = null, pinnedPlan = null }) {
  if (!root || !originals || !outputDir) throw Error('Required: root, originals and outputDir')
  const source = await realpath(resolve(root))
  const destination = resolve(outputDir)
  if (destination === source || destination.startsWith(source + sep))
    throw Error('Evidence output must stay outside private media folder')
  await mkdir(dirname(destination), { recursive: true, mode: 0o700 })
  const trueParent = await realpath(dirname(destination))
  const final = join(trueParent, basename(destination))
  if (final === source || final.startsWith(source + sep))
    throw Error('Evidence parent points back into private media folder')
  const initial = await readPrivateJson(originals)
  const generated = await buildPrivateCandidatePlan(source, initial)
  const pinned = pinnedPlan ? await readPrivateJson(pinnedPlan) : null
  if (pinned) assertPinnedCandidates(generated, pinned)
  const masters = await inspectFinalMasters(source, generated, initial)
  if (masters.technical.passed !== 4) throw Error('V24 failed; refuse to serve unverified media')
  const delivery = []
  for (const candidate of generated.assets)
    delivery.push(await verifyAuthenticatedCandidate({ root: source, candidate }))
  const rights = rightsUsage ? await auditRightsEvidence(source, await readPrivateJson(rightsUsage), generated) : null
  const board = rights ? buildGoNoGoBoard(masters, rights, delivery) : null
  const summary = privateSummary({ generated, masters, rights, delivery, board, pinned: Boolean(pinned) })

  await mkdir(final, { recursive: false, mode: 0o700 }) // refuse overwrites
  const records = [
    ['V28_CANDIDATE_MANIFEST.json', generated],
    ['V24_MEDIA_QA.json', masters],
    ['V26_PRIVATE_DELIVERY_QA.json', delivery],
  ]
  if (rights) records.push(['V25_RIGHTS_BYTES_QA.json', rights])
  if (board) records.push(['V27_FINAL_NO_GO_BOARD.json', board])
  records.push(['V29_OWNER_PREFLIGHT_NO_GO.json', summary]) // summary is the final JSON file
  const checksums = []
  for (const [filename, record] of records) {
    const bytes = JSON.stringify(record, null, 2) + '\n'
    await writeFile(join(final, filename), bytes, { flag: 'wx', mode: 0o600 })
    checksums.push(createHash('sha256').update(bytes).digest('hex') + '  ' + filename)
  }
  await writeFile(join(final, 'CHECKSUMS.sha256'), checksums.join('\n') + '\n', { flag:'wx', mode:0o600 })
  return { summary, files: [...records.map(x=>x[0]), 'CHECKSUMS.sha256'], outputDir: final }
}

function parseArgs(args) {
  const options = { root: null, originals: 'docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json', outputDir: null,
    rightsUsage: null, pinnedPlan: null, strictPublication: false }
  for (let i = 0; i < args.length; i++) {
    const arg = args[i]
    if (arg === '--strict-publication') options.strictPublication = true
    else if (['--root','--originals','--out','--rights-usage','--pinned-plan'].includes(arg)) {
      const value = args[++i]
      if (!value || value.startsWith('--')) throw Error('Missing value for ' + arg)
      const key = { '--root':'root','--originals':'originals','--out':'outputDir',
        '--rights-usage':'rightsUsage','--pinned-plan':'pinnedPlan' }[arg]
      options[key] = value
    } else throw Error('Unexpected V29 argument ' + arg)
  }
  return options
}

async function main(args) {
  const options = parseArgs(args)
  const result = await runOwnerPreflight(options)
  console.log('OSA_CINEMA_V29_PRIVATE_NO_GO ' + JSON.stringify({
    masters: result.summary.technical.mastersPassed,
    privateHttp: result.summary.technical.privateHttpPassed,
    rightsDocuments: result.summary.technical.evidenceDocumentsVerified,
    decision: result.summary.result, publicationAuthorized: false,
    outputDir: result.outputDir,
  }))
  if (options.strictPublication) process.exitCode = 2
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url))
  main(process.argv.slice(2)).catch(e => { console.error('OSA_V29_FAILED ' + e.message); process.exitCode = 1 })
