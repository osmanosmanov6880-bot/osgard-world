import { isValidPartnerInventoryText } from './partner-inventory-contract.mjs'
const base = process.env.OSGARD_BASE_URL || 'https://osgard.world'
const expectCurrentDesign = process.env.SKILLCRED_EXPECT_CURRENT_DESIGN === '1'
const routes = ['/tedes/','/tedes/catalog/','/tedes/collections/','/tedes/product/?sku=FORMA-ARC-01','/tedes/data/catalog.v1.json','/tedes/materials/','/tedes/project/','/tedes/print/','/development/tedes/','/development/merakki/','/development/merakki/en/','/development/merakki/ar/','/development/merakki/og.svg','/','/portal','/osa-cinema','/academy','/skillcred/','/skillcred/favicon.svg','/skillcred-api/health','/skillcred-api/ready','/skillcred-api/issuer','/entertainment','/entertainment/','/entertainment/en/','/entertainment/ar/','/entertainment/og.svg','/entertainment/elbrus/','/entertainment/elbrus/en/','/entertainment/elbrus/ar/','/entertainment/elbrus/og.svg','/games/','/games/index.html','/games/partners/','/games/admin/','/games/afterimage-run/','/games/vector-zero/','/games/favicon.svg','/privacy/','/terms/','/community','/stream','/archive','/profile','/api/v1/player/profile','/api/v1/analytics/summary?from=0&to=1','/r/1842','/games/time','/games/null-shift/','/games/null-shift/index.html','/games/null-shift-godot/','/games/null-shift-godot/index.html','/play/swarm','/play/null-shift','/play/inherit','/play/remix','/media','/business','/create','/mobility']
const agents = { desktop: 'OSGARD-Route-Matrix/1.1 Desktop', mobile: 'OSGARD-Route-Matrix/1.1 Mobile' }
const results = []
for (const [device, userAgent] of Object.entries(agents)) for (const route of routes) {
  const started = Date.now()
  try {
    const requestUrl = new URL(route, base)
    if (route === '/') requestUrl.searchParams.set('osa_release_probe', `${device}-${Date.now()}`)
    const response = await fetch(requestUrl, { headers: { 'user-agent': userAgent, 'cache-control': 'no-cache', pragma: 'no-cache' } })
    const text = await response.text()
    const shellOk = route === '/'
      ? (text.includes('<title>OSA Intelligence — понимать, проверять, решать</title>') || text.includes('<title>OSGARD WORLD — цифровая экосистема</title>')) &&
        /<script[^>]+src="\/assets\/[^"]+\.js"/i.test(text)
      : route === '/tedes/'
        ? text.includes('<title>TEDES Studio — архитектурная фурнитура как система</title>') && text.includes('id="addDoor"') && text.includes('id="exportJson"') && text.includes('id="exportCsv"') && text.includes('id="doorRows"') && text.includes('STORAGE_KEY') && text.includes('id="buildQuote"') && text.includes('id="importJson"') && text.includes('id="importFile"') && text.includes('data-duplicate=') && text.includes('safeCsvCell')
      : route === '/tedes/catalog/'
        ? text.includes('<title>TEDES Catalog — коллекция архитектурной фурнитуры</title>') && text.includes('id="products"') && text.includes('id="search"') && text.includes('id="collection"') && text.includes('id="finish"')
      : route === '/tedes/collections/'
        ? text.includes('<title>TEDES Collections — форма, линия, материя</title>') && text.includes('FORMA') && text.includes('LINEA') && text.includes('MATERIA')
      : route.startsWith('/tedes/product/')
        ? text.includes('<title>TEDES Product Studio — configurable door hardware concept</title>') && text.includes('id="addToProject"') && text.includes('localStorage') && text.includes('id="swatches"')
      : route === '/tedes/materials/'
        ? text.includes('<title>TEDES Materials — guide to finishes</title>') && text.includes('Antique Brass') && text.includes('Brushed Steel') && text.includes('Matte Black')
      : route === '/tedes/data/catalog.v1.json'
        ? (() => { try { const data = JSON.parse(text); return data.schemaVersion === 1 && data.catalogId === 'tedes-demo-catalog-v1' && data.status === 'demo-only' && Array.isArray(data.products) && data.products.length === 6 && new Set(data.products.map(item => item.sku)).size === data.products.length && data.products.every(item => item.recordStatus === 'concept' && item.price === null && item.availability === null && item.dimensionsMm === null && item.mechanism === null && item.imageStatus === 'concept-visualization') } catch { return false } })()
      : route === '/tedes/project/'
        ? text.includes('<title>TEDES — проектная ведомость</title>') && text.includes('id="positionRows"') && text.includes('id="requestForm"') && text.includes('id="exportJson"') && text.includes('id="exportCsv"') && text.includes('noindex,nofollow') && text.includes('src="/tedes/project/project-workspace.js"')
      : route === '/tedes/print/'
        ? text.includes('<title>TEDES — печатная ведомость проекта</title>') && text.includes('id="positionRows"') && text.includes('id="printProject"') && text.includes('tedes-studio-project-v1') && text.includes('не подтверждённая производственная спецификация')
      : route === '/development/tedes/'
        ? text.includes('<title>TEDES — кейс OSGARD Development</title>') && text.includes('href="/tedes/"') && text.includes('FLAGSHIP CASE')
      : route === '/development/merakki/'
        ? text.includes('<title>MERAKKI GLOBAL — кейс OSGARD Development</title>') && text.includes('utm_campaign=merakki_global_case') && text.includes('id="contact-cta"') && text.includes('id="email-cta"') && text.includes('id="project-brief"') && text.includes('id="brief-generate"') && text.includes('id="brief-preview"') && text.includes('id="brief-copy"') && text.includes('id="brief-download"') && text.includes('id="brief-share"') && text.includes('id="case-structured-data"') && text.includes('name="twitter:card" content="summary_large_image"') && text.includes('data-case-status="demo-only"')
      : route === '/development/merakki/en/'
        ? text.includes('<title>MERAKKI GLOBAL — OSGARD Development case</title>') && text.includes('<html lang="en"') && text.includes('rel="canonical" href="https://osgard.world/development/merakki/en/"') && text.includes('hreflang="ar"') && text.includes('id="brief-copy"') && text.includes('id="brief-download"') && text.includes('id="brief-share"')
      : route === '/development/merakki/ar/'
        ? text.includes('<html lang="ar" dir="rtl"') && text.includes('rel="canonical" href="https://osgard.world/development/merakki/ar/"') && text.includes('hreflang="en"') && text.includes('id="brief-copy"') && text.includes('id="brief-download"') && text.includes('id="brief-share"')
      : route === '/development/merakki/og.svg'
        ? text.includes('<svg') && text.includes('width="1200" height="630"') && text.includes('viewBox="0 0 1200 630"') && text.includes('MERAKKI') && text.includes('NO LIVE CHECKOUT') && (response.headers.get('content-type') || '').toLowerCase().includes('image/svg+xml')
      : route.startsWith('/api/v1/')
        ? [401, 403].includes(response.status) && (response.headers.get('content-type') || '').toLowerCase().includes('application/json') && (() => { try { JSON.parse(text); return true } catch { return false } })()
       : route === '/skillcred/favicon.svg'
       ? text.includes('<svg') && text.includes('viewBox="0 0 64 64"') && text.includes('SKILLCRED')
      : route === '/skillcred/'
      ? text.includes('id="issueBtn"') &&
        text.includes('id="verifyBtn"') &&
        text.includes('id="revokeBtn"') &&
        text.includes('id="downloadBtn"') &&
        (!expectCurrentDesign || text.includes('id="trustSpine"')) &&
        text.includes('id="signatureClock"') &&
        text.includes('id="timeElapsed"') &&
        text.includes('id="heroCredential"') &&
        text.includes('name="api-base" content="/skillcred-api"') &&
        text.includes('/demo/issue') &&
        text.includes('/demo/verify') &&
        text.includes('/demo/revoke')
      : route.startsWith('/skillcred-api/')
        ? route.endsWith('/health') ? /"service"\s*:\s*"skillcred"/.test(text) && /"version"\s*:\s*"0\.3\.0"/.test(text)
          : route.endsWith('/ready') ? /"ready"\s*:\s*true/.test(text)
            : /"id"\s*:/.test(text) && /"name"\s*:/.test(text)
        : route === '/games/admin/'
          ? text.includes('<meta name="robots" content="noindex,nofollow,noarchive">') && text.includes('id="access-form"') && text.includes('X-Moderation-Token') && text.includes('/api/v1/analytics/summary')
      : route === '/games/favicon.svg'
          ? text.includes('<svg') && text.includes('viewBox="0 0 64 64"')
        : route === '/privacy/'
          ? text.includes('<title>Конфиденциальность OSGARD PLAY</title>') && text.includes('osgard.games.analytics-consent.v1')
        : route === '/terms/'
          ? text.includes('<title>Условия использования OSGARD PLAY</title>') && text.includes('прототип')
        : route === '/games/partners/'
          ? text.includes('id="campaign-form"') && text.includes('id="inventory-grid"') && text.includes('id="principles"') && text.includes('partners.js') && text.includes('mailto:osman.osmanov0099@gmail.com')
        : (route === '/games/' || route === '/games/index.html')
          ? text.includes('id="games-grid"') && text.includes('data-game="null-shift"') && text.includes('data-game="time"') && text.includes('data-game="swarm"') && text.includes('data-game="inherit"') && text.includes('data-game="remix"') && text.includes('data-game="vector-zero"') && text.includes('data-game="afterimage-run"') && text.includes('"numberOfItems":7') && text.includes('id="player-dialog"') && text.includes('id="player-share"') && text.includes('data-lazy-src="./player-lifecycle.js"') && text.includes('data-lazy-src="./ecosystem-intermission.js"') && text.includes('id="project-form"') && text.includes('id="analytics-toggle"') && text.includes('osgardvanguard.studio')
        : route.startsWith('/games/afterimage-run/')
          ? text.includes('<title>AFTERIMAGE//RUN — OSGARD PLAY</title>') && text.includes('id="runnerCanvas"') && text.includes('id="run-start"') && text.includes('id="share-telegram"') && text.includes('osgard:game-lifecycle')
        : route.startsWith('/games/vector-zero/')
          ? text.includes('<title>VECTOR//ZERO — Разрыв поля</title>') && text.includes('id="field"') && text.includes('id="start"') && text.includes('osgard:game-lifecycle')
        : route.startsWith('/games/null-shift-godot')
          ? /<canvas/i.test(text) && /godot/i.test(text) && text.includes('index.wasm') && text.includes('index.pck') &&
            text.includes('data-nullshift-shell="premium-v1"') &&
            text.includes('Engine.isWebGLAvailable(2)') &&
            text.includes('onProgress') &&
            text.includes('НАЧАТЬ ОПЕРАЦИЮ') && text.includes('osgard:game-lifecycle')
          : route.startsWith('/games/null-shift')
            ? text.includes('id="game"') && text.includes('id="mobile-ui"') && text.includes('id="diag-panel"') && text.includes('id="sound-toggle"') && text.includes('id="touch-sound"') && text.includes('./styles.css') && text.includes('./game.js') && text.includes('./engine-3d.js') && text.includes('id="engine-toggle"') && text.includes('id="touch-engine"') && text.includes('id="godot-preview"')
          : route === '/entertainment/en/'
            ? text.includes('<title>OSGARD Entertainment | Playable Worlds</title>') && text.includes('<html lang="en" dir="ltr">') && text.includes('rel="canonical" href="https://osgard.world/entertainment/en/"') && text.includes('hreflang="ar"') && text.includes('/entertainment/elbrus/')
          : route === '/entertainment/ar/'
            ? text.includes('<title>OSGARD Entertainment | عوالم قابلة للعب</title>') && text.includes('<html lang="ar" dir="rtl">') && text.includes('rel="canonical" href="https://osgard.world/entertainment/ar/"') && text.includes('hreflang="en"') && text.includes('/entertainment/elbrus/')
          : route === '/entertainment/og.svg'
            ? text.includes('<svg') && text.includes('OSGARD WORLD') && !text.includes('<script')
          : route === '/entertainment/elbrus/'
            ? text.includes('<title>ELBRUS — цифровой опыт гостеприимства | OSGARD WORLD</title>') && text.includes('<html lang="ru" dir="ltr">') && text.includes('id="interactive-preview"') && text.includes('не отправляет заказы')
          : route === '/entertainment/elbrus/en/'
            ? text.includes('<title>ELBRUS — Hospitality Experience | OSGARD WORLD</title>') && text.includes('<html lang="en" dir="ltr">') && text.includes('does not place orders') && text.includes('id="interactive-preview"')
          : route === '/entertainment/elbrus/ar/'
            ? text.includes('<title>ELBRUS — تجربة الضيافة | OSGARD WORLD</title>') && text.includes('<html lang="ar" dir="rtl">') && text.includes('لا ترسل طلبات') && text.includes('id="interactive-preview"')
          : route === '/entertainment/elbrus/og.svg'
            ? text.includes('<svg') && text.includes('ELBRUS')
          : (route === '/entertainment' || route === '/entertainment/')
            ? text.includes('<title>OSGARD Entertainment</title>') &&
              text.includes('rel="canonical" href="https://osgard.world/entertainment/"') &&
              text.includes('hreflang="en"') && text.includes('hreflang="ar"') &&
              text.includes('/entertainment/elbrus/') &&
              (text.match(/class="case-shelf"/g) || []).length === 1
          : text.includes('<div id="root">')
    const isGamesHub = route === '/games/' || route === '/games/index.html'
    const isPartnerPage = route === '/games/partners/'
    const isGodot = route.startsWith('/games/null-shift-godot')
    const assetPaths = route === '/skillcred/favicon.svg' ? ['/skillcred/favicon.svg'] : route === '/tedes/' ? ['/tedes/assets/hero-door.webp'] : route === '/tedes/catalog/' ? ['/tedes/data/catalog.v1.json', '/tedes/assets/architecture-scene.webp', '/tedes/assets/hero-door.webp'] : route === '/tedes/collections/' ? ['/tedes/assets/architecture-scene.webp', '/tedes/assets/hero-door.webp'] : route.startsWith('/tedes/product/') ? ['/tedes/data/catalog.v1.json', '/tedes/assets/hero-door.webp'] : route === '/tedes/materials/' ? ['/tedes/assets/hero-door.webp'] : route === '/tedes/project/' ? ['/tedes/project/project-workspace.js'] : route === '/development/tedes/' ? ['/tedes/assets/hero-door.webp', '/tedes/assets/architecture-scene.webp'] : route === '/games/favicon.svg' || route === '/privacy/' || route === '/terms/' ? [] : isPartnerPage ? ['/games/partners/partners.js', '/games/partners/inventory.json'] : isGamesHub ? ['/games/player-lifecycle.js', '/games/ecosystem-intermission.js'] : route === '/skillcred/' ? ['/skillcred/styles.css', '/skillcred/app.js', '/skillcred/fonts/InterVariable.woff2', '/skillcred/fonts/InstrumentSerif-Italic.woff2', '/skillcred/fonts/JetBrainsMono-Regular.woff2'] : isGodot ? ['/games/null-shift-godot/index.js', '/games/null-shift-godot/index.wasm', '/games/null-shift-godot/index.pck'] : route.startsWith('/games/null-shift') ? ['/games/null-shift/styles.css', '/games/null-shift/game.js', '/games/null-shift/engine-3d.js'] : []
    if (route === '/') {
      const rootBundle = text.match(/<script[^>]+src="([^"]+\.js)"[^>]*><\/script>/i)?.[1]
      if (rootBundle) assetPaths.push(rootBundle)
    }
    const assetChecks = await Promise.all(assetPaths.map(async path => {
      const expectedType = path.endsWith('.svg') ? 'image/svg+xml' : path.endsWith('.webp') ? 'image' : path.endsWith('.css') ? 'text/css' : path.endsWith('.json') ? 'json' : path.endsWith('.js') ? 'javascript' : path.endsWith('.wasm') ? 'wasm' : path.endsWith('.pck') ? 'pack' : 'font'
      const asset = await fetch(new URL(path, base), { headers: { 'user-agent': userAgent, 'cache-control': 'no-cache', pragma: 'no-cache' } })
      const contentType = asset.headers.get('content-type') || ''
      const mime = contentType.toLowerCase()
      const typeOk = expectedType === 'image/svg+xml' ? mime.includes('image/svg+xml') : expectedType === 'text/css' ? mime.includes('text/css') : expectedType === 'json' ? mime.includes('application/json') || mime.includes('text/json') || mime.includes('text/plain') : expectedType === 'javascript' ? mime.includes('javascript') || mime.includes('ecmascript') : expectedType === 'wasm' ? mime.includes('wasm') || mime.includes('octet-stream') : expectedType === 'pack' ? mime.length > 0 : expectedType === 'image' ? mime.includes('image/webp') : mime.includes('font/woff2') || mime.includes('application/octet-stream')
      let nonEmpty = false
      if (expectedType === 'font' || expectedType === 'wasm' || expectedType === 'pack' || expectedType === 'image') {
        const size = (await asset.arrayBuffer()).byteLength
        const minimum = expectedType === 'image' ? 1000 : expectedType === 'font' ? (path.endsWith('InterVariable.woff2') ? 100000 : 5000) : expectedType === 'wasm' ? 100000 : 10000
        nonEmpty = size > minimum
      } else {
        const content = await asset.text()
        const normalized = content.toLowerCase()
        nonEmpty = expectedType === 'image/svg+xml' ? content.includes('<svg') && content.includes('viewBox="0 0 64 64"') && content.includes('SKILLCRED') : isPartnerPage
          ? path.endsWith('.json') ? isValidPartnerInventoryText(content) : content.includes("fetch('./inventory.json'") && content.includes('item.active === false') && content.includes("sendLink.href = 'https://wa.me/79640027222?text='")
          : isGodot
          ? content.length > 100000
          : path.startsWith('/games/null-shift/')
            ? path.endsWith('engine-3d.js')
              ? content.includes("getContext('webgl'") && content.includes('NULL_SHIFT_GET_SCENE_STATE') && content.includes('function cube(){') && content.includes('NULL_SHIFT_SCREEN_TO_WORLD') && content.includes('drawParticles') && content.includes('ANGLE_instanced_arrays') && content.includes('renderInstanced') && content.includes('gpuFrameStats.triangles') && content.includes('function updateAdaptiveResolution(') && content.includes('adaptiveScale') && content.includes('renderCost.toFixed(1)') && content.includes('lastStats=0') && content.includes('renderCost=0') && content.includes('function softShadow(') && content.includes('aVertexAlpha') && content.includes('G.shadow')
              : path.endsWith('.css')
                ? content.includes('.mobile-ui') && content.includes('prefers-reduced-motion') && content.includes('.engine-minimap')
                : content.includes('premiumAtmosphere') && content.includes('PerformanceObserver') && content.includes('premiumV05DrawMotion') && content.includes('premiumV05ArmAudio') && content.includes('premiumV05UpdateMotion') && content.includes('NULL_SHIFT_GET_SCENE_STATE')
            : path === '/games/player-lifecycle.js'
              ? content.includes('function startSession(') && content.includes('game_session_completed') && content.includes('osgard:game-lifecycle') && content.includes('event.source!==frame.contentWindow')
              : path === '/games/ecosystem-intermission.js'
              ? content.includes('const services=[') && content.includes('data-skip') && content.includes('ecosystem_promo_clicked') && content.includes('utm_campaign')
              : path === '/tedes/data/catalog.v1.json'
                ? (() => { try { const data = JSON.parse(content); return data.catalogId === 'tedes-demo-catalog-v1' && data.status === 'demo-only' && data.products.length === 6 && data.products.every(item => item.price === null && item.availability === null) } catch { return false } })()
                : path === '/tedes/project/project-workspace.js'
                ? content.includes('export function parseProjectDocument') && content.includes('export function mergeProjectDocuments') && content.includes('MAX_IMPORT_BYTES') && content.includes('localStorage') && content.length > 10000
                : route === '/'
                  ? (content.includes('OSA INTELLIGENCE / BEYOND THE MODEL') || /osgard|world/i.test(content)) && content.length > 100000
                : path === '/tedes/project/project-workspace.js'
                ? content.includes('export const PROJECT_SCHEMA = "tedes-studio-project/v1";') &&
                  content.includes('MAX_PROJECT_POSITIONS = 30') &&
                  content.includes('MAX_IMPORT_BYTES = 1024 * 1024') &&
                  content.includes('exportCsv') &&
                  content.includes('JSON.parse') &&
                  content.includes('localStorage')
                : path.endsWith('.css')
              ? normalized.includes('--acid:#c8ff3d') && normalized.includes('/skillcred/fonts/intervariable.woff2') && normalized.includes('/skillcred/fonts/instrumentserif-italic.woff2') && normalized.includes('/skillcred/fonts/jetbrainsmono-regular.woff2') && (!expectCurrentDesign || (normalized.includes('--hero-size:clamp(88px,6vw,104px)') && normalized.replace(/["']/g, '').includes('.trust-spine[data-state=revoked]')))
              : content.includes('demo/issue') && content.includes('data-clock-step')
      }
      return { path, status: asset.status, contentType, ok: asset.status === 200 && typeOk && nonEmpty }
    }))
    const assetsOk = assetChecks.every(asset => asset.ok)
    const statusOk = route.startsWith('/api/v1/') ? [401, 403].includes(response.status) : response.status === 200
    results.push({ device, route, status: response.status, assets: assetChecks, ok: statusOk && shellOk && assetsOk, durationMs: Date.now() - started })
  } catch (error) { results.push({ device, route, status: 0, ok: false, error: String(error), durationMs: Date.now() - started }) }
}
const failed = results.filter(item => !item.ok)
const report = { base, checkedAt: new Date().toISOString(), routes: results.length, failed: failed.length, status: failed.length ? 'failed' : 'ready', results }
console.log(JSON.stringify(report, null, 2))
if (failed.length) process.exitCode = 1
