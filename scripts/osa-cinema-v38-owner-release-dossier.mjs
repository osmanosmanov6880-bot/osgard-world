/**
 * OSA CINEMA V38: offline, read-only private owner release dossier.
 * Performs real V35 (genuine Git source snapshot), V36 (receipts), V37
 * (four MP4 + four WebVTT), and optionally V30 (eight signed statements).
 * No code path can authorize publication, payments, deployment or legal rights.
 */
import { createHash } from 'node:crypto'
import { constants } from 'node:fs'
import { lstat, open, realpath } from 'node:fs/promises'
import { dirname, isAbsolute, join, resolve, sep } from 'node:path'
import { fileURLToPath } from 'node:url'
import { verifyHistoricalEvidence } from './osa-cinema-v35-historical-guard.mjs'
import { verifyPrivateReceiptDirectory } from './osa-cinema-v36-verify-private-receipts.mjs'
import { verifyPrivateMediaBytes } from './osa-cinema-v37-verify-private-media.mjs'
import { verifyExternalAttestations } from './osa-cinema-v30-external-attestations.mjs'
import { EXTERNAL_GATES } from './osa-cinema-v27-release-board.mjs'

const SHA = /^[a-f0-9]{64}$/
const requireThat = (pass, message) => {
  if (!pass) throw Error('OSA_V38_RELEASE_HOLD: ' + message)
}
const digest = bytes => createHash('sha256').update(bytes).digest('hex')
const equalRoles = (a, b) => Array.isArray(a) && a.length === b.length &&
  new Set(a).size === b.length && b.every(role => a.includes(role))
const canRelease = result => result?.publicationAuthorized === false &&
  result?.rightsCleared === false && result?.paidCheckoutEnabled === false

/** Pure contract validator: never accepts a report with a GO flag or counterfeit counters. */
export function composePrivateDossier({ historical, receipts, media, signatures = null }) {
  requireThat(historical?.stage === 'V35_HISTORICAL_CODE_REPOSITORY_GUARD' &&
    historical.verifiedHistoricalSnapshot === true &&
    historical.testOrCustomPinMode === false &&
    historical.releaseDecision === 'NO_GO' && canRelease(historical),
    'genuine historical V16/V18/V20 snapshot missing')
  requireThat(receipts?.stage === 'V36_PRIVATE_RECEIPT_INTEGRITY' &&
    receipts.reportSelfConsistent === true &&
    [4, 6].includes(receipts.receiptRecordsValidated) &&
    receipts.decision === 'NO_GO' && canRelease(receipts) &&
    equalRoles(receipts.outstandingIndependentGates, EXTERNAL_GATES),
    'V29 evidence receipts missing, inconsistent or falsely released')
  requireThat(media?.stage === 'V37_PRIVATE_MEDIA_BYTE_AUDIT' &&
    media.bytesMatched === true && media.reportPackageSelfConsistent === true &&
    media.verifiedPrivateVideoFiles === 4 && media.verifiedPrivateCaptionFiles === 4 &&
    media.checkedWebvttHeadersAndFirstCues === true &&
    Array.isArray(media.perEdition) && media.perEdition.length === 4 &&
    new Set(media.perEdition.map(x => x.id)).size === 4 &&
    media.perEdition.every(x => x.bytesMatched === true) &&
    media.decision === 'NO_GO' && canRelease(media) &&
    media.publicCatalogueWriteAllowed === false &&
    media.productionDeploymentPerformed === false,
    'four real MP4 and four VTT bytes have not been independently verified')
  if (signatures !== null) {
    requireThat(receipts.receiptRecordsValidated === 6,
      'external signed approvals require actual rights evidence receipts')
    requireThat(signatures.stage === 'V30_INDEPENDENT_EXTERNAL_SIGNATURE_VERIFICATION' &&
      signatures.status === 'ALL_EIGHT_SIGNATURES_CRYPTOGRAPHICALLY_VERIFIED_PRIVATE_ONLY' &&
      signatures.verifiedSignatures === 8 && signatures.requiredSignatures === 8 &&
      Array.isArray(signatures.missingRoles) && signatures.missingRoles.length === 0 &&
      Array.isArray(signatures.invalidRoles) && signatures.invalidRoles.length === 0 &&
      SHA.test(signatures.releaseFingerprint || '') &&
      SHA.test(signatures.signerRegistrySha256 || '') &&
      signatures.publicFilmPublicationAuthorized === false &&
      signatures.paidCheckoutEnabled === false &&
      signatures.legalContentReviewedBySoftware === false &&
      signatures.publisherLegalAuthorityVerifiedBySoftware === false &&
      signatures.realProductionVerifiedBySoftware === false &&
      signatures.decision === 'NO_GO_UNTIL_INDEPENDENT_FINAL_HUMAN_AND_PRODUCTION_RELEASE',
      'V30 signer evidence is incomplete, expired, or misleading')
  }
  return Object.freeze({
    schemaVersion: 1,
    project: 'OSA CINEMA',
    stage: 'V38_OWNER_OFFLINE_RELEASE_DOSSIER',
    status: 'TECHNICAL_EVIDENCE_VERIFIED_FOR_PRIVATE_REVIEW',
    evidence: Object.freeze({
      genuineHistoricalDocuments: 3,
      checkedPrivateReceiptReports: receipts.receiptRecordsValidated,
      checkedLocalMP4: 4,
      checkedLocalWebVTT: 4,
      signedClaimCount: signatures ? 8 : 0,
      signedClaimsStatus: signatures ? 'CRYPTOGRAPHICALLY_VERIFIED_PRIVATE_ONLY' : 'NOT_PROVIDED',
    }),
    independentLegalHumanAndProductionGatesStillRequired: [...EXTERNAL_GATES],
    actualFinalFilmEditoriallyAccepted: false,
    legalRightsIndependentReviewComplete: false,
    publicHttpsAndDeviceQaComplete: false,
    publisherLegalAuthorityEstablishedBySoftware: false,
    releaseDecision: 'NO_GO',
    publicationAuthorized: false,
    rightsCleared: false,
    paidCheckoutEnabled: false,
    publicCatalogueWriteAllowed: false,
    productionDeploymentPerformed: false,
    notice: 'Technical file matching, receipt consistency and signed claims do not prove legal permission, truth of claims, human editorial approval or production acceptance.',
  })
}

async function safePrivatePath(path, label, { file = false } = {}) {
  requireThat(typeof path === 'string' && isAbsolute(path) &&
    !/^(?:[/\\]{2}|\\\\\?\\)/.test(path), label + ' must be an ordinary absolute local path')
  const clean = resolve(path)
  for (let p = clean;; p = dirname(p)) {
    const st = await lstat(p)
    requireThat(!st.isSymbolicLink() && (p === clean ? (file ? st.isFile() : st.isDirectory()) : st.isDirectory()),
      label + ' has unsafe type or symlinked ancestor')
    if (p === clean && process.platform !== 'win32')
      requireThat((st.mode & 0o077) === 0, label + ' must be private to the owner')
    if (p === dirname(p)) break
  }
  return clean
}
async function readPrivateJson(path, label) {
  const target = await safePrivatePath(path, label, { file: true })
  const before = await lstat(target)
  requireThat(before.nlink === 1 && before.size > 1 && before.size <= 1_000_000,
    label + ' cannot be hard-linked, empty or oversized')
  const handle = await open(target, constants.O_RDONLY | (constants.O_NOFOLLOW || 0))
  try {
    const stat = await handle.stat()
    requireThat(stat.isFile() && stat.dev === before.dev && stat.ino === before.ino &&
      stat.size === before.size && stat.nlink === 1, label + ' was replaced before read')
    const bytes = await handle.readFile()
    const after = await handle.stat()
    requireThat(after.dev === stat.dev && after.ino === stat.ino && after.size === stat.size &&
      after.mtimeMs === stat.mtimeMs && after.ctimeMs === stat.ctimeMs &&
      bytes.length === stat.size, label + ' changed during read')
    let value
    try { value = JSON.parse(bytes.toString('utf8')) }
    catch { throw Error('OSA_V38_RELEASE_HOLD: malformed private ' + label + ' JSON') }
    requireThat(value && typeof value === 'object' && !Array.isArray(value),
      label + ' must be a JSON object')
    return { value, sha256: digest(bytes) }
  } finally { await handle.close() }
}

function signerOptions(provided) {
  const keys = ['registryPath', 'registrySha256', 'attestationsPath', 'evidenceDir']
  const supplied = keys.filter(k => provided[k] != null)
  requireThat(supplied.length === 0 || supplied.length === keys.length,
    'all four signer options must be supplied together, never partially')
  if (supplied.length) requireThat(SHA.test(provided.registrySha256),
    'signer registry SHA-256 must come from an independently trusted channel')
  return supplied.length === keys.length
}

/** Execute real historical/receipt/media verifiers and optionally real V30 crypto verification. */
export async function auditPrivateOwnerDossier({
  repoRoot, receiptsDir, mastersDir, captionsDir,
  registryPath, registrySha256, attestationsPath, evidenceDir,
} = {}) {
  const hasSignerInput = signerOptions({registryPath,registrySha256,attestationsPath,evidenceDir})
  // The repo is public code; private folders must not be children of it.
  requireThat(typeof repoRoot === 'string' && isAbsolute(repoRoot),
    'explicit absolute repository root required')
  const source = resolve(repoRoot)
  const [receipts, masters, captions] = await Promise.all([
    safePrivatePath(receiptsDir, 'Private receipt folder'),
    safePrivatePath(mastersDir, 'Private master folder'),
    safePrivatePath(captionsDir, 'Private caption folder'),
  ])
  const isUnder = (path, base) => path === base || path.startsWith(base + sep)
  requireThat([receipts, masters, captions].every(p => !isUnder(p, source)),
    'private movie bytes and receipts must be outside repository checkout')
  if (hasSignerInput) {
    const approvalEvidence = await safePrivatePath(evidenceDir, 'Private signed PDF folder')
    requireThat(!isUnder(approvalEvidence, source), 'signed PDFs cannot be inside public checkout')
    requireThat(!isUnder(resolve(registryPath), source) && !isUnder(resolve(attestationsPath), source),
      'private signer details cannot be inside public checkout')
  }
  const historical = await verifyHistoricalEvidence({ root: source })
  const before = await verifyPrivateReceiptDirectory({ directory: receipts })
  const media = await verifyPrivateMediaBytes({receiptsDir:receipts,mastersDir:masters,captionsDir:captions})
  let signatures = null
  if (hasSignerInput) {
    const [registry,attestations,preflight] = await Promise.all([
      readPrivateJson(registryPath, 'Trusted signer registry'),
      readPrivateJson(attestationsPath, 'External signed approvals'),
      readPrivateJson(join(receipts,'V29_OWNER_PREFLIGHT_NO_GO.json'), 'V29 preflight'),
    ])
    requireThat(registry.sha256 === registrySha256,
      'registry public keys differ from independent pinned SHA-256')
    signatures = await verifyExternalAttestations({
      preflight:preflight.value, registry:registry.value,registrySha256,
      attestations:attestations.value,evidenceDir,
    })
  }
  // A second read is cheap and detects a concurrent replacement of the receipt set.
  // This is not a filesystem snapshot guarantee; mutable files remain private only.
  const after = await verifyPrivateReceiptDirectory({ directory: receipts })
  requireThat(JSON.stringify(before) === JSON.stringify(after),
    'private receipt set changed during combined verification')
  const historyAgain = await verifyHistoricalEvidence({root:source})
  requireThat(JSON.stringify(historical) === JSON.stringify(historyAgain),
    'historical source changed during combined verification')
  return composePrivateDossier({historical,receipts:after,media,signatures})
}

const ARGUMENTS = new Map([
  ['--repo-root','repoRoot'], ['--receipts-dir','receiptsDir'],
  ['--masters-dir','mastersDir'], ['--captions-dir','captionsDir'],
  ['--registry','registryPath'], ['--registry-sha256','registrySha256'],
  ['--attestations','attestationsPath'], ['--evidence-dir','evidenceDir'],
])
export function parseArgs(args) {
  requireThat(Array.isArray(args) && args.length >= 8 && args.length % 2 === 0,
    'required: --repo-root DIR --receipts-dir DIR --masters-dir DIR --captions-dir DIR')
  const o = {}
  for (let i = 0; i < args.length; i += 2) {
    const property = ARGUMENTS.get(args[i]), value = args[i+1]
    requireThat(property && !Object.hasOwn(o,property) && typeof value === 'string' &&
      value.length > 0 && !value.startsWith('--'), 'unknown, repeated or incomplete argument')
    o[property] = value
  }
  requireThat(['repoRoot','receiptsDir','mastersDir','captionsDir'].every(k => typeof o[k] === 'string'),
    'all four required paths must be present')
  signerOptions(o)
  return o
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  let state = 1
  try {
    const options = parseArgs(process.argv.slice(2))
    const result = await auditPrivateOwnerDossier(options)
    console.log(JSON.stringify(result,null,2))
    console.log('OSA CINEMA V38: private technical audit finished. PUBLIC FILM AND PAYMENTS NO-GO.')
    state = 0
  } catch (err) {
    // Avoid printing user file paths, signer's PDF names, keys, or raw evidence.
    console.error('OSA CINEMA V38: HOLD. ' + (String(err.message).startsWith('OSA_V38_RELEASE_HOLD:')
      ? err.message : 'A source verifier rejected the private evidence or required files were missing.'))
  }
  process.exitCode = state
}
