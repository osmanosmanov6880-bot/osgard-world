/**
 * OSA CINEMA V40: isolated one-shot worker for REAL private V38 evidence audit.
 * Reads exactly one bounded JSON configuration from stdin. Never accepts secrets
 * or file locations as command-line arguments. Prints only V38 safe result JSON.
 * Exit failure is deliberately generic; no media paths, keys or report bytes in logs.
 */
import { auditPrivateOwnerDossier, parseArgs } from './osa-cinema-v38-owner-release-dossier.mjs'
import { resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const MAX_CONFIG = 8192
const KEYS = new Map([
  ['repoRoot','--repo-root'],['receiptsDir','--receipts-dir'],
  ['mastersDir','--masters-dir'],['captionsDir','--captions-dir'],
  ['registryPath','--registry'],['registrySha256','--registry-sha256'],
  ['attestationsPath','--attestations'],['evidenceDir','--evidence-dir'],
])
const reject = () => { throw Error('untrusted isolated audit input') }

export function validateWorkerConfiguration(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) reject()
  const items = Object.entries(raw)
  if (items.length < 4 || items.length > KEYS.size) reject()
  const args=[]
  for (const [key,val] of items) {
    if (!KEYS.has(key) || typeof val !== 'string' || val.length === 0 || val.length > 2048) reject()
    args.push(KEYS.get(key), val)
  }
  // The established V38 parser checks all required paths and signer option grouping.
  return parseArgs(args)
}

async function receiveConfiguration() {
  let size=0, chunks=[]
  for await (const block of process.stdin) {
    size+=block.length
    if (size>MAX_CONFIG) reject()
    chunks.push(block)
  }
  if(size===0)reject()
  let value
  try {value=JSON.parse(Buffer.concat(chunks).toString('utf8'))}catch{reject()}
  return validateWorkerConfiguration(value)
}

if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  try {
    // A failed credential-isolation contract MUST abort before reading private data.
    if (process.env.OSA_CINEMA_OWNER_PASSWORD || process.env.NODE_OPTIONS) reject()
    if (process.argv.length!==2) reject()
    const opts=await receiveConfiguration()
    const result=await auditPrivateOwnerDossier(opts)
    if (result.releaseDecision!=='NO_GO' || result.publicationAuthorized!==false ||
        result.paidCheckoutEnabled!==false || result.rightsCleared!==false) reject()
    const output=JSON.stringify(result)
    if (Buffer.byteLength(output,'utf8')>16384) reject()
    process.stdout.write(output+'\n')
  } catch {
    console.error('OSA CINEMA V40: isolated private audit HOLD; no media published')
    process.exitCode=1
  }
}
