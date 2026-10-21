import { useEffect, useRef, useState } from 'react'
import { ArrowRight, ArrowUpRight, Bookmark, Orbit, Search, ShieldCheck, Sparkles, Waypoints, X, Zap } from './PlayIcons'
import { getPlayGame, playGames } from './redesignCatalog'
import type { PlayCollection } from './playCollection'
import { playWorldHref } from './playFilters'
import type { PlayFilters } from './playFilters'
import { FEATURED_WORLD_IDS, PLAY_ART_ROOT, gameArtwork } from './playCinematicData'
import PlayWorldCard from './PlayWorldCard'
import { magnet, resetMagnet } from './playButtonMotion'

const genres = [...new Set(playGames.map(game => game.genre))]
const featuredWorlds = FEATURED_WORLD_IDS.map(id => getPlayGame(id)).filter(game => game !== undefined)

const worldStories: Record<string, { eyebrow: string; title: string; text: string; mechanic: string }> = {
  'vector-zero': {
    eyebrow: '01 / ФИЗИКА ПОД ТВОИМ КОНТРОЛЕМ',
    title: 'Смени полярность. Найди свой путь.',
    text: 'Магнитное поле становится инструментом. Направь ядро к приёмнику, используй импульс и пройди через арену к выходу.',
    mechanic: 'Полярность · импульс · один уровень',
  },
  time: {
    eyebrow: '02 / КАЖДОЕ РЕШЕНИЕ МЕНЯЕТ ГОРОД',
    title: 'У твоей империи есть следующий ход.',
    text: 'Казна, энергия, районы и фракции связаны между собой. Выбирай действия и наблюдай, как город отвечает на твои решения.',
    mechanic: 'Ресурсы · районы · пошаговая стратегия',
  },
  'null-shift': {
    eyebrow: '03 / ОДИН РЕЙД. ТВОЯ ТАКТИКА.',
    title: 'Доберись до ядра. Вернись обратно.',
    text: 'Терминалы, охрана и путь к эвакуации. Изучи управление, выбери подход и пройди тактическую миссию NULL//SHIFT.',
    mechanic: 'Терминалы · квантовое ядро · эвакуация',
  },
  'zion-030': {
    eyebrow: '04 / ТЕНЕВОЙ ПРОТОКОЛ',
    title: 'Добавь тень. Измени город.',
    text: 'Три горячие точки и три решения. Размести дерево, навес и дождевой сад так, чтобы охладить квартал.',
    mechanic: 'Пространственная головоломка · 3D / облегчённое поле',
  },
}

type Props = {
  filters: PlayFilters
  onFiltersChange: (filters: PlayFilters) => void
  collection: PlayCollection
  message: string
  onFavorite: (id: string) => boolean
  onReady: () => void
}

export default function PlayExploreSections({ filters, onFiltersChange, collection, message, onFavorite, onReady }: Props) {
  const catalogSearch = useRef<HTMLInputElement>(null)
  const [storyId, setStoryId] = useState('zion-030')
  const { query, genre, mode, view } = filters
  const setQuery = (query: string) => onFiltersChange({ ...filters, query })
  const setGenre = (genre: string) => onFiltersChange({ ...filters, genre })
  const setMode = (mode: PlayFilters['mode']) => onFiltersChange({ ...filters, mode })
  const setView = (view: PlayFilters['view']) => onFiltersChange({ ...filters, view })
  useEffect(onReady, [onReady])
  const clearFilters = () => {
    onFiltersChange({ query: '', genre: 'all', mode: 'all', view: 'all' })
    catalogSearch.current?.focus()
  }
  const filtered = playGames.filter(item => [item.id, item.title, item.searchTerms, item.description, item.format, worldStories[item.id]?.title || '']
    .join(' ').toLocaleLowerCase('ru').includes(query.trim().toLocaleLowerCase('ru')) &&
    (genre === 'all' || item.genre === genre) &&
    (mode === 'all' || item.mode === mode) &&
    (view === 'all' || (view === 'favorites' ? collection.favorites : collection.recent).includes(item.id)))
  if (view === 'recent') filtered.sort((a, b) => collection.recent.indexOf(a.id) - collection.recent.indexOf(b.id))
  const activeFilters = Boolean(query || genre !== 'all' || mode !== 'all' || view !== 'all')
  const storyGame = getPlayGame(storyId) || featuredWorlds[0]
  const story = worldStories[storyGame.id]
  const storyArt = gameArtwork(storyGame)

  return <>
    <section id="experience" className="cp-section cp-container cp-experience" aria-labelledby="experience-title" data-reveal>
      <p className="cp-eyebrow">ВОЗМОЖНОСТИ</p>
      <h2 id="experience-title">БОЛЬШЕ, ЧЕМ НАБЛЮДАТЬ. <span>ТВОЁ ДЕЙСТВИЕ.</span></h2>
      <div className="cp-experience-grid">
        <a href={playWorldHref('vector-zero', filters)}><Zap aria-hidden="true" /><span><strong>Управляй физикой</strong><small>Полярность, импульс и движение в VECTOR//ZERO.</small></span><ArrowUpRight aria-hidden="true" /></a>
        <a href={playWorldHref('time', filters)}><Waypoints aria-hidden="true" /><span><strong>Принимай решения</strong><small>Ресурсы, районы и следующий такт твоей империи.</small></span><ArrowUpRight aria-hidden="true" /></a>
        <a href={playWorldHref('inherit', filters)}><Sparkles aria-hidden="true" /><span><strong>Создавай свой мир</strong><small>Деревья, свет и следы локальных поколений INHERIT.</small></span><ArrowUpRight aria-hidden="true" /></a>
        <a href="/play?view=favorites#catalog"><Bookmark aria-hidden="true" /><span><strong>Собирай коллекцию</strong><small>Сохраняй любимые миры и возвращайся к ним.</small></span><ArrowUpRight aria-hidden="true" /></a>
      </div>
    </section>

    <section id="discover" className="cp-discover cp-container" aria-labelledby="discover-title" data-reveal>
      <div className="cp-discover-art">
        <img key={storyGame.id} src={storyArt.src} srcSet={storyArt.srcSet} sizes="(max-width: 760px) 100vw, 55vw"
          alt={'Художественная иллюстрация: ' + storyGame.title} width="1536" height="1024" loading="lazy" decoding="async" />
        <span>{storyArt.label}</span>
      </div>
      <div className="cp-discover-copy">
        <p className="cp-eyebrow">БЛИЖЕ К МИРУ</p>
        <div className="cp-story-selector" role="group" aria-label="Выбрать мир для знакомства">
          {featuredWorlds.map((item, index) => <button key={item.id} type="button" aria-label={item.title}
            aria-pressed={storyId === item.id} onClick={() => setStoryId(item.id)}>{String(index + 1).padStart(2, '0')}</button>)}
        </div>
        <span className="cp-story-kicker">{story.eyebrow}</span>
        <h2 id="discover-title">{story.title}</h2>
        <p>{story.text}</p>
        <span className="cp-mechanic">{story.mechanic}</span>
        <a className="cp-button" href={playWorldHref(storyGame.id, filters)}>Открыть {storyGame.title} <ArrowUpRight size={19} aria-hidden="true" /></a>
        <small className="cp-story-state">{storyGame.status} · {storyGame.save}</small>
      </div>
    </section>

    <section id="catalog" className="cp-section cp-container cp-catalog" aria-labelledby="catalog-title">
      <div className="cp-section-top"><div><p className="cp-eyebrow">КООРДИНАТЫ ТВОЕГО СЛЕДУЮЩЕГО МИРА</p><h2 id="catalog-title">ВСЯ ВСЕЛЕННАЯ. <span>ТВОЙ ВЫБОР.</span></h2></div>
        <a className="cp-back-top" href="#play-title">К началу <ArrowUpRight size={16} aria-hidden="true" /></a>
      </div>
      <div className="cp-catalog-toolbar">
        <div className="cp-collection-tabs" role="group" aria-label="Моя коллекция">
          <button type="button" aria-pressed={view === 'all'} onClick={() => setView('all')}>Все миры <span>{playGames.length}</span></button>
          <button type="button" aria-pressed={view === 'favorites'} onClick={() => setView('favorites')}><Bookmark size={15} aria-hidden="true" /> Избранное <span>{collection.favorites.length}</span></button>
          <button type="button" aria-pressed={view === 'recent'} onClick={() => setView('recent')}>Недавние <span>{collection.recent.length}</span></button>
        </div>
        <p>Коллекция хранится в этом браузере</p>
      </div>
      <div className="cp-filters">
        <label className="cp-search-label" htmlFor="play-search">Найти свой мир
          <span><Search size={18} aria-hidden="true" /><input ref={catalogSearch} id="play-search" type="search" value={query} maxLength={80}
            placeholder="Название, механика или настроение" onChange={event => setQuery(event.target.value)} /></span>
        </label>
        <label htmlFor="play-genre">Жанр<select id="play-genre" value={genre} onChange={event => setGenre(event.target.value)}><option value="all">Все жанры</option>{genres.map(item => <option key={item}>{item}</option>)}</select></label>
        <label htmlFor="play-mode">Доступность<select id="play-mode" value={mode} onChange={event => setMode(event.target.value as typeof mode)}>
          <option value="all">Все форматы</option><option value="solo">Одиночный доступ</option><option value="service">Нужен игровой сервис</option>
        </select></label>
      </div>
      <div className="cp-results"><span role="status" aria-live="polite" aria-atomic="true">Найдено миров: {filtered.length} из {playGames.length}</span>
        {activeFilters && <button type="button" onClick={clearFilters}><X size={14} aria-hidden="true" /> Сбросить фильтры</button>}
      </div>
      {filtered.length === 0 ? <div className="cp-empty"><Orbit size={48} aria-hidden="true" /><h3>Пока ни одного мира.</h3>
        <p>{view === 'favorites' ? 'Нажми значок закладки на карточке — мир появится в твоей коллекции.' : view === 'recent' ? 'Открой страницу игры — она появится здесь.' : 'Попробуй другое название или сбрось фильтры.'}</p>
        <button type="button" className="cp-button" onClick={clearFilters}>Показать все миры <ArrowRight size={17} aria-hidden="true" /></button>
      </div> : <div className="play-grid">
        {filtered.map((item, index) => <PlayWorldCard key={item.id} game={item} filters={filters} index={index}
          favorite={collection.favorites.includes(item.id)}
          onFavorite={() => { if (onFavorite(item.id) && view === 'favorites') catalogSearch.current?.focus() }} />)}
      </div>}
      <p className="cp-collection-feedback" role="status">{message}</p>
    </section>

    <section id="guest-access" className="cp-guest cp-container" aria-labelledby="guest-title" data-reveal>
      <ShieldCheck size={37} aria-hidden="true" />
      <div><p className="cp-eyebrow">ЗНАКОМСТВО НАЧИНАЕТСЯ С ИГРЫ</p><h2 id="guest-title">Заходи. Выбирай. Пробуй.</h2>
        <p>Каталог, описания и общедоступные прототипы открыты без регистрации. Управление, сохранения и требования к сервису указаны на странице каждой игры. Избранное остаётся на этом устройстве.</p></div>
      <a className="cp-button" href="/play/partners">Для брендов и команд <ArrowUpRight size={18} aria-hidden="true" /></a>
    </section>

    <section className="cp-final" aria-labelledby="final-title" data-reveal>
      <picture aria-hidden="true"><source media="(max-width: 600px)" srcSet={PLAY_ART_ROOT + 'hero-mobile-780.webp'} />
        <img src={PLAY_ART_ROOT + 'panorama-discover.webp'}
          srcSet={PLAY_ART_ROOT + 'panorama-discover-1280.webp 1280w, ' + PLAY_ART_ROOT + 'panorama-discover-1920.webp 1920w, ' + PLAY_ART_ROOT + 'panorama-discover.webp 1983w'}
          sizes="100vw" alt="" width="1983" height="793" loading="lazy" decoding="async" /></picture>
      <div className="cp-final-copy"><p className="cp-eyebrow">OSGARD PLAY</p><h2 id="final-title">ТВОИ МИРЫ <span>ЖДУТ.</span></h2>
        <p>ОДНА ВСЕЛЕННАЯ. ТВОЯ СЛЕДУЮЩАЯ ИСТОРИЯ.</p>
        <a className="cp-button cp-button-primary" href="#catalog" onPointerMove={magnet} onPointerLeave={resetMagnet}>Погрузиться в OSGARD Play <ArrowUpRight size={20} aria-hidden="true" /></a>
      </div>
    </section>
  </>
}
