import { useEffect, useMemo, useRef, useState } from 'react'
import { BookOpen, ChevronRight, Download, Link2, Pause, Play, Search } from 'lucide-react'
import {
  buildCinemaTranscript,
  getCinemaScenePath,
  searchCinemaScenes,
  type CinemaCompanionLocale,
  type CinemaCompanionScene,
} from './osaCinemaCompanionText'
import './osaCinemaCompanion.css'

type Props = {
  locale: CinemaCompanionLocale
  currentIndex: number
  scenes: readonly CinemaCompanionScene[]
  onSelectScene: (index: number) => void
}

export default function OSACinemaCompanion({ locale, currentIndex, scenes, onSelectScene }: Props) {
  const [scriptOpen, setScriptOpen] = useState(false)
  const [query, setQuery] = useState('')
  const [feedback, setFeedback] = useState('')
  const [manualLink, setManualLink] = useState('')
  const [canSpeak, setCanSpeak] = useState(false)
  const [speaking, setSpeaking] = useState(false)
  const spokenRef = useRef<SpeechSynthesisUtterance | null>(null)
  const scene = scenes[currentIndex]
  const results = useMemo(() => searchCinemaScenes(scenes, locale, query), [scenes, locale, query])
  const ru = locale === 'ru'
  const copy = ru
    ? {
        eyebrow: 'OSA ORIGINALS / РЕЖИМ ИССЛЕДОВАНИЯ', title: 'Все восемь сцен. Один маршрут.',
        desc: 'Найдите нужную мысль, вернитесь к главе или сохраните полный сценарий. Ваши решения и прогресс остаются на устройстве.',
        script: 'Открыть полный сценарий', close: 'Свернуть сценарий', voice: 'Слушать текст сцены',
        stop: 'Остановить чтение', link: 'Ссылка на сцену', download: 'Сохранить текст',
        search: 'Поиск по сценам', placeholder: 'Например: источники, данные, решение',
        count: 'из 8 сцен', noResults: 'Ничего не найдено. Попробуйте другое слово.',
        jump: 'Перейти к сцене', insight: 'Главная мысль', question: 'Вопрос для размышления',
        copied: 'Ссылка скопирована', manual: 'Не удалось скопировать автоматически. Выделите адрес ниже.',
        saved: 'Текст курса подготовлен для сохранения', voiceError: 'Системное озвучивание недоступно. Текст остаётся на экране.',
        disclosure: 'Читает системный голос устройства, если он доступен. Записанная аудио- и видеоверсия фильма ещё не опубликована.',
      }
    : {
        eyebrow: 'OSA ORIGINALS / EXPLORATION MODE', title: 'Eight scenes. One journey.',
        desc: 'Find a key idea, return to any chapter, or save the complete transcript. Your decisions and progress remain on your device.',
        script: 'Open full transcript', close: 'Close transcript', voice: 'Read this scene aloud',
        stop: 'Stop reading', link: 'Share scene link', download: 'Save transcript',
        search: 'Search the scenes', placeholder: 'For example: sources, data, decision',
        count: 'of 8 scenes', noResults: 'No matches. Try a different keyword.',
        jump: 'Go to scene', insight: 'Key insight', question: 'Question to consider',
        copied: 'Scene link copied', manual: 'Automatic copying is unavailable. Select the address below.',
        saved: 'The transcript is ready for download', voiceError: 'Device speech is unavailable. The text remains available.',
        disclosure: 'Uses your device’s synthetic voice where available. Recorded movie audio and video have not yet been released.',
      }

  useEffect(() => {
    setCanSpeak(typeof window !== 'undefined' && 'speechSynthesis' in window && 'SpeechSynthesisUtterance' in window)
    return () => {
      if (spokenRef.current && 'speechSynthesis' in window) window.speechSynthesis.cancel()
      spokenRef.current = null
    }
  }, [])

  useEffect(() => {
    if (spokenRef.current && 'speechSynthesis' in window) {
      window.speechSynthesis.cancel()
      spokenRef.current = null
    }
    setSpeaking(false)
  }, [locale, currentIndex])

  const toggleSpeech = () => {
    if (!canSpeak || !scene) return
    if (spokenRef.current) {
      window.speechSynthesis.cancel()
      spokenRef.current = null
      setSpeaking(false)
      return
    }
    try {
      const utterance = new SpeechSynthesisUtterance([scene.title, scene.body, scene.takeaway].join('. '))
      utterance.lang = ru ? 'ru-RU' : 'en-US'
      utterance.rate = 0.95
      utterance.onend = () => { if (spokenRef.current === utterance) { spokenRef.current = null; setSpeaking(false) } }
      utterance.onerror = () => {
        if (spokenRef.current === utterance) { spokenRef.current = null; setSpeaking(false); setFeedback(copy.voiceError) }
      }
      spokenRef.current = utterance
      setFeedback('')
      setSpeaking(true)
      window.speechSynthesis.cancel()
      window.speechSynthesis.speak(utterance)
    } catch {
      spokenRef.current = null
      setSpeaking(false)
      setFeedback(copy.voiceError)
    }
  }

  const sceneLink = () => {
    const path = getCinemaScenePath(
      window.location.pathname,
      window.location.search,
      window.location.hash,
      locale,
      currentIndex,
      scenes.length,
    )
    return window.location.origin + path
  }

  const shareScene = async () => {
    const address = sceneLink()
    try {
      if (!navigator.clipboard?.writeText) throw new Error('Clipboard unavailable')
      await navigator.clipboard.writeText(address)
      setManualLink('')
      setFeedback(copy.copied)
    } catch {
      setManualLink(address)
      setFeedback(copy.manual)
    }
  }

  const saveTranscript = () => {
    const text = buildCinemaTranscript(scenes, locale)
    const url = URL.createObjectURL(new Blob([text], { type: 'text/plain;charset=utf-8' }))
    const link = document.createElement('a')
    link.href = url
    link.download = 'osa-cinema-transcript-' + locale + '.txt'
    document.body.appendChild(link)
    link.click()
    link.remove()
    window.setTimeout(() => URL.revokeObjectURL(url), 2000)
    setFeedback(copy.saved)
  }

  const select = (index: number) => {
    onSelectScene(index)
    setFeedback('')
    setManualLink('')
  }

  return <section className='cinema-companion' aria-labelledby='cinema-companion-title' data-testid='cinema-companion'>
    <div className='cinema-companion__intro'>
      <p className='cinema-companion__eyebrow'>{copy.eyebrow}</p>
      <h2 id='cinema-companion-title'>{copy.title}</h2>
      <p className='cinema-companion__description'>{copy.desc}</p>
      <div className='cinema-companion__actions'>
        <button type='button' onClick={() => setScriptOpen(open => !open)}
          aria-expanded={scriptOpen} aria-controls='cinema-companion-transcript'>
          <BookOpen size={17} aria-hidden='true' />{scriptOpen ? copy.close : copy.script}
        </button>
        {canSpeak && <button type='button' onClick={toggleSpeech} aria-pressed={speaking}
          aria-label={speaking ? copy.stop : copy.voice}>
          {speaking ? <Pause size={17} aria-hidden='true' /> : <Play size={17} aria-hidden='true' />}
          {speaking ? copy.stop : copy.voice}
        </button>}
        <button type='button' onClick={shareScene}><Link2 size={17} aria-hidden='true' />{copy.link}</button>
        <button type='button' onClick={saveTranscript}><Download size={17} aria-hidden='true' />{copy.download}</button>
      </div>
      <p className='cinema-companion__disclosure'>{copy.disclosure}</p>
      <p className='cinema-companion__feedback' role='status' aria-live='polite'>{feedback}</p>
      {manualLink && <input className='cinema-companion__manual' readOnly aria-label={copy.link}
        value={manualLink} onFocus={event => event.currentTarget.select()} onClick={event => event.currentTarget.select()} />}
    </div>

    <nav className='cinema-companion__rail' aria-label={ru ? 'Список сцен' : 'Scene index'}>
      {scenes.map((item, index) =>
        <button key={locale + index} type='button' className={index === currentIndex ? 'active' : ''}
          onClick={() => select(index)} aria-current={index === currentIndex ? 'step' : undefined}
          aria-label={(ru ? 'Сцена ' : 'Scene ') + (index + 1) + ': ' + item.title}>
          <span>{String(index + 1).padStart(2, '0')}</span>
          <strong>{item.tag}</strong>
          <ChevronRight size={15} aria-hidden='true' />
        </button>)}
    </nav>

    <div id='cinema-companion-transcript' className='cinema-companion__transcript' hidden={!scriptOpen}>
      <label htmlFor='cinema-companion-search'><Search size={16} aria-hidden='true' />{copy.search}</label>
      <input id='cinema-companion-search' type='search' value={query}
        onChange={event => setQuery(event.target.value)} placeholder={copy.placeholder} autoComplete='off' />
      <p className='cinema-companion__counter' role='status'>{results.length} {copy.count}</p>
      {results.length === 0 && <p className='cinema-companion__empty'>{copy.noResults}</p>}
      <div className='cinema-companion__results'>
        {results.map(index => {
          const item = scenes[index]
          return <article className='cinema-companion__chapter' key={locale + index}>
            <div className='cinema-companion__chapter-head'>
              <span>{String(index + 1).padStart(2, '0')} / {String(scenes.length).padStart(2, '0')}</span>
              <span>{item.tag}</span>
            </div>
            <h3>{item.title}</h3>
            <p>{item.body}</p>
            <p className='cinema-companion__insight'><strong>{copy.insight}</strong>{item.takeaway}</p>
            {item.prompt && <p className='cinema-companion__question'><strong>{copy.question}</strong>{item.prompt}</p>}
            <button type='button' className='cinema-companion__jump' onClick={() => select(index)}>
              {copy.jump}<ChevronRight size={15} aria-hidden='true'/>
            </button>
          </article>
        })}
      </div>
    </div>
  </section>
}
