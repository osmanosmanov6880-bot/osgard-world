import { useState } from 'react'
import type { CSSProperties } from 'react'
import { BrandLockup, BrandMark } from './BrandMark'
import { readBrandEventState, clearBrandEvents } from './brandTelemetry'
import { getPlayGame, playGames } from './redesignCatalog'

const brands = [
  { theme: 'world', name: 'OSGARD WORLD', note: 'Деловой, точный, собранный', bg: '#F3F4F1', ink: '#172027', muted: '#59656B', accent: '#315A62', colors: [['Фон', '#F3F4F1'], ['Поверхности', '#FFFFFF'], ['Текст', '#172027'], ['Вторичный текст', '#59656B'], ['Акцент', '#315A62'], ['Разделители', '#DCE2E1']] },
  { theme: 'intelligence', name: 'OSA Intelligence', note: 'Внимание, ясность, глубина', bg: '#101A27', ink: '#F3F0E8', muted: '#AAB4BC', accent: '#83B9AE', colors: [['Фон', '#101A27'], ['Поверхности', '#182330'], ['Текст', '#F3F0E8'], ['Вторичный текст', '#AAB4BC'], ['Акцент', '#83B9AE']] },
  { theme: 'play', name: 'OSGARD PLAY', note: 'Исследование, движение, игра', bg: '#080B12', ink: '#F1F5FA', muted: '#AAB6C7', accent: '#5CE1E6', colors: [['Фон', '#080B12'], ['Поверхности', '#111926'], ['Акцент', '#5CE1E6'], ['Игровой сигнал', '#B7F15A']] },
] as const
const eventNames = [
  ['course_started', 'Открытие курса'], ['lecture_opened', 'Открытие лекции'], ['game_launch_clicked', 'Клик запуска'], ['brief_exported', 'Экспорт брифа'], ['contact_opened', 'Открытие контакта'],
] as const

export default function BrandPages({ quality = false }: { quality?: boolean }) {
  const [eventState, setEventState] = useState(readBrandEventState)
  const [notice, setNotice] = useState('')
  const [eventError, setEventError] = useState(false)
  const events = eventState.events
  const refresh = () => { setEventState(readBrandEventState()); setNotice(''); setEventError(false) }
  const clear = () => {
    if (clearBrandEvents()) { setEventState({ status: 'ok', events: [] }); setNotice('Локальный журнал удалён.'); setEventError(false) }
    else { setNotice('Не удалось удалить журнал: хранилище недоступно. Данные не отмечены удалёнными.'); setEventError(true) }
  }
  const download = () => {
    try {
      const anchor = document.createElement('a')
      const url = URL.createObjectURL(new Blob([JSON.stringify(events, null, 2)], { type: 'application/json' }))
      setTimeout(() => URL.revokeObjectURL(url), 1000)
      anchor.href = url
      anchor.download = 'OSGARD-local-events.json'
      anchor.click()
      setNotice('Файл журнала подготовлен.')
      setEventError(false)
    } catch { setNotice('Не удалось подготовить файл журнала. Повторите попытку после проверки браузера.'); setEventError(true) }
  }

  if (quality) {
    const nullShift = getPlayGame('null-shift')
    const launchable = playGames.filter(game => game.launchable).length
    const rows = [
      ['Три главные страницы', 'OSGARD WORLD, OSA Intelligence и OSGARD PLAY', 'Переключить продукт в верхнем меню; название и палитра показывают текущий раздел.'],
      ['Каталог PLAY', `${playGames.length} миров в каталоге; у ${launchable} доступна кнопка запуска`, 'Открыть страницу мира: формат, управление и ограничения указаны до запуска. Кнопка сама по себе не подтверждает успешную игровую сессию.'],
      ['Избранное и недавние', 'Данные этого браузера', 'Поставить звезду, открыть мир и вернуться в каталог. При запрете хранилища интерфейс показывает ошибку сохранения.'],
      ['Сетевые режимы', 'Зависят от сервиса конкретной игры', 'Проверить соединение и комнату в клиенте. Локальная страница каталога не наблюдает состояние игрового сервера.'],
      ['NULL//SHIFT', nullShift ? nullShift.platform : 'Нет записи в каталоге', nullShift?.warning || 'Проверить текущий состав каталога.'],
      ['Гостевое обучение', 'Отметки уроков и проекты в браузере', 'Пройти урок, открыть «Мой прогресс»; перенос локальных данных доступен на странице «Мои данные».'],
      ['Серверные проекты и роли', 'Подключение через аккаунт Core', 'Открыть рабочий центр: он получает состояние доступных проектов с сервера и показывает ошибку, если соединение недоступно.'],
      ['Контактная форма', 'Подготовка файла брифа', 'Скачать файл и приложить к письму. Автоматической отправки заявки из этой формы нет.'],
      ['Платежи', 'Доступность зависит от подключения провайдера', 'Статус заказа и подтверждение оплаты проверяются в рабочем пространстве. Наличие предложения не подтверждает приём реальных платежей.'],
      ['Аудио и видео OSA', 'По реестру медиатеки', 'На /osa-library/ сохраняются статусы материалов, файлов и постоянных адресов.'],
      ['Скорость сайта', 'Полевые Core Web Vitals ещё нужно измерить', 'Ориентиры на p75: LCP ≤ 2,5 с; INP ≤ 200 мс; CLS ≤ 0,1. Это цели, а не опубликованные результаты измерения.'],
      ['Доступность', 'Фокус, клавиатура, крупные цели, уменьшение движения', 'Проверить маршруты с клавиатуры и на мобильном экране. Полный аудит соответствия и проверка экранным диктором — отдельная работа.'],
    ]
    return <main className="brand-container brand-quality">
      <p className="brand-eyebrow">OSGARD / СОСТОЯНИЕ И ПРОВЕРКА</p><h1>Что доступно.<br />Как это проверить.</h1>
      <p>Здесь описаны интерфейс и состав текущей сборки. Состояние подключённых сервисов проверяется в их рабочих сценариях.</p>
      <div className="brand-actions"><a className="brand-button primary" href="/play">Открыть каталог игр →</a><a className="brand-button" href="/workspace/overview">Рабочий центр →</a><a className="brand-button" href="/osa-library/">Статусы медиа →</a></div>
      <div className="quality-table-wrap"><table><caption className="brand-table-caption">Возможности, границы и способ проверки</caption><thead><tr><th scope="col">Часть</th><th scope="col">Состояние</th><th scope="col">Как проверить</th></tr></thead><tbody>{rows.map(([name, state, check]) => <tr key={name}><th scope="row">{name}</th><td>{state}</td><td>{check}</td></tr>)}</tbody></table></div>
      <section id="measurements" className="brand-section">
        <p className="brand-eyebrow">НАБЛЮДЕНИЯ ЭТОГО БРАУЗЕРА</p><h2>Локальный журнал действий</h2>
        <p>В журнале хранятся до 200 событий. Текст брифа и контакты в него не записываются; события никуда не отправляются. Клик запуска означает нажатие кнопки, а экспорт брифа — подготовку файла. Эти действия не подтверждают игровую сессию или отправку заявки.</p>
        <dl className="brand-measurement-grid">{eventNames.map(([name, label]) => <div key={name}><dt>{label}</dt><dd>{eventState.status === 'ok' ? events.filter(event => event.event === name).length : '—'}</dd></div>)}</dl>
        <div className="brand-quality-controls"><button type="button" className="brand-button" onClick={refresh}>Обновить журнал</button><button type="button" className="brand-button" disabled={!events.length || eventState.status !== 'ok'} onClick={download}>Скачать JSON ↓</button><button type="button" className="brand-button" onClick={clear}>Удалить журнал</button></div>
        <p className="brand-journal-feedback" role={eventError || eventState.status !== 'ok' ? 'alert' : 'status'}>{notice || (eventState.status === 'unavailable' ? 'Хранилище недоступно. Журнал сейчас нельзя прочитать.' : eventState.status === 'invalid' ? 'Журнал повреждён. Можно удалить его и начать новый.' : events.length ? `Событий в журнале: ${events.length}. Это наблюдения на этом устройстве.` : 'Журнал пока пуст. Откройте урок, запустите клиент игры или подготовьте бриф, затем обновите журнал.')}</p>
        <p>Для общих показателей продукта нужны согласованный сбор данных и исходный уровень. Из этого локального журнала нельзя получить конверсию, выручку или полевую скорость всех посещений.</p>
      </section>
    </main>
  }

  return <main className="brand-container brand-quality">
    <p className="brand-eyebrow">OSGARD / ОТКРЫТЫЙ ПОРТАЛ</p><h1>Одна геометрия.<br />Три характера.</h1>
    <p>Кольцо объединяет мир. Разрыв приглашает войти. Линия направляет к цели. Один знак связывает цифровую студию, интеллектуальную среду и игровые миры.</p>
    <div className="brand-logo-grid">{brands.map(brand => <div key={brand.theme} style={{ background: brand.bg, '--ink': brand.ink, '--muted': brand.muted, '--accent': brand.accent } as CSSProperties}>
      <BrandLockup theme={brand.theme} /><p className="brand-variant-label" style={{ color: brand.muted }}>{brand.note}</p>
      <div className="brand-logo-downloads"><a href={`/brand/lockup-${brand.theme}-primary.svg`} download>Логотип в цвете бренда ↓</a><a href={`/brand/lockup-${brand.theme}-mono.svg`} download>Монохромный для светлого фона ↓</a><a href={`/brand/lockup-${brand.theme}-reverse.svg`} download>Белый для тёмного фона ↓</a><a href={`/brand/portal-${brand.theme}.svg`} download>Компактный знак ↓</a></div>
    </div>)}</div>

    <h2>Три палитры</h2><p>Общими остаются сетка, размеры элементов, клавиатурный фокус и ясный текст. Цвет и типографика передают характер продукта.</p>
    <div className="brand-swatch-grid">{brands.map(brand => <section className="brand-swatch-group" key={brand.theme}><h3>{brand.name}</h3>{brand.colors.map(([label, value]) => <div className="brand-swatch" key={label}><span><i style={{ background: value }} aria-hidden="true" />{label}</span><code>{value}</code></div>)}</section>)}</div>
    <p>OSGARD WORLD использует Inter. OSA сочетает Cormorant Garamond в крупных редакционных заголовках с Inter в интерфейсе. В PLAY заголовки набраны Space Grotesk с резервным Inter для отсутствующих символов; JetBrains Mono используется для параметров и номеров. Лаймовый акцент PLAY отведён статусу и прогрессу.</p>

    <h2>Читаемость в масштабе</h2><p>Охранное поле — не меньше четверти диаметра знака. В небольшом размере используется компактный символ, а на вкладке — упрощённый favicon.</p>
    {brands.map(brand => <section key={brand.theme} className="brand-specimen-group" style={{ background: brand.bg, '--ink': brand.ink, '--muted': brand.muted, '--accent': brand.accent } as CSSProperties}><h3>{brand.name}</h3><div className="brand-specimens">{[16, 24, 48, 96].map(size => <figure key={size}><BrandMark theme={brand.theme} width={size} height={size} /><figcaption>{size} px</figcaption></figure>)}</div></section>)}
    <div className="brand-actions"><a className="brand-button" href="/brand/portal-mono.svg" download>Монохромный знак ↓</a><a className="brand-button" href="/brand/portal-white.svg" download>Белый знак ↓</a><a className="brand-button" href="/brand/favicon.svg" download>Favicon ↓</a><a className="brand-button" href="/brand/app-icon.svg" download>Иконка приложения ↓</a><a className="brand-button" href="/brand/app-icon-512.png" download>Иконка 512 × 512 PNG ↓</a></div>

    <h2>Знак в слове</h2><p>В написании OSGARD внутренняя линия буквы G повторяет открытый портал. У OSA тот же символ работает как линза внимания, у PLAY — как направленный импульс. Геометрия остаётся узнаваемой без декоративных шлемов, рун и сложных текстур.</p>
    <h2>Движение по делу</h2><p>При переходе между продуктами портал раскрывается в палитре следующего раздела. В OSA источники появляются мягко. В PLAY короткий переход использует изображение выбранного мира. Обычная навигация продолжается сразу; у урока и игры есть понятный путь назад.</p><p>Системная настройка уменьшения движения и переключатель «Меньше движения» отключают необязательные эффекты. Постоянной фоновой анимации и вспышек в брендовой оболочке нет.</p>
    <div className="brand-actions"><a className="brand-button" href="/intelligence">Открыть OSA ↗</a><a className="brand-button" href="/play">Открыть PLAY ↗</a><a className="brand-button" href="/quality">Посмотреть состояние сборки →</a></div>
  </main>
}
