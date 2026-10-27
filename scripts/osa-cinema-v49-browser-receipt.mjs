/** Convert successful REAL Playwright JSON into evidence; never run on skipped/failed tests. */
import { readFileSync, writeFileSync } from 'node:fs'
import assert from 'node:assert/strict'
const [input,output]=process.argv.slice(2)
assert.ok(input && output,'playwright JSON input and proof output required')
const report=JSON.parse(readFileSync(input,'utf8'))
const stats=report.stats
assert.ok(stats && stats.expected===2 && stats.unexpected===0 && stats.skipped===0 && stats.flaky===0,
  'real desktop + mobile tests must have exactly two PASS with no failure/skip')
const source=process.env.OSA_V49_SOURCE_SHA||''
assert.match(source,/^[0-9a-f]{40}$/,'exact checked-out production source SHA required')
const proof={schemaVersion:1,project:'OSA CINEMA',status:'PUBLIC_BROWSER_PLAYBACK_PASS',
  baseUrl:'https://osgard.world/osa-cinema/premiere/',sourceSha:source,
  checks:{desktopPlayback:true,mobilePlayback:true,seek:true,languageSwitch:true,captions:true,trailer:true},
  evidence:'Two Playwright browser tests passed in GitHub Actions against the real public origin; verify runner logs and URL independently.',
  generatedUtc:new Date().toISOString()}
writeFileSync(output,JSON.stringify(proof,null,2)+'\n',{flag:'wx',mode:0o600})
console.log('PASS OSA V49 browser receipt; actual public origin tested in GitHub Actions')
