import assert from 'node:assert/strict'
import { readFile, writeFile } from 'node:fs/promises'
import { resolve } from 'node:path'

const MAIN_LINK = '<link rel="stylesheet" href="/skillcred/styles.css">'
const BRAND_LINK = '<link rel="stylesheet" href="/brand/osa5-portals.css">'
const BUNDLED_MARKER = '<!-- SkillCred: shared brand styles are bundled in styles.css. -->'
const mainSourcePath = resolve('public/skillcred/styles.css')
const brandSourcePath = resolve('public/brand/osa5-portals.css')
const htmlPath = resolve('dist/skillcred/index.html')
const outputPath = resolve('dist/skillcred/styles.css')

function occurrences(text, value) {
  return text.split(value).length - 1
}

function validateCss(source, label) {
  assert.ok(source.length > 0, `${label}: stylesheet must not be empty`)
  const css = source.toString('utf8').replace(/\/\*[\s\S]*?\*\//g, '')
  // Imports and namespace/charset declarations cannot be relocated by concatenation.
  assert.ok(!/@(?:import|charset|namespace)\b/i.test(css), `${label}: review CSS directives before bundling`)
  // Fail closed on escaped syntax instead of guessing how it resolves after relocation.
  assert.ok(!css.includes('\\'), `${label}: review escaped CSS syntax before bundling`)
  assert.ok(!/\b(?:image-set|src)\s*\(/i.test(css), `${label}: review indirect asset references before bundling`)
  const urlStarts = css.match(/\burl\s*\(/gi) || []
  const urls = [...css.matchAll(/\burl\s*\(\s*(?:"([^"\n]*)"|'([^'\n]*)'|([^\s"'()]*))\s*\)/gi)]
  assert.equal(urls.length, urlStarts.length, `${label}: unsupported CSS url() syntax`)
  for (const match of urls) {
    const url = match[1] ?? match[2] ?? match[3]
    assert.ok(/^(?:\/(?!\/)|https?:\/\/|data:)/i.test(url), `${label}: relative CSS URLs must be made absolute before bundling`)
  }
}

function bundleHtml(html) {
  // Commented-out links are not active stylesheets. Keep offsets unchanged.
  const linkedHtml = html.replace(/<!--[\s\S]*?-->/g, comment => ' '.repeat(comment.length))
  const headStart = linkedHtml.indexOf('<head>')
  const headEnd = linkedHtml.indexOf('</head>')
  assert.ok(headStart >= 0 && headEnd > headStart, 'SkillCred: expected one ordinary document head')
  assert.equal(occurrences(linkedHtml, '<head>'), 1, 'SkillCred: ambiguous document head')
  assert.equal(occurrences(linkedHtml, '</head>'), 1, 'SkillCred: ambiguous document head end')
  assert.equal(occurrences(linkedHtml, MAIN_LINK), 1, 'SkillCred: expected exactly one unchanged main stylesheet link')
  const mainIndex = linkedHtml.indexOf(MAIN_LINK)
  assert.ok(mainIndex > headStart && mainIndex < headEnd, 'SkillCred: main stylesheet must remain in the document head')

  // Only the two known blocking stylesheets are supported. Extra attributes,
  // alternate stylesheets, preloads, or versioned CSS links need explicit review.
  const links = [...linkedHtml.matchAll(/<link\b(?:[^>"']|"[^"]*"|'[^']*')*>/gi)]
  const cssLinks = links.filter(([tag]) => /\bstylesheet\b|\.css(?:[\s"'?#>]|$)/i.test(tag))
  for (const [tag] of cssLinks) {
    assert.ok(tag === MAIN_LINK || tag === BRAND_LINK, 'SkillCred: unexpected CSS linkage; refusing to change the cascade')
  }
  const brandCount = occurrences(linkedHtml, BRAND_LINK)
  const markerCount = occurrences(html, BUNDLED_MARKER)
  assert.ok(
    (brandCount === 1 && markerCount === 0) || (brandCount === 0 && markerCount === 1),
    'SkillCred: expected one brand stylesheet link or one previous bundle marker',
  )
  assert.equal(cssLinks.length, brandCount + 1, 'SkillCred: ambiguous stylesheet links')
  const brandIndex = brandCount ? linkedHtml.indexOf(BRAND_LINK) : html.indexOf(BUNDLED_MARKER)
  assert.ok(brandIndex > mainIndex && brandIndex < headEnd, 'SkillCred: brand styles must follow main styles in the document head')
  assert.ok(!/<style\b/i.test(linkedHtml.slice(mainIndex + MAIN_LINK.length, brandIndex)), 'SkillCred: interposed inline styles require cascade review before bundling')
  return brandCount ? html.slice(0, brandIndex) + BUNDLED_MARKER + html.slice(brandIndex + BRAND_LINK.length) : html
}

const [mainCss, brandCss, html] = await Promise.all([
  readFile(mainSourcePath),
  readFile(brandSourcePath),
  readFile(htmlPath, 'utf8'),
])
validateCss(mainCss, mainSourcePath)
validateCss(brandCss, brandSourcePath)
const bundledHtml = bundleHtml(html)
// Always use public sources: reruns never append to an already bundled/minified file.
const bundledCss = Buffer.concat([mainCss, Buffer.from('\n'), brandCss])
// Validate everything before writing; write CSS before removing its separate link.
await writeFile(outputPath, bundledCss)
if (bundledHtml !== html) await writeFile(htmlPath, bundledHtml)
console.log(JSON.stringify({
  status: 'ready',
  stylesheet: outputPath,
  mainBytes: mainCss.length,
  brandBytes: brandCss.length,
  bundledBytes: bundledCss.length,
  separateBrandStylesheetRemoved: true,
}))
