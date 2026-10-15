import { useEffect, useRef, useState } from 'react'
import { ArrowDownToLine, Pause, Play, RotateCcw, RotateCw, Volume2 } from 'lucide-react'
import type { OSAMediaResource } from './osaMediaCatalog'
import { isPermanentMediaUrl } from './osaMediaUrl'
import './osaMediaPlayer.css'

const POSITION_KEY = 'osgard-osa-media-position-v1'

function formatTime(value: number) {
  if (!Number.isFinite(value) || value < 0) return '0:00'
  const seconds = Math.floor(value)
  const minutes = Math.floor(seconds / 60)
  return minutes + ':' + String(seconds % 60).padStart(2, '0')
}

export default function OSAMediaPlayer({ media }: { media: OSAMediaResource | null }) {
  const audioRef = useRef<HTMLAudioElement>(null)
  const videoRef = useRef<HTMLVideoElement>(null)
  const lastSavedPosition = useRef(0)
  const [playing, setPlaying] = useState(false)
  const [currentTime, setCurrentTime] = useState(0)
  const [duration, setDuration] = useState(0)
  const [volume, setVolume] = useState(0.9)
  const [speed, setSpeed] = useState(1)
  const [playbackError, setPlaybackError] = useState(false)

  const safeSrc = media && media.src && isPermanentMediaUrl(media.src) ? media.src : null
  const safeCaptions = media && media.captionsSrc && isPermanentMediaUrl(media.captionsSrc) ? media.captionsSrc : null
  const storageKey = media ? POSITION_KEY + ':' + media.id + ':' + media.locale : null
  const getElement = () => media && media.kind === 'video' ? videoRef.current : audioRef.current

  const restorePosition = (node: HTMLMediaElement) => {
    setDuration(Number.isFinite(node.duration) ? node.duration : 0)
    if (!storageKey) return
    try {
      const saved = Number(localStorage.getItem(storageKey))
      if (Number.isFinite(saved) && saved > 0 && Number.isFinite(node.duration) && node.duration > 0) {
        node.currentTime = Math.min(saved, Math.max(0, node.duration - 1))
        setCurrentTime(node.currentTime)
      }
    } catch {
      // Private browsing and storage restrictions must not block playback.
    }
  }

  const savePosition = (node: HTMLMediaElement, force = false) => {
    if (!storageKey || !Number.isFinite(node.currentTime)) return
    if (!force && node.currentTime - lastSavedPosition.current < 5) return
    try {
      localStorage.setItem(storageKey, String(Math.floor(node.currentTime)))
      lastSavedPosition.current = node.currentTime
    } catch {
      // Playback remains available when local persistence is unavailable.
    }
  }

  useEffect(() => {
    const node = getElement()
    lastSavedPosition.current = 0
    setPlaying(false)
    setPlaybackError(false)
    setCurrentTime(0)
    setDuration(0)
    if (!node || !safeSrc) return

    const onMetadata = () => restorePosition(node)
    if (node.readyState >= 1) onMetadata()
    else node.addEventListener('loadedmetadata', onMetadata)

    return () => {
      node.removeEventListener('loadedmetadata', onMetadata)
      savePosition(node, true)
    }
  // getElement and persistence helpers intentionally read the current media selection.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [storageKey, safeSrc, media && media.kind])

  useEffect(() => {
    const node = getElement()
    if (node) node.playbackRate = speed
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [speed, media && media.kind])

  useEffect(() => {
    const node = getElement()
    if (node) node.volume = volume
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [volume, media && media.kind])

  if (!media || !media.src) return null

  const isEnglish = media.locale === 'en'
  const copy = isEnglish
    ? {
        kind: media.kind === 'audio' ? 'AUDIO LESSON' : 'VIDEO LESSON',
        play: 'Play',
        pause: 'Pause',
        back: 'Back 15 seconds',
        forward: 'Forward 15 seconds',
        seek: 'Seek in media',
        volume: 'Volume',
        speed: 'Playback speed',
        unavailable: 'This media URL is not a permanent HTTPS or same-origin asset URL. Playback is disabled until a durable source is configured.',
        error: 'The media could not be loaded. Check the file and its hosting permissions.',
        transcript: 'Read transcript',
        transcriptMissing: 'Transcript has not been published.',
      }
    : {
        kind: media.kind === 'audio' ? 'АУДИОЛЕКЦИЯ' : 'ВИДЕОЛЕКЦИЯ',
        play: 'Воспроизвести',
        pause: 'Пауза',
        back: 'Назад на 15 секунд',
        forward: 'Вперёд на 15 секунд',
        seek: 'Перемотка материала',
        volume: 'Громкость',
        speed: 'Скорость воспроизведения',
        unavailable: 'Адрес медиа не является постоянным HTTPS-адресом или путём этого сайта. Воспроизведение отключено до настройки постоянного источника.',
        error: 'Не удалось загрузить медиафайл. Проверьте файл и права доступа к хранилищу.',
        transcript: 'Открыть текст лекции',
        transcriptMissing: 'Транскрипт пока не опубликован.',
      }

  if (!safeSrc) {
    return <section className="osa-media-player osa-media-player--warning" role="status">
      <p className="osa-media-player__eyebrow">{copy.kind}</p>
      <h3>{media.title}</h3>
      <p>{copy.unavailable}</p>
    </section>
  }

  const seek = (seconds: number) => {
    const node = getElement()
    if (!node || !Number.isFinite(node.duration)) return
    node.currentTime = Math.min(node.duration, Math.max(0, node.currentTime + seconds))
    setCurrentTime(node.currentTime)
    savePosition(node, true)
  }

  const togglePlayback = async () => {
    const node = getElement()
    if (!node) return
    setPlaybackError(false)
    if (node.paused) {
      try {
        await node.play()
      } catch {
        setPlaybackError(true)
      }
    } else {
      node.pause()
    }
  }

  const handleTimeUpdate = (node: HTMLMediaElement) => {
    setCurrentTime(Number.isFinite(node.currentTime) ? node.currentTime : 0)
    savePosition(node)
  }

  const handleEnded = (node: HTMLMediaElement) => {
    setPlaying(false)
    setCurrentTime(Number.isFinite(node.duration) ? node.duration : 0)
    if (storageKey) {
      try { localStorage.removeItem(storageKey) } catch { /* Storage is optional. */ }
    }
  }

  return <section className="osa-media-player" aria-label={media.title}>
    <div className="osa-media-player__header">
      <div>
        <p className="osa-media-player__eyebrow">{copy.kind}</p>
        <h3>{media.title}</h3>
      </div>
      <span className="osa-media-player__language">{media.locale.toUpperCase()}</span>
    </div>

    {media.kind === 'audio' ? (
      <audio
        ref={audioRef}
        src={safeSrc}
        preload="metadata"
        onLoadedMetadata={(event) => restorePosition(event.currentTarget)}
        onTimeUpdate={(event) => handleTimeUpdate(event.currentTarget)}
        onPlay={() => { setPlaying(true); setPlaybackError(false) }}
        onPause={(event) => { setPlaying(false); savePosition(event.currentTarget, true) }}
        onEnded={(event) => handleEnded(event.currentTarget)}
        onError={() => { setPlaybackError(true); setPlaying(false) }}
      >
        {safeCaptions && <track kind="captions" src={safeCaptions} srcLang={media.locale} label={isEnglish ? 'English captions' : 'Русские субтитры'} default />}
      </audio>
    ) : (
      <video
        ref={videoRef}
        className="osa-media-player__video"
        src={safeSrc}
        controls
        preload="metadata"
        playsInline
        aria-label={media.title}
        onLoadedMetadata={(event) => restorePosition(event.currentTarget)}
        onTimeUpdate={(event) => handleTimeUpdate(event.currentTarget)}
        onPlay={() => { setPlaying(true); setPlaybackError(false) }}
        onPause={(event) => { setPlaying(false); savePosition(event.currentTarget, true) }}
        onEnded={(event) => handleEnded(event.currentTarget)}
        onError={() => { setPlaybackError(true); setPlaying(false) }}
      >
        {safeCaptions && <track kind="captions" src={safeCaptions} srcLang={media.locale} label={isEnglish ? 'English captions' : 'Русские субтитры'} default />}
      </video>
    )}

    {media.kind === 'audio' && <div className="osa-media-player__controls">
      <button type="button" className="osa-media-player__primary" onClick={togglePlayback} aria-label={playing ? copy.pause : copy.play}>
        {playing ? <Pause size={17} /> : <Play size={17} />}
        <span>{playing ? copy.pause : copy.play}</span>
      </button>
      <button type="button" onClick={() => seek(-15)} aria-label={copy.back} title={copy.back}><RotateCcw size={17} /><span>15</span></button>
      <button type="button" onClick={() => seek(15)} aria-label={copy.forward} title={copy.forward}><RotateCw size={17} /><span>15</span></button>
      <div className="osa-media-player__timeline">
        <input
          type="range"
          min="0"
          max={duration || 0}
          step="1"
          value={Math.min(currentTime, duration || 0)}
          disabled={!duration}
          onChange={(event) => {
            const node = audioRef.current
            if (!node) return
            node.currentTime = Number(event.currentTarget.value)
            setCurrentTime(node.currentTime)
            savePosition(node, true)
          }}
          aria-label={copy.seek}
        />
        <div><span>{formatTime(currentTime)}</span><span>{formatTime(duration)}</span></div>
      </div>
    </div>}

    <div className="osa-media-player__settings">
      <label>
        <span>{copy.speed}</span>
        <select value={speed} onChange={(event) => setSpeed(Number(event.currentTarget.value))} aria-label={copy.speed}>
          {[0.75, 1, 1.25, 1.5, 1.75, 2].map(rate => <option value={rate} key={rate}>{rate}×</option>)}
        </select>
      </label>
      {media.kind === 'audio' && <label className="osa-media-player__volume">
        <Volume2 size={16} />
        <input type="range" min="0" max="1" step="0.05" value={volume} onChange={(event) => setVolume(Number(event.currentTarget.value))} aria-label={copy.volume} />
      </label>}
      {media.transcript
        ? <details className="osa-media-player__transcript"><summary><ArrowDownToLine size={15} />{copy.transcript}</summary><div>{media.transcript}</div></details>
        : <span className="osa-media-player__transcript-status">{copy.transcriptMissing}</span>}
    </div>

    {playbackError && <p className="osa-media-player__error" role="alert">{copy.error}</p>}
  </section>
}
