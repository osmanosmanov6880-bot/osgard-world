import assert from 'node:assert/strict'
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

const compressed = gzipSync(original, { level: 9, mtime: 0 })
const restored = gunzipSync(compressed)
assert.equal(restored.length, original.length, 'Compressed WASM round-trip length mismatch')
assert.ok(restored.equals(original), 'Compressed WASM round-trip bytes mismatch')
assert.ok(compressed.length < 25 * 1024 * 1024,
  'Compressed WASM still exceeds the Cloudflare Pages 25 MiB per-file limit: ' + compressed.length)

await writeFile(wasmPath, compressed)
console.log(JSON.stringify({
  status: 'compressed-for-cloudflare-pages',
  path: 'games/null-shift-godot/index.wasm',
  originalBytes: original.length,
  compressedBytes: compressed.length,
  ratio: Number((compressed.length / original.length).toFixed(3)),
  roundTripVerified: true,
  requiresContentEncoding: 'gzip',
}, null, 2))
