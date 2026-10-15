import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { createHash } from 'node:crypto'
import vm from 'node:vm'
import ts from 'typescript'

const MAX_SEGMENT_CHARS = 4500
const CREDIT_CHAR_COUNT = 50
const LOCALES = ['ru', 'en']

async function loadTypeScriptModule(path, dependencies = {}) {
  const source = await readFile(path, 'utf8')
  const compiled = ts.transpileModule(source, {
    compilerOptions: {
      target: ts.ScriptTarget.ES2022,
      module: ts.ModuleKind.CommonJS,
    },
  }).outputText
  const moduleRecord = { exports: {} }
  const context = {
    module: moduleRecord,
    exports: moduleRecord.exports,
    require(specifier) {
      if (Object.prototype.hasOwnProperty.call(dependencies, specifier)) return dependencies[specifier]
      throw new Error(path + ' attempted to load an unexpected module: ' + specifier)
    },
  }
  vm.runInNewContext(compiled, context, { filename: path + '.transpiled.cjs' })
  return moduleRecord.exports
}

function sha256(value) {
  return createHash('sha256').update(value, 'utf8').digest('hex')
}
function normalizeWhitespace(value) {
  return value.replace(/\s+/gu, ' ').trim()
}
function splitLongParagraph(paragraph) {
  const words = paragraph.match(/\S+/gu) || []
  const chunks = []
  let current = ''
  for (const word of words) {
    assert.ok(word.length <= MAX_SEGMENT_CHARS, 'A single narration token exceeds the TTS segment limit.')
    const next = current ? current + ' ' + word : word
    if (next.length > MAX_SEGMENT_CHARS && current) {
      chunks.push(current)
      current = word
    } else current = next
  }
  if (current) chunks.push(current)
  return chunks
}
function segmentNarration(text) {
  const paragraphs = text.split(/\n{2,}/u).map(p => p.trim()).filter(Boolean)
  const segments = []
  let current = ''
  const flush = () => {
    if (current) segments.push(current.trim())
    current = ''
  }
  for (const paragraph of paragraphs) {
    if (paragraph.length > MAX_SEGMENT_CHARS) {
      flush()
      segments.push(...splitLongParagraph(paragraph))
      continue
    }
    const next = current ? current + '\n\n' + paragraph : paragraph
    if (next.length > MAX_SEGMENT_CHARS && current) {
      flush()
      current = paragraph
    } else current = next
  }
  flush()
  assert.ok(segments.length > 0, 'Every lesson should yield at least one narration segment.')
  assert.ok(segments.every(segment => segment.length <= MAX_SEGMENT_CHARS), 'TTS segment exceeds the configured limit.')
  assert.equal(normalizeWhitespace(segments.join(' ')), normalizeWhitespace(text), 'Segmentation lost or changed narration text.')
  return segments
}
function buildNarration(slug, lessonIndex, locale, reading, guide) {
  const isRussian = locale === 'ru'
  const labels = isRussian
    ? {
        lesson: 'Урок ' + (lessonIndex + 1) + ' из 8.',
        objectives: 'Цели обучения.',
        example: 'Практический пример.',
        glossary: 'Словарь ключевых терминов.',
        exercise: 'Практическое задание.',
        success: 'Критерий выполнения.',
        summary: 'Ключевые выводы.',
        continue: 'Проверьте понимание и откройте дополнительные источники на странице урока.',
      }
    : {
        lesson: 'Lesson ' + (lessonIndex + 1) + ' of 8.',
        objectives: 'Learning objectives.',
        example: 'Practical example.',
        glossary: 'Key terms.',
        exercise: 'Practical exercise.',
        success: 'Success criteria.',
        summary: 'Key takeaways.',
        continue: 'Complete the knowledge check and open the additional sources on the lesson page.',
      }
  const sections = reading.sections.map(section => section.heading + '. ' + section.body)
  const glossary = guide.glossary.map(item => item.term + '. ' + item.definition).join(' ')
  const exercise = guide.exercise.title + '. ' + guide.exercise.steps.join(' ') + ' ' + labels.success + ' ' + guide.exercise.successCriteria
  const parts = [
    labels.lesson,
    labels.objectives + ' ' + guide.objectives.join(' '),
    ...sections,
    labels.example + ' ' + guide.example,
    labels.glossary + ' ' + glossary,
    labels.exercise + ' ' + exercise,
    labels.summary + ' ' + reading.keyTakeaways.join(' '),
    labels.continue,
  ]
  const narration = parts.join('\n\n').trim()
  assert.ok(!/https?:\/\/|www\./iu.test(narration), slug + '/' + locale + ' narration must not read raw URLs.')
  assert.ok(!/\bundefined\b/iu.test(narration), slug + '/' + locale + ' narration contains a missing field marker.')
  return narration
}

const guideModule = await loadTypeScriptModule('src/osaLessonGuides.ts')
const readingModule = await loadTypeScriptModule('src/osaLessonReading.ts', { './osaLessonGuides': guideModule })
const slugs = guideModule.OSA_LESSON_SLUGS
const guides = guideModule.osaLessonGuides
const readings = readingModule.osaLessonReadings
assert.deepEqual(Array.from(slugs), [
  'intelligence-and-imitation',
  'how-language-models-work',
  'power-of-knowledge',
  'signal-and-noise',
  'verify-an-ai-answer',
  'privacy-before-prompting',
  'human-in-the-loop',
  'investigate-the-future',
], 'Canonical OSA lesson order changed; review narration mapping.')

const records = []
for (const locale of LOCALES) {
  assert.equal(guides[locale].length, slugs.length, 'Guide count differs for ' + locale)
  for (let index = 0; index < slugs.length; index += 1) {
    const slug = slugs[index]
    const reading = readings[locale][slug]
    const guide = guides[locale][index]
    assert.ok(reading && reading.sections && reading.sections.length === 3, 'Missing three-section reading for ' + slug + '/' + locale)
    assert.equal(reading.keyTakeaways.length, 3, 'Missing three key takeaways for ' + slug + '/' + locale)
    assert.ok(guide && guide.objectives.length >= 2, 'Missing learning objectives for ' + slug + '/' + locale)
    assert.ok(guide.example && guide.glossary.length >= 1, 'Missing example or glossary for ' + slug + '/' + locale)
    assert.ok(guide.exercise && guide.exercise.steps.length >= 2 && guide.exercise.successCriteria, 'Missing exercise specification for ' + slug + '/' + locale)
    assert.ok(guide.sources.length >= 2, 'Missing additional study sources for ' + slug + '/' + locale)
    const narration = buildNarration(slug, index, locale, reading, guide)
    const segments = segmentNarration(narration)
    const segmentRecords = segments.map((segment, segmentIndex) => {
      const characters = Array.from(segment).length
      return {
        index: segmentIndex + 1,
        characters,
        codeUnits: segment.length,
        estimatedCredits: Math.ceil(characters / CREDIT_CHAR_COUNT),
        sha256: sha256(segment),
      }
    })
    records.push({
      slug,
      locale,
      sequence: index + 1,
      title: reading.sections[0].heading,
      narrationCharacters: Array.from(narration).length,
      scriptSha256: sha256(narration),
      segmentCount: segments.length,
      segmentCharacterCounts: segmentRecords.map(segment => segment.characters),
      segments: segmentRecords,
      estimatedCredits: segmentRecords.reduce((sum, segment) => sum + segment.estimatedCredits, 0),
      status: 'script_ready_audio_not_generated',
      blockers: ['voice_not_auditioned', 'audio_not_generated', 'permanent_hosting_not_configured', 'human_qc_not_passed'],
    })
  }
}
const byLocale = Object.fromEntries(LOCALES.map(locale => {
  const subset = records.filter(record => record.locale === locale)
  return [locale, {
    lessons: subset.length,
    characters: subset.reduce((sum, record) => sum + record.narrationCharacters, 0),
    segments: subset.reduce((sum, record) => sum + record.segmentCount, 0),
    estimatedCredits: subset.reduce((sum, record) => sum + record.estimatedCredits, 0),
    perLesson: subset.map(record => ({ slug: record.slug, characters: record.narrationCharacters, segments: record.segmentCount, estimatedCredits: record.estimatedCredits })),
  }]
}))
const manifest = {
  schemaVersion: 1,
  sourceOfTruth: ['src/osaLessonReading.ts', 'src/osaLessonGuides.ts'],
  providerForEstimate: 'Runway TTS / eleven_multilingual_v2; final voice must be auditioned before batch generation',
  costModel: { creditsPerCharacters: CREDIT_CHAR_COUNT, rounding: 'round up per generated segment', maxCharactersPerSegment: MAX_SEGMENT_CHARS },
  lessonsPerLocale: slugs.length,
  totalScripts: records.length,
  totals: {
    characters: records.reduce((sum, record) => sum + record.narrationCharacters, 0),
    segments: records.reduce((sum, record) => sum + record.segmentCount, 0),
    estimatedCredits: records.reduce((sum, record) => sum + record.estimatedCredits, 0),
  },
  byLocale,
  records,
  releaseGate: {
    status: 'planned_not_generated',
    permanentAudioUrls: 0,
    readyAudioTracks: 0,
    note: 'Credit estimate only. This script makes no generation calls. Actual duration, voice choice, pronunciation and audio quality must be checked after a real sample and each completed track.',
  },
}
const serialized = JSON.stringify(manifest)
assert.equal(records.length, 16, 'There must be one narration plan per lesson and language.')
assert.ok(records.every(record => record.estimatedCredits > 0 && record.segments.length > 0), 'Every narration must have a positive, segmented plan.')
assert.ok(!/cloudfront\.net|_jwt=|signed_url/i.test(serialized), 'Narration plan must not contain temporary media URLs.')
console.log(JSON.stringify({
  status: 'narration-plan-valid-audio-not-generated',
  lessonsPerLocale: manifest.lessonsPerLocale,
  totalScripts: manifest.totalScripts,
  totals: manifest.totals,
  byLocale,
  records: records.map(({slug,locale,title,narrationCharacters,segmentCount,estimatedCredits,status})=>({slug,locale,title,narrationCharacters,segmentCount,estimatedCredits,status})),
  blockers: manifest.releaseGate,
}, null, 2))
