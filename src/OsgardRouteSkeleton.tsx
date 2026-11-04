import { BrandLockup, type ProductTheme } from './BrandMark'
import './osgardRouteSkeleton.css'

/** Branded, lightweight loading state for deferred route bundles. */
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
  const markTheme: ProductTheme = area === 'intelligence' || area === 'academy' || area === 'lectures' ? 'intelligence'
    : area === 'play' || area === 'entertainment' ? 'play' : 'world'

  return <main className="osgard-route-skeleton" data-skeleton-theme={markTheme} data-skeleton-area={area}
    role="status" aria-live="polite" aria-busy="true" aria-label={description}>
    <div className="osgard-loader-glow" aria-hidden="true" />
    <div className="osgard-loader-lockup"><BrandLockup theme={markTheme} /></div>
    <p className="osgard-loader-caption">{name}</p>
    <p className="osgard-loader-description">{description}</p>
    <div className="osgard-loader-track" aria-hidden="true"><i /></div>
  </main>
}
