import React, { useCallback, useEffect, useRef, useState } from 'react'
import type { OsgardCinematicProps } from './OsgardCinematic'
import { OSGARD_NAVIGATION_EVENT } from './browserNavigation'
import type { NavigationNotice } from './browserNavigation'
import { INTRO_STORAGE_KEY, MOTION_CHANGE_EVENT, REPLAY_INTRO_EVENT, introEligible, isLowPowerDevice, majorSectionForPath } from './osgardRouting'

type Session = { id: number; kind: OsgardCinematicProps['kind']; phase: string; replay: boolean }
let shownInDocument = false
let visualPromise: Promise<typeof import('./OsgardCinematic')> | undefined
const hasSeenIntro = () => {
  if (shownInDocument) return true
  try { return localStorage.getItem(INTRO_STORAGE_KEY) === 'seen' } catch { return false }
}

class CinematicBoundary extends React.Component<{ onFailure: () => void; children: React.ReactNode }, { failed: boolean }> {
  state = { failed: false }
  static getDerivedStateFromError() { return { failed: true } }
  componentDidCatch() { this.props.onFailure() }
  render() { return this.state.failed ? null : this.props.children }
}

/** The route renders immediately beneath a finite, optional visual layer. */
export default function OsgardTransitionProvider({ children }: { children: React.ReactNode }) {
  const [session, setSession] = useState<Session | null>(() => introEligible() && !hasSeenIntro() ? { id: 1, kind: 'intro', phase: 'awakening', replay: false } : null)
  const [Visual, setVisual] = useState<React.ComponentType<OsgardCinematicProps> | null>(null)
  const active = useRef(session)
  const sequence = useRef(1)
  const previousFocus = useRef<HTMLElement | null>(typeof document === 'undefined' ? null : document.activeElement as HTMLElement | null)
  const overlay = useRef<HTMLDivElement>(null)
  const revealTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined)
  const focusTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined)
  const clearReveal = useCallback(() => {
    clearTimeout(revealTimer.current)
    delete document.documentElement.dataset.osgardReveal
  }, [])
  const reveal = useCallback(() => {
    clearReveal()
    if (!introEligible()) return
    document.documentElement.dataset.osgardReveal = 'true'
    revealTimer.current = setTimeout(clearReveal, 900)
  }, [clearReveal])
  const finish = useCallback((id: number, skipped = false) => {
    const running = active.current
    if (!running || running.id !== id) return
    active.current = null
    setSession(null)
    if (skipped || !introEligible()) clearReveal()
    clearTimeout(focusTimer.current)
    focusTimer.current = setTimeout(() => {
      if (active.current) return
      const target = running.replay && previousFocus.current?.isConnected ? previousFocus.current : document.getElementById('product-main')
      target?.focus({ preventScroll: true })
      // A connected replay trigger can become disabled or hidden during playback.
      if (document.activeElement !== target) document.getElementById('product-main')?.focus({ preventScroll: true })
    }, 0)
  }, [clearReveal])
  const begin = useCallback((kind: Session['kind'], replay = false) => {
    clearReveal()
    clearTimeout(focusTimer.current)
    previousFocus.current = document.activeElement as HTMLElement | null
    const next: Session = { id: ++sequence.current, kind, phase: kind === 'intro' ? 'awakening' : 'activation', replay }
    active.current = next
    setSession(next)
  }, [clearReveal])

  useEffect(() => {
    try { sessionStorage.removeItem('osgard:portal-navigation:v2') } catch { /* Static game transitions retain their own implementation. */ }
    const navigation = (event: Event) => {
      const { from, to, action } = (event as CustomEvent<NavigationNotice>).detail
      if (action !== 'push' && action !== 'pop') return
      const source = new URL(from, location.origin)
      const target = new URL(to, location.origin)
      if (source.pathname === target.pathname) return
      if (active.current) finish(active.current.id, true)
      if (!introEligible() || majorSectionForPath(source.pathname) === majorSectionForPath(target.pathname)) return
      begin(majorSectionForPath(target.pathname) === 'play' ? 'play' : 'transition')
    }
    const replay = () => { if (introEligible()) begin('intro', true) }
    const settings = () => {
      if (active.current && !introEligible()) finish(active.current.id, true)
      if (!introEligible()) clearReveal()
    }
    const media = window.matchMedia?.('(prefers-reduced-motion: reduce)')
    const observer = typeof MutationObserver === 'undefined' ? null : new MutationObserver(settings)
    observer?.observe(document.documentElement, { attributes: true, attributeFilter: ['data-motion'] })
    window.addEventListener(OSGARD_NAVIGATION_EVENT, navigation)
    window.addEventListener(REPLAY_INTRO_EVENT, replay)
    window.addEventListener(MOTION_CHANGE_EVENT, settings)
    window.addEventListener('storage', settings)
    media?.addEventListener('change', settings)
    return () => {
      observer?.disconnect()
      window.removeEventListener(OSGARD_NAVIGATION_EVENT, navigation)
      window.removeEventListener(REPLAY_INTRO_EVENT, replay)
      window.removeEventListener(MOTION_CHANGE_EVENT, settings)
      window.removeEventListener('storage', settings)
      media?.removeEventListener('change', settings)
      clearReveal()
      clearTimeout(focusTimer.current)
    }
  }, [begin, clearReveal, finish])

  useEffect(() => {
    if (!session) return
    const { id, kind } = session
    if (!introEligible()) { finish(id, true); return }
    if (kind === 'intro') {
      shownInDocument = true
      try { localStorage.setItem(INTRO_STORAGE_KEY, 'seen') } catch { /* Once per document remains available if persistence is disabled. */ }
    }
    const timers: ReturnType<typeof setTimeout>[] = []
    const at = (delay: number, callback: () => void) => timers.push(setTimeout(() => { if (active.current?.id === id) callback() }, delay))
    const phase = (value: string) => setSession(current => current?.id === id ? { ...current, phase: value } : current)
    if (Visual) {
      // CSS starts when the visual mounts. Use the same start for the deadline,
      // so a cold chunk cannot consume the logo's actual reveal time.
      if (kind === 'intro') {
        at(650, () => phase('activation'))
        at(1350, () => phase('reveal'))
        at(2150, () => phase('online'))
        at(3000, () => { phase('enter'); reveal() })
      } else at(550, () => { phase('enter'); reveal() })
      at(kind === 'intro' ? 3600 : 900, () => finish(id))
    } else {
      // A slow/failed optional import never holds the real interface indefinitely.
      at(kind === 'intro' ? 800 : 300, () => finish(id, true))
      const emblem = new Image()
      emblem.src = '/brand/intro/osgard-emblem-640.webp'
      if (!visualPromise) visualPromise = import('./OsgardCinematic')
      visualPromise.then(module => {
        if (active.current?.id === id) setVisual(() => module.default)
      }).catch(() => { visualPromise = undefined; finish(id, true) })
    }
    const keydown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') { event.preventDefault(); finish(id, true) }
      if (event.key === 'Tab') {
        const buttons = overlay.current?.querySelectorAll<HTMLElement>('button:not([disabled]), a[href], [tabindex="0"]')
        if (!buttons?.length) return
        const first = buttons[0], last = buttons[buttons.length - 1]
        if (event.shiftKey && (document.activeElement === first || !overlay.current?.contains(document.activeElement)) || !event.shiftKey && (document.activeElement === last || !overlay.current?.contains(document.activeElement))) {
          event.preventDefault(); (event.shiftKey ? last : first).focus()
        }
      }
    }
    document.documentElement.dataset.osgardCinematic = kind
    window.addEventListener('keydown', keydown)
    return () => {
      timers.forEach(clearTimeout)
      window.removeEventListener('keydown', keydown)
      delete document.documentElement.dataset.osgardCinematic
    }
  // Phases update presentation without resetting the finite timeline.
  }, [session?.id, Visual, finish, reveal])

  return <>
    <div data-osgard-content inert={session ? true : undefined} aria-hidden={session ? true : undefined}>{children}</div>
    {session && <div ref={overlay} key={session.id}>
      <CinematicBoundary onFailure={() => finish(session.id, true)}>
        {Visual ? <Visual kind={session.kind} phase={session.phase} lowPower={isLowPowerDevice()} onComplete={() => finish(session.id)} onSkip={() => finish(session.id, true)} /> :
          <section data-osgard-pending role="dialog" aria-modal="true" aria-label="Заставка OSGARD" style={{ position: 'fixed', inset: 0, zIndex: 10000, background: '#020814', color: '#F7FBFF' }}>
            <button type="button" autoFocus onClick={() => finish(session.id, true)} style={{ position: 'absolute', right: 'max(24px, env(safe-area-inset-right))', top: 'max(24px, env(safe-area-inset-top))', padding: '12px 20px', color: 'inherit', background: '#061527', border: '1px solid #56F4F5', borderRadius: 4 }}>Пропустить</button>
          </section>}
      </CinematicBoundary>
    </div>}
  </>
}
