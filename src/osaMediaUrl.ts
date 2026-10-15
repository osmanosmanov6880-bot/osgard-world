const TEMPORARY_QUERY_KEYS = new Set([
  '_jwt', 'jwt', 'token', 'access_token', 'signature', 'sig', 'expires', 'expiry',
  'policy', 'key-pair-id', 'x-amz-signature', 'x-amz-credential', 'x-amz-security-token',
])

/**
 * Accepts durable HTTPS media URLs or same-origin public paths.
 * Rejects temporary/signed delivery URLs so they cannot silently become production sources.
 */
export function isPermanentMediaUrl(source: string | null | undefined): source is string {
  if (typeof source !== 'string' || !source.trim() || source !== source.trim()) return false
  if (/[\u0000-\u001f\u007f]/.test(source)) return false
  const value = source.trim()
  if (value.startsWith('//') || value.indexOf(String.fromCharCode(92)) >= 0) return false

  if (value.startsWith('/')) {
    if (value.startsWith('/../') || value.includes('/./')) return false
    const path = value.split(/[?#]/, 1)[0]
    if (path.split('/').some(segment => {
      try { const decoded = decodeURIComponent(segment); return decoded === '..' || decoded === '.' || decoded.includes('/') || decoded.includes(String.fromCharCode(92)) } catch { return true }
    })) return false
    const query = value.includes('?') ? value.slice(value.indexOf('?') + 1).split('#', 1)[0] : ''
    const params = new URLSearchParams(query)
    for (const key of params.keys()) {
      if (TEMPORARY_QUERY_KEYS.has(key.toLowerCase())) return false
    }
    return true
  }

  try {
    const url = new URL(value)
    if (url.protocol !== 'https:' || url.username || url.password) return false
    for (const key of url.searchParams.keys()) {
      if (TEMPORARY_QUERY_KEYS.has(key.toLowerCase())) return false
    }
    return true
  } catch {
    return false
  }
}
