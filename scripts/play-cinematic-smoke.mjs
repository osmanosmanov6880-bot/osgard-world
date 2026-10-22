import assert from 'node:assert/strict'
import { readFile, mkdir, mkdtemp, writeFile, rm } from 'node:fs/promises'
import { createRequire } from 'node:module'
import path from 'node:path'
import { runInNewContext } from 'node:vm'
import { build } from 'esbuild'

// Checks public assets and server-rendered contracts without starting a browser
// or a server. Runtime gameplay is verified separately in the actual browser.
const root = process.cwd()
const failures = []
function check(value, message) { if (!value) failures.push(message) }
function attr(tag, name) {
  return new RegExp('\\b' + name + '="([^"]*)"').exec(tag)?.[1]
    ?.replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&#x27;|&#39;/g, "'")
}
const tags = (html, name) => html.match(new RegExp('<' + name + '\\b[^>]*>', 'g')) || []
function catalogCards(html) {
  const catalog = /<section\b[^>]*\bid="catalog"[^>]*>([\s\S]*?)<\/section>/.exec(html)?.[1] || ''
  return [...catalog.matchAll(/<article\b([^>]*)>([\s\S]*?)<\/article>/g)]
    .map(match => ({ id: attr(match[1], 'data-world-id'), html: match[0] }))
}

function webpDimensions(bytes) {
  assert.equal(bytes.toString('ascii', 0, 4), 'RIFF', 'WebP RIFF signature')
  assert.equal(bytes.toString('ascii', 8, 12), 'WEBP', 'WebP format signature')
  for (let offset = 12; offset + 8 <= bytes.length;) {
    const kind = bytes.toString('ascii', offset, offset + 4)
    const length = bytes.readUInt32LE(offset + 4)
    const start = offset + 8
    assert.ok(start + length <= bytes.length, 'Complete WebP chunk')
    if (kind === 'VP8X' && length >= 10) {
      return [bytes.readUIntLE(start + 4, 3) + 1, bytes.readUIntLE(start + 7, 3) + 1]
    }
    if (kind === 'VP8L' && length >= 5) {
      assert.equal(bytes[start], 0x2f, 'Lossless WebP signature')
      const bits = bytes.readUInt32LE(start + 1)
      return [(bits & 0x3fff) + 1, ((bits >>> 14) & 0x3fff) + 1]
    }
    if (kind === 'VP8 ' && length >= 10) {
      assert.deepEqual([...bytes.subarray(start + 3, start + 6)], [0x9d, 0x01, 0x2a], 'VP8 keyframe')
      return [bytes.readUInt16LE(start + 6) & 0x3fff, bytes.readUInt16LE(start + 8) & 0x3fff]
    }
    offset = start + length + (length & 1)
  }
  throw new Error('Missing WebP dimension chunk')
}

const renderSource = [
  "import React from 'react'",
  "import { renderToPipeableStream } from 'react-dom/server'",
  "import { Writable } from 'node:stream'",
  "import { BrandShell } from './src/BrandShell'",
  "import PlayHome from './src/PlayHome'",
  "import PlayGameRoute from './src/PlayGameRoute'",
  "export { playGames } from './src/redesignCatalog'",
  "export { gameArtwork } from './src/playCinematicData'",
  "export { playReturnHref } from './src/playFilters'",
  "function renderComplete(element) {",
  "  return new Promise((resolve, reject) => {",
  "    const chunks = []",
  "    let settled = false",
  "    let renderer",
  "    const destination = new Writable({",
  "      write(chunk, _encoding, callback) { chunks.push(Buffer.from(chunk)); callback() },",
  "    })",
  "    const timer = setTimeout(() => fail(new Error('Full React SSR did not finish within 10 seconds')), 10000)",
  "    function fail(error) {",
  "      if (settled) return",
  "      settled = true",
  "      clearTimeout(timer)",
  "      renderer?.abort()",
  "      destination.destroy()",
  "      reject(error)",
  "    }",
  "    destination.on('error', fail)",
  "    destination.on('finish', () => {",
  "      if (settled) return",
  "      settled = true",
  "      clearTimeout(timer)",
  "      resolve(Buffer.concat(chunks).toString('utf8'))",
  "    })",
  "    try {",
  "      renderer = renderToPipeableStream(element, {",
  "        onAllReady() { if (!settled) renderer.pipe(destination) },",
  "        onError: fail,",
  "        onShellError: fail,",
  "      })",
  "    } catch (error) { fail(error) }",
  "  })",
  "}",
  "export async function renderPlay(gameId, search = '', partners = false) {",
  "  const pathname = partners ? '/play/partners' : gameId ? '/play/world/' + gameId : '/play'",
  "  globalThis.location = { pathname, search, hash: '', origin: 'https://osgard.world' }",
  "  globalThis.localStorage = { getItem: () => null }",
  "  return renderComplete(",
  "    <BrandShell theme={partners ? 'world' : 'play'}>",
  "      {gameId ? <PlayGameRoute gameId={gameId} /> : <PlayHome partners={partners} />}",
  "    </BrandShell>",
  "  )",
  "}",
].join('\n')

await mkdir(path.join(root, 'node_modules/.tmp'), { recursive: true })
const temporary = await mkdtemp(path.join(root, 'node_modules/.tmp/play-cinematic-'))
try {
  const rendered = await build({
    stdin: { contents: renderSource, resolveDir: root, loader: 'tsx' },
    bundle: true, format: 'cjs', platform: 'node', packages: 'external',
    write: false, metafile: true, loader: { '.css': 'empty' }, jsx: 'automatic',
  })
  const output = path.join(temporary, 'render.cjs')
  await writeFile(output, rendered.outputFiles[0].text)
  const { renderPlay, playGames, gameArtwork, playReturnHref } = createRequire(import.meta.url)(output)
  const ids = playGames.map(game => game.id)
  check(ids.length === 19 && new Set(ids).size === 19, 'Catalogue must retain nineteen unique game IDs')
  const bundledInputs = Object.keys(rendered.metafile.inputs)
  check(!bundledInputs.some(file => /(?:TimePrototype|InheritPrototype|RemixPrototype|OnlineGamePrototype)\.tsx$/.test(file) || file.startsWith('public/games/')),
    'Rendering the catalogue must not import a playable runtime')

  const catalogueBundle = await build({
    entryPoints: [path.join(root, 'src/PlayHome.tsx')], bundle: true,
    format: 'esm', platform: 'browser', packages: 'external',
    write: false, metafile: true, loader: { '.css': 'empty' }, jsx: 'automatic',
  })
  // A dynamic import appears in esbuild's complete inputs but is absent from
  // the initial synchronous module graph. Walk actual import edges from home.
  const catalogueInputs = catalogueBundle.metafile.inputs
  const homeEntry = Object.keys(catalogueInputs).find(file => path.resolve(root, file) === path.join(root, 'src/PlayHome.tsx'))
  assert.ok(homeEntry, 'The catalogue metafile must identify its actual entry')
  const eagerInputs = new Set()
  const synchronousKinds = new Set(['import-statement', 'require-call', 'import-rule'])
  function visitEager(file) {
    if (eagerInputs.has(file)) return
    eagerInputs.add(file)
    for (const dependency of catalogueInputs[file].imports) {
      if (!dependency.external && synchronousKinds.has(dependency.kind) && catalogueInputs[dependency.path]) visitEager(dependency.path)
    }
  }
  visitEager(homeEntry)
  check(![...eagerInputs].some(file => /(?:PlayExploreSections|PlayGameRoute|PlayGameDetail)\.tsx$/.test(file)),
    'The initial catalogue dependency graph must exclude below-fold sections and the game session controller')
  check([...eagerInputs].some(file => catalogueInputs[file].imports.some(dependency =>
    dependency.kind === 'dynamic-import' && /PlayExploreSections\.tsx$/.test(dependency.path))),
  'Below-fold sections must be reached through an actual dynamic import')

  let verifiedAssets = 0
  for (const game of playGames) {
    const art = gameArtwork(game)
    check(art.src === '/brand/play/' + game.id + '.webp', game.id + ': cover must use its own game ID')
    const candidates = art.srcSet.split(',').map(value => value.trim().split(/\s+/))
    const expectedCandidates = new Map([
      ['/brand/play/' + game.id + '-640.webp', '640w'],
      ['/brand/play/' + game.id + '.webp', '1536w'],
    ])
    check(candidates.length === 2 && new Set(candidates.map(([url]) => url)).size === 2 &&
      candidates.every(([url, descriptor]) => expectedCandidates.get(url) === descriptor),
    game.id + ': its own thumbnail and full-size srcset candidates are required')
    for (const [url, descriptor] of candidates) {
      try {
        assert.ok(/^\/brand\/play\/[a-z0-9-]+\.webp$/.test(url), 'Cover must be a local public WebP')
        const bytes = await readFile(path.join(root, 'public', url))
        const dimensions = webpDimensions(bytes)
        const expected = descriptor === '640w' ? [640, 427] : descriptor === '1536w' ? [1536, 1024] : null
        assert.ok(expected, 'Only accurate 640w and 1536w cover descriptors are supported')
        assert.deepEqual(dimensions, expected, 'Cover dimensions must match srcset and the 3:2 artwork')
        verifiedAssets++
      } catch (error) { failures.push(game.id + ': ' + url + ': ' + error.message) }
    }
  }

  const catalog = await renderPlay()
  const cards = catalogCards(catalog)
  check(tags(catalog, 'h1').length === 1, 'Catalogue must have one primary heading')
  check(cards.length === 19, 'Full catalogue must render nineteen semantic articles')
  check(new Set(cards.map(card => card.id)).size === 19, 'Catalogue articles must not duplicate game IDs')
  check(tags(catalog, 'iframe').length === 0, 'Catalogue must not load any game browsing context')
  for (const game of playGames) {
    const card = cards.find(item => item.id === game.id)
    if (!card) { failures.push(game.id + ': missing catalogue article'); continue }
    const links = tags(card.html, 'a')
    check(links.some(tag => attr(tag, 'href')?.startsWith('/play/world/' + game.id + '?back=')), game.id + ': card must link to its real detail route')
    check(tags(card.html, 'img').some(tag => attr(tag, 'src') === gameArtwork(game).src && attr(tag, 'loading') === 'lazy'),
      game.id + ': card needs its own lazily loaded cover')
    check(tags(card.html, 'button').some(tag => attr(tag, 'aria-pressed') === 'false' && Boolean(attr(tag, 'aria-label'))),
      game.id + ': favorite control needs an accessible name and pressed state')
  }

  for (const [search, expected] of [
    ['?q=VECTOR', ['vector-zero']],
    ['?genre=' + encodeURIComponent('Стратегия'), ['time', 'empire-orbit']],
    ['?mode=service', ['remix']],
    ['?view=favorites', []],
    ['?view=recent', []],
  ]) {
    const actual = catalogCards(await renderPlay(undefined, search)).map(card => card.id).sort()
    check(JSON.stringify(actual) === JSON.stringify([...expected].sort()), 'SSR filters must apply URL state: ' + search)
  }

  const returnCatalog = '/play?q=VECTOR&mode=solo#catalog'
  const search = '?back=' + encodeURIComponent(returnCatalog)
  const genres = [...new Set(playGames.map(game => game.genre))]
  const expectedReturn = playReturnHref(search, genres)
  for (const game of playGames) {
    const html = await renderPlay(game.id, search)
    check(tags(html, 'h1').length === 1, game.id + ': detail requires one primary heading')
    check(tags(html, 'section').some(tag => attr(tag, 'id') === 'play-session' && attr(tag, 'data-session-phase') === 'idle'),
      game.id + ': detail starts in the idle session phase')
    check(tags(html, 'iframe').length === 0, game.id + ': game must wait for explicit user launch')
    check(tags(html, 'button').some(tag => attr(tag, 'data-game-launch') === game.id && attr(tag, 'aria-controls') === 'play-session'),
      game.id + ': launch button must identify its game and controlled session')
    check(tags(html, 'a').some(tag => attr(tag, 'href') === expectedReturn), game.id + ': detail must preserve a safe filtered return URL')
    if (game.launchable) check(tags(html, 'a').some(tag => attr(tag, 'href') === game.href && attr(tag, 'target') === '_blank' && /\bnoopener\b/.test(attr(tag, 'rel') || '')),
      game.id + ': original direct launch remains available without opener access')
    if (game.alternate) check(tags(html, 'a').some(tag => attr(tag, 'href') === game.alternate.href), game.id + ': alternate runtime link must remain')
    check(tags(html, 'div').some(tag => attr(tag, 'role') === 'status' && attr(tag, 'aria-live') === 'polite'),
      game.id + ': session status must be announced accessibly')
  }
  const missing = await renderPlay('not-an-existing-world')
  check(tags(missing, 'h1').length === 1 && !tags(missing, 'button').some(tag => attr(tag, 'data-game-launch')),
    'Unknown worlds must have a non-playable, accessible fallback')

  // Execute the actual effect with a minimal non-browser host. This catches a
  // lost fallback without relying on source-string or marketing-copy assertions.
  const motion = await build({
    entryPoints: [path.join(root, 'src/PlayMotion.tsx')], bundle: true,
    format: 'cjs', platform: 'node', write: false,
    plugins: [{
      name: 'effect-harness',
      setup(builder) {
        builder.onResolve({ filter: /^react$/ }, () => ({ path: 'effect', namespace: 'effect-harness' }))
        builder.onLoad({ filter: /.*/, namespace: 'effect-harness' }, () => ({
          contents: 'export function useEffect(effect) { globalThis.cleanup = effect() }', loader: 'js',
        }))
      },
    }],
  })
  for (const apiState of ['absent', 'undefined']) {
    const visible = Array.from({ length: 6 }, () => new Set())
    const host = {
      dataset: {}, style: { setProperty() {} },
      querySelectorAll: () => visible.map(classes => ({ classList: { add: value => classes.add(value) } })),
      querySelector: () => null, addEventListener() {}, removeEventListener() {},
    }
    const media = { matches: false, addEventListener() {}, removeEventListener() {} }
    const windowStub = { matchMedia: () => media }
    if (apiState === 'undefined') windowStub.IntersectionObserver = undefined
    const module = { exports: {} }
    const context = {
      module, exports: module.exports, window: windowStub, navigator: {},
      document: { documentElement: { dataset: { motion: 'on' } }, addEventListener() {}, removeEventListener() {} },
      MutationObserver: class { observe() {} disconnect() {} },
      cancelAnimationFrame() {}, requestAnimationFrame() { return 1 },
    }
    runInNewContext(motion.outputFiles[0].text, context)
    module.exports.usePlayMotion({ current: host })
    check(visible.every(classes => classes.has('is-visible')), 'Every reveal section must be visible when IntersectionObserver is ' + apiState)
    context.cleanup?.()
  }

  if (failures.length) {
    console.error('PLAY cinematic smoke failed (' + failures.length + '):\n' + failures.map(message => '- ' + message).join('\n'))
    process.exitCode = 1
  } else {
    console.log('PLAY cinematic smoke passed: ' + verifiedAssets + ' WebP files and dimensions; nineteen semantic cards; URL filters; nineteen idle/lazy detail pages with direct/alternate launches; separate catalogue/session dependency graphs; observer fallback.')
  }
} finally {
  await rm(temporary, { recursive: true, force: true })
}
