import assert from 'node:assert/strict'
import { existsSync, readFileSync, statSync } from 'node:fs'
import vm from 'node:vm'

const read = (path) => {
  assert.ok(existsSync(path), `Required TEDES file is missing: ${path}`)
  return readFileSync(path, 'utf8')
}
const demoPath = 'public/tedes/index.html'
const casePath = 'public/development/tedes/index.html'
const demo = read(demoPath)
const casePage = read(casePath)
const devSource = read('src/Development.tsx')
const cardCss = read('src/tedes-case.css')
const sitemap = read('public/sitemap.xml')
const routeMatrix = read('scripts/production-route-matrix.mjs')
const workflow = read('.github/workflows/deploy-frontend.yml')

assert.ok(demo.includes('<title>TEDES Studio — архитектурная фурнитура как система</title>'), 'TEDES demo title mismatch')
assert.ok(demo.includes('https://osgard.world/tedes/'), 'TEDES demo canonical URL missing')
for (const marker of ['id="addDoor"', 'id="doorRows"', 'id="exportJson"', 'id="exportCsv"', 'id="projectName"', '30 независимых']) {
  assert.ok(demo.includes(marker), `TEDES demo capability marker missing: ${marker}`)
}
assert.ok(demo.includes('реальные складские остатки') || demo.includes('Реальные складские остатки'), 'Demo boundaries disclaimer missing')
assert.ok(casePage.includes('<title>TEDES — кейс OSGARD Development</title>'), 'TEDES case title mismatch')
assert.ok(casePage.includes('https://osgard.world/development/tedes/'), 'TEDES case canonical URL missing')
assert.ok(casePage.includes('href="/tedes/"'), 'Case must link to the standalone TEDES demo')
assert.ok(casePage.includes('Не заявляется как готовое коммерческое подключение'), 'Case must explain commercial integration boundaries')
assert.ok(devSource.includes("import './tedes-case.css'") && devSource.includes('tedes-featured-case') && devSource.includes('href="/development/tedes/"'), 'Development portfolio case card is missing')
assert.ok(cardCss.includes('.tedes-featured-case') && cardCss.includes('@media(max-width:760px)'), 'Responsive case-card styling is missing')

for (const imagePath of ['public/tedes/assets/hero-door.webp', 'public/tedes/assets/architecture-scene.webp']) {
  assert.ok(existsSync(imagePath) && statSync(imagePath).size > 1000, `TEDES product image is missing or too small: ${imagePath}`)
}
assert.ok(demo.includes('src="/tedes/assets/hero-door.webp"'), 'TEDES demo must use the real product image')
assert.ok(casePage.includes('id="materials"') && casePage.includes('src="/tedes/assets/architecture-scene.webp"') && casePage.includes('src="/tedes/assets/hero-door.webp"'), 'TEDES case material gallery must use real images')
assert.ok(demo.includes('LUXURY ART DIRECTION') && demo.includes('Cormorant+Garamond'), 'TEDES demo luxury art direction or display typography is missing')
assert.ok(casePage.includes('LUXURY ART DIRECTION') && casePage.includes('Cormorant+Garamond'), 'TEDES case luxury art direction or display typography is missing')
assert.ok(!demo.includes(String.fromCharCode(92) + 'n</style>') && !casePage.includes(String.fromCharCode(92) + 'n</style>'), 'Luxury CSS must not be preceded by a literal escaped newline')
assert.ok(demo.includes('<meta charset="utf-8">' + String.fromCharCode(10) + '<link rel="preconnect"') && casePage.includes('<meta charset="utf-8">' + String.fromCharCode(10) + '<link rel="preconnect"'), 'Web-font preconnects must be valid head markup')
assert.ok(cardCss.includes('LUXURY CARD') && cardCss.includes('Cormorant Garamond'), 'Development featured case luxury styling is missing')
assert.ok(sitemap.includes('https://osgard.world/development/tedes/') && sitemap.includes('https://osgard.world/tedes/'), 'TEDES routes are missing from sitemap')
assert.ok(routeMatrix.includes("'/tedes/'") && routeMatrix.includes("'/development/tedes/'"), 'Production route matrix does not include TEDES routes')
assert.ok(workflow.includes('"public/tedes/**"') && workflow.includes('"public/development/tedes/**"'), 'Deployment workflow does not watch TEDES pages')

let scriptCount = 0
for (const match of demo.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)) {
  scriptCount++
  new vm.Script(match[1], { filename: demoPath })
}
assert.equal(scriptCount, 1, 'Expected exactly one inline demo script and no unreviewed external scripts')
for (const route of ['/tedes/', '/development/tedes/']) {
  assert.ok(routeMatrix.includes(route), `Production route matrix missing ${route}`)
}
console.log(JSON.stringify({ status: 'PASS', pages: [demoPath, casePath], inlineScriptsSyntaxChecked: scriptCount, routes: ['/tedes/', '/development/tedes/'], productLimits: 'clearly disclosed' }, null, 2))
