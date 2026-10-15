import assert from 'node:assert/strict'
import { readFile, writeFile } from 'node:fs/promises'
import { gzipSync, gunzipSync } from 'node:zlib'
import { resolve } from 'node:path'

const DEFAULT_SOURCE = 'dist/brand/osa-transition.js'
function gzip(source) {
  return gzipSync(source, { level: 9, mtime: 0 })
}
function validate(source, compressed, label) {
  assert.ok(source.length > 0, label + ': source must not be empty')
  assert.ok(compressed.length > 0, label + ': compressed output must not be empty')
  assert.ok(compressed.length < source.length, label + ': gzip must reduce the source size')
  assert.deepEqual(gunzipSync(compressed), source, label + ': gzip round trip must preserve the exact source bytes')
}
async function main() {
  if (process.argv.includes('--self-test')) {
    const fixture = Buffer.from(('(()=>{const message="OSGARD shared brand transition";document.documentElement.dataset.brand=message})();\n').repeat(80), 'utf8')
    const compressed = gzip(fixture)
    validate(fixture, compressed, 'self-test fixture')
    const mismatch = Buffer.from('not the source', 'utf8')
    assert.throws(() => assert.deepEqual(gunzipSync(compressed), mismatch), 'different source bytes must be detected')
    console.log('BRAND_TRANSITION_GZIP_SELF_TEST_PASS: gzip reduction and exact byte-for-byte round trip verified.')
    return
  }

  const sourcePath = resolve(process.argv.includes('--check-dist')
    ? DEFAULT_SOURCE
    : (process.argv[2] || DEFAULT_SOURCE))
  const targetPath = sourcePath + '.gz'
  const source = await readFile(sourcePath)
  const compressed = process.argv.includes('--check-dist')
    ? await readFile(targetPath)
    : gzip(source)
  validate(source, compressed, sourcePath)
  if (!process.argv.includes('--check-dist')) await writeFile(targetPath, compressed)
  const report = {
    status: 'ready',
    source: sourcePath,
    compressed: targetPath,
    sourceBytes: source.length,
    gzipBytes: compressed.length,
    savedBytes: source.length - compressed.length,
    savingsPercent: Number(((1 - compressed.length / source.length) * 100).toFixed(1)),
    sha256Uncompressed: (await import('node:crypto')).createHash('sha256').update(source).digest('hex'),
  }
  console.log(JSON.stringify(report, null, 2))
}
await main()
