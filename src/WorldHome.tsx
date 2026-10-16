import { useEffect, useRef, useState } from 'react'
import { cases } from './redesignCatalog'
import { BrandMark } from './BrandMark'
import { formatEnquiry, validateEnquiry } from './projectEnquiry'
import { recordBrandEvent } from './brandTelemetry'

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
    <section className="world-hero" aria-labelledby="world-title">
      <div><p className="brand-eyebrow">OSGARD {development ? 'DEVELOPMENT / РАЗРАБОТКА' : 'WORLD / ЦИФРОВАЯ СТУДИЯ'}</p>
        <h1 id="world-title">Цифровые продукты,<br /><span>построенные<br />как системы.</span></h1>
        <p className="brand-lead">Соединяем продуктовую задачу, структуру, дизайн и разработку. От первого сценария — до работающего цифрового опыта.</p>
        <div className="brand-actions"><a className="brand-button primary" href="#cases">Смотреть проекты <span aria-hidden="true">↗</span></a><a className="brand-button" href="#contact">Обсудить проект <span aria-hidden="true">→</span></a></div>
        <p className="brand-meta">СТРАТЕГИЯ / ИНТЕРФЕЙС / РАЗРАБОТКА</p>
      </div>
      <div className="world-system-art" role="img" aria-label="Открытый портал объединяет стратегию, интерфейс и систему">
        <div className="world-art-caption">СИСТЕМА / 001<span>ОТКРЫТА К НОВОМУ</span></div><BrandMark /><div className="world-art-axis" />
        <span className="world-art-label label-a">01 / СТРАТЕГИЯ</span><span className="world-art-label label-b">02 / ИНТЕРФЕЙС</span><span className="world-art-label label-c">03 / СИСТЕМА</span><p>Каждый элемент<br />работает на цель.</p>
      </div>
    </section>

    <section id="products" className="brand-section" aria-labelledby="world-products-title">
      <div className="brand-section-heading"><p className="brand-eyebrow">01 / ЭКОСИСТЕМА</p><h2 id="world-products-title">Разные задачи.<br />Одна логика качества.</h2></div>
      <div className="world-directions">{directions.map(([index, title, description, href, label]) => <a key={index} href={href}><span className="brand-eyebrow">{index} / {label}</span><h3>{title} <span aria-hidden="true">↗</span></h3><p>{description}</p></a>)}</div>
      <div className="world-workspace-link"><p>Есть цель, над которой хотите работать сами? Соберите план, материалы и критерии результата в одном проекте.</p><a className="brand-text-link" href="/workspace">Открыть рабочее пространство <span aria-hidden="true">↗</span></a></div>
    </section>

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
