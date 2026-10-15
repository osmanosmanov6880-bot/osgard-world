import { useRef, useState } from 'react'
import { ArrowDownToLine, Captions, RotateCcw, RotateCw } from 'lucide-react'
import { isPlayableLessonMedia, isPermanentHttpsUrl, type OSALessonMediaResource } from './osaLessonMedia'
import './osaLessonMediaPlayer.css'

const PLAYBACK_RATES = [0.75, 1, 1.25, 1.5, 1.75, 2]

type Props = {
  lessonSlug: string
  resource: OSALessonMediaResource
  title: string
  languageLabel: string
  speedLabel: string
  captionsLabel: string
  transcriptLabel: string
  playbackErrorLabel: string
  audioTypeLabel: string
  videoTypeLabel: string
  seekBackLabel: string
  seekForwardLabel: string
}

export default function OSALessonMediaPlayer({
  lessonSlug,
  resource,
  title,
  languageLabel,
  speedLabel,
  captionsLabel,
  transcriptLabel,
  playbackErrorLabel,
  audioTypeLabel,
  videoTypeLabel,
  seekBackLabel,
  seekForwardLabel,
}: Props) {
  const mediaRef = useRef<HTMLMediaElement | null>(null)
  const lastSavedSecond = useRef(-1)
  const [playbackRate, setPlaybackRate] = useState(1)
  const [playbackError, setPlaybackError] = useState(false)
  const canPlay = isPlayableLessonMedia(resource)
  const captionsAvailable = Boolean(resource.language && resource.captionsUrl && isPermanentHttpsUrl(resource.captionsUrl))
  const transcriptAvailable = Boolean(resource.transcriptUrl && isPermanentHttpsUrl(resource.transcriptUrl))
  const storageKey = 'osgard-osa-media-position-v1:' + lessonSlug + ':' + resource.kind

  if (!canPlay) return null

  const restorePosition = (element: HTMLMediaElement) => {
    try {
      const saved = Number(localStorage.getItem(storageKey))
      if (Number.isFinite(saved) && saved > 0 && Number.isFinite(element.duration) && saved < element.duration - 1) {
        element.currentTime = saved
      }
      element.playbackRate = playbackRate
      setPlaybackError(false)
    } catch {
      // Playback must remain available if local storage is disabled or corrupted.
    }
  }

  const savePosition = (element: HTMLMediaElement) => {
    try {
      if (!Number.isFinite(element.currentTime) || element.currentTime < 0) return
      const second = Math.floor(element.currentTime)
      if (second - lastSavedSecond.current < 3 && element.currentTime < (element.duration || Infinity) - 1) return
      localStorage.setItem(storageKey, String(element.currentTime))
      lastSavedSecond.current = second
    } catch {
      // The media remains usable even when progress persistence is unavailable.
    }
  }

  const seekBy = (deltaSeconds: number) => {
    const element = mediaRef.current
    if (!element || !Number.isFinite(element.duration)) return
    element.currentTime = Math.min(element.duration, Math.max(0, element.currentTime + deltaSeconds))
  }

  const changeRate = (value: string) => {
    const next = Number(value)
    if (!PLAYBACK_RATES.includes(next)) return
    setPlaybackRate(next)
    if (mediaRef.current) mediaRef.current.playbackRate = next
  }

  return <section className="osa-media-player" aria-label={title}>
    <div className="osa-media-player-heading">
      <div>
        <p>{resource.kind === 'audio' ? audioTypeLabel : videoTypeLabel}</p>
        <h3>{title}</h3>
      </div>
      <span>{resource.durationSeconds ? Math.round(resource.durationSeconds / 60) + ' min' : ''}</span>
    </div>
    {resource.kind === 'audio'
      ? <audio
          ref={element => { mediaRef.current = element }}
          src={resource.permanentUrl!}
          controls
          preload="metadata"
          onLoadedMetadata={event => restorePosition(event.currentTarget)}
          onTimeUpdate={event => savePosition(event.currentTarget)}
          onEnded={() => { try { localStorage.removeItem(storageKey) } catch {} }}
          onError={() => setPlaybackError(true)}
          aria-label={title}
        />
      : <video
          ref={element => { mediaRef.current = element }}
          src={resource.permanentUrl!}
          controls
          playsInline
          preload="metadata"
          onLoadedMetadata={event => restorePosition(event.currentTarget)}
          onTimeUpdate={event => savePosition(event.currentTarget)}
          onEnded={() => { try { localStorage.removeItem(storageKey) } catch {} }}
          onError={() => setPlaybackError(true)}
          aria-label={title}
        >
          {captionsAvailable && <track kind="captions" src={resource.captionsUrl!} srcLang={resource.language || 'en'} label={captionsLabel} />}
        </video>}
    <div className="osa-media-player-controls">
      <button type="button" onClick={() => seekBy(-15)} aria-label={seekBackLabel}><RotateCcw size={15} /><span>−15 s</span></button>
      <button type="button" onClick={() => seekBy(15)} aria-label={seekForwardLabel}><RotateCw size={15} /><span>+15 s</span></button>
      <label><span>{speedLabel}</span><select value={playbackRate} onChange={event => changeRate(event.target.value)}>{PLAYBACK_RATES.map(rate => <option key={rate} value={rate}>{rate.toLocaleString('en-US')}×</option>)}</select></label>
      {captionsAvailable && <span className="osa-media-player-availability"><Captions size={14} />{captionsLabel}</span>}
      {transcriptAvailable && <a href={resource.transcriptUrl!} target="_blank" rel="noopener noreferrer"><ArrowDownToLine size={14} />{transcriptLabel}</a>}
    </div>
    {playbackError && <p className="osa-media-player-error" role="status" aria-live="polite">{playbackErrorLabel}</p>}
    <p className="osa-media-player-language">{languageLabel}: {resource.language?.toUpperCase()}</p>
  </section>
}
