import { isEmbedded, isReactRoute, normalizeReactPath } from './osgardRouting.ts'

/** replaceState does not emit popstate: keep product navigation in sync explicitly. */
export const BROWSER_LOCATION_EVENT = 'osgard:locationchange'
export const OSGARD_NAVIGATION_EVENT = 'osgard:navigation'
export type NavigationAction = 'initial' | 'push' | 'pop' | 'replace' | 'hash'
export type BrowserSnapshot = { href: string; revision: number; action: NavigationAction }
export type NavigationNotice = { from: string; to: string; action: NavigationAction }

export function browserLocationKey(): string {
  return typeof location === 'undefined' ? '/' : location.pathname + (location.search || '') + (location.hash || '')
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

type HistoryEntry = { id: string; index: number; scroll: [number, number] }
const HISTORY_KEY = '__osgardNavigation'
const listeners = new Set<() => void>()
const positions = new Map<string, [number, number]>()
let snapshot: BrowserSnapshot | undefined
let serverSnapshot: BrowserSnapshot | undefined
let currentEntry: HistoryEntry | undefined
let stop: (() => void) | undefined
let pendingScroll: { revision: number; href: string; point?: [number, number] } | undefined
let cancelScroll: (() => void) | undefined
let sequence = 0

export function getBrowserSnapshot(): BrowserSnapshot {
  if (!snapshot || !stop && snapshot.href !== browserLocationKey()) snapshot = { href: browserLocationKey(), revision: 0, action: 'initial' }
  return snapshot
}
export function getServerSnapshot(): BrowserSnapshot {
  const href = browserLocationKey()
  if (!serverSnapshot || serverSnapshot.href !== href) serverSnapshot = { href, revision: 0, action: 'initial' }
  return serverSnapshot
}
const pageKey = (href: string) => href.split('#')[0]
// coreLoginLink uses this URL for login/registration and a native post-login return.
const isCoreLoginUrl = (url: URL) => normalizeReactPath(url.pathname) === '/workspace' && url.searchParams.has('returnTo')
const entryFromState = (): HistoryEntry | undefined => {
  const value = history.state?.[HISTORY_KEY]
  return value && typeof value.id === 'string' && Number.isInteger(value.index) && Array.isArray(value.scroll) ? value : undefined
}
const newEntry = (index: number): HistoryEntry => ({ id: Date.now().toString(36) + '-' + ++sequence, index, scroll: [0, 0] })
const stateWithEntry = (entry: HistoryEntry) => ({ ...(history.state && typeof history.state === 'object' ? history.state : {}), [HISTORY_KEY]: entry })

/** Existing dirty forms already implement this cancelable event; no second dirty store is invented. */
export function hasUnsavedChanges(): boolean {
  return !window.dispatchEvent(new Event('beforeunload', { cancelable: true }))
}

function rememberScroll(persist = false): void {
  if (!currentEntry) return
  currentEntry = { ...currentEntry, scroll: [window.scrollX, window.scrollY] }
  positions.set(currentEntry.id, currentEntry.scroll)
  if (persist) history.replaceState(stateWithEntry(currentEntry), '', browserLocationKey())
}

function publish(action: NavigationAction, point?: [number, number]): void {
  const previous = getBrowserSnapshot()
  const href = browserLocationKey()
  if (previous.href === href) return
  const changedPage = pageKey(previous.href) !== pageKey(href)
  const revision = previous.revision + (changedPage && (action === 'push' || action === 'pop') ? 1 : 0)
  snapshot = { href, revision, action }
  cancelScroll?.()
  if (action === 'pop' || changedPage && action === 'push') pendingScroll = { href, revision, point }
  // Notify before React commits so the controller can capture the outgoing focus.
  window.dispatchEvent(new CustomEvent<NavigationNotice>(OSGARD_NAVIGATION_EVENT, { detail: { from: previous.href, to: href, action } }))
  listeners.forEach(listener => listener())
}

/** Returns false for a native boundary, including a form which reports unsaved changes. */
export function navigateBrowserUrl(href: string): boolean {
  if (isEmbedded()) return false
  let next: URL
  try { next = new URL(href, location.href) } catch { return false }
  if (next.origin !== location.origin || !/^https?:$/.test(next.protocol) || !isReactRoute(next.pathname) || !isReactRoute(location.pathname)) return false
  if (isCoreLoginUrl(next) || isCoreLoginUrl(new URL(location.href))) return false
  const destination = next.pathname + next.search + next.hash
  if (pageKey(destination) === pageKey(browserLocationKey())) return false
  if (hasUnsavedChanges()) return false
  rememberScroll(true)
  currentEntry = newEntry((currentEntry?.index ?? 0) + 1)
  history.pushState(stateWithEntry(currentEntry), '', destination)
  publish('push')
  return true
}

function startBrowserNavigation(): () => void {
  if (isEmbedded()) return () => {}
  currentEntry = entryFromState() || newEntry(0)
  history.replaceState(stateWithEntry(currentEntry), '', browserLocationKey())
  const previousRestoration = history.scrollRestoration
  history.scrollRestoration = 'manual'
  let restoring = false
  const click = (event: MouseEvent) => {
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    const anchor = event.target instanceof Element ? event.target.closest<HTMLAnchorElement>('a[href]') : null
    if (!anchor || anchor.hasAttribute('download') || anchor.target && anchor.target !== '_self' || anchor.rel.split(/\s+/).includes('external') || anchor.hasAttribute('data-native-navigation')) return
    if (navigateBrowserUrl(anchor.href)) event.preventDefault()
  }
  const pop = () => {
    if (restoring) { restoring = false; return }
    const previous = getBrowserSnapshot()
    const samePage = pageKey(previous.href) === pageKey(browserLocationKey())
    let nextEntry = entryFromState()
    if (samePage && (!nextEntry || nextEntry.id === currentEntry?.id)) {
      // A native anchor creates a history entry too. Give it a distinct index;
      // later Back/Forward can then restore its actual scroll position.
      nextEntry = newEntry((currentEntry?.index ?? 0) + 1)
      currentEntry = nextEntry
      history.replaceState(stateWithEntry(nextEntry), '', browserLocationKey())
      publish('hash')
      return
    }
    if (!samePage && hasUnsavedChanges() && !window.confirm('На странице есть несохранённые изменения. Покинуть страницу и потерять этот ввод?')) {
      const delta = (currentEntry?.index ?? 0) - (nextEntry?.index ?? 0)
      if (delta) { restoring = true; history.go(delta) }
      else history.pushState(stateWithEntry(currentEntry || newEntry(0)), '', previous.href)
      return
    }
    currentEntry = nextEntry || newEntry((currentEntry?.index ?? 0) - 1)
    publish('pop', positions.get(currentEntry.id) || currentEntry.scroll)
    if (samePage) completeBrowserNavigation(getBrowserSnapshot().revision)
  }
  const replace = () => publish('replace')
  const hash = () => {
    if (!restoring) {
      // Native fragment navigation creates its own history entry without our metadata.
      if (getBrowserSnapshot().href !== browserLocationKey()) {
        currentEntry = newEntry((currentEntry?.index ?? 0) + 1)
        history.replaceState(stateWithEntry(currentEntry), '', browserLocationKey())
      }
      publish('hash')
    }
  }
  const scroll = () => rememberScroll()
  const pagehide = () => rememberScroll(true)
  document.addEventListener('click', click)
  window.addEventListener('popstate', pop)
  window.addEventListener('hashchange', hash)
  window.addEventListener(BROWSER_LOCATION_EVENT, replace)
  window.addEventListener('scroll', scroll, { passive: true })
  window.addEventListener('pagehide', pagehide)
  return () => {
    cancelScroll?.()
    document.removeEventListener('click', click)
    window.removeEventListener('popstate', pop)
    window.removeEventListener('hashchange', hash)
    window.removeEventListener(BROWSER_LOCATION_EVENT, replace)
    window.removeEventListener('scroll', scroll)
    window.removeEventListener('pagehide', pagehide)
    history.scrollRestoration = previousRestoration
  }
}

export function subscribeBrowserNavigation(listener: () => void): () => void {
  listeners.add(listener)
  if (!stop && typeof window !== 'undefined') {
    // A child mount effect may canonicalize an alias before subscriptions attach.
    getBrowserSnapshot()
    stop = startBrowserNavigation()
  }
  return () => {
    listeners.delete(listener)
    if (!listeners.size) { stop?.(); stop = undefined }
  }
}

/** Run only after the destination's lazy route commits, never after a filter replaceState. */
export function completeBrowserNavigation(revision: number): void {
  if (isEmbedded()) return
  const pending = pendingScroll
  if (!pending || pending.revision !== revision) { if (!revision) restorePageFragment(); return }
  pendingScroll = undefined
  const url = new URL(pending.href, location.origin)
  let id = ''
  try { if (!pending.point) id = decodeURIComponent(url.hash.slice(1)) } catch { /* Invalid fragments do not affect route rendering. */ }
  let observer: MutationObserver | undefined
  let timeout: ReturnType<typeof setTimeout> | undefined
  const cleanup = () => {
    observer?.disconnect()
    clearTimeout(timeout)
    window.removeEventListener('wheel', cleanup)
    window.removeEventListener('touchstart', cleanup)
    window.removeEventListener('keydown', cleanup)
    if (cancelScroll === cleanup) cancelScroll = undefined
  }
  const apply = () => {
    if (getBrowserSnapshot().revision !== revision) { cleanup(); return }
    const target = id ? document.getElementById(id) : null
    if (target) { target.scrollIntoView({ behavior: 'instant', block: 'start' }); cleanup(); return }
    if (id) return
    const [x, y] = pending.point || [0, 0]
    window.scrollTo({ left: x, top: y, behavior: 'instant' })
    if (document.documentElement.scrollHeight - window.innerHeight >= y) cleanup()
  }
  cancelScroll?.()
  cancelScroll = cleanup
  if (typeof MutationObserver !== 'undefined') { observer = new MutationObserver(apply); observer.observe(document.getElementById('product-main') || document.body, { childList: true, subtree: true }) }
  timeout = setTimeout(cleanup, 5000)
  window.addEventListener('wheel', cleanup, { passive: true, once: true })
  window.addEventListener('touchstart', cleanup, { passive: true, once: true })
  window.addEventListener('keydown', cleanup, { once: true })
  apply()
  if (!document.querySelector('.osgard-cinematic, [data-osgard-pending]')) document.getElementById('product-main')?.focus({ preventScroll: true })
}
