import { cases } from './featuredCases.ts'
import { playGameTitles } from './playGameTitles.ts'
import { OSA_LESSON_SLUGS } from './osaLessonRegistry.ts'
import { lessonTitles } from './brandNavigation.ts'

/** Local, actionable destinations. No generated pages, fake results or account claims. */
export type OsgardCommand = Readonly<{
  id: string
  label: string
  description: string
  href: string
  group: 'Экосистема' | 'Знания' | 'Игры' | 'Проекты'
  keywords: string
}>

const baseCommands: readonly OsgardCommand[] = [
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

/** Four real portfolio pages, sourced from the case registry to avoid stale
 * marketing labels or invented statuses in the search experience. */
const caseCommands: readonly OsgardCommand[] = cases.map(item => ({
  id: 'case-' + item.id,
  label: item.name,
  description: item.type + ' · ' + item.category,
  href: item.href,
  group: 'Проекты',
  keywords: [item.id, item.name, item.category, 'кейс', 'портфолио', 'открыть'].join(' '),
}))
/** Direct links to all 19 games. The light breadcrumb registry provides only
 * confirmed game ids/titles; heavy Play content is still loaded on its route. */
const gameAliases: Readonly<Record<string, string>> = {
  'time': 'империя времени экономическая стратегия city управление городом',
  'empire-orbit': 'империя орбита космос стратегия',
  'vector-zero': 'магнит полярность импульс физика вектор зеро',
  'null-shift': 'рейд тактика ядро эвакуация нулл шифт',
  'inherit': 'наследие поколения семья sandbox',
  'remix': 'ремикс кооператив совместная игра',
  'swarm': 'рой swarm стратегия',
  'afterimage-run': 'раннер бег afterimage',
  'zion-030': 'добавь тень охлаждение дождевой сад климат город',
}

const gameCommands: readonly OsgardCommand[] = Object.entries(playGameTitles).map(([id, title]) => ({
  id: 'game-' + id,
  label: title,
  description: 'Игровой мир · сведения и варианты запуска',
  href: '/play/world/' + id,
  group: 'Игры',
  keywords: [id, title, gameAliases[id] || '', 'игра', 'игровой', 'мир', 'play', 'game'].join(' '),
}))

/** Eight real lesson routes from the single OSA slug and breadcrumb registries.
 * No invented completion status or server-side learning progress. */
const lessonCommands: readonly OsgardCommand[] = OSA_LESSON_SLUGS.map((slug, index) => ({
  id: 'lesson-' + slug,
  label: lessonTitles[slug],
  description: 'Урок ' + (index + 1) + ' из ' + OSA_LESSON_SLUGS.length + ' · материалы и задания',
  href: '/lectures/' + slug,
  group: 'Знания',
  keywords: [slug, lessonTitles[slug], 'урок', 'лекция', 'lesson', 'academy'].join(' '),
}))

export const osgardCommands: readonly OsgardCommand[] = [...baseCommands, ...caseCommands, ...gameCommands, ...lessonCommands]

const normalize = (value: string) => value.toLocaleLowerCase('ru-RU').replace(/ё/g, 'е').trim()

/** Recover a frequent keyboard-layout mistake, without calling a server or AI.
 * Example: "frfltvbz" typed on an English keyboard means "академия". */
const englishKeys = "qwertyuiop[]asdfghjkl;'zxcvbnm,."
const russianKeys = "йцукенгшщзхъфывапролджэячсмитьбю"
export function recoverRussianKeyboard(query: string): string {
  if (!/^[a-z\\[\\]\\;\\',.\\/\\s-]+$/i.test(query) || query.length > 100) return query
  return [...query.toLowerCase()].map(char => {
    const index = englishKeys.indexOf(char)
    return index < 0 ? char : russianKeys[index]
  }).join('')
}

/** Fully local deterministic command search. Only previously approved routes
 * can appear, and keyboard-layout recovery happens only on zero exact matches. */
export function searchOsgardCommands(query: string, recentlyOpened: readonly string[] = []): OsgardCommand[] {
  const makeWords = (value: string) => normalize(value).slice(0, 120).split(/\s+/).filter(Boolean)
  let words = makeWords(query)
  const find = (terms: readonly string[]) => osgardCommands.filter(command => {
    const text = normalize([command.label, command.description, command.group, command.keywords].join(' '))
    return terms.every(word => text.includes(word))
  })
  let matches = find(words)
  if (words.length && !matches.length) {
    const corrected = recoverRussianKeyboard(query)
    if (corrected !== query) {
      const correctedWords = makeWords(corrected)
      const recovered = find(correctedWords)
      if (recovered.length) { words = correctedWords; matches = recovered }
    }
  }
  if (words.length) {
    // A direct matching case should beat a generic portfolio link. All
    // results still come exclusively from the vetted, local route registry.
    const phrase = words.join(' ')
    const rank = (command: OsgardCommand) => {
      const label = normalize(command.label)
      if (label === phrase) return 0
      if (label.startsWith(phrase)) return 1
      return words.every(word => label.includes(word)) ? 2 : 3
    }
    return matches.sort((a, b) => rank(a) - rank(b))
  }
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
