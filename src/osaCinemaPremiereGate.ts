/** V49: only a real, publisher-approved, SHA-pinned film may appear in navigation. */
export const PREMIERE_PATH = '/osa-cinema/premiere/' as const
export const FULL_RU_SHA256 = 'c6e71377c2f4ecdcf8327c9ae213cd972a78ea6f97f9090945a7d18fad0fe751' as const
export const FULL_RU_BYTES = 87058919 as const

export function isLivePremiereReceipt(value: unknown): boolean {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false
  const r = value as Record<string, unknown>
  return r.schemaVersion === 1 && r.project === 'OSA CINEMA' &&
    r.status === 'PUBLIC_BROWSER_QA_PASS' && r.publicationAuthorized === true &&
    r.paidCheckoutEnabled === false && r.publicPath === PREMIERE_PATH &&
    r.fullRuSha256 === FULL_RU_SHA256 && r.assetCount === 8 &&
    typeof r.releaseId === 'string' && /^osa-v[0-9]+-[a-z0-9-]{3,50}$/.test(r.releaseId)
}

export function isPlayableFullFilmResponse(status: number, contentType: string | null, contentLength: string | null): boolean {
  return (status === 200 || status === 206) &&
    typeof contentType === 'string' && /^video\/mp4(?:\s*;|$)/i.test(contentType) &&
    contentLength !== null && /^\d+$/.test(contentLength) && Number(contentLength) === FULL_RU_BYTES
}
