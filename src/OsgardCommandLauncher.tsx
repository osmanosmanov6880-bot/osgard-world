import { lazy, Suspense, useEffect, useState } from 'react'
import './osgardCommandPalette.css'

/**
 * A real, immediately usable header control. Searchable games and portfolio data
 * are loaded only when somebody actually invokes the command. This protects
 * the existing 95 KiB Play landing JavaScript budget on slow connections.
 */
const LoadedCommand = lazy(() =>
  import('./OsgardCommandPalette').then(module => ({ default: module.OsgardCommandPalette }))
)

export function OsgardCommandLauncher({ path }: { path: string }) {
  const [requested, setRequested] = useState(false)

  useEffect(() => {
    if (requested) return
    const shortcut = (event: KeyboardEvent) => {
      if (event.key.toLowerCase() !== 'k' || !(event.ctrlKey || event.metaKey) || event.altKey) return
      const target = event.target
      if (target instanceof HTMLElement && target.closest('input, textarea, [contenteditable="true"]')) return
      if (document.querySelector('.osgard-cinematic, [data-osgard-pending]')) return
      event.preventDefault()
      setRequested(true)
    }
    window.addEventListener('keydown', shortcut)
    return () => window.removeEventListener('keydown', shortcut)
  }, [requested])

  if (requested) return <Suspense fallback={
    <span className="osgard-command-trigger" role="status" aria-label="Загружается поиск OSGARD">
      <span className="osgard-command-glyph" aria-hidden="true">⌕</span>
      <span className="osgard-command-trigger-label">Поиск…</span>
    </span>
  }>
    <LoadedCommand path={path} initialOpen />
  </Suspense>

  return <button type="button" className="osgard-command-trigger"
    aria-haspopup="dialog" aria-expanded="false" aria-keyshortcuts="Control+K Meta+K"
    aria-label="Быстрый переход по OSGARD" title="Поиск разделов и игр (Ctrl+K)"
    onClick={() => setRequested(true)}>
    <span className="osgard-command-glyph" aria-hidden="true">⌕</span>
    <span className="osgard-command-trigger-label">Быстрый переход</span>
    <kbd aria-hidden="true">⌘ K</kbd>
  </button>
}
