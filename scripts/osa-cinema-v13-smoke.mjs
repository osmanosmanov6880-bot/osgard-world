import assert from 'node:assert/strict'
import { readFileSync, existsSync } from 'node:fs'
import { createHash } from 'node:crypto'

const component = readFileSync('src/OSACinema.tsx', 'utf8')
const css = readFileSync('src/osaCinemaV13.css', 'utf8')
const media = readFileSync('src/osaMediaCatalog.ts', 'utf8')
const progress = readFileSync('src/osaProgress.ts', 'utf8')
const router = readFileSync('src/main.tsx', 'utf8')

const requiredSections = [
  '.cinema-topbar',
  '.cinema-shell',
  '.cinema-scene',
  '.scene-art',
  '.scene-content h1',
  '.cinema-choice-grid',
  '.cinema-progress',
  '.cinema-aside',
  '.osa-media-player',
  '.cinema-notes',
  '.cinema-completion',
  '.cinema-footer',
]
for (const selector of requiredSections) {
  assert.ok(css.includes(selector), `V13 missed section: ${selector}`)
}
assert.ok(css.includes('data-cinema-design="v13"'), 'V13 styling must be scoped')
assert.ok(component.includes("import './osaCinemaV13.css'"), 'Missing V13 stylesheet import')
assert.ok(component.includes("data-cinema-design='v13'"), 'V13 theme not enabled')
assert.match(css, /@media\s*\(max-width:\s*390px\)/, '390px mobile layout absent')
assert.match(css, /prefers-reduced-motion:\s*reduce/, 'Reduced motion missing')
assert.ok(!/url\(['"]?http:\/\//.test(css), 'Non-HTTPS remote media is not permitted')
assert.ok(component.includes('getOSALearningProgress()'), 'Learning progress loading removed')
assert.ok(component.includes('saveOSACinemaProgress('), 'Progress saving removed')
assert.ok(component.includes('getOSACinemaMedia(index,locale,'), 'Cinema media wiring removed')
assert.ok(component.includes('changeLocale'), 'Localized navigation was removed')
assert.ok(component.includes("url.searchParams.set('lang',next)"), 'Language URL state is not synchronized')
assert.ok(component.includes('target.closest('), 'Media/interactive keyboard focus guard is missing')
assert.ok(media.includes('isPermanentMediaUrl'), 'Media permanence guard removed')
assert.ok(progress.includes('OSA_PROGRESS_STORAGE_KEY'), 'Existing progress storage contract missing')
assert.ok(router.includes("path === '/osa-cinema'"), 'Cinema route removed')
const resources = [...new Set(css.split('url("').slice(1).map(chunk => chunk.split('")')[0]))]
const manifest = JSON.parse(readFileSync('public/osa-cinema/reference/manifest.json', 'utf8'))
const expectedAssets = ['library.webp', 'understand.webp', 'verify.webp', 'decide.webp']
assert.equal(manifest.files.length, expectedAssets.length, 'Approved image manifest must list four files')
assert.equal(resources.length, expectedAssets.length, 'V13 backgrounds may only load four approved images')
for (const asset of expectedAssets) {
  const url = '/osa-cinema/reference/' + asset
  assert.ok(resources.includes(url), `Missing same-origin reference: ${asset}`)
  const filePath = 'public' + url
  assert.ok(existsSync(filePath), `Asset not archived in repository: ${filePath}`)
  const bytes = readFileSync(filePath)
  assert.ok(bytes.length >= 10_000 && bytes.length <= 8_000_000, `Invalid asset size: ${asset}`)
  assert.equal(bytes.toString('ascii', 0, 4), 'RIFF', `RIFF magic mismatch: ${asset}`)
  assert.equal(bytes.toString('ascii', 8, 12), 'WEBP', `WebP magic mismatch: ${asset}`)
  const expected = manifest.files.find(item => item.name === asset)
  assert.ok(expected, `No provenance entry: ${asset}`)
  assert.equal(bytes.length, expected.size, `Size drift: ${asset}`)
  assert.equal(createHash('sha256').update(bytes).digest('hex'), expected.sha256, `SHA-256 drift: ${asset}`)
}
assert.ok(!css.includes('https://osa-cinema-beyond-the-model.'), 'V13 still relies on an external site for backgrounds')
console.log('OSA_CINEMA_V13_SMOKE_PASS: accessible navigation, media/progress, scoped responsive UI and 4 SHA-256-attested same-origin WebP assets')
