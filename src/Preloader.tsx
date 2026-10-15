import { useCallback, useEffect, useRef, useState } from 'react'
import { OSAMark } from './OSAMark'

type Props = { onComplete: () => void }
const SEEN_KEY = 'osgard-preloader-seen-v3'
function hasSeenIntro() {
  try { return window.sessionStorage.getItem(SEEN_KEY) === '1' } catch { return false }
}

export function Preloader({ onComplete }: Props) {
  const shouldSkipIntro = useRef(
    hasSeenIntro()
    || window.location.pathname === '/miniapp'
    || window.matchMedia('(prefers-reduced-motion: reduce)').matches
  ).current
  const skipButtonRef = useRef<HTMLButtonElement>(null)
  const previousFocusRef = useRef<HTMLElement | null>(null)
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
    if (shouldSkipIntro) {
      onComplete()
      return
    }

    const active = document.activeElement
    previousFocusRef.current = active instanceof HTMLElement && active !== document.body ? active : null
    skipButtonRef.current?.focus({ preventScroll: true })
    const timer = window.setTimeout(finish, 910)
    return () => {
      window.clearTimeout(timer)
      const previous = previousFocusRef.current
      if (previous?.isConnected) previous.focus({ preventScroll: true })
    }
  }, [shouldSkipIntro, finish, onComplete])

  if (shouldSkipIntro) return null

  return <div
    className={'access-preloader osa5-intro' + (leaving ? ' is-leaving' : '')}
    role="dialog"
    aria-modal="true"
    aria-label="OSGARD WORLD · OSA 5.0"
    aria-describedby="osa5-intro-description"
    onKeyDown={event => {
      if (event.key === 'Escape') {
        event.preventDefault()
        finish()
      } else if (event.key === 'Tab') {
        // The skip control is the only interactive item in this short modal.
        event.preventDefault()
        skipButtonRef.current?.focus()
      }
    }}
  >
    <div className="osa5-intro-light" aria-hidden="true" />
    <div className="osa5-intro-lockup">
      <OSAMark variant="lockup" className="osa5-intro-mark" />
      <p id="osa5-intro-description">OSGARD WORLD <span>·</span> ONE CONNECTED ECOSYSTEM</p>
    </div>
    <div className="osa5-intro-controls"><button ref={skipButtonRef} type="button" onClick={finish}>Пропустить <span aria-hidden="true">↗</span></button></div>
  </div>
}
