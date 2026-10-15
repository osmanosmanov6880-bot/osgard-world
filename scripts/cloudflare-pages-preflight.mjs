import assert from 'node:assert/strict'
import { readdir, readFile, stat } from 'node:fs/promises'
import { join, relative, resolve } from 'node:path'

const root = resolve(process.argv[2] || 'dist')
const required = [
  'index.html', '_headers', '_redirects', 'robots.txt', 'sitemap.xml',
  'brand/osa-transition.js', 'games/index.html', 'games/ecosystem-intermission.js',
  'games/null-shift-godot/index.html', 'skillcred/index.html', 'privacy/index.html',
  'terms/index.html', 'entertainment/index.html', 'entertainment/noir-auto/index.html',
  'entertainment/noir-auto/en/index.html', 'entertainment/noir-auto/ar/index.html',
  'entertainment/noir-auto/og.svg', 'development/index.html',
  // TEDES standalone studio, catalog, project tools, and portfolio case.
  'tedes/index.html',
  'tedes/assets/hero-door.webp',
  'tedes/assets/architecture-scene.webp',
  'tedes/catalog/index.html',
  'tedes/collections/index.html',
  'tedes/product/index.html',
  'tedes/materials/index.html',
  'tedes/print/index.html',
  'tedes/project/index.html',
  'tedes/project/project-workspace.js',
  'tedes/data/catalog.v1.json',
  'development/tedes/index.html',
]

for (const rel of required) {
  const full = join(root, rel)
  try {
    const info = await stat(full)
    assert.ok(info.isFile(), 'Required deployment path is not a file: ' + rel)
    assert.ok(info.size > 0, 'Required deployment file is empty: ' + rel)
    if (rel.startsWith('tedes/assets/') && rel.endsWith('.webp')) {
      assert.ok(info.size > 1000, 'TEDES WebP asset is unexpectedly small: ' + rel)
    }
  } catch (error) {
    throw new Error('Cloudflare Pages artifact is missing ' + rel + ': ' + (error instanceof Error ? error.message : 'unknown error'))
  }
}

// The Pages config is source configuration, not a runtime secret.
const wrangler = await readFile(resolve('wrangler.jsonc'), 'utf8')
assert.match(wrangler, /"name"\s*:\s*"osgard-world"/, 'Wrangler Pages project name must match the configured Pages project')
assert.match(wrangler, /"pages_build_output_dir"\s*:\s*"\.\/dist"/, 'Wrangler Pages output directory must be ./dist')
assert.match(wrangler, /"compatibility_date"\s*:\s*"\d{4}-\d{2}-\d{2}"/, 'Wrangler compatibility date must be an explicit ISO date')

const headers = await readFile(join(root, '_headers'), 'utf8')
assert.ok(headers.includes('X-Content-Type-Options: nosniff'), '_headers must include nosniff')
assert.ok(headers.includes('Referrer-Policy: strict-origin-when-cross-origin'), '_headers must include a safe referrer policy')
assert.ok(headers.includes('/index.html'), '_headers must prevent stale root HTML')
const redirects = await readFile(join(root, '_redirects'), 'utf8')
assert.ok(redirects.includes('/games/time-empire /games/time 301'), 'Legacy time-empire route redirect is missing')
assert.ok(redirects.includes('/games/time-empire/ /games/time 301'), 'Legacy time-empire slash route redirect is missing')

const maxFiles = Number(process.env.CLOUDFLARE_PAGES_MAX_FILES || 20000)
const maxAssetBytes = 25 * 1024 * 1024
const files = []
async function walk(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name)
    if (entry.isDirectory()) await walk(path)
    else if (entry.isFile()) {
      const info = await stat(path)
      files.push({ path, size: info.size })
      assert.ok(info.size <= maxAssetBytes, 'Cloudflare Pages asset exceeds 25 MiB: ' + relative(root, path) + ' (' + info.size + ' bytes)')
      const rel = relative(root, path).replaceAll('\\\\', '/')
      assert.ok(!/(^|\\/)\\.env(?:\\.|$)|(^|\\/)(?:id_rsa|id_ed25519|credentials\\.json)(?:$|\\.)/i.test(rel),
        'Potential secret file must not be deployed: ' + rel)
    }
  }
}
await walk(root)
assert.ok(files.length <= maxFiles, 'Cloudflare Pages file count ' + files.length + ' exceeds configured limit ' + maxFiles)

const totalBytes = files.reduce((sum, file) => sum + file.size, 0)
const largest = files.slice().sort((a, b) => b.size - a.size).slice(0, 5)
console.log(JSON.stringify({
  status: 'ready-for-static-pages-deploy',
  files: files.length,
  totalBytes,
  maxFiles,
  maxAssetBytes,
  largestAssets: largest.map(file => ({ path: relative(root, file.path).replaceAll('\\\\', '/'), bytes: file.size })),
  requiredStaticRoutes: required.length,
  tedesRoutes: required.filter(path => path.startsWith('tedes/') || path.startsWith('development/tedes/')),
  note: 'Static files only: current container-backed API, WebSocket, SSE and game-session routes still need an origin/Worker proxy before production DNS is moved.',
}, null, 2))
