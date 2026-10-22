import { useEffect, useId, useMemo, useRef, useState } from 'react'
import type { MouseEvent as ReactMouseEvent, KeyboardEvent as ReactKeyboardEvent } from 'react'
import { hasUnsavedChanges, navigateBrowserUrl } from './browserNavigation'
import { isReactRoute } from './osgardRouting'
import { clearQuickNavRecent, getOsgardContextSuggestions, osgardCommands, readQuickNavRecent, rememberQuickNav, searchOsgardCommands } from './osgardQuickNavData'
import type { OsgardCommand } from './osgardQuickNavData'
import './osgardQuickNav.css'

const groups = ['Все', 'Игры', 'Знания', 'Проекты', 'Экосистема'] as const
type GroupFilter = typeof groups[number]
type Props = { onClose: () => void; onNavigate: () => void }

/** A real cross-product shortcut, not an AI search or a list of invented features. */
export default function OsgardQuickNav({ onClose, onNavigate }: Props) {
  const [query, setQuery] = useState('')
  const [group, setGroup] = useState<GroupFilter>('Все')
  const [recent, setRecent] = useState(readQuickNavRecent)
  const [active, setActive] = useState(0)
  const results = useMemo(() => searchOsgardCommands(query, recent).filter(command => group === 'Все' || command.group === group), [query, recent, group])
  const contextSuggestions = getOsgardContextSuggestions(location.pathname)
  const selectedIndex = Math.min(active, Math.max(results.length - 1, 0))
  const listId = useId()
  const dialogRef = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLInputElement>(null)
  const latestClose = useRef(onClose)
  latestClose.current = onClose

  useEffect(() => { setActive(0) }, [query, group])
  useEffect(() => {
    if (document.activeElement !== inputRef.current || results.length === 0) return
    document.getElementById(listId + '-option-' + selectedIndex)?.scrollIntoView({ block: 'nearest', inline: 'nearest' })
  }, [selectedIndex, results, listId])
  useEffect(() => {
    const before = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    // aria-modal alone does not stop assistive technologies from exploring the
    // page underneath. Keep only this dialog interactive while it is open.
    // Observe direct shell children because the footer is lazy-loaded.
    const dialog = dialogRef.current
    const shell = dialog?.closest<HTMLElement>('.brand-system')
    const overlay = dialog?.closest<HTMLElement>('.osgard-quick-overlay')
    const previousInert = new Map<HTMLElement, boolean>()
    const lockBackground = () => {
      if (!shell) return
      for (const child of Array.from(shell.children)) {
        if (!(child instanceof HTMLElement) || child === overlay) continue
        if (!previousInert.has(child)) previousInert.set(child, child.inert)
        child.inert = true
      }
    }
    lockBackground()
    const observer = shell ? new MutationObserver(lockBackground) : null
    if (shell) observer?.observe(shell, { childList: true })
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
      observer?.disconnect()
      for (const [element, inert] of previousInert) element.inert = inert
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
    const element = document.getElementById(listId + '-option-' + selectedIndex)
    if (element instanceof HTMLAnchorElement) element.click()
  }
  const handleInputKey = (event: ReactKeyboardEvent<HTMLInputElement>) => {
    if (event.key === 'ArrowDown') { event.preventDefault(); setActive(i => (i + 1) % Math.max(results.length, 1)) }
    if (event.key === 'ArrowUp') { event.preventDefault(); setActive(i => (i - 1 + Math.max(results.length, 1)) % Math.max(results.length, 1)) }
    if (event.key === 'Home') { event.preventDefault(); setActive(0) }
    if (event.key === 'End') { event.preventDefault(); setActive(Math.max(results.length - 1, 0)) }
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
          aria-controls={listId + '-results'} aria-activedescendant={results.length ? listId + '-option-' + selectedIndex : undefined}
          aria-label="Поиск по разделам OSGARD" placeholder="Например: игры, уроки, TEDES…" autoComplete="off" />
        <kbd>ESC</kbd>
      </div>
      <div className="osgard-quick-categories" role="group" aria-label="Фильтр по направлениям">
        {groups.map(value => <button key={value} type="button" aria-pressed={group === value}
          onClick={() => setGroup(value)}>
          {value}<span aria-hidden="true">{value === 'Все' ? osgardCommands.length : osgardCommands.filter(command => command.group === value).length}</span>
        </button>)}
      </div>
      {!query.trim() && group === 'Все' && <div className="osgard-quick-context">
        <span>КУДА ДАЛЬШЕ</span>
        <nav aria-label="Быстрые действия текущего раздела">
          {contextSuggestions.map(command => <a href={command.href} key={command.id} onClick={event => select(event, command)}>
            {command.label}<span aria-hidden="true">↗</span>
          </a>)}
        </nav>
      </div>}
      <div className="osgard-quick-meta">
        <span aria-live="polite">{results.length ? 'НАЙДЕНО: ' + results.length : 'НИЧЕГО НЕ НАЙДЕНО'}</span>
        {recent.length > 0 && <button type="button" onClick={() => { clearQuickNavRecent(); setRecent([]); setActive(0) }}>
          Очистить недавние
        </button>}
      </div>
      <div className="osgard-quick-results" id={listId + '-results'} role="listbox" aria-label="Доступные разделы">
        {results.length ? results.map((command, index) =>
          <a key={command.id} id={listId + '-option-' + index} href={command.href} role="option"
            aria-selected={index === selectedIndex}
            data-command-id={command.id} className={'osgard-quick-result' + (command.art ? ' has-art' : '') + (index === selectedIndex ? ' is-active' : '')}
            onMouseEnter={() => setActive(index)} onFocus={() => setActive(index)}
            onClick={event => select(event, command)}>
            <span className="osgard-quick-number">{String(index + 1).padStart(2, '0')}</span>
            {command.art && <span className="osgard-quick-thumb" aria-hidden="true"><img src={command.art}
              width="96" height="68" loading="lazy" decoding="async" alt="" /></span>}
            <span className="osgard-quick-info"><small>{recent.includes(command.id) && !query ? 'НЕДАВНО · ' : ''}{command.group}</small><strong>{command.label}</strong><em>{command.description}</em></span>
            <span className="osgard-quick-arrow" aria-hidden="true">↗</span>
          </a>
        ) : <div className="osgard-quick-empty"><strong>Такого раздела нет.</strong><p>Попробуйте «игры», «академия», «проекты» или «ИИ».</p></div>}
      </div>
      <div className="osgard-quick-bottom"><span>↑ ↓ Выбрать</span><span>Home / End</span><span>ENTER Открыть</span><span>ESC Закрыть</span><span>Ctrl / ⌘ + K</span></div>
    </div>
  </div>
}
