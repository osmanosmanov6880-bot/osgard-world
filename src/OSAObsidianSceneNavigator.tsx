/**
 * OSA CINEMA / V43 — accessible mobile chapter navigator.
 * Chapter titles come from the existing, already published interactive story.
 * No new films, video sources, payment controls or entitlement claims.
 */
type Locale = 'ru' | 'en'
type Props = {
  locale: Locale
  currentIndex: number
  titles: readonly string[]
  onSelectScene: (sceneIndex: number) => void
}

export default function OSAObsidianSceneNavigator({locale, currentIndex, titles, onSelectScene}: Props) {
  if (titles.length === 0) return null
  const ru = locale === 'ru'
  const safeIndex = Math.max(0, Math.min(currentIndex, titles.length - 1))
  const selectScene = (scene: number) => {
    if (Number.isInteger(scene) && scene >= 0 && scene < titles.length && scene !== safeIndex) {
      onSelectScene(scene)
    }
  }

  return <nav className='osa43-mobile-nav' aria-label={ru ? 'Быстрый переход между сценами' : 'Quick scene navigation'}>
    <div className='osa43-mobile-counter' aria-live='polite'>
      <span>{String(safeIndex + 1).padStart(2, '0')} / {String(titles.length).padStart(2, '0')}</span>
      <small>{ru ? 'СЦЕНА' : 'SCENE'}</small>
    </div>
    <label className='osa43-mobile-select'>
      <span className='osa43-visually-hidden'>{ru ? 'Текущая сцена' : 'Current scene'}</span>
      <select value={safeIndex} onChange={event => selectScene(Number(event.currentTarget.value))} aria-label={ru ? 'Выбрать сцену истории' : 'Choose a story scene'}>
        {titles.map((title, index) => <option key={index} value={index}>{String(index + 1).padStart(2, '0')} — {title}</option>)}
      </select>
    </label>
    <button type='button' className='osa43-mobile-step' onClick={() => selectScene(safeIndex - 1)} disabled={safeIndex === 0} aria-label={ru ? 'Предыдущая глава' : 'Previous chapter'}>←</button>
    <button type='button' className='osa43-mobile-step' onClick={() => selectScene(safeIndex + 1)} disabled={safeIndex === titles.length - 1} aria-label={ru ? 'Следующая глава' : 'Next chapter'}>→</button>
  </nav>
}
