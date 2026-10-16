import { OSA_LESSON_SLUGS } from './osaLessonRegistry'
import { isPermanentMediaUrl } from './osaMediaUrl'

export type OSAMediaLocale = 'ru' | 'en'
export type OSAMediaKind = 'audio' | 'video'

export type OSAMediaResource = {
  id: string
  kind: OSAMediaKind
  title: string
  src: string | null
  locale: OSAMediaLocale
  durationSeconds?: number | null
  captionsSrc?: string | null
  transcript?: string | null
}

type LocaleResources = Record<OSAMediaLocale, OSAMediaResource | null>
type LessonResources = Record<OSAMediaKind, LocaleResources>

function pendingResource(slug: string, kind: OSAMediaKind, locale: OSAMediaLocale): OSAMediaResource {
  return {
    id: slug + ':' + kind + ':' + locale,
    kind,
    title: slug,
    src: null,
    locale,
    durationSeconds: null,
    captionsSrc: null,
    transcript: null,
  }
}

function createPendingLesson(slug: string): LessonResources {
  return {
    audio: {
      ru: pendingResource(slug, 'audio', 'ru'),
      en: pendingResource(slug, 'audio', 'en'),
    },
    video: {
      ru: pendingResource(slug, 'video', 'ru'),
      en: pendingResource(slug, 'video', 'en'),
    },
  }
}

/**
 * Canonical attachment point for per-lesson media.
 * The entries intentionally have null sources until approved files receive durable URLs.
 * Do not paste temporary Runway gallery URLs into this catalogue.
 */
export const osaLessonMedia = Object.fromEntries(
  OSA_LESSON_SLUGS.map(slug => [slug, createPendingLesson(slug)]),
) as Record<(typeof OSA_LESSON_SLUGS)[number], LessonResources>

export function getOSALessonMedia(
  slug: string,
  locale: OSAMediaLocale,
  kind: OSAMediaKind,
): OSAMediaResource | null {
  const lesson = osaLessonMedia[slug as keyof typeof osaLessonMedia]
  return lesson?.[kind]?.[locale] ?? null
}

export function getOSACinemaMedia(
  sceneIndex: number,
  locale: OSAMediaLocale,
  kind: OSAMediaKind,
): OSAMediaResource | null {
  const slug = OSA_LESSON_SLUGS[sceneIndex]
  return slug ? getOSALessonMedia(slug, locale, kind) : null
}

/** A publication-safe status, independent of whether a player component is mounted. */
export type OSAMediaAvailability = 'not_published' | 'invalid_source' | 'available'

export function getOSAMediaAvailability(resource: OSAMediaResource | null | undefined): OSAMediaAvailability {
  if (!resource?.src) return 'not_published'
  return isPermanentMediaUrl(resource.src) ? 'available' : 'invalid_source'
}

/** Summary for editors: only valid durable sources count as published. */
export function getOSALessonMediaSummary(locale: OSAMediaLocale) {
  const lessons = OSA_LESSON_SLUGS.map(slug => {
    const audio = getOSAMediaAvailability(getOSALessonMedia(slug, locale, 'audio'))
    const video = getOSAMediaAvailability(getOSALessonMedia(slug, locale, 'video'))
    return { slug, audio, video }
  })
  return {
    locale,
    totalLessons: lessons.length,
    playableAudio: lessons.filter(item => item.audio === 'available').length,
    playableVideo: lessons.filter(item => item.video === 'available').length,
    invalidSources: lessons.reduce((sum, item) => sum + Number(item.audio === 'invalid_source') + Number(item.video === 'invalid_source'), 0),
    lessons,
  }
}
