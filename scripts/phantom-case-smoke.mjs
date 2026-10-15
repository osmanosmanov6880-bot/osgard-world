import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'
const read = (path) => { assert.ok(existsSync(path), 'Required PHANTOM case file is missing: ' + path); return readFileSync(path, 'utf8') }
const page = read('public/development/phantom/index.html')
const og = read('public/development/phantom/og.svg')
const dev = read('src/Development.tsx')
const css = read('src/phantom-case.css')
const sitemap = read('public/sitemap.xml')
const routes = read('scripts/production-route-matrix.mjs')
const workflow = read('.github/workflows/deploy-frontend.yml')
const pkg = JSON.parse(read('package.json'))
for (const marker of [
 '<title>PHANTOM — премиальный игровой клуб | OSGARD Development</title>',
 'https://osgard.world/development/phantom/',
 'name="robots" content="index,follow"',
 'id="preview-modes"', 'data-view-panel="calendar"', 'data-view-panel="queue"', 'data-view-panel="health"',
 'data-case-status="implementation-showcase"', 'id="scope-note"', 'NO API CONNECTION · NO BOOKINGS CREATED',
 'RELEASE SHOWCASE / 3.3.0', 'aria-pressed="true"', 'prefers-reduced-motion:reduce', 'case-structured-data'
]) assert.ok(page.includes(marker), 'PHANTOM case page marker missing: ' + marker)
assert.ok(page.includes('addEventListener("click"') && page.includes('data-view="calendar"') && page.includes('data-view="queue"') && page.includes('data-view="health"'), 'Preview tabs must be interactive.')
assert.ok(page.includes('не принимает настоящие бронирования') && page.includes('не отражает занятость реального клуба'), 'Case must disclose synthetic data and no live bookings.')
assert.ok(!page.includes('action="/api/') && !page.includes('fetch("https://'), 'Static case must not submit data or contact a live API.')
assert.ok(og.includes('<svg') && og.includes('width="1200" height="630"') && og.includes('PHANTOM') && og.includes('OSGARD'), 'Social preview SVG is incomplete.')
assert.ok(dev.includes("import './phantom-case.css'") && dev.includes('className="phantom-featured-case"') && dev.includes('href="/development/phantom/"'), 'Development portfolio card is missing.')
assert.ok(css.includes('.phantom-featured-case') && css.includes('@media(max-width:760px)') && css.includes('prefers-reduced-motion'), 'Responsive luxury card styling is missing.')
assert.ok(sitemap.includes('https://osgard.world/development/phantom/'), 'PHANTOM case is missing from sitemap.')
assert.ok(routes.includes("'/development/phantom/'") && routes.includes("'/development/phantom/og.svg'"), 'Production route matrix must check the page and OG image.')
assert.ok(routes.includes('PHANTOM — премиальный игровой клуб | OSGARD Development') && routes.includes('data-case-status="implementation-showcase"'), 'Production route matrix must validate PHANTOM page content.')
assert.ok(workflow.includes('"public/development/phantom/**"') && workflow.includes('"scripts/phantom-case-smoke.mjs"') && workflow.includes('run: node scripts/phantom-case-smoke.mjs'), 'SSH deployment workflow must watch and test the PHANTOM case.')
assert.equal(pkg.scripts?.['qa:phantom-case'], 'node scripts/phantom-case-smoke.mjs', 'Package script must expose the PHANTOM case test.')
assert.ok(read('scripts/deploy-workflow-smoke.mjs').includes('scripts/phantom-case-smoke.mjs'), 'General deployment smoke test must validate the PHANTOM test hook.')
console.log('PHANTOM case smoke passed: luxury layout, interactive preview, clear production boundaries, portfolio, social preview, sitemap and SSH deployment contract.')
