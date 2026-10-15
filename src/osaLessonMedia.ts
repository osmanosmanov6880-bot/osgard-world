import { OSA_LESSON_SLUGS } from './osaLessonGuides'

export type OSALessonMediaKind = 'audio' | 'video'
export type OSALessonMediaStatus = 'not-ready' | 'published'
export type OSALessonMediaLocale = 'ru' | 'en'

export type OSALessonMediaChapter = {
  title: string
  startSeconds: number
}

export type OSALessonMediaResource = {
  kind: OSALessonMediaKind
  status: OSALessonMediaStatus
  /** Runway ID or other source reference; never treated as a playback URL. */
  assetId: string | null
  /** Only durable, project-controlled HTTPS URLs belong here. Never put signed temporary URLs here. */
  permanentUrl: string | null
  mimeType: string | null
  durationSeconds: number | null
  language: OSALessonMediaLocale | null
  chapters: OSALessonMediaChapter[]
  captionsUrl: string | null
  transcriptUrl: string | null
  rightsStatus: 'unverified' | 'approved'
}

export type OSALessonMediaBundle = {
  estimatedStudyMinutes: { min: number; max: number }
  audio: OSALessonMediaResource
  video: OSALessonMediaResource
}

type LessonSlug = (typeof OSA_LESSON_SLUGS)[number]

const pendingResource = (kind: OSALessonMediaKind): OSALessonMediaResource => ({
  kind,
  status: 'not-ready',
  assetId: null,
  permanentUrl: null,
  mimeType: null,
  durationSeconds: null,
  language: null,
  chapters: [],
  captionsUrl: null,
  transcriptUrl: null,
  rightsStatus: 'unverified',
})

/**
 * Editorial status per lesson. None of the current Runway clips has been
 * approved and permanently hosted as a complete audio/video lesson yet.
 * Keep this explicit so the UI never invents a player or a duration.
 */
export const osaLessonMedia: Record<LessonSlug, OSALessonMediaBundle> = {
  'intelligence-and-imitation': { estimatedStudyMinutes: { min: 15, max: 20 }, audio: pendingResource('audio'), video: pendingResource('video') },
  'how-language-models-work': { estimatedStudyMinutes: { min: 15, max: 20 }, audio: pendingResource('audio'), video: pendingResource('video') },
  'power-of-knowledge': { estimatedStudyMinutes: { min: 15, max: 20 }, audio: pendingResource('audio'), video: pendingResource('video') },
  'signal-and-noise': { estimatedStudyMinutes: { min: 15, max: 20 }, audio: pendingResource('audio'), video: pendingResource('video') },
  'verify-an-ai-answer': { estimatedStudyMinutes: { min: 15, max: 20 }, audio: pendingResource('audio'), video: pendingResource('video') },
  'privacy-before-prompting': { estimatedStudyMinutes: { min: 15, max: 20 }, audio: pendingResource('audio'), video: pendingResource('video') },
  'human-in-the-loop': { estimatedStudyMinutes: { min: 15, max: 20 }, audio: pendingResource('audio'), video: pendingResource('video') },
  'investigate-the-future': { estimatedStudyMinutes: { min: 15, max: 20 }, audio: pendingResource('audio'), video: pendingResource('video') },
}

export function isPermanentHttpsUrl(value: string | null | undefined): value is string {
  if (typeof value !== 'string' || !value.trim()) return false
  try {
    const parsed = new URL(value)
    return parsed.protocol === 'https:' && !parsed.username && !parsed.password
  } catch {
    return false
  }
}

export function isPlayableLessonMedia(resource: OSALessonMediaResource): boolean {
  return resource.status === 'published'
    && resource.rightsStatus === 'approved'
    && isPermanentHttpsUrl(resource.permanentUrl)
    && typeof resource.durationSeconds === 'number'
    && Number.isFinite(resource.durationSeconds)
    && resource.durationSeconds > 0
    && Boolean(resource.mimeType)
    && (resource.kind !== 'video' || Boolean(resource.captionsUrl && isPermanentHttpsUrl(resource.captionsUrl)))
}
