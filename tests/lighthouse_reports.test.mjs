import assert from 'node:assert/strict'
import { test } from 'node:test'
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { spawnSync } from 'node:child_process'
import { assessReport as skillcred } from '../scripts/lighthouse-report.mjs'
import { assessReport as games } from '../scripts/games-lighthouse-report.mjs'
import { validateReport } from '../scripts/lighthouse-report-validation.mjs'
import { lighthouseFixture } from './fixtures/lighthouse-reports.mjs'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const components = { skillcred: { assess: skillcred, script: 'lighthouse-report.mjs' }, games: { assess: games, script: 'games-lighthouse-report.mjs' } }
const metricIds = ['first-contentful-paint', 'largest-contentful-paint', 'speed-index', 'total-blocking-time', 'cumulative-layout-shift']

function cli(component, reports, options = {}) {
  const directory = mkdtempSync(join(tmpdir(), 'osgard-lighthouse-report-'))
  try {
    const paths = reports.map((report, index) => {
      // Deliberately uninformative names: report content and argument position
      // determine the profile, never a filename substring.
      const file = join(directory, `input-${index}.json`)
      writeFileSync(file, options.raw ? report : JSON.stringify(report))
      return file
    })
    if (options.missing) paths[0] = join(directory, 'missing.json')
    const result = spawnSync(process.execPath, [join(root, 'scripts', components[component].script), ...paths], { encoding: 'utf8', timeout: 10000 })
    assert.ifError(result.error)
    assert.equal(result.signal, null)
    return { status: result.status, output: result.stdout + result.stderr }
  } finally {
    rmSync(directory, { recursive: true, force: true })
  }
}

for (const [component, { assess }] of Object.entries(components)) {
  const pair = () => ['mobile', 'desktop'].map(mode => lighthouseFixture(component, mode))

  test(`${component}: a complete CLI mobile/desktop pair passes`, () => {
    assert.equal(cli(component, pair()).status, 0)
  })

  test(`${component}: the CLI requires exactly two distinct profiles`, () => {
    for (const reports of [[], [pair()[0]], [...pair(), pair()[0]], [pair()[0], pair()[0]], pair().reverse()]) {
      assert.notEqual(cli(component, reports).status, 0)
    }
  })

  test(`${component}: empty, partial, malformed and unreadable JSON cannot pass`, () => {
    for (const report of [{}, { categories: {} }, null, [], 'report', 100]) {
      assert.equal(assess(report, 'mobile').pass, false)
    }
    assert.equal(cli(component, [{ categories: {} }, { categories: {} }]).status, 1)
    assert.equal(cli(component, ['{', JSON.stringify(pair()[1])], { raw: true }).status, 2)
    assert.equal(cli(component, pair(), { missing: true }).status, 2)
  })

  test(`${component}: every category needs a finite bounded score and its audit evidence`, () => {
    for (const key of ['performance', 'accessibility', 'best-practices', 'seo']) {
      for (const value of [undefined, null, '1', true, NaN, Infinity, -Infinity, -0.01, 1.01]) {
        const report = pair()[0]
        report.categories[key].score = value
        assert.equal(assess(report, 'mobile').pass, false, `${key}: ${String(value)}`)
      }
      for (const change of [r => { delete r.categories[key] }, r => { r.categories[key].auditRefs = [] }, r => { r.categories[key].auditRefs = [{ id: 'absent-audit' }] }]) {
        const report = pair()[0]
        change(report)
        assert.equal(assess(report, 'mobile').pass, false, key)
      }
    }
    const reports = pair()
    delete reports[1].categories.seo
    assert.equal(cli(component, reports).status, 1)
    const raw = JSON.stringify(pair()[0]).replace('"score":1', '"score":1e999')
    assert.equal(cli(component, [raw, JSON.stringify(pair()[1])], { raw: true }).status, 1)
  })

  test(`${component}: required metrics cannot be missing, invalid, errored or in the wrong unit`, () => {
    for (const id of metricIds) {
      for (const value of [undefined, null, '0', true, NaN, Infinity, -Infinity, -0.01]) {
        const report = pair()[0]
        report.audits[id].numericValue = value
        assert.equal(assess(report, 'mobile').pass, false, `${id}: ${String(value)}`)
      }
      for (const mutate of [r => { delete r.audits[id] }, r => { r.audits[id].score = null }, r => { r.audits[id].scoreDisplayMode = 'error' }, r => { r.audits[id].numericUnit = 'second' }]) {
        const report = pair()[0]
        mutate(report)
        assert.equal(assess(report, 'mobile').pass, false, id)
      }
    }
    const reports = pair()
    reports[0].audits['total-blocking-time'].numericValue = -1
    assert.equal(cli(component, reports).status, 1)
    const raw = JSON.stringify(pair()[0]).replace('"numericValue":1000', '"numericValue":1e999')
    assert.equal(cli(component, [raw, JSON.stringify(pair()[1])], { raw: true }).status, 1)
  })

  test(`${component}: declared URLs must identify the intended live page`, () => {
    for (const field of ['requestedUrl', 'mainDocumentUrl', 'finalDisplayedUrl', 'finalUrl']) {
      for (const value of [null, 'https://example.com/', `https://osgard.world/${component}/?preview=1`, 'https://osgard.world/login/', `http://osgard.world/${component}/`]) {
        const report = pair()[0]
        report[field] = value
        assert.equal(assess(report, 'mobile').pass, false, field)
      }
    }
    const reports = pair()
    reports[1].finalDisplayedUrl = 'https://osgard.world/login/'
    assert.equal(cli(component, reports).status, 1)
  })

  test(`${component}: another profile or incomplete diagnostic is not acceptance`, () => {
    const mutations = [
      r => { delete r.configSettings }, r => { r.configSettings.formFactor = 'desktop' },
      r => { r.configSettings.throttlingMethod = 'provided' }, r => { r.configSettings.throttling.cpuSlowdownMultiplier = 1 },
      r => { r.configSettings.screenEmulation.width = 1350 }, r => { r.configSettings.screenEmulation.disabled = true },
      r => { r.configSettings.emulatedUserAgent = 'desktop' }, r => { r.configSettings.disableStorageReset = true },
      r => { r.configSettings.auditMode = true }, r => { r.configSettings.gatherMode = true }, r => { r.configSettings.ignoreStatusCode = true },
      r => { r.configSettings.onlyCategories = ['performance'] }, r => { r.configSettings.onlyCategories = ['performance', 'performance', 'seo', 'accessibility'] },
      r => { r.configSettings.onlyAudits = ['first-contentful-paint'] }, r => { r.configSettings.skipAudits = ['is-on-https'] },
      r => { r.configSettings.blockedUrlPatterns = ['*.js'] }, r => { r.configSettings.additionalTraceCategories = 'disabled-by-default-v8.cpu_profiler' },
      r => { r.lighthouseVersion = '12.8.1' }, r => { r.gatherMode = 'snapshot' }, r => { r.fetchTime = 'not-a-time' },
    ]
    for (const mutate of mutations) {
      const report = pair()[0]
      mutate(report)
      assert.equal(assess(report, 'mobile').pass, false)
    }
    for (const mode of [undefined, 'phone', 'input-mobile.json', '__proto__']) assert.equal(assess(pair()[0], mode).pass, false)
    const reports = pair()
    reports[0].configSettings.screenEmulation.disabled = true
    assert.equal(cli(component, reports).status, 1)
  })

  test(`${component}: runtime and individual audit errors fail despite perfect category scores`, () => {
    for (const runtimeError of [{ code: 'NO_FCP' }, {}, false, 'error']) {
      const reports = pair()
      reports[0].runtimeError = runtimeError
      assert.equal(cli(component, reports).status, 1)
    }
    const report = pair()[0]
    report.audits['aria-valid-attr'].scoreDisplayMode = 'error'
    assert.equal(assess(report, 'mobile').pass, false)
    report.audits['aria-valid-attr'].scoreDisplayMode = 'binary'
    report.audits['aria-valid-attr'].errorMessage = 'Audit failed'
    assert.equal(assess(report, 'mobile').pass, false)
    report.audits['aria-valid-attr'].errorMessage = undefined
    report.runtimeError = null
    assert.equal(assess(report, 'mobile').pass, true)
  })
}

test('SkillCred preserves the existing displayed-score 100 requirement in all four categories', () => {
  for (const mode of ['mobile', 'desktop']) for (const key of ['performance', 'accessibility', 'best-practices', 'seo']) {
    const report = lighthouseFixture('skillcred', mode)
    report.categories[key].score = 0.99
    assert.equal(skillcred(report, mode).pass, false)
    report.categories[key].score = 0.995
    assert.equal(skillcred(report, mode).pass, true, 'Preserve the existing rounded category threshold')
  }
})

test('Games preserves every category and TBT/LCP boundary on both profiles', () => {
  for (const [mode, performance, tbt, lcp] of [['mobile', 0.85, 500, 4000], ['desktop', 0.9, 300, 3000]]) {
    const report = lighthouseFixture('games', mode)
    for (const key of ['performance', 'accessibility', 'best-practices', 'seo']) report.categories[key].score = key === 'performance' ? performance : 0.9
    report.audits['total-blocking-time'].numericValue = tbt
    report.audits['largest-contentful-paint'].numericValue = lcp
    assert.equal(games(report, mode).pass, true)
    for (const id of ['total-blocking-time', 'largest-contentful-paint']) {
      const changed = structuredClone(report)
      changed.audits[id].numericValue += 0.001
      assert.equal(games(changed, mode).pass, false)
    }
    for (const key of ['performance', 'accessibility', 'best-practices', 'seo']) {
      const changed = structuredClone(report)
      changed.categories[key].score -= 0.01
      assert.equal(games(changed, mode).pass, false)
    }
  }
})

test('Retained measured failures stay failures without changing the acceptance thresholds', () => {
  const evidence = JSON.parse(readFileSync(join(root, 'docs/evidence/lighthouse-current-2026-10-17.json'), 'utf8'))
  for (const component of evidence.audits) {
    const reports = component.audits.map(record => {
      const report = lighthouseFixture(component.component, record.viewport)
      for (const [key, score] of Object.entries(record.scores)) report.categories[key].score = score / 100
      for (const [id, key] of [['first-contentful-paint', 'firstContentfulPaintMs'], ['largest-contentful-paint', 'largestContentfulPaintMs'], ['speed-index', 'speedIndexMs'], ['total-blocking-time', 'totalBlockingTimeMs']]) report.audits[id].numericValue = record.modeledMetrics[key]
      report.audits['cumulative-layout-shift'].numericValue = record.observedMetrics.cumulativeLayoutShift
      assert.equal(validateReport(report, component.component, record.viewport).valid, true)
      return report
    })
    const result = cli(component.component, reports)
    assert.equal(result.status, 1)
    assert.match(result.output, component.component === 'skillcred' ? /70\/100[\s\S]*92\/100/ : /Total Blocking Time above guardrail/)
  }
})

test('Both deployment-triggered workflows preserve raw assets and use the deployed source revision', () => {
  for (const component of ['games', 'skillcred']) {
    const source = readFileSync(join(root, `.github/workflows/${component}-lighthouse.yml`), 'utf8')
    const navigationCommands = source.split('\n').filter(line => line.includes('run: npx --yes lighthouse@'))
    assert.equal(navigationCommands.length, 2)
    for (const command of navigationCommands) {
      assert.ok(command.includes('lighthouse@12.8.2'))
      assert.ok(command.includes('--save-assets'))
      assert.ok(command.includes('--only-categories=performance,accessibility,best-practices,seo'))
    }
    assert.ok(source.includes('ref: ${{ github.event.workflow_run.head_sha || github.sha }}'))
    assert.match(source, /if: always\(\)[\s\S]*uses: actions\/upload-artifact@v4/)
    assert.match(source, /path: \/tmp\/(?:osgard-games|skillcred)-lighthouse-\*\.json/)
  }
})
