/** Source-of-truth helpers for the bilingual OSA Cinema companion.
 * This is a text-accessibility feature; it does not claim a produced film or recorded voice. */
export type CinemaCompanionLocale = 'ru' | 'en'
export type CinemaCompanionChoice = Readonly<{ label: string; result: string; insight: string }>
export type CinemaCompanionScene = Readonly<{
  act: number
  tag: string
  title: string
  body: string
  takeaway: string
  prompt?: string
  choices?: readonly CinemaCompanionChoice[]
}>

export function getCinemaScenePath(
  pathname: string,
  search: string,
  hash: string,
  locale: CinemaCompanionLocale,
  sceneIndex: number,
  sceneCount: number,
): string {
  if (!Number.isInteger(sceneIndex) || sceneIndex < 0 || sceneIndex >= sceneCount) {
    throw new RangeError('Scene index is outside the published course')
  }
  const url = new URL(pathname + search + hash, 'https://osa.local.invalid')
  url.searchParams.set('lang', locale)
  url.searchParams.set('scene', String(sceneIndex))
  return url.pathname + url.search + url.hash
}

/** Reject ambiguous or noncanonical chapter and locale links. */
export function readCinemaRoute(search: string, sceneCount: number): {
 sceneIndex: number | null
 locale: CinemaCompanionLocale | null
} {
 const params = new URLSearchParams(search)
 const sceneValues = params.getAll('scene')
 const langValues = params.getAll('lang')
 const raw = sceneValues.length === 1 ? sceneValues[0] : null
 const numeric = raw !== null && /^(?:0|[1-9][0-9]*)$/.test(raw) ? Number(raw) : NaN
 const sceneIndex = Number.isSafeInteger(numeric) && numeric >= 0 && numeric < sceneCount ? numeric : null
 const language = langValues.length === 1 ? langValues[0] : null
 const locale = language === 'ru' || language === 'en' ? language : null
 return { sceneIndex, locale }
}

export function searchCinemaScenes(
  scenes: readonly CinemaCompanionScene[],
  locale: CinemaCompanionLocale,
  query: string,
): number[] {
  const needle = query.normalize('NFKC').trim().toLocaleLowerCase(locale)
  return scenes.flatMap((scene, index) => {
    const fullText = [
      scene.tag, scene.title, scene.body, scene.takeaway, scene.prompt || '',
      ...(scene.choices || []).flatMap(choice => [choice.label, choice.result, choice.insight]),
    ].join(' ').normalize('NFKC').toLocaleLowerCase(locale)
    return !needle || fullText.includes(needle) ? [index] : []
  })
}

export function buildCinemaTranscript(
  scenes: readonly CinemaCompanionScene[],
  locale: CinemaCompanionLocale,
): string {
  const ru = locale === 'ru'
  const blocks = scenes.map((scene, index) => {
    const lines = [
      (ru ? 'СЦЕНА ' : 'SCENE ') + String(index + 1).padStart(2, '0') + ' / ' + String(scenes.length).padStart(2, '0'),
      scene.tag,
      scene.title,
      '',
      scene.body,
      '',
      (ru ? 'ГЛАВНАЯ МЫСЛЬ: ' : 'KEY INSIGHT: ') + scene.takeaway,
    ]
    if (scene.prompt && scene.choices?.length) {
      lines.push('', (ru ? 'ВОПРОС: ' : 'QUESTION: ') + scene.prompt)
      for (const [choiceIndex, choice] of scene.choices.entries()) {
        lines.push(
          String(choiceIndex + 1) + '. ' + choice.label,
          (ru ? '   РЕЗУЛЬТАТ: ' : '   RESULT: ') + choice.result,
          (ru ? '   ВЫВОД: ' : '   INSIGHT: ') + choice.insight,
        )
      }
    }
    return lines.join('\n')
  })
  return [
    'OSA CINEMA / BEYOND THE MODEL',
    ru ? 'Полный текст интерактивного курса — русский' : 'Full interactive course transcript — English',
    ru
      ? 'Это текстовая версия учебных сцен. Не является записью фильма или аудиодорожкой.'
      : 'This is the written version of the learning scenes, not a recorded movie or soundtrack.',
    '',
    blocks.join('\n\n' + '─'.repeat(42) + '\n\n'),
    '',
    ru ? 'Проверяйте первоисточники и применяйте рекомендации с учётом контекста.' : 'Verify original sources and apply guidance in context.',
    '',
  ].join('\n')
}
