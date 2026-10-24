import { lazy, Suspense, useEffect, useRef, useState, useSyncExternalStore } from 'react'
import type { ReactNode } from 'react'
import { BrandLockup } from './BrandMark'
import { brandAreaForPath, brandBreadcrumbs, globalNavigationState } from './brandNavigation'
import { getPlayGameTitle } from './playGameTitles'
import { getBrowserSnapshot, getServerSnapshot, subscribeBrowserNavigation } from './browserNavigation'
import { MOTION_CHANGE_EVENT } from './osgardRouting'
import type { ProductTheme } from './BrandMark'
import './brandFonts.css'
import './brandSystem.css'
import './omegaSystems.css'

const OsgardQuickNav = lazy(() => import('./OsgardQuickNav'))
const OsgardFooter = lazy(() => import('./OsgardFooter'))

const readMotion = () => { try { return localStorage.getItem('osgard:motion') !== 'off' } catch { return true } }
const readOSALocale = (): 'ru' | 'en' => { try { return localStorage.getItem('osa:locale') === 'en' ? 'en' : 'ru' } catch { return 'ru' } }
const productHomes = { world: '/', intelligence: '/intelligence', play: '/play' }
const productNames = { world: 'OSGARD WORLD', intelligence: 'OSA Intelligence', play: 'OSGARD PLAY' }
const globalLinks = [['OSGARD', '/'], ['Intelligence', '/intelligence'], ['Play', '/play'], ['Development', '/development']] as const
export function BrandShell({ theme, children }: { theme: ProductTheme; children: ReactNode }) {
  const [motion, setMotion] = useState(readMotion)
  const [osaLocale, setOSALocale] = useState(readOSALocale)
  const [reduced, setReduced] = useState(false)
  const [quickOpen, setQuickOpen] = useState(false)
  const quickTrigger = useRef<HTMLButtonElement>(null)
  const currentLocation = useSyncExternalStore(subscribeBrowserNavigation, getBrowserSnapshot, getServerSnapshot)
  const currentUrl = new URL(currentLocation.href, 'https://osgard.world')
  const hash = currentUrl.hash
  const path = currentUrl.pathname.replace(/\/+$/, '') || '/'
  const product = brandAreaForPath(path, theme)
  const development = path === '/development' || path.startsWith('/development/')
  const englishChrome = osaLocale === 'en' && (product === 'intelligence' || product === 'play' || path === '/' || development)
  const gameTitle = path.startsWith('/play/world/') ? getPlayGameTitle(path.slice('/play/world/'.length)) : undefined
  const crumbs = brandBreadcrumbs(path, product, gameTitle)
  const worldBase = development ? '/development' : '/'
  const local = product === 'world'
    ? englishChrome ? [['Products', worldBase + '#products'], ['Cases', worldBase + '#cases'], ['Approach', worldBase + '#approach'], ['About', worldBase + '#about'], ['Contact', worldBase + '#contact']] : [['Продукты', worldBase + '#products'], ['Кейсы', worldBase + '#cases'], ['Подход', worldBase + '#approach'], ['О компании', worldBase + '#about'], ['Контакт', worldBase + '#contact']]
    : product === 'intelligence'
      ? path === '/intelligence'
        ? osaLocale === 'en' ? [['Review', '/intelligence#proof-card'], ['Lessons', '/lectures'], ['My progress', '/learning']] : [['Проверка', '/intelligence#proof-card'], ['Уроки', '/lectures'], ['Мой прогресс', '/learning']]
        : osaLocale === 'en' ? [['Method', '/intelligence#method'], ['Demo', '/intelligence#demo'], ['Programme', '/learning/program'], ['Lectures', '/lectures'], ['My progress', '/learning'], ['Practice', '/learning/campus']] : [['Метод', '/intelligence#method'], ['Демонстрация', '/intelligence#demo'], ['Программа', '/learning/program'], ['Лекции', '/lectures'], ['Мой прогресс', '/learning'], ['Практика', '/learning/campus']]
      : osaLocale === 'en' ? [['Worlds', '/play#catalog'], ['Favorites', '/play?view=favorites#catalog'], ['Recently opened', '/play?view=recent#catalog'], ['For partners', '/play/partners']] : [['Миры', '/play#catalog'], ['Избранное', '/play?view=favorites#catalog'], ['Недавние', '/play?view=recent#catalog'], ['Партнёрам', '/play/partners']]

  useEffect(() => {
    document.documentElement.dataset.product = theme
    document.documentElement.lang = englishChrome ? 'en' : 'ru'
    return () => { delete document.documentElement.dataset.product }
  }, [theme, product, osaLocale])
  useEffect(() => {
    const syncLocale = () => setOSALocale(readOSALocale())
    window.addEventListener('osgard:locale-change', syncLocale)
    window.addEventListener('storage', syncLocale)
    return () => {
      window.removeEventListener('osgard:locale-change', syncLocale)
      window.removeEventListener('storage', syncLocale)
    }
  }, [])
  useEffect(() => {
    document.documentElement.dataset.motion = motion ? 'on' : 'off'
    if (!motion) document.querySelector('.osgard-portal-transition')?.remove()
  }, [motion])
  useEffect(() => {
    const media = window.matchMedia?.('(prefers-reduced-motion: reduce)')
    const update = () => setReduced(Boolean(media?.matches))
    update()
    media?.addEventListener('change', update)
    const syncStorage = (event: StorageEvent) => { if (event.key === 'osgard:motion' || event.key === null) setMotion(readMotion()) }
    window.addEventListener('storage', syncStorage)
    return () => {
      media?.removeEventListener('change', update)
      window.removeEventListener('storage', syncStorage)
    }
  }, [])

  const closeQuickNav = () => {
    setQuickOpen(false)
    requestAnimationFrame(() => quickTrigger.current?.focus({ preventScroll: true }))
  }
  useEffect(() => {
    const shortcut = (event: KeyboardEvent) => {
      if (event.defaultPrevented || event.altKey || event.shiftKey || !(event.ctrlKey || event.metaKey) || event.key.toLowerCase() !== 'k') return
      if (document.querySelector('.osgard-cinematic, [data-osgard-pending]')) return
      event.preventDefault()
      if (quickOpen) closeQuickNav()
      else setQuickOpen(true)
    }
    window.addEventListener('keydown', shortcut)
    return () => window.removeEventListener('keydown', shortcut)
  }, [quickOpen])
  useEffect(() => { setQuickOpen(false) }, [path])

  const localState = (href: string): 'page' | 'location' | undefined => {
    const target = new URL(href, 'https://osgard.world')
    if ((target.pathname.replace(/\/+$/, '') || '/') !== path) return undefined
    const view = currentUrl.searchParams.get('view') || 'all'
    if (target.pathname === '/play' && (target.searchParams.get('view') || 'all') !== view) return undefined
    if (target.hash) return hash === target.hash || target.hash === '#catalog' && path === '/play' ? 'location' : undefined
    return 'page'
  }
  const toggleMotion = () => {
    if (reduced) return
    const enabled = !motion
    setMotion(enabled)
    try { localStorage.setItem('osgard:motion', enabled ? 'on' : 'off') } catch { /* The setting still applies to this open page. */ }
    document.documentElement.dataset.motion = enabled ? 'on' : 'off'
    window.dispatchEvent(new Event(MOTION_CHANGE_EVENT))
  }

  return <div className={`brand-system theme-${theme}${theme === 'play' && (path === '/play' || path === '/games' || path === '/entertainment') ? ' play-catalog-shell' : ''}`}>
    <a className="brand-skip" href="#product-main">{englishChrome ? 'Skip to content' : 'Перейти к содержанию'}</a>
    <header className="brand-header">
      <a href={productHomes[product]} aria-label={productNames[product]}><BrandLockup theme={product} /></a>
      <nav aria-label={englishChrome ? 'OSGARD products' : 'Продукты OSGARD'} className="brand-global-nav">
        {globalLinks.map(([name, href]) => <a key={href} href={href} aria-current={globalNavigationState(path, product, href)}>{name}</a>)}
      </nav>
      <button type="button" ref={quickTrigger} className="brand-quick-trigger" aria-haspopup="dialog" aria-expanded={quickOpen}
        aria-keyshortcuts="Control+K Meta+K" aria-label={englishChrome ? 'Quick access to OSGARD sections' : 'Быстрый переход по разделам OSGARD'} onClick={() => quickOpen ? closeQuickNav() : setQuickOpen(true)}>
        <span aria-hidden="true" className="brand-quick-symbol">⌕</span><span className="brand-quick-label">{englishChrome ? 'Sections' : 'Разделы'}</span><kbd>⌘K</kbd>
      </button>
      <button type="button" className="brand-motion" aria-pressed={reduced || !motion} disabled={reduced}
        aria-label={englishChrome ? 'Reduce motion' : 'Меньше движения'} title={englishChrome ? (reduced ? 'Reduced motion is enabled in device settings' : 'Turn off nonessential animation') : (reduced ? 'Уменьшение движения включено в настройках устройства' : 'Отключить необязательную анимацию')} onClick={toggleMotion}>
        <span className="brand-motion-state" aria-hidden="true">{reduced || !motion ? '◌' : '◉'}</span> {englishChrome ? 'Reduce motion' : 'Меньше движения'}
        <span className="brand-motion-value">{reduced ? (englishChrome ? 'System' : 'Система') : motion ? (englishChrome ? 'Off' : 'Выкл.') : (englishChrome ? 'On' : 'Вкл.')}</span>
      </button>
    </header>
    <div className="brand-local-bar">
      <span>{product === 'world' ? (englishChrome ? (development ? 'OSGARD DEVELOPMENT / Digital studio' : 'OSGARD WORLD / Digital studio') : (development ? 'Development / Разработка продуктов' : 'OSGARD WORLD / Цифровая студия')) : product === 'intelligence' ? (osaLocale === 'en' ? 'OSA / Understand. Verify. Decide.' : 'OSA / Понять. Проверить. Решить.') : (osaLocale === 'en' ? 'OSGARD PLAY / Interactive worlds' : 'OSGARD PLAY / Игровые миры')}</span>
      <nav aria-label={englishChrome ? 'Section navigation' : 'Навигация раздела'}>
        {local.map(([name, href]) => <a key={name} href={href} aria-current={localState(href)}>{name}</a>)}
      </nav>
    </div>
    <nav className="brand-breadcrumbs" aria-label="Путь к странице" hidden={!crumbs.length}>
      <ol>{crumbs.map((item, index) => <li key={index}>{item.href ? <a href={item.href}>{item.label}</a> : <span aria-current="page">{item.label}</span>}</li>)}</ol>
    </nav>
    <div id="product-main" tabIndex={-1}>{children}</div>
    <Suspense fallback={<footer className="brand-footer brand-footer-loading" aria-label="Загрузка ссылок" />}>
      <OsgardFooter product={product} motion={motion} reduced={reduced} locale={osaLocale} />
    </Suspense>
    <Suspense fallback={null}>
      {quickOpen && <OsgardQuickNav onClose={closeQuickNav} onNavigate={() => {
          setQuickOpen(false)
          requestAnimationFrame(() => document.getElementById('product-main')?.focus({ preventScroll: true }))
        }} />}
    </Suspense>
  </div>
}
