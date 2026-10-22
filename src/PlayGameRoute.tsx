import { useEffect, useState } from 'react'
import { getPlayGame, playGames } from './redesignCatalog'
import { PLAY_COLLECTION_KEY, emptyPlayCollection, parsePlayCollection, toggleFavorite, visitGame } from './playCollection'
import type { PlayCollection } from './playCollection'
import { playReturnHref } from './playFilters'
import { recordBrandEvent } from './brandTelemetry'
import PlayGameDetail from './PlayGameDetail'

const ids = playGames.map(game => game.id)
const genres = [...new Set(playGames.map(game => game.genre))]

function loadCollection(): PlayCollection {
  const current = localStorage.getItem(PLAY_COLLECTION_KEY)
  if (current) {
    try { return parsePlayCollection(current, ids) } catch { /* Recover optional storage without blocking the game. */ }
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

// The route is lazy in main.tsx. Its session controller and iframe/fullscreen
// handling are therefore downloaded only when a visitor opens a game's page.
export default function PlayGameRoute({ gameId }: { gameId: string }) {
  const game = getPlayGame(gameId)
  const returnTo = playReturnHref(location.search, genres)
  const [collection, setCollection] = useState<PlayCollection>(emptyPlayCollection)
  const [message, setMessage] = useState('')

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
  useEffect(() => { if (game) mutate(previous => visitGame(previous, game.id)) }, [game?.id])

  if (!game) return <main className="brand-container"><section className="brand-section">
    <h1>Мир не найден.</h1><a className="brand-button primary" href={returnTo}>Вернуться в каталог →</a>
  </section></main>

  return <PlayGameDetail game={game} returnTo={returnTo}
    isFavorite={collection.favorites.includes(game.id)} onToggleFavorite={() => mutate(previous => toggleFavorite(previous, game.id))}
    message={message} onLaunch={() => recordBrandEvent('game_launch_clicked', game.id)} />
}
