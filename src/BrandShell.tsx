import { useEffect, useState } from 'react'
import type { ReactNode } from 'react'
import { BrandLockup } from './BrandMark'
import { brandAreaForPath, brandBreadcrumbs, globalNavigationState } from './brandNavigation'
import { getPlayGame } from './redesignCatalog'
import { BROWSER_LOCATION_EVENT, browserLocationKey } from './browserNavigation'
import type { ProductTheme } from './BrandMark'
import './brandFonts.css'
import './brandSystem.css'
import './omegaSystems.css'

const readMotion = () => { try { return localStorage.getItem('osgard:motion') !== 'off' } catch { return true } }
const productHomes = { world: '/', intelligence: '/intelligence', play: '/play' }
const productNames = { world: 'OSGARD WORLD', intelligence: 'OSA Intelligence', play: 'OSGARD PLAY' }
const globalLinks = [['OSGARD', '/'], ['Intelligence', '/intelligence'], ['Play', '/play'], ['Development', '/development']] as const
const footerGroups = [
  { title: 'Продукты', links: [['OSGARD WORLD', '/'], ['OSA Intelligence', '/intelligence'], ['OSGARD PLAY', '/play'], ['Разработка', '/development']] },
  { title: 'Моя работа', links: [['Рабочий центр', '/workspace/overview'], ['Проекты', '/workspace'], ['Команды', '/teams'], ['Полученные материалы', '/deliveries'], ['Покупки', '/purchases'], ['Аккаунт', '/account'], ['Мои данные', '/data']] },
  { title: 'Информация', links: [['Фирменная система', '/brand'], ['Состояние сборки', '/quality'], ['Приватность', '/privacy/'], ['Условия', '/terms/'], ['Связаться', '/#contact']] },
]

export function BrandShell({ theme, children }: { theme: ProductTheme; children: ReactNode }) {
  const [motion, setMotion] = useState(readMotion)
  const [reduced, setReduced] = useState(false)
  const [currentLocation, setCurrentLocation] = useState(browserLocationKey)
  const currentUrl = new URL(currentLocation, 'https://osgard.world')
  const hash = currentUrl.hash
  const path = location.pathname.replace(/\/+$/, '') || '/'
  const product = brandAreaForPath(path, theme)
  const development = path === '/development' || path.startsWith('/development/')
  const game = path.startsWith('/play/world/') ? getPlayGame(path.slice('/play/world/'.length)) : undefined
  const crumbs = brandBreadcrumbs(path, product, game?.title)
  const worldBase = development ? '/development' : '/'
  const local = product === 'world'
    ? [['Продукты', worldBase + '#products'], ['Кейсы', worldBase + '#cases'], ['Подход', worldBase + '#approach'], ['О компании', worldBase + '#about'], ['Контакт', worldBase + '#contact']]
    : product === 'intelligence'
      ? path === '/intelligence'
        ? [['Проверка', '/intelligence#demo'], ['Уроки', '/lectures'], ['Мой прогресс', '/learning']]
        : [['Метод', '/intelligence#method'], ['Демонстрация', '/intelligence#demo'], ['Программа', '/learning/program'], ['Лекции', '/lectures'], ['Мой прогресс', '/learning'], ['Практика', '/learning/campus']]
      : [['Миры', '/play#catalog'], ['Избранное', '/play?view=favorites#catalog'], ['Недавние', '/play?view=recent#catalog'], ['Партнёрам', '/play/partners']]

  useEffect(() => {
    document.documentElement.dataset.product = theme
    document.documentElement.lang = 'ru'
    return () => { delete document.documentElement.dataset.product }
  }, [theme])
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
    const syncLocation = () => setCurrentLocation(browserLocationKey())
    window.addEventListener('storage', syncStorage)
    window.addEventListener('hashchange', syncLocation)
    window.addEventListener('popstate', syncLocation)
    window.addEventListener('pageshow', syncLocation)
    window.addEventListener(BROWSER_LOCATION_EVENT, syncLocation)
    syncLocation()
    return () => {
      media?.removeEventListener('change', update)
      window.removeEventListener('storage', syncStorage)
      window.removeEventListener('hashchange', syncLocation)
      window.removeEventListener('popstate', syncLocation)
      window.removeEventListener('pageshow', syncLocation)
      window.removeEventListener(BROWSER_LOCATION_EVENT, syncLocation)
    }
  }, [])

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
  }

  return <div className={`brand-system theme-${theme}`}>
    <a className="brand-skip" href="#product-main">Перейти к содержанию</a>
    <header className="brand-header">
      <a href={productHomes[product]} aria-label={productNames[product]}><BrandLockup theme={product} /></a>
      <nav aria-label="Продукты OSGARD" className="brand-global-nav">
        {globalLinks.map(([name, href]) => <a key={href} href={href} aria-current={globalNavigationState(path, product, href)}>{name}</a>)}
      </nav>
      <button type="button" className="brand-motion" aria-pressed={reduced || !motion} disabled={reduced}
        aria-label="Меньше движения" title={reduced ? 'Уменьшение движения включено в настройках устройства' : 'Отключить необязательную анимацию'} onClick={toggleMotion}>
        <span className="brand-motion-state" aria-hidden="true">{reduced || !motion ? '◌' : '◉'}</span> Меньше движения
        <span className="brand-motion-value">{reduced ? 'Система' : motion ? 'Выкл.' : 'Вкл.'}</span>
      </button>
    </header>
    <div className="brand-local-bar">
      <span>{product === 'world' ? development ? 'Development / Разработка продуктов' : 'OSGARD WORLD / Цифровая студия' : product === 'intelligence' ? 'OSA / Понять. Проверить. Решить.' : 'OSGARD PLAY / Игровые миры'}</span>
      <nav aria-label="Навигация раздела">
        {local.map(([name, href]) => <a key={name} href={href} aria-current={localState(href)}>{name}</a>)}
      </nav>
    </div>
    <nav className="brand-breadcrumbs" aria-label="Путь к странице" hidden={!crumbs.length}>
      <ol>{crumbs.map((item, index) => <li key={index}>{item.href ? <a href={item.href}>{item.label}</a> : <span aria-current="page">{item.label}</span>}</li>)}</ol>
    </nav>
    <div id="product-main" tabIndex={-1}>{children}</div>
    <footer className="brand-footer">
      <div className="brand-footer-intro"><BrandLockup theme={product} /><p>Одна экосистема.<br />Разные способы двигаться вперёд.</p></div>
      {footerGroups.map(group => <nav key={group.title} aria-label={group.title} className="brand-footer-group"><h2>{group.title}</h2>{group.links.map(([label, href]) => <a key={href} href={href}>{label}</a>)}</nav>)}
      <small className="brand-footer-note">Гостевой прогресс остаётся в этом браузере. Серверные проекты доступны через аккаунт. <a href="/quality#measurements">Посмотреть и удалить локальный журнал действий →</a></small>
    </footer>
  </div>
}
