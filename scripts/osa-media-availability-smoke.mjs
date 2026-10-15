import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import ts from 'typescript'
import vm from 'node:vm'
function load(path, dependencies = {}) {
  const source = readFileSync(path, 'utf8')
  const compiled = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }).outputText
  const module = { exports: {} }
  vm.runInNewContext(compiled, { module, exports: module.exports, URL, URLSearchParams, require(name) {
    if (Object.prototype.hasOwnProperty.call(dependencies, name)) return dependencies[name]
    throw new Error('Unexpected import ' + name)
  } }, { filename: path })
  return module.exports
}
const url = load('src/osaMediaUrl.ts')
const lessons = load('src/osaLessonGuides.ts')
const catalog = load('src/osaMediaCatalog.ts', { './osaLessonGuides': lessons, './osaMediaUrl': url })
assert.equal(lessons.OSA_LESSON_SLUGS.length, 8)
for (const locale of ['ru', 'en']) {
  const summary = catalog.getOSALessonMediaSummary(locale)
  assert.equal(summary.totalLessons, 8)
  assert.equal(summary.lessons.length, 8)
  assert.equal(summary.playableAudio, 0, 'No approved audio sources yet')
  assert.equal(summary.playableVideo, 0, 'No approved video sources yet')
  assert.equal(summary.invalidSources, 0)
  for (const row of summary.lessons) {
    assert.equal(row.audio, 'not_published')
    assert.equal(row.video, 'not_published')
  }
}
assert.equal(catalog.getOSAMediaAvailability(null), 'not_published')
assert.equal(catalog.getOSAMediaAvailability({src: 'https://example.com/audio.mp3?token=secret'}), 'invalid_source')
assert.equal(catalog.getOSAMediaAvailability({src: '/osa-media/approved.mp3'}), 'available')
console.log('OSA_MEDIA_AVAILABILITY_PASS: 16 lesson-language records, no fabricated media, safe URL classification')
