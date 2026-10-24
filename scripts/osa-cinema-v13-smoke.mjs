import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

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
const resources = [...css.matchAll(/url\("([^"]+)"/g)].map(match => match[1])
const expectedAssets = ['library.webp', 'understand.webp', 'verify.webp', 'decide.webp']
for (const asset of expectedAssets) {
  assert.ok(resources.some(resource => resource.endsWith('/media/reference/' + asset)), `Missing approved image ${asset}`)
}
for (const resource of resources) {
  const url = new URL(resource)
  assert.equal(url.protocol, 'https:')
  assert.equal(url.hostname, 'osa-cinema-beyond-the-model.osman-absolu-5357.chatgpt.site')
}
console.log('OSA_CINEMA_V13_SMOKE_PASS: scoped art direction, 390px layout, reduced motion, bilingual URLs, media/progress contracts and image references')
