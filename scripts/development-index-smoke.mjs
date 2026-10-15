import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'

const read = path => { assert.ok(existsSync(path), 'Missing Development landing file: ' + path); return readFileSync(path, 'utf8') }
const page = read('public/development/index.html')
const og = read('public/development/og.svg')
const routes = read('scripts/production-route-matrix.mjs')
const sitemap = read('public/sitemap.xml')
const deploy = read('.github/workflows/deploy-frontend.yml')
const frontend = read('.github/workflows/frontend-check.yml')

for (const marker of [
  '<title>Разработка цифровых продуктов — OSGARD Development</title>',
  '<link rel="canonical" href="https://osgard.world/development/">',
  'property="og:image" content="https://osgard.world/development/og.svg"',
  'id="work"', 'href="/development/phantom/"', 'href="/development/tedes/"',
  'href="/development/merakki/"', 'href="/development/auto-style/"', 'href="/development/osa-intelligence/"',
  'STATUS /', 'prefers-reduced-motion:reduce'
]) assert.ok(page.includes(marker), 'Development landing marker missing: ' + marker)
assert.ok(!/<form\b/i.test(page) && !/action=["']\/api/i.test(page), 'Portfolio landing must not submit live data.')
assert.ok(og.startsWith('<svg') && og.includes('width="1200" height="630"') && og.includes('OSGARD / DEVELOPMENT') && og.includes('Build what'), 'Development social card is incomplete.')
assert.ok(routes.includes("'/development/'") && routes.includes("'/development/og.svg'"), 'Production route matrix must include Development landing and social image.')
assert.ok(routes.includes('Разработка цифровых продуктов — OSGARD Development') && routes.includes('SELECTED WORK / 01—05'), 'Production matrix must validate Development landing content.')
assert.ok(sitemap.includes('<loc>https://osgard.world/development/</loc>'), 'Development landing must be listed in sitemap.')
for (const workflow of [deploy, frontend]) {
  assert.ok(workflow.includes('"public/development/index.html"'), 'Workflow must trigger for Development landing changes.')
  assert.ok(workflow.includes('"public/development/og.svg"'), 'Workflow must trigger for Development social card changes.')
  assert.ok(workflow.includes('"scripts/development-index-smoke.mjs"'), 'Workflow must trigger for Development smoke changes.')
  assert.ok(workflow.includes('node scripts/development-index-smoke.mjs'), 'Workflow must execute Development smoke.')
}
console.log('PASS Development landing: index route, case links, social metadata, sitemap, production route matrix and deploy QA.')
