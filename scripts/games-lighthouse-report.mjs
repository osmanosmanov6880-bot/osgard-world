import path from 'node:path'
import { pathToFileURL } from 'node:url'
import { categoryNames, readReportPair, validateReport } from './lighthouse-report-validation.mjs'

const guardrails = {
  mobile: {
    performance: 85,
    accessibility: 90,
    'best-practices': 90,
    seo: 90,
    maxTbtMs: 500,
    maxLcpMs: 4000,
  },
  desktop: {
    performance: 90,
    accessibility: 90,
    'best-practices': 90,
    seo: 90,
    maxTbtMs: 300,
    maxLcpMs: 3000,
  },
}

export function assessReport(json, mode) {
  const limits = guardrails[mode]
  const validation = validateReport(json, 'games', mode)
  const issues = [...validation.issues]
  const scores = validation.scores

  for (const [key, name] of Object.entries(categoryNames)) {
    const score = scores[key]
    if (limits && score !== undefined && score < limits[key]) issues.push(name + ' below guardrail: ' + score + '/100 (minimum ' + limits[key] + ')')
  }

  const tbtMs = validation.metrics['total-blocking-time'] ?? null
  const lcpMs = validation.metrics['largest-contentful-paint'] ?? null

  if (limits && tbtMs !== null && tbtMs > limits.maxTbtMs) issues.push('Total Blocking Time above guardrail: ' + Math.round(tbtMs) + ' ms (maximum ' + limits.maxTbtMs + ' ms)')

  if (limits && lcpMs !== null && lcpMs > limits.maxLcpMs) issues.push('Largest Contentful Paint above guardrail: ' + (lcpMs / 1000).toFixed(2) + ' s (maximum ' + (limits.maxLcpMs / 1000).toFixed(1) + ' s)')

  return {
    label: typeof mode === 'string' ? mode.toUpperCase() : 'UNKNOWN',
    url: 'https://osgard.world/games/',
    scores,
    tbtMs,
    lcpMs,
    issues,
    pass: issues.length === 0,
  }
}

function main(paths) {
  let pair
  try {
    pair = readReportPair(paths)
  } catch (error) {
    console.error('Lighthouse report input: ' + error.message)
    process.exitCode = 2
    return
  }

  const results = pair.map(({ report, mode }) => assessReport(report, mode))

  for (const result of results) {
    console.log('\nOSGARD GAMES Lighthouse ' + result.label + ' — ' + result.url)
    for (const [key, title] of Object.entries(categoryNames)) {
      console.log('  ' + title + ': ' + (result.scores[key] === undefined ? 'not reported' : result.scores[key] + '/100'))
    }
    console.log('  Total Blocking Time: ' + (result.tbtMs === null ? 'not reported' : Math.round(result.tbtMs) + ' ms'))
    console.log('  Largest Contentful Paint: ' + (result.lcpMs === null ? 'not reported' : (result.lcpMs / 1000).toFixed(2) + ' s'))
    if (result.issues.length) {
      for (const issue of result.issues) console.error('  GUARDRAIL: ' + issue)
    } else {
      console.log('  Guardrails: PASS')
    }
  }

  const failed = results.filter(result => !result.pass)
  console.log('\nOSGARD GAMES Lighthouse guardrails: ' + (failed.length ? 'FAIL' : 'PASS'))
  if (failed.length) process.exitCode = 1
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main(process.argv.slice(2))
}
