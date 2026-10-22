import { useEffect } from 'react'
import type { RefObject } from 'react'

/** Decorative work pauses offscreen and never intercepts a navigation or game input. */
export function usePlayMotion(root: RefObject<HTMLElement | null>) {
  useEffect(() => {
    const host = root.current
    if (!host) return
    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)')
    const fine = window.matchMedia('(hover: hover) and (pointer: fine)')
    const connection = (navigator as Navigator & { connection?: { saveData?: boolean } }).connection
    let frame = 0
    let observer: IntersectionObserver | undefined
    const sync = () => {
      const active = !reduced.matches && document.documentElement.dataset.motion !== 'off' && !connection?.saveData
      host.dataset.animated = String(active)
      if (!active) {
        host.style.setProperty('--scene-x', '0px')
        host.style.setProperty('--scene-y', '0px')
        host.querySelectorAll<HTMLElement>('[data-reveal]').forEach(el => el.classList.add('is-visible'))
      }
    }
    const onPointer = (event: PointerEvent) => {
      if (host.dataset.animated !== 'true' || !fine.matches || frame) return
      const hero = host.querySelector<HTMLElement>('.cp-hero')
      if (!hero) return
      const box = hero.getBoundingClientRect()
      if (box.bottom <= 0 || event.clientY > box.bottom) return
      frame = requestAnimationFrame(() => {
        host.style.setProperty('--scene-x', ((event.clientX / Math.max(box.width, 1) - .5) * 9).toFixed(2) + 'px')
        host.style.setProperty('--scene-y', ((event.clientY / Math.max(box.height, 1) - .5) * 6).toFixed(2) + 'px')
        frame = 0
      })
    }
    const observeReveals = () => {
      host.querySelectorAll<HTMLElement>('[data-reveal]').forEach(el => {
        if (!observer || host.dataset.animated !== 'true') el.classList.add('is-visible')
        else if (!el.classList.contains('is-visible')) observer.observe(el)
      })
    }
    sync()
    if (typeof window.IntersectionObserver === 'function') {
      observer = new IntersectionObserver(entries => {
        entries.forEach(entry => {
          if (entry.target.classList.contains('cp-hero')) {
            host.dataset.heroVisible = String(entry.isIntersecting && !document.hidden)
          } else if (entry.isIntersecting) {
            entry.target.classList.add('is-visible')
            observer?.unobserve(entry.target)
          }
        })
      }, { rootMargin: '0px 0px -24px 0px', threshold: .04 })
      const hero = host.querySelector('.cp-hero')
      if (hero) observer.observe(hero)
    }
    observeReveals()
    // Exploration is inserted after its deferred import. Observe newly mounted
    // sections as well; an absent observer always leaves them fully visible.
    const mutation = new MutationObserver(() => { sync(); observeReveals() })
    mutation.observe(document.documentElement, { attributes: true, attributeFilter: ['data-motion'] })
    mutation.observe(host, { childList: true, subtree: true })
    const visibility = () => {
      const hero = host.querySelector('.cp-hero')
      host.dataset.heroVisible = String(!document.hidden && Boolean(hero && hero.getBoundingClientRect().bottom > 0))
    }
    document.addEventListener('visibilitychange', visibility)
    reduced.addEventListener('change', sync)
    host.addEventListener('pointermove', onPointer, { passive: true })
    return () => {
      cancelAnimationFrame(frame)
      observer?.disconnect()
      mutation.disconnect()
      reduced.removeEventListener('change', sync)
      document.removeEventListener('visibilitychange', visibility)
      host.removeEventListener('pointermove', onPointer)
    }
  }, [root])
}
