// Verify that R135 serves the real optimized Godot Web binary from osgard.world.
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
const manifest = await manifestResponse.json()
if (manifest.version !== 'r135-web-optimized-20261024') fail('wrong R135 release version')
const files = manifest.files
const pckBytes = Number(manifest.optimized_pck_bytes)
if (pckBytes < 10_000_000 || pckBytes >= 100_000_000) fail('PCK size outside approved budget')

for (const name of ['index.js', 'index.wasm', 'index.pck']) {
  if (!files?.[name]?.sha256) fail('manifest lacks ' + name)
  const response = await fetch(probe(name), { method: 'HEAD', ...options })
  if (response.status !== 200) fail(name + ' HTTP ' + response.status)
  const lengthHeader = response.headers.get('content-length')
  if (lengthHeader !== null && Number(lengthHeader) !== Number(files[name].size_bytes)) {
    fail(name + ' content-length mismatch: ' + lengthHeader)
  }
  const type = (response.headers.get('content-type') || '').toLowerCase()
  if (name === 'index.wasm' && !type.includes('application/wasm')) fail('bad wasm MIME ' + type)
  if (name === 'index.js' && !type.includes('javascript')) fail('bad loader MIME ' + type)
}
const response = await fetch(probe('index.pck'), {
  headers: { Range: 'bytes=0-63', 'cache-control': 'no-cache', 'accept-encoding': 'identity' },
  redirect: 'manual',
})
if (response.status !== 206) fail('PCK byte ranges unsupported: ' + response.status)
const range = response.headers.get('content-range') || ''
if (!range.startsWith('bytes 0-63/')) fail('wrong PCK content-range: ' + range)
const chunk = Buffer.from(await response.arrayBuffer())
if (chunk.length !== 64) fail('expected exactly 64 PCK bytes, got ' + chunk.length)
console.log('R135 LIVE PASS', JSON.stringify({
  route: url, sourceVersion: manifest.version,
  pckBytes, wasmBytes: files['index.wasm'].size_bytes,
  pckRanges: response.status, status: 'native-Godot-WebGL',
}))
