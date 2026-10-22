import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import vm from 'node:vm'
import ts from 'typescript'

const read = path => readFileSync(path, 'utf8')
const main = read('src/main.tsx')
const home = read('src/AcademyHome.tsx')
const osaHome = read('src/IntelligenceHome.tsx')
const osaStyles = read('src/brandSystem.css')
const styles = read('src/academyHome.css')
const cinemaStyles = read('src/osaCinema.css')
const cinema = read('src/OSACinema.tsx')
const studio = read('src/AcademyStudio.tsx')
const progressStore = read('src/osaProgress.ts')
const studioStyles = read('src/academyStudio.css')
const html = read('index.html')
const sitemap = read('public/sitemap.xml')
const routeMatrix = read('scripts/production-route-matrix.mjs')

// Execute the real route selectors with successive browser snapshots. JSX and
// hooks are observation boundaries; no routing decision is reimplemented here.
// Reading a stale global location is an error: the latest SPA href owns routing.
const source = ts.createSourceFile('main.tsx', main, ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX)
const routeDeclarations = ['RoutedRoot', 'RoutedContent'].map(name => {
  const declaration = source.statements.find(node => ts.isFunctionDeclaration(node) && node.name?.text === name)
  assert.ok(declaration, 'The application must expose its actual ' + name + ' route selector')
  return declaration
})
const componentNames = new Set()
const visit = node => {
  if ((ts.isJsxOpeningElement(node) || ts.isJsxSelfClosingElement(node)) && ts.isIdentifier(node.tagName) && /^[A-Z]/.test(node.tagName.text)) componentNames.add(node.tagName.text)
  ts.forEachChild(node, visit)
}
routeDeclarations.forEach(visit)
const jsx = (type, props) => ({ type, props: props || {} })
const runtime = { jsx, jsxs: jsx, Fragment: Symbol('Fragment') }
const compile = text => ts.transpileModule(text, { compilerOptions: {
  target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX,
} }).outputText
const routing = { exports: {} }
vm.runInNewContext(compile(read('src/osgardRouting.ts')), { module: routing, exports: routing.exports }, { filename: 'actual-osgardRouting.ts' })
let snapshot = { href: '/', revision: 0, action: 'initial' }
const selectedRoutes = { exports: {} }
vm.runInNewContext(compile(routeDeclarations.map(node => node.getText(source)).join('\n') + '\nexport { RoutedRoot, RoutedContent };'), {
  ...Object.fromEntries([...componentNames].map(name => [name, name])),
  URL, normalizeReactPath: routing.exports.normalizeReactPath,
  React: { useState: initial => [initial, () => {}], useSyncExternalStore: (_subscribe, getSnapshot) => getSnapshot() },
  subscribeBrowserNavigation: () => () => {}, getBrowserSnapshot: () => snapshot, getServerSnapshot: () => snapshot,
  location: new Proxy({}, { get() { throw Error('Route selection must use the current browser snapshot, not global location') } }),
  module: selectedRoutes, exports: selectedRoutes.exports,
  require(name) { assert.equal(name, 'react/jsx-runtime'); return runtime },
}, { filename: 'actual-main-route-selectors.tsx' })
const find = (node, type) => {
  if (!node || typeof node !== 'object') return null
  if (Array.isArray(node)) return node.map(child => find(child, type)).find(Boolean) || null
  return node.type === type ? node : find(node.props?.children, type)
}
const routeCases = [
  ['/?project=evidence', 'AcademyHome', '/academy', 'intelligence'],
  ['/?project', 'AcademyHome', '/academy', 'intelligence'],
  ['/?project=&lang=en#notes', 'AcademyHome', '/academy', 'intelligence'],
  ['/?project=privacy#project-studio', 'AcademyHome', '/academy', 'intelligence'],
  ['/?%70roject=decision', 'AcademyHome', '/academy', 'intelligence'],
  ['/#project-studio', 'AcademyHome', '/academy', 'intelligence'],
  ['/?utm_source=course#project-studio', 'AcademyHome', '/academy', 'intelligence'],
  ['/', 'WorldHome', '/', 'world'],
  ['/?utm_source=course', 'WorldHome', '/', 'world'],
  ['/?projectile=evidence', 'WorldHome', '/', 'world'],
  ['/?Project=evidence', 'WorldHome', '/', 'world'],
  ['/#project-studio-extra', 'WorldHome', '/', 'world'],
  ['/?fragment=%23project-studio', 'WorldHome', '/', 'world'],
  ['/academy', 'AcademyHome', '/academy', 'intelligence'],
  ['/academy/', 'AcademyHome', '/academy', 'intelligence'],
  ['/intelligence?project=evidence#project-studio', 'IntelligenceHome', '/intelligence', 'intelligence'],
  ['/portal?project=privacy#project-studio', 'WorldHome', '/', 'world'],
  ['/osa-cinema', 'OSACinema', '/osa-cinema', 'intelligence'],
  ['/play?project=evidence#project-studio', 'PlayHome', '/play', 'play'],
]
for (const [href, component, seoPath, theme] of routeCases) {
  snapshot = { href, revision: snapshot.revision + 1, action: 'push' }
  const root = selectedRoutes.exports.RoutedRoot()
  assert.equal(find(root, 'BrandShell')?.props.theme, theme, href + ': correct product theme')
  const measured = find(root, 'MeasuredRoute')
  assert.ok(measured, href + ': the real route must remain mounted')
  assert.equal(measured.props.href, href, href + ': query and fragment must reach the route unchanged')
  assert.equal(measured.props.revision, snapshot.revision, href + ': latest navigation revision must reach the route')
  const content = selectedRoutes.exports.RoutedContent(measured.props)
  assert.ok(find(content, component), href + ': expected ' + component)
  assert.equal(find(content, 'Seo')?.props.path, seoPath, href + ': correct route metadata')
}
console.log('PASS ' + routeCases.length + ' actual route cases: Academy deep links, current SPA snapshots, preserved product routes, themes and SEO')
assert.ok(osaHome.includes('OSA INTELLIGENCE') && osaHome.includes("'/osa-cinema'") && osaHome.includes("'/academy'") && osaHome.includes('href="/learning"'), 'OSA homepage must link to the existing course, preserved Academy, and ecosystem portal')
assert.ok(osaHome.includes('Гостевой прогресс') && osaHome.includes('хранится в этом браузере') && osaHome.includes('isOSALearningProgressPersistent') && osaHome.includes('href="/learning/campus"') && osaHome.includes('Статус аудио и видео'), 'OSA homepage must distinguish guest persistence from server projects and disclose media limits')
assert.ok(osaStyles.includes('@media(max-width:760px)') && osaStyles.includes('@media(prefers-reduced-motion:reduce)') && osaStyles.includes(':focus-visible'), 'OSA homepage must be responsive, keyboard-accessible, and respect reduced motion')
assert.ok(home.includes("import AcademyStudio from './AcademyStudio'") && home.includes('<AcademyStudio locale={locale} />'), 'Academy must integrate the bilingual project studio into the learning journey')
assert.ok(studio.includes("KEY='osgard-academy-studio-v1'") && studio.includes('localStorage.setItem(KEY'), 'Project drafts and self-assessments must persist locally')
assert.ok(studio.includes("id:'evidence'") && studio.includes("id:'privacy'") && studio.includes("id:'decision'"), 'Project studio must include verification, privacy and human-decision assignments')
assert.ok(studio.includes('weights=[40,30,20,10]') && studio.includes('submission.scores.reduce'), 'Project studio must calculate a weighted rubric score')
assert.ok(studio.includes('URL.createObjectURL') && studio.includes('download='), 'Learners must be able to export their project as a text file')
assert.ok(studio.includes('setSaveFailed(true)') && studio.includes('t.saveFailed') && studio.includes('role="status"'), 'Project studio must clearly report when local draft persistence fails')
assert.ok(studio.includes('window.setTimeout(()=>URL.revokeObjectURL(url),1000)'), 'Project export must not revoke its object URL before the browser starts downloading')
assert.ok(studio.includes('aria-pressed={active===item.id}') && studio.includes('aria-live="polite"'), 'Project selection and scoring must expose accessible state')
assert.ok(studioStyles.includes('@media(max-width:700px)') && studioStyles.includes('focus-visible'), 'Project studio must be responsive and keyboard accessible')
assert.ok(studioStyles.includes('var(--panel)') && studioStyles.includes('var(--bg)') && !studioStyles.includes('var(--surface)') && !studioStyles.includes('var(--background)'), 'Project studio must use defined Academy design tokens')
assert.ok(home.includes('getOSACinemaLessons(locale)'), 'Featured lessons must use existing course data')
assert.ok(home.includes('lessonFilters.map') && home.includes('aria-pressed={activeAct === filter.value}'), 'Curriculum filters must be keyboard-accessible and expose their selected state')
assert.ok(home.includes('visibleLessons.map(lesson =>') && !home.includes('lessons.slice(0, 4)'), 'Academy must expose the full curriculum instead of silently truncating to four scenes')
assert.ok(home.includes('academy-lab') && home.includes('const taskBrief = task.trim()'), 'Academy must provide a task-to-prompt practical lab')
assert.ok(home.includes('qualityChecks') && home.includes('labEvidence') && home.includes('labPrivacy') && home.includes('labLimits'), 'Practical lab must let learners select concrete quality criteria')
assert.ok(home.includes('navigator.clipboard.writeText(taskBrief)') && home.includes('aria-pressed={taskType===mode.value}'), 'Practical lab must support accessible task modes and copying the generated prompt')
assert.ok(home.includes('maxLength={1000}') && home.includes('labCopyError'), 'Practical lab must constrain task input and explain clipboard failure')
assert.ok(home.includes('difficultyLabels') && home.includes('aria-pressed={difficulty===level}'), 'Practical lab must offer accessible difficulty levels')
assert.ok(home.includes('Assessment rubric (weights total 100%)') && home.includes('rubricAccuracy') && home.includes('rubricSafety'), 'Generated brief must include a weighted assessment rubric')
assert.ok(home.includes('labFeedback') && home.includes('Score each criterion from 0–4'), 'Generated brief must request criterion-based scores and actionable feedback')
assert.ok(styles.includes('.academy-lab-difficulty') && styles.includes('.academy-lab-rubric'), 'Difficulty and rubric controls must be styled')
assert.ok(styles.includes('.academy-lab-panel') && styles.includes('@media(max-width:760px)'), 'Practical lab must have responsive layout styling')
assert.ok(home.includes('/osa-cinema?scene=') && cinema.includes("new URLSearchParams(window.location.search).get('scene')"), 'Lesson cards must deep-link to their corresponding course scene')
assert.ok(home.includes('lessonPractice') && home.includes('/?project=${project}#project-studio'), 'Each lesson must offer a direct link to a mapped practical project')
assert.ok(home.includes("sceneIndex === 5 ? 'privacy' : sceneIndex === 3 || sceneIndex === 4 ? 'evidence' : 'decision'"), 'Lessons must map to the matching privacy, evidence or decision project')
assert.ok(studio.includes("new URLSearchParams(window.location.search).get('project')") && studio.includes("['evidence','privacy','decision'].includes(requested)"), 'Project studio must open a requested project safely from a lesson link')
assert.ok(studio.includes("has('project')") && studio.includes("scrollIntoView({behavior:'auto',block:'start'})"), 'Opening a mapped project must scroll the learner to the project workspace')
assert.ok(styles.includes('.academy-lesson-link') && styles.includes('.academy-lesson-practice'), 'Lesson and project actions must have distinct visual styles')
assert.ok(styles.includes('.academy-lesson-filters') && styles.includes('@media(prefers-reduced-motion:reduce)'), 'Curriculum filters must have responsive and reduced-motion styling')
for (const href of ['href="/osa-cinema"', 'href="/catalog"', 'href="/games/"', 'href="/portal"']) {
  assert.ok(home.includes(href), 'Academy homepage is missing expected navigation: ' + href)
}
assert.ok(home.includes('getOSALearningProgress()') && home.includes("osgard-academy-studio-v1") && home.includes('subscribeOSALearningProgress') && progressStore.includes("osgard-osa-learning-progress-v1"), 'Learning dashboard must consume the canonical progress store while preserving local project drafts')
assert.ok(home.includes('lessonCompletions') && home.includes('OSA_LESSON_SLUGS.length') && home.includes('href="/lectures"') && home.includes('lessonDetailCatalog'), 'Academy progress dashboard must display detailed lesson completion and link to the catalogue')
assert.ok(home.includes('academy-progress-grid') && home.includes('progressResume') && home.includes('progressStudio'), 'Learning dashboard must offer course resume and project continuation actions')
assert.ok(styles.includes('.academy-progress-card') && styles.includes('@media(max-width:760px)'), 'Learning dashboard must be responsive')
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
assert.ok(cinema.includes('getOSALearningProgress().cinema') && cinema.includes('saveOSACinemaProgress'), 'Cinema progress must use the canonical progress store')
assert.ok(progressStore.includes('function normalizeCinema') && progressStore.includes('OSA_PROGRESS_STORAGE_KEY') && progressStore.includes('CHOICE_COUNTS'), 'Canonical progress storage must version and validate cinema state')
assert.ok(cinema.includes('cinema-self-check') && cinema.includes('aria-labelledby=\'cinema-self-check-title\''), 'Course completion must offer an accessible self-assessment checkpoint')
assert.ok(cinema.includes('Check your readiness to practise') && cinema.includes('Проверьте готовность к практике'), 'Mastery self-check must be bilingual')
assert.ok(progressStore.includes("typeof checked === 'boolean'") && cinema.includes('setSelfChecks(saved.selfChecks)'), 'Self-check state must be validated and restored safely')
assert.ok(cinemaStyles.includes('.cinema-self-check') && cinemaStyles.includes('input:focus-visible'), 'Self-check controls must have visible keyboard focus styling')
assert.ok(cinema.includes('getOSALearningProgress().cinema') && cinema.includes('setHydrated(true)'), 'Progress writes must wait until the unified progress store has been restored')
assert.ok(cinema.includes('setCompleted(true)') && cinema.includes('t.completeTitle'), 'Completing the final scene must show a completion summary')
assert.ok(progressStore.includes('Number.isInteger(rawChoice)') && progressStore.includes('CHOICE_COUNTS[sceneIndex]'), 'Stored answer indices must be validated before restoration')
assert.ok(cinema.includes('data.findIndex(s=>s.act===act)') && cinema.includes('data.findIndex(s=>s.act===3)'), 'Act navigation must follow scene data when lessons are inserted')
assert.ok(html.includes('<title>OSGARD WORLD — цифровые продукты, построенные как системы</title>'), 'Root static title must describe OSGARD WORLD')
assert.ok(html.includes('OSGARD WORLD — стратегия, дизайн и разработка'), 'Root static description must describe OSGARD WORLD')
assert.ok(sitemap.includes('https://osgard.world/academy') && sitemap.includes('https://osgard.world/osa-cinema') && sitemap.includes('https://osgard.world/portal'), 'Sitemap must include OSA home, preserved Academy, course, and portal')
assert.ok(routeMatrix.includes("'/portal','/osa-cinema','/academy'"), 'Production route matrix must verify the Academy route and preserved portal/course routes')

assert.ok(studio.includes('next:') && studio.includes('item.next') && studio.includes("locale==='ru'?'Следующий шаг':'Next step'"), 'Low rubric ratings must reveal concrete, bilingual next-step advice for each quality criterion')
assert.ok(studioStyles.includes('.academy-studio-next-step'), 'Actionable rubric guidance must have a distinct readable visual treatment')

console.log('PASS three-brand map: preserved Academy and portal routes, source-backed lessons, SEO, responsive and reduced-motion contracts')

assert.ok(cinema.includes('cinema-practice-link') && cinema.includes('t.practice') && cinema.includes("index===5?'privacy':index===3||index===4?'evidence':'decision'"), 'Every course scene must link directly to its mapped practical project')
assert.ok(cinemaStyles.includes('.cinema-practice-link') && cinemaStyles.includes('.cinema-practice-link:focus-visible'), 'In-course project link must be styled and keyboard accessible')

assert.ok(studio.includes('deliverables:string[]') && studio.includes('academy-studio-checklist') && studio.includes('aria-valuenow={submission.deliverables.length}'), 'Project Studio must provide an accessible, persisted deliverable checklist')
assert.ok(studio.includes('deliverables:Array.isArray(value.deliverables)'), 'Checklist progress must restore from existing local drafts safely')
assert.ok(studio.includes("wordCount:'слов'") && studio.includes("wordCount:'words'") && studio.includes('split(/\\s+/)'), 'Project editor must show a whitespace-aware word count in both locales')
assert.ok(studio.includes('localOnly:') && studio.includes('academy-studio-local-note') && studioStyles.includes('.academy-studio-local-note'), 'Project editor must clearly explain browser-local storage and style the privacy notice')
assert.ok(home.includes('projectChecks') && home.includes('projectsCompleted') && home.includes('checklist items completed'), 'Academy dashboard must summarize practical checklist progress')

assert.ok(home.includes('const projectIds = [\'evidence\',\'privacy\',\'decision\']') && home.includes('learningProgress.nextProject'), 'Dashboard must recommend the next incomplete practical project')
assert.ok(home.includes('Продолжить:') && home.includes('Continue:'), 'Next-project recommendation must be localised in Russian and English')

assert.ok(home.includes('academy-skills-grid') && home.includes('academy-skill-card'), 'Academy dashboard must expose a practical competency map')
assert.ok(home.includes('nextLearningAction') && home.includes('actionChecksTitle') && home.includes('learningProgress.selfChecks < 3'), 'Dashboard must prioritize unfinished course self-checks before recommending another project')
assert.ok(home.includes('academy-next-action') && home.includes('actionStartTitle') && home.includes('actionProjectTitle'), 'Dashboard must show a contextual next learning action in both locales')
assert.ok(styles.includes('.academy-next-action') && styles.includes('@media(max-width:640px)'), 'Next learning action must have responsive styling')
assert.ok(home.includes('evidenceChecks') && home.includes('privacyChecks') && home.includes('decisionChecks'), 'Competency map must derive each skill state from its matching project checklist')
assert.ok(home.includes("!Array.isArray(studio)") && home.includes("[...new Set(entries.filter") && home.includes("deliverables.length === 4"), 'Dashboard must sanitize corrupted project state, deduplicate checklist entries and require four unique outcomes for completion')
assert.ok(home.includes("validAnswers") && home.includes("validSelfChecks") && home.includes("Math.min(3,validSelfChecks)"), 'Dashboard must validate stored course answers and cap self-check progress at three')
assert.ok(home.includes("index < lessons.length") && home.includes("started:Boolean(course && (index > 0 || validAnswers > 0 || validSelfChecks > 0 || completed))"), 'Dashboard must safely restore course state and recognize valid activity at the first scene')

assert.ok(home.includes('skillComplete') && home.includes('skillInProgress') && home.includes('skillNotStarted'), 'Competency map must distinguish not-started, in-progress and complete practice')
assert.ok(home.includes('aria-valuenow={Math.min(4,skill.count)}') && home.includes('skillSelfCheck'), 'Competency map must expose accessible checklist progress and course self-check totals')
assert.ok(home.includes('SKILL MAP') && home.includes('КАРТА НАВЫКОВ'), 'Competency map must be bilingual')
assert.ok(styles.includes('.academy-skills-grid') && styles.includes('@media(max-width:760px)'), 'Competency map must be responsive')

assert.ok(studio.includes('ratedCriteria=submission.scores.filter(value=>value>0).length') && studio.includes('rubricComplete=ratedCriteria===weights.length'), 'Rubric must distinguish unrated criteria from a complete self-assessment')
assert.ok(studio.includes("{rubricComplete?score:'—'}") && studio.includes('t.scorePending') && studio.includes('ratedCriteria/'), 'A final score must only appear after all criteria are rated, with visible completion progress')
assert.ok(studio.includes('rubricComplete?`${score}/100`:t.scorePending'), 'Exported project must not present an incomplete rubric as a final score')
assert.ok(studio.includes("scorePending:'Оцените все четыре критерия") && studio.includes("scorePending:'Rate all four criteria") && studioStyles.includes('.academy-studio-rubric-progress'), 'Rubric completion guidance must be bilingual and styled')

assert.ok(studio.includes("format:'osgard-academy-studio-backup',version:1") && studio.includes('osgard-academy-backup.json'), 'Learners must be able to export a versioned portable backup of all projects')
assert.ok(studio.includes('const importBackup=async(file:File|null)') && studio.includes("parsed.format!=='osgard-academy-studio-backup'") && studio.includes('parsed.version!==1'), 'Backup import must validate the expected format and version before restoring')
assert.ok(studio.includes('value.response.length>12000') && studio.includes('value.scores.length!==4') && studio.includes('item.deliverables.includes(id)'), 'Backup import must validate draft length, rubric scores and project checklist entries')
assert.ok(studio.includes('backupExport:') && studio.includes('backupImport:') && studio.includes('backupInvalid:') && studio.includes('aria-live="polite">{backupStatus}'), 'Backup and restore must provide bilingual accessible status feedback')
assert.ok(studio.includes('accept="application/json,.json"') && studioStyles.includes('.academy-studio-import-button') && studioStyles.includes('.academy-studio-backup-status'), 'Backup import must use an accessible JSON picker and responsive styled controls')

assert.ok(studio.includes('missingDeliverables') && studio.includes('weakCriteria') && studio.includes('reviewSteps'), 'Project Studio must derive a concrete improvement plan from incomplete deliverables and rubric scores')
assert.ok(studio.includes('reviewReady?t.reviewReady:t.reviewInProgress') && studio.includes('reviewAllDone') && studio.includes('aria-labelledby="academy-studio-review-title"'), 'Project Studio must distinguish actionable work remaining from readiness for human review')
assert.ok(studio.includes('submission.response.trim().length<250') && studio.includes('reviewShort'), 'Review plan must flag overly short drafts for substantive evidence and next steps')
assert.ok(studio.includes('reviewTitle:') && studio.includes('reviewReady:') && studio.includes('reviewMissing:') && studio.includes('reviewLow:'), 'Improvement plan status and guidance must be localised in both languages')
assert.ok(studioStyles.includes('.academy-studio-review') && studioStyles.includes('.academy-studio-review.is-ready'), 'Improvement plan must have clear responsive-ready visual states')

assert.ok(home.includes('academy-journey-steps') && home.includes('academy-journey-title'), 'Academy must show a unified course-to-practice learning pathway')
assert.ok(home.includes('criteriaRated') && home.includes('reviewedProjects') && home.includes('selfChecks===3'), 'Learning pathway must reflect course mastery and project rubric progress')
assert.ok(home.includes("addEventListener('osgard-academy-progress'") && studio.includes("dispatchEvent(new Event('osgard-academy-progress'))"), 'Dashboard progress must refresh immediately when project drafts or rubric scores change')
assert.ok(styles.includes('.academy-journey-steps') && styles.includes('@media(max-width:760px)'), 'Learning pathway must be responsive')
