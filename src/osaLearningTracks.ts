import { OSA_LESSON_SLUGS } from './osaLessonRegistry'

export type OSALearningTrack = {
  id: string
  title: { ru: string; en: string }
  description: { ru: string; en: string }
  lessonSlugs: string[]
  premium: boolean
}

export const OSA_LEARNING_TRACKS: OSALearningTrack[] = [
  {
    id: 'ai-foundations',
    title: { ru: 'Основы искусственного интеллекта', en: 'AI Foundations' },
    description: { ru: 'Понять принципы работы ИИ и языковых моделей.', en: 'Understand AI and language model fundamentals.' },
    lessonSlugs: OSA_LESSON_SLUGS.slice(0, 2),
    premium: false,
  },
  {
    id: 'critical-thinking',
    title: { ru: 'Критическое мышление и проверка фактов', en: 'Critical Thinking and Verification' },
    description: { ru: 'Различать сигнал и шум, проверять ответы ИИ.', en: 'Separate signal from noise and verify AI output.' },
    lessonSlugs: OSA_LESSON_SLUGS.slice(2, 5),
    premium: false,
  },
  {
    id: 'responsible-ai',
    title: { ru: 'Ответственное использование ИИ', en: 'Responsible AI Practice' },
    description: { ru: 'Защита данных, человеческий контроль и будущее технологий.', en: 'Privacy, human oversight, and technology futures.' },
    lessonSlugs: OSA_LESSON_SLUGS.slice(5, 8),
    premium: false,
  },
]

export function getOSATrackProgress(track: OSALearningTrack, completed: readonly string[]) {
  const valid = new Set<string>(OSA_LESSON_SLUGS)
  const lessons = [...new Set(track.lessonSlugs.filter(slug => valid.has(slug)))]
  const completedSet = new Set(completed)
  const done = lessons.filter(slug => completedSet.has(slug)).length
  return { completed: done, total: lessons.length, percent: lessons.length ? Math.round(done / lessons.length * 100) : 0 }
}

export function getOSANextLesson(completed: readonly string[]): string | null {
  return OSA_LESSON_SLUGS.find(slug => !completed.includes(slug)) ?? null
}
