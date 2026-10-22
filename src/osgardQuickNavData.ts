/** Local, actionable destinations. No generated pages, fake results or account claims. */
export type OsgardCommand = Readonly<{
  id: string
  label: string
  description: string
  href: string
  group: 'Экосистема' | 'Знания' | 'Игры' | 'Проекты'
  keywords: string
}>

export const osgardCommands: readonly OsgardCommand[] = [
  { id: 'world', label: 'OSGARD World', description: 'Главная страница и направления экосистемы', href: '/', group: 'Экосистема', keywords: 'главная дом земля globe home portal' },
  { id: 'intelligence', label: 'OSA Intelligence', description: 'Практика проверки утверждений и источников', href: '/intelligence', group: 'Знания', keywords: 'ии ai интеллект доказательства evidence nist проверка ответы' },
  { id: 'academy', label: 'Академия OSA', description: 'Учебный кабинет и мой прогресс', href: '/academy', group: 'Знания', keywords: 'академия обучение academy cockpit прогресс' },
  { id: 'lectures', label: 'Восемь уроков', description: 'Каталог настоящих материалов OSA', href: '/lectures', group: 'Знания', keywords: 'уроки лекции lessons lectures знания' },
  { id: 'cinema', label: 'OSA Original', description: 'Интерактивный курс и задания', href: '/osa-cinema', group: 'Знания', keywords: 'кино курс cinema упражнение самопроверка' },
  { id: 'progress', label: 'Мой учебный маршрут', description: 'Прогресс, сохраняемый в этом браузере', href: '/learning', group: 'Знания', keywords: 'результаты статус progress learning прогресс' },
  { id: 'play', label: 'OSGARD Play', description: 'Полный каталог игровых миров', href: '/play', group: 'Игры', keywords: 'игры play world game миры каталог' },
  { id: 'favorites', label: 'Избранные игры', description: 'Сохранённые игровые миры', href: '/play?view=favorites#catalog', group: 'Игры', keywords: 'избранное favorites любимые' },
  { id: 'recent-games', label: 'Недавние игры', description: 'Ранее открытые миры', href: '/play?view=recent#catalog', group: 'Игры', keywords: 'недавние история recent games' },
  { id: 'game-archive', label: 'Архив семи игр', description: 'Классические миры Entertainment', href: '/entertainment/archive/', group: 'Игры', keywords: 'entertainment архив семь 7 old legacy' },
  { id: 'development', label: 'Development', description: 'Разработка цифровых продуктов', href: '/development', group: 'Проекты', keywords: 'разработка студия development portfolio' },
  { id: 'cases', label: 'Портфолио проектов', description: 'TEDES, PHANTOM, MERAKKI и ESSENTIA', href: '/development#cases', group: 'Проекты', keywords: 'кейсы cases portfolio проекты tedes phantom merakki essentia' },
]

const normalize = (value: string) => value.toLocaleLowerCase('ru-RU').replace(/ё/g, 'е').trim()

/** A stable, tiny command search; aliases are authored rather than hallucinated. */
export function searchOsgardCommands(query: string, recentlyOpened: readonly string[] = []): OsgardCommand[] {
  const words = normalize(query).split(/\s+/).filter(Boolean)
  const matches = osgardCommands.filter(command => {
    const text = normalize([command.label, command.description, command.group, command.keywords].join(' '))
    return words.every(word => text.includes(word))
  })
  if (words.length) return matches
  const score = (id: string) => recentlyOpened.indexOf(id)
  return matches.sort((a, b) => {
    const aIndex = score(a.id), bIndex = score(b.id)
    if (aIndex < 0 && bIndex < 0) return 0
    if (aIndex < 0) return 1
    if (bIndex < 0) return -1
    return aIndex - bIndex
  })
}

const recentKey = 'osgard:quick-nav:session'

/** Per-tab navigation shortcuts, not a persistent browsing history or analytics feed. */
export function readQuickNavRecent(): string[] {
  try {
    const value: unknown = JSON.parse(sessionStorage.getItem(recentKey) || '[]')
    if (!Array.isArray(value)) return []
    return [...new Set(value.filter((id): id is string => typeof id === 'string' && osgardCommands.some(command => command.id === id)))].slice(0, 5)
  } catch { return [] }
}
export function rememberQuickNav(id: string): string[] {
  const next = [id, ...readQuickNavRecent().filter(old => old !== id)].slice(0, 5)
  try { sessionStorage.setItem(recentKey, JSON.stringify(next)) } catch { /* Private mode still supports the dialog. */ }
  return next
}
export function clearQuickNavRecent(): void {
  try { sessionStorage.removeItem(recentKey) } catch { /* Keep the UI usable. */ }
}
