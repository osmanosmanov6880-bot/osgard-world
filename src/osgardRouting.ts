/** Only pages actually rendered by the React application participate in SPA navigation. */
const reactPaths = new Set(('/ /portal /intelligence /development /academy /osa-cinema /lectures /learning /learning/assessment /learning/program /learning/workspace /learning/portfolio /learning/experiments /learning/project /learning/pricing /learning/organizer /learning/campus /learning/enrollment /teams /deliveries /purchases /workspace/overview /workspace /account /data /brand /quality /play /games /entertainment /play/partners /play/swarm /play/null-shift /play/inherit /play/remix /miniapp /week /next /archive /profile /community /stream /marcosa /media /core-events /mobility /create /business /worlds /aurum /timecoin /catalog /chronicle /masters /club').split(' '))
export const INTRO_STORAGE_KEY = 'osgard:intro:v1'
export const REPLAY_INTRO_EVENT = 'osgard:replay-intro'
export const MOTION_CHANGE_EVENT = 'osgard:motionchange'
export const normalizeReactPath = (path: string) => path.replace(/\/+$/, '') || '/'
export const isAccountRoute = (path: string) => ['/account', '/workspace', '/workspace/overview', '/teams', '/deliveries', '/purchases', '/data', '/learning/campus', '/learning/organizer', '/learning/enrollment'].includes(normalizeReactPath(path))
export function isReactRoute(path: string): boolean {
  const normalized = normalizeReactPath(path)
  return reactPaths.has(normalized) || /^\/(play\/world|lectures|r)\/[^/]+$/.test(normalized)
}

export function majorSectionForPath(path: string): 'world' | 'development' | 'intelligence' | 'play' | 'account' {
  const current = normalizeReactPath(path)
  if (isAccountRoute(current)) return 'account'
  if (current === '/development') return 'development'
  if (/^\/(play|games)(\/|$)/.test(current) || current === '/entertainment') return 'play'
  if (/^\/(learning|lectures)(\/|$)/.test(current) || ['/academy', '/intelligence', '/osa-cinema'].includes(current)) return 'intelligence'
  return 'world'
}

export function isEmbedded(): boolean {
  if (typeof window === 'undefined') return true
  try { return window.self !== window.top } catch { return true }
}

export function isLowPowerDevice(): boolean {
  if (typeof navigator === 'undefined') return false
  const device = navigator as Navigator & { deviceMemory?: number }
  return Boolean(device.deviceMemory && device.deviceMemory <= 2 || device.hardwareConcurrency && device.hardwareConcurrency <= 2)
}

/** User motion/data preferences and embedded games always bypass the optional sequence. */
export function introEligible(): boolean {
  if (isEmbedded() || !isReactRoute(location.pathname)) return false
  if (window.matchMedia?.('(prefers-reduced-motion: reduce)').matches || document.documentElement.dataset.motion === 'off') return false
  try { if (localStorage.getItem('osgard:motion') === 'off') return false } catch { /* A private window can still opt out for this document. */ }
  return !(navigator as Navigator & { connection?: { saveData?: boolean } }).connection?.saveData
}
