import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'

const read = path => {
  assert.ok(existsSync(path), 'Missing OSA case release file: ' + path)
  return readFileSync(path, 'utf8')
}

const page = read('public/development/osa-intelligence/index.html')
const og = read('public/development/osa-intelligence/og.svg')
const mediaLibrary = read('public/osa-library/index.html')
const mediaManifest = JSON.parse(read('public/osa-library/media-manifest.json'))
const canonicalDoc = read('docs/OSA_CANONICAL_SOURCE_OF_TRUTH.md')
const landing = read('public/development/index.html')
const sitemap = read('public/sitemap.xml')
const routes = read('scripts/production-route-matrix.mjs')
const pkg = JSON.parse(read('package.json'))
const deploy = read('.github/workflows/deploy-frontend.yml')
const frontend = read('.github/workflows/frontend-check.yml')

for (const marker of [
  '<title>OSA Global Intelligence — кейс OSGARD Development</title>',
  '<link rel="canonical" href="https://osgard.world/development/osa-intelligence/">',
  'https://osgard.world/development/osa-intelligence/og.svg',
  'id="osa-case-schema"',
  'id="learning-path"',
  'ИИ меняет правила игры',
  'Власть знаний',
  'Человек в контуре',
  'id="video-status"',
  'Видеолекции: файлы ещё не подключены',
  '19 записей видео и 9 записей аудио',
  'data-case-status="interactive-demo"',
  'href="/"',
  'href="/osa-cinema"',
  'osa-global-intelligence',
  'osa-global-intelligence-2',
  'хранится локально в браузере',
  'не заявляет о готовом полнометражном видео',
  'prefers-reduced-motion:reduce'
]) assert.ok(page.includes(marker), 'OSA case contract marker missing: ' + marker)

assert.ok(mediaLibrary.includes('<title>OSA Media Library — единая карта курса и медиа</title>'), 'OSA media library title is missing.')
assert.ok(mediaLibrary.includes('data-media-count="31"') && mediaLibrary.includes('19') && mediaLibrary.includes('9') && mediaLibrary.includes('3'), 'OSA media library counts are missing.')
assert.ok((mediaLibrary.match(/<tr data-kind=/g) || []).length === 31, 'OSA media library must list all 31 declared media assets.')
assert.ok(mediaLibrary.includes('data-release-gate="blocked"') && mediaLibrary.includes('28 ID найдены в текущем списке Runway, 3 не обнаружены') && mediaLibrary.includes('Постоянных URL: 0') && mediaLibrary.includes('Подписанные временные ссылки не сохраняются'), 'OSA media library must show the current audited source counts and remain blocked until permanent media hosting.')
assert.equal(mediaManifest.schemaVersion, 1, 'OSA media manifest schema version is unsupported.')
assert.equal(mediaManifest.metrics.total, 31, 'OSA media manifest must cover all 31 inventory rows.')
assert.equal(mediaManifest.metrics.sourceFound, 28, 'OSA media manifest source match count is stale.')
assert.equal(mediaManifest.metrics.sourceMissing, 3, 'OSA media manifest missing source count is stale.')
assert.equal(mediaManifest.metrics.permanentUrls, 0, 'OSA media manifest must not invent permanent URLs.')
assert.equal(mediaManifest.metrics.readyForPublication, 0, 'No OSA media asset should be ready before hosting, rights clearance and QC.')
assert.ok(!JSON.stringify(mediaManifest).includes('cloudfront.net') && !JSON.stringify(mediaManifest).includes('_jwt='), 'OSA media manifest must not leak signed Runway URLs.')
assert.ok(mediaLibrary.includes('https://github.com/osmanosmanov6880-bot/osa-global-intelligence') && mediaLibrary.includes('https://github.com/osmanosmanov6880-bot/osa-global-intelligence-2'), 'OSA media library must link both repositories.')
assert.ok(canonicalDoc.includes('Единый источник правды') && canonicalDoc.includes('osa-global-intelligence-2') && canonicalDoc.includes('19 видео'), 'OSA source-of-truth document is incomplete.')
assert.ok(page.includes('href="/osa-library/"'), 'OSA case must link the media library.')
assert.ok(mediaLibrary.includes('href="/lectures"'), 'OSA media library must link the ordered lecture catalogue.')
assert.ok(og.startsWith('<svg') && og.includes('width="1200" height="630"') && og.includes('OSA Global') && og.includes('BEYOND THE MODEL'), 'OSA social card is incomplete.')
assert.ok(landing.includes('href="/development/osa-intelligence/"') && landing.includes('<h3>OSA Global Intelligence</h3>'), 'Development landing does not feature OSA case.')
assert.ok(sitemap.includes('<loc>https://osgard.world/development/osa-intelligence/</loc>'), 'OSA case route is missing from sitemap.')
assert.ok(sitemap.includes('<loc>https://osgard.world/osa-library/</loc>'), 'OSA media library route is missing from sitemap.')
assert.ok(routes.includes("'/osa-library/'") && routes.includes("'/osa-library/media-manifest.json'"), 'Production matrix must probe both the OSA media library and its machine-readable manifest.')
assert.ok(routes.includes("'/development/osa-intelligence/'") && routes.includes("'/development/osa-intelligence/og.svg'"), 'Production route matrix must probe OSA case and social card.')
assert.ok(routes.includes('<title>OSA Global Intelligence — кейс OSGARD Development</title>') && routes.includes('data-case-status="interactive-demo"'), 'Production matrix must validate OSA case content.')
assert.equal(pkg.scripts?.['qa:osa-intelligence-case'], 'node scripts/osa-intelligence-case-smoke.mjs', 'Package must expose OSA case smoke test.')

for (const [name, workflow] of [['deploy', deploy], ['frontend check', frontend]]) {
  assert.ok(workflow.includes('"public/development/osa-intelligence/**"'), name + ' workflow must trigger on OSA case assets.')
  assert.ok(workflow.includes('"scripts/osa-intelligence-case-smoke.mjs"'), name + ' workflow must trigger on OSA smoke test changes.')
  assert.ok(workflow.includes('npm run qa:osa-intelligence-case'), name + ' workflow must run OSA case contract.')
}

console.log('PASS OSA Global Intelligence case: metadata, source links, release boundaries, Development portfolio, sitemap, route matrix and CI/SSH-deploy contracts.')
