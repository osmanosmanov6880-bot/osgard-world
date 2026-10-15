import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'

const read = path => {
  assert.ok(existsSync(path), 'Missing OSA case release file: ' + path)
  return readFileSync(path, 'utf8')
}

const page = read('public/development/osa-intelligence/index.html')
const og = read('public/development/osa-intelligence/og.svg')
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
  'data-case-status="interactive-demo"',
  'href="/"',
  'href="/osa-cinema"',
  'osa-global-intelligence',
  'osa-global-intelligence-2',
  'localStorage',
  'не заявляет о готовом полнометражном видео',
  'prefers-reduced-motion:reduce'
]) assert.ok(page.includes(marker), 'OSA case contract marker missing: ' + marker)

assert.ok(og.startsWith('<svg') && og.includes('width="1200" height="630"') && og.includes('OSA Global') && og.includes('BEYOND THE MODEL'), 'OSA social card is incomplete.')
assert.ok(landing.includes('SELECTED WORK / 01—05') && landing.includes('href="/development/osa-intelligence/"'), 'Development landing does not feature OSA case.')
assert.ok(sitemap.includes('<loc>https://osgard.world/development/osa-intelligence/</loc>'), 'OSA case route is missing from sitemap.')
assert.ok(routes.includes("'/development/osa-intelligence/'") && routes.includes("'/development/osa-intelligence/og.svg'"), 'Production route matrix must probe OSA case and social card.')
assert.ok(routes.includes('<title>OSA Global Intelligence — кейс OSGARD Development</title>') && routes.includes('data-case-status="interactive-demo"'), 'Production matrix must validate OSA case content.')
assert.equal(pkg.scripts?.['qa:osa-intelligence-case'], 'node scripts/osa-intelligence-case-smoke.mjs', 'Package must expose OSA case smoke test.')

for (const [name, workflow] of [['deploy', deploy], ['frontend check', frontend]]) {
  assert.ok(workflow.includes('"public/development/osa-intelligence/**"'), name + ' workflow must trigger on OSA case assets.')
  assert.ok(workflow.includes('"scripts/osa-intelligence-case-smoke.mjs"'), name + ' workflow must trigger on OSA smoke test changes.')
  assert.ok(workflow.includes('npm run qa:osa-intelligence-case'), name + ' workflow must run OSA case contract.')
}

console.log('PASS OSA Global Intelligence case: metadata, source links, release boundaries, Development portfolio, sitemap, route matrix and CI/SSH-deploy contracts.')
