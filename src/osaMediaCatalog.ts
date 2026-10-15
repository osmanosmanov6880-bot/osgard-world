import { OSA_LESSON_SLUGS } from './osaLessonGuides'

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
