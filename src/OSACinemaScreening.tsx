import { useEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import { ArrowLeft, ArrowRight, Clapperboard, Pause, Volume2, X } from 'lucide-react'
import type { CinemaCompanionLocale, CinemaCompanionScene } from './osaCinemaCompanionText'
import './osaCinemaScreening.css'

type Props = {
  locale: CinemaCompanionLocale
  currentIndex: number
  scenes: readonly CinemaCompanionScene[]
  selectedAnswer?: number
  onSelectScene: (index: number) => void
  onAnswer: (index: number, choice: number) => void
  onFinish: () => void
}

const imageFileByScene = [
  'library.webp', 'understand.webp', 'library.webp', 'verify.webp',
  'verify.webp', 'library.webp', 'decide.webp', 'decide.webp',
] as const

const artworkDescriptions = {
  ru: [
    'Человек в монументальной библиотеке', 'Рукопись и свет — сцена понимания',
    'Библиотека знаний', 'Исследование источников и проверка',
    'Сопоставление доказательств', 'Библиотека и приватность',
    'Пространство человеческого выбора', 'Финальный свет и решение',
  ],
  en: [
    'A person in a monumental library', 'A manuscript and light, exploring understanding',
    'A library of knowledge', 'Researching and checking sources',
    'Comparing evidence', 'The library and privacy',
    'A setting for human choice', 'The final light and decision',
  ],
} as const

export default function OSACinemaScreening({
  locale, currentIndex, scenes, selectedAnswer, onSelectScene, onAnswer, onFinish,
}: Props) {
  const [open, setOpen] = useState(false)
  const [speaking, setSpeaking] = useState(false)
  const [voiceSupported, setVoiceSupported] = useState(false)
  const [voiceError, setVoiceError] = useState(false)
  const closeButton = useRef<HTMLButtonElement>(null)
  const dialog = useRef<HTMLElement>(null)
  const contentRef = useRef<HTMLDivElement>(null)
  const previousFocus = useRef<HTMLElement | null>(null)
  const utterance = useRef<SpeechSynthesisUtterance | null>(null)
  const closeAction = useRef<() => void>(() => undefined)
  const ru = locale === 'ru'
  const scene = scenes[currentIndex]
  const lastScene = currentIndex === scenes.length - 1

  const copy = ru ? {
    launch: 'Кинопросмотр восьми сцен', launchSub: 'Полноэкранная интерактивная история · без опубликованного видео',
    close: 'Вернуться к уроку', next: 'Следующая сцена', prev: 'Предыдущая сцена', finish: 'Завершить путешествие',
    label: 'Интерактивный показ OSA Cinema', act: 'АКТ', scene: 'СЦЕНА', of: 'ИЗ',
    insight: 'КЛЮЧЕВАЯ МЫСЛЬ', question: 'ВОПРОС ЗРИТЕЛЮ', result: 'РЕЗУЛЬТАТ ВЫБОРА',
    narration: 'Системное чтение сцены', stop: 'Остановить чтение', unsupported: 'Системный голос недоступен; весь текст можно читать.',
    disclosure: 'Это интерактивный показ на статичных авторизованных изображениях, не видеозапись. Озвучка синтезируется устройством только по нажатию.',
  } : {
    launch: 'Enter eight-scene screening', launchSub: 'Full-screen interactive story · no published video',
    close: 'Return to the lesson', next: 'Next scene', prev: 'Previous scene', finish: 'Complete the journey',
    label: 'OSA Cinema interactive screening', act: 'ACT', scene: 'SCENE', of: 'OF',
    insight: 'KEY INSIGHT', question: 'YOUR DECISION', result: 'YOUR CHOICE',
    narration: 'Read aloud using device voice', stop: 'Stop voice', unsupported: 'Device speech is unavailable; the text remains readable.',
    disclosure: 'An interactive visual experience made with approved still images, not recorded video. Device speech only starts when requested.',
  }

  const stopVoice = () => {
    if (utterance.current && typeof window !== 'undefined' && 'speechSynthesis' in window) {
      window.speechSynthesis.cancel()
    }
    utterance.current = null
    setSpeaking(false)
  }

  const closeScreening = () => {
    stopVoice()
    setOpen(false)
  }
  closeAction.current = closeScreening

  useEffect(() => {
    setVoiceSupported(typeof window !== 'undefined' && 'speechSynthesis' in window && 'SpeechSynthesisUtterance' in window)
    return () => {
      if (utterance.current && 'speechSynthesis' in window) window.speechSynthesis.cancel()
      utterance.current = null
    }
  }, [])

  useEffect(() => {
    if (contentRef.current) contentRef.current.scrollTop = 0
  }, [currentIndex, locale])

  useEffect(() => {
    if (!utterance.current) return
    if ('speechSynthesis' in window) window.speechSynthesis.cancel()
    utterance.current = null
    setSpeaking(false)
  }, [currentIndex, locale])

  useEffect(() => {
    if (!open) return
    previousFocus.current = document.activeElement instanceof HTMLElement ? document.activeElement : null
    const previousOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    closeButton.current?.focus()
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        event.preventDefault()
        event.stopPropagation()
        closeAction.current()
        return
      }
      if (event.key !== 'Tab' || !dialog.current) return
      const buttons = [...dialog.current.querySelectorAll<HTMLElement>('button:not(:disabled), a[href], [tabindex="0"]')]
        .filter(button => button.getClientRects().length > 0)
      if (!buttons.length) return
      const first = buttons[0]
      const last = buttons[buttons.length - 1]
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault()
        last.focus()
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault()
        first.focus()
      }
    }
    window.addEventListener('keydown', onKeyDown, true)
    return () => {
      window.removeEventListener('keydown', onKeyDown, true)
      document.body.style.overflow = previousOverflow
      previousFocus.current?.focus()
    }
  }, [open])

  const changeScene = (target: number) => {
    if (target < 0 || target >= scenes.length) return
    stopVoice()
    setVoiceError(false)
    onSelectScene(target)
  }

  const speak = () => {
    if (speaking) {
      stopVoice()
      return
    }
    if (!voiceSupported) return
    try {
      const text = [scene.title, scene.body, scene.takeaway].join('. ')
      const spoken = new SpeechSynthesisUtterance(text)
      spoken.lang = ru ? 'ru-RU' : 'en-US'
      spoken.rate = 0.94
      spoken.onend = () => { if (utterance.current === spoken) { utterance.current = null; setSpeaking(false) } }
      spoken.onerror = () => { if (utterance.current === spoken) { utterance.current = null; setSpeaking(false); setVoiceError(true) } }
      utterance.current = spoken
      setVoiceError(false)
      setSpeaking(true)
      window.speechSynthesis.cancel()
      window.speechSynthesis.speak(spoken)
    } catch {
      utterance.current = null
      setSpeaking(false)
      setVoiceError(true)
    }
  }

  const finish = () => {
    closeScreening()
    onFinish()
  }

  return <>
    <button type='button' className='osa-cinema-screening-launch' data-testid='cinema-screening-launch'
      onClick={() => { setVoiceError(false); setOpen(true) }}>
      <Clapperboard size={21} aria-hidden='true'/>
      <span><strong>{copy.launch}</strong><small>{copy.launchSub}</small></span>
      <ArrowRight size={18} aria-hidden='true'/>
    </button>
    {open && typeof document !== 'undefined' && createPortal(
      <div className='osa-cinema-screening' data-testid='cinema-screening'>
        <section ref={dialog} className='osa-cinema-screening__stage' role='dialog' aria-modal='true'
          aria-label={copy.label} aria-describedby='osa-screening-disclosure'>
          <div className='osa-cinema-screening__art' key={currentIndex + '-' + locale}>
            <img
              src={'/osa-cinema/reference/' + imageFileByScene[currentIndex]}
              alt={artworkDescriptions[locale][currentIndex]}
              decoding='async'
            />
          </div>
          <div className='osa-cinema-screening__vignette' aria-hidden='true'/>
          <header className='osa-cinema-screening__top'>
            <p>OSA ORIGINALS <span>/</span> 001</p>
            <button ref={closeButton} className='osa-cinema-screening__close'
              type='button' onClick={closeScreening} aria-label={copy.close}>
              <X size={20} aria-hidden='true'/><span>{copy.close}</span>
            </button>
          </header>
          <div ref={contentRef} className='osa-cinema-screening__content'>
            <p className='osa-cinema-screening__eyebrow'>{copy.act} 0{scene.act} <span>•</span> {copy.scene} {String(currentIndex + 1).padStart(2,'0')} {copy.of} 08</p>
            <h2 key={locale + '-' + currentIndex}>{scene.title}</h2>
            <p className='osa-cinema-screening__body'>{scene.body}</p>
            <div className='osa-cinema-screening__takeaway'>
              <strong>{copy.insight}</strong><p>{scene.takeaway}</p>
            </div>
            {scene.prompt && scene.choices?.length ? <div className='osa-cinema-screening__decision'>
              <h3>{copy.question}</h3>
              <p>{scene.prompt}</p>
              <div className='osa-cinema-screening__choices' role='group' aria-label={copy.question}>
                {scene.choices.map((choice, choiceIndex)=>
                  <button type='button' key={choiceIndex} onClick={()=>onAnswer(currentIndex, choiceIndex)}
                    aria-pressed={selectedAnswer===choiceIndex}>
                    <span>{String(choiceIndex + 1).padStart(2,'0')}</span>{choice.label}
                  </button>)}
              </div>
              {selectedAnswer!==undefined && scene.choices[selectedAnswer] &&
                <p className='osa-cinema-screening__result' role='status'>
                  <strong>{copy.result}: </strong>{scene.choices[selectedAnswer].result} — {scene.choices[selectedAnswer].insight}
                </p>}
            </div> : null}
          </div>
          <footer className='osa-cinema-screening__footer'>
            <div className='osa-cinema-screening__timeline'>
              <span aria-live='polite'>{String(currentIndex + 1).padStart(2,'0')} / 08</span>
              <div role='progressbar' aria-valuemin={1} aria-valuemax={scenes.length}
                aria-valuenow={currentIndex + 1} aria-label={ru?'Прогресс просмотра':'Screening progress'}>
                <i style={{width: ((currentIndex + 1) / scenes.length * 100)+'%'}}/>
              </div>
            </div>
            <div className='osa-cinema-screening__controls'>
              <button type='button' onClick={()=>changeScene(currentIndex - 1)} disabled={currentIndex === 0}>
                <ArrowLeft size={17} aria-hidden='true'/>{copy.prev}
              </button>
              {voiceSupported && <button type='button' onClick={speak} aria-pressed={speaking}>
                {speaking ? <Pause size={17} aria-hidden='true'/> : <Volume2 size={17} aria-hidden='true'/>}
                {speaking?copy.stop:copy.narration}
              </button>}
              <button type='button' className='osa-cinema-screening__primary'
                onClick={lastScene?finish:()=>changeScene(currentIndex + 1)}>
                {lastScene?copy.finish:copy.next}<ArrowRight size={17} aria-hidden='true'/>
              </button>
            </div>
            {voiceError && <p role='status'>{copy.unsupported}</p>}
            <p id='osa-screening-disclosure' className='osa-cinema-screening__disclosure'>{copy.disclosure}</p>
          </footer>
        </section>
      </div>, document.body
    )}
  </>
}
