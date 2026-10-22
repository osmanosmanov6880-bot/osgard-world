import { useEffect, useId, useMemo, useRef, useState } from 'react'
import type { MouseEvent as ReactMouseEvent, KeyboardEvent as ReactKeyboardEvent } from 'react'
import { hasUnsavedChanges, navigateBrowserUrl } from './browserNavigation'
import { isReactRoute } from './osgardRouting'
import { clearQuickNavRecent, readQuickNavRecent, rememberQuickNav, searchOsgardCommands } from './osgardQuickNavData'
import type { OsgardCommand } from './osgardQuickNavData'
import './osgardQuickNav.css'

type Props = { onClose: () => void; onNavigate: () => void }

/** A real cross-product shortcut, not an AI search or a list of invented features. */
export default function OsgardQuickNav({ onClose, onNavigate }: Props) {
  const [query, setQuery] = useState('')
  const [recent, setRecent] = useState(readQuickNavRecent)
  const [active, setActive] = useState(0)
  const results = useMemo(() => searchOsgardCommands(query, recent), [query, recent])
  const listId = useId()
  const dialogRef = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLInputElement>(null)
  const latestClose = useRef(onClose)
  latestClose.current = onClose

  useEffect(() => { setActive(0) }, [query])
  useEffect(() => {
    const before = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    const frame = requestAnimationFrame(() => inputRef.current?.focus())
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        event.preventDefault()
        event.stopPropagation()
        latestClose.current()
        return
      }
      if (event.key !== 'Tab') return
      const dialog = dialogRef.current
      if (!dialog) return
      const focusable = Array.from(dialog.querySelectorAll<HTMLElement>('button:not([disabled]), input:not([disabled]), a[href], [tabindex]:not([tabindex="-1"])'))
        .filter(element => element.getClientRects().length > 0)
      if (!focusable.length) { event.preventDefault(); return }
      const current = document.activeElement
      if (event.shiftKey && (current === focusable[0] || !dialog.contains(current))) {
        event.preventDefault(); focusable[focusable.length - 1].focus()
      } else if (!event.shiftKey && (current === focusable[focusable.length - 1] || !dialog.contains(current))) {
        event.preventDefault(); focusable[0].focus()
      }
    }
    document.addEventListener('keydown', onKey, true)
    return () => {
      cancelAnimationFrame(frame)
      document.removeEventListener('keydown', onKey, true)
      document.body.style.overflow = before
    }
  }, [])

  const select = (event: ReactMouseEvent<HTMLAnchorElement>, command: OsgardCommand) => {
    if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    const destination = new URL(command.href, location.href)
    const current = new URL(location.href)
    if (destination.origin !== current.origin) { event.preventDefault(); return }
    const sameDocument = destination.pathname === current.pathname && destination.search === current.search
    if (sameDocument) {
      event.preventDefault()
      if (destination.hash && destination.hash !== current.hash) window.location.hash = destination.hash
      else if (destination.hash) document.getElementById(decodeURIComponent(destination.hash.slice(1)))?.scrollIntoView({ block: 'start' })
      else window.scrollTo({ top: 0, behavior: 'instant' })
      setRecent(rememberQuickNav(command.id))
      onNavigate()
      return
    }
    if (isReactRoute(destination.pathname) && isReactRoute(current.pathname)) {
      event.preventDefault()
      // The central router handles unsaved forms and preserves SPA transitions.
      // Its refusal must never fall through to an unguarded native navigation.
      if (!navigateBrowserUrl(command.href)) return
      setRecent(rememberQuickNav(command.id))
      onNavigate()
      return
    }
    if (hasUnsavedChanges()) { event.preventDefault(); return }
    // Static archives and other non-SPA pages use their native URL.
    setRecent(rememberQuickNav(command.id))
    onNavigate()
  }
  const selectActive = () => {
    const element = document.getElementById(listId + '-option-' + active)
    if (element instanceof HTMLAnchorElement) element.click()
  }
  const handleInputKey = (event: ReactKeyboardEvent<HTMLInputElement>) => {
    if (event.key === 'ArrowDown') { event.preventDefault(); setActive(i => (i + 1) % Math.max(results.length, 1)) }
    if (event.key === 'ArrowUp') { event.preventDefault(); setActive(i => (i - 1 + Math.max(results.length, 1)) % Math.max(results.length, 1)) }
    if (event.key === 'Enter' && results.length) { event.preventDefault(); selectActive() }
  }

  return <div className="osgard-quick-overlay" data-osgard-quick-nav="open"
    onMouseDown={event => { if (event.target === event.currentTarget) onClose() }}>
    <div className="osgard-quick-dialog" ref={dialogRef} role="dialog" aria-modal="true"
      aria-labelledby={listId + '-title'} aria-describedby={listId + '-description'}>
      <div className="osgard-quick-top">
        <div>
          <p className="osgard-quick-eyebrow">OSGARD / UNIVERSAL NAVIGATOR</p>
          <h2 id={listId + '-title'}>Куда перейти?</h2>
          <p id={listId + '-description'}>Найдите раздел и откройте настоящую страницу экосистемы.</p>
        </div>
        <button className="osgard-quick-close" type="button" onClick={onClose} aria-label="Закрыть навигатор">×</button>
      </div>
      <div className="osgard-quick-search">
        <span aria-hidden="true">⌕</span>
        <input ref={inputRef} type="search" value={query} onChange={event => setQuery(event.target.value)}
          onKeyDown={handleInputKey}
          role="combobox" aria-autocomplete="list" aria-expanded="true"
          aria-controls={listId + '-results'} aria-activedescendant={results.length ? listId + '-option-' + Math.min(active, results.length - 1) : undefined}
          aria-label="Поиск по разделам OSGARD" placeholder="Например: игры, уроки, TEDES…" autoComplete="off" />
        <kbd>ESC</kbd>
      </div>
      <div className="osgard-quick-meta">
        <span aria-live="polite">{results.length ? 'НАЙДЕНО: ' + results.length : 'НИЧЕГО НЕ НАЙДЕНО'}</span>
        {recent.length > 0 && <button type="button" onClick={() => { clearQuickNavRecent(); setRecent([]); setActive(0) }}>
          Очистить недавние
        </button>}
      </div>
      <div className="osgard-quick-results" id={listId + '-results'} role="listbox" aria-label="Доступные разделы">
        {results.length ? results.map((command, index) =>
          <a key={command.id} id={listId + '-option-' + index} href={command.href} role="option"
            aria-selected={index === Math.min(active, results.length - 1)}
            data-command-id={command.id} className={index === active ? 'osgard-quick-result is-active' : 'osgard-quick-result'}
            onMouseEnter={() => setActive(index)} onFocus={() => setActive(index)}
            onClick={event => select(event, command)}>
            <span className="osgard-quick-number">{String(index + 1).padStart(2, '0')}</span>
            <span className="osgard-quick-info"><small>{recent.includes(command.id) && !query ? 'НЕДАВНО · ' : ''}{command.group}</small><strong>{command.label}</strong><em>{command.description}</em></span>
            <span className="osgard-quick-arrow" aria-hidden="true">↗</span>
          </a>
        ) : <div className="osgard-quick-empty"><strong>Такого раздела нет.</strong><p>Попробуйте «игры», «академия», «проекты» или «ИИ».</p></div>}
      </div>
      <div className="osgard-quick-bottom"><span>↑ ↓ Выбрать</span><span>ENTER Открыть</span><span>ESC Закрыть</span><span>Ctrl / ⌘ + K</span></div>
    </div>
  </div>
}
