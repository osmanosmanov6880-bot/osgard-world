import { useCallback, useEffect, useRef, useState, type CSSProperties } from 'react'
import { ArrowLeft, ArrowUpRight, Expand, Gamepad2, Heart, Info, LoaderCircle, Minimize2, Monitor, Play, RotateCcw, Save, X } from 'lucide-react'
import type { PlayGame } from './redesignCatalog'
import { gameArtwork } from './playCinematicData'
import './playGameDetail.css'

type PlayGameDetailProps = {
  game: PlayGame
  returnTo: string
  isFavorite: boolean
  onToggleFavorite: () => void
  message: string
  onLaunch: () => void
}

type SessionPhase = 'idle' | 'loading' | 'loaded' | 'ready' | 'playing' | 'completed' | 'timeout' | 'error'

const phaseLabels: Record<SessionPhase, string> = {
  idle: 'Выберите способ запуска',
  loading: 'Загружаем страницу игры…',
  loaded: 'Страница открыта. Следуйте инструкции внутри игры.',
  ready: 'Игра готова. Начните сессию в игровом окне.',
  playing: 'Игра подтвердила запуск сессии',
  completed: 'Сессия завершена. Результат — в игровом окне.',
  timeout: 'Загрузка занимает больше обычного',
  error: 'Не удалось открыть игру в этом окне',
}

// The catalogue only launches its own public games. No credentials or private
// API calls are involved, and the original game keeps its storage and controls.
function sameOriginGameUrl(href: string) {
  const url = new URL(href, window.location.href)
  if (url.origin !== window.location.origin || !url.pathname.startsWith('/games/')) {
    throw new Error('Unsupported game location')
  }
  // Resolve static directory exports explicitly. Production Nginx resolves
  // index.html automatically; Vite's public middleware otherwise serves the
  // SPA fallback. React routes such as /games/time remain unchanged.
  if (url.pathname.endsWith('/')) url.pathname += 'index.html'
  return url.href
}

function isCatalogUrl(url: URL) {
  return url.origin === window.location.origin && /^\/(play|games|entertainment)\/?$/.test(url.pathname)
}

export default function PlayGameDetail({ game, returnTo, isFavorite, onToggleFavorite, message, onLaunch }: PlayGameDetailProps) {
  const artwork = gameArtwork(game)
  const [frameSrc, setFrameSrc] = useState<string | null>(null)
  const [run, setRun] = useState(0)
  const [phase, setPhase] = useState<SessionPhase>('idle')
  const [issue, setIssue] = useState('')
  const [fullscreen, setFullscreen] = useState(false)
  const [fullscreenMessage, setFullscreenMessage] = useState('')
  const phaseRef = useRef<SessionPhase>('idle')
  const frameRef = useRef<HTMLIFrameElement>(null)
  const playerRef = useRef<HTMLElement>(null)
  const playerHeadingRef = useRef<HTMLHeadingElement>(null)
  const launchRef = useRef<HTMLButtonElement>(null)
  const returnFocusRef = useRef<HTMLElement | null>(null)
  const childKeyboardCleanup = useRef<(() => void) | null>(null)

  const updatePhase = useCallback((next: SessionPhase) => {
    phaseRef.current = next
    setPhase(next)
  }, [])

  const releaseFullscreen = useCallback(() => {
    const player = playerRef.current
    if (document.fullscreenElement && player?.contains(document.fullscreenElement)) {
      void document.exitFullscreen().catch(() => {})
    }
    try { frameRef.current?.contentDocument?.exitPointerLock() } catch { /* An unavailable frame has no active controls. */ }
    try { document.exitPointerLock() } catch { /* Pointer lock is optional. */ }
  }, [])

  const stopSession = useCallback(() => {
    releaseFullscreen()
    childKeyboardCleanup.current?.()
    childKeyboardCleanup.current = null
    // Unmounting destroys the browsing context: game loops, sound and keyboard
    // listeners cannot continue invisibly after the visitor stops the session.
    setFrameSrc(null)
    updatePhase('idle')
    setIssue('')
    setFullscreenMessage('')
    requestAnimationFrame(() => {
      const target = returnFocusRef.current?.isConnected ? returnFocusRef.current : launchRef.current
      target?.focus()
    })
  }, [releaseFullscreen, updatePhase])

  const failSession = useCallback((text: string) => {
    releaseFullscreen()
    childKeyboardCleanup.current?.()
    childKeyboardCleanup.current = null
    setFrameSrc(null)
    setIssue(text)
    updatePhase('error')
    requestAnimationFrame(() => playerHeadingRef.current?.focus({ preventScroll: true }))
  }, [releaseFullscreen, updatePhase])

  const returnToCatalog = useCallback(() => {
    // returnTo is supplied by playReturnHref, but keep the frame bridge safe
    // independently of its caller. Restore the visitor's catalogue filters.
    const destination = new URL(returnTo, window.location.href)
    stopSession()
    window.location.assign(isCatalogUrl(destination) ? destination.href : '/play#catalog')
  }, [returnTo, stopSession])

  function startSession() {
    if (!game.launchable) return
    returnFocusRef.current = document.activeElement instanceof HTMLElement ? document.activeElement : launchRef.current
    childKeyboardCleanup.current?.()
    childKeyboardCleanup.current = null
    setIssue('')
    setFullscreenMessage('')
    try {
      const src = sameOriginGameUrl(game.href)
      updatePhase('loading')
      setRun(value => value + 1)
      setFrameSrc(src)
      onLaunch()
      requestAnimationFrame(() => {
        const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches || document.documentElement.dataset.motion === 'off'
        playerRef.current?.scrollIntoView({ behavior: reduced ? 'instant' : 'smooth', block: 'start' })
        playerHeadingRef.current?.focus({ preventScroll: true })
      })
    } catch {
      failSession('Этот адрес нельзя встроить в игровой каталог. Используйте ссылку «Открыть отдельно».')
    }
  }

  async function toggleFullscreen() {
    const player = playerRef.current
    if (!player) return
    setFullscreenMessage('')
    try {
      if (document.fullscreenElement && player.contains(document.fullscreenElement)) {
        await document.exitFullscreen()
      } else if (player.requestFullscreen) {
        await player.requestFullscreen()
      } else {
        setFullscreenMessage('Полный экран недоступен в этом браузере. Можно открыть игру отдельно.')
      }
    } catch {
      setFullscreenMessage('Браузер не включил полный экран. Игра остаётся доступна в этом окне.')
    }
  }

  function handleFrameLoad() {
    const frame = frameRef.current
    if (!frame) return
    try {
      const doc = frame.contentDocument
      if (!doc || frame.contentWindow?.location.origin !== window.location.origin) {
        failSession('Браузер не разрешил встроенное окно. Откройте игру отдельно или выберите облегчённую версию.')
        return
      }
      if (frame.contentWindow?.location.href === 'about:blank') return
      if (isCatalogUrl(new URL(frame.contentWindow!.location.href))) {
        returnToCatalog()
        return
      }
      // A missing static export may return the site's SPA fallback with HTTP
      // 200. In particular, Godot is deployed separately and is absent in Git.
      const appFallback = game.id !== 'time' && doc.querySelector('meta[name="osgard-app"][content="osgard-ecosystem"]')
      const errorPage = doc.querySelector('.brand-not-found') || /^(404|403|502|503)\b/.test(doc.title.trim())
      if (appFallback || errorPage) {
        failSession('Сборка игры недоступна в этом окружении. Попробуйте открыть её отдельно' + (game.alternate ? ' или используйте облегчённую версию.' : '.'))
        return
      }
      childKeyboardCleanup.current?.()
      const followCatalogExit = (event: MouseEvent) => {
        if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
        // An iframe has its own Element constructor. Use its DOM methods,
        // rather than an instanceof check against the parent window.
        const target = event.target as Element | null
        const link = target?.closest?.('a[href]')
        if (!link || link.hasAttribute('download') || link.getAttribute('target') === '_blank') return
        const url = new URL(link.getAttribute('href')!, doc.baseURI)
        if (!isCatalogUrl(url)) return
        event.preventDefault()
        returnToCatalog()
      }
      // Escape inside a game retains its own pause/menu controls. When the
      // host owns fullscreen, Escape can release it without resetting a run.
      const exitChildFullscreen = (event: KeyboardEvent) => {
        if (event.key === 'Escape' && document.fullscreenElement && playerRef.current?.contains(document.fullscreenElement)) {
          void document.exitFullscreen().catch(() => {})
        }
      }
      doc.addEventListener('keydown', exitChildFullscreen, true)
      doc.addEventListener('click', followCatalogExit)
      childKeyboardCleanup.current = () => {
        doc.removeEventListener('keydown', exitChildFullscreen, true)
        doc.removeEventListener('click', followCatalogExit)
      }
      if (['loading', 'timeout'].includes(phaseRef.current)) updatePhase('loaded')
    } catch {
      failSession('Не удалось проверить загрузку встроенного окна. Используйте прямой запуск игры.')
    }
  }

  useEffect(() => {
    const onMessage = (event: MessageEvent) => {
      if (event.origin !== window.location.origin || event.source !== frameRef.current?.contentWindow) return
      const data: unknown = event.data
      if (!data || typeof data !== 'object') return
      const signal = data as Record<string, unknown>
      if (signal.type !== 'osgard:game-lifecycle' || signal.game !== game.id) return
      if (signal.state === 'ready') updatePhase('ready')
      if (signal.state === 'started') updatePhase('playing')
      if (signal.state === 'completed') updatePhase('completed')
      if (signal.state === 'error') failSession('Игра сообщила об ошибке. Повторите запуск или откройте её отдельно.')
    }
    const onFullscreenChange = () => setFullscreen(Boolean(document.fullscreenElement && playerRef.current?.contains(document.fullscreenElement)))
    window.addEventListener('message', onMessage)
    document.addEventListener('fullscreenchange', onFullscreenChange)
    return () => {
      window.removeEventListener('message', onMessage)
      document.removeEventListener('fullscreenchange', onFullscreenChange)
      childKeyboardCleanup.current?.()
    }
  }, [game.id, failSession, updatePhase])

  useEffect(() => {
    if (!frameSrc) return
    const timer = window.setTimeout(() => {
      if (phaseRef.current === 'loading') updatePhase('timeout')
    }, 20000)
    const onEscape = (event: KeyboardEvent) => {
      if (event.key !== 'Escape' || event.defaultPrevented) return
      event.preventDefault()
      if (document.fullscreenElement && playerRef.current?.contains(document.fullscreenElement)) {
        void document.exitFullscreen().catch(() => {})
      } else {
        stopSession()
      }
    }
    document.addEventListener('keydown', onEscape)
    return () => {
      window.clearTimeout(timer)
      document.removeEventListener('keydown', onEscape)
    }
  }, [frameSrc, run, stopSession, updatePhase])

  const active = frameSrc !== null
  const isStory = game.format === 'Интерактивная история'

  return <main className="play-detail play-game-detail" style={{ '--detail-accent': game.accent } as CSSProperties}>
    <section className="play-game-hero" aria-labelledby="play-game-title">
      <figure className="play-game-backdrop">
        <img className="play-detail-art" src={artwork.src} srcSet={artwork.srcSet} sizes="100vw" alt={'Художественная обложка мира «' + game.title + '»'} fetchPriority="high" width="1536" height="1024" />
        <figcaption>{artwork.label || 'Художественная обложка'}</figcaption>
      </figure>
      <div className="play-detail-inner play-game-hero-layout">
        <a className="play-detail-back" href={returnTo}><ArrowLeft size={16} aria-hidden="true" /> Каталог миров</a>
        <div className="play-game-hero-copy">
          <p className="play-detail-eyebrow">OSGARD PLAY <span>/</span> {game.genre}</p>
          <div className="play-detail-tags"><span>{game.format}</span><span>{game.status}</span></div>
          <h1 id="play-game-title">{game.title}</h1>
          <p className="play-detail-description">{game.description}</p>
          <div className="play-detail-actions">
            <button ref={launchRef} className="play-detail-button play-detail-button-primary" data-game-launch={game.id} onClick={startSession} disabled={!game.launchable || active} aria-controls="play-session">
              <Play size={17} fill="currentColor" aria-hidden="true" /> {active ? 'Игра открыта ниже' : game.launchable ? game.launchLabel : 'Сборка недоступна'}
            </button>
            {game.launchable && <a className="play-detail-button" href={game.href} target="_blank" rel="noopener noreferrer" data-game-launch={game.id} onClick={onLaunch}>Открыть отдельно <ArrowUpRight size={18} aria-hidden="true" /></a>}
            <button className="play-detail-button play-detail-favorite" aria-label={(isFavorite ? 'Убрать из избранного: ' : 'Добавить в избранное: ') + game.title} aria-pressed={isFavorite} onClick={onToggleFavorite}><Heart size={19} fill={isFavorite ? 'currentColor' : 'none'} aria-hidden="true" /></button>
          </div>
          <p className="play-detail-guest">Каталог и публичный запуск — без регистрации</p>
        </div>
        <aside className="play-detail-glass" aria-label="Информация о мире">
          <span className="play-detail-panel-mark" aria-hidden="true"><Gamepad2 size={22} /></span>
          <p className="play-detail-eyebrow">ПЕРЕД ВХОДОМ</p>
          <dl>
            <div><dt>Платформа</dt><dd>{game.platform}</dd></div>
            <div><dt>Режим</dt><dd>{game.online}</dd></div>
            <div><dt>Прогресс</dt><dd>{game.save}</dd></div>
          </dl>
          {game.alternate && <a className="play-detail-alt-link" href={game.alternate.href} target="_blank" rel="noopener noreferrer" onClick={onLaunch}>{game.alternate.label} <ArrowUpRight size={16} aria-hidden="true" /></a>}
        </aside>
      </div>
    </section>

    <div className="play-detail-inner">
      <section className="play-detail-briefing" aria-labelledby="play-briefing-title">
        <div className="play-detail-briefing-heading">
          <p className="play-detail-eyebrow">01 / ПРАВИЛА МИРА</p>
          <h2 id="play-briefing-title">Ваш первый шаг.</h2>
        </div>
        <div className="play-detail-controls"><Gamepad2 size={24} aria-hidden="true" /><h3>Управление</h3><p>{game.controls}</p></div>
        <div className="play-detail-controls"><Save size={23} aria-hidden="true" /><h3>Сохранение</h3><p>{game.save}. Избранное сохраняет ссылку на мир и не заменяет игровой прогресс.</p></div>
      </section>
      <div className="play-detail-note"><Info size={18} aria-hidden="true" /><p>{game.warning}</p></div>

      <section id="play-session" ref={playerRef} className="play-session" aria-labelledby="play-session-title" data-session-phase={phase}>
        <div className="play-session-toolbar">
          <div className="play-session-heading"><span className="play-session-indicator" aria-hidden="true" /><div><p>{isStory ? 'ИНТЕРАКТИВНАЯ ИСТОРИЯ' : 'ИГРОВОЕ ОКНО'}</p><h2 id="play-session-title" ref={playerHeadingRef} tabIndex={-1}>{game.title}</h2></div></div>
          <div className="play-session-tools">
            {game.launchable && <a className="play-session-tool" href={game.href} target="_blank" rel="noopener noreferrer" onClick={onLaunch} aria-label={'Открыть «' + game.title + '» отдельно'}><ArrowUpRight size={17} aria-hidden="true" /><span>Отдельно</span></a>}
            {active && <button className="play-session-tool" onClick={() => void toggleFullscreen()} aria-label={fullscreen ? 'Выйти из полного экрана' : 'Открыть игру на полный экран'}>{fullscreen ? <Minimize2 size={17} aria-hidden="true" /> : <Expand size={17} aria-hidden="true" />}<span>{fullscreen ? 'Свернуть' : 'Полный экран'}</span></button>}
            {active && <button className="play-session-tool play-session-stop" onClick={stopSession}><X size={17} aria-hidden="true" /><span>Остановить</span></button>}
          </div>
        </div>
        <div className="play-session-state" role="status" aria-live="polite">
          {phase === 'loading' && <LoaderCircle className="play-session-spinner" size={15} aria-hidden="true" />}
          <span>{phaseLabels[phase]}</span>
        </div>
        {fullscreenMessage && <p className="play-session-notice" role="status">{fullscreenMessage}</p>}
        {phase === 'timeout' && <div className="play-session-notice"><p>Можно подождать, повторить загрузку или открыть игру отдельно. Запуск сессии пока не подтверждён.</p><button className="play-session-tool" onClick={startSession}><RotateCcw size={16} aria-hidden="true" /> Повторить загрузку</button></div>}
        <div className="play-session-stage">
          {active ? <iframe key={run} ref={frameRef} src={frameSrc} title={game.title + ' — игровое окно'} className="play-session-frame" onLoad={handleFrameLoad} onError={() => failSession('Не удалось загрузить страницу игры. Проверьте соединение и повторите попытку.')} allow="fullscreen; gamepad; autoplay; clipboard-write" allowFullScreen sandbox="allow-scripts allow-same-origin allow-pointer-lock allow-downloads allow-forms allow-popups" referrerPolicy="strict-origin-when-cross-origin" /> : <div className="play-session-poster">
            <img src={artwork.src} srcSet={artwork.srcSet} sizes="(max-width: 760px) 100vw, 85vw" alt="" loading="lazy" width="1536" height="1024" />
            <div className="play-session-poster-copy">
              <span className="play-session-poster-icon" aria-hidden="true">{phase === 'error' ? <Info size={28} /> : <Monitor size={30} />}</span>
              <p className="play-detail-eyebrow">{phase === 'error' ? 'ЗАПУСК НЕ ЗАВЕРШЁН' : 'ВАШ МИР. ВАШ ХОД.'}</p>
              <h3>{phase === 'error' ? 'Попробуем ещё раз?' : isStory ? 'Откройте свою историю.' : 'Войти в игровой мир.'}</h3>
              {phase === 'error' ? <p role="alert">{issue}</p> : <p>Игра загрузится после нажатия. Управление и сохранения работают по правилам этого мира.</p>}
              <div className="play-detail-actions">
                <button className="play-detail-button play-detail-button-primary" disabled={!game.launchable} data-game-launch={game.id} onClick={startSession}>{phase === 'error' ? <RotateCcw size={17} aria-hidden="true" /> : <Play size={17} fill="currentColor" aria-hidden="true" />}{phase === 'error' ? 'Повторить запуск' : game.launchable ? game.launchLabel : 'Сборка недоступна'}</button>
                {game.alternate && <a className="play-detail-button" href={game.alternate.href} target="_blank" rel="noopener noreferrer" onClick={onLaunch}>{game.alternate.label}<ArrowUpRight size={17} aria-hidden="true" /></a>}
              </div>
            </div>
          </div>}
        </div>
        <div className="play-session-footnote"><span>{game.platform}</span><span>Нажмите внутри окна, чтобы управлять игрой.</span></div>
      </section>

      <section className="play-detail-collection" aria-label="Ваша коллекция миров">
        <div><p className="play-detail-eyebrow">ПРОДОЛЖЕНИЕ ВАШЕЙ ИСТОРИИ</p><h2>Этот мир может стать вашим.</h2><p>Избранное и история открытия сохраняются на этом устройстве. Добавьте мир в коллекцию, чтобы быстро вернуться к нему из каталога.</p></div>
        <div className="play-detail-collection-actions"><button className="play-detail-button" aria-pressed={isFavorite} onClick={onToggleFavorite}><Heart size={18} fill={isFavorite ? 'currentColor' : 'none'} aria-hidden="true" />{isFavorite ? 'В избранном' : 'Сохранить мир'}</button><a className="play-detail-back" href={returnTo}>Другие миры <ArrowUpRight size={17} aria-hidden="true" /></a></div>
        <p className="play-detail-collection-message" role="status" aria-live="polite">{message}</p>
      </section>
    </div>
  </main>
}
