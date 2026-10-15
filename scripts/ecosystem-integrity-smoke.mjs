import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const read = path => readFileSync(path, 'utf8')
const app = read('src/App.tsx')
const sections = read('src/Sections.tsx')
const development = read('src/Development.tsx')
const merakkiPage = read('public/development/merakki/index.html')
const merakkiPageEn = read('public/development/merakki/en/index.html')
const merakkiPageAr = read('public/development/merakki/ar/index.html')
const manifest = read('src/core/manifest.ts')
const games = read('public/games/index.html')
const lifecycle = read('public/games/player-lifecycle.js')
const sitemap = read('public/sitemap.xml')
const nginx = read('nginx.conf')
const activation = read('scripts/activate-frontend-remote.sh')

const promotionSources = { app, sections, development, merakkiPage, merakkiPageEn, merakkiPageAr }
for (const [locale, page] of Object.entries({ ru: merakkiPage, en: merakkiPageEn, ar: merakkiPageAr })) {
  for (const id of ['brief-copy', 'brief-download', 'brief-share']) {
    assert.ok(page.includes('id="' + id + '"'), 'MERAKKI ' + locale + ' page is missing ' + id)
  }
  assert.ok(page.includes('function downloadBriefMessage') && page.includes('function shareBriefMessage'), 'MERAKKI ' + locale + ' page is missing local export/share logic')
  assert.ok(page.includes('data-case-status="demo-only"'), 'MERAKKI ' + locale + ' page must remain demo-only')
}
const unsupportedClaims = [
  '99.9%', '7 min', '7 мин', '360°', '360пїЅ', '+2 h', '+2 часа в день',
  '40% less chaos', 'Меньше хаоса на 40%', '2 min', '2 мин', '0.0%',
  '4K MASTER', 'Экономия 50 000 ₽', 'Доход от 30 000 ₽/мес',
  'osgardnewworld.com',
]
for (const [file, source] of Object.entries(promotionSources)) {
  for (const claim of unsupportedClaims) {
    assert.ok(!source.includes(claim), 'Unsupported quantitative claim "' + claim + '" remains in ' + file)
  }
}

const projectHosts = [
  'osgardbewworld.com', 'o2system.art', 'senjorio.com', 'superday.run',
  'marcosa.club', 'myosa.world', 'gold-glamour.online', 'gardvpn.is',
  'osgardos.com', 'osgardvanguard.studio',
]
for (const host of projectHosts) {
  assert.ok(games.includes(host), 'Games hub is missing first-party project ' + host)
  assert.ok(games.includes('utm_source=osgard_games'), 'Games hub lacks campaign attribution')
  assert.ok(development.includes(host), 'Development portfolio is missing ' + host)
}
assert.ok(development.includes('href="/development/merakki/"') && development.includes('MERAKKI GLOBAL'), 'Development portfolio must link to the MERAKKI GLOBAL case')
assert.ok(merakkiPage.includes('<title>MERAKKI GLOBAL — кейс OSGARD Development</title>'), 'MERAKKI case needs its own metadata title')
const merakkiStructuredDataMatch = merakkiPage.match(/<script type="application\/ld\+json" id="case-structured-data">([\s\S]*?)<\/script>/)
assert.ok(merakkiStructuredDataMatch, 'MERAKKI case must contain JSON-LD structured data')
const merakkiStructuredData = JSON.parse(merakkiStructuredDataMatch[1])
assert.ok(merakkiStructuredData['@graph'].some(node => node['@type'] === 'Article'), 'MERAKKI JSON-LD must describe the case as an article')
assert.ok(merakkiStructuredData['@graph'].some(node => node['@type'] === 'BreadcrumbList'), 'MERAKKI JSON-LD must include breadcrumb structured data')
assert.ok(merakkiPage.includes('property="og:site_name" content="OSGARD WORLD"') && merakkiPage.includes('name="twitter:card" content="summary_large_image"') && merakkiPage.includes('property="og:image" content="https://osgard.world/development/merakki/og.svg"'), 'MERAKKI case must include large-image social sharing metadata')
assert.ok(merakkiPage.includes('twitterDescription.content=v.description') && merakkiPage.includes('ogTitle.content=v.title'), 'MERAKKI social metadata must update when the locale changes')
assert.ok(merakkiPage.includes('utm_campaign=merakki_global_case') && merakkiPage.includes('Live checkout and payments are disabled'), 'MERAKKI case must tag public-preview attribution and state checkout boundaries')
assert.ok(merakkiPage.includes('id="contact-cta"') && merakkiPage.includes('https://wa.me/79640027222'), 'MERAKKI case must provide a direct WhatsApp project CTA')
assert.ok(merakkiPage.includes('id="brief-preview"') && merakkiPage.includes('id="brief-copy"'), 'MERAKKI case must expose generated preview and copy controls')
assert.ok(merakkiPage.includes('id="email-cta"') && merakkiPage.includes('mailto:osman.osmanov0099@gmail.com'), 'MERAKKI case must provide an email fallback')
assert.ok(merakkiPage.includes('encodeURIComponent(v.contactMessage)') && merakkiPage.includes('"ru":{') && merakkiPage.includes('"en":{') && merakkiPage.includes('"contactMessage":"'), 'MERAKKI contact actions must follow the selected language')
assert.ok(merakkiPage.includes('id="project-brief"') && merakkiPage.includes('id="brief-type"') && merakkiPage.includes('id="brief-goal"') && merakkiPage.includes('id="brief-timeline"'), 'MERAKKI case must include guided project brief fields')
assert.ok(merakkiPage.includes('id="brief-context"') && merakkiPage.includes('maxlength="320"') && merakkiPage.includes('id="brief-count"') && merakkiPage.includes('id="brief-status"'), 'MERAKKI brief must bound free text and expose accessible status/count')
assert.ok(merakkiPage.includes('function updateContactLinks()') && merakkiPage.includes('encodeURIComponent(message)'), 'MERAKKI brief must generate encoded WhatsApp/email drafts')
assert.ok(merakkiPage.includes('data-i18n-placeholder="briefContextPlaceholder"') && merakkiPage.includes('briefReady') && merakkiPage.includes('passwords or confidential data'), 'MERAKKI brief must support RU/EN placeholder and confidential-data guidance')
assert.ok(!merakkiPage.includes('localStorage') && !merakkiPage.includes('fetch('), 'MERAKKI brief must not persist or submit visitor input')
assert.ok(merakkiPage.includes('data-case-status="demo-only"'), 'MERAKKI case must declare demo-only status')
assert.ok(sitemap.includes('https://osgard.world/development/merakki/'), 'Sitemap must include the MERAKKI case')

assert.ok(merakkiPage.includes('hreflang="en"') && merakkiPage.includes('hreflang="ar"'), 'MERAKKI RU case must declare reciprocal EN and AR alternates')
assert.ok(merakkiPageEn.includes('<html lang="en"') && merakkiPageEn.includes('rel="canonical" href="https://osgard.world/development/merakki/en/"'), 'MERAKKI English locale must have its own canonical')
assert.ok(merakkiPageAr.includes('<html lang="ar" dir="rtl"') && merakkiPageAr.includes('rel="canonical" href="https://osgard.world/development/merakki/ar/"'), 'MERAKKI Arabic locale must have a distinct RTL canonical')
assert.ok(merakkiPageEn.includes('id="brief-copy"') && merakkiPageAr.includes('id="brief-copy"'), 'MERAKKI locale variants must preserve the brief-copy flow')
assert.ok(sitemap.includes('https://osgard.world/development/merakki/en/') && sitemap.includes('https://osgard.world/development/merakki/ar/'), 'Sitemap must include the MERAKKI EN and AR routes')

for (const [path, source] of [['src/App.tsx', app], ['src/Development.tsx', development], ['public/games/index.html', games]]) {
  assert.ok(source.includes('osman.osmanov0099@gmail.com'), path + ' is missing contact email')
  assert.ok(source.includes('https://wa.me/79640027222'), path + ' is missing the WhatsApp contact URL')
}

assert.ok(app.includes('href="/games/"'), 'Main navigation must expose the Games hub')
assert.ok(app.includes("url: 'https://osgardbewworld.com/'"), 'Main ecosystem must use the supplied digital-development domain')
assert.ok(sections.includes("href: '/games/time'"), 'Entertainment route must point to the current Time game URL')
assert.ok(!sections.includes('/games/time-empire/'), 'Legacy Time route must not be used by the current catalog')
assert.ok(manifest.includes("href: '/games/null-shift-godot/index.html'"), 'Manifest should point to the engine-export route')
assert.ok(games.includes('Рекламная сеть не подключена. Скрытых показов нет.'), 'Sponsor inventory must remain transparent while no ad provider is connected')
assert.ok(games.includes('Без фиктивных рейтингов и онлайна') || games.includes('БЕЗ ФИКТИВНЫХ РЕЙТИНГОВ И ОНЛАЙНА'), 'Catalog should not imply fabricated players or ratings')
assert.ok(games.includes('/privacy/') && games.includes('/terms/'), 'Privacy and terms links are required')
assert.ok(sitemap.includes('https://osgard.world/games/'), 'Sitemap must include Games')
assert.ok(lifecycle.includes('if(!consent||!token)return'), 'Session analytics must require user consent and authenticated account')
assert.ok(lifecycle.includes('event.origin!==location.origin') && lifecycle.includes('event.source!==frame.contentWindow'), 'Cross-frame lifecycle messages must be same-origin and source-checked')
assert.ok(lifecycle.includes('function startSession(') && lifecycle.includes('game_session_completed'), 'Gameplay lifecycle tracking must observe real client readiness and session completion')
const apiProxyStart = nginx.indexOf('location ^~ /api/v1/ {')
const apiProxyEnd = nginx.indexOf('location /api/remix/ {', apiProxyStart)
const spaFallbackStart = nginx.indexOf('location / {')
assert.ok(apiProxyStart >= 0 && apiProxyEnd > apiProxyStart && spaFallbackStart > apiProxyStart, 'Nginx must route /api/v1/* before the SPA fallback')
const apiProxy = nginx.slice(apiProxyStart, apiProxyEnd)
assert.ok(nginx.indexOf('limit_req_zone $binary_remote_addr zone=osgard_player_api:10m rate=15r/s;') < apiProxyStart, 'Nginx API rate-limit zone must be declared in the http context before server blocks')
assert.ok(apiProxy.includes('resolver 127.0.0.11 valid=30s ipv6=off;') && apiProxy.includes('set $osgard_game_api_host __OSGARD_HOST_GATEWAY__;') && apiProxy.includes('proxy_pass http://$osgard_game_api_host:4317;') && activation.includes('__OSGARD_HOST_GATEWAY__') && activation.includes('Detected host API gateway'), 'Protected API proxy must target the verified host-managed API through the current Docker gateway')
assert.ok(apiProxy.includes('limit_req zone=osgard_player_api burst=30 nodelay;') && apiProxy.includes('limit_req_status 429;'), 'API route must enforce an explicit per-client rate limit')
assert.ok(apiProxy.includes('add_header Cache-Control "no-store" always;'), 'Player and admin analytics responses must not be cached by shared browsers/proxies')
assert.ok(apiProxy.includes('proxy_read_timeout 10s;') && apiProxy.includes('client_max_body_size 256k;'), 'API proxy needs bounded request size and upstream timeout')
assert.ok(!apiProxy.includes('proxy_set_header Authorization "Bearer'), 'API credentials must never be injected by static Nginx configuration')

console.log(JSON.stringify({
  status: 'PASS',
  checks: 53,
  projects: projectHosts.length,
  claimsGuarded: unsupportedClaims.length,
  contacts: 3,
  verifiedInSource: ['game route wiring', 'honest monetization status', 'consent/auth-gated event capture', 'cross-frame origin validation', 'contact routing'],
}, null, 2))
