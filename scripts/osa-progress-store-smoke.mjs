import assert from 'node:assert/strict'
import { createOSALearningProgressStore, OSA_PROGRESS_STORAGE_KEY } from '../src/osaProgress.ts'

class MemoryStorage {
  data = new Map()
  getItem(key) { return this.data.has(key) ? this.data.get(key) : null }
  setItem(key, value) { this.data.set(key, String(value)) }
  removeItem(key) { this.data.delete(key) }
}

const storage = new MemoryStorage()
storage.setItem('osgard-osa-lesson-completion-v1', JSON.stringify([
  'intelligence-and-imitation',
  'power-of-knowledge',
  'not-a-real-lesson',
  'intelligence-and-imitation',
]))
storage.setItem('osgard-osa-cinema-progress-v1', JSON.stringify({
  version: 3,
  index: 5,
  locale: 'en',
  answers: { '0': 2, '1': 1, '5': 2, '99': 0 },
  completed: false,
  selfChecks: { '0': true, '1': false, '4': true },
}))
let changeEvents = 0
const store = createOSALearningProgressStore(storage, () => { changeEvents += 1 }, () => '2026-10-15T00:00:00.000Z')

let progress = store.read()
assert.deepEqual(progress.lessonCompletions, ['intelligence-and-imitation', 'power-of-knowledge'], 'legacy completions should be deduplicated and invalid slugs removed')
assert.equal(progress.cinema.index, 5, 'legacy cinema position should migrate')
assert.equal(progress.cinema.locale, 'en', 'legacy locale should migrate')
assert.deepEqual(progress.cinema.answers, { 0: 2, 5: 2 }, 'answers from invalid or non-choice scenes should be removed')
assert.deepEqual(progress.cinema.selfChecks, { 0: true, 1: false }, 'only the three recognised self-checks should migrate')
assert.ok(storage.getItem(OSA_PROGRESS_STORAGE_KEY), 'a canonical snapshot should be written during migration')

assert.equal(store.setLessonCompletion('human-in-the-loop', true), true, 'valid completion should persist')
assert.equal(store.setLessonCompletion('not-a-real-lesson', true), false, 'unknown lesson slugs should be rejected')
assert.equal(store.markLessonOpened('signal-and-noise'), true, 'last lesson should persist')
progress = store.read()
assert.equal(progress.lastLessonSlug, 'signal-and-noise', 'last opened lesson should be recorded')
assert.ok(progress.lessonCompletions.includes('human-in-the-loop'), 'completion update should preserve existing lessons')
assert.equal(progress.updatedAt, '2026-10-15T00:00:00.000Z', 'writes should carry a stable updatedAt timestamp')

assert.equal(store.saveCinema({ index: 999, answers: { 0: 8 }, locale: 'fr', completed: true, selfChecks: { 0: true, 9: true } }), true)
progress = store.read()
assert.equal(progress.cinema.index, 0, 'out-of-range scene indexes should normalise to zero')
assert.equal(progress.cinema.locale, 'ru', 'unsupported locale should normalise to Russian')
assert.deepEqual(progress.cinema.answers, {}, 'invalid choice indexes should be discarded')
assert.deepEqual(progress.cinema.selfChecks, { 0: true }, 'out-of-range self-check indexes should be discarded')

assert.equal(store.resetCinema(), true, 'course restart should persist')
progress = store.read()
assert.equal(progress.cinema.index, 0, 'restart should reset the current scene')
assert.equal(progress.lastLessonSlug, 'signal-and-noise', 'restart must preserve last opened lesson')
assert.ok(progress.lessonCompletions.includes('power-of-knowledge'), 'restart must preserve lesson completion history')
assert.ok(changeEvents >= 4, 'writes should emit change events')

const blocked = createOSALearningProgressStore({
  getItem() { throw new Error('storage blocked') },
  setItem() { throw new Error('storage blocked') },
})
assert.equal(blocked.setLessonCompletion('intelligence-and-imitation', true), false, 'blocked storage should be reported as non-persistent')
assert.ok(blocked.read().lessonCompletions.includes('intelligence-and-imitation'), 'memory fallback should keep this tab functional')

console.log('OSA_PROGRESS_STORE_PASS: legacy migration, validation, persistence, eventing, and blocked-storage fallback verified.')
