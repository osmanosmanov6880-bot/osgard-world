import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const read = path => readFileSync(path, 'utf8')
const main = read('src/main.tsx')
const home = read('src/AcademyHome.tsx')
const styles = read('src/academyHome.css')
const cinema = read('src/OSACinema.tsx')
const html = read('index.html')
const sitemap = read('public/sitemap.xml')
const routeMatrix = read('scripts/production-route-matrix.mjs')

assert.ok(main.includes("if (path === '/') return <><Seo path=\"/\" /><AcademyHome /></>"), 'Root route must render the Academy homepage')
assert.ok(main.includes("if (path === '/portal') return <><Seo path=\"/portal\" /><App /></>"), 'Previous ecosystem homepage must remain available at /portal')
assert.ok(main.includes("if (path === '/osa-cinema') return <><Seo path={path} /><OSACinema /></>"), 'Existing OSA Original course URL must remain registered')
assert.ok(home.includes('getOSACinemaLessons(locale)'), 'Featured lessons must use existing course data')
for (const href of ['href="/osa-cinema"', 'href="/catalog"', 'href="/games/"', 'href="/portal"']) {
  assert.ok(home.includes(href), 'Academy homepage is missing expected navigation: ' + href)
}
for (const section of ['academy-hero', 'academy-path-grid', 'academy-lesson-grid', 'academy-practice-grid', 'academy-ecosystem-grid', 'academy-final-cta']) {
  assert.ok(home.includes(section), 'Academy homepage is missing section: ' + section)
}
assert.ok(styles.includes('@media(max-width:760px)'), 'Academy responsive layout rules are missing')
assert.ok(styles.includes('@media(prefers-reduced-motion:reduce)'), 'Academy reduced-motion support is missing')
assert.ok(cinema.includes("className='cinema-brand' href='/portal'"), 'Existing course navigation must link to the preserved portal route')
assert.ok(cinema.includes("location.href='/portal'"), 'Escape-key course navigation must return to the preserved portal route')
assert.ok(cinema.includes('ПРАКТИКУМ · ПРОВЕРКА ОТВЕТА') && cinema.includes('PRACTICE · VERIFY THE ANSWER'), 'Course must teach evidence verification in both locales')
assert.ok(cinema.includes('ПРАКТИКУМ · ПРИВАТНОСТЬ') && cinema.includes('PRACTICE · PRIVACY'), 'Course must teach privacy-aware prompting in both locales')
assert.ok(cinema.includes('независимое подтверждение') && cinema.includes('independent corroboration'), 'Verification lesson must distinguish citations from independent evidence')
assert.ok(cinema.includes('принцип минимизации') && cinema.includes('data minimisation'), 'Privacy lesson must teach data minimisation')
assert.ok(cinema.includes('https://www.nist.gov/privacy-framework'), 'Course notes must link to the NIST Privacy Framework')
assert.ok(cinema.includes('function restoreProgress(raw:string|null)'), 'Course progress restoration must be centralised and validated')
assert.ok(cinema.includes('version:2,index,answers,locale,completed'), 'Course progress must persist a versioned completion state')
assert.ok(cinema.includes("finally{setHydrated(true)}"), 'Progress writes must wait until stored progress has been restored')
assert.ok(cinema.includes('setCompleted(true)') && cinema.includes('t.completeTitle'), 'Completing the final scene must show a completion summary')
assert.ok(cinema.includes('Number.isInteger(value)') && cinema.includes('scenes.ru[sceneIndex].choices?.length'), 'Stored answer indices must be validated before restoration')
assert.ok(html.includes('<title>OSGARD AI Academy — понимать, проверять, применять ИИ</title>'), 'Static document title must describe the Academy homepage')
assert.ok(html.includes('OSGARD AI Academy — интерактивное обучение ИИ'), 'Static description must describe the Academy homepage')
assert.ok(sitemap.includes('https://osgard.world/osa-cinema') && sitemap.includes('https://osgard.world/portal'), 'Sitemap must include the Academy experience and preserved portal')
assert.ok(routeMatrix.includes("'/portal','/osa-cinema'"), 'Production route matrix must verify both preserved routes')

console.log('PASS Academy-first homepage: root routing, source-backed lesson content, ecosystem links, SEO, responsive and reduced-motion contracts')
