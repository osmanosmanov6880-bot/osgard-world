import { studioIds } from './osaCinemaStudioRegistry'

/** Local preferences only. Never an account, licence, entitlement or stream history. */
export const OSA_STUDIO_WATCHLIST_KEY = 'osa-studio-favorites-v1'
export const OSA_STUDIO_WATCHLIST_EVENT = 'osa-studio-watchlist-change'
export const OSA_STUDIO_BACKUP_SCHEMA = 'OSA_CINEMA_WATCHLIST_V1'
const knownIds = new Set<string>(studioIds)
export const OSA_STUDIO_MAX_IMPORT_BYTES = 16 * 1024

export function normalizeWatchlist(value: unknown): string[] {
  if (!Array.isArray(value)) return []
  const found: string[] = []
  for (const id of value) {
    if (typeof id !== 'string' || !knownIds.has(id) || found.includes(id)) continue
    found.push(id)
    if (found.length === knownIds.size) break
  }
  return found
}
function storage(): Storage | null {
  try { return typeof window === 'undefined' ? null : window.localStorage } catch { return null }
}
export function readWatchlist(): string[] {
  try {
    const raw = storage()?.getItem(OSA_STUDIO_WATCHLIST_KEY)
    return raw ? normalizeWatchlist(JSON.parse(raw) as unknown) : []
  } catch { return [] }
}
export function writeWatchlist(value: unknown): boolean {
  const store = storage()
  if (!store) return false
  try {
    store.setItem(OSA_STUDIO_WATCHLIST_KEY, JSON.stringify(normalizeWatchlist(value)))
    window.dispatchEvent(new Event(OSA_STUDIO_WATCHLIST_EVENT))
    return true
  } catch { return false }
}
export function subscribeWatchlist(callback: () => void): () => void {
  if (typeof window === 'undefined') return () => undefined
  const storageChanged = (event: StorageEvent) => {
    if (event.key === OSA_STUDIO_WATCHLIST_KEY || event.key === null) callback()
  }
  window.addEventListener(OSA_STUDIO_WATCHLIST_EVENT, callback)
  window.addEventListener('storage', storageChanged)
  return () => {
    window.removeEventListener(OSA_STUDIO_WATCHLIST_EVENT, callback)
    window.removeEventListener('storage', storageChanged)
  }
}
export function exportWatchlist(value: unknown, generatedAt: string = new Date().toISOString()): string {
  const data = {
    schema: OSA_STUDIO_BACKUP_SCHEMA,
    version: 1,
    generatedAt,
    storage: 'local_device_only',
    favorites: normalizeWatchlist(value),
  }
  return JSON.stringify(data, null, 2) + '\n'
}
export function parseWatchlistBackup(text: string): string[] | null {
  if (typeof text !== 'string' || text.length < 1 || text.length > OSA_STUDIO_MAX_IMPORT_BYTES) return null
  try {
    const value: unknown = JSON.parse(text)
    if (!value || typeof value !== 'object' || Array.isArray(value)) return null
    const data = value as Record<string, unknown>
    if (data.schema !== OSA_STUDIO_BACKUP_SCHEMA || data.version !== 1 || data.storage !== 'local_device_only' ||
        !Array.isArray(data.favorites) || data.favorites.length > 64 ||
        typeof data.generatedAt !== 'string' || Number.isNaN(Date.parse(data.generatedAt))) return null
    if (!data.favorites.every(id => typeof id === 'string' && knownIds.has(id))) return null
    return normalizeWatchlist(data.favorites)
  } catch { return null }
}
