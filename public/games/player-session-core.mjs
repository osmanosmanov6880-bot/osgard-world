// OSGARD PLAY — intentionally store only the last world, not an invented game save.
export const LAST_WORLD_KEY = 'osgard.games.last-world.v1'
export const LAST_WORLD_MAX_AGE_MS = 45 * 24 * 60 * 60 * 1000

export function createLastWorld(id, allowedIds, now = Date.now()) {
  if (typeof id !== 'string' || !allowedIds.has(id)) return null
  if (!Number.isSafeInteger(now) || now < 1) return null
  return { version: 1, id, openedAt: now }
}

export function parseLastWorld(value, allowedIds, now = Date.now()) {
  if (typeof value !== 'string' || !value.trim()) return null
  let record
  try { record = JSON.parse(value) } catch { return null }
  if (!record || record.version !== 1 || typeof record.id !== 'string' || !allowedIds.has(record.id)) return null
  if (!Number.isSafeInteger(record.openedAt) || !Number.isSafeInteger(now)) return null
  if (record.openedAt > now + 60_000 || now - record.openedAt > LAST_WORLD_MAX_AGE_MS) return null
  return { version: 1, id: record.id, openedAt: record.openedAt }
}

export function gameRouteFromCard(card, baseUrl) {
  const link = card?.querySelector('.game-actions a.play-link[href], a.art[href]')
  if (!link) return null
  try {
    const url = new URL(link.href, baseUrl)
    if (url.origin !== new URL(baseUrl).origin || !url.pathname.startsWith('/games/') && !url.pathname.startsWith('/play/')) return null
    return url.href
  } catch { return null }
}
