import { lazy, Suspense, useCallback, useEffect, useRef, useState } from 'react'
import type { CSSProperties } from 'react'
import { ArrowDown, ArrowRight, ArrowUpRight, Bookmark, Box, Film, Gamepad2, InfinityIcon, Layers3, Orbit, ShieldCheck } from './PlayIcons'
import { playGames } from './redesignCatalog'
import { PLAY_COLLECTION_KEY, emptyPlayCollection, parsePlayCollection, toggleFavorite } from './playCollection'
import type { PlayCollection } from './playCollection'
import { playCatalogHref, readPlayFilters } from './playFilters'
import { replaceBrowserUrl } from './browserNavigation'
import { PLAY_ART_ROOT } from './playCinematicData'
import { usePlayMotion } from './PlayMotion'
import { magnet, resetMagnet } from './playButtonMotion'
import './playCinematic.css'

const PlayExploreSections = lazy(() => import('./PlayExploreSections'))
const PlayFeaturedSection = lazy(() => import('./PlayFeaturedSection'))
const PlayPartnerIntro = lazy(() => import('./PlayPartnerIntro'))

function exploreAnchor(hash: string) {
  return /^#(catalog|experience|discover|guest-access)$/.exec(hash)?.[1] || ''
}

const ids = playGames.map(game => game.id)
const genres = [...new Set(playGames.map(game => game.genre))]

function loadCollection(): PlayCollection {
  const current = localStorage.getItem(PLAY_COLLECTION_KEY)
  if (current) {
    try { return parsePlayCollection(current, ids) } catch { /* Recover optional storage without blocking the catalogue. */ }
  }
  const readLegacy = (key: string): string[] => {
    try {
      const value = JSON.parse(localStorage.getItem(key) || '[]')
      return Array.isArray(value) ? value.filter((v): v is string => typeof v === 'string' && ids.includes(v)) : []
    } catch { return [] }
  }
  return parsePlayCollection(JSON.stringify({
    favorites: readLegacy('osgard.games.favorites.v1'),
    recent: readLegacy('osgard.games.recent.v1'),
  }), ids)
}


export default function PlayHome({ partners = false }: { partners?: boolean }) {
  const page = useRef<HTMLElement>(null)
  const exploration = useRef<HTMLDivElement>(null)
  const initial = readPlayFilters(location.search, genres)
  const [filters, setFilters] = useState(initial)
  const { query, genre, mode, view } = filters
  const initialTarget = exploreAnchor(location.hash || '') ||
    (initial.query || initial.genre !== 'all' || initial.mode !== 'all' || initial.view !== 'all' ? 'catalog' : '')
  const pendingAnchor = useRef(initialTarget)
  const anchorFrame = useRef(0)
  const mountedExploration = useRef(false)
  // Async server rendering includes the full catalogue. In the browser the
  // import begins only for an explicit destination or the proximity observer.
  const [exploreRequested, setExploreRequested] = useState(() => typeof window === 'undefined' || Boolean(initialTarget))
  const [exploreReady, setExploreReady] = useState(false)
  const [collection, setCollection] = useState<PlayCollection>(emptyPlayCollection)
  const [message, setMessage] = useState('')
  const [artState, setArtState] = useState<'loading' | 'loaded' | 'failed'>('loading')
  usePlayMotion(page)

  useEffect(() => {
    if (!partners) replaceBrowserUrl(playCatalogHref(filters).replace(/#catalog$/, location.hash || ''))
  }, [query, genre, mode, view, partners])
  useEffect(() => {
    if (partners) return
    let observer: IntersectionObserver | undefined
    const request = (anchor = '') => {
      if (anchor) pendingAnchor.current = anchor
      observer?.disconnect()
      setExploreRequested(true)
    }
    const hashChanged = () => {
      const anchor = exploreAnchor(location.hash)
      if (anchor && !mountedExploration.current) request(anchor)
      else pendingAnchor.current = ''
    }
    const clicked = (event: MouseEvent) => {
      if (mountedExploration.current || event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
      const link = event.target instanceof Element ? event.target.closest<HTMLAnchorElement>('a[href]') : null
      if (!link || link.target && link.target !== '_self' || link.hasAttribute('download')) return
      const url = new URL(link.href, location.href)
      if (url.origin === location.origin && url.pathname === location.pathname && url.search === location.search) {
        const anchor = exploreAnchor(url.hash)
        if (anchor) request(anchor)
      }
    }
    window.addEventListener('hashchange', hashChanged)
    document.addEventListener('click', clicked)
    if (!exploreRequested) {
      if (typeof window.IntersectionObserver === 'function') {
        observer = new IntersectionObserver(entries => {
          if (entries.some(entry => entry.isIntersecting)) request()
        }, { rootMargin: '200px', threshold: 0 })
        if (exploration.current) observer.observe(exploration.current)
      } else request()
    }
    return () => {
      observer?.disconnect()
      cancelAnimationFrame(anchorFrame.current)
      window.removeEventListener('hashchange', hashChanged)
      document.removeEventListener('click', clicked)
    }
  }, [partners])
  const onExploreReady = useCallback(() => {
    mountedExploration.current = true
    setExploreReady(true)
    anchorFrame.current = requestAnimationFrame(() => {
      const id = pendingAnchor.current
      pendingAnchor.current = ''
      const target = id && document.getElementById(id)
      if (target) {
        target.scrollIntoView({ behavior: 'instant', block: 'start' })
        target.tabIndex = -1
        target.focus({ preventScroll: true })
      }
    })
  }, [])
  useEffect(() => {
    const read = () => {
      try { setCollection(loadCollection()) }
      catch { setMessage('Коллекция недоступна. Каталог и запуск работают без сохранения.') }
    }
    read()
    const changed = (event: StorageEvent) => { if (event.key === PLAY_COLLECTION_KEY || event.key === null) read() }
    window.addEventListener('storage', changed)
    return () => window.removeEventListener('storage', changed)
  }, [])
  const mutate = (change: (previous: PlayCollection) => PlayCollection) => {
    try {
      const next = change(loadCollection())
      localStorage.setItem(PLAY_COLLECTION_KEY, JSON.stringify(next))
      setCollection(next)
      setMessage('Коллекция сохранена на этом устройстве.')
      return true
    } catch {
      setMessage('Не удалось сохранить коллекцию на устройстве. Игры по-прежнему можно открывать.')
      return false
    }
  }

  if (partners) return <Suspense fallback={<main className="brand-container play-partners"><h1>OSGARD PLAY</h1><p>Загружаем информацию для партнёров…</p></main>}>
    <PlayPartnerIntro />
  </Suspense>


  return <main className="play-universe" ref={page} data-art-state={artState} data-hero-visible="true">
    <section className="cp-hero" aria-labelledby="play-title">
      <picture className="cp-hero-art" aria-hidden="true">
        <source media="(max-width: 600px)" srcSet={PLAY_ART_ROOT + 'hero-mobile-780.webp 780w, ' + PLAY_ART_ROOT + 'hero-mobile.webp 1024w'} sizes="100vw" />
        <img src={PLAY_ART_ROOT + 'hero-megacity.webp'}
          srcSet={PLAY_ART_ROOT + 'hero-megacity-1280.webp 1280w, ' + PLAY_ART_ROOT + 'hero-megacity-1920.webp 1920w, ' + PLAY_ART_ROOT + 'hero-megacity.webp 1983w'}
          sizes="100vw" alt="" width="1983" height="793" fetchPriority="high" decoding="async"
          onLoad={() => setArtState('loaded')} onError={() => setArtState('failed')} />
      </picture>
      <div className="cp-hero-shade" aria-hidden="true" />
      <div className="cp-atmosphere" aria-hidden="true">
        {Array.from({ length: 10 }, (_, index) => <i key={index} style={{
          '--i': index, left: ((index * 37 + 19) % 94) + '%', top: ((index * 23 + 13) % 83) + '%',
        } as CSSProperties} />)}
        <span className="cp-vessel cp-vessel-one" /><span className="cp-vessel cp-vessel-two" />
      </div>
      {artState === 'loading' && <div className="cp-art-loading" aria-hidden="true"><Orbit /><span>OSGARD PLAY</span></div>}
      <div className="cp-hero-layout cp-container">
        <div className="cp-hero-copy">
          <p className="cp-eyebrow cp-hero-eyebrow">ИНТЕРАКТИВНЫЕ МИРЫ<br />В ЦИФРОВОЙ ВСЕЛЕННОЙ</p>
          <h1 id="play-title">OSGARD<span>Play</span></h1>
          <p className="cp-hero-slogan">ИГРЫ. МИРЫ. <span>ТЫ ВНУТРИ.</span></p>
          <p className="cp-hero-description">Интерактивные миры нового поколения. Исследуй, создавай, играй и открывай новые возможности в цифровой вселенной OSGARD.</p>
          <div className="cp-hero-actions">
            <a className="cp-button cp-button-primary" href="#featured" onPointerMove={magnet} onPointerLeave={resetMagnet}>
              Исследовать миры <ArrowUpRight size={19} aria-hidden="true" />
            </a>
            <button className="cp-button cp-trailer" type="button" disabled aria-describedby="trailer-status">
              <Film size={18} aria-hidden="true" /> Смотреть трейлер
            </button>
          </div>
          <span id="trailer-status" className="cp-trailer-note">Трейлер пока не опубликован. Игры доступны в каталоге.</span>
        </div>
        <aside className="cp-glass-panel" aria-label="Возможности OSGARD Play">
          <p>БОЛЬШЕ, ЧЕМ КАРТИНКА.<br />МИРЫ, В КОТОРЫЕ МОЖНО ВОЙТИ.</p>
          <a href="#catalog"><Layers3 aria-hidden="true" /><span><strong>{playGames.length} миров</strong><small>ИГРЫ И ИСТОРИИ В КАТАЛОГЕ</small></span><ArrowRight className="cp-panel-arrow" aria-hidden="true" /></a>
          <a href="#experience"><Gamepad2 aria-hidden="true" /><span><strong>Твой выбор</strong><small>ФИЗИКА · СТРАТЕГИЯ · ТАКТИКА</small></span><ArrowRight className="cp-panel-arrow" aria-hidden="true" /></a>
          <a href="#guest-access"><ShieldCheck aria-hidden="true" /><span><strong>Гостевой вход</strong><small>ЗНАКОМСТВО БЕЗ РЕГИСТРАЦИИ</small></span><ArrowRight className="cp-panel-arrow" aria-hidden="true" /></a>
        </aside>
      </div>
      <div className="cp-hero-foot cp-container"><span>OSGARD MEGACITY / ХУДОЖЕСТВЕННАЯ ВСЕЛЕННАЯ</span><a href="#featured">ЛИСТАЙ. ОТКРЫВАЙ. <ArrowDown size={15} aria-hidden="true" /></a></div>
      {artState === 'failed' && <p className="cp-image-error" role="status">Фон не загрузился. Каталог и игры доступны ниже.</p>}
    </section>

    <div className="cp-signal-strip" aria-label="Коротко о платформе">
      <div className="cp-container">
        <a href="#catalog"><InfinityIcon aria-hidden="true" /><span>РАЗНЫЕ МИРЫ<br /><b>ОДНА ВСЕЛЕННАЯ</b></span></a>
        <a href="#guest-access"><ShieldCheck aria-hidden="true" /><span>ГОСТЕВОЙ ДОСТУП<br /><b>БЕЗ РЕГИСТРАЦИИ</b></span></a>
        <a href="#experience"><Box aria-hidden="true" /><span>ИГРОВЫЕ МЕХАНИКИ<br /><b>ВЫБЕРИ СВОЮ</b></span></a>
        <a href="/play?view=favorites#catalog"><Bookmark aria-hidden="true" /><span>ТВОЯ КОЛЛЕКЦИЯ<br /><b>НА ЭТОМ УСТРОЙСТВЕ</b></span></a>
        <a href="#discover"><Orbit aria-hidden="true" /><span>НОВЫЕ ВПЕЧАТЛЕНИЯ<br /><b>В КАЖДОМ МИРЕ</b></span></a>
      </div>
    </div>

    <Suspense fallback={<section id="featured" className="cp-section cp-container cp-featured" aria-label="Избранные миры">
      <p className="cp-explore-loading" role="status">Загружаем избранные миры…</p>
    </section>}>
      <PlayFeaturedSection filters={filters} collection={collection}
        onFavorite={id => mutate(previous => toggleFavorite(previous, id))} />
    </Suspense>

    <div className="cp-explore" ref={exploration} data-explore-state={exploreReady ? 'ready' : exploreRequested ? 'requested' : 'deferred'}>
      {exploreRequested ? <Suspense fallback={<div className="cp-explore-placeholder"><p className="cp-explore-loading" role="status" aria-live="polite"><Orbit aria-hidden="true" /> Загружаем миры и каталог…</p></div>}>
        <PlayExploreSections filters={filters} onFiltersChange={setFilters} collection={collection} message={message}
          onFavorite={id => mutate(previous => toggleFavorite(previous, id))} onReady={onExploreReady} />
      </Suspense> : <div className="cp-explore-placeholder"><a className="cp-button cp-explore-entry" href="#catalog">Открыть каталог миров <ArrowUpRight size={18} aria-hidden="true" /></a></div>}
    </div>
  </main>
}
