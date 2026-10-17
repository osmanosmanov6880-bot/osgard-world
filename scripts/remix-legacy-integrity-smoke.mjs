import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import vm from 'node:vm'
import ts from 'typescript'

// Execute the actual TSX components with effects and API spies. This fixture
// verifies that viewing the retired REMIX route cannot publish synthetic scores.
function componentFixture(file) {
  const source = readFileSync(file, 'utf8')
  const code = ts.transpileModule(source, { fileName: file, compilerOptions: { module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX, target: ts.ScriptTarget.ES2022 } }).outputText
  const effects = [], state = [], events = [], apiCalls = [], redirects = []
  let cursor = 0
  const jsx = (type, props, key) => ({ type, props: props || {}, key })
  const hooks = {
    useEffect: fn => effects.push(fn),
    useRef: value => ({ current: value }),
    useState(initial) { const index = cursor++; if (!(index in state)) state[index] = typeof initial === 'function' ? initial() : initial; return [state[index], next => { state[index] = typeof next === 'function' ? next(state[index]) : next }] },
  }
  const module = { exports: {} }, location = { search: '', hash: '', replace: path => redirects.push(path) }
  const context = { module, exports: module.exports, URL, URLSearchParams, window: { location }, console,
    fetch() { apiCalls.push(['fetch']); throw Error('Unexpected network call') },
    require(id) {
      if (id === 'react') return hooks
      if (id === 'react/jsx-runtime') return { jsx, jsxs: jsx, Fragment: 'fragment' }
      if (id === 'lucide-react') return new Proxy({}, { get: (_target, name) => 'icon-' + String(name) })
      if (id === './core/eventQueue') return { recordOsgardEvent: (...args) => events.push(args) }
      if (id === './core/playerApi') return Object.fromEntries(['startPlayerSession', 'completePlayerSession'].map(name => [name, (...args) => { apiCalls.push([name, ...args]); return Promise.resolve(null) }]))
      throw Error('Unexpected fixture import: ' + id)
    },
  }
  vm.createContext(context); vm.runInContext(code, context, { filename: file })
  return { exports: module.exports, location, redirects, events, apiCalls, render(name) { cursor = 0; return module.exports[name]() }, runEffects() { for (const effect of effects.splice(0)) effect() } }
}
const descendants = tree => Array.isArray(tree) ? tree.flatMap(descendants) : tree && typeof tree === 'object' ? [tree, ...descendants(tree.props?.children)] : []
const text = tree => (Array.isArray(tree) ? tree.map(text).join(' ') : tree && typeof tree === 'object' ? text(tree.props?.children) : tree == null || typeof tree === 'boolean' ? '' : String(tree)).replace(/\s+/g, ' ').trim()
let passed = 0
function check(name, run) { run(); passed++; console.log('PASS', name) }

check('legacy REMIX keeps recognized invitation, language, attribution and fragment on a fixed local route', () => {
  const { remixLegacyDestination } = componentFixture('src/LegacyCreatorPrototypes.tsx').exports
  const destination = remixLegacyDestination('?challenge=ch_example&seed=20261017&ref=friend&lang=en&utm_source=invite&utm_content=card', '#live-growth-console')
  const url = new URL(destination, 'https://osgard.world')
  assert.equal(url.origin, 'https://osgard.world'); assert.equal(url.pathname, '/games/remix/')
  for (const [key, value] of [['challenge', 'ch_example'], ['seed', '20261017'], ['ref', 'friend'], ['lang', 'en'], ['utm_source', 'invite'], ['utm_content', 'card']]) assert.equal(url.searchParams.get(key), value)
  assert.equal(url.hash, '#live-growth-console')
})

check('untrusted redirect targets cannot turn the legacy REMIX handoff into an external navigation', () => {
  const { remixLegacyDestination } = componentFixture('src/LegacyCreatorPrototypes.tsx').exports
  for (const fragment of ['#//other.example', '#javascript:alert(1)', '#section']) {
    const destination = remixLegacyDestination('?redirect=https://other.example&next=//other.example&api=https://other.example&challenge=ch_example', fragment)
    const url = new URL(destination, 'https://osgard.world')
    assert.equal(url.origin, 'https://osgard.world'); assert.equal(url.pathname, '/games/remix/')
    assert.equal(url.searchParams.size, 1); assert.equal(url.searchParams.get('challenge'), 'ch_example')
    assert.equal(url.hash, fragment)
  }
})

check('rendering and mounting the actual legacy redirect makes no game-session, score or analytics publication', () => {
  const fixture = componentFixture('src/LegacyCreatorPrototypes.tsx')
  fixture.location.search = '?challenge=ch_example&lang=ru'; fixture.location.hash = '#live-growth-console'
  const tree = fixture.render('RemixLegacyRedirect'); fixture.runEffects()
  assert.deepEqual(fixture.redirects, ['/games/remix/?challenge=ch_example&lang=ru#live-growth-console'])
  const links = descendants(tree).filter(node => node.type === 'a')
  assert.equal(links.length, 1); assert.equal(links[0].props.href, fixture.redirects[0])
  assert.equal(descendants(tree).filter(node => node.type === 'button').length, 0)
  assert.deepEqual(fixture.apiCalls, []); assert.deepEqual(fixture.events, [])
  assert.equal(typeof fixture.exports.InheritPrototype, 'function')
})

check('the public legacy route selects the redirect component, never the retired score generator', () => {
  const main = readFileSync('src/main.tsx', 'utf8')
  assert.match(main, /if \(path === '\/play\/remix'\) return <RemixLegacyRedirect \/>/)
  assert.ok(!main.includes('m.RemixPrototype'))
  const legacy = readFileSync('src/LegacyCreatorPrototypes.tsx', 'utf8')
  assert.ok(!legacy.includes('184200')); assert.ok(!legacy.includes("startPlayerSession('remix'")); assert.ok(!legacy.includes('submitRun('))
})

check('active catalogs launch the Core arena with its actual controls and keep the unavailable Unity build distinct', () => {
  const games = componentFixture('src/redesignCatalog.ts').exports.playGames
  const remix = games.find(game => game.id === 'remix')
  assert.equal(remix.launchable, true); assert.equal(remix.href, '/games/remix/arena/')
  assert.equal(remix.alternate.href, '/games/remix/player/')
  assert.ok(remix.alternate.label.includes('Статус')); assert.ok(remix.warning.includes('Unity-сборка сейчас недоступна'))
  for (const control of ['WASD', 'стрелки', 'четыре направления', 'пробел', 'экранные кнопки']) assert.ok(remix.controls.includes(control), control)
  for (const capability of ['проверочный заезд', 'опубликуйте', 'результат', 'повтор']) assert.ok(remix.description.includes(capability), capability)
  assert.ok(remix.online.includes('аккаунт') && remix.online.includes('сервис'))
  const catalog = readFileSync('public/games/index.html', 'utf8')
  const card = catalog.match(/<article\b[^>]*data-game="remix"[\s\S]*?<\/article>/)?.[0]
  assert.ok(card); assert.ok(card.includes('Unity-сборка сейчас недоступна'))
  assert.match(card, /class="play-link" href="\/games\/remix\/arena\/"/)
  assert.match(card, /href="\/games\/remix\/player\/">Статус Unity-сборки/)
  assert.ok(card.includes('<span>Повторы</span>')); assert.ok(card.includes('проверочный заезд'))
  const arena = readFileSync('public/games/remix/arena/index.html', 'utf8')
  assert.match(arena, /href="\/games\/remix\/"/)
  const landing = readFileSync('public/games/remix/index.html', 'utf8')
  assert.match(landing, /href="#live-growth-console">Open challenge console/)
  assert.match(landing, /href="\/games\/remix\/player\/index.html">Unity build status/)
})

check('the season screen renders an explicit unconnected demo and a real catalog link without invented results', () => {
  const fixture = componentFixture('src/WeekSurface.tsx'), tree = fixture.render('WeekSurface'), visible = text(tree)
  fixture.runEffects()
  assert.ok(visible.includes('Демонстрация интерфейса')); assert.ok(visible.includes('пока не подключены'))
  for (const fictional of ['87 420', '82 190', '79 840', '74 610', '68 220', '03:18:42', 'Вы участвуете']) assert.ok(!visible.includes(fictional), fictional)
  assert.equal(descendants(tree).filter(node => node.type === 'button').length, 0)
  assert.deepEqual(descendants(tree).filter(node => node.type === 'a').map(node => node.props.href), ['/play'])
  assert.deepEqual(fixture.apiCalls, []); assert.deepEqual(fixture.events, [])
})

check('stream modes remain interactive demos, never viewer counts or participation; challenge opens the actual console', () => {
  const fixture = componentFixture('src/StreamSurface.tsx')
  let tree = fixture.render('StreamSurface')
  for (let index = 0; index < 4; index++) {
    descendants(tree).filter(node => node.type === 'button')[index].props.onClick()
    tree = fixture.render('StreamSurface')
    const visible = text(tree)
    assert.ok(visible.includes('Демонстрация интерфейса')); assert.ok(visible.includes('пока не подключены'))
    for (const misleading of ['2 184', '846', 'LIVE SIGNAL', 'IN MOTION', 'ARCHIVED', 'ARENA 04']) assert.ok(!visible.includes(misleading), misleading)
    assert.equal(descendants(tree).filter(node => node.type === 'button' && node.props['aria-pressed']).length, 1)
  }
  const link = descendants(tree).find(node => node.type === 'a')
  assert.equal(link.props.href, '/games/remix/'); assert.ok(text(link).includes('Открыть консоль REMIX'))
  assert.ok(fixture.events.every(([name, payload]) => name === 'portal_opened' && payload.demo === true))
  fixture.runEffects(); assert.deepEqual(fixture.apiCalls, [])
})

console.log(`SUMMARY ${passed} PASS / 0 FAIL. Actual TSX redirect and demo interactions executed with API spies; no synthetic REMIX completion is published.`)
