import fs from 'node:fs'
import crypto from 'node:crypto'

const argv = process.argv.slice(2)
const sourcePath = argv[0]
const flags = {}
const allowedFlags = new Set(['--expect-sha256', '--expect-bytes', '--expect-lines'])
for (let index = 1; index < argv.length; index += 2) {
  if (!allowedFlags.has(argv[index]) || index + 1 >= argv.length || flags[argv[index]] !== undefined) {
    console.error('Usage: node scripts/brief-coverage-audit.mjs <brief-file> [--expect-sha256 HEX] [--expect-bytes NUMBER] [--expect-lines NUMBER]')
    process.exit(2)
  }
  flags[argv[index]] = argv[index + 1]
}
if (!sourcePath) {
  console.error('Usage: node scripts/brief-coverage-audit.mjs <brief-file> [--expect-sha256 HEX] [--expect-bytes NUMBER] [--expect-lines NUMBER]')
  process.exit(2)
}
if (flags['--expect-sha256'] && !/^[a-f0-9]{64}$/i.test(flags['--expect-sha256'])) {
  console.error('Expected SHA-256 must be exactly 64 hexadecimal characters.')
  process.exit(2)
}
for (const name of ['--expect-bytes', '--expect-lines']) {
  if (flags[name] !== undefined && (!/^(0|[1-9][0-9]*)$/.test(flags[name]) || !Number.isSafeInteger(Number(flags[name])))) {
    console.error('Expected count must be a nonnegative safe integer.')
    process.exit(2)
  }
}

let source
try { source = fs.readFileSync(sourcePath) }
catch (error) {
  console.error('Brief file unavailable: ' + error.code)
  process.exit(2)
}
const sourceText = source.toString('utf8')
const lines = sourceText.split(/\r?\n/)
const sections = [...sourceText.matchAll(/(?:^|:\s)#\s+(\d+)\./gm)].map((match) => Number(match[1]))
const sectionCounts = new Map()
for (const number of sections) sectionCounts.set(number, (sectionCounts.get(number) || 0) + 1)
const uniqueSections = [...sectionCounts.keys()].sort((a, b) => a - b)
const expected = Array.from({ length: 255 }, (_, index) => index + 1)
const missing = expected.filter((number) => !sectionCounts.has(number))
const extra = uniqueSections.filter((number) => number < 0 || number > 255)
const duplicate = uniqueSections.filter((number) => sectionCounts.get(number) > 1)
const sha256 = crypto.createHash('sha256').update(source).digest('hex')
const fingerprintMatch = {
  sha256: flags['--expect-sha256'] === undefined ? null : sha256 === flags['--expect-sha256'].toLowerCase(),
  bytes: flags['--expect-bytes'] === undefined ? null : source.byteLength === Number(flags['--expect-bytes']),
  lines: flags['--expect-lines'] === undefined ? null : lines.length === Number(flags['--expect-lines']),
}
const sectionCoverageValid = missing.length === 0 && extra.length === 0 && duplicate.length === 0
const provenanceValid = Object.values(fingerprintMatch).every((value) => value !== false)
const result = {
  file: sourcePath,
  lines: lines.length,
  bytes: source.byteLength,
  sha256,
  headingCount: sections.length,
  numberedSections: uniqueSections.filter((number) => number >= 1 && number <= 255).length,
  preambleSections: uniqueSections.filter((number) => number === 0),
  missing,
  extra,
  duplicate,
  sectionCoverageValid,
  fingerprintMatch,
  provenanceVerified: flags['--expect-sha256'] !== undefined && fingerprintMatch.sha256 && provenanceValid,
  status: sectionCoverageValid && provenanceValid ? 'ready' : 'not-ready',
}
console.log(JSON.stringify(result, null, 2))
if (result.status !== 'ready') process.exit(1)
