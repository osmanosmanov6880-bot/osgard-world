import { useState } from 'react'
import { ChevronLeft, ChevronRight } from './PlayIcons'
import { getPlayGame } from './redesignCatalog'
import { FEATURED_WORLD_IDS } from './playCinematicData'
import PlayWorldCard from './PlayWorldCard'
import type { PlayCollection } from './playCollection'
import type { PlayFilters } from './playFilters'

// Featured game cards live below the hero. Download and render their runtime
// only after the first-screen PlayHome bundle has initialized.
const featuredWorlds = FEATURED_WORLD_IDS.map(id => getPlayGame(id)).filter(game => game !== undefined)

export default function PlayFeaturedSection({ filters, collection, onFavorite }: {
  filters: PlayFilters
  collection: PlayCollection
  onFavorite: (id: string) => void
}) {
  const [featuredOffset, setFeaturedOffset] = useState(0)
  if (!featuredWorlds.length) return null
  const selectedWorlds = Array.from({ length: 3 }, (_, index) => featuredWorlds[(featuredOffset + index) % featuredWorlds.length])
  return (
    <section id="featured" className="cp-section cp-container cp-featured" aria-labelledby="featured-title" data-reveal>
      <div className="cp-section-top">
        <div><p className="cp-eyebrow">ИЗБРАННЫЕ МИРЫ</p><h2 id="featured-title">ИССЛЕДУЙ. ИГРАЙ. <span>ОТКРЫВАЙ.</span></h2></div>
        <div className="cp-featured-navigation"><p>Разные жанры. Собственные правила.<br />Твой следующий мир — здесь.</p>
          <button type="button" aria-label="Предыдущие избранные миры" onClick={() => setFeaturedOffset(previous => (previous + featuredWorlds.length - 1) % featuredWorlds.length)}><ChevronLeft aria-hidden="true" /></button>
          <button type="button" aria-label="Следующие избранные миры" onClick={() => setFeaturedOffset(previous => (previous + 1) % featuredWorlds.length)}><ChevronRight aria-hidden="true" /></button>
        </div>
      </div>
      <div className="cp-feature-grid">
        {selectedWorlds.map(item => <PlayWorldCard key={item.id} game={item} filters={filters}
          index={FEATURED_WORLD_IDS.indexOf(item.id as typeof FEATURED_WORLD_IDS[number])}
          featured favorite={collection.favorites.includes(item.id)} onFavorite={() => mutate(previous => toggleFavorite(previous, item.id))} />)}
      </div>
      <p className="cp-art-disclosure">Обложки — художественные иллюстрации миров. Графика и возможности каждой игры показаны при запуске.</p>
    </section>
  )
}
