import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { join, resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const src = readFileSync(join(root, 'src/OSACinemaScreening.tsx'), 'utf8')
const spec = readFileSync(join(root, 'scripts/osa-cinema-v45-production.spec.mjs'), 'utf8')
const config = readFileSync(join(root, 'playwright.osa-cinema-v44-live.config.mjs'), 'utf8')
const workflow = readFileSync(join(root, '.github/workflows/osa-cinema-v44-live-acceptance.yml'), 'utf8')
const policy = JSON.parse(readFileSync(join(root, 'docs/OSA_CINEMA_V20_PRIVATE_RELEASE_POLICY.json'), 'utf8'))
const expectedArt = ['library.webp', 'understand.webp', 'library.webp', 'verify.webp',
  'verify.webp', 'library.webp', 'decide.webp', 'decide.webp']

test('V45 fullscreen modal isolates its background and restores prior inert state', () => {
  assert.match(src, /portalRoot = useRef<HTMLDivElement>/)
  assert.match(src, /child !== activePortal/)
  assert.match(src, /element.inert = true/)
  assert.match(src, /element.inert = wasInert/)
  assert.match(src, /if \(!dialog.current.contains\(document.activeElement\)\)/)
  assert.match(src, /previousFocus.current\?\.focus\(\)/)
  assert.match(src, /ref=\{portalRoot\}/)
  assert.match(spec, /Shift\+Tab/)
  assert.match(spec, /toBeFocused\(\)/)
  assert.match(spec, /Background inert state must be restored/)
})

test('V45 all eight scenes retain four original same-origin WebP images', () => {
  const list = src.match(/const imageFileByScene = \[([\s\S]*?)\] as const/)
  assert.ok(list, 'Cannot identify authoritative eight-scene artwork map')
  const names = [...list[1].matchAll(/'([^']+\.webp)'/g)].map(match => match[1])
  assert.deepEqual(names, expectedArt)
  for (const name of new Set(names)) {
    const bytes = readFileSync(join(root, 'public/osa-cinema/reference', name))
    assert.ok(bytes.length > 2048)
    assert.equal(bytes.subarray(0, 4).toString('ascii'), 'RIFF')
    assert.equal(bytes.subarray(8, 12).toString('ascii'), 'WEBP')
  }
  assert.match(spec, /element.decode\(\)/)
  assert.match(spec, /naturalWidth/)
  assert.match(spec, /toBeLessThanOrEqual\(2\)/)
  assert.doesNotMatch(src, /<video\b|<audio\b|stripe\.com|checkout\.stripe/i)
})

test('V45 production HTTPS runs with existing exact-deployment V44 receipt', () => {
  assert.match(config, /osa-cinema-v44-production\.spec\.mjs/)
  assert.match(config, /osa-cinema-v45-production\.spec\.mjs/)
  assert.match(workflow, /scripts\/osa-cinema-v45-accessibility-contract\.test\.mjs/)
  assert.match(workflow, /src\/OSACinemaScreening\.tsx/)
  assert.match(workflow, /public\/osa-cinema\/reference\/\*\*/)
  assert.match(workflow, /github.event.workflow_run.conclusion == 'success'/)
  assert.match(workflow, /github.event.workflow_run.head_branch == 'master'/)
  assert.match(spec, /osa-cinema-deploy-sha/)
  assert.match(spec, /OSGARD_DEPLOY_SHA/)
})

test('V45 commercial film rights and checkout remain strictly NO-GO', () => {
  assert.equal(policy.publicationAuthorized, false)
  assert.equal(policy.rightsCleared, false)
  assert.equal(policy.paidCheckoutEnabled, false)
})
