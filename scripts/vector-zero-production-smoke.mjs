#!/usr/bin/env node
/** Compare deployed VECTOR//ZERO runtime with the actual packaged release.
 * This performs no payments and does not send or receive player data.
 */
import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { readFile } from 'node:fs/promises'
import { createServer } from 'node:http'

const ENTRY = '/games/vector-zero/'
const hex = source => createHash('sha256').update(source).digest('hex')
function gameSource(html) {
  const scripts = [...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script\s*>/gi)]
  const runtime = scripts.map(match => match[1]).find(script => script.includes('function step(dt)') && script.includes('osgard:game-lifecycle'))
  assert.ok(runtime, 'VECTOR//ZERO executable runtime must be present, not a fallback page')
  assert.ok(runtime.includes('function queueJump()'), 'Buffered-jump gameplay must be included')
  assert.ok(runtime.includes('pollGamepad()'), 'Gamepad gameplay must be included')
  return runtime
}
async function check(origin, expectedHtml, nonce = String(Date.now())) {
  const expectedRuntime = gameSource(expectedHtml)
  const endpoint = new URL(ENTRY, origin)
  endpoint.searchParams.set('vector_release', nonce)
  const response = await fetch(endpoint, {
    headers: { 'cache-control': 'no-cache', pragma: 'no-cache', 'user-agent': 'OSGARD-VECTOR-ZERO-Release-Verification/1.0' },
    redirect: 'follow', signal: AbortSignal.timeout(20000),
  })
  assert.equal(response.status, 200, 'VECTOR//ZERO release route must return 200')
  assert.match(response.headers.get('content-type') || '', /text\/html/i, 'VECTOR//ZERO must be served as HTML')
  const publishedHtml = await response.text()
  const publishedRuntime = gameSource(publishedHtml)
  assert.equal(hex(publishedRuntime), hex(expectedRuntime), 'Published gameplay differs from the candidate release; stale or wrong asset')
  return { route: endpoint.pathname, status: response.status, runtimeSha256: hex(publishedRuntime), bytes: publishedRuntime.length }
}
if (process.argv[2] === '--self-test') {
  const expectedHtml = await readFile('public/games/vector-zero/index.html', 'utf8')
  let served = expectedHtml
  const server = createServer((request, response) => {
    response.writeHead(200, { 'content-type': 'text/html; charset=utf-8' })
    response.end(served)
  })
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve))
  try {
    const port = server.address().port
    const origin = 'http://127.0.0.1:' + port
    await check(origin, expectedHtml, 'good')
    served = expectedHtml.replace('function queueJump()', 'function bogusJump()')
    await assert.rejects(() => check(origin, expectedHtml, 'bad'), /Buffered-jump gameplay|Published gameplay differs/)
    served = '<!doctype html><title>Outdated fallback</title>'
    await assert.rejects(() => check(origin, expectedHtml, 'missing'), /executable runtime must be present/)
    console.log('PASS: exact gameplay runtime, changed runtime and fallback routes verified')
  } finally {
    await new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve()))
  }
} else {
  const origin = process.env.OSGARD_BASE_URL
  assert.ok(origin, 'Set OSGARD_BASE_URL before checking the published game')
  const root = process.argv[2] || 'osgard-release/html'
  const expectedHtml = await readFile(root + ENTRY + 'index.html', 'utf8')
  const result = await check(origin, expectedHtml, process.env.GITHUB_SHA?.slice(0, 12) || String(Date.now()))
  console.log(JSON.stringify({ status: 'PASS', result }, null, 2))
}
