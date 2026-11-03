import assert from 'node:assert/strict'
import { readFileSync, existsSync } from 'node:fs'

const read = path => readFileSync(path, 'utf8')
const checks = []
const check = (name, action) => {
  action()
  checks.push(name)
  console.log('PASS', name)
}

check('six independently reachable OSGARD surfaces', () => {
  for (const file of ['src/PlayHome.tsx','src/WorldHome.tsx','src/AcademyHome.tsx',
    'src/IntelligenceHome.tsx','src/developmentSignature.css','public/entertainment/archive/index.html']) {
    assert.equal(existsSync(file), true, 'Missing unified surface: ' + file)
  }
})
check('19 existing Play world identities retained', () => {
  const titles = read('src/playGameTitles.ts')
  assert.equal((titles.match(/^\s+"[^"]+":/gm) || []).length, 19)
  assert.match(read('src/PlayExploreSections.tsx'), /id="catalog"/)
  assert.match(read('src/BrandShell.tsx'), /play-catalog-shell/)
})
check('master game advancement retained, no gameplay fork', () => {
  const empire = read('public/games/empire-orbit/index.html')
  assert.match(empire, /OSGARD EMPIRE standalone v25/)
  assert.match(empire, /OSGARD AURORA \/ FIVE WAVES 2026/)
  assert.equal(existsSync('public/games/time-omega-preview/index.html'), true)
  assert.match(read('src/TimePrototype.tsx'), /recordCoreEvent/)
})
check('World architectural portals stay lightweight, reachable and motion-aware', () => {
  const world = read('src/WorldHome.tsx')
  const styles = read('src/omegaWorld.css')
  assert.match(world, /omega-portals-hero/)
  assert.ok(world.includes('osgard-portal-desktop.webp'))
  assert.ok(world.includes('osgard-portal-mobile.webp'))
  assert.equal(existsSync('public/brand/osgard-portal-desktop.webp'), true)
  assert.equal(existsSync('public/brand/osgard-portal-mobile.webp'), true)
  assert.match(styles, /omega-portals-primary-hotspot:focus-visible/)
  assert.match(world, /fetchPriority="high"/)
  assert.match(world, /className="omega-portal omega-portal--osa"/)
  assert.match(world, /className="omega-portal omega-portal--play"/)
  assert.match(world, /className="omega-portal omega-portal--development"/)
  assert.match(world, /href="\/intelligence"/)
  assert.match(world, /href="\/play"/)
  assert.match(world, /href="\/development"/)
  assert.match(styles, /@media\s*\(prefers-reduced-motion:\s*reduce\)/)
  assert.match(styles, /omega-portal-stage/)
})
check('Academy deep links stay in Academy and follow SPA history', () => {
  const home = read('src/AcademyHome.tsx')
  const studio = read('src/AcademyStudio.tsx')
  assert.doesNotMatch(home, /href=[^\n]*["'`]\/\?project=/)
  assert.match(home, /\/academy\?project=privacy#project-studio/)
  assert.match(home, /<main className="academy-home" lang={locale}>/)
  assert.match(studio, /subscribeBrowserNavigation/)
  assert.match(studio, /setActive\(requestedProject\)/)
  assert.match(read('src/academyStudio.css'), /#academy-studio-backup-input/)
})
check('Intelligence panel is real, sourced and keyboard reachable', () => {
  const osa = read('src/IntelligenceHome.tsx')
  assert.match(osa, /id="proof-card"[^\n]*tabIndex={-1}/)
  assert.match(osa, /nvlpubs\.nist\.gov\/nistpubs\/ai\/NIST\.AI\.600-1\.pdf/)
  assert.match(read('src/BrandShell.tsx'), /\/intelligence#proof-card/)
})
check('portfolio statuses are source backed', () => {
  const cases = read('src/featuredCases.ts')
  assert.match(cases, /'TEDES'/)
  assert.match(cases, /'PHANTOM'/)
  assert.match(cases, /'MERAKKI'/)
  assert.match(cases, /'ESSENTIA'/)
  assert.match(read('src/WorldHome.tsx'), /cases\[1\]\.href/)
})
check('Entertainment archive works in RU EN AR and points to full Play', () => {
  for (const name of ['archive','en','ar']) {
    const html = read('public/entertainment/' + name + '/index.html')
    assert.match(html, /entertainment-premium/)
    assert.match(html, /href="\/play"/)
    assert.equal((html.match(/<div class="art"><small>/g) || []).length, 7, name)
    assert.equal((html.match(/<a class="case-feature/g) || []).length, 4, name)
  }
})
check('new unified browser scenarios are registered', () => {
  const config = read('playwright.ecosystem.config.mjs')
  assert.match(config, /unified-six-surfaces\.spec\.mjs/)
  assert.match(read('scripts/academy-cockpit-browser.spec.mjs'), /Academy deep links open the intended/)
})
console.log('OSGARD UNIFIED RELEASE CONTRACT:', checks.length, 'checks passed')
