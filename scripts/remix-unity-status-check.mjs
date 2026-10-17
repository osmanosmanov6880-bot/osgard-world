import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { readFile, mkdtemp, mkdir, copyFile, writeFile, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

const runtimeFiles = ['REMIX-webgl3.data.gz', 'REMIX-webgl3.framework.js.gz', 'REMIX-webgl3.wasm.gz', 'REMIX-webgl3.loader.js']

async function verify(root) {
  const folder = join(root, 'games/remix/player')
  const status = JSON.parse(await readFile(join(folder, 'build-status.json'), 'utf8'))
  assert.equal(status.schemaVersion, 1, 'Unknown Unity status schema; review it explicitly')
  assert.equal(status.game, 'remix')
  assert.equal(status.availability, 'unavailable', 'Changing Unity availability requires scene and input evidence plus a reviewed launcher change')
  assert.equal(status.reason, 'inactive-main-scene')
  assert.equal(status.playableSceneVerified, false)
  assert.equal(status.defaultEngineDownload, false)
  assert.equal(status.diagnosticQuery, 'diagnostic=1')
  assert.deepEqual(Object.keys(status.runtimeSha256).sort(), [...runtimeFiles].sort(), 'The reviewed runtime inventory must be complete')
  const hashes = {}
  for (const name of runtimeFiles) {
    const bytes = await readFile(join(folder, 'Build', name))
    const actual = createHash('sha256').update(bytes).digest('hex')
    assert.equal(actual, status.runtimeSha256[name], `${name}: unknown or changed Unity build; review the actual engine, scene and input before updating status`)
    hashes[name] = actual
  }
  const html = await readFile(join(folder, 'index.html'), 'utf8')
  assert.ok(html.includes('data-unity-availability="unavailable"'), 'Default route must disclose unavailability')
  assert.ok(html.includes('data-gameplay-state="unavailable"'), 'Engine-ready must not imply gameplay-ready')
  assert.match(html, /if \(params\.get\('diagnostic'\) !== '1'\) return;/, 'Original runtime starts only in explicit diagnostic mode')
  assert.match(html, /id="unity-container"[^>]*\bhidden/, 'The unavailable route must hide the nonworking canvas before scripts execute')
  assert.ok(status.evidence?.originalRun && status.evidence?.originalArtifactSha256, 'A quarantine decision requires traceable runtime evidence')
  return { status: 'PASS', availability: 'unavailable', verification: 'Hash-pinned quarantine metadata and guarded launcher; this does not certify gameplay', hashes }
}

if (process.argv.includes('--self-test')) {
  const temporary = await mkdtemp(join(tmpdir(), 'osgard-unity-status-'))
  try {
    const target = join(temporary, 'games/remix/player')
    await mkdir(join(target, 'Build'), { recursive: true })
    for (const name of ['index.html', 'build-status.json']) await copyFile(join('public/games/remix/player', name), join(target, name))
    for (const name of runtimeFiles) await copyFile(join('public/games/remix/player/Build', name), join(target, 'Build', name))
    await verify(temporary)
    const file = join(target, 'Build', runtimeFiles[0])
    const original = await readFile(file)
    const changed = Buffer.from(original)
    changed[changed.length - 1] ^= 1
    await writeFile(file, changed)
    await assert.rejects(verify(temporary), /unknown or changed Unity build/)
    await writeFile(file, original)
    const statusPath = join(target, 'build-status.json')
    const status = JSON.parse(await readFile(statusPath, 'utf8'))
    status.availability = 'available'
    await writeFile(statusPath, JSON.stringify(status))
    await assert.rejects(verify(temporary), /Changing Unity availability requires/)
    console.log('PASS reviewed export; changed binary rejected; unreviewed availability change rejected')
  } finally {
    await rm(temporary, { recursive: true, force: true })
  }
} else {
  console.log(JSON.stringify(await verify(process.argv[2] || 'public'), null, 2))
}
