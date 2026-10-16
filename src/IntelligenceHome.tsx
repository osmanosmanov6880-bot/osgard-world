import { useEffect, useState } from 'react'
import { BrandMark } from './BrandMark'
import { getOSALearningProgress, isOSALearningProgressPersistent, subscribeOSALearningProgress } from './osaProgress'
import { getOSANextLesson } from './osaLearningTracks'
import { OSA_LESSON_SLUGS } from './osaLessonRegistry'

const claims = [
  'Модель может выдать правдоподобный, но неверный ответ.',
  'Любой ответ ИИ автоматически точнее решения специалиста.',
  'Перед важным решением полезно проверить факты и последствия ошибки.',
]
const evidenceSource = 'https://nvlpubs.nist.gov/nistpubs/ai/NIST.AI.600-1.pdf'

export default function IntelligenceHome() {
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

  return <main className="intelligence-home brand-container">
    <section className="intelligence-hero" aria-labelledby="intelligence-title">
      <div>
        <p className="brand-eyebrow">OSA INTELLIGENCE / МЫШЛЕНИЕ И ПРАКТИКА</p>
        <h1 id="intelligence-title">Понимать ИИ.<br /><em>Проверять ответы.</em><br />Решать осознанно.</h1>
        <p className="brand-lead">Разберитесь, как работает ИИ. Научитесь находить основания для ответа и применять знания в собственной задаче.</p>
        <div className="brand-actions">
          <a className="brand-button primary" href="/learning/program">Начать обучение <span aria-hidden="true">↗</span></a>
          <a className="brand-button" href="#demo">Посмотреть, как это работает <span aria-hidden="true">↓</span></a>
        </div>
        <p className="brand-meta">{total} УРОКОВ / ПРАКТИКА / ПРОВЕРКА ИСТОЧНИКОВ</p>
      </div>
      <div className="intelligence-lens" aria-hidden="true">
        <span className="brand-eyebrow">ОКНО ВНИМАНИЯ / 01</span>
        <div className="lens-ring"><BrandMark theme="intelligence" /></div>
        <p>Ответ — начало.<br /><i>Доказательство — опора.</i></p>
        <small>МОДЕЛЬ → ИСТОЧНИК → РЕШЕНИЕ</small>
      </div>
    </section>

    <section id="method" className="brand-section" aria-labelledby="intelligence-method-title">
      <div className="brand-section-heading"><p className="brand-eyebrow">01 / МЕТОД</p><h2 id="intelligence-method-title">Три действия.<br /><em>Одно осознанное решение.</em></h2></div>
      <div className="intelligence-method">
        {[
          ['01', 'Понять', 'Как устроена модель, что она умеет и где её ограничения.'],
          ['02', 'Проверить', 'Что подтверждает утверждение и где находится первоисточник.'],
          ['03', 'Решить', 'Что можно применить, что уточнить и где нужен человек.'],
        ].map(([index, title, text]) => <div key={index}><span>{index}</span><h3>{title}</h3><p>{text}</p></div>)}
      </div>
    </section>

    <section id="demo" className="brand-section intelligence-demo" aria-labelledby="intelligence-demo-title">
      <div>
        <p className="brand-eyebrow">02 / ПОПРОБУЙТЕ СЕЙЧАС</p>
        <h2 id="intelligence-demo-title">Уверенность —<br /><em>ещё не источник.</em></h2>
        <p>Перед вами учебный ответ. Отметьте фразы, которые требуют проверки, и раскройте основания. Вы можете пересмотреть свой выбор.</p>
        <ol className="intelligence-demo-steps"><li>Выберите утверждения.</li><li>Откройте источники и границы.</li><li>Решите, чему можно доверять.</li></ol>
        <p className="brand-meta">УЧЕБНЫЙ ПРИМЕР / НЕ ОТВЕТ ПОДКЛЮЧЁННОЙ МОДЕЛИ</p>
      </div>
      <div className="intelligence-answer">
        <div className="answer-heading"><span>ЧЕРНОВИК ОТВЕТА</span><span>3 УТВЕРЖДЕНИЯ</span></div>
        <fieldset className="answer-claims"><legend>Что вы хотите проверить?</legend>
          {claims.map((text, index) => <label key={text} className={marked.includes(index) ? 'answer-claim selected' : 'answer-claim'}>
            <input type="checkbox" checked={marked.includes(index)} onChange={event => setMarked(previous => event.target.checked ? [...previous, index] : previous.filter(value => value !== index))} />
            <span><small>УТВЕРЖДЕНИЕ 0{index + 1}</small>{text}</span>
          </label>)}
        </fieldset>
        <button type="button" className="brand-button" aria-expanded={sources} aria-controls="demo-sources" onClick={() => setSources(!sources)}>
          {sources ? 'Скрыть источники и границы' : 'Раскрыть источники и границы'} <span aria-hidden="true">{sources ? '−' : '+'}</span>
        </button>
        <div id="demo-sources" hidden={!sources} className="demo-sources">
          <h3>На что можно опереться</h3>
          <ol className="intelligence-source-list">
            <li><span className="brand-status">01 / Основание есть</span><p>Риск убедительно сформулированной ошибки описан в <a href={evidenceSource + '#page=10'} target="_blank" rel="noopener noreferrer">NIST AI 600-1, § 2.2 ↗</a>. Документ объясняет риск; он не определяет точность конкретного ответа.</p></li>
            <li><span className="brand-status">02 / Не подтверждено</span><p>Для слова «любой» оснований нет. Нужны конкретная задача, критерии, модель и результаты сравнения. Уверенная формулировка сама по себе их не заменяет.</p></li>
            <li><span className="brand-status">03 / Практическая рекомендация</span><p>В том же документе, <a href={evidenceSource + '#page=35'} target="_blank" rel="noopener noreferrer">MS-2.5-003 ↗</a>, предложена проверка источников и цитат. Способ проверки зависит от задачи и цены ошибки.</p></li>
          </ol>
          <p className="intelligence-source-note">Первоисточник: NIST, июль 2024, PDF на английском. Открывается в новой вкладке. Этот разбор — учебная интерпретация документа; он не является оценкой ваших знаний.</p>
          <a className="brand-text-link" href="/lectures/verify-an-ai-answer">Пройти практику «Проверьте ответ ИИ» →</a>
        </div>
        <div className="intelligence-demo-feedback"><p role="status">Отмечено для проверки: {marked.length} из {claims.length}. Выбор действует в этой демонстрации.</p><button type="button" className="brand-reset" disabled={!marked.length && !sources} onClick={() => { setMarked([]); setSources(false) }}>Начать заново</button></div>
      </div>
    </section>

    <section className="brand-section" aria-labelledby="intelligence-path-title">
      <div className="brand-section-heading"><p className="brand-eyebrow">03 / МАРШРУТ ОБУЧЕНИЯ</p><h2 id="intelligence-path-title">От первой сцены<br /><em>до собственной работы.</em></h2></div>
      <div className="intelligence-path">
        {[
          ['OSA Original', 'Интерактивные сцены: исследуйте вопрос и разбирайте последствия выбора.', '/osa-cinema', 'Войти в первую сцену'],
          ['Академия', 'Учебные маршруты, упражнения и практика над собственной задачей.', '/academy', 'Открыть Академию'],
          ['Каталог лекций', `${total} тем с учебным материалом, самопроверкой и первоисточниками.`, '/lectures', 'Выбрать лекцию'],
        ].map(([title, text, href, cta], index) => <a key={title} href={href}><small>0{index + 1}</small><h3>{title}</h3><p>{text}</p><strong>{cta} <span aria-hidden="true">↗</span></strong></a>)}
      </div>
    </section>

    <section className="brand-section intelligence-trust" aria-labelledby="intelligence-trust-title">
      <p className="brand-eyebrow">04 / ПРИНЦИПЫ ДОВЕРИЯ</p>
      <h2 id="intelligence-trust-title">Источники видны.<br /><em>Ограничения названы.</em></h2>
      <div><p>У каждого урока есть цель, практика и ссылки на источники. Самопроверка помогает увидеть пробелы; профессиональную квалификацию она не подтверждает.</p><p>Статус аудио и видео указан в медиатеке. Интерактивные сцены и текст доступны отдельно; видеоверсии появляются только после проверки файлов и постоянных адресов.</p><a className="brand-text-link" href="/osa-library/">Медиатека и статусы материалов <span aria-hidden="true">↗</span></a></div>
    </section>

    <section className="brand-section intelligence-continue" aria-labelledby="intelligence-continue-title">
      <p className="brand-eyebrow">05 / ВАШ СЛЕДУЮЩИЙ ШАГ</p>
      <h2 id="intelligence-continue-title">{completed ? 'Продолжим с того, что уже есть.' : 'Начните с одного хорошего вопроса.'}</h2>
      <p>{completed ? `В гостевом прогрессе отмечено уроков: ${completed} из ${total}.` : 'Гостевой прогресс появится после прохождения уроков.'} {persistent ? 'Он хранится в этом браузере.' : 'Сейчас постоянное сохранение недоступно: результат может остаться только до закрытия страницы.'}</p>
      {completed > 0 && <div className="intelligence-progress"><label htmlFor="intelligence-progress">Ваш маршрут: {completed} из {total} уроков</label><progress id="intelligence-progress" max={total} value={completed}>{completed} из {total}</progress></div>}
      <div className="brand-actions"><a className="brand-button primary" href={completed ? next ? '/lectures/' + next : '/learning/project' : '/osa-cinema'}>{completed ? next ? 'Открыть следующий урок' : 'Перейти к практическому проекту' : 'Начать первую сцену'} <span aria-hidden="true">↗</span></a><a className="brand-button" href="/learning">Открыть мой прогресс <span aria-hidden="true">→</span></a></div>
      <p className="intelligence-account-note">Работаете над проектом с аккаунтом? <a href="/learning/campus">Открыть учебное пространство →</a></p>
    </section>
  </main>
}
