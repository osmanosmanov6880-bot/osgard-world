import { lazy, Suspense, useEffect, useRef, useState } from 'react'
import type { KeyboardEvent as ReactKeyboardEvent } from 'react'
import './omegaWorld.css'
import { cases } from './redesignCatalog'
import { BrandMark } from './BrandMark'
import { formatEnquiry, validateEnquiry } from './projectEnquiry'
import { recordBrandEvent } from './brandTelemetry'
import type { GlobeChapter, GlobeMode, GlobeView, GlobeQuality } from './OmegaGlobe'

const OmegaGlobe = lazy(() => import('./OmegaGlobe'))

const readOmegaMode = (): GlobeMode => {
  try {
    const value = localStorage.getItem('osgard:omega-world-mode')
    return value === 'cinema' || value === 'world' || value === 'hybrid' ? value : 'hybrid'
  } catch { return 'hybrid' }
}
const omegaChapters = ['Планета', 'Связи', 'Миры'] as const
const omegaHelp: Record<GlobeMode, string> = {
  cinema: 'Камера сама показывает Землю с разных ракурсов. Выберите главу или перейдите к продуктам.',
  world: 'Вращайте планету мышью или горизонтальным свайпом. Масштаб — колёсиком или кнопками. Остальные разделы доступны сразу.',
  hybrid: 'Живой 3D-глобус работает на фоне, а все разделы и кнопки остаются на переднем плане.',
}


const directions = [
  ['01', 'OSA Intelligence', 'Для тех, кто хочет понимать ИИ, проверять ответы и принимать обоснованные решения.', '/intelligence', 'Обучение и мышление'],
  ['02', 'Development', 'Для команд, которым нужен цифровой продукт: от структуры и интерфейса до разработки и проверки.', '/development', 'Создание продуктов'],
  ['03', 'OSGARD PLAY', 'Для игроков, исследующих интерактивные миры, стратегии и короткие эксперименты.', '/play', 'Игры и взаимодействие'],
]
const process = [
  ['Стратегия', 'Уточняем аудиторию, задачу и критерии результата.'],
  ['Структура', 'Собираем маршруты и главное действие каждого экрана.'],
  ['Дизайн', 'Выбираем визуальный язык, который работает на продукт.'],
  ['Разработка', 'Реализуем интерфейс, состояния и сохранение данных.'],
  ['Запуск', 'Проверяем сборку, зависимости и готовность инфраструктуры.'],
]

export default function WorldHome({ development = false }: { development?: boolean }) {
  const [omegaMode, setOmegaMode] = useState<GlobeMode>(readOmegaMode)
  const [omegaChapter, setOmegaChapter] = useState<GlobeChapter>(0)
  const [omegaQuality, setOmegaQuality] = useState<GlobeQuality>('auto')
  const [omegaView, setOmegaView] = useState<GlobeView>({ yaw: 0, pitch: -0.14, distance: 5.7 })
  useEffect(() => {
    try { localStorage.setItem('osgard:omega-world-mode', omegaMode) } catch { /* The mode still works for this visit. */ }
  }, [omegaMode])
  const moveWorld = (action: 'left' | 'right' | 'closer' | 'farther' | 'reset') => {
    setOmegaView(view => action === 'reset'
      ? { yaw: 0, pitch: -0.14, distance: 5.7 }
      : action === 'left' ? { ...view, yaw: view.yaw - 0.38 }
      : action === 'right' ? { ...view, yaw: view.yaw + 0.38 }
      : action === 'closer' ? { ...view, distance: Math.max(3.1, view.distance - 0.42) }
      : { ...view, distance: Math.min(8, view.distance + 0.42) })
  }
  const onWorldKeyDown = (event: ReactKeyboardEvent<HTMLElement>) => {
    if (omegaMode !== 'world' || event.target !== event.currentTarget) return
    const action = event.key === 'ArrowLeft' ? 'left'
      : event.key === 'ArrowRight' ? 'right'
      : event.key === '+' || event.key === '=' ? 'closer'
      : event.key === '-' ? 'farther' : event.key === 'Home' ? 'reset' : null
    if (action) { event.preventDefault(); moveWorld(action) }
  }
  const [brief, setBrief] = useState('')
  const [contact, setContact] = useState('')
  const [saved, setSaved] = useState(false)
  const [error, setError] = useState('')
  const briefInput = useRef<HTMLTextAreaElement>(null)
  useEffect(() => {
    const warn = (event: BeforeUnloadEvent) => { if ((brief.trim() || contact.trim()) && !saved) { event.preventDefault(); event.returnValue = '' } }
    window.addEventListener('beforeunload', warn)
    return () => window.removeEventListener('beforeunload', warn)
  }, [brief, contact, saved])
  const download = () => {
    try {
      const blob = new Blob([formatEnquiry(brief, contact)], { type: 'text/plain;charset=utf-8' })
      const url = URL.createObjectURL(blob)
      const anchor = document.createElement('a')
      anchor.href = url
      anchor.download = 'OSGARD-project-brief.txt'
      anchor.click()
      setTimeout(() => URL.revokeObjectURL(url), 1000)
      setSaved(true)
      recordBrandEvent('brief_exported')
      setError('')
    } catch { setError('Не удалось создать файл. Скопируйте описание задачи и отправьте его на указанный адрес.') }
  }

  return <main className="world-home brand-container">
    {development ? <>
      <section className="omega-dev-hero" aria-labelledby="world-title">
        <div className="omega-dev-hero-art" aria-hidden="true"><img src="/brand/omega-development.svg" width="1600" height="1000" alt="" decoding="async" /><span className="omega-dev-orbit omega-dev-orbit-a"/><span className="omega-dev-orbit omega-dev-orbit-b"/></div>
        <div className="omega-dev-intro">
          <p className="brand-eyebrow">OSGARD / DEVELOPMENT / DIGITAL ENGINEERING</p>
          <h1 id="world-title">СОЗДАЁМ<br/><span>ЦИФРОВЫЕ</span><br/>РЕШЕНИЯ.</h1>
          <p className="brand-lead">Проектируем интерфейсы и цифровые продукты — от первых сценариев до проверяемых демонстраций. Смотрите реальные кейсы, возможности и текущую стадию каждого проекта.</p>
          <div className="brand-actions"><a className="brand-button primary" href="#cases">Смотреть проекты <span aria-hidden="true">↗</span></a><a className="brand-button" href="#contact">Обсудить разработку <span aria-hidden="true">→</span></a></div>
          <p className="brand-meta">СТРАТЕГИЯ / ПРОТОТИП / ИНТЕРФЕЙС / ЗАПУСК</p>
        </div>
        <div className="omega-dev-console" aria-label="Принцип работы студии">
          <span>OSGARD ENGINEERING / 001</span>
          <strong>От идеи — к работающему сценарию.</strong>
          <p>Технология ценна, когда результат можно открыть, попробовать и проверить.</p>
          <a href="#approach">Как мы работаем <span aria-hidden="true">↘</span></a>
        </div>
      </section>
      <section id="products" className="brand-section omega-dev-capabilities" aria-labelledby="dev-capabilities-title">
        <div className="brand-section-heading"><p className="brand-eyebrow">01 / ЧТО МЫ ДЕЛАЕМ</p><h2 id="dev-capabilities-title">АРХИТЕКТУРА. <span>ДИЗАЙН. КОД.</span></h2><p>Начинаем с задачи, показываем логику продукта и доступную реализацию. Без выдуманных результатов и обещаний несуществующих функций.</p></div>
        <div className="omega-dev-capability-grid">
          <a href="#cases"><span>01 / UX & PRODUCT</span><strong>Интерфейсы и сценарии</strong><p>Понятная структура, удобная навигация, адаптация и доступность.</p><em>Смотреть кейсы ↗</em></a>
          <a href="/development/tedes/"><span>02 / PROTOTYPES</span><strong>Конфигураторы и инструменты</strong><p>Изучите демонстрацию TEDES с локальной проектной спецификацией.</p><em>Открыть TEDES ↗</em></a>
          <a href="#contact"><span>03 / ENGINEERING</span><strong>Разработка и проверка</strong><p>Обсуждаем требования, реализуем необходимые функции и проверяем результат.</p><em>Обсудить задачу ↗</em></a>
        </div>
      </section>
    </> : <>
    <section className={'omega-hero omega-command omega-experience-' + omegaMode}
      data-omega-mode={omegaMode} data-omega-yaw={omegaView.yaw.toFixed(2)}
      data-omega-distance={omegaView.distance.toFixed(2)}
      aria-labelledby="world-title"
      tabIndex={omegaMode === 'world' ? 0 : undefined} onKeyDown={onWorldKeyDown}>
      <div className="omega-sky" aria-hidden="true">
        <div className="omega-stars" />
        <div className="omega-command-nebula" />
        <Suspense fallback={null}><OmegaGlobe key={omegaQuality} quality={omegaQuality} mode={omegaMode}
          chapter={omegaChapter} view={omegaView} onViewChange={setOmegaView} /></Suspense>
        <div className="omega-globe" />
        <div className="omega-orbit omega-orbit-one" />
        <div className="omega-orbit omega-orbit-two" />
        <div className="omega-command-terminator" />
      </div>
      <div className="omega-copy">
        <p className="brand-eyebrow omega-command-eyebrow">OSGARD WORLD <span>/ ЦИФРОВАЯ ВСЕЛЕННАЯ</span></p>
        <h1 id="world-title">ТЕХНОЛОГИИ,<br/><span>КОТОРЫЕ</span><br/>СОЕДИНЯЮТ<br/>МИРЫ<span className="omega-period">.</span></h1>
        <p className="brand-lead">Искусственный интеллект, интерактивные миры и создание цифровых продуктов. Три понятных направления — одна вселенная OSGARD.</p>
        <div className="brand-actions omega-command-actions">
          <a className="brand-button primary" href="#products">Исследовать экосистему <span aria-hidden="true">↗</span></a>
          <a className="brand-button omega-command-secondary" href="/play">Перейти в Play <span aria-hidden="true">↗</span></a>
        </div>
        <p className="omega-command-promise">ПОНИМАТЬ ИИ <span>•</span> ИГРАТЬ <span>•</span> СОЗДАВАТЬ</p>
      </div>
      <p className="omega-command-planet-caption">BLUE MARBLE / ЗЕМЛЯ <span>NASA · СПУТНИКОВАЯ ТЕКСТУРА</span></p>
      <nav className="omega-gate" aria-label="Три направления экосистемы">
        <p className="brand-eyebrow">ВЫБЕРИ СВОЙ ПУТЬ <span>01—03 / OSGARD</span></p>
        <a href="/intelligence">
          <span className="omega-glyph" aria-hidden="true">◇</span>
          <span><small>01 / ЗНАНИЯ</small><strong>OSA Intelligence</strong><em>Понимай ИИ, проверяй ответы и учись.</em></span>
          <b aria-hidden="true">↗</b>
        </a>
        <a href="/play">
          <span className="omega-glyph" aria-hidden="true">✦</span>
          <span><small>02 / ИГРОВЫЕ МИРЫ</small><strong>OSGARD Play</strong><em>Выбирай мир, открывай игру, исследуй.</em></span>
          <b aria-hidden="true">↗</b>
        </a>
        <a href="/development">
          <span className="omega-glyph" aria-hidden="true">⌘</span>
          <span><small>03 / ПРОЕКТЫ</small><strong>Development</strong><em>Смотри реальные проекты и их возможности.</em></span>
          <b aria-hidden="true">↗</b>
        </a>
      </nav>
      <details className="omega-experience-panel" aria-label="Настройки 3D-глобуса">
        <summary><span className="omega-settings-mark" aria-hidden="true">◈</span> Настройки планеты <span className="omega-settings-chevron" aria-hidden="true">⌄</span></summary>
        <div className="omega-experience-content">
          <div className="omega-experience-title"><span>ГЛОБУС / РЕЖИМ ПРОСМОТРА</span><span className="omega-experience-live"><span aria-hidden="true" /> СЦЕНА</span></div>
          <div className="omega-mode-tabs" role="group" aria-label="Выберите режим 3D-сцены">
            <button type="button" aria-pressed={omegaMode === 'cinema'} onClick={() => setOmegaMode('cinema')}>Кино</button>
            <button type="button" aria-pressed={omegaMode === 'world'} onClick={() => setOmegaMode('world')}>3D-мир</button>
            <button type="button" aria-pressed={omegaMode === 'hybrid'} onClick={() => setOmegaMode('hybrid')}>Гибрид</button>
          </div>
          <p className="omega-mode-description" aria-live="polite">{omegaHelp[omegaMode]}</p>
          <div className="omega-quality-switch">
            <label htmlFor="omega-quality">Детализация 3D</label>
            <select id="omega-quality" value={omegaQuality} onChange={event => setOmegaQuality(event.target.value as GlobeQuality)}
              aria-label="Качество 3D-глобуса">
              <option value="auto">Авто · оптимально</option>
              <option value="eco">Экономно · быстрый режим</option>
              <option value="ultra">Ультра · до 4K текстур</option>
            </select>
          </div>
          {omegaMode === 'cinema' && <div className="omega-cinema-chapters" role="group" aria-label="Кинематографические главы">
            {omegaChapters.map((name, index) => <button type="button" key={name} aria-pressed={omegaChapter === index}
              onClick={() => setOmegaChapter(index as GlobeChapter)}>{String(index + 1).padStart(2, '0')} / {name}</button>)}
          </div>}
          {omegaMode === 'world' && <div className="omega-world-navigation" role="group" aria-label="Управление вращением и масштабом глобуса">
            <button type="button" onClick={() => moveWorld('left')} aria-label="Повернуть Землю влево">←</button>
            <button type="button" onClick={() => moveWorld('right')} aria-label="Повернуть Землю вправо">→</button>
            <button type="button" onClick={() => moveWorld('closer')} aria-label="Приблизить глобус">+</button>
            <button type="button" onClick={() => moveWorld('farther')} aria-label="Отдалить глобус">−</button>
            <button type="button" onClick={() => moveWorld('reset')} className="omega-reset-view">Сбросить</button>
          </div>}
          <p className="omega-imagery-credit">Земля: <a href="https://science.nasa.gov/earth/earth-observatory/blue-marble-next-generation/base-map/" target="_blank" rel="noreferrer">NASA Blue Marble ↗</a> · ночные огни 2016 · облака процедурные. Это визуализация, не прямой эфир.</p>
        </div>
      </details>
    </section>
    <section id="products" className="brand-section omega-products" aria-labelledby="world-products-title">
      <div className="brand-section-heading"><p className="brand-eyebrow">01 / НАПРАВЛЕНИЯ OSGARD</p><h2 id="world-products-title">ТРИ МИРА. <span>ОДНА ВСЕЛЕННАЯ.</span></h2><p>Выбери свой путь. Каждое направление показывает конкретные возможности, доступные действия и ограничения.</p></div>
      <div className="omega-cards">
        <a href="/intelligence" className="omega-card"><div className="omega-card-art"><img src="/brand/omega-osa.svg" alt="Голографическое интеллектуальное ядро с нейронными связями" loading="lazy"/><small>01 / ИНТЕЛЛЕКТ</small></div><div className="omega-card-content"><h3>OSA <span>Intelligence</span></h3><p>Разберись в возможностях ИИ, научись проверять ответы и применять знания на практике.</p><strong>Начать обучение <span aria-hidden="true">↗</span></strong></div></a>
        <a href="/play" className="omega-card"><div className="omega-card-art"><img src="/brand/omega-play.svg" alt="Футуристический цифровой город и игровой портал" loading="lazy"/><small>02 / ИГРОВЫЕ МИРЫ</small></div><div className="omega-card-content"><h3>OSGARD <span>Play</span></h3><p>Исследуй интерактивные миры, открывай доступные игры и игровые эксперименты.</p><strong>Исследовать игры <span aria-hidden="true">↗</span></strong></div></a>
        <a href="/development" className="omega-card"><div className="omega-card-art"><img src="/brand/omega-development.svg" alt="Голографические 3D-кубы и архитектура программных продуктов" loading="lazy"/><small>03 / РАЗРАБОТКА</small></div><div className="omega-card-content"><h3>OSGARD <span>Development</span></h3><p>Изучи настоящие демонстрации интерфейсов, кейсы и подход к созданию продуктов.</p><strong>Смотреть проекты <span aria-hidden="true">↗</span></strong></div></a>
      </div>
      <div className="world-workspace-link"><p>Работаешь над своей идеей? Собери план и материалы в одном месте.</p><a className="brand-text-link" href="/workspace">Открыть рабочее пространство ↗</a></div>
    </section>
    </>}
    <section id="cases" className="brand-section" aria-labelledby="world-cases-title">
      <div className="brand-section-heading"><p className="brand-eyebrow">02 / ИЗБРАННЫЕ ПРОЕКТЫ</p><h2 id="world-cases-title">У каждой задачи<br />свой характер.</h2><p>Откройте кейс: посмотрите интерфейс, доступные возможности и стадию проекта. Статус указан на каждой карточке.</p></div>
      <div className="world-case-grid">{cases.map((item, index) => <a href={item.href} className="world-case" key={item.id}>
        <div className="world-case-art" style={item.visual === 'screenshot' ? { aspectRatio: '3 / 2' } : undefined}><img src={item.art} alt={(item.visual === 'screenshot' ? 'Снимок публичной страницы кейса ' : 'Визуальное превью ') + item.name} width="1200" height={item.visual === 'screenshot' ? 800 : 630} loading="lazy" decoding="async" /><span className="brand-status">{item.type}</span></div>
        <div className="world-case-title"><span>0{index + 1} / {item.category}</span><h3>{item.name} <span aria-hidden="true">↗</span></h3><p>{item.description}</p><span className="world-case-open">Открыть кейс <span aria-hidden="true">→</span></span></div>
      </a>)}</div>
      <p className="world-case-legend"><strong>Как читать статусы.</strong> Концепт показывает направление. Демо позволяет попробовать сценарий. Прототип проверяет часть продукта. Коммерческий запуск требует отдельного подтверждения. PHANTOM, TEDES и MERAKKI показаны на реальных снимках публичных страниц кейсов. ESSENTIA — визуальное превью. Снимки не подтверждают работу сервера или коммерческий запуск.</p>
    </section>

    <section id="approach" className="brand-section" aria-labelledby="world-approach-title">
      <div className="brand-section-heading"><p className="brand-eyebrow">03 / ПОДХОД</p><h2 id="world-approach-title">Сначала смысл.<br />Потом — каждый пиксель.</h2></div>
      <ol className="world-process">{process.map(([name, description], index) => <li key={name}><span>0{index + 1}</span><h3>{name}</h3><p>{description}</p></li>)}</ol>
    </section>

    <section id="about" className="brand-section world-about" aria-labelledby="world-about-title">
      <p className="brand-eyebrow">04 / О СТУДИИ И РЕЗУЛЬТАТАХ</p><h2 id="world-about-title">Работу можно<br />проверить.</h2>
      <div><p>OSGARD объединяет разработку цифровых продуктов, обучение и интерактивные эксперименты. Для каждого направления мы показываем доступный сценарий и его ограничения.</p>
        <ul><li><a href="/learning/project">Редактор учебного проекта</a> — цель, план, локальное сохранение и перенос в JSON.</li><li><a href="/tedes/project/">Проектная спецификация TEDES</a> — подбор и сохранение конфигурации в браузере.</li><li><a href="/play/world/vector-zero">VECTOR//ZERO</a> — одиночный игровой клиент с инструкцией и управлением.</li></ul>
        <p>Откройте сценарий и попробуйте действие. Доступность конкретной функции указана на её странице.</p><a className="brand-text-link" href="/quality">Состояние функций и сборки <span aria-hidden="true">→</span></a>
      </div>
    </section>

    <section id="contact" className="brand-section world-contact" aria-labelledby="world-contact-title">
      <div><p className="brand-eyebrow">05 / СЛЕДУЮЩИЙ ШАГ</p><h2 id="world-contact-title">Начнём<br />с вашей задачи.</h2>
        <p>Опишите цель, аудиторию и желаемый результат. Скачайте бриф и приложите его к письму на адрес ниже. Это подготовка заявки: форма сама ничего не отправляет.</p>
        <a href="mailto:osman.osmanov0099@gmail.com" onClick={() => recordBrandEvent('contact_opened')}>osman.osmanov0099@gmail.com <span aria-hidden="true">↗</span></a>
        <p className="world-contact-next">Первое обсуждение — задача, объём и следующий шаг. Сроки и стоимость определяются после разбора брифа.</p>
      </div>
      <form noValidate onSubmit={event => { event.preventDefault(); const problem = validateEnquiry(brief, contact); if (problem) { setError(problem); briefInput.current?.focus(); return } download() }}>
        <label htmlFor="project-brief">Что хотите создать?</label>
        <p id="brief-help" className="brand-field-help">Для кого продукт, какую задачу решает, что уже есть. От 20 до 5000 символов.</p>
        <textarea id="project-brief" name="project-brief" ref={briefInput} aria-invalid={Boolean(error)} aria-describedby="brief-help brief-feedback" required minLength={20} maxLength={5000} value={brief} onChange={event => { setBrief(event.target.value); setSaved(false); setError('') }} placeholder="Например: сервис записи для небольшого клуба. Нужно показать расписание и собирать заявки…" rows={5} />
        <label htmlFor="project-contact">Как с вами связаться? <span>(необязательно)</span></label>
        <input id="project-contact" name="project-contact" value={contact} maxLength={250} onChange={event => { setContact(event.target.value); setSaved(false) }} autoComplete="off" aria-describedby="contact-help" placeholder="Телефон, почта или удобный мессенджер" />
        <p id="contact-help" className="brand-field-help">Контакт попадёт только в скачанный файл.</p>
        <button type="submit" className="brand-button primary">Скачать бриф <span aria-hidden="true">↓</span></button>
        <p id="brief-feedback" className={error ? 'brand-form-feedback is-error' : 'brand-form-feedback'} role={error ? 'alert' : 'status'}>{error || (saved ? 'Файл подготовлен. Заявка не отправлена — приложите бриф к письму.' : 'Данные формы не передаются на сервер и не сохраняются автоматически.')}</p>
        {saved && <a className="brand-text-link" href="mailto:osman.osmanov0099@gmail.com?subject=Проект%20для%20OSGARD" onClick={() => recordBrandEvent('contact_opened')}>Открыть письмо и приложить файл <span aria-hidden="true">↗</span></a>}
      </form>
    </section>
  </main>
}
