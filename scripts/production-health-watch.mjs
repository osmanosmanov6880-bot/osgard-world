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

function responseDiagnostics(response) {
  const names = ['content-type', 'cache-control', 'age', 'via', 'server', 'etag', 'last-modified', 'x-cache', 'cf-cache-status', 'x-served-by']
  return Object.fromEntries(names.map(name => [name, response.headers.get(name)]).filter(([, value]) => value))
}

await check('OSGARD/OSA homepage identity, cache policy, and backend consistency', async () => {
  const probes = []
  for (let index = 0; index < 3; index++) {
    const { response, body } = await get('/')
    const title = body.match(/<title[^>]*>(.*?)<\/title>/i)?.[1]?.trim() || 'no <title> tag'
    const appId = body.match(/<meta\s+name=["']osgard-app["']\s+content=["']([^"']+)["']/i)?.[1] || 'missing'
    const headers = responseDiagnostics(response)
    const cache = (headers['cache-control'] || '').toLowerCase()
    probes.push({
      attempt: index + 1,
      statusCode: response.status,
      url: response.url,
      title,
      appId,
      cacheControl: cache || null,
      headers,
    })
    if (index === 0) homeHtml = body
  }

  const invalid = probes.filter(probe =>
    probe.statusCode !== 200 ||
    !String(probe.headers['content-type'] || '').toLowerCase().includes('text/html') ||
    !(probe.title.toLowerCase().includes('osa intelligence') || probe.title.toLowerCase().includes('osgard world')) ||
    (probe.title.toLowerCase().includes('osa intelligence') && probe.appId !== 'osa-intelligence') ||
    (probe.title.toLowerCase().includes('osgard world') && probe.appId !== 'osgard-ecosystem') ||
    !probe.cacheControl?.includes('no-store') ||
    !probe.cacheControl?.includes('no-cache')
  )
  expect(invalid.length === 0, `expected 3 consistent OSGARD homepage responses; invalid=${JSON.stringify(invalid)}; all=${JSON.stringify(probes)}`)
  return {
    statusCode: probes[0].statusCode,
    cacheControl: probes[0].cacheControl,
    probes: probes.map(({ attempt, statusCode, title, appId, cacheControl, headers }) => ({ attempt, statusCode, title, appId, cacheControl, edge: { age: headers.age, via: headers.via, server: headers.server, xCache: headers['x-cache'], cfCacheStatus: headers['cf-cache-status'], xServedBy: headers['x-served-by'], etag: headers.etag } })),
  }
})

await check('Live homepage JavaScript entry bundle', async () => {
  expect(homeHtml.length > 0, 'homepage HTML was not available')
  const path = homeHtml.match(/<script[^>]+src="([^"]+\.js)"[^>]*><\/script>/i)?.[1]
  expect(path && path.startsWith('/assets/'), 'could not resolve the same-origin homepage bundle')
  const { response, body } = await get(path)
  expect(response.status === 200, `bundle returned HTTP ${response.status}`)
  expect(body.length > 10000 && body.includes('__vite__mapDeps'), `homepage entry bundle is unexpectedly small or missing the Vite dependency map in ${path}; HTTP ${response.status}; headers=${JSON.stringify(responseDiagnostics(response))}; bytes=${new TextEncoder().encode(body).byteLength}; prefix=${body.slice(0, 220).replace(/\\s+/g, ' ')}`)
  return { statusCode: response.status, bundle: path, bytes: new TextEncoder().encode(body).byteLength }
})

const merakkiLocales = [
 {path:'/development/merakki/',locale:'ru',title:'MERAKKI GLOBAL — кейс OSGARD Development',canonical:'https://osgard.world/development/merakki/',language:'ru'},
 {path:'/development/merakki/en/',locale:'en',title:'MERAKKI GLOBAL — OSGARD Development case',canonical:'https://osgard.world/development/merakki/en/',language:'en'},
 {path:'/development/merakki/ar/',locale:'ar',title:'MERAKKI GLOBAL — دراسة حالة OSGARD Development',canonical:'https://osgard.world/development/merakki/ar/',language:'ar'}
]
for(const item of merakkiLocales){
 await check('MERAKKI public case '+item.locale.toUpperCase(),async()=>{
  const {response,body}=await get(item.path),type=(response.headers.get('content-type')||'').toLowerCase()
  expect(response.status===200,item.path+' returned HTTP '+response.status)
  expect(type.includes('text/html'),item.path+' is not HTML')
  expect(body.includes('<title>'+item.title+'</title>'),item.path+' title mismatch')
  expect(body.includes('<link rel="canonical" href="'+item.canonical+'">'),item.path+' canonical missing')
  expect(body.includes('data-case-status="demo-only"'),item.path+' lost demo-only boundary')
  expect(body.includes('id="project-brief"')&&body.includes('id="contact-cta"')&&body.includes('id="email-cta"'),item.path+' missing brief/contact')
  expect(body.includes('utm_campaign=merakki_global_case'),item.path+' missing attribution')
  expect(body.includes('property="og:image" content="https://osgard.world/development/merakki/og.svg"'),item.path+' missing OG image')
  expect(body.includes('name="twitter:card" content="summary_large_image"')&&body.includes('name="twitter:image" content="https://osgard.world/development/merakki/og.svg"'),item.path+' missing large-image Twitter metadata')
  const ld=body.match(/<script type="application\/ld\+json" id="case-structured-data">([\s\S]*?)<\/script>/)
  expect(Boolean(ld),item.path+' missing JSON-LD')
  const graph=JSON.parse(ld[1])['@graph']
  expect(graph.some(n=>n['@type']==='Article'&&n.inLanguage===item.language),item.path+' JSON-LD locale mismatch')
  return {statusCode:response.status,locale:item.locale,canonical:item.canonical}
 })
}
await check('MERAKKI social image 1200x630 SVG',async()=>{
 const {response,body}=await get('/development/merakki/og.svg'),type=(response.headers.get('content-type')||'').toLowerCase()
 expect(response.status===200,'social image HTTP '+response.status)
 expect(type.includes('image/svg+xml')||type.includes('image/svg'),'social image MIME invalid')
 expect(body.includes('<svg')&&body.includes('width="1200" height="630"')&&body.includes('viewBox="0 0 1200 630"'),'social image dimensions mismatch')
 expect(body.includes('MERAKKI')&&body.includes('GLOBAL')&&body.includes('NO LIVE CHECKOUT'),'social image brand/status missing')
 return {statusCode:response.status,contentType:type,width:1200,height:630}
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

await check('OSGARD Core API health', async () => {
  const { response, body } = await get('/api/core/health')
  expect(response.status === 200, `expected HTTP 200, got ${response.status}`)
  const value = JSON.parse(body)
  expect(value.status === 'ok' && value.mode === 'self-hosted-pilot', 'unexpected Core API identity')
  expect(value.payments === false && value.ai === false, 'Core must report unconnected payments and AI honestly')
  return { statusCode: response.status, mode: value.mode, schemaVersion: value.schemaVersion, payments: value.payments, ai: value.ai }
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
