import path from 'node:path'
import { pathToFileURL } from 'node:url'
import { categoryNames, readReportPair, validateReport } from './lighthouse-report-validation.mjs'

export function assessReport(json, mode) {
  const validation = validateReport(json, 'skillcred', mode)
  const issues = [...validation.issues]
  for (const [key, score] of Object.entries(validation.scores)) {
    if (score < 100) issues.push(`${categoryNames[key]} below requirement: ${score}/100 (required 100)`)
  }
  return { ...validation, issues, pass: issues.length === 0 }
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
  let failed = false
  for (const { report, mode } of pair) {
    const result = assessReport(report, mode)
    console.log(`\nLighthouse ${mode.toUpperCase()} — https://osgard.world/skillcred/`)
    for (const [key, title] of Object.entries(categoryNames)) {
      console.log('  ' + title + ': ' + (result.scores[key] === undefined ? 'not valid' : result.scores[key] + '/100'))
    }
    console.log('Core Web Vitals diagnostics:')
    for (const [id, value] of Object.entries(result.metrics)) console.log(`  ${id}: ${value}`)
    for (const issue of result.issues) console.error('  REQUIREMENT: ' + issue)
    if (!result.pass) failed = true
  }
  console.log('\nLighthouse four-category mobile/desktop gate: ' + (failed ? 'FAIL' : 'PASS'))
  if (failed) process.exitCode = 1
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main(process.argv.slice(2))
}
