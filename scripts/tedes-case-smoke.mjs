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


const catalog = read('public/tedes/catalog/index.html')
const collections = read('public/tedes/collections/index.html')
const product = read('public/tedes/product/index.html')
const materials = read('public/tedes/materials/index.html')
const printView = read('public/tedes/print/index.html')
const projectWorkspace = read('public/tedes/project/index.html')
assert.ok(catalog.includes('id="search"') && catalog.includes('id="collection"') && catalog.includes('id="finish"') && catalog.includes('id="products"'), 'Catalog filter UI is incomplete')
assert.ok(catalog.includes('Цена не подтверждена'), 'Catalog must not invent prices')
assert.ok(collections.includes('href="/tedes/catalog/?collection=FORMA"') && collections.includes('href="/tedes/catalog/?collection=LINEA"') && collections.includes('href="/tedes/catalog/?collection=MATERIA"'), 'Collection routes must filter the catalog')
assert.ok(catalog.includes('new URLSearchParams(location.search)') && catalog.includes('query.get("collection")'), 'Catalog must initialize filters from collection links')
assert.ok(product.includes('id="addToProject"') && product.includes('localStorage') && product.includes('tedes-studio-project-v1'), 'Product page must add a concept item into the shared local project')
assert.ok(product.includes('link.href="/tedes/project/"') && product.includes('sku==="LINEA-EDGE-02"?"Brushed steel"'), 'Product page must route to the project workspace and map the steel finish correctly')
assert.ok(projectWorkspace.includes('<title>TEDES — проектная ведомость</title>') && projectWorkspace.includes('name="robots" content="noindex,nofollow"'), 'Project workspace metadata or private indexing policy is missing')
for (const marker of ['id="positionRows"','id="requestForm"','id="contactEmail"','id="exportJson"','id="exportCsv"','id="clearProject"','id="projectName"','tedes-studio-project-v1','data-duplicate=','data-remove=','LOCAL FILE ONLY','tedes-project-request.json','window.addEventListener("storage"']) {
  assert.ok(projectWorkspace.includes(marker), 'Project workspace contract marker missing: ' + marker)
}
assert.ok(projectWorkspace.includes('noindex,nofollow') && projectWorkspace.includes('не отправлено') && projectWorkspace.includes('не подтверждены'), 'Workspace privacy/commercial disclaimers are incomplete')
assert.ok(demo.includes('doors:doors.map(d=>({...d}))') && demo.includes('schema:"tedes-studio-project/v1"'), 'Studio quote JSON must remain importable into the same project schema')
assert.ok(demo.includes('const columns=["id","zone","sku","collection"') && demo.includes('door.sku?" · "+escapeHtml(door.sku)'), 'Model SKUs must remain visible and included in the exported CSV')
assert.ok(materials.includes('Brushed Steel') && materials.includes('Matte Black') && materials.includes('Техническая граница'), 'Materials guide must show demo finishes and disclose limits')
assert.ok(demo.includes('tedes-studio-project-v1') && demo.includes('id="buildQuote"') && demo.includes('id="quoteEmail"'), 'Studio persistence and quote brief UI are missing')
assert.ok(demo.includes('href="/tedes/print/"'), 'Studio must link to the print-ready project schedule')
assert.ok(demo.includes('id="importJson"') && demo.includes('id="importFile"') && demo.includes('file.size>1024*1024'), 'Validated JSON project import is missing')
assert.ok(demo.includes('data-duplicate=') && demo.includes('doors.splice(index+1,0,copy)'), 'Schedule position duplication is missing')
assert.ok(demo.includes('doors.length>=30') && demo.includes('id="doorCount"'), 'Schedule duplication must respect the 30-position cap')
const safeCsvCellMatch = demo.match(/function safeCsvCell\(value\)\s*\{[\s\S]*?\n  \}/)
assert.ok(safeCsvCellMatch, 'Reusable CSV formula-injection guard is missing')
const safeCsvCell = vm.runInNewContext('(' + safeCsvCellMatch[0] + ')')
assert.equal(safeCsvCell('=1+1'), '"\'=1+1"')
assert.equal(safeCsvCell('Door "A"'), '"Door ""A"""')
assert.ok(safeCsvCell('  @SUM(A1:A2)').startsWith('"\'  @SUM'), 'CSV guard must neutralize formula prefixes after whitespace')
assert.ok(demo.includes('tedes-project-demo/v1') && demo.includes('tedes-studio-project/v1') && demo.includes('Текущий проект не изменён'), 'JSON import must accept only TEDES backups and preserve state on failure')
assert.ok(printView.includes('<title>TEDES — печатная ведомость проекта</title>') && printView.includes('name="robots" content="noindex,nofollow"'), 'Print view title or indexing safeguards are missing')
for (const marker of ['id="printProject"', 'id="positionRows"', 'id="sourceNotice"', 'id="generatedAt"', 'window.print()', 'tedes-studio-project-v1', 'localStorage.getItem', 'не подтверждённая производственная спецификация', 'не отправляются на сервер']) {
  assert.ok(printView.toLowerCase().includes(marker.toLowerCase()), 'Print view contract marker missing: ' + marker)
}
assert.ok(demo.includes('НЕ отправлены') || demo.includes('не отправляется'), 'Quote builder must clearly say it does not submit anything')
let featureScriptCount = 0
for (const [filename, page] of [['catalog', catalog], ['product', product], ['print-view', printView], ['project-workspace', projectWorkspace]]) {
  for (const match of page.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)) {
    new vm.Script(match[1], { filename: filename + '.html' })
    featureScriptCount++
  }
}
for (const route of ['/tedes/catalog/','/tedes/collections/','/tedes/product/','/tedes/materials/','/tedes/project/']) assert.ok(routeMatrix.includes(route), 'Production route matrix missing ' + route)

let scriptCount = 0
for (const match of demo.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)) {
  scriptCount++
  new vm.Script(match[1], { filename: demoPath })
}
assert.equal(scriptCount, 1, 'Expected exactly one inline demo script and no unreviewed external scripts')
for (const route of ['/tedes/', '/tedes/project/', '/tedes/print/', '/development/tedes/']) {
  assert.ok(routeMatrix.includes(route), `Production route matrix missing ${route}`)
}
console.log(JSON.stringify({ status: 'PASS', pages: [demoPath, 'public/tedes/project/index.html', casePath], inlineScriptsSyntaxChecked: scriptCount + featureScriptCount, routes: ['/tedes/', '/tedes/project/', '/tedes/print/', '/development/tedes/'], productLimits: 'clearly disclosed' }, null, 2))
