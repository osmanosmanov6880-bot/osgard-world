import assert from 'node:assert/strict'
import { gzipSync, gunzipSync } from 'node:zlib'
import { readFile, writeFile, stat } from 'node:fs/promises'
import { join, resolve } from 'node:path'

const root = resolve(process.argv[2] || 'dist')
const targets = [
  'games/null-shift-godot/index.wasm',
  'games/omega-3d-preview/index.wasm',
  'games/remix/arena-v2/nebula-3d/index.wasm',
]
const assets = []

for (const relativePath of targets) {
  const wasmPath = join(root, relativePath)
  const info = await stat(wasmPath).catch(() => null)
  if (!info?.isFile()) throw new Error('Godot WebAssembly asset is missing: ' + wasmPath)

  const original = await readFile(wasmPath)
  assert.ok(original.length >= 8, 'Godot WASM payload is unexpectedly small: ' + relativePath)
  assert.equal(original.subarray(0, 4).toString('hex'), '0061736d',
    'Expected an uncompressed WebAssembly binary before packaging: ' + relativePath)

  const compressed = gzipSync(original, { level: 9, mtime: 0 })
  const restored = gunzipSync(compressed)
  assert.equal(restored.length, original.length, 'Compressed WASM round-trip length mismatch: ' + relativePath)
  assert.ok(restored.equals(original), 'Compressed WASM round-trip bytes mismatch: ' + relativePath)
  assert.ok(compressed.length < 25 * 1024 * 1024,
    'Compressed WASM still exceeds the Cloudflare Pages 25 MiB per-file limit: ' + relativePath + ' (' + compressed.length + ')')

  await writeFile(wasmPath, compressed)
  assets.push({
    path: relativePath,
    originalBytes: original.length,
    compressedBytes: compressed.length,
    ratio: Number((compressed.length / original.length).toFixed(3)),
    roundTripVerified: true,
    requiresContentEncoding: 'gzip',
  })
}

console.log(JSON.stringify({
  status: 'compressed-for-cloudflare-pages',
  assets,
}, null, 2))
