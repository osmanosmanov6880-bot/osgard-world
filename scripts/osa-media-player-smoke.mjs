import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { isPermanentMediaUrl } from '../src/osaMediaUrl.ts'

const player = readFileSync('src/OSAMediaPlayer.tsx', 'utf8')
const catalog = readFileSync('src/osaMediaCatalog.ts', 'utf8')
const lessonGuides = readFileSync('src/osaLessonGuides.ts', 'utf8')
const lessonPage = readFileSync('src/OSALessonPage.tsx', 'utf8')
const cinema = readFileSync('src/OSACinema.tsx', 'utf8')
const packageJson = JSON.parse(readFileSync('package.json', 'utf8'))

assert.equal(isPermanentMediaUrl('/osa-media/lesson-01.mp3'), true, 'same-origin static media paths should be accepted')
assert.equal(isPermanentMediaUrl('https://cdn.example.org/osa/lesson-01.mp3'), true, 'durable HTTPS media should be accepted')
assert.equal(isPermanentMediaUrl('http://cdn.example.org/lesson.mp3'), false, 'external media must use HTTPS')
assert.equal(isPermanentMediaUrl('javascript:alert(1)'), false, 'script URLs must be rejected')
assert.equal(isPermanentMediaUrl('//untrusted.example.org/lesson.mp3'), false, 'protocol-relative URLs must be rejected')
assert.equal(isPermanentMediaUrl('https://user:pass@cdn.example.org/lesson.mp3'), false, 'embedded URL credentials must be rejected')
assert.equal(isPermanentMediaUrl('https://cdn.example.org/lesson.mp3?_jwt=temporary'), false, 'Runway signed URLs must be rejected')
assert.equal(isPermanentMediaUrl('https://cdn.example.org/lesson.mp3?token=temporary'), false, 'temporary token URLs must be rejected')
assert.equal(isPermanentMediaUrl('/media/lesson.mp3?X-Amz-Signature=temporary'), false, 'signed object-storage URLs must be rejected')
assert.equal(isPermanentMediaUrl(null), false, 'missing media is not playable')
assert.equal(isPermanentMediaUrl(' /osa-media/lesson.mp3'), false, 'leading whitespace must be rejected')
assert.equal(isPermanentMediaUrl('/osa-media/lesson.mp3 '), false, 'trailing whitespace must be rejected')
assert.equal(isPermanentMediaUrl('/osa-media/lesson.mp3' + String.fromCharCode(10)), false, 'newlines must be rejected')
assert.equal(isPermanentMediaUrl('/osa-media/%2e%2e/secret.mp3'), false, 'encoded parent traversal must be rejected')
assert.equal(isPermanentMediaUrl('/osa-media/%2Fsecret.mp3'), false, 'encoded path separators must be rejected')
assert.equal(isPermanentMediaUrl('/osa-media/%5csecret.mp3'), false, 'encoded backslashes must be rejected')
assert.equal(isPermanentMediaUrl('/osa-media/%ZZ.mp3'), false, 'malformed percent encoding must be rejected')

for (const slug of [
  'intelligence-and-imitation',
  'how-language-models-work',
  'power-of-knowledge',
  'signal-and-noise',
  'verify-an-ai-answer',
  'privacy-before-prompting',
  'human-in-the-loop',
  'investigate-the-future',
]) assert.ok(lessonGuides.includes(slug), 'canonical lesson source should include ' + slug)

assert.ok(catalog.includes('src: null'), 'media must remain unpublished until a durable source is assigned')
assert.ok(catalog.includes('OSA_LESSON_SLUGS.map(slug => [slug, createPendingLesson(slug)]'), 'media catalogue must derive from the canonical lesson registry')
assert.ok(!/https:\/\/[^\s"'<>]+(?:_jwt=|token=|signature=)/i.test(catalog), 'temporary signed delivery URLs must never be committed')
assert.ok(player.includes('playbackRate') && player.includes('[0.75, 1, 1.25, 1.5, 1.75, 2]'), 'player should apply the selected playback speeds')
assert.ok(player.includes('localStorage') && player.includes('loadedmetadata'), 'player must restore the prior playback position when metadata loads')
assert.ok(player.includes('kind="captions"') && player.includes('aria-label={copy.seek}'), 'caption tracks and an accessible seek control should be supported')
assert.ok(player.includes('onError') && player.includes('role="alert"'), 'failed media must show an accessible error state')
assert.ok(player.includes('if (!media || !media.src) return null'), 'no player controls should be shown without a configured file')
assert.ok(lessonPage.includes("getOSALessonMedia(slug, locale, 'audio')"), 'lesson detail should mount its configured audio resource')
assert.ok(lessonPage.includes("getOSALessonMedia(slug, locale, 'video')"), 'lesson detail should mount its configured video resource')
assert.ok(cinema.includes("getOSACinemaMedia(index,locale,'audio')"), 'cinema scenes should resolve the matching audio resource')
assert.ok(cinema.includes("getOSACinemaMedia(index,locale,'video')"), 'cinema scenes should resolve the matching video resource')
assert.equal(packageJson.scripts['qa:osa-media'], 'node --experimental-strip-types scripts/osa-media-player-smoke.mjs', 'media smoke test must be available from npm')

console.log('OSA_MEDIA_PLAYER_PASS: permanent URL policy, eight lesson bindings, resume, speed, seek, captions, error states, and honest empty-media behaviour verified.')
