import { OSA_LESSON_SLUGS, osaLessonGuides, type OSALessonLocale } from './osaLessonGuides'
import { getOSALearningProgress } from './osaProgress'

export type OSAQuizAnswer = { slug: string; selectedIndex: number; correct: boolean }
export type OSAQuizResult = { correct: number; total: number; percent: number; passed: boolean; answers: OSAQuizAnswer[] }

export function gradeOSAQuiz(answers: Record<string, number>, locale: OSALessonLocale): OSAQuizResult {
  const rows = OSA_LESSON_SLUGS.map((slug, index) => {
    const selectedIndex = answers[slug]
    const check = osaLessonGuides[locale][index].check
    return { slug, selectedIndex, correct: Number.isInteger(selectedIndex) && selectedIndex === check.correctIndex }
  })
  const correct = rows.filter(row => row.correct).length
  return { correct, total: rows.length, percent: Math.round(correct / rows.length * 100), passed: correct >= 6, answers: rows }
}

export function canCompleteOSATrack(lessonSlugs: readonly string[]): boolean {
  const completed = new Set(getOSALearningProgress().lessonCompletions)
  return lessonSlugs.every(slug => completed.has(slug))
}
