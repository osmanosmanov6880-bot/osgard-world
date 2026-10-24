import { lazy, Suspense, useEffect, useRef, useState } from 'react'
import type { KeyboardEvent as ReactKeyboardEvent } from 'react'
import { Globe2 } from 'lucide-react'
import './omegaWorld.css'
import './developmentSignature.css'
import { cases } from './featuredCases'
import { BrandMark } from './BrandMark'
import { formatEnquiry, validateEnquiry } from './projectEnquiry'
import { recordBrandEvent } from './brandTelemetry'
import { MOTION_CHANGE_EVENT } from './osgardRouting'
import type { GlobeChapter, GlobeMode, GlobeView, GlobeQuality } from './OmegaGlobe'

const OmegaGlobe = lazy(() => import('./OmegaGlobe'))
type Locale = 'ru' | 'en'
const readWorldLocale = (): Locale => { try { return localStorage.getItem('osa:locale') === 'en' ? 'en' : 'ru' } catch { return 'ru' } }

const readOmegaMode = (): GlobeMode => {
  try {
    const value = localStorage.getItem('osgard:omega-world-mode')
    return value === 'cinema' || value === 'world' || value === 'hybrid' ? value : 'hybrid'
  } catch { return 'hybrid' }
}
const preferStillWorld = () => {
  if (typeof window === 'undefined') return false
  if (window.matchMedia?.('(prefers-reduced-motion: reduce)').matches) return true
  if (document.documentElement.dataset.motion === 'off') return true
  try { if (localStorage.getItem('osgard:motion') === 'off') return true } catch { /* Browsers can restrict storage. */ }
  return Boolean((navigator as Navigator & { connection?: { saveData?: boolean } }).connection?.saveData)
}

const omegaChapters = (locale: Locale) => locale === 'ru' ? ['Планета', 'Связи', 'Миры'] as const : ['Earth', 'Connections', 'Worlds'] as const
const omegaHelpRu: Record<GlobeMode, string> = {
  cinema: 'Камера сама показывает Землю с разных ракурсов. Выберите главу или перейдите к продуктам.',
  world: 'Вращайте планету мышью или горизонтальным свайпом. Масштаб — колёсиком или кнопками. Остальные разделы доступны сразу.',
  hybrid: 'Живой 3D-глобус работает на фоне, а все разделы и кнопки остаются на переднем плане.',
}
const omegaHelpEn: Record<GlobeMode, string> = {
  cinema: 'The camera presents Earth from several angles. Choose a chapter or explore the products below.',
  world: 'Rotate Earth with a mouse or horizontal swipe. Zoom with the wheel or controls. Other sections remain available.',
  hybrid: 'The live 3D globe runs in the background while content and controls stay in the foreground.',
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
  const [locale, setLocale] = useState<Locale>(readWorldLocale)
  // Fetch long-form English copy only when needed to keep the initial route within its gzip budget.
  const [englishCopy, setEnglishCopy] = useState<Record<string, string> | null>(null)
  useEffect(() => {
    if (locale !== 'en' || englishCopy) return
    let current = true
    void import('./worldHomeEnglish').then(module => { if (current) setEnglishCopy(module.default) })
    return () => { current = false }
  }, [locale, englishCopy])
  const tx = (ru: string) => locale === 'ru' ? ru : englishCopy?.[ru] || ru
  const txCase = (id: string, field: 'type' | 'category' | 'description') => englishCopy?.[`case.${id}.${field}`]
  const changeLocale = () => {
    const next: Locale = locale === 'ru' ? 'en' : 'ru'
    setLocale(next)
    try { localStorage.setItem('osa:locale', next) } catch { /* Language choice is optional. */ }
    window.dispatchEvent(new Event('osgard:locale-change'))
  }
  const [omegaMode, setOmegaMode] = useState<GlobeMode>(readOmegaMode)
  const [omegaChapter, setOmegaChapter] = useState<GlobeChapter>(0)
  const [omegaQuality, setOmegaQuality] = useState<GlobeQuality>('auto')
  const [omegaView, setOmegaView] = useState<GlobeView>({ yaw: 0, pitch: -0.14, distance: 5.7 })
  // Reduced-motion and Save-Data visitors should never fetch the 3D chunk.
  // The existing NASA satellite globe remains a usable photographic fallback.
  const [stillWorld, setStillWorld] = useState(preferStillWorld)
  useEffect(() => {
    const media = window.matchMedia?.('(prefers-reduced-motion: reduce)')
    const connection = (navigator as Navigator & { connection?: EventTarget & { saveData?: boolean } }).connection
    const sync = () => setStillWorld(preferStillWorld())
    media?.addEventListener?.('change', sync)
    connection?.addEventListener?.('change', sync)
    window.addEventListener(MOTION_CHANGE_EVENT, sync)
    window.addEventListener('storage', sync)
    sync()
    return () => {
      media?.removeEventListener?.('change', sync)
      connection?.removeEventListener?.('change', sync)
      window.removeEventListener(MOTION_CHANGE_EVENT, sync)
      window.removeEventListener('storage', sync)
    }
  }, [])
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
    } catch { setError(locale === 'ru' ? 'Не удалось создать файл. Скопируйте описание задачи и отправьте его на указанный адрес.' : 'Could not create the file. Copy the project description and email it to the address above.') }
  }

  return <main lang={locale} className={development ? 'world-home brand-container development-signature' : 'world-home brand-container world-command'}>
    {development ? <>
      <section className="omega-dev-hero signature-hero" aria-labelledby="world-title">
        <div className="omega-dev-hero-art" aria-hidden="true">
          <img src="/brand/omega-development.svg" width="1600" height="1000" alt="" decoding="async" />
          <span className="omega-dev-orbit omega-dev-orbit-a" />
          <span className="omega-dev-orbit omega-dev-orbit-b" />
        </div>
        <div className="omega-dev-intro signature-intro">
          <div className="world-locale-row"><p className="brand-eyebrow">OSGARD / DEVELOPMENT / DIGITAL CRAFT</p><button type="button" className="world-language-toggle" onClick={changeLocale} aria-label={locale === 'ru' ? 'Switch language to English' : 'Переключить язык на русский'}><Globe2 size={15} aria-hidden="true" />{locale === 'ru' ? 'EN' : 'RU'}</button></div>
          <h1 id="world-title">{locale === 'ru' ? <>СОЗДАЁМ<br /><span>ЦИФРОВЫЕ</span><br />РЕШЕНИЯ.</> : <>WE BUILD<br /><span>DIGITAL</span><br />PRODUCTS.</>}</h1>
          <p className="brand-lead">{tx("От первых сценариев до открытых демонстраций. Показываем настоящие интерфейсы, рабочие действия и честный статус каждого проекта.")}</p>
          <div className="brand-actions signature-hero-actions">
            <a className="brand-button primary" href="#cases">{tx("Смотреть проекты")} <span aria-hidden="true">↗</span></a>
            <a className="brand-button signature-secondary" href="#contact">{tx("Обсудить разработку")} <span aria-hidden="true">→</span></a>
          </div>
          <div className="signature-hero-facts" aria-label={tx("Принципы разработки")}>
            <span><strong>{cases.length}</strong><small>{tx("публичных кейса")}</small></span>
            <span><strong>UX → CODE</strong><small>{tx("дизайн и реализация")}</small></span>
            <span><strong>OPEN DEMOS</strong><small>{tx("посмотрите сами")}</small></span>
          </div>
          <p className="signature-caption">{tx("ПРОТОТИПЫ · КОНФИГУРАТОРЫ · ЦИФРОВЫЕ ПРОДУКТЫ")}</p>
        </div>
        <div className="signature-showcase" aria-label="Демонстрация работ студии">
          <div className="signature-showcase-top"><span>SELECTED WORK / 2026</span><span>01 — 03 / 04</span></div>
          <a className="signature-featured-case" href={cases[1].href}>
            <div className="signature-featured-image">
              <img src={cases[1].art} width="1200" height="800" alt={tx("Скриншот открытого проекта ") + cases[1].name}
                decoding="async" fetchPriority="high" />
              <span>{locale === 'en' ? txCase(cases[1].id, 'type') : cases[1].type} / 02</span>
            </div>
            <div className="signature-featured-copy">
              <div><small>{tx("АРХИТЕКТУРА / КОНФИГУРАТОР")}</small><strong>{cases[1].name}</strong></div>
              <span>{tx("Открыть кейс")} <b aria-hidden="true">↗</b></span>
            </div>
          </a>
          <div className="signature-case-pair" aria-label={tx("Другие проекты")}>
            {[cases[0],cases[2]].map((item) => <a key={item.id} href={item.href}>
              <img src={item.art} alt={tx("Скриншот проекта ") + item.name} width="380" height="255"
                loading="lazy" decoding="async" />
              <span><small>{locale === 'en' ? txCase(item.id, 'type') : item.type}</small><strong>{item.name}</strong></span>
              <b aria-hidden="true">↗</b>
            </a>)}
          </div>
          <p className="signature-showcase-note">{tx("Снимки публичных страниц. Демо не подтверждает работу серверов, продаж или коммерческий запуск.")}</p>
        </div>
      </section>
      <section id="products" className="brand-section omega-dev-capabilities" aria-labelledby="dev-capabilities-title">
        <div className="brand-section-heading"><p className="brand-eyebrow">{tx("01 / ЧТО МЫ ДЕЛАЕМ")}</p><h2 id="dev-capabilities-title">{locale === 'ru' ? <>АРХИТЕКТУРА. <span>ДИЗАЙН. КОД.</span></> : <>ARCHITECTURE. <span>DESIGN. CODE.</span></>}</h2><p>{tx("Начинаем с задачи, показываем логику продукта и доступную реализацию. Без выдуманных результатов и обещаний несуществующих функций.")}</p></div>
        <div className="omega-dev-capability-grid">
          <a href="#cases"><span>01 / UX & PRODUCT</span><strong>{tx("Интерфейсы и сценарии")}</strong><p>{tx("Понятная структура, удобная навигация, адаптация и доступность.")}</p><em>{tx("Смотреть кейсы")} ↗</em></a>
          <a href="/development/tedes/"><span>02 / PROTOTYPES</span><strong>{tx("Конфигураторы и инструменты")}</strong><p>{tx("Изучите демонстрацию TEDES с локальной проектной спецификацией.")}</p><em>{tx("Открыть TEDES")} ↗</em></a>
          <a href="#contact"><span>03 / ENGINEERING</span><strong>{tx("Разработка и проверка")}</strong><p>{tx("Обсуждаем требования, реализуем необходимые функции и проверяем результат.")}</p><em>{tx("Обсудить задачу")} ↗</em></a>
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
        {!stillWorld && <Suspense fallback={null}><OmegaGlobe key={omegaQuality} quality={omegaQuality} mode={omegaMode}
          chapter={omegaChapter} view={omegaView} onViewChange={setOmegaView} /></Suspense>}
        <div className="omega-globe" />
        <div className="omega-orbit omega-orbit-one" />
        <div className="omega-orbit omega-orbit-two" />
        <div className="omega-command-terminator" />
      </div>
      <div className="omega-copy">
        <div className="world-locale-row"><p className="brand-eyebrow omega-command-eyebrow">OSGARD WORLD <span>/ {tx("ЦИФРОВАЯ ВСЕЛЕННАЯ")}</span></p><button type="button" className="world-language-toggle" onClick={changeLocale} aria-label={locale === 'ru' ? 'Switch language to English' : 'Переключить язык на русский'}><Globe2 size={15} aria-hidden="true" />{locale === 'ru' ? 'EN' : 'RU'}</button></div>
        <h1 id="world-title">{locale === 'ru' ? <>ТЕХНОЛОГИИ,<br/><span>КОТОРЫЕ</span><br/>СОЕДИНЯЮТ<br/>МИРЫ</> : <>TECHNOLOGY<br/><span>THAT</span><br/>CONNECTS<br/>WORLDS</>}<span className="omega-period">.</span></h1>
        <p className="brand-lead">{tx("Искусственный интеллект, интерактивные миры и создание цифровых продуктов. Три понятных направления — одна вселенная OSGARD.")}</p>
        <div className="brand-actions omega-command-actions">
          <a className="brand-button primary" href="#products">{tx("Исследовать экосистему")} <span aria-hidden="true">↗</span></a>
          <a className="brand-button omega-command-secondary" href="/play">{tx("Перейти в Play")} <span aria-hidden="true">↗</span></a>
        </div>
        <p className="omega-command-promise">{tx("ПОНИМАТЬ ИИ")} <span>•</span> {tx("ИГРАТЬ")} <span>•</span> {tx("СОЗДАВАТЬ")}</p>
      </div>
      <p className="omega-command-planet-caption">BLUE MARBLE / {tx("ЗЕМЛЯ")} <span>NASA · {tx("СПУТНИКОВАЯ ТЕКСТУРА")}</span></p>
      <nav className="omega-gate" aria-label={tx("Три направления экосистемы")}>
        <p className="brand-eyebrow">{tx("ВЫБЕРИ СВОЙ ПУТЬ")} <span>01—03 / OSGARD</span></p>
        <a href="/intelligence">
          <span className="omega-glyph" aria-hidden="true">◇</span>
          <span><small>01 / {tx("ЗНАНИЯ")}</small><strong>OSA Intelligence</strong><em>{tx("Понимай ИИ, проверяй ответы и учись.")}</em></span>
          <b aria-hidden="true">↗</b>
        </a>
        <a href="/play">
          <span className="omega-glyph" aria-hidden="true">✦</span>
          <span><small>02 / {tx("ИГРОВЫЕ МИРЫ")}</small><strong>OSGARD Play</strong><em>{tx("Выбирай мир, открывай игру, исследуй.")}</em></span>
          <b aria-hidden="true">↗</b>
        </a>
        <a href="/development">
          <span className="omega-glyph" aria-hidden="true">⌘</span>
          <span><small>03 / {tx("ПРОЕКТЫ")}</small><strong>Development</strong><em>{tx("Смотри реальные проекты и их возможности.")}</em></span>
          <b aria-hidden="true">↗</b>
        </a>
      </nav>
      <details className="omega-experience-panel" aria-label={tx("Настройки 3D-глобуса")}>
        <summary><span className="omega-settings-mark" aria-hidden="true">◈</span> {tx("Настройки планеты")} <span className="omega-settings-chevron" aria-hidden="true">⌄</span></summary>
        <div className="omega-experience-content">
          <div className="omega-experience-title"><span>{tx("ГЛОБУС / РЕЖИМ ПРОСМОТРА")}</span><span className="omega-experience-live"><span aria-hidden="true" /> {tx("СЦЕНА")}</span></div>
          <div className="omega-mode-tabs" role="group" aria-label={tx("Выберите режим 3D-сцены")}>
            <button type="button" aria-pressed={omegaMode === 'cinema'} onClick={() => setOmegaMode('cinema')}>{tx("Кино")}</button>
            <button type="button" aria-pressed={omegaMode === 'world'} onClick={() => setOmegaMode('world')}>{tx("3D-мир")}</button>
            <button type="button" aria-pressed={omegaMode === 'hybrid'} onClick={() => setOmegaMode('hybrid')}>{tx("Гибрид")}</button>
          </div>
          <p className="omega-mode-description" aria-live="polite">{(locale === 'ru' ? omegaHelpRu : omegaHelpEn)[omegaMode]}</p>
          {stillWorld && <p className="omega-mode-description" role="status">{tx("Режим экономии ресурсов: отображается фотография Земли. 3D станет доступно, когда в устройстве и OSGARD разрешено движение и выключена экономия трафика.")}</p>}
          <div className="omega-quality-switch">
            <label htmlFor="omega-quality">{tx("Детализация 3D")}</label>
            <select id="omega-quality" value={omegaQuality} disabled={stillWorld} onChange={event => setOmegaQuality(event.target.value as GlobeQuality)}
              aria-label={tx("Качество 3D-глобуса")}>
              <option value="auto">{tx("Авто · оптимально")}</option>
              <option value="eco">{tx("Экономно · быстрый режим")}</option>
              <option value="ultra">{tx("Ультра · до 4K текстур")}</option>
            </select>
          </div>
          {omegaMode === 'cinema' && <div className="omega-cinema-chapters" role="group" aria-label={tx("Кинематографические главы")}>
            {omegaChapters(locale).map((name, index) => <button type="button" key={name} aria-pressed={omegaChapter === index}
              onClick={() => setOmegaChapter(index as GlobeChapter)}>{String(index + 1).padStart(2, '0')} / {name}</button>)}
          </div>}
          {omegaMode === 'world' && <div className="omega-world-navigation" role="group" aria-label={tx("Управление вращением и масштабом глобуса")}>
            <button type="button" onClick={() => moveWorld('left')} aria-label={tx("Повернуть Землю влево")}>←</button>
            <button type="button" onClick={() => moveWorld('right')} aria-label={tx("Повернуть Землю вправо")}>→</button>
            <button type="button" onClick={() => moveWorld('closer')} aria-label={tx("Приблизить глобус")}>+</button>
            <button type="button" onClick={() => moveWorld('farther')} aria-label={tx("Отдалить глобус")}>−</button>
            <button type="button" onClick={() => moveWorld('reset')} className="omega-reset-view">{tx("Сбросить")}</button>
          </div>}
          <p className="omega-imagery-credit">{tx("Земля:")} <a href="https://science.nasa.gov/earth/earth-observatory/blue-marble-next-generation/base-map/" target="_blank" rel="noreferrer">NASA Blue Marble ↗</a> · {tx("ночные огни 2016 · облака процедурные. Это визуализация, не прямой эфир.")}</p>
        </div>
      </details>
    </section>
    <section id="products" className="brand-section omega-products" aria-labelledby="world-products-title">
      <div className="brand-section-heading"><p className="brand-eyebrow">{tx("01 / НАПРАВЛЕНИЯ OSGARD")}</p><h2 id="world-products-title">{locale === 'ru' ? <>ТРИ МИРА. <span>ОДНА ВСЕЛЕННАЯ.</span></> : <>THREE WORLDS. <span>ONE ECOSYSTEM.</span></>}</h2><p>{tx("Выбери свой путь. Каждое направление показывает конкретные возможности, доступные действия и ограничения.")}</p></div>
      <div className="omega-cards">
        <a href="/intelligence" className="omega-card"><div className="omega-card-art"><img src="/brand/omega-osa.svg" alt={tx("Голографическое интеллектуальное ядро с нейронными связями")} loading="lazy"/><small>01 / {tx("ИНТЕЛЛЕКТ")}</small></div><div className="omega-card-content"><h3>OSA <span>Intelligence</span></h3><p>{tx("Разберись в возможностях ИИ, научись проверять ответы и применять знания на практике.")}</p><strong>{tx("Начать обучение")} <span aria-hidden="true">↗</span></strong></div></a>
        <a href="/play" className="omega-card"><div className="omega-card-art"><img src="/brand/omega-play.svg" alt={tx("Футуристический цифровой город и игровой портал")} loading="lazy"/><small>02 / {tx("ИГРОВЫЕ МИРЫ")}</small></div><div className="omega-card-content"><h3>OSGARD <span>Play</span></h3><p>{tx("Исследуй интерактивные миры, открывай доступные игры и игровые эксперименты.")}</p><strong>{tx("Исследовать игры")} <span aria-hidden="true">↗</span></strong></div></a>
        <a href="/development" className="omega-card"><div className="omega-card-art"><img src="/brand/omega-development.svg" alt={tx("Голографические 3D-кубы и архитектура программных продуктов")} loading="lazy"/><small>03 / {tx("РАЗРАБОТКА")}</small></div><div className="omega-card-content"><h3>OSGARD <span>Development</span></h3><p>{tx("Изучи настоящие демонстрации интерфейсов, кейсы и подход к созданию продуктов.")}</p><strong>Смотреть проекты <span aria-hidden="true">↗</span></strong></div></a>
      </div>
      <div className="world-workspace-link"><p>{tx("Работаешь над своей идеей? Собери план и материалы в одном месте.")}</p><a className="brand-text-link" href="/workspace">{tx("Открыть рабочее пространство")} ↗</a></div>
    </section>
    </>}
    <section id="cases" className="brand-section" aria-labelledby="world-cases-title">
      <div className="brand-section-heading"><p className="brand-eyebrow">{tx("02 / ИЗБРАННЫЕ ПРОЕКТЫ")}</p><h2 id="world-cases-title">{locale === 'ru' ? <>У каждой задачи<br />свой характер.</> : <>EVERY PROJECT<br />HAS ITS OWN CHARACTER.</>}</h2><p>{tx("Откройте кейс: посмотрите интерфейс, доступные возможности и стадию проекта. Статус указан на каждой карточке.")}</p></div>
      <div className="world-case-grid">{cases.map((item, index) => <a href={item.href} className="world-case" key={item.id}>
        <div className="world-case-art" style={item.visual === 'screenshot' ? { aspectRatio: '3 / 2' } : undefined}><img src={item.art} alt={(item.visual === 'screenshot' ? tx("Снимок публичной страницы кейса ") : tx("Визуальное превью ")) + item.name} width="1200" height={item.visual === 'screenshot' ? 800 : 630} loading="lazy" decoding="async" /><span className="brand-status">{locale === 'en' ? txCase(item.id, 'type') || item.type : item.type}</span></div>
        <div className="world-case-title"><span>0{index + 1} / {locale === 'en' ? txCase(item.id, 'category') || item.category : item.category}</span><h3>{item.name} <span aria-hidden="true">↗</span></h3><p>{locale === 'en' ? txCase(item.id, 'description') || item.description : item.description}</p><span className="world-case-open">{tx("Открыть кейс")} <span aria-hidden="true">→</span></span></div>
      </a>)}</div>
      <p className="world-case-legend"><strong>{tx("Как читать статусы.")}</strong> {tx("Концепт показывает направление. Демо позволяет попробовать сценарий. Прототип проверяет часть продукта. Коммерческий запуск требует отдельного подтверждения. PHANTOM, TEDES и MERAKKI показаны на реальных снимках публичных страниц кейсов. ESSENTIA — визуальное превью. Снимки не подтверждают работу сервера или коммерческий запуск.")}</p>
    </section>

    <section id="approach" className="brand-section" aria-labelledby="world-approach-title">
      <div className="brand-section-heading"><p className="brand-eyebrow">{tx("03 / ПОДХОД")}</p><h2 id="world-approach-title">{locale === 'ru' ? <>Сначала смысл.<br />Потом — каждый пиксель.</> : <>MEANING FIRST.<br />THEN EVERY PIXEL.</>}</h2></div>
      <ol className="world-process">{(locale === 'ru' ? process : [['Strategy', 'Clarify the audience, problem and success criteria.'], ['Structure', 'Map user journeys and the main action on each screen.'], ['Design', 'Choose a visual language that serves the product.'], ['Development', 'Build the interface, states and data persistence.'], ['Launch', 'Check the build, dependencies and infrastructure readiness.']]).map(([name, description], index) => <li key={name}><span>0{index + 1}</span><h3>{name}</h3><p>{description}</p></li>)}</ol>
    </section>

    <section id="about" className="brand-section world-about" aria-labelledby="world-about-title">
      <p className="brand-eyebrow">{tx("04 / О СТУДИИ И РЕЗУЛЬТАТАХ")}</p><h2 id="world-about-title">{locale === 'ru' ? <>Работу можно<br />проверить.</> : <>WORK YOU CAN<br />VERIFY.</>}</h2>
      <div><p>{tx("OSGARD объединяет разработку цифровых продуктов, обучение и интерактивные эксперименты. Для каждого направления мы показываем доступный сценарий и его ограничения.")}</p>
        <ul><li><a href="/learning/project">{tx("Редактор учебного проекта")}</a> — {tx("цель, план, локальное сохранение и перенос в JSON.")}</li><li><a href="/tedes/project/">{tx("Проектная спецификация TEDES")}</a> — {tx("подбор и сохранение конфигурации в браузере.")}</li><li><a href="/play/world/vector-zero">VECTOR//ZERO</a> — {tx("одиночный игровой клиент с инструкцией и управлением.")}</li></ul>
        <p>{tx("Откройте сценарий и попробуйте действие. Доступность конкретной функции указана на её странице.")}</p><a className="brand-text-link" href="/quality">{tx("Состояние функций и сборки")} <span aria-hidden="true">→</span></a>
      </div>
    </section>

    <section id="contact" className="brand-section world-contact" aria-labelledby="world-contact-title">
      <div><p className="brand-eyebrow">{tx("05 / СЛЕДУЮЩИЙ ШАГ")}</p><h2 id="world-contact-title">{locale === 'ru' ? <>Начнём<br />с вашей задачи.</> : <>LET’S START<br />WITH YOUR PROJECT.</>}</h2>
        <p>{tx("Опишите цель, аудиторию и желаемый результат. Скачайте бриф и приложите его к письму на адрес ниже. Это подготовка заявки: форма сама ничего не отправляет.")}</p>
        <a href="mailto:osman.osmanov0099@gmail.com" onClick={() => recordBrandEvent('contact_opened')}>osman.osmanov0099@gmail.com <span aria-hidden="true">↗</span></a>
        <p className="world-contact-next">{tx("Первое обсуждение — задача, объём и следующий шаг. Сроки и стоимость определяются после разбора брифа.")}</p>
      </div>
      <form noValidate onSubmit={event => { event.preventDefault(); const problem = validateEnquiry(brief, contact); if (problem) { setError(problem); briefInput.current?.focus(); return } download() }}>
        <label htmlFor="project-brief">{tx("Что хотите создать?")}</label>
        <p id="brief-help" className="brand-field-help">{tx("Для кого продукт, какую задачу решает, что уже есть. От 20 до 5000 символов.")}</p>
        <textarea id="project-brief" name="project-brief" ref={briefInput} aria-invalid={Boolean(error)} aria-describedby="brief-help brief-feedback" required minLength={20} maxLength={5000} value={brief} onChange={event => { setBrief(event.target.value); setSaved(false); setError('') }} placeholder={tx("Например: сервис записи для небольшого клуба. Нужно показать расписание и собирать заявки…")} rows={5} />
        <label htmlFor="project-contact">{tx("Как с вами связаться?")} <span>({tx("необязательно")})</span></label>
        <input id="project-contact" name="project-contact" value={contact} maxLength={250} onChange={event => { setContact(event.target.value); setSaved(false) }} autoComplete="off" aria-describedby="contact-help" placeholder={tx("Телефон, почта или удобный мессенджер")} />
        <p id="contact-help" className="brand-field-help">{tx("Контакт попадёт только в скачанный файл.")}</p>
        <button type="submit" className="brand-button primary">{tx("Скачать бриф")} <span aria-hidden="true">↓</span></button>
        <p id="brief-feedback" className={error ? 'brand-form-feedback is-error' : 'brand-form-feedback'} role={error ? 'alert' : 'status'}>{error || (saved ? tx("Файл подготовлен. Заявка не отправлена — приложите бриф к письму.") : tx("Данные формы не передаются на сервер и не сохраняются автоматически."))}</p>
        {saved && <a className="brand-text-link" href="mailto:osman.osmanov0099@gmail.com?subject=Проект%20для%20OSGARD" onClick={() => recordBrandEvent('contact_opened')}>{tx("Открыть письмо и приложить файл")} <span aria-hidden="true">↗</span></a>}
      </form>
    </section>
  </main>
}
