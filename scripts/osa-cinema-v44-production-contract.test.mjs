import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { join, resolve } from 'node:path'
const root = resolve(import.meta.dirname, '..')
const source = readFileSync(join(root, 'src/OSACinema.tsx'), 'utf8')
const spec = readFileSync(join(root, 'scripts/osa-cinema-v44-production.spec.mjs'), 'utf8')
const config = readFileSync(join(root, 'playwright.osa-cinema-v44-live.config.mjs'), 'utf8')
const workflow = readFileSync(join(root, '.github/workflows/osa-cinema-v44-live-acceptance.yml'), 'utf8')
const rights = JSON.parse(readFileSync(join(root, 'docs/OSA_CINEMA_V20_PRIVATE_RELEASE_POLICY.json'), 'utf8'))
const art = readFileSync(join(root, 'public/osa-cinema/obsidian/portal-640.webp'))
test('release marker is in actual unchanged V43 React viewer', () => {
  assert.match(source, /data-cinema-art='obsidian' data-cinema-release='v44'/)
  assert.equal(source.split('<OSAObsidianSceneNavigator ').length - 1, 1)
  assert.equal(source.split('<OSACinemaScreening ').length - 1, 1)
  assert.match(source, /titles=\{data\.map\(chapter=>chapter\.title\)\}/)
  assert.match(source, /saveOSACinemaProgress\(\{index,answers,locale,completed,selfChecks\}\)/)
})
test('real browser acceptance covers phone, desktop, story and language', () => {
  assert.match(spec, /width: 390, height: 844/)
  assert.match(spec, /width: 1536, height: 960/)
  assert.match(spec, /\.toHaveCount\(8\)/)
  assert.match(spec, /select\.selectOption\('4'\)/)
  assert.match(spec, /page\.reload/)
  assert.match(spec, /Switch to English/)
  assert.match(spec, /data-cinema-release=/)
  assert.match(spec, /\.toEqual\(\{ playable: 0, checkout: 0 \}\)/)
})
test('dedicated live HTTPS Playwright config cannot omit V44', () => {
  assert.match(config, /osa-cinema-v44-production\.spec\.mjs/)
  assert.match(config, /playwright\.osa-cinema-live\.config\.mjs/)
  assert.match(spec, /https:\/\/osgard\.world/)
  assert.match(spec, /response\.status\(\)/)
})
test('production E2E triggers only after master deploy success', () => {
  assert.match(workflow, /workflows: \['OSGARD frontend deploy'\]/)
  assert.match(workflow, /github\.event\.workflow_run\.conclusion == 'success'/)
  assert.match(workflow, /github\.event\.workflow_run\.head_branch == 'master'/)
  assert.match(workflow, /github\.event\.workflow_run\.head_sha/)
  assert.match(workflow, /--config playwright\.osa-cinema-v44-live\.config\.mjs/)
})
test('V20 film publication, commercial rights and checkout remain forbidden', () => {
  assert.equal(rights.publicationAuthorized, false)
  assert.equal(rights.rightsCleared, false)
  assert.equal(rights.paidCheckoutEnabled, false)
})
test('architectural portal remains bundled as original WebP', () => {
  assert.equal(art.subarray(0, 4).toString('ascii'), 'RIFF')
  assert.equal(art.subarray(8, 12).toString('ascii'), 'WEBP')
  assert.ok(art.length > 2048)
  assert.doesNotMatch(spec, /https?:\/\/(?:images\.unsplash|cdn\.pixabay)/i)
})
