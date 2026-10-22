import type { PointerEvent } from 'react'

export function magnet(event: PointerEvent<HTMLAnchorElement>) {
  if (event.pointerType !== 'mouse' || document.documentElement.dataset.motion === 'off' ||
    window.matchMedia('(prefers-reduced-motion: reduce)').matches) return
  const target = event.currentTarget
  const rect = target.getBoundingClientRect()
  target.style.setProperty('--magnet-x', ((event.clientX - rect.left - rect.width / 2) * .025).toFixed(1) + 'px')
  target.style.setProperty('--magnet-y', ((event.clientY - rect.top - rect.height / 2) * .07).toFixed(1) + 'px')
}
export function resetMagnet(event: PointerEvent<HTMLAnchorElement>) {
  event.currentTarget.style.setProperty('--magnet-x', '0px')
  event.currentTarget.style.setProperty('--magnet-y', '0px')
}
