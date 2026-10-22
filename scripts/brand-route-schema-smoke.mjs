import assert from 'node:assert/strict'
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

// Run the real route builder in a temporary fixture. No production dist or
// product source is rewritten, and the initial schema needs no runtime import.
const repo = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const temporary = mkdtempSync(join(tmpdir(), 'osgard-route-schema-'))
const previousDirectory = process.cwd()
const scripts = html => [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)]
  .filter(match => /\btype=["']application\/ld\+json["']/.test(match[1]))
  .map(match => ({ route: /\bdata-route-seo(?:\s|=|$)/.test(match[1]), data: JSON.parse(match[2]) }))
const decode = text => text.replaceAll('&quot;', '"').replaceAll('&lt;', '<').replaceAll('&amp;', '&')

try {
  mkdirSync(join(temporary, 'src')); mkdirSync(join(temporary, 'dist'))
  copyFileSync(join(repo, 'src/redesignCatalog.ts'), join(temporary, 'src/redesignCatalog.ts'))
  copyFileSync(join(repo, 'src/featuredCases.ts'), join(temporary, 'src/featuredCases.ts'))
  copyFileSync(join(repo, 'index.html'), join(temporary, 'dist/index.html'))
  // Breadcrumb names are small and eager; full game definitions stay lazy.
  // Enforce exact title parity so an added game never receives a stale label.
  const gameCatalogText = readFileSync(join(repo, 'src/redesignCatalog.ts'), 'utf8')
  const lightweightTitlesText = readFileSync(join(repo, 'src/playGameTitles.ts'), 'utf8')
  const catalogTitles = [...gameCatalogText.matchAll(/"id":\s*"([^"]+)"\s*,\s*"title":\s*"([^"]+)"/g)]
    .map((match) => [match[1], match[2]])
  const breadcrumbTitles = [...lightweightTitlesText.matchAll(/^\s*"([^"]+)": "([^"]+)",/gm)]
    .map((match) => [match[1], match[2]])
  assert.equal(catalogTitles.length, 19, 'Expected all nineteen source game titles')
  assert.deepEqual(breadcrumbTitles, catalogTitles, 'Breadcrumb metadata must match source game titles')
  assert.ok(gameCatalogText.includes("export { cases } from './featuredCases'"), 'Case cards must have one source')
  const rootSchemas = scripts(readFileSync(join(repo, 'index.html'), 'utf8'))
  const originalGraph = rootSchemas.find(schema => Array.isArray(schema.data['@graph']))?.data
  assert.ok(originalGraph, 'root Organization/WebSite graph is required')
  assert.equal(rootSchemas.filter(schema => schema.route).length, 1, 'initial root must contain one WebPage schema')
  process.chdir(temporary)
  await import(pathToFileURL(join(repo, 'scripts/build-brand-routes.mjs')).href)
  const pages = readdirSync(join(temporary, 'dist'), { recursive: true }).filter(name => name === 'index.html' || name.endsWith('/index.html'))
  assert.equal(pages.length, 83, 'root plus all 82 generated route shells are checked')
  for (const file of pages) {
    const html = readFileSync(join(temporary, 'dist', file), 'utf8'), data = scripts(html)
    const pageSchemas = data.filter(schema => schema.route)
    assert.equal(pageSchemas.length, 1, file + ': duplicate or missing route schema')
    const page = pageSchemas[0].data
    assert.equal(page['@type'], 'WebPage', file)
    assert.equal(page['@context'], 'https://schema.org', file)
    assert.equal(page.url, /<link rel="canonical" href="([^"]+)"/.exec(html)?.[1], file + ': canonical/schema mismatch')
    assert.ok(page.name && page.description, file + ': incomplete WebPage schema')
    if (file !== 'index.html') {
      assert.equal(page.name, decode(/<title>([\s\S]*?)<\/title>/.exec(html)[1]), file + ': wrong route name')
      assert.equal(page.description, decode(/<meta name="description" content="([^"]*)"/.exec(html)[1]), file + ': wrong route description')
    }
    assert.equal(page.isPartOf?.['@type'], 'WebSite', file)
    assert.equal(page.isPartOf?.url, 'https://osgard.world/', file)
    assert.deepEqual(data.find(schema => Array.isArray(schema.data['@graph']))?.data, originalGraph, file + ': Organization/WebSite graph changed')
  }
  console.log('PASS: initial WebPage JSON-LD in 83 real generated shells; route titles/descriptions/canonical aliases match, Organization/WebSite graph preserved')
} finally {
  process.chdir(previousDirectory)
  rmSync(temporary, { recursive: true, force: true })
}
