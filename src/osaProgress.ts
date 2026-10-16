import { OSA_LESSON_SLUGS } from './osaLessonRegistry'

export const OSA_PROGRESS_STORAGE_KEY = 'osgard-osa-learning-progress-v1'
export const OSA_PROGRESS_EVENT = 'osgard-osa-progress'

const LEGACY_CINEMA_KEY = 'osgard-osa-cinema-progress-v1'
const LEGACY_LESSONS_KEY = 'osgard-osa-lesson-completion-v1'
const CINEMA_SCENE_COUNT = 8
const CHOICE_COUNTS = [3, 0, 3, 0, 3, 3, 3, 0] as const

export type OSACinemaLocaleValue = 'ru' | 'en'
export type OSACinemaSavedProgress = {
  index: number
  answers: Record<number, number>
  locale: OSACinemaLocaleValue
  completed: boolean
  selfChecks: Record<number, boolean>
}
export type OSALearningProgress = {
  version: 1
  lessonCompletions: string[]
  lastLessonSlug: string | null
  cinema: OSACinemaSavedProgress
  updatedAt: string | null
}

export type OSAStorageLike = {
  getItem(key: string): string | null
  setItem(key: string, value: string): void
  removeItem?(key: string): void
}

const validSlugs = OSA_LESSON_SLUGS as readonly string[]
const defaultCinema = (): OSACinemaSavedProgress => ({
  index: 0,
  answers: {},
  locale: 'ru',
  completed: false,
  selfChecks: {},
})
const defaultProgress = (): OSALearningProgress => ({
  version: 1,
  lessonCompletions: [],
  lastLessonSlug: null,
  cinema: defaultCinema(),
  updatedAt: null,
})

function cloneProgress(value: OSALearningProgress): OSALearningProgress {
  return {
    ...value,
    lessonCompletions: [...value.lessonCompletions],
    cinema: {
      ...value.cinema,
      answers: { ...value.cinema.answers },
      selfChecks: { ...value.cinema.selfChecks },
    },
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === 'object' && !Array.isArray(value)
}

function uniqueValidSlugs(value: unknown): string[] {
  if (!Array.isArray(value)) return []
  return [...new Set(value.filter((slug): slug is string => typeof slug === 'string' && validSlugs.includes(slug)))]
}

function normalizeCinema(value: unknown): OSACinemaSavedProgress {
  if (!isRecord(value)) return defaultCinema()
  const index = Number.isInteger(value.index) && Number(value.index) >= 0 && Number(value.index) < CINEMA_SCENE_COUNT
    ? Number(value.index)
    : 0
  const locale: OSACinemaLocaleValue = value.locale === 'en' ? 'en' : 'ru'
  const answers: Record<number, number> = {}
  if (isRecord(value.answers)) {
    for (const [rawIndex, rawChoice] of Object.entries(value.answers)) {
      const sceneIndex = Number(rawIndex)
      if (
        Number.isInteger(sceneIndex) &&
        sceneIndex >= 0 &&
        sceneIndex < CHOICE_COUNTS.length &&
        CHOICE_COUNTS[sceneIndex] > 0 &&
        typeof rawChoice === 'number' &&
        Number.isInteger(rawChoice) &&
        Number(rawChoice) >= 0 &&
        Number(rawChoice) < CHOICE_COUNTS[sceneIndex]
      ) answers[sceneIndex] = Number(rawChoice)
    }
  }
  const selfChecks: Record<number, boolean> = {}
  if (isRecord(value.selfChecks)) {
    for (const [rawIndex, checked] of Object.entries(value.selfChecks)) {
      const checkIndex = Number(rawIndex)
      if (Number.isInteger(checkIndex) && checkIndex >= 0 && checkIndex < 3 && typeof checked === 'boolean') {
        selfChecks[checkIndex] = checked
      }
    }
  }
  return { index, answers, locale, completed: value.completed === true, selfChecks }
}

function parseJson(storage: OSAStorageLike | null, key: string): unknown {
  if (!storage) return null
  try {
    const raw = storage.getItem(key)
    return raw ? JSON.parse(raw) as unknown : null
  } catch {
    return null
  }
}

function normalizeProgress(value: unknown): OSALearningProgress | null {
  if (!isRecord(value) || value.version !== 1) return null
  return {
    version: 1,
    lessonCompletions: uniqueValidSlugs(value.lessonCompletions),
    lastLessonSlug: typeof value.lastLessonSlug === 'string' && validSlugs.includes(value.lastLessonSlug)
      ? value.lastLessonSlug
      : null,
    cinema: normalizeCinema(value.cinema),
    updatedAt: typeof value.updatedAt === 'string' && !Number.isNaN(Date.parse(value.updatedAt))
      ? value.updatedAt
      : null,
  }
}

function migrateLegacyProgress(storage: OSAStorageLike | null): OSALearningProgress {
  const migrated = defaultProgress()
  const oldLessons = parseJson(storage, LEGACY_LESSONS_KEY)
  const oldCinema = parseJson(storage, LEGACY_CINEMA_KEY)
  migrated.lessonCompletions = uniqueValidSlugs(oldLessons)
  migrated.cinema = normalizeCinema(oldCinema)
  if (storage && (oldLessons !== null || oldCinema !== null)) {
    migrated.updatedAt = new Date().toISOString()
    try {
      storage.setItem(OSA_PROGRESS_STORAGE_KEY, JSON.stringify(migrated))
    } catch {
      // The store will keep this migrated snapshot in memory for the current tab.
    }
  }
  return migrated
}

/**
 * Create a progress store around a minimal Storage-compatible adapter.
 * The browser uses localStorage today; tests can inject memory or failure adapters.
 * A future authenticated API adapter can replace this boundary without treating
 * client-provided progress as authoritative for paid access or certification.
 */
export function createOSALearningProgressStore(
  storage: OSAStorageLike | null,
  onChange: () => void = () => undefined,
  now: () => string = () => new Date().toISOString(),
) {
  let memorySnapshot = defaultProgress()
  let memoryDirty = false

  const read = (): OSALearningProgress => {
    if (!storage) return cloneProgress(memorySnapshot)
    try {
      const raw = storage.getItem(OSA_PROGRESS_STORAGE_KEY)
      if (raw) {
        const canonical = normalizeProgress(JSON.parse(raw) as unknown)
        if (canonical) {
          memorySnapshot = canonical
          memoryDirty = false
          return cloneProgress(canonical)
        }
        if (memoryDirty) return cloneProgress(memorySnapshot)
      } else if (memoryDirty) {
        return cloneProgress(memorySnapshot)
      }
    } catch {
      return cloneProgress(memorySnapshot)
    }

    const migrated = migrateLegacyProgress(storage)
    memorySnapshot = migrated
    if (migrated.updatedAt) {
      try {
        memoryDirty = storage.getItem(OSA_PROGRESS_STORAGE_KEY) === null
      } catch {
        memoryDirty = true
      }
    } else {
      // Repair a malformed canonical value with a safe, validated default snapshot.
      try {
        if (storage.getItem(OSA_PROGRESS_STORAGE_KEY) !== null) {
          storage.setItem(OSA_PROGRESS_STORAGE_KEY, JSON.stringify(migrated))
        }
        memoryDirty = false
      } catch {
        memoryDirty = true
      }
    }
    return cloneProgress(memorySnapshot)
  }

  const write = (candidate: OSALearningProgress): boolean => {
    const normalized = normalizeProgress({ ...candidate, version: 1, updatedAt: now() }) || defaultProgress()
    memorySnapshot = normalized
    memoryDirty = true
    let persisted = false
    if (storage) {
      try {
        storage.setItem(OSA_PROGRESS_STORAGE_KEY, JSON.stringify(normalized))
        persisted = true
        memoryDirty = false
      } catch {
        // Keep the current tab functional; callers can warn that persistence failed.
      }
    }
    try { onChange() } catch { /* State events must never break saving. */ }
    return persisted
  }

  return {
    read,
    saveCinema(cinema: OSACinemaSavedProgress): boolean {
      const current = read()
      return write({ ...current, cinema: normalizeCinema(cinema) })
    },
    resetCinema(): boolean {
      const current = read()
      return write({ ...current, cinema: defaultCinema() })
    },
    setLessonCompletion(slug: string, completed: boolean): boolean {
      if (!validSlugs.includes(slug)) return false
      const current = read()
      const next = completed
        ? [...new Set([...current.lessonCompletions, slug])]
        : current.lessonCompletions.filter(item => item !== slug)
      return write({ ...current, lessonCompletions: next })
    },
    markLessonOpened(slug: string): boolean {
      if (!validSlugs.includes(slug)) return false
      const current = read()
      if (current.lastLessonSlug === slug) return this.isPersistent()
      return write({ ...current, lastLessonSlug: slug })
    },
    isPersistent(): boolean {
      if (!storage || memoryDirty) return false
      try {
        storage.getItem(OSA_PROGRESS_STORAGE_KEY)
        return true
      } catch {
        return false
      }
    },
  }
}

function getBrowserStorage(): OSAStorageLike | null {
  try {
    if (typeof window === 'undefined' || !window.localStorage) return null
    return window.localStorage
  } catch {
    return null
  }
}

function emitProgressChange() {
  if (typeof window === 'undefined') return
  try { window.dispatchEvent(new CustomEvent(OSA_PROGRESS_EVENT)) } catch { /* Browser events are optional in tests. */ }
}

const browserStore = createOSALearningProgressStore(getBrowserStorage(), emitProgressChange)

export function getOSALearningProgress(): OSALearningProgress {
  return browserStore.read()
}

export function saveOSACinemaProgress(cinema: OSACinemaSavedProgress): boolean {
  return browserStore.saveCinema(cinema)
}

export function resetOSACinemaProgress(): boolean {
  return browserStore.resetCinema()
}

export function setOSALessonCompletion(slug: string, completed: boolean): boolean {
  return browserStore.setLessonCompletion(slug, completed)
}

export function markOSALessonOpened(slug: string): boolean {
  return browserStore.markLessonOpened(slug)
}

export function isOSALearningProgressPersistent(): boolean {
  return browserStore.isPersistent()
}

export function subscribeOSALearningProgress(callback: () => void): () => void {
  if (typeof window === 'undefined') return () => undefined
  window.addEventListener(OSA_PROGRESS_EVENT, callback)
  window.addEventListener('storage', callback)
  window.addEventListener('focus', callback)
  return () => {
    window.removeEventListener(OSA_PROGRESS_EVENT, callback)
    window.removeEventListener('storage', callback)
    window.removeEventListener('focus', callback)
  }
}
