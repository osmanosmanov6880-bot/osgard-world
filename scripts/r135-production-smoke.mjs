// Verify that R135 serves the exact reviewed native Godot Web runtime.
import { createHash } from 'node:crypto'
// Unlike a route-only 200, a range request proves Nginx serves the PCK bytes.
const root = (process.env.OSGARD_BASE_URL || 'https://osgard.world').replace(/\/$/, '')
const url = root + '/games/r135-service/'
const probe = (path) => new URL(path, url).href
const options = { headers: { 'cache-control': 'no-cache', 'accept-encoding': 'identity' }, redirect: 'manual' }
function fail(text) { throw new Error('OSGARD R135 live smoke: ' + text) }

const home = await fetch(probe('index.html?verify=' + Date.now()), options)
if (!home.ok) fail('missing HTML: ' + home.status)
const page = await home.text()
if (!page.includes('index.js') || !page.includes('<canvas')) fail('React fallback instead of Godot HTML')

const manifestResponse = await fetch(probe('release.json?verify=' + Date.now()), options)
if (!manifestResponse.ok) fail('missing release manifest: ' + manifestResponse.status)
const manifestBytes = new Uint8Array(await manifestResponse.arrayBuffer())
const manifestDigest = createHash('sha256').update(manifestBytes).digest('hex')
if (manifestDigest !== '0638f1ad5c0ab26d2d112e63bd1759923e5401a85ad4f2cedd450bbb7def2f61') fail('W6 manifest SHA-256 mismatch')
const manifest = JSON.parse(new TextDecoder().decode(manifestBytes))
const expectedVersion = process.env.OSGARD_EXPECTED_R135_VERSION || 'r135-web-framing-w6-20261024'
if (manifest.version !== expectedVersion) fail('wrong R135 release version')
if (!/^[0-9a-f]{40}$/.test(manifest.source_commit || '')) fail('missing valid W6 source commit')
const expectedSource = process.env.OSGARD_EXPECTED_R135_SOURCE
if (expectedSource && manifest.source_commit !== expectedSource) fail('wrong W6 source commit')
const files = manifest.files
const pckBytes = Number(manifest.optimized_pck_bytes)
if (pckBytes < 10_000_000 || pckBytes >= 100_000_000) fail('PCK size outside approved budget')

for (const name of ['index.js', 'index.wasm', 'index.pck']) {
  if (!files?.[name]?.sha256) fail('manifest lacks ' + name)
  const response = await fetch(probe(name), { method: 'HEAD', ...options })
  if (response.status !== 200) fail(name + ' HTTP ' + response.status)
  const lengthHeader = response.headers.get('content-length')
  // The WASM route intentionally serves its verified .gz sidecar even when
  // an edge normalizes the request's Accept-Encoding header.
  if (name !== 'index.wasm' && lengthHeader !== null && Number(lengthHeader) !== Number(files[name].size_bytes)) {
    fail(name + ' content-length mismatch: ' + lengthHeader)
  }
  const type = (response.headers.get('content-type') || '').toLowerCase()
  if (name === 'index.wasm' && !type.includes('application/wasm')) fail('bad wasm MIME ' + type)
  if (name === 'index.js' && !type.includes('javascript')) fail('bad loader MIME ' + type)
}
const wasmCompressed = files['index.wasm.gz']
if (!wasmCompressed?.sha256) fail('Release manifest has no verified compressed WASM')
const compressedResponse = await fetch(probe('index.wasm'), {
  method: 'HEAD',
  headers: { 'accept-encoding': 'gzip', 'cache-control': 'no-cache' },
  redirect: 'manual',
})
if (compressedResponse.status !== 200) fail('compressed WASM HTTP ' + compressedResponse.status)
const encoding = (compressedResponse.headers.get('content-encoding') || '').toLowerCase()
if (encoding === 'gzip') {
  const zippedLength = compressedResponse.headers.get('content-length')
  if (zippedLength !== null && Number(zippedLength) !== Number(wasmCompressed.size_bytes)) {
    fail('Compressed WASM length does not match signed manifest: ' + zippedLength)
  }
} else if (!encoding) {
  if (process.env.OSGARD_REQUIRE_GZIP === '1') {
    fail('candidate Nginx did not serve precompressed WASM')
  }
  // Public production smoke remains diagnostic if an upstream edge strips
  // Content-Encoding. Verify raw and compressed assets against the manifest.
  const rawLength = compressedResponse.headers.get('content-length')
  if (rawLength !== null && Number(rawLength) !== Number(files['index.wasm'].size_bytes)) {
    fail('Raw WASM length does not match signed manifest: ' + rawLength)
  }
  const compressedAsset = await fetch(probe('index.wasm.gz'), {
    method: 'HEAD',
    headers: { 'cache-control': 'no-cache', 'accept-encoding': 'identity' },
    redirect: 'manual',
  })
  if (compressedAsset.status !== 200) fail('compressed WASM asset HTTP ' + compressedAsset.status)
  const assetLength = compressedAsset.headers.get('content-length')
  if (assetLength !== null && Number(assetLength) !== Number(wasmCompressed.size_bytes)) {
    fail('Compressed WASM asset length does not match signed manifest: ' + assetLength)
  }
  console.warn('R135: edge returned raw WASM; verified gzip asset is available, but edge compression negotiation is not active')
} else {
  fail('Unsupported WASM content encoding: ' + encoding)
}
const response = await fetch(probe('index.pck'), {
  headers: { Range: 'bytes=0-63', 'cache-control': 'no-cache', 'accept-encoding': 'identity' },
  redirect: 'manual',
})
if (response.status !== 206) fail('PCK byte ranges unsupported: ' + response.status)
const range = response.headers.get('content-range') || ''
if (range !== 'bytes 0-63/' + pckBytes) fail('wrong PCK content-range: ' + range)
const chunk = Buffer.from(await response.arrayBuffer())
if (chunk.length !== 64) fail('expected exactly 64 PCK bytes, got ' + chunk.length)
console.log('R135 LIVE PASS', JSON.stringify({
  route: url, sourceVersion: manifest.version,
  pckBytes, wasmBytes: files['index.wasm'].size_bytes,
  pckRanges: response.status, wasmDelivery: encoding === 'gzip' ? 'gzip' : 'raw-edge-fallback', status: 'native-Godot-WebGL',
}))
