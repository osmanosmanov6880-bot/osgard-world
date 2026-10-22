import { ArrowUpRight, Bookmark } from './PlayIcons'
import type { CSSProperties } from 'react'
import type { PlayGame } from './redesignCatalog'
import type { PlayFilters } from './playFilters'
import { playWorldHref } from './playFilters'
import { gameArtwork } from './playCinematicData'

type Props = {
  game: PlayGame
  filters: PlayFilters
  index: number
  featured?: boolean
  favorite: boolean
  onFavorite: () => void
}

export default function PlayWorldCard({ game, filters, index, featured = false, favorite, onFavorite }: Props) {
  const art = gameArtwork(game)
  const href = playWorldHref(game.id, filters)
  return <article className={featured ? 'cp-world cp-featured-world' : 'play-card'}
    style={{ '--world-accent': game.accent } as CSSProperties} data-world-id={game.id}>
    <a className="play-card-art" href={href} aria-label={'Открыть мир ' + game.title}>
      <img src={art.src} srcSet={art.srcSet}
        sizes="(max-width: 600px) 92vw, (max-width: 1000px) 45vw, 30vw"
        alt={'Художественная иллюстрация мира ' + game.title}
        width="1536" height="1024" loading="lazy" decoding="async" />
    </a>
    <div className="cp-card-top">
      <span>{String(index + 1).padStart(2, '0')} <i>/</i> {game.genre}</span>
      <button type="button" className="cp-favorite" aria-pressed={favorite}
        aria-label={(favorite ? 'Убрать из избранного: ' : 'В избранное: ') + game.title}
        onClick={onFavorite}>
        <Bookmark size={17} fill={favorite ? 'currentColor' : 'none'} aria-hidden="true" />
      </button>
    </div>
    <div className="play-card-body">
      <span className="cp-card-format">{game.format}</span>
      <h3><a href={href}>{game.title}</a></h3>
      <p>{game.description}</p>
      <div className="play-card-actions">
        <span className={'cp-status' + (game.mode === 'service' ? ' cp-status-service' : '')}>
          <i aria-hidden="true" />{game.status}
        </span>
        <a className="cp-card-link" href={href}>Открыть мир <ArrowUpRight size={17} aria-hidden="true" /></a>
      </div>
    </div>
    <span className="cp-card-corner cp-card-corner-a" aria-hidden="true" />
    <span className="cp-card-corner cp-card-corner-b" aria-hidden="true" />
  </article>
}
