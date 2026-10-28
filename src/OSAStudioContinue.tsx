import { useEffect, useState } from 'react'
import { ArrowRight, BookmarkCheck, Clapperboard } from 'lucide-react'
import { getOSALearningProgress, subscribeOSALearningProgress } from './osaProgress'
import type { StudioLocale } from './osaCinemaStudioRegistry'

type Session = { index: number; completed: boolean; hasStoryEvidence: boolean }
const TOTAL_SCENES = 8
function readSession(): Session {
  const { cinema, updatedAt } = getOSALearningProgress()
  void updatedAt
  const hasStoryEvidence = cinema.completed || cinema.index > 0 || Object.keys(cinema.answers).length > 0 || Object.values(cinema.selfChecks).some(Boolean)
  return { index: cinema.index, completed: cinema.completed, hasStoryEvidence }
}
/** Displays only progress that the original interactive player really saved.
 * Stored locally; never masquerades as streaming history or a server account.
 */
export default function OSAStudioContinue({ locale }: { locale: StudioLocale }) {
  const [session, setSession] = useState<Session>(readSession)
  useEffect(() => subscribeOSALearningProgress(() => setSession(readSession())), [])
  if (!session.hasStoryEvidence) return null
  const ru = locale === 'ru'
  const scene = session.completed ? 0 : Math.min(Math.max(session.index, 0), TOTAL_SCENES - 1)
  const percentage = session.completed ? 100 : Math.round((scene + 1) / TOTAL_SCENES * 100)
  const url = '/osa-cinema?lang=' + locale + '&scene=' + scene
  return <section className="osa-studio-continue" aria-labelledby="osa-studio-continue-title">
    <div className="osa-studio-continue-icon" aria-hidden="true"><Clapperboard size={26}/></div>
    <div className="osa-studio-continue-copy">
      <span className="osa-studio-eyebrow">YOUR CINEMA / LOCAL PROGRESS</span>
      <h2 id="osa-studio-continue-title">{ru ? 'Ваша история продолжается.' : 'Your story continues.'}</h2>
      <p>{session.completed ? (ru ? 'Интерактивная история пройдена. Вы можете посмотреть её снова.' : 'You have completed the interactive story. You can revisit it.') : (ru ? 'Вы дошли до сцены ' + (scene + 1) + ' из ' + TOTAL_SCENES + '. Ваш прогресс хранится только на этом устройстве.' : 'You reached scene ' + (scene + 1) + ' of ' + TOTAL_SCENES + '. Your progress stays on this device.')}</p>
      <div className="osa-studio-continue-meter" role="progressbar" aria-label={ru ? 'Прогресс интерактивной истории' : 'Interactive story progress'} aria-valuemin={0} aria-valuemax={100} aria-valuenow={percentage}><span style={{ width: percentage + '%' }}/></div>
    </div>
    <a className="osa-studio-continue-action" href={url}><BookmarkCheck size={16}/>{session.completed ? (ru ? 'Пройти снова' : 'Replay') : (ru ? 'Продолжить' : 'Resume')}<ArrowRight size={16}/></a>
  </section>
}
