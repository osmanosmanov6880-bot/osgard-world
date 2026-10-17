// Small, synthetic acceptance fixtures using the shape and unchanged profiles of
// the retained Lighthouse 12.8.2 reports from runs 39032711133 and 39032711146.
// Scores/metrics are chosen by tests; these fixtures are not measured evidence.
export function lighthouseFixture(page = 'skillcred', mode = 'mobile') {
  const mobile = mode === 'mobile'
  const metrics = {
    'first-contentful-paint': 1000,
    'largest-contentful-paint': 1500,
    'speed-index': 1200,
    'total-blocking-time': 0,
    'cumulative-layout-shift': 0,
  }
  const audits = Object.fromEntries(Object.entries(metrics).map(([id, numericValue]) => [id, {
    id, score: 1, scoreDisplayMode: 'numeric', numericValue,
    numericUnit: id === 'cumulative-layout-shift' ? 'unitless' : 'millisecond',
  }]))
  for (const id of ['aria-valid-attr', 'errors-in-console', 'document-title']) audits[id] = { id, score: 1, scoreDisplayMode: 'binary' }
  const refs = { performance: Object.keys(metrics), accessibility: ['aria-valid-attr'], 'best-practices': ['errors-in-console'], seo: ['document-title'] }
  const url = `https://osgard.world/${page}/`
  return {
    lighthouseVersion: '12.8.2', requestedUrl: url, mainDocumentUrl: url, finalDisplayedUrl: url, finalUrl: url,
    fetchTime: mobile ? '2026-10-17T12:29:59.093Z' : '2026-10-17T12:30:14.773Z', gatherMode: 'navigation', runWarnings: [],
    configSettings: {
      formFactor: mode, throttlingMethod: 'simulate',
      throttling: mobile
        ? { rttMs: 150, throughputKbps: 1638.4, requestLatencyMs: 562.5, downloadThroughputKbps: 1474.5600000000002, uploadThroughputKbps: 675, cpuSlowdownMultiplier: 4 }
        : { rttMs: 40, throughputKbps: 10240, requestLatencyMs: 0, downloadThroughputKbps: 0, uploadThroughputKbps: 0, cpuSlowdownMultiplier: 1 },
      screenEmulation: mobile
        ? { mobile: true, width: 412, height: 823, deviceScaleFactor: 1.75, disabled: false }
        : { mobile: false, width: 1350, height: 940, deviceScaleFactor: 1, disabled: false },
      emulatedUserAgent: mobile
        ? 'Mozilla/5.0 (Linux; Android 11; moto g power (2022)) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Mobile Safari/537.36'
        : 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36',
      disableStorageReset: false, auditMode: false, gatherMode: false, ignoreStatusCode: false,
      onlyCategories: ['performance', 'accessibility', 'best-practices', 'seo'],
      onlyAudits: null, skipAudits: null, blockedUrlPatterns: null, additionalTraceCategories: null,
    },
    categories: Object.fromEntries(Object.entries(refs).map(([id, ids]) => [id, { id, score: 1, auditRefs: ids.map(id => ({ id, weight: 1 })) }])),
    audits,
  }
}
