export type OSAStoredAttempt = { at: string; correct: number; total: number }
const STORAGE_KEY = 'osa6-assessment-attempts-v1'
const LIMIT = 20

export function readOSAAttempts(): OSAStoredAttempt[] {
  try {
    const parsed: unknown = JSON.parse(window.localStorage.getItem(STORAGE_KEY) || '[]')
    if (!Array.isArray(parsed)) return []
    return parsed.filter((item): item is OSAStoredAttempt =>
      typeof item === 'object' && item !== null &&
      typeof item.at === 'string' && !Number.isNaN(Date.parse(item.at)) &&
      Number.isInteger(item.correct) && item.correct >= 0 && item.correct <= 8 && item.total === 8
    ).slice(0, LIMIT)
  } catch { return [] }
}

export function recordOSAAttempt(correct: number): boolean {
  if (!Number.isInteger(correct) || correct < 0 || correct > 8) return false
  try {
    const next = [{ at: new Date().toISOString(), correct, total: 8 }, ...readOSAAttempts()].slice(0, LIMIT)
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(next))
    window.dispatchEvent(new Event('osa6:attempts-changed'))
    return true
  } catch { return false }
}

export function clearOSAAttempts(): boolean {
  try {
    window.localStorage.removeItem(STORAGE_KEY)
    window.dispatchEvent(new Event('osa6:attempts-changed'))
    return true
  } catch { return false }
}
