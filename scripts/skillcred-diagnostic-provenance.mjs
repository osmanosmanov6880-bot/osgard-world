import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { execFileSync } from 'node:child_process'
import { readFileSync, writeFileSync } from 'node:fs'
import { resolve, join } from 'node:path'

const ORIGIN = 'https://osgard.world'
const PAGE = `${ORIGIN}/skillcred/`
const VERSION = '12.8.2'
const hash = bytes => createHash('sha256').update(bytes).digest('hex')
const load = file => JSON.parse(readFileSync(file, 'utf8'))
const save = (file, value) => writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`)

async function resource(path, contentType) {
  const url = new URL(path, ORIGIN)
  assert.equal(url.origin, ORIGIN, 'Diagnostic resources must be same-origin')
  const response = await fetch(url, {
    headers: { Accept: contentType === 'javascript' ? 'application/javascript, text/javascript' : contentType, 'Cache-Control': 'no-cache' },
    redirect: 'error',
    signal: AbortSignal.timeout(15000),
  })
  assert.equal(response.status, 200, `${url.pathname}: expected HTTP 200`)
  const kind = response.headers.get('content-type') || ''
  assert.ok(kind.includes(contentType), `${url.pathname}: unexpected MIME ${kind}`)
  const bytes = Buffer.from(await response.arrayBuffer())
  assert.ok(bytes.length > 0 && bytes.length <= 512 * 1024, 'Unexpected diagnostic asset size')
  return {
    evidence: { url: url.href, contentType: kind, decodedBytes: bytes.length, sha256: hash(bytes) },
    text: bytes.toString('utf8'),
  }
}

async function capture(file) {
  const chromePath = process.env.CHROME_PATH
  assert.ok(chromePath, 'CHROME_PATH must identify the fixed CI browser')
  const chromeVersion = execFileSync(chromePath, ['--version'], { encoding: 'utf8', timeout: 10000 }).trim()
  const chromeNumber = chromeVersion.match(/\b\d+\.\d+\.\d+\.\d+\b/)?.[0]
  assert.ok(chromeNumber, 'Cannot identify the actual Chrome version')
  const page = await resource('/skillcred/', 'text/html')
  const links = [...page.text.matchAll(/(?:href|src)="(\/(?:skillcred\/(?:styles\.css|app\.js)|brand\/osa-transition\.js)\?v=([0-9a-f]{12}))"/g)]
  assert.equal(links.length, 3, 'Expected three known versioned SkillCred/brand resources')
  const markers = [...new Set(links.map(match => match[2]))]
  assert.equal(markers.length, 1, 'Published resource versions differ')
  const release = markers[0]
  const expected = process.env.SKILLCRED_EXPECTED_RELEASE || ''
  if (expected) {
    assert.match(expected, /^(?:[0-9a-f]{12}|[0-9a-f]{40})$/, 'Invalid expected release SHA')
    assert.equal(release, expected.slice(0, 12), 'A different product release is published')
  }
  const paths = [...new Set(links.map(match => match[1]))].sort()
  assert.equal(paths.length, 3, 'Repeated resource linkage is not a valid capture')
  const assets = await Promise.all(paths.map(path => resource(path, path.includes('.css?') ? 'text/css' : 'javascript')))
  const result = {
    schemaVersion: 1,
    capturedAt: new Date().toISOString(),
    page: PAGE,
    release,
    chrome: { path: chromePath, version: chromeVersion, number: chromeNumber },
    nodeVersion: process.version,
    lighthouseVersion: VERSION,
    ci: Object.fromEntries(['GITHUB_SHA', 'GITHUB_HEAD_REF', 'GITHUB_RUN_ID', 'GITHUB_RUN_ATTEMPT', 'ImageOS', 'ImageVersion'].map(key => [key, process.env[key] || null])),
    assets: [page.evidence, ...assets.map(item => item.evidence)],
  }
  save(file, result)
  process.stdout.write(`Captured published ${release}; Chrome ${chromeNumber}; ${result.assets.length} resources\n`)
}

function reportedChromeVersion(userAgent, binaryVersion, label) {
  const reported = userAgent?.match(/(?:HeadlessChrome|Chrome)\/(\d+\.\d+\.\d+\.\d+)/)?.[1]
  const reduced = `${binaryVersion.split('.')[0]}.0.0.0`
  assert.ok(reported && (reported === binaryVersion || reported === reduced), `${label}: Lighthouse Chrome version does not match the captured browser`)
  return { reported, reduced: reported !== binaryVersion }
}

function diagnosticSettings(config, name) {
  const { additionalTraceCategories, ...common } = config
  const categories = additionalTraceCategories == null ? [] : Array.isArray(additionalTraceCategories)
    ? additionalTraceCategories : additionalTraceCategories.split(',')
  assert.deepEqual(categories, name === 'sampled' ? ['disabled-by-default-v8.cpu_profiler'] : [], `${name}: unexpected profiler configuration`)
  return { common, categories }
}

function verify(directory) {
  const before = load(join(directory, 'before.json'))
  const after = load(join(directory, 'after.json'))
  assert.equal(before.page, PAGE)
  assert.equal(after.page, PAGE)
  assert.equal(before.release, after.release, 'The public release changed during profiling')
  assert.deepEqual(before.assets, after.assets, 'Published bytes changed during profiling')
  assert.deepEqual(before.chrome, after.chrome, 'Chrome changed between diagnostic captures')
  assert.deepEqual(before.ci, after.ci, 'CI context changed between captures')
  const versioned = before.assets.slice(1).map(item => item.url)
  let commonSettings
  const profiles = ['normal', 'sampled'].map(name => {
    const reportPath = join(directory, `${name}.json`)
    const logPath = join(directory, `${name}-0.devtoolslog.json`)
    const report = load(reportPath)
    const log = load(logPath)
    assert.equal(report.lighthouseVersion, VERSION, `${name}: Lighthouse version changed`)
    assert.equal(report.finalDisplayedUrl, PAGE, `${name}: unexpected page`)
    assert.equal(report.configSettings.formFactor, 'mobile', `${name}: expected the mobile profile`)
    assert.ok(!report.runtimeError, `${name}: Lighthouse runtime error`)
    const chrome = reportedChromeVersion(report.environment.hostUserAgent, before.chrome.number, name)
    const settings = diagnosticSettings(report.configSettings, name)
    if (commonSettings) assert.deepEqual(settings.common, commonSettings, 'Diagnostic settings differ beyond the explicitly added profiler category')
    else commonSettings = settings.common
    const requests = report.audits['network-requests']?.details?.items
    assert.ok(Array.isArray(requests) && requests.length, `${name}: missing request evidence`)
    for (const url of versioned) assert.ok(requests.some(item => item.url === url && item.statusCode === 200), `${name}: missing current resource ${url}`)
    const methods = {}
    let publicRequests = 0
    for (const event of log) {
      if (event.method !== 'Network.requestWillBeSent') continue
      const request = event.params?.request
      if (!request || !request.url.startsWith(`${ORIGIN}/`)) continue
      assert.ok(['GET', 'HEAD'].includes(request.method), `${name}: public diagnostic made a non-read request`)
      assert.ok(!new URL(request.url).pathname.startsWith('/skillcred-api/'), `${name}: unexpected automatic demo API request`)
      methods[request.method] = (methods[request.method] || 0) + 1
      publicRequests++
    }
    assert.ok(publicRequests > 0, `${name}: no public requests in DevTools log`)
    return {
      name,
      instrumented: name === 'sampled',
      reportSha256: hash(readFileSync(reportPath)),
      devtoolsLogSha256: hash(readFileSync(logPath)),
      fetchTime: report.fetchTime,
      hostUserAgent: report.environment.hostUserAgent,
      reportedChromeVersion: chrome.reported,
      userAgentVersionReduced: chrome.reduced,
      additionalTraceCategories: settings.categories,
      benchmarkIndex: report.environment.benchmarkIndex,
      requestCount: requests.length,
      methods,
      runWarnings: report.runWarnings || [],
      acceptanceResult: null,
    }
  })
  assert.equal(profiles[0].hostUserAgent, profiles[1].hostUserAgent)
  const result = {
    schemaVersion: 1,
    status: 'consistent_diagnostic_capture',
    purpose: 'Locate actual startup work; sampling overhead and diagnostic scores are not release acceptance.',
    release: before.release,
    chrome: before.chrome,
    commonSettings,
    profiles,
    acceptanceGate: 'The separate post-deployment audit still requires 100 in all four categories on mobile and desktop.',
  }
  save(join(directory, 'provenance.json'), result)
  process.stdout.write(`Verified normal and sampled captures of ${before.release} with one Chrome version\n`)
}

const [mode, target] = process.argv.slice(2)
if (mode === '--self-test' && !target) {
  assert.deepEqual(reportedChromeVersion('HeadlessChrome/155.0.0.0 Safari/537.36', '155.0.8050.40', 'reduced'), { reported: '155.0.0.0', reduced: true })
  assert.equal(reportedChromeVersion('Chrome/155.0.8050.40', '155.0.8050.40', 'full').reduced, false)
  assert.throws(() => reportedChromeVersion('HeadlessChrome/154.0.0.0', '155.0.8050.40', 'wrong major'))
  assert.throws(() => reportedChromeVersion('HeadlessChrome/155.0.8050.41', '155.0.8050.40', 'wrong full version'))
  assert.deepEqual(diagnosticSettings({ formFactor: 'mobile', additionalTraceCategories: null }, 'normal').common,
    diagnosticSettings({ formFactor: 'mobile', additionalTraceCategories: 'disabled-by-default-v8.cpu_profiler' }, 'sampled').common)
  assert.throws(() => diagnosticSettings({ additionalTraceCategories: null }, 'sampled'))
  assert.throws(() => diagnosticSettings({ additionalTraceCategories: 'disabled-by-default-v8.cpu_profiler,extra' }, 'sampled'))
  process.stdout.write('SkillCred provenance: reduced/full Chrome versions and explicit profiler configuration passed.\n')
} else {
  assert.ok(target && ['capture', 'verify'].includes(mode), 'Usage: skillcred-diagnostic-provenance.mjs capture FILE.json | verify DIRECTORY | --self-test')
  if (mode === 'capture') await capture(resolve(target))
  else verify(resolve(target))
}
