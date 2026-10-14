const base = (process.env.OSGARD_BASE_URL || 'https://osgard.world').replace(/\/+$/, '')
const timeoutMs = 12000
const headers = {
  'user-agent': 'OSGARD-Production-Health-Watch/1.0',
  'cache-control': 'no-cache',
  pragma: 'no-cache',
}
const checks = []
let homeHtml = ''

async function check(name, run) {
  const started = Date.now()
  try {
    const detail = await run()
    checks.push({ name, status: 'pass', durationMs: Date.now() - started, detail })
  } catch (error) {
    checks.push({
      name,
      status: 'fail',
      durationMs: Date.now() - started,
      error: error instanceof Error ? error.message : 'Unknown probe error',
    })
  }
}

async function get(path) {
  const url = new URL(path, base)
  if (path === '/') url.searchParams.set('health_probe', String(Date.now()))
  const response = await fetch(url, {
    headers,
    redirect: 'follow',
    signal: AbortSignal.timeout(timeoutMs),
  })
  const body = await response.text()
  return { response, body, url: url.toString() }
}

function expect(condition, message) {
  if (!condition) throw new Error(message)
}

await check('OSA homepage HTML and cache policy', async () => {
  const { response, body } = await get('/')
  homeHtml = body
  expect(response.status === 200, `expected HTTP 200, got ${response.status}`)
  expect((response.headers.get('content-type') || '').includes('text/html'), 'response is not HTML')
  const title = body.match(/<title[^>]*>(.*?)<\\/title>/i)?.[1]?.trim() || 'no <title> tag'\n  expect(title.toLowerCase().includes('osa intelligence'), `expected OSA Intelligence title, got "${title}" from ${response.url}; prefix=${body.slice(0, 220).replace(/\\s+/g, ' ')}`)
  expect(/<script[^>]+src="\/assets\/index-[A-Za-z0-9_-]+\.js"/i.test(body), 'hashed application bundle is missing')
  const cache = (response.headers.get('cache-control') || '').toLowerCase()
  expect(cache.includes('no-store') && cache.includes('no-cache'), `homepage cache policy is unsafe: ${cache || 'missing'}`)
  return { statusCode: response.status, cacheControl: cache }
})

await check('Live OSA JavaScript bundle', async () => {
  expect(homeHtml.length > 0, 'homepage HTML was not available')
  const path = homeHtml.match(/<script[^>]+src="([^"]+\.js)"[^>]*><\/script>/i)?.[1]
  expect(path && path.startsWith('/assets/'), 'could not resolve the same-origin homepage bundle')
  const { response, body } = await get(path)
  expect(response.status === 200, `bundle returned HTTP ${response.status}`)
  expect(body.includes('OSA INTELLIGENCE / BEYOND THE MODEL'), `expected OSA bundle marker is missing in ${path}; HTTP ${response.status}; bytes=${new TextEncoder().encode(body).byteLength}; prefix=${body.slice(0, 220).replace(/\\s+/g, ' ')}`)
  return { statusCode: response.status, bundle: path, bytes: new TextEncoder().encode(body).byteLength }
})

for (const path of ['/academy', '/osa-cinema', '/portal', '/games/', '/skillcred/']) {
  await check(`Public route ${path}`, async () => {
    const { response, body } = await get(path)
    expect(response.status === 200, `expected HTTP 200, got ${response.status}`)
    expect(body.length > 100, 'response body unexpectedly small')
    return { statusCode: response.status, bytes: new TextEncoder().encode(body).byteLength }
  })
}

await check('SkillCred API health', async () => {
  const { response, body } = await get('/skillcred-api/health')
  expect(response.status === 200, `expected HTTP 200, got ${response.status}`)
  const value = JSON.parse(body)
  expect(value.service === 'skillcred', 'unexpected service identity')
  expect(value.version === '0.3.0', 'unexpected SkillCred API version')
  return { statusCode: response.status, service: value.service, version: value.version }
})

await check('SkillCred API readiness', async () => {
  const { response, body } = await get('/skillcred-api/ready')
  expect(response.status === 200, `expected HTTP 200, got ${response.status}`)
  const value = JSON.parse(body)
  expect(value.ready === true, 'API did not report ready=true')
  return { statusCode: response.status, ready: value.ready }
})

await check('Protected OSGARD API proxy', async () => {
  const { response, body } = await get('/api/v1/player/profile')
  expect([401, 403].includes(response.status), `expected auth-gated HTTP 401/403, got ${response.status} (proxy or API may be down)`)
  expect((response.headers.get('content-type') || '').toLowerCase().includes('application/json'), 'protected endpoint did not return JSON')
  JSON.parse(body)
  return { statusCode: response.status, authorization: 'correctly required' }
})

const failed = checks.filter(item => item.status === 'fail')
const report = {
  status: failed.length === 0 ? 'PASS' : 'FAIL',
  base,
  checkedAt: new Date().toISOString(),
  passed: checks.length - failed.length,
  failed: failed.length,
  total: checks.length,
  checks,
}
console.log(JSON.stringify(report, null, 2))
if (failed.length) process.exitCode = 1
