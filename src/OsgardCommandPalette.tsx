import { useEffect, useMemo, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import type { KeyboardEvent as ReactKeyboardEvent } from 'react'
import { playGameTitles } from './playGameTitles'
import { cases } from './featuredCases'
import { navigateBrowserUrl } from './browserNavigation'

type Destination = {
  id: string
  label: string
  subtitle: string
  href: string
  section: string
  keywords?: string
}

const destinations: Destination[] = [
  { id: 'world', label: 'OSGARD World', subtitle: 'Главная · шесть направлений', href: '/', section: 'НАПРАВЛЕНИЯ', keywords: 'главная портал планета мир' },
  { id: 'osa', label: 'OSA Intelligence', subtitle: 'Проверка утверждений и источников', href: '/intelligence', section: 'НАПРАВЛЕНИЯ', keywords: 'ии искусственный интеллект доказательства nist' },
  { id: 'play', label: 'OSGARD Play', subtitle: 'Все 19 игровых миров', href: '/play', section: 'НАПРАВЛЕНИЯ', keywords: 'игры играть каталог' },
  { id: 'development', label: 'Development', subtitle: 'Кейсы, демо и прототипы', href: '/development', section: 'НАПРАВЛЕНИЯ', keywords: 'разработка проекты кейсы' },
  { id: 'academy', label: 'OSA Academy', subtitle: 'Учебный кабинет и прогресс', href: '/academy', section: 'ОБУЧЕНИЕ', keywords: 'академия образование кабинет' },
  { id: 'lectures', label: 'Лекции OSA', subtitle: 'Каталог из восьми уроков', href: '/lectures', section: 'ОБУЧЕНИЕ', keywords: 'лекции 8 уроков знания' },
  { id: 'learning', label: 'Мой прогресс', subtitle: 'Реальный локальный учебный маршрут', href: '/learning', section: 'ОБУЧЕНИЕ', keywords: 'прогресс занятия результат' },
  { id: 'assessment', label: 'Самопроверка', subtitle: 'Проверка учебных знаний', href: '/learning/assessment', section: 'ОБУЧЕНИЕ', keywords: 'экзамен тест проверка' },
  { id: 'favorites', label: 'Избранные игры', subtitle: 'Миры, сохранённые в браузере', href: '/play?view=favorites#catalog', section: 'ИГРЫ', keywords: 'любимые коллекция сохраненные' },
  { id: 'recent', label: 'Недавние игры', subtitle: 'Последние открытые миры', href: '/play?view=recent#catalog', section: 'ИГРЫ', keywords: 'история игры' },
  { id: 'archive', label: 'Архив Entertainment', subtitle: 'Семь игр из истории OSGARD', href: '/entertainment/index.html', section: 'ИГРЫ', keywords: 'архив семь 7 старые игры entertainment' },
  { id: 'partners', label: 'Партнёрам Play', subtitle: 'Сотрудничество и интеграции', href: '/play/partners', section: 'ОБРАТНАЯ СВЯЗЬ' },
  { id: 'quality', label: 'Состояние сборки', subtitle: 'Проверки и ограничения платформы', href: '/quality', section: 'ОБРАТНАЯ СВЯЗЬ', keywords: 'качество статус техническая проверка' },
]
const games: Destination[] = Object.entries(playGameTitles).map(([id, label]) => ({
  id: 'game-' + id, label, subtitle: 'Открыть страницу игрового мира',
  href: '/play/world/' + id, section: 'ИГРОВЫЕ МИРЫ', keywords: id.replaceAll('-', ' '),
}))
const portfolio: Destination[] = cases.map(item => ({
  id: 'case-' + item.id, label: item.name,
  subtitle: item.type + ' · ' + item.category,
  href: item.href, section: 'ПРОЕКТЫ', keywords: item.id + ' ' + item.description,
}))
const allDestinations = [...destinations, ...portfolio, ...games]
const routeSuggestions = (path: string): string[] => {
  if (path.startsWith('/play') || path === '/games' || path === '/entertainment') {
    return ['play','favorites','recent','archive','game-vector-zero','game-time','academy','intelligence','world']
  }
  if (path === '/development' || path.startsWith('/development/')) {
    return ['development','case-tedes','case-phantom','case-merakki','case-essentia','world','intelligence','play','quality']
  }
  if (path === '/intelligence' || path.startsWith('/learning') || path.startsWith('/lectures') || path === '/academy') {
    return ['intelligence','academy','lectures','learning','assessment','world','play','development','quality']
  }
  return ['world','intelligence','play','development','academy','lectures','learning','quality','archive']
}
const normal = (value: string): string => value.trim().toLocaleLowerCase('ru')

export function OsgardCommandPalette({ path, initialOpen = false }: { path: string; initialOpen?: boolean }) {
  const [open, setOpen] = useState(initialOpen)
  const [query, setQuery] = useState('')
  const trigger = useRef<HTMLButtonElement>(null)
  const input = useRef<HTMLInputElement>(null)
  const dialog = useRef<HTMLDivElement>(null)
  const prevPath = useRef(path)
  const matches = useMemo(() => {
    const term = normal(query)
    if (term) return allDestinations.filter(item =>
      normal([item.label,item.subtitle,item.section,item.keywords || ''].join(' ')).includes(term)).slice(0, 14)
    const byId = new Map(allDestinations.map(item => [item.id, item]))
    return routeSuggestions(path).flatMap(id => {
      const item = byId.get(id)
      return item ? [item] : []
    }).slice(0, 9)
  }, [query, path])

  useEffect(() => {
    const key = (event: KeyboardEvent) => {
      if (event.key.toLowerCase() !== 'k' || !(event.ctrlKey || event.metaKey) || event.altKey) return
      const target = event.target
      if (target instanceof HTMLElement && target.closest('input, textarea, [contenteditable="true"]') && target !== input.current) return
      if (document.querySelector('.osgard-cinematic, [data-osgard-pending]')) return
      event.preventDefault()
      setOpen(state => !state)
    }
    window.addEventListener('keydown', key)
    return () => window.removeEventListener('keydown', key)
  }, [])

  useEffect(() => {
    if (prevPath.current !== path) {
      prevPath.current = path
      setOpen(false)
      setQuery('')
    }
  }, [path])

  useEffect(() => {
    if (!open) return
    const previousOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    input.current?.focus({ preventScroll: true })
    return () => {
      document.body.style.overflow = previousOverflow
      trigger.current?.focus({ preventScroll: true })
    }
  }, [open])

  const close = () => { setOpen(false); setQuery('') }
  const activate = (href: string) => {
    close()
    if (!navigateBrowserUrl(href)) window.location.assign(href)
  }
  const handleKeys = (event: ReactKeyboardEvent<HTMLDivElement>) => {
    if (event.key === 'Escape') {
      event.preventDefault()
      close()
    } else if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault()
      const results = Array.from(dialog.current?.querySelectorAll<HTMLAnchorElement>('[data-command-result]') || [])
      if (!results.length) return
      const current = results.indexOf(document.activeElement as HTMLAnchorElement)
      if (event.key === 'ArrowDown') results[(current + 1) % results.length]?.focus()
      else if (current <= 0) input.current?.focus()
      else results[current - 1]?.focus()
    } else if (event.key === 'Enter' && document.activeElement === input.current && matches.length) {
      event.preventDefault()
      activate(matches[0].href)
    } else if (event.key === 'Tab') {
      // Keep keyboard focus inside the modal; native links retain semantic navigation.
      const candidates = Array.from(dialog.current?.querySelectorAll<HTMLElement>('button, input, a[href]') || [])
        .filter(element => element.getClientRects().length > 0 && !element.hasAttribute('disabled'))
      if (!candidates.length) return
      const first = candidates[0], last = candidates[candidates.length - 1]
      if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus() }
      else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus() }
    }
  }

  return <>
    <button ref={trigger} type="button" className="osgard-command-trigger"
      aria-haspopup="dialog" aria-expanded={open} aria-keyshortcuts="Control+K Meta+K"
      aria-label="Быстрый переход по OSGARD" title="Поиск разделов и игр (Ctrl+K)"
      onClick={() => { setQuery(''); setOpen(true) }}>
      <span className="osgard-command-glyph" aria-hidden="true">⌕</span>
      <span className="osgard-command-trigger-label">Быстрый переход</span>
      <kbd aria-hidden="true">⌘ K</kbd>
    </button>
    {open && createPortal(<div className="osgard-command-backdrop" role="presentation" onMouseDown={event => {
      if (event.target === event.currentTarget) close()
    }}>
      <div className="osgard-command-dialog" role="dialog" aria-modal="true"
        aria-labelledby="osgard-command-title" aria-describedby="osgard-command-help"
        ref={dialog} onKeyDown={handleKeys}>
        <div className="osgard-command-heading">
          <div><span className="osgard-command-kicker">OSGARD / COMMAND</span>
            <h2 id="osgard-command-title">Куда отправимся?</h2></div>
          <button type="button" className="osgard-command-close" onClick={close} aria-label="Закрыть поиск">✕</button>
        </div>
        <label className="osgard-command-input-wrap">
          <span className="osgard-command-input-icon" aria-hidden="true">⌕</span>
          <input ref={input} type="search" autoComplete="off" spellCheck={false}
            value={query} maxLength={100} aria-label="Поиск по OSGARD"
            placeholder="Название раздела или игры…" onChange={event => setQuery(event.target.value)} />
          <span className="osgard-command-input-hint" aria-hidden="true">↵</span>
        </label>
        <p id="osgard-command-help" className="osgard-command-help">
          Введите название · ↑ ↓ — выбрать · Enter — открыть · Esc — закрыть
        </p>
        <nav className="osgard-command-results" aria-label="Результаты быстрого перехода">
          {matches.length ? <ul>{matches.map((item, index) => <li key={item.id}>
            <a data-command-result href={item.href} onClick={close}
              aria-current={item.href.split(/[?#]/)[0].split('/').filter(Boolean).join('/') === path.split('/').filter(Boolean).join('/') ? 'page' : undefined}>
              <span className="osgard-command-result-index" aria-hidden="true">{String(index + 1).padStart(2,'0')}</span>
              <span className="osgard-command-result-copy">
                <span className="osgard-command-result-title">{item.label}</span>
                <small>{item.subtitle}</small>
              </span>
              <span className="osgard-command-result-section">{item.section}</span>
              <span className="osgard-command-result-arrow" aria-hidden="true">↗</span>
            </a>
          </li>)}</ul> :
            <div className="osgard-command-empty" role="status">Ничего не найдено. Попробуйте другое название или откройте полный каталог.</div>}
        </nav>
        <div className="osgard-command-footer"><span>{matches.length} {query ? 'совпадений' : 'быстрых направлений'}</span>
          <span>Без регистрации · реальные маршруты OSGARD</span></div>
      </div>
    </div>, document.body)}
  </>
}
