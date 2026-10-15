import { useCallback, useEffect, useRef, useState } from 'react'
import { OSAMark } from './OSAMark'

type Props = { onComplete: () => void }
const SEEN_KEY = 'osgard-preloader-seen-v3'
function hasSeenIntro() {
  try { return window.sessionStorage.getItem(SEEN_KEY) === '1' } catch { return false }
}

export function Preloader({ onComplete }: Props) {
  const alreadySeen = useRef(hasSeenIntro()).current
  const [leaving, setLeaving] = useState(false)
  const completed = useRef(false)

  const finish = useCallback(() => {
    if (completed.current) return
    completed.current = true
    try { window.sessionStorage.setItem(SEEN_KEY, '1') } catch { /* private browsing can disable storage */ }
    setLeaving(true)
    window.setTimeout(onComplete, 260)
  }, [onComplete])

  useEffect(() => {
    if (alreadySeen || window.location.pathname === '/miniapp') {
      onComplete()
      return
    }
    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    const timer = window.setTimeout(finish, reduced ? 80 : 910)
    return () => window.clearTimeout(timer)
  }, [alreadySeen, finish, onComplete])

  if (alreadySeen) return null

  return <div className={'access-preloader osa5-intro' + (leaving ? ' is-leaving' : '')} role="dialog" aria-modal="true" aria-label="OSGARD WORLD · OSA 5.0">
    <div className="osa5-intro-light" aria-hidden="true" />
    <div className="osa5-intro-lockup">
      <OSAMark variant="lockup" className="osa5-intro-mark" />
      <p>OSGARD WORLD <span>·</span> ONE CONNECTED ECOSYSTEM</p>
    </div>
    <div className="osa5-intro-controls"><button type="button" onClick={finish}>Пропустить <span aria-hidden="true">↗</span></button></div>
  </div>
}
