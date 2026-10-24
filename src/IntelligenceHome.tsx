import { useEffect, useState } from 'react'
import { Globe2 } from 'lucide-react'
import { getOSALearningProgress, isOSALearningProgressPersistent, subscribeOSALearningProgress } from './osaProgress'
import { getOSANextLesson } from './osaLearningTracks'
import { OSA_LESSON_SLUGS } from './osaLessonRegistry'
import './intelligenceCommand.css'

type Locale = 'ru' | 'en'

const copy = {
  ru: {
    skip: 'Перейти к содержанию',
    langLabel: 'Switch language to English',
    lang: 'EN',
    eyebrow: 'OSA INTELLIGENCE / ИНТЕЛЛЕКТУАЛЬНАЯ СРЕДА',
    titleA: 'Понимать ИИ.', titleB: 'Проверять ответы.', titleC: 'Решать осознанно.',
    lead: 'Разбирайтесь в сложных ответах, находите проверяемые основания и принимайте собственные решения. Начните с короткого упражнения — без регистрации.',
    check: 'Проверить утверждения', program: 'Программа обучения',
    route: 'МОЙ УЧЕБНЫЙ МАРШРУТ', lessons: 'УРОКОВ',
    progressLabel: 'Пройденные уроки OSA',
    saved: 'Отметки сохраняются в этом браузере.',
    noSave: 'Сейчас постоянное сохранение недоступно.',
    lab: 'OSA / ЛАБОРАТОРИЯ ДОКАЗАТЕЛЬСТВ', example: 'ИНТЕРАКТИВНЫЙ ПРИМЕР',
    practice: 'ПРАКТИКА · 01 / 03',
    question: 'Какие утверждения стоит проверить?',
    instruction: 'Нажмите на формулировки, которым нужны основания. Отметки сразу появятся в подробном разборе ниже.',
    choose: 'Выберите утверждения для проверки', selected: 'ОТМЕЧЕНО',
    evidence: 'Посмотреть доказательства',
    demoNote: 'Это подготовленный учебный пример, а не ответ подключённой нейросети. Источники и ограничения указаны в разборе.',
    claims: [
      'Модель может выдать правдоподобный, но неверный ответ.',
      'Любой ответ ИИ автоматически точнее решения специалиста.',
      'Перед важным решением полезно проверить факты и последствия ошибки.',
    ],
    quick: 'БЫСТРЫЙ СТАРТ ОБУЧЕНИЯ',
    quickItems: [
      ['01 / ЗНАНИЯ', '8 уроков', 'Начать программу'],
      ['02 / ПРОВЕРКА', 'Разбор', 'Источники и границы'],
      ['03 / РЕЗУЛЬТАТ', 'Прогресс', 'Мой учебный маршрут'],
    ],
    methodLabel: '01 / МЕТОД', methodA: 'Три действия.', methodB: 'Одно осознанное решение.',
    method: [
      ['Понять', 'Как устроена модель, что она умеет и где её ограничения.'],
      ['Проверить', 'Что подтверждает утверждение и где находится первоисточник.'],
      ['Решить', 'Что можно применить, что уточнить и где нужен человек.'],
    ],
    demoLabel: '02 / ПОПРОБУЙТЕ СЕЙЧАС', demoA: 'Уверенность —', demoB: 'ещё не источник.',
    demoLead: 'Перед вами учебный ответ. Отметьте фразы, которые требуют проверки, и раскройте основания. Вы можете пересмотреть свой выбор.',
    steps: ['Выберите утверждения.', 'Откройте источники и границы.', 'Решите, чему можно доверять.'],
    sample: 'УЧЕБНЫЙ ПРИМЕР / НЕ ОТВЕТ ПОДКЛЮЧЁННОЙ МОДЕЛИ',
    draft: 'ЧЕРНОВИК ОТВЕТА', threeClaims: '3 УТВЕРЖДЕНИЯ', legend: 'Что вы хотите проверить?',
    claimLabel: 'УТВЕРЖДЕНИЕ',
    hide: 'Скрыть источники и границы', reveal: 'Раскрыть источники и границы',
    sourceHeading: 'На что можно опереться',
    sourceStatus: ['01 / Основание есть', '02 / Не подтверждено', '03 / Практическая рекомендация'],
    sourceText: [
      <>Риск убедительно сформулированной ошибки описан в <a href="https://nvlpubs.nist.gov/nistpubs/ai/NIST.AI.600-1.pdf#page=10" target="_blank" rel="noopener noreferrer">NIST AI 600-1, § 2.2 ↗</a>. Документ объясняет риск; он не определяет точность конкретного ответа.</>,
      <>Для слова «любой» оснований нет. Нужны конкретная задача, критерии, модель и результаты сравнения. Уверенная формулировка сама по себе их не заменяет.</>,
      <>В том же документе, <a href="https://nvlpubs.nist.gov/nistpubs/ai/NIST.AI.600-1.pdf#page=35" target="_blank" rel="noopener noreferrer">MS-2.5-003 ↗</a>, предложена проверка источников и цитат. Способ проверки зависит от задачи и цены ошибки.</>,
    ],
    sourceNote: 'Первоисточник: NIST, июль 2024, PDF на английском. Этот разбор — учебная интерпретация документа, а не оценка ваших знаний.',
    practiceLink: 'Пройти практику «Проверьте ответ ИИ»',
    feedback: 'Отмечено для проверки:', of: 'из', reset: 'Начать заново',
    pathLabel: '03 / МАРШРУТ ОБУЧЕНИЯ', pathA: 'От первой сцены', pathB: 'до собственной работы.',
    path: [
      ['OSA Original', 'Интерактивные сцены: исследуйте вопрос и разбирайте последствия выбора.', 'Войти в первую сцену'],
      ['Академия', 'Учебные маршруты, упражнения и практика над собственной задачей.', 'Открыть Академию'],
      ['Каталог лекций', 'тем с учебным материалом, самопроверкой и первоисточниками.', 'Выбрать лекцию'],
    ],
    trustLabel: '04 / ПРИНЦИПЫ ДОВЕРИЯ', trustA: 'Источники видны.', trustB: 'Ограничения названы.',
    trustTextA: 'У каждого урока есть цель, практика и ссылки на источники. Самопроверка помогает увидеть пробелы; профессиональную квалификацию она не подтверждает.',
    trustTextB: 'Статус аудио и видео указан в медиатеке. Интерактивные сцены и текст доступны отдельно; видеоверсии появляются только после проверки файлов и постоянных адресов.',
    media: 'Медиатека и статусы материалов',
    nextLabel: '05 / ВАШ СЛЕДУЮЩИЙ ШАГ',
    nextTitle: 'Начните с одного хорошего вопроса.',
    nextTitleProgress: 'Продолжим с того, что уже есть.',
    nextEmpty: 'Гостевой прогресс появится после прохождения уроков.',
    nextProgress: 'В гостевом прогрессе отмечено уроков:',
    local: 'Он хранится в этом браузере.',
    volatile: 'Сейчас постоянное сохранение недоступно: результат может остаться только до закрытия страницы.',
    routeProgress: 'Ваш маршрут:',
    nextLesson: 'Открыть следующий урок',
    project: 'Перейти к практическому проекту',
    start: 'Начать первую сцену',
    myProgress: 'Открыть мой прогресс',
    account: 'Работаете над проектом с аккаунтом?',
    workspace: 'Открыть учебное пространство',
  },
  en: {
    skip: 'Skip to content',
    langLabel: 'Переключить язык на русский',
    lang: 'RU',
    eyebrow: 'OSA INTELLIGENCE / KNOWLEDGE STUDIO',
    titleA: 'Understand AI.', titleB: 'Check its answers.', titleC: 'Decide with care.',
    lead: 'Explore complex answers, find evidence you can verify, and make your own informed decisions. Start with a short exercise — no sign-up required.',
    check: 'Review the claims', program: 'Learning programme',
    route: 'MY LEARNING PATH', lessons: 'LESSONS',
    progressLabel: 'OSA lessons completed',
    saved: 'Progress is saved in this browser.',
    noSave: 'Persistent progress storage is unavailable right now.',
    lab: 'OSA / EVIDENCE LAB', example: 'INTERACTIVE EXAMPLE',
    practice: 'PRACTICE · 01 / 03',
    question: 'Which claims should you check?',
    instruction: 'Select the statements that need evidence. Your choices will appear in the detailed review below.',
    choose: 'Choose claims to review', selected: 'SELECTED',
    evidence: 'View the evidence',
    demoNote: 'This is a prepared learning example, not an answer from a connected AI model. Sources and limitations are shown in the review.',
    claims: [
      'A model can produce an answer that sounds plausible but is wrong.',
      'Any AI answer is automatically more accurate than an expert’s judgement.',
      'Before an important decision, check the facts and the consequences of error.',
    ],
    quick: 'QUICK START',
    quickItems: [
      ['01 / LEARN', '8 lessons', 'Start the programme'],
      ['02 / VERIFY', 'Review', 'Sources and limits'],
      ['03 / PROGRESS', 'Progress', 'My learning path'],
    ],
    methodLabel: '01 / METHOD', methodA: 'Three actions.', methodB: 'One considered decision.',
    method: [
      ['Understand', 'How a model works, what it can do, and where its limits are.'],
      ['Verify', 'What supports a claim and where to find the original source.'],
      ['Decide', 'What to apply, what to clarify, and when a person is needed.'],
    ],
    demoLabel: '02 / TRY IT NOW', demoA: 'Confidence', demoB: 'is not a source.',
    demoLead: 'This is a learning example. Mark the statements that need checking and reveal the evidence. You can change your selections at any time.',
    steps: ['Select the claims.', 'Open the sources and limitations.', 'Decide what you can trust.'],
    sample: 'LEARNING EXAMPLE / NOT AN ANSWER FROM A CONNECTED MODEL',
    draft: 'DRAFT ANSWER', threeClaims: '3 CLAIMS', legend: 'What would you like to check?',
    claimLabel: 'CLAIM',
    hide: 'Hide sources and limitations', reveal: 'Reveal sources and limitations',
    sourceHeading: 'What the evidence says',
    sourceStatus: ['01 / Supported risk', '02 / Not supported', '03 / Practical recommendation'],
    sourceText: [
      <>The risk of confidently stated errors is discussed in <a href="https://nvlpubs.nist.gov/nistpubs/ai/NIST.AI.600-1.pdf#page=10" target="_blank" rel="noopener noreferrer">NIST AI 600-1, § 2.2 ↗</a>. The document describes the risk; it does not establish the accuracy of a specific answer.</>,
      <>There is no basis for the word “any.” You need a specific task, criteria, model, and comparison results. Confidence of wording does not replace them.</>,
      <>The same document, <a href="https://nvlpubs.nist.gov/nistpubs/ai/NIST.AI.600-1.pdf#page=35" target="_blank" rel="noopener noreferrer">MS-2.5-003 ↗</a>, recommends checking sources and citations. The right method depends on the task and the cost of error.</>,
    ],
    sourceNote: 'Primary source: NIST, July 2024, English PDF. This review is a learning interpretation of the document, not an assessment of your knowledge.',
    practiceLink: 'Try the “Verify an AI answer” exercise',
    feedback: 'Marked for review:', of: 'of', reset: 'Start over',
    pathLabel: '03 / LEARNING PATH', pathA: 'From the first scene', pathB: 'to your own project.',
    path: [
      ['OSA Original', 'Interactive scenes: explore a question and consider the consequences of your choices.', 'Enter the first scene'],
      ['Academy', 'Learning paths, exercises, and practice with a task of your own.', 'Open the Academy'],
      ['Lecture library', ' topics with learning material, self-checks, and primary sources.', 'Choose a lecture'],
    ],
    trustLabel: '04 / TRUST PRINCIPLES', trustA: 'Sources are visible.', trustB: 'Limitations are stated.',
    trustTextA: 'Every lesson has a goal, practice, and source links. Self-checks help reveal gaps; they do not certify professional qualifications.',
    trustTextB: 'Audio and video availability is shown in the media library. Interactive scenes and text are available separately; video versions are listed only after files and stable URLs are verified.',
    media: 'Media library and availability',
    nextLabel: '05 / YOUR NEXT STEP',
    nextTitle: 'Start with one good question.',
    nextTitleProgress: 'Continue where you left off.',
    nextEmpty: 'Guest progress appears after you complete lessons.',
    nextProgress: 'Lessons completed in guest progress:',
    local: 'It is stored in this browser.',
    volatile: 'Persistent storage is unavailable. Progress may be lost when you close this page.',
    routeProgress: 'Your path:',
    nextLesson: 'Open the next lesson',
    project: 'Go to the practical project',
    start: 'Start the first scene',
    myProgress: 'View my progress',
    account: 'Working on a project with an account?',
    workspace: 'Open the learning workspace',
  },
}

export default function IntelligenceHome() {
  const [locale, setLocale] = useState<Locale>(() => {
    try { return localStorage.getItem('osa:locale') === 'en' ? 'en' : 'ru' } catch { return 'ru' }
  })
  const t = copy[locale]
  const claims = t.claims
  const [sources, setSources] = useState(false)
  const [marked, setMarked] = useState<number[]>([])
  const [progress, setProgress] = useState(getOSALearningProgress)
  const [persistent, setPersistent] = useState(isOSALearningProgressPersistent)
  useEffect(() => subscribeOSALearningProgress(() => {
    setProgress(getOSALearningProgress())
    setPersistent(isOSALearningProgressPersistent())
  }), [])
  const next = getOSANextLesson(progress.lessonCompletions)
  const completed = progress.lessonCompletions.length
  const total = OSA_LESSON_SLUGS.length
  const changeLocale = () => {
    const nextLocale: Locale = locale === 'ru' ? 'en' : 'ru'
    setLocale(nextLocale)
    try { localStorage.setItem('osa:locale', nextLocale) } catch { /* Storage is optional. */ }
  }

  return <main className="intelligence-home brand-container intelligence-command" lang={locale}>
    <a className="intelligence-skip-link" href="#intelligence-content">{t.skip}</a>
    <section className="intelligence-hero intelligence-command-hero" aria-labelledby="intelligence-title">
      <div className="intelligence-command-copy">
        <div className="intelligence-language-row">
          <p className="brand-eyebrow intelligence-command-eyebrow">{t.eyebrow}</p>
          <button className="intelligence-language-toggle" type="button" onClick={changeLocale} aria-label={t.langLabel}>
            <Globe2 size={15} aria-hidden="true" /> {t.lang}
          </button>
        </div>
        <h1 id="intelligence-title">{t.titleA}<br /><em>{t.titleB}</em><br />{t.titleC}</h1>
        <p className="brand-lead">{t.lead}</p>
        <div className="brand-actions intelligence-command-actions">
          <a className="brand-button primary" href="#proof-card">{t.check} <span aria-hidden="true">↘</span></a>
          <a className="brand-button intelligence-command-secondary" href="/learning/program">{t.program} <span aria-hidden="true">↗</span></a>
        </div>
        <div className="intelligence-command-progress">
          <div className="intelligence-progress-heading"><span>{t.route}</span><strong>{completed} / {total} {t.lessons}</strong></div>
          <div className="intelligence-progress-rail" role="progressbar" aria-label={t.progressLabel} aria-valuemin={0} aria-valuemax={total} aria-valuenow={completed}>
            <span style={{width: (100 * completed / Math.max(total, 1)) + '%'}} />
          </div>
          <p>{persistent ? t.saved : t.noSave}</p>
        </div>
      </div>
      <div className="intelligence-lens omega-intelligence-lens intelligence-command-lens">
        <div className="omega-intelligence-scene intelligence-command-art" aria-hidden="true">
          <img src="/brand/omega-osa.svg" alt="" width="1600" height="1000" decoding="async" fetchPriority="high" />
          <span className="omega-intelligence-pulse omega-intelligence-pulse-a" />
          <span className="omega-intelligence-pulse omega-intelligence-pulse-b" />
        </div>
        <section id="proof-card" className="intelligence-proof-console" aria-labelledby="intelligence-proof-title" tabIndex={-1}>
          <div className="intelligence-proof-topbar">
            <span>OSA / EVIDENCE LAB</span>
            <span><i aria-hidden="true" />{t.example}</span>
          </div>
          <p className="intelligence-proof-eyebrow">{t.practice}</p>
          <h2 id="intelligence-proof-title">{t.question}</h2>
          <p className="intelligence-proof-lead">{t.instruction}</p>
          <div className="intelligence-proof-claims" role="group" aria-label={t.choose}>
            {claims.map((claim,index)=><button key={claim} type="button" className={marked.includes(index) ? 'intelligence-proof-claim is-selected' : 'intelligence-proof-claim'}
              aria-pressed={marked.includes(index)}
              onClick={() => setMarked(previous => previous.includes(index) ? previous.filter(value => value !== index) : [...previous,index])}>
              <span className="intelligence-proof-index" aria-hidden="true">0{index+1}</span>
              <span className="intelligence-proof-statement">{claim}</span>
              <span className="intelligence-proof-marker" aria-hidden="true">{marked.includes(index)?'✓':'+'}</span>
            </button>)}
          </div>
          <div className="intelligence-proof-summary">
            <span>{t.selected} <strong>{marked.length} / {claims.length}</strong></span>
            <a href="#demo" onClick={() => setSources(true)}>{t.evidence} <span aria-hidden="true">↗</span></a>
          </div>
          <p className="intelligence-proof-note">{t.demoNote}</p>
        </section>
      </div>
      <nav className="omega-osa-trails intelligence-command-trails" aria-label={t.quick}>
        {t.quickItems.map(([eyebrow, title, label], index) => <a key={eyebrow} href={index === 0 ? '/learning/program' : index === 1 ? '#demo' : '/learning'}>
          <span>{eyebrow}</span><strong>{title}</strong><small>{label}</small>
        </a>)}
      </nav>
    </section>

    <div id="intelligence-content">
      <section id="method" className="brand-section" aria-labelledby="intelligence-method-title">
        <div className="brand-section-heading"><p className="brand-eyebrow">{t.methodLabel}</p><h2 id="intelligence-method-title">{t.methodA}<br /><em>{t.methodB}</em></h2></div>
        <div className="intelligence-method">
          {t.method.map(([title, text], index) => <div key={title}><span>0{index + 1}</span><h3>{title}</h3><p>{text}</p></div>)}
        </div>
      </section>

      <section id="demo" className="brand-section intelligence-demo" aria-labelledby="intelligence-demo-title">
        <div>
          <p className="brand-eyebrow">{t.demoLabel}</p>
          <h2 id="intelligence-demo-title">{t.demoA}<br /><em>{t.demoB}</em></h2>
          <p>{t.demoLead}</p>
          <ol className="intelligence-demo-steps">{t.steps.map(step => <li key={step}>{step}</li>)}</ol>
          <p className="brand-meta">{t.sample}</p>
        </div>
        <div className="intelligence-answer">
          <div className="answer-heading"><span>{t.draft}</span><span>{t.threeClaims}</span></div>
          <fieldset className="answer-claims"><legend>{t.legend}</legend>
            {claims.map((text, index) => <label key={text} className={marked.includes(index) ? 'answer-claim selected' : 'answer-claim'}>
              <input type="checkbox" checked={marked.includes(index)} onChange={event => setMarked(previous => event.target.checked ? [...new Set([...previous, index])] : previous.filter(value => value !== index))} />
              <span><small>{t.claimLabel} 0{index + 1}</small>{text}</span>
            </label>)}
          </fieldset>
          <button type="button" className="brand-button" aria-expanded={sources} aria-controls="demo-sources" onClick={() => setSources(!sources)}>
            {sources ? t.hide : t.reveal} <span aria-hidden="true">{sources ? '−' : '+'}</span>
          </button>
          <div id="demo-sources" hidden={!sources} className="demo-sources">
            <h3>{t.sourceHeading}</h3>
            <ol className="intelligence-source-list">
              {t.sourceText.map((text, index) => <li key={index}><span className="brand-status">{t.sourceStatus[index]}</span><p>{text}</p></li>)}
            </ol>
            <p className="intelligence-source-note">{t.sourceNote}</p>
            <a className="brand-text-link" href="/lectures/verify-an-ai-answer">{t.practiceLink} →</a>
          </div>
          <div className="intelligence-demo-feedback">
            <p role="status">{t.feedback} {marked.length} {t.of} {claims.length}. {locale === 'ru' ? 'Выбор действует в этой демонстрации.' : 'Your selection applies to this demonstration.'}</p>
            <button type="button" className="brand-reset" disabled={!marked.length && !sources} onClick={() => { setMarked([]); setSources(false) }}>{t.reset}</button>
          </div>
        </div>
      </section>

      <section className="brand-section" aria-labelledby="intelligence-path-title">
        <div className="brand-section-heading"><p className="brand-eyebrow">{t.pathLabel}</p><h2 id="intelligence-path-title">{t.pathA}<br /><em>{t.pathB}</em></h2></div>
        <div className="intelligence-path">
          {t.path.map(([title, text, cta], index) => <a key={title} href={index === 0 ? '/osa-cinema' : index === 1 ? '/academy' : '/lectures'}>
            <small>0{index + 1}</small><h3>{title}</h3><p>{index === 2 ? `${total}${text}` : text}</p><strong>{cta} <span aria-hidden="true">↗</span></strong>
          </a>)}
        </div>
      </section>

      <section className="brand-section intelligence-trust" aria-labelledby="intelligence-trust-title">
        <p className="brand-eyebrow">{t.trustLabel}</p>
        <h2 id="intelligence-trust-title">{t.trustA}<br /><em>{t.trustB}</em></h2>
        <div><p>{t.trustTextA}</p><p>{t.trustTextB}</p><a className="brand-text-link" href="/osa-library/">{t.media} <span aria-hidden="true">↗</span></a></div>
      </section>

      <section className="brand-section intelligence-continue" aria-labelledby="intelligence-continue-title">
        <p className="brand-eyebrow">{t.nextLabel}</p>
        <h2 id="intelligence-continue-title">{completed ? t.nextTitleProgress : t.nextTitle}</h2>
        <p>{completed ? <>{t.nextProgress} {completed} {t.of} {total}.</> : t.nextEmpty} {persistent ? t.local : t.volatile}</p>
        {completed > 0 && <div className="intelligence-progress"><label htmlFor="intelligence-progress">{t.routeProgress} {completed} {t.of} {total} {t.lessons.toLowerCase()}</label><progress id="intelligence-progress" max={total} value={completed}>{completed} / {total}</progress></div>}
        <div className="brand-actions">
          <a className="brand-button primary" href={completed ? next ? '/lectures/' + next : '/learning/project' : '/osa-cinema'}>
            {completed ? next ? t.nextLesson : t.project : t.start} <span aria-hidden="true">↗</span>
          </a>
          <a className="brand-button" href="/learning">{t.myProgress} <span aria-hidden="true">→</span></a>
        </div>
        <p className="intelligence-account-note">{t.account} <a href="/learning/campus">{t.workspace} →</a></p>
      </section>
    </div>
  </main>
}
