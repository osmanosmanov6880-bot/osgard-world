export type BrandArea = 'world' | 'intelligence' | 'play'
export type BrandBreadcrumb = { label: string; href?: string }

const normalize = (path: string) => path.replace(/\/+$/, '') || '/'
const belongsTo = (path: string, section: string) => path === section || path.startsWith(section + '/')

/** Product identity is independent of the quieter palette used on the partner page. */
export function brandAreaForPath(path: string, fallback: BrandArea = 'world'): BrandArea {
  const current = normalize(path)
  if (belongsTo(current, '/play') || belongsTo(current, '/games') || current === '/entertainment') return 'play'
  if (['/intelligence', '/academy', '/osa-cinema'].includes(current) || ['/learning', '/lectures', '/osa-library'].some(section => belongsTo(current, section))) return 'intelligence'
  return fallback
}

export function globalNavigationState(path: string, theme: BrandArea, href: string): 'page' | 'location' | undefined {
  const current = normalize(path)
  const area = brandAreaForPath(current, theme)
  if (current === href) return 'page'
  if (href === '/development' && belongsTo(current, '/development')) return 'location'
  if (href === '/' && area === 'world' && !belongsTo(current, '/development')) return 'location'
  if (href === '/intelligence' && area === 'intelligence') return 'location'
  if (href === '/play' && area === 'play') return 'location'
  return undefined
}

export const lessonTitles: Readonly<Record<string, string>> = {
  'intelligence-and-imitation': 'Интеллект и имитация',
  'how-language-models-work': 'Как работают языковые модели',
  'power-of-knowledge': 'Власть знаний',
  'signal-and-noise': 'Сигнал и шум',
  'verify-an-ai-answer': 'Проверьте ответ ИИ',
  'privacy-before-prompting': 'Приватность до запроса',
  'human-in-the-loop': 'Человек в контуре',
  'investigate-the-future': 'Исследуйте будущее',
}

const routeLabels: Record<string, string> = {
  '/teams': 'Команды', '/deliveries': 'Полученные материалы', '/purchases': 'Мои покупки', '/workspace/overview': 'Рабочий центр',
  '/account': 'Аккаунт и доступ', '/workspace': 'Рабочее пространство', '/data': 'Мои данные',
  '/learning/organizer': 'Организация пилота', '/learning/campus': 'Учебное пространство',
  '/learning/enrollment': 'Приобретённая программа',
  '/learning': 'Мой прогресс', '/learning/program': 'Практическая программа',
  '/learning/project': 'Редактор проекта', '/learning/workspace': 'Мастерская',
  '/learning/portfolio': 'Локальное портфолио', '/learning/experiments': 'Журнал экспериментов',
  '/learning/assessment': 'Самопроверка', '/learning/pricing': 'Форматы обучения',
  '/lectures': 'Лекции', '/academy': 'Академия', '/osa-cinema': 'OSA Original',
  '/osa-library': 'Медиатека и статусы материалов', '/quality': 'Состояние сборки',
  '/brand': 'Фирменная система', '/play/partners': 'Партнёрам',
  '/development/phantom': 'PHANTOM', '/development/tedes': 'TEDES',
  '/development/merakki': 'MERAKKI', '/development/essentia': 'ESSENTIA',
  '/games/time': 'Империя времени', '/games/time-empire': 'Империя времени',
}

/** The game title comes from the catalogue, so new worlds need no duplicate label map. */
export function brandBreadcrumbs(path: string, theme: BrandArea, gameTitle?: string): BrandBreadcrumb[] {
  const current = normalize(path)
  if (['/', '/portal', '/intelligence', '/play', '/entertainment', '/games', '/development'].includes(current)) return []
  const area = brandAreaForPath(current, theme)
  const items: BrandBreadcrumb[] = [{ label: 'OSGARD', href: '/' }]
  if (area === 'intelligence') items.push({ label: 'OSA Intelligence', href: '/intelligence' })
  if (area === 'play') items.push({ label: 'OSGARD PLAY', href: '/play' })
  if (current.startsWith('/development/')) items.push({ label: 'Development', href: '/development' })
  if (current.startsWith('/lectures/')) items.push({ label: 'Лекции', href: '/lectures' })
  if (current.startsWith('/learning/')) items.push({ label: 'Мой прогресс', href: '/learning' })
  const lesson = current.startsWith('/lectures/') ? lessonTitles[current.slice('/lectures/'.length)] : undefined
  const title = routeLabels[current] || lesson || (current.startsWith('/play/world/') ? gameTitle || 'Игровой мир' : 'Раздел экосистемы')
  return [...items, { label: title }]
}
