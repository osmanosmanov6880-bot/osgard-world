import { useMemo, useState } from 'react'
import './ecosystemIndex.css'

type Category = 'learn' | 'play' | 'build'
const filters: { id: 'all' | Category; label: string }[] = [
  { id: 'all', label: 'Все направления' },
  { id: 'learn', label: 'Изучать' },
  { id: 'play', label: 'Играть' },
  { id: 'build', label: 'Создавать' },
]

// Every href here points to an existing OSGARD page. These are destinations,
// not synthetic service health states, user counts or credential promises.
const destinations: {
  id: string; category: Category; label: string; title: string;
  description: string; href: string; action: string; image: string; search: string
}[] = [
  {
    id: 'intelligence', category: 'learn', label: '01 / ПРОВЕРКА ИИ',
    title: 'OSA Intelligence', description: 'Отмечайте утверждения, проверяйте их основания и изучайте источники.',
    href: '/intelligence', action: 'Проверить утверждения', image: '/brand/omega-osa.svg',
    search: 'оса интеллект доказательства источники nist проверить ответ artificial intelligence',
  },
  {
    id: 'academy', category: 'learn', label: '02 / ОБУЧЕНИЕ',
    title: 'OSA Academy', description: 'Восемь уроков, практические задания и прогресс на вашем устройстве.',
    href: '/academy', action: 'Открыть обучение', image: '/brand/omega-osa.svg',
    search: 'академия уроки практика progress обучение курс lesson',
  },
  {
    id: 'play', category: 'play', label: '03 / ИГРОВЫЕ МИРЫ',
    title: 'OSGARD Play', description: 'Полный игровой каталог: выбирайте мир и запускайте доступные игры.',
    href: '/play', action: 'Выбрать игру', image: '/brand/omega-play.svg',
    search: 'игры играть миры каталог game world play 19',
  },
  {
    id: 'archive', category: 'play', label: '04 / ИГРОВОЙ АРХИВ',
    title: 'Entertainment', description: 'Семь архивных игр с отдельными страницами на RU, EN и AR.',
    href: '/entertainment/archive/', action: 'Открыть архив', image: '/brand/world-time.svg',
    search: 'архив семь игры entertainment games ru en ar',
  },
  {
    id: 'development', category: 'build', label: '05 / ПОРТФОЛИО',
    title: 'Development', description: 'Реальные публичные кейсы: TEDES, PHANTOM, MERAKKI и ESSENTIA.',
    href: '/development', action: 'Посмотреть проекты', image: '/brand/omega-development.svg',
    search: 'разработка проекты tedес tedes phantom merakki essentia development',
  },
  {
    id: 'studio', category: 'build', label: '06 / ПРОЕКТНАЯ ПРАКТИКА',
    title: 'Project Studio', description: 'Составляйте учебный проект, оценивайте работу и сохраняйте результат в JSON.',
    href: '/learning/project', action: 'Начать проект', image: '/brand/omega-osa.svg',
    search: 'студия проект практикум json export import project studio учебный',
  },
]

export default function OsgardEcosystemIndex() {
  const [active, setActive] = useState<'all' | Category>('all')
  const [query, setQuery] = useState('')
  const items = useMemo(() => {
    const term = query.trim().toLocaleLowerCase('ru')
    return destinations.filter(item =>
      (active === 'all' || item.category === active) &&
      (!term || [item.title, item.description, item.label, item.search]
        .some(value => value.toLocaleLowerCase('ru').includes(term))),
    )
  }, [active, query])
  return <section id="ecosystem" className="brand-section ecosystem-index" aria-labelledby="ecosystem-index-title">
    <div className="ecosystem-index-heading">
      <div>
        <p className="brand-eyebrow">OSGARD / ЭКОСИСТЕМА</p>
        <h2 id="ecosystem-index-title">Найдите то,<br /><span>что вам нужно.</span></h2>
        <p>Проверить ответ ИИ, пройти урок, запустить игру или открыть проект — выберите действие и попробуйте сами.</p>
      </div>
      <a href="/quality" className="ecosystem-index-quality">Что действительно работает? <span aria-hidden="true">↗</span></a>
    </div>
    <div className="ecosystem-index-controls">
      <div className="ecosystem-index-tabs" role="group" aria-label="Фильтр направлений">
        {filters.map(filter => <button key={filter.id} type="button"
          aria-pressed={filter.id === active} onClick={() => setActive(filter.id)}>{filter.label}</button>)}
      </div>
      <label className="ecosystem-index-search">
        <span>Поиск по экосистеме</span>
        <input type="search" value={query} onChange={event => setQuery(event.target.value)}
          placeholder="Например: уроки, игры, TEDES…" autoComplete="off" />
      </label>
    </div>
    <p className="ecosystem-index-count" role="status" aria-live="polite">
      Показано направлений: {items.length} из {destinations.length}
    </p>
    {items.length > 0
      ? <div className="ecosystem-index-grid">
          {items.map(item => <a className={'ecosystem-index-card is-' + item.category}
            href={item.href} key={item.id} aria-label={item.title + '. ' + item.action}>
            <div className="ecosystem-index-art" aria-hidden="true">
              <img src={item.image} alt="" width="960" height="600" loading="lazy" decoding="async" />
            </div>
            <div className="ecosystem-index-content">
              <small>{item.label}</small>
              <h3>{item.title}</h3>
              <p>{item.description}</p>
              <span>{item.action} <b aria-hidden="true">↗</b></span>
            </div>
          </a>)}
        </div>
      : <div className="ecosystem-index-empty">
          <p>По этому запросу ничего не найдено. Попробуйте другое слово или покажите все направления.</p>
          <button type="button" onClick={() => { setQuery(''); setActive('all') }}>Показать все</button>
        </div>}
    <p className="ecosystem-index-note">Демо и локальные проекты доступны без регистрации. Серверные функции, мультиплеер и коммерческие статусы проверяются отдельно.</p>
  </section>
}
