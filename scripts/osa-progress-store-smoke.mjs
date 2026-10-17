import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import vm from 'node:vm'
import ts from 'typescript'

const source = readFileSync('src/osaProgress.ts', 'utf8')
const compiled = ts.transpileModule(source, {
  compilerOptions: {
    target: ts.ScriptTarget.ES2022,
    module: ts.ModuleKind.CommonJS,
  },
}).outputText

const moduleRecord = { exports: {} }
const sandbox = {
  module: moduleRecord,
  exports: moduleRecord.exports,
  Date,
  require(specifier) {
    if (specifier === './osaLessonRegistry') {
      return {
        OSA_LESSON_SLUGS: [
          'intelligence-and-imitation',
          'how-language-models-work',
          'power-of-knowledge',
          'signal-and-noise',
          'verify-an-ai-answer',
          'privacy-before-prompting',
          'human-in-the-loop',
          'investigate-the-future',
        ],
      }
    }
    throw new Error('Unexpected dependency in progress-store test: ' + specifier)
  },
}
vm.runInNewContext(compiled, sandbox, { filename: 'osaProgress.transpiled.cjs' })
const { createOSALearningProgressStore, OSA_PROGRESS_STORAGE_KEY } = moduleRecord.exports
const plain = value => JSON.parse(JSON.stringify(value))

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

let progress = plain(store.read())
assert.deepEqual(progress.lessonCompletions, ['intelligence-and-imitation', 'power-of-knowledge'], 'legacy completions should be deduplicated and invalid slugs removed')
assert.equal(progress.cinema.index, 5, 'legacy cinema position should migrate')
assert.equal(progress.cinema.locale, 'en', 'legacy locale should migrate')
assert.deepEqual(progress.cinema.answers, { 0: 2, 5: 2 }, 'answers from invalid or non-choice scenes should be removed')
assert.deepEqual(progress.cinema.selfChecks, { 0: true, 1: false }, 'only the three recognised self-checks should migrate')
assert.ok(storage.getItem(OSA_PROGRESS_STORAGE_KEY), 'a canonical snapshot should be written during migration')

assert.equal(store.setLessonCompletion('human-in-the-loop', true), true, 'valid completion should persist')
assert.equal(store.setLessonCompletion('not-a-real-lesson', true), false, 'unknown lesson slugs should be rejected')
assert.equal(store.markLessonOpened('signal-and-noise'), true, 'last lesson should persist')
progress = plain(store.read())
assert.equal(progress.lastLessonSlug, 'signal-and-noise', 'last opened lesson should be recorded')
assert.ok(progress.lessonCompletions.includes('human-in-the-loop'), 'completion update should preserve existing lessons')
assert.equal(progress.updatedAt, '2026-10-15T00:00:00.000Z', 'writes should carry a stable updatedAt timestamp')

assert.equal(store.saveCinema({ index: 999, answers: { 0: 8 }, locale: 'fr', completed: true, selfChecks: { 0: true, 9: true } }), true)
progress = plain(store.read())
assert.equal(progress.cinema.index, 0, 'out-of-range scene indexes should normalise to zero')
assert.equal(progress.cinema.locale, 'ru', 'unsupported locale should normalise to Russian')
assert.deepEqual(progress.cinema.answers, {}, 'invalid choice indexes should be discarded')
assert.deepEqual(progress.cinema.selfChecks, { 0: true }, 'out-of-range self-check indexes should be discarded')

assert.equal(store.resetCinema(), true, 'course restart should persist')
progress = plain(store.read())
assert.equal(progress.cinema.index, 0, 'restart should reset the current scene')
assert.equal(progress.lastLessonSlug, 'signal-and-noise', 'restart must preserve last opened lesson')
assert.ok(progress.lessonCompletions.includes('power-of-knowledge'), 'restart must preserve lesson completion history')
assert.ok(changeEvents >= 4, 'writes should emit change events')

const blocked = createOSALearningProgressStore({
  getItem() { throw new Error('storage blocked') },
  setItem() { throw new Error('storage blocked') },
})
assert.equal(blocked.setLessonCompletion('intelligence-and-imitation', true), false, 'blocked storage should be reported as non-persistent')
assert.ok(plain(blocked.read()).lessonCompletions.includes('intelligence-and-imitation'), 'memory fallback should keep this tab functional')

class RecoverableStorage extends MemoryStorage {
  failWrites = false
  setItem(key, value) {
    if (this.failWrites) throw new Error('QuotaExceededError')
    super.setItem(key, value)
  }
}

// Match the page subscription: a save immediately dispatches an event whose
// listener reads both the current progress and its persistence status.
const recoverableStorage = new RecoverableStorage()
const observed = []
const recoverableStore = createOSALearningProgressStore(recoverableStorage, () => {
  observed.push({ progress: plain(recoverableStore.read()), persistent: recoverableStore.isPersistent() })
}, () => '2026-10-17T00:00:00.000Z')
assert.equal(recoverableStore.setLessonCompletion('intelligence-and-imitation', true), true)
const lastSuccessfulRaw = recoverableStorage.getItem(OSA_PROGRESS_STORAGE_KEY)
recoverableStorage.failWrites = true
assert.equal(recoverableStore.setLessonCompletion('how-language-models-work', true), false, 'a later quota failure should be reported even when old valid data can be read')
assert.deepEqual(observed.at(-1).progress.lessonCompletions, ['intelligence-and-imitation', 'how-language-models-work'], 'a synchronous subscriber must see the new unsaved completion instead of the old persisted snapshot')
assert.equal(observed.at(-1).persistent, false, 'a subscription read must not clear the failed-save warning')
for (let read = 0; read < 3; read += 1) {
  assert.ok(plain(recoverableStore.read()).lessonCompletions.includes('how-language-models-work'), 'repeated reads should retain the unsaved lesson')
  assert.equal(recoverableStore.isPersistent(), false, 'retained memory progress must remain marked as non-persistent')
}
assert.equal(recoverableStorage.getItem(OSA_PROGRESS_STORAGE_KEY), lastSuccessfulRaw, 'failed updates must leave the previous persisted snapshot intact')

assert.equal(recoverableStore.saveCinema({ index: 2, answers: { 0: 1 }, locale: 'en', completed: false, selfChecks: { 0: true } }), false)
assert.equal(recoverableStore.markLessonOpened('signal-and-noise'), false)
progress = plain(recoverableStore.read())
assert.ok(progress.lessonCompletions.includes('how-language-models-work'), 'subsequent failed updates must keep the pending completion')
assert.equal(progress.cinema.index, 2, 'pending cinema progress should survive the next failed update')
assert.equal(progress.lastLessonSlug, 'signal-and-noise', 'last-opened lesson should remain available in memory')

recoverableStorage.failWrites = false
assert.equal(recoverableStore.markLessonOpened('signal-and-noise'), true, 'retrying the same last-opened lesson should persist pending progress after storage recovers')
assert.equal(observed.at(-1).persistent, true, 'the successful retry should clear the subscription warning')
const recoveredProgress = plain(recoverableStore.read())
assert.deepEqual(plain(createOSALearningProgressStore(recoverableStorage).read()), recoveredProgress, 'a fresh store must recover all pending fields after a successful retry')
assert.ok(recoveredProgress.lessonCompletions.includes('how-language-models-work'))
assert.equal(recoveredProgress.cinema.index, 2)

const otherTab = createOSALearningProgressStore(recoverableStorage)
assert.equal(otherTab.setLessonCompletion('verify-an-ai-answer', true), true)
assert.ok(plain(recoverableStore.read()).lessonCompletions.includes('verify-an-ai-answer'), 'a clean tab should still accept another tab\'s persisted update')
recoverableStorage.failWrites = true
assert.equal(recoverableStore.setLessonCompletion('privacy-before-prompting', true), false)
recoverableStorage.failWrites = false
assert.equal(otherTab.setLessonCompletion('human-in-the-loop', true), true)
progress = plain(recoverableStore.read())
assert.ok(progress.lessonCompletions.includes('human-in-the-loop'), 'a genuinely changed valid external snapshot should keep the existing cross-tab precedence')
assert.equal(progress.lessonCompletions.includes('privacy-before-prompting'), false, 'only an unchanged old persisted snapshot is ignored; a newer external snapshot remains authoritative')
assert.equal(recoverableStore.isPersistent(), true)

const migrationStorage = new RecoverableStorage()
migrationStorage.setItem(OSA_PROGRESS_STORAGE_KEY, JSON.stringify({ version: 0 }))
migrationStorage.setItem('osgard-osa-lesson-completion-v1', JSON.stringify(['power-of-knowledge']))
migrationStorage.failWrites = true
const migrationStore = createOSALearningProgressStore(migrationStorage)
assert.deepEqual(plain(migrationStore.read()).lessonCompletions, ['power-of-knowledge'], 'legacy migration should remain available when a stale invalid canonical record cannot be replaced')
assert.equal(migrationStore.isPersistent(), false, 'the presence of an invalid canonical record must not make a failed migration look persisted')
assert.deepEqual(plain(migrationStore.read()).lessonCompletions, ['power-of-knowledge'])
migrationStorage.failWrites = false
assert.equal(migrationStore.setLessonCompletion('power-of-knowledge', true), true)
assert.deepEqual(plain(createOSALearningProgressStore(migrationStorage).read()).lessonCompletions, ['power-of-knowledge'])

console.log('OSA_PROGRESS_STORE_PASS: legacy migration, validation, persistence, eventing, blocked storage, late write failure with subscriptions, recovery, and cross-tab updates verified.')
