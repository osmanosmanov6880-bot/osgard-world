import assert from 'node:assert/strict'
import { createHash, randomUUID } from 'node:crypto'
import { readFileSync } from 'node:fs'

const base = new URL(process.env.OSGARD_BASE_URL || 'https://osgard.world')
assert.equal(base.protocol, 'https:', 'Production acceptance requires HTTPS')
assert.equal(base.pathname, '/', 'Production URL must target the site root')

const manifestPath = 'public/osa-cinema/reference/manifest.json'
const localManifestText = readFileSync(manifestPath, 'utf8')
const manifest = JSON.parse(localManifestText)
const approved = ['library.webp', 'understand.webp', 'verify.webp', 'decide.webp']
assert.deepEqual(manifest.files.map(file => file.name).sort(), approved.slice().sort(), 'Exactly four approved images are required')

const results = { origin: base.origin, routes: [], images: [], manifest: null }
async function getSameOrigin(path) {
  const url = new URL(path, base)
  url.searchParams.set('osa_v13_integrity', randomUUID())
  const response = await fetch(url, {
    redirect: 'follow',
    signal: AbortSignal.timeout(20000),
    headers: { 'user-agent': 'OSA-Cinema-V13-LiveAcceptance/1.0', 'cache-control': 'no-cache', pragma: 'no-cache' }
  })
  assert.equal(new URL(response.url).origin, base.origin, 'Unexpected cross-origin redirect: ' + path)
  assert.equal(response.status, 200, 'Unexpected HTTP status for ' + path)
  return { response, bytes: Buffer.from(await response.arrayBuffer()) }
}
for (const locale of ['ru', 'en']) {
  const path = '/osa-cinema?lang=' + locale
  const { response, bytes } = await getSameOrigin(path)
  assert.match(response.headers.get('content-type') || '', /text\/html/i, 'Not an HTML document: ' + path)
  const html = bytes.toString('utf8')
  assert.ok(html.includes('id="root"'), 'Missing React root: ' + path)
  assert.ok(html.includes('/assets/'), 'Missing production bundle references: ' + path)
  results.routes.push({ locale, status: response.status, htmlBytes: bytes.length })
}
const liveManifest = await getSameOrigin('/osa-cinema/reference/manifest.json')
assert.match(liveManifest.response.headers.get('content-type') || '', /json/i, 'Published manifest has wrong MIME type')
assert.equal(liveManifest.bytes.toString('utf8'), localManifestText, 'Live image manifest differs from the checked-out release')
results.manifest = { status: liveManifest.response.status, bytes: liveManifest.bytes.length }

for (const file of manifest.files) {
  const path = '/osa-cinema/reference/' + file.name
  const { response, bytes } = await getSameOrigin(path)
  assert.match(response.headers.get('content-type') || '', /image\/webp/i, 'Incorrect WebP MIME: ' + path)
  assert.equal(bytes.toString('ascii', 0, 4), 'RIFF', 'Bad RIFF signature: ' + path)
  assert.equal(bytes.toString('ascii', 8, 12), 'WEBP', 'Bad WebP signature: ' + path)
  assert.equal(bytes.length, file.size, 'Published image byte length differs: ' + path)
  const hash = createHash('sha256').update(bytes).digest('hex')
  assert.equal(hash, file.sha256, 'Published image SHA-256 mismatch: ' + path)
  results.images.push({ name: file.name, status: response.status, bytes: bytes.length, sha256: hash })
}
console.log('OSA_CINEMA_V13_LIVE_PASS ' + JSON.stringify(results))
