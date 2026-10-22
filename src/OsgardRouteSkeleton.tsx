import type { ProductTheme } from './BrandMark'
import './osgardRouteSkeleton.css'

/** Real loading state for deferred route bundles. No mock metrics or fake actions. */
export default function OsgardRouteSkeleton({ theme, path }: { theme: ProductTheme; path: string }) {
  const area = path === '/development' || path.startsWith('/development/') ? 'development'
    : path === '/academy' ? 'academy'
    : path.startsWith('/lectures') ? 'lectures'
    : path === '/entertainment' ? 'entertainment'
    : theme
  const labels = {
    world: ['OSGARD WORLD', 'Подготавливаем цифровую вселенную…'],
    intelligence: ['OSA INTELLIGENCE', 'Загружаем инструменты проверки и обучения…'],
    play: ['OSGARD PLAY', 'Открываем игровые миры…'],
    development: ['OSGARD DEVELOPMENT', 'Подготавливаем проекты и их демонстрации…'],
    academy: ['OSA ACADEMY', 'Открываем уроки и ваш прогресс…'],
    lectures: ['OSA LECTURES', 'Загружаем материалы уроков…'],
    entertainment: ['OSGARD PLAY', 'Загружаем каталог игровых миров…'],
  } as const
  const [name, description] = labels[area]
  return <main className="osgard-route-skeleton" data-skeleton-theme={theme} data-skeleton-area={area} role="status"
    aria-live="polite" aria-busy="true" aria-label={description}>
    <div className="osgard-skeleton-ambient" aria-hidden="true" />
    <div className="osgard-skeleton-copy">
      <p className="osgard-skeleton-eyebrow">{name} <span>/ ЗАГРУЗКА</span></p>
      <h2>{description}</h2>
      <p>Экран откроется после загрузки необходимых файлов.</p>
      <div className="osgard-skeleton-actions" aria-hidden="true">
        <span /><span />
      </div>
      <div className="osgard-skeleton-bars" aria-hidden="true">
        <span /><span /><span />
      </div>
    </div>
    <div className="osgard-skeleton-art" aria-hidden="true">
      <div className="osgard-skeleton-ring"><span /></div>
      <div className="osgard-skeleton-grid"><span /><span /><span /></div>
    </div>
  </main>
}
