/** Deterministic, offline-safe creator drafts. No AI inference and no network telemetry. */
export const CREATE_DRAFT_KEY = 'osgard:create-drafts:v1'
export const PROJECT_KINDS = {
  general: { label: 'Универсальный проект', tasks: ['Определить проблему и аудиторию', 'Согласовать критерии результата', 'Собрать первую версию', 'Проверить результат', 'Подготовить запуск', 'Измерить эффект'] },
  software: { label: 'Сайт или приложение', tasks: ['Описать пользовательский сценарий', 'Спроектировать структуру экранов', 'Создать рабочий прототип', 'Проверить интерфейс и доступность', 'Протестировать безопасность и данные', 'Подготовить безопасный релиз'] },
  business: { label: 'Бизнес или сервис', tasks: ['Проверить проблему клиентов', 'Определить ценность и предложение', 'Сделать минимальную услугу', 'Проверить стоимость и спрос', 'Настроить процесс обслуживания', 'Запустить ограниченный пилот'] },
  research: { label: 'Исследование', tasks: ['Поставить исследовательский вопрос', 'Определить метод и источники', 'Собрать факты и наблюдения', 'Проверить гипотезы', 'Документировать ограничения', 'Подготовить проверяемый вывод'] },
} as const
export type ProjectKind = keyof typeof PROJECT_KINDS
export type CreateDraft = {
  id: string
  title: string
  goal: string
  audience: string
  kind: ProjectKind
  tasks: string[]
  acceptance: string[]
  updatedAt: string
  serverProjectId?: string
}
const validId = (value: unknown) => typeof value === 'string' && /^[a-zA-Z0-9_-]{8,80}$/.test(value)
const validString = (value: unknown, max: number) => typeof value === 'string' && value.length <= max
const validItems = (value: unknown) => Array.isArray(value) && value.length <= 30 && value.every(item => validString(item, 500))

export function newCreateDraft(id: string, date = new Date().toISOString()): CreateDraft {
  return { id, title: '', goal: '', audience: '', kind: 'general', tasks: [...PROJECT_KINDS.general.tasks], acceptance: ['Результат решает обозначенную задачу', 'Основные сценарии проверены'], updatedAt: date }
}
export function parseCreateDrafts(raw: string | null): CreateDraft[] {
  if (!raw || raw.length > 150000) return []
  let parsed: unknown
  try { parsed = JSON.parse(raw) } catch { return [] }
  if (!Array.isArray(parsed)) return []
  const unique = new Set<string>()
  return parsed.filter((item): item is CreateDraft => {
    if (!item || typeof item !== 'object') return false
    const draft = item as CreateDraft
    if (!validId(draft.id) || unique.has(draft.id)) return false
    if (!validString(draft.title, 160) || !validString(draft.goal, 4000) || !validString(draft.audience, 1000)) return false
    if (!Object.prototype.hasOwnProperty.call(PROJECT_KINDS, draft.kind)) return false
    if (!validItems(draft.tasks) || !validItems(draft.acceptance)) return false
    if (draft.serverProjectId !== undefined && !(typeof draft.serverProjectId === 'string' && /^[a-f0-9]{32}$/.test(draft.serverProjectId))) return false
    if (typeof draft.updatedAt !== 'string' || !Number.isFinite(Date.parse(draft.updatedAt))) return false
    unique.add(draft.id)
    return true
  }).slice(0, 12).map(draft => ({
    id: draft.id, title: draft.title, goal: draft.goal, audience: draft.audience,
    kind: draft.kind, tasks: [...draft.tasks], acceptance: [...draft.acceptance],
    updatedAt: draft.updatedAt, ...(draft.serverProjectId ? { serverProjectId: draft.serverProjectId } : {}),
  }))
}
export function readCreateDrafts(): CreateDraft[] {
  try { return parseCreateDrafts(localStorage.getItem(CREATE_DRAFT_KEY)) } catch { return [] }
}
export function persistCreateDrafts(drafts: CreateDraft[]): boolean {
  try { localStorage.setItem(CREATE_DRAFT_KEY, JSON.stringify(drafts.slice(0, 12))); return true } catch { return false }
}
export function validateCreateDraft(draft: CreateDraft): string | null {
  if (draft.title.trim().length < 2) return 'Введите название проекта от 2 символов.'
  if (draft.goal.trim().length < 10) return 'Опишите измеримую цель хотя бы в 10 символах.'
  if (draft.tasks.length === 0 || draft.tasks.some(v => v.trim().length < 2)) return 'Добавьте хотя бы одну сформулированную задачу.'
  if (draft.acceptance.length === 0 || draft.acceptance.some(v => v.trim().length < 2)) return 'Укажите хотя бы один критерий готовности.'
  return null
}
export function createProjectPayload(draft: CreateDraft) {
  const error = validateCreateDraft(draft)
  if (error) throw new Error(error)
  return { title: draft.title.trim(), goal: draft.goal.trim(), audience: draft.audience.trim(), projectKind: draft.kind,
    tasks: draft.tasks.map(item => item.trim()), acceptance: draft.acceptance.map(item => item.trim()) }
}
