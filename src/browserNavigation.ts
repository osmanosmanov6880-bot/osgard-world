/** replaceState does not emit popstate: keep product navigation in sync explicitly. */
export const BROWSER_LOCATION_EVENT = 'osgard:locationchange'

export function browserLocationKey(): string {
  return location.pathname + (location.search || '') + (location.hash || '')
}

export function replaceBrowserUrl(href: string): void {
  if (browserLocationKey() === href) return
  history.replaceState(history.state, '', href)
  window.dispatchEvent(new Event(BROWSER_LOCATION_EVENT))
}

/** Called after the lazy page commits, when a native fragment target can finally exist. */
export function restorePageFragment(): void {
  if (!location.hash || location.hash === '#') return
  let id: string
  try { id = decodeURIComponent(location.hash.slice(1)) } catch { return }
  const target = document.getElementById(id)
  if (!target) return
  // A user who has already moved on while the chunk loaded keeps control of the page.
  if (window.scrollY > 0) return
  target.scrollIntoView({ behavior: 'instant', block: 'start' })
}
