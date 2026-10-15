import assert from 'node:assert/strict'
import { readFileSync, existsSync } from 'node:fs'
import { join } from 'node:path'

const root = 'cloudflare/essentia'
const read = name => {
  const path = join(root, name)
  assert.ok(existsSync(path), `Missing Cloudflare Pages file: ${path}`)
  return readFileSync(path, 'utf8')
}
const html = read('index.html')
const css = read('store.css')
const js = read('store.js')
const og = read('og.svg')
const headers = read('_headers')
const redirects = read('_redirects')
const wrangler = read('wrangler.toml')
const readme = read('README.md')
assert.match(html, /href="\/store\.css"/)
assert.match(html, /src="\/store\.js"/)
assert.doesNotMatch(html, /href="\/development\/essentia\/store\.css"/)
assert.doesNotMatch(html, /src="\/development\/essentia\/store\.js"/)
assert.doesNotMatch(html, /rel="canonical"[^>]*osgard\.world/)
assert.match(css, /\.product-grid/)
assert.match(js, /ESSENTIA10/)
assert.match(js, /data-add/)
assert.match(js, /checkout/i)
assert.match(og, /<svg/)
assert.match(headers, /X-Content-Type-Options: nosniff/)
assert.match(headers, /Cache-Control/)
assert.match(redirects, /\/index\.html \/ 301/)
assert.match(wrangler, /pages_build_output_dir = "\."/)
assert.match(readme, /does not create or transmit orders/)
console.log('PASS ESSENTIA Cloudflare Pages bundle: standalone paths, storefront assets, headers, Wrangler config and demo-only checkout disclosure.')
