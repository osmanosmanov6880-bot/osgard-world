import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { readFile, writeFile } from 'node:fs/promises'
import { gzipSync, gunzipSync } from 'node:zlib'
import { resolve } from 'node:path'

const BRAND_ASSETS = [
  'brand/osa-transition.js',
  'brand/osa5-portals.css',
]
function gzip(source) {
  return gzipSync(source, { level: 9, mtime: 0 })
}
function validate(source, compressed, label) {
  assert.ok(source.length > 0, label + ': source must not be empty')
  assert.ok(compressed.length > 0, label + ': compressed output must not be empty')
  assert.ok(compressed.length < source.length, label + ': gzip must reduce the source size')
  assert.deepEqual(gunzipSync(compressed), source, label + ': gzip round trip must preserve the exact source bytes')
  return {
    sourceBytes: source.length,
    gzipBytes: compressed.length,
    savedBytes: source.length - compressed.length,
    savingsPercent: Number(((1 - compressed.length / source.length) * 100).toFixed(1)),
    sha256Uncompressed: createHash('sha256').update(source).digest('hex'),
  }
}
function runSelfTest() {
  const fixtures = [
    { path: 'osa-transition.js', source: Buffer.from(('(()=>{const message="OSGARD shared brand transition";document.documentElement.dataset.brand=message})();\n').repeat(80), 'utf8') },
    { path: 'osa5-portals.css', source: Buffer.from(('.osa-brand-transition{opacity:1;transform:translateZ(0);contain:paint}\n').repeat(80), 'utf8') },
  ]
  for (const fixture of fixtures) validate(fixture.source, gzip(fixture.source), fixture.path)
  const compressed = gzip(fixtures[0].source)
  assert.throws(() => assert.deepEqual(gunzipSync(compressed), Buffer.from('not the original source')), 'different source bytes must be detected')
  console.log('BRAND_ASSET_GZIP_SELF_TEST_PASS: JavaScript/CSS gzip reduction and exact byte-for-byte round trip verified.')
}
async function main() {
  const checkDist = process.argv.includes('--check-dist')
  if (process.argv.includes('--self-test')) {
    runSelfTest()
    return
  }
  const results = []
  for (const asset of BRAND_ASSETS) {
    const sourcePath = resolve('dist', asset)
    const targetPath = sourcePath + '.gz'
    const source = await readFile(sourcePath)
    const compressed = checkDist ? await readFile(targetPath) : gzip(source)
    const metrics = validate(source, compressed, sourcePath)
    if (!checkDist) await writeFile(targetPath, compressed)
    results.push({ status: 'ready', source: sourcePath, compressed: targetPath, ...metrics })
  }
  console.log(JSON.stringify({ status: 'ready', assets: results }, null, 2))
}
await main()
