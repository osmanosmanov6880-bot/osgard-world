import type { PlayGame } from './redesignCatalog'

/** Artwork is concept illustration. Game IDs, launch targets and status stay in redesignCatalog. */
export const PLAY_ART_ROOT = '/brand/play/'
export const FEATURED_WORLD_IDS = ['vector-zero', 'time', 'null-shift', 'zion-030'] as const
export const PLAY_ART_LABEL = 'Художественная обложка'

export function gameArtwork(game: PlayGame) {
  return {
    src: PLAY_ART_ROOT + game.id + '.webp',
    srcSet: PLAY_ART_ROOT + game.id + '-640.webp 640w, ' + PLAY_ART_ROOT + game.id + '.webp 1536w',
    label: PLAY_ART_LABEL,
  }
}

