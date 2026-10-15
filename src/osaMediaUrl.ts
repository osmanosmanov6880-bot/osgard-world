const TEMPORARY_QUERY_KEYS = new Set([
  '_jwt', 'jwt', 'token', 'access_token', 'signature', 'sig', 'expires', 'expiry',
  'policy', 'key-pair-id', 'x-amz-signature', 'x-amz-credential', 'x-amz-security-token',
])

/**
 * Accepts durable HTTPS media URLs or same-origin public paths.
 * Rejects temporary/signed delivery URLs so they cannot silently become production sources.
 */
export function isPermanentMediaUrl(source: string | null | undefined): source is string {
  if (typeof source !== 'string' || !source.trim()) return false
  const value = source.trim()
  if (value.startsWith('//') || value.indexOf(String.fromCharCode(92)) >= 0) return false

  if (value.startsWith('/')) {
    if (value.startsWith('/../') || value.includes('/./')) return false
    const query = value.includes('?') ? value.slice(value.indexOf('?') + 1) : ''
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
