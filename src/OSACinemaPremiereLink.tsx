import { useEffect, useState } from 'react'
import { isLivePremiereReceipt, isPlayableFullFilmResponse, PREMIERE_PATH } from './osaCinemaPremiereGate'

/** Hidden without a real release receipt AND an actual streaming MP4 response. */
export default function OSACinemaPremiereLink({ locale }: { locale: 'ru' | 'en' }) {
  const [available, setAvailable] = useState(false)
  useEffect(() => {
    const controller = new AbortController()
    const probe = async () => {
      try {
        const receipt = await fetch(PREMIERE_PATH + 'release.json', {
          cache: 'no-store', signal: controller.signal, headers: { Accept: 'application/json' },
        })
        if (!receipt.ok || !receipt.headers.get('content-type')?.includes('application/json')) return
        const body: unknown = await receipt.json()
        if (!isLivePremiereReceipt(body)) return
        const media = await fetch(PREMIERE_PATH + 'masters/osa-v48-directors-ru.mp4', {
          method: 'HEAD', cache: 'no-store', signal: controller.signal,
        })
        if (!isPlayableFullFilmResponse(media.status, media.headers.get('content-type'), media.headers.get('content-length'))) return
        if (!controller.signal.aborted) setAvailable(true)
      } catch { /* Missing/unreachable public film is never advertised. */ }
    }
    void probe()
    return () => controller.abort()
  }, [])
  if (!available) return null
  return <a data-testid='osa-cinema-premiere-link' className='cinema-practice-link'
    href={PREMIERE_PATH} aria-label={locale === 'ru' ? 'Смотреть фильм За пределами модели' : 'Watch Beyond the Model film'}>
    {locale === 'ru' ? 'Смотреть фильм · 03:59' : 'Watch the film · 03:59'}
    <span aria-hidden='true'> ↗</span>
  </a>
}
