import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { createHash } from 'node:crypto'

/**
 * Independent, read-only smoke gate for the exact public ZION-030 files.
 * Runs immediately after SSH activation, even if a different game fails later.
 */
const origin = process.env.OSGARD_BASE_URL || 'https://osgard.world'
const root = 'public/games/zion-9/queue/ZION-030/'
const assets = ['index.html', 'premium.js', 'premium.css', 'athens-skyline.svg', 'open-city-rules.js', 'open-city.js', 'open-city.css', 'open-city-details.js', 'open-city-cinematic.js', 'open-city-landmarks.js', 'open-city-streets.js', 'open-city-focus.css', 'open-city-focus.js', 'open-city-v34.css', 'open-city-pbr34.js', 'open-city-postfx34.js', 'open-city-perf34.js', 'open-city-cooling34.js', 'open-city-surfaces35.js', 'open-city-civic36.js', 'open-city-photoreal37.js', 'open-city-nature38.js', 'open-city-optics39.js', 'open-city-store40.js', 'open-city-store40.css']
const checksum = b => createHash('sha256').update(b).digest('hex')
const evidence = []
for(const asset of assets){
  const relative = '/games/zion-9/queue/ZION-030/' + asset
  const url = new URL(relative, origin)
  url.searchParams.set('release_check', process.env.GITHUB_SHA?.slice(0, 12) || Date.now().toString())
  const response = await fetch(url, { headers: { 'Cache-Control': 'no-cache', Pragma: 'no-cache' }, signal: AbortSignal.timeout(20000) })
  const expected = await readFile(root + asset)
  const published = Buffer.from(await response.arrayBuffer())
  const result = { path: relative, status: response.status, bytes: published.length, expectedSha256: checksum(expected), publishedSha256: checksum(published), matches: response.status === 200 && expected.equals(published) }
  evidence.push(result)
  console.log(JSON.stringify(result))
}
assert.ok(evidence.every(x => x.matches), 'ZION-030 public assets do not match the activated release; see per-file checksums above')
console.log(`PASS exact ZION-030 deployment: ${assets.length} assets byte-identical on public HTTPS`)
