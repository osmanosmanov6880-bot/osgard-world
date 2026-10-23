// Check artwork resolved for every published game world, not just hero covers.
// This catches blank cards before they reach the browser and is cheap enough for CI.
import assert from 'node:assert/strict'
import { stat, readFile } from 'node:fs/promises'
import { build } from 'esbuild'
import { expectedPlayCatalogIds } from './play-catalog-test-contract.mjs'

const built = await build({ entryPoints: ['src/playCinematicData.ts'], bundle: true, format: 'esm', platform: 'node', write: false })
const encoded = Buffer.from(built.outputFiles[0].text).toString('base64')
const { gameArtwork } = await import('data:text/javascript;base64,' + encoded)
const index = await readFile('src/playCatalogIndex.ts', 'utf8')
const idsMatch = index.match(/export const PLAY_GAME_IDS:[^=]*=\s*\[([\s\S]*?)\]/)
assert.ok(idsMatch, 'The tiny PLAY game-id index is missing')
const indexed = [...idsMatch[1].matchAll(/'([^']+)'/g)].map(m => m[1])
assert.deepEqual([...indexed].sort(), [...expectedPlayCatalogIds].sort(), 'Hero count/index and full catalogue must list the same released games')
const expectedOriginals = {
  'empire-omega': '/brand/world-empire-omega.svg',
  'nebula-3d': '/brand/world-nebula.svg',
  'r136-precision': '/brand/world-r136.svg',
}
let checked = 0
for (const id of expectedPlayCatalogIds) {
  const art = gameArtwork({ id })
  assert.equal(typeof art.src, 'string', id + ': missing image path')
  assert.ok(art.src.startsWith('/brand/'), id + ': unreviewed/external artwork')
  if (id in expectedOriginals) {
    assert.equal(art.src, expectedOriginals[id], id + ': must use its own real SVG cover')
    assert.equal(art.srcSet, undefined, id + ': SVG cover must not advertise missing WebP variants')
  } else {
    assert.equal(art.src, '/brand/play/' + id + '.webp', id + ': dedicated raster cover changed unexpectedly')
    assert.equal(art.srcSet, '/brand/play/' + id + '-640.webp 640w, /brand/play/' + id + '.webp 1536w', id + ': missing responsive cover declarations')
  }
  const sources = [art.src, ...(art.srcSet ? [...art.srcSet.matchAll(/(\/\S+)\s+\d+w/g)].map(x => x[1]) : [])]
  for (const source of sources) {
    const fsPath = 'public' + source
    const file = await stat(fsPath).catch(() => null)
    assert.ok(file?.isFile() && file.size > 300, id + ': missing or empty cover ' + fsPath)
    checked++
  }
}
console.log(JSON.stringify({ status: 'PASS', gameWorlds: expectedPlayCatalogIds.length, verifiedArtworkFiles: checked, exactGameArtwork: Object.keys(expectedOriginals) }, null, 2))
