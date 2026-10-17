import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { gzipSync, gunzipSync } from 'node:zlib'
import { readFile, writeFile, stat } from 'node:fs/promises'
import { join, resolve } from 'node:path'

const root = resolve(process.argv[2] || 'dist')
const wasmPath = join(root, 'games/null-shift-godot/index.wasm')
const info = await stat(wasmPath).catch(() => null)
if (!info?.isFile()) throw new Error('Godot WebAssembly asset is missing: ' + wasmPath)

const original = await readFile(wasmPath)
assert.ok(original.length >= 8, 'Godot WASM payload is unexpectedly small')
assert.equal(original.subarray(0, 4).toString('hex'), '0061736d', 'Expected an uncompressed WebAssembly binary before packaging')

const buildInfoPath = join(root, 'games/null-shift-godot/build-info.json')
const buildInfo = JSON.parse(await readFile(buildInfoPath, 'utf8'))
const wasmRecord = buildInfo.files?.find(file => file.path === 'index.wasm')
const originalSha256 = createHash('sha256').update(original).digest('hex')
assert.equal(buildInfo.schemaVersion, 1, 'The Godot export must have validated build metadata before packaging')
assert.ok(!buildInfo.packaging, 'The Godot export has already been packaged')
assert.equal(wasmRecord?.bytes, original.length, 'Godot WASM length differs from the source-bound export')
assert.equal(wasmRecord?.sha256, originalSha256, 'Godot WASM hash differs from the source-bound export')

const compressed = gzipSync(original, { level: 9, mtime: 0 })
const restored = gunzipSync(compressed)
assert.equal(restored.length, original.length, 'Compressed WASM round-trip length mismatch')
assert.ok(restored.equals(original), 'Compressed WASM round-trip bytes mismatch')
assert.ok(compressed.length < 25 * 1024 * 1024,
  'Compressed WASM still exceeds the Cloudflare Pages 25 MiB per-file limit: ' + compressed.length)

await writeFile(wasmPath, compressed)
wasmRecord.bytes = compressed.length
wasmRecord.sha256 = createHash('sha256').update(compressed).digest('hex')
buildInfo.packaging = {
  target: 'cloudflare-pages',
  wasm: { path: 'index.wasm', contentEncoding: 'gzip', uncompressedBytes: original.length, uncompressedSha256: originalSha256 },
}
await writeFile(buildInfoPath, JSON.stringify(buildInfo, null, 2) + '\n')
console.log(JSON.stringify({
  status: 'compressed-for-cloudflare-pages',
  path: 'games/null-shift-godot/index.wasm',
  originalBytes: original.length,
  compressedBytes: compressed.length,
  ratio: Number((compressed.length / original.length).toFixed(3)),
  roundTripVerified: true,
  requiresContentEncoding: 'gzip',
  uncompressedSha256: originalSha256,
  packagedSha256: wasmRecord.sha256,
}, null, 2))
