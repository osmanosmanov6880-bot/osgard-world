import fs from 'node:fs'

export const categoryNames = {
  performance: 'Performance',
  accessibility: 'Accessibility',
  'best-practices': 'Best Practices',
  seo: 'SEO',
}

const metricUnits = {
  'first-contentful-paint': 'millisecond',
  'largest-contentful-paint': 'millisecond',
  'speed-index': 'millisecond',
  'total-blocking-time': 'millisecond',
  'cumulative-layout-shift': 'unitless',
}

// The workflows pin Lighthouse 12.8.2. These are its actual mobile/default and
// desktop preset values, also retained in the 2026-10-17 report/trace evidence.
// A version or measurement-profile change must be reviewed with these checks.
const profiles = {
  mobile: {
    screenEmulation: { mobile: true, width: 412, height: 823, deviceScaleFactor: 1.75, disabled: false },
    throttling: { rttMs: 150, throughputKbps: 1638.4, requestLatencyMs: 562.5, downloadThroughputKbps: 1474.5600000000002, uploadThroughputKbps: 675, cpuSlowdownMultiplier: 4 },
    emulatedUserAgent: 'Mozilla/5.0 (Linux; Android 11; moto g power (2022)) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Mobile Safari/537.36',
  },
  desktop: {
    screenEmulation: { mobile: false, width: 1350, height: 940, deviceScaleFactor: 1, disabled: false },
    throttling: { rttMs: 40, throughputKbps: 10240, requestLatencyMs: 0, downloadThroughputKbps: 0, uploadThroughputKbps: 0, cpuSlowdownMultiplier: 1 },
    emulatedUserAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36',
  },
}

const isObject = value => value !== null && typeof value === 'object' && !Array.isArray(value)
const isScore = value => Number.isFinite(value) && value >= 0 && value <= 1
const isEmptyOption = value => value === null || (Array.isArray(value) && value.length === 0)

export function validateReport(report, page, mode) {
  const issues = []
  const scores = {}
  const metrics = {}
  const result = () => ({ issues, scores, metrics, valid: issues.length === 0 })
  if (!['skillcred', 'games'].includes(page) || !['mobile', 'desktop'].includes(mode)) {
    issues.push('Unknown expected Lighthouse page or profile')
    return result()
  }
  if (!isObject(report)) {
    issues.push('Expected a Lighthouse report object')
    return result()
  }

  const expectedUrl = `https://osgard.world/${page}/`
  for (const key of ['requestedUrl', 'mainDocumentUrl', 'finalDisplayedUrl']) {
    if (report[key] !== expectedUrl) issues.push(`${key}: expected ${expectedUrl}`)
  }
  if (report.finalUrl !== undefined && report.finalUrl !== expectedUrl) issues.push('finalUrl: unexpected audited URL')
  if (report.lighthouseVersion !== '12.8.2') issues.push('Expected the pinned Lighthouse 12.8.2 report')
  if (report.gatherMode !== 'navigation') issues.push('Expected a navigation report')
  if (typeof report.fetchTime !== 'string' || !Number.isFinite(Date.parse(report.fetchTime))) issues.push('Missing or invalid fetchTime')
  if (report.runtimeError !== undefined && report.runtimeError !== null) issues.push('Lighthouse runtimeError is present')

  const config = isObject(report.configSettings) ? report.configSettings : {}
  const expected = profiles[mode]
  for (const [key, value] of Object.entries({ formFactor: mode, throttlingMethod: 'simulate', emulatedUserAgent: expected.emulatedUserAgent, disableStorageReset: false, auditMode: false, gatherMode: false, ignoreStatusCode: false })) {
    if (config[key] !== value) issues.push(`configSettings.${key}: unexpected ${mode} measurement profile`)
  }
  for (const key of ['screenEmulation', 'throttling']) {
    for (const [field, value] of Object.entries(expected[key])) {
      if (config[key]?.[field] !== value) issues.push(`configSettings.${key}.${field}: unexpected ${mode} measurement profile`)
    }
  }
  const categories = Object.keys(categoryNames)
  if (!Array.isArray(config.onlyCategories) || config.onlyCategories.length !== categories.length || categories.some(key => !config.onlyCategories.includes(key))) {
    issues.push('Expected all four categories in the measurement configuration')
  }
  for (const key of ['onlyAudits', 'skipAudits', 'blockedUrlPatterns', 'additionalTraceCategories']) {
    if (!isEmptyOption(config[key])) issues.push(`configSettings.${key}: acceptance requires the normal complete audit`)
  }

  const audits = isObject(report.audits) ? report.audits : {}
  for (const [key, title] of Object.entries(categoryNames)) {
    const category = report.categories?.[key]
    if (!isObject(category) || !isScore(category.score)) issues.push(`${title}: expected a finite category score between 0 and 1`)
    else scores[key] = Math.round(category.score * 100)
    if (category?.id !== key || !Array.isArray(category.auditRefs) || category.auditRefs.length === 0) {
      issues.push(`${title}: missing category audit references`)
    } else {
      for (const ref of category.auditRefs) {
        if (!isObject(ref) || typeof ref.id !== 'string' || !isObject(audits[ref.id])) issues.push(`${title}: referenced audit is missing`)
      }
    }
  }
  for (const [id, unit] of Object.entries(metricUnits)) {
    const audit = audits[id]
    if (!isObject(audit) || !Number.isFinite(audit.numericValue) || audit.numericValue < 0) {
      issues.push(`${id}: expected a finite non-negative metric`)
    } else metrics[id] = audit.numericValue
    if (audit?.id !== id || audit.scoreDisplayMode !== 'numeric' || !isScore(audit.score) || audit.numericUnit !== unit) {
      issues.push(`${id}: incomplete or invalid scored metric`)
    }
  }
  for (const [id, audit] of Object.entries(audits)) {
    if (isObject(audit) && (audit.scoreDisplayMode === 'error' || audit.errorMessage != null)) issues.push(`${id}: Lighthouse audit error`)
  }
  return result()
}

export function readReportPair(paths) {
  if (paths.length !== 2) throw new Error('Pass exactly two reports: <mobile-report.json> <desktop-report.json>')
  // Argument position is the expected profile; filenames never choose a budget.
  return paths.map((file, index) => ({ report: JSON.parse(fs.readFileSync(file, 'utf8')), mode: index === 0 ? 'mobile' : 'desktop' }))
}
