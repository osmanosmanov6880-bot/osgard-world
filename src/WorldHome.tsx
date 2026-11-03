import { useEffect, useRef, useState } from 'react'
import { Globe2 } from 'lucide-react'
import './omegaWorld.css'
import './developmentSignature.css'
import { cases } from './featuredCases'
import { BrandMark } from './BrandMark'
import { recordBrandEvent } from './brandTelemetry'

type Locale = 'ru' | 'en'
const readWorldLocale = (): Locale => { try { return localStorage.getItem('osa:locale') === 'en' ? 'en' : 'ru' } catch { return 'ru' } }

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
  const download = (validatedContent: string) => {
    try {
      const blob = new Blob([validatedContent], { type: 'text/plain;charset=utf-8' })
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
          <p className="brand-lead">{tx("От сценариев до демо: работающие экраны и статусы.")}</p>
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
          <p className="signature-showcase-note">{tx("Снимки страниц не доказывают продажи, работу серверов или запуск.")}</p>
        </div>
      </section>
      <section id="products" className="brand-section omega-dev-capabilities" aria-labelledby="dev-capabilities-title">
        <div className="brand-section-heading"><p className="brand-eyebrow">{tx("01 / ЧТО МЫ ДЕЛАЕМ")}</p><h2 id="dev-capabilities-title">{locale === 'ru' ? <>АРХИТЕКТУРА. <span>ДИЗАЙН. КОД.</span></> : <>ARCHITECTURE. <span>DESIGN. CODE.</span></>}</h2><p>{tx("От задачи к понятной логике и рабочей реализации. Без вымышленных результатов.")}</p></div>
        <div className="omega-dev-capability-grid">
          <a href="#cases"><span>01 / UX & PRODUCT</span><strong>{tx("Интерфейсы и сценарии")}</strong><p>{tx("Понятная структура, удобная навигация, адаптация и доступность.")}</p><em>{tx("Смотреть кейсы")} ↗</em></a>
          <a href="/development/tedes/"><span>02 / PROTOTYPES</span><strong>{tx("Конфигураторы и инструменты")}</strong><p>{tx("Изучите демонстрацию TEDES с локальной проектной спецификацией.")}</p><em>{tx("Открыть TEDES")} ↗</em></a>
          <a href="#contact"><span>03 / ENGINEERING</span><strong>{tx("Разработка и проверка")}</strong><p>{tx("Определяем требования, создаём функции и проверяем.")}</p><em>{tx("Обсудить задачу")} ↗</em></a>
        </div>
      </section>
    </> : <>
    <section className="omega-hero omega-portals-hero" data-locale={locale} aria-labelledby="world-title">
      <div className="omega-copy omega-portals-copy">
        <p className="brand-eyebrow omega-portals-eyebrow">OSGARD WORLD <span>/ {locale === 'ru' ? 'ЦИФРОВАЯ ЭКОСИСТЕМА' : 'DIGITAL ECOSYSTEM'}</span></p>
        <h1 id="world-title">
          {locale === 'ru' ? <>СОЗДАЁМ<br /><span>ЦИФРОВЫЕ</span><br />МИРЫ<span className="omega-portals-period">.</span></> : <>WE CREATE<br /><span>DIGITAL</span><br />WORLDS<span className="omega-portals-period">.</span></>}
        </h1>
        <p className="brand-lead">{locale === 'ru' ? 'Обучение. Продукты. Интерактивные миры.' : 'Learning. Products. Interactive worlds.'}</p>
        <a className="brand-button primary omega-portals-live-cta" href="#products">{tx("Исследовать экосистему")} <span aria-hidden="true">↗</span></a>
      </div>
      <div className="omega-portals-visual">
        <picture className="omega-portals-reference">
          <source media="(max-width: 760px)" srcSet="/brand/osgard-portal-mobile.webp" />
          <img src="/brand/osgard-portal-desktop.webp" alt="" aria-hidden="true" width="1672" height="869" fetchPriority="high" decoding="async" />
        </picture>
        <nav className="omega-portal-stage" aria-label={locale === 'ru' ? 'Входы в экосистему OSGARD' : 'Enter the OSGARD ecosystem'}>
          <a href="/intelligence" className="omega-portal omega-portal--osa" aria-label={locale === 'ru' ? 'OSA Intelligence — перейти' : 'Enter OSA Intelligence'}>
            
          </a>
          <a href="/play" className="omega-portal omega-portal--play" aria-label={locale === 'ru' ? 'OSGARD Play — перейти' : 'Enter OSGARD Play'}>
            <span className="omega-portal-label" aria-hidden="true">{locale === 'en' ? 'Enter' : ''}</span>
          </a>
          <a href="/development" className="omega-portal omega-portal--development" aria-label={locale === 'ru' ? 'OSGARD Development — перейти' : 'Enter OSGARD Development'}>
            <span className="omega-portal-label" aria-hidden="true">{locale === 'en' ? 'Enter' : ''}</span>
          </a>
        </nav>
      </div>
      <a className="omega-portals-primary-hotspot" href="#products" aria-label={tx("Исследовать экосистему")}><span className="omega-portals-sr-only">{tx("Исследовать экосистему")}</span></a>
      <button type="button" className="world-language-toggle omega-portals-language" onClick={changeLocale}
        aria-label={locale === 'ru' ? 'Switch language to English' : 'Переключить язык на русский'}>
        <Globe2 size={15} aria-hidden="true" />{locale === 'ru' ? 'EN' : 'RU'}
      </button>
    </section>
    <section id="products" className="brand-section omega-products" aria-labelledby="world-products-title">
      <div className="brand-section-heading"><p className="brand-eyebrow">{tx("01 / НАПРАВЛЕНИЯ OSGARD")}</p><h2 id="world-products-title">{locale === 'ru' ? <>ТРИ МИРА. <span>ОДНА ВСЕЛЕННАЯ.</span></> : <>THREE WORLDS. <span>ONE ECOSYSTEM.</span></>}</h2><p>{tx("Выберите направление и изучите его реальные возможности и ограничения.")}</p></div>
      <div className="omega-cards">
        <a href="/intelligence" className="omega-card"><div className="omega-card-art"><img src="/brand/omega-osa.svg" alt={tx("Голографическое интеллектуальное ядро с нейронными связями")} loading="lazy"/><small>01 / {tx("ИНТЕЛЛЕКТ")}</small></div><div className="omega-card-content"><h3>OSA <span>Intelligence</span></h3><p>{tx("Изучай ИИ, проверяй ответы и применяй знания.")}</p><strong>{tx("Начать обучение")} <span aria-hidden="true">↗</span></strong></div></a>
        <a href="/play" className="omega-card"><div className="omega-card-art"><img src="/brand/omega-play.svg" alt={tx("Футуристический цифровой город и игровой портал")} loading="lazy"/><small>02 / {tx("ИГРОВЫЕ МИРЫ")}</small></div><div className="omega-card-content"><h3>OSGARD <span>Play</span></h3><p>{tx("Исследуй интерактивные миры, открывай доступные игры и игровые эксперименты.")}</p><strong>{tx("Исследовать игры")} <span aria-hidden="true">↗</span></strong></div></a>
        <a href="/development" className="omega-card"><div className="omega-card-art"><img src="/brand/omega-development.svg" alt={tx("Голографические 3D-кубы и архитектура программных продуктов")} loading="lazy"/><small>03 / {tx("РАЗРАБОТКА")}</small></div><div className="omega-card-content"><h3>OSGARD <span>Development</span></h3><p>{tx("Изучи действующие демо, кейсы и метод разработки.")}</p><strong>{tx("Смотреть проекты")} <span aria-hidden="true">↗</span></strong></div></a>
      </div>
      <div className="world-workspace-link"><p>{tx("Работаешь над идеей? Собери план и материалы здесь.")}</p><a className="brand-text-link" href="/workspace">{tx("Открыть рабочее пространство")} ↗</a></div>
    </section>
    </>}
    <section id="cases" className="brand-section" aria-labelledby="world-cases-title">
      <div className="brand-section-heading"><p className="brand-eyebrow">{tx("02 / ИЗБРАННЫЕ ПРОЕКТЫ")}</p><h2 id="world-cases-title">{locale === 'ru' ? <>У каждой задачи<br />свой характер.</> : <>EVERY PROJECT<br />HAS ITS OWN CHARACTER.</>}</h2><p>{tx("Изучите интерфейс, возможности и стадию каждого проекта.")}</p></div>
      <div className="world-case-grid">{cases.map((item, index) => <a href={item.href} className="world-case" key={item.id}>
        <div className="world-case-art" style={item.visual === 'screenshot' ? { aspectRatio: '3 / 2' } : undefined}><img src={item.art} alt={(item.visual === 'screenshot' ? tx("Снимок публичной страницы кейса ") : tx("Визуальное превью ")) + item.name} width="1200" height={item.visual === 'screenshot' ? 800 : 630} loading="lazy" decoding="async" /><span className="brand-status">{locale === 'en' ? txCase(item.id, 'type') || item.type : item.type}</span></div>
        <div className="world-case-title"><span>0{index + 1} / {locale === 'en' ? txCase(item.id, 'category') || item.category : item.category}</span><h3>{item.name} <span aria-hidden="true">↗</span></h3><p>{locale === 'en' ? txCase(item.id, 'description') || item.description : item.description}</p><span className="world-case-open">{tx("Открыть кейс")} <span aria-hidden="true">→</span></span></div>
      </a>)}</div>
      <p className="world-case-legend"><strong>{tx("Как читать статусы.")}</strong> {tx("Концепт — идея, демо — проба, прототип — проверка части продукта. Запуск подтверждается отдельно. PHANTOM, TEDES и MERAKKI — снимки страниц, ESSENTIA — превью: это не доказательство продаж.")}</p>
    </section>

    <section id="approach" className="brand-section" aria-labelledby="world-approach-title">
      <div className="brand-section-heading"><p className="brand-eyebrow">{tx("03 / ПОДХОД")}</p><h2 id="world-approach-title">{locale === 'ru' ? <>Сначала смысл.<br />Потом — каждый пиксель.</> : <>MEANING FIRST.<br />THEN EVERY PIXEL.</>}</h2></div>
      <ol className="world-process">{process.map(([name, description], index) => <li key={name}><span>0{index + 1}</span><h3>{tx(name)}</h3><p>{tx(description)}</p></li>)}</ol>
    </section>

    <section id="about" className="brand-section world-about" aria-labelledby="world-about-title">
      <p className="brand-eyebrow">{tx("04 / О СТУДИИ И РЕЗУЛЬТАТАХ")}</p><h2 id="world-about-title">{locale === 'ru' ? <>Работу можно<br />проверить.</> : <>WORK YOU CAN<br />VERIFY.</>}</h2>
      <div><p>{tx("OSGARD: продукты, обучение и эксперименты с ясными границами.")}</p>
        <ul><li><a href="/learning/project">{tx("Редактор учебного проекта")}</a> — {tx("цель, план, локальное сохранение и перенос в JSON.")}</li><li><a href="/tedes/project/">{tx("Проектная спецификация TEDES")}</a> — {tx("подбор и сохранение конфигурации в браузере.")}</li><li><a href="/play/world/vector-zero">VECTOR//ZERO</a> — {tx("одиночный игровой клиент с инструкцией и управлением.")}</li></ul>
        <p>{tx("Откройте сценарий. Доступность функций указана на странице.")}</p><a className="brand-text-link" href="/quality">{tx("Состояние функций и сборки")} <span aria-hidden="true">→</span></a>
      </div>
    </section>

    <section id="contact" className="brand-section world-contact" aria-labelledby="world-contact-title">
      <div><p className="brand-eyebrow">{tx("05 / СЛЕДУЮЩИЙ ШАГ")}</p><h2 id="world-contact-title">{locale === 'ru' ? <>Начнём<br />с вашей задачи.</> : <>LET’S START<br />WITH YOUR PROJECT.</>}</h2>
        <p>{tx("Опишите проект, скачайте бриф и приложите его к письму: форма сама ничего не отправляет.")}</p>
        <a href="mailto:osman.osmanov0099@gmail.com" onClick={() => recordBrandEvent('contact_opened')}>osman.osmanov0099@gmail.com <span aria-hidden="true">↗</span></a>
        <p className="world-contact-next">{tx("Сначала определяем задачу и объём. Сроки и стоимость — после анализа брифа.")}</p>
      </div>
      <form noValidate onSubmit={async event => { event.preventDefault(); try { const { validateEnquiry, formatEnquiry } = await import('./projectEnquiry'); const problem = validateEnquiry(brief, contact); if (problem) { setError(problem); briefInput.current?.focus(); return } download(formatEnquiry(brief, contact)) } catch { setError(locale === 'ru' ? 'Не удалось подготовить файл. Скопируйте описание и отправьте его на указанный адрес.' : 'Could not prepare the file. Copy your description and email it to the address above.') } }}>
        <label htmlFor="project-brief">{tx("Что хотите создать?")}</label>
        <p id="brief-help" className="brand-field-help">{tx("Для кого продукт, какую задачу решает, что уже есть. От 20 до 5000 символов.")}</p>
        <textarea id="project-brief" name="project-brief" ref={briefInput} aria-invalid={Boolean(error)} aria-describedby="brief-help brief-feedback" required minLength={20} maxLength={5000} value={brief} onChange={event => { setBrief(event.target.value); setSaved(false); setError('') }} placeholder={tx("Например: расписание клуба и приём заявок…")} rows={5} />
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
