import assert from 'node:assert/strict'
import { readFile, access } from 'node:fs/promises'
import { createHash } from 'node:crypto'
import { gunzipSync } from 'node:zlib'

// A successful HTML wrapper does not prove that Unity can obtain its runtime.
// Exercise exactly the URLs configured in the actual player, without a browser.
const origin = process.env.OSGARD_BASE_URL
assert.ok(origin, 'Set OSGARD_BASE_URL to the candidate server or production origin')
const root = process.argv[2] || 'dist'
const player = await readFile(root + '/games/remix/player/index.html', 'utf8')
const entries = [...player.matchAll(/\b(dataUrl|frameworkUrl|codeUrl):\s*buildUrl\s*\+\s*["']([^"']+)["']/g)]
assert.equal(entries.length, 3, 'Read all three configured Unity runtime assets')
const digest = bytes => createHash('sha256').update(bytes).digest('hex')
const checks = []
for (const [, kind, suffix] of entries) {
  const path = '/games/remix/player/Build' + suffix
  const local = root + path
  let compressed = false
  try { await access(local) } catch { compressed = true }
  const source = await readFile(compressed ? local + '.gz' : local)
  const expected = compressed ? gunzipSync(source) : source
  const url = new URL(path, origin)
  url.searchParams.set('delivery_probe', process.env.GITHUB_SHA?.slice(0, 12) || Date.now().toString())
  const response = await fetch(url, { headers: { 'Accept-Encoding': 'gzip', 'Cache-Control': 'no-cache' }, signal: AbortSignal.timeout(45000) })
  assert.equal(response.status, 200, path + ': runtime asset must load')
  const type = response.headers.get('content-type') || ''
  assert.match(type, kind === 'codeUrl' ? /application\/wasm/ : kind === 'frameworkUrl' ? /(?:application|text)\/javascript/ : /application\/octet-stream/, path + ': MIME type')
  if (compressed) assert.equal(response.headers.get('content-encoding'), 'gzip', path + ': gzip export must declare its encoding')
  const actual = Buffer.from(await response.arrayBuffer())
  assert.equal(digest(actual), digest(expected), path + ': decoded bytes must equal this release')
  if (kind === 'codeUrl') assert.deepEqual([...actual.subarray(0, 4)], [0, 97, 115, 109], 'Valid WebAssembly signature')
  checks.push({ path, status: response.status, decodedBytes: actual.length })
}
for (const path of ['/api/osgard-missing-delivery-probe', '/osgard-missing-delivery-probe.wasm']) {
  const response = await fetch(new URL(path, origin), { signal: AbortSignal.timeout(15000) })
  assert.equal(response.status, 404, path + ': missing resources must not return the React shell')
  if (path.startsWith('/api/')) {
    assert.match(response.headers.get('content-type') || '', /application\/json/)
    assert.equal((await response.json()).error, 'not_found')
  }
  checks.push({ path, status: response.status })
}
console.log(JSON.stringify({ status: 'PASS', verification: 'Actual Unity request URLs, MIME, gzip, decoded hashes and missing-resource status; gameplay interaction is separate', checks }, null, 2))
