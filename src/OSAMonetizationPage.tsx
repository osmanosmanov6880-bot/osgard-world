import { useState } from 'react'

type Locale = 'ru' | 'en'

const copy = {
  ru: {
    home: 'OSA Learning',
    language: 'Переключить язык',
    eyebrow: 'OSA LEARNING · ПРАКТИЧЕСКАЯ ПРОГРАММА',
    title: 'Понимать ИИ. Проверять ответы. Решать осознанно.',
    intro: 'Практический маршрут для тех, кто хочет применять ИИ в работе: от постановки задачи до проверяемой итоговой работы.',
    freeCta: 'Начать бесплатные уроки',
    detailsCta: 'Посмотреть программу',
    statusLabel: 'Открытый маршрут доступен · платный набор пока закрыт',
    methodEyebrow: 'МЕТОД',
    methodTitle: 'Три действия, которые превращают ответ в решение',
    method: [
      { n: '01', title: 'Понять', body: 'Сформулировать задачу, контекст и критерии хорошего результата.' },
      { n: '02', title: 'Проверить', body: 'Сверить ответ с источниками, ограничениями и новым примером.' },
      { n: '03', title: 'Решить', body: 'Сохранить выводы и оформить работу так, чтобы её можно было показать.' },
    ],
    programEyebrow: 'САМОСТОЯТЕЛЬНЫЙ МАРШРУТ',
    programTitle: 'Восемь практик и итоговая работа',
    programIntro: 'Состав опирается на существующие уроки OSA и практический проект. Бесплатные уроки уже доступны; коммерческая версия программы ещё не открыта.',
    steps: [
      'Пройти восемь практических уроков с самопроверкой.',
      'Собрать в проекте задачу, критерии, источники и рабочий артефакт.',
      'Сравнить результат на новом примере и сохранить итоговую версию.',
    ],
    outcomeTitle: 'Что останется у вас',
    outcomes: [
      'Структурированная постановка задачи для ИИ.',
      'Источники и ограничения, которые можно перепроверить.',
      'Практический артефакт и итоговая работа в личном проекте.',
    ],
    boundariesTitle: 'Честные границы программы',
    boundaries: [
      'Самопроверка сверяет ответы с учебным материалом, но не подтверждает квалификацию.',
      'Практический текст и итоговую работу автоматически не оценивают.',
      'Наставник, живые занятия, сертификат и гарантированный карьерный или финансовый результат не входят в доступный сейчас продукт.',
    ],
    offersEyebrow: 'ФОРМАТЫ',
    offersTitle: 'Начните с открытых уроков',
    freeLabel: 'Доступно сейчас',
    freeTitle: 'Открытый маршрут',
    freePrice: 'Бесплатно',
    freeBody: 'Посмотрите формат OSA и пройдите доступные уроки.',
    freeItems: ['Учебная карта', 'Интерактивные уроки', 'Самопроверка знаний'],
    courseLabel: 'Готовится к запуску',
    courseTitle: 'Практическая программа',
    coursePrice: '$79',
    courseCadence: 'тестовая цена · не публичная оферта',
    courseBody: 'Планируемый самостоятельный формат: восемь практик и итоговая работа.',
    courseItems: ['Пошаговый маршрут', 'Практические задания', 'Сохранённый результат в проекте'],
    cohortLabel: 'Не открыт',
    cohortTitle: 'Практическая когорта',
    cohortPrice: '$499',
    cohortCadence: 'гипотеза цены · даты не назначены',
    cohortBody: 'Групповой формат рассматривается отдельно и появится только после подготовки ведущего и расписания.',
    cohortItems: ['Групповая практика — планируется', 'Живые разборы — не запущены', 'Обратная связь — не подтверждена'],
    teamLabel: 'Для организаций',
    teamTitle: 'Командный пилот',
    teamPrice: 'Обсудить',
    teamBody: 'Уточнить задачу команды, критерии результата и возможный состав пилота.',
    teamItems: ['Без опубликованной цены', 'Без автоматического заказа', 'Параметры подтверждаются отдельно'],
    freeCardCta: 'Открыть обучение',
    statusCta: 'Условия запуска',
    teamCta: 'Обсудить в Telegram',
    launchTitle: 'Платный набор ещё не открыт',
    launchText: 'Сейчас сайт не принимает заказы и оплату, не резервирует места и не выдаёт платный доступ. Цены $79 и $499 — гипотезы для проверки, а не действующее предложение. Для командного обсуждения можно написать через официальный Telegram-бот OSGARD; это не оформляет заказ и не резервирует место.',
    launchNote: 'Публикация платной программы зависит от готовности содержания, поддержки, условий продажи и платёжной инфраструктуры.',
    finalTitle: 'Сначала проверьте подход на бесплатных уроках',
    finalText: 'Пройдите доступный маршрут и посмотрите, подходит ли вам практический формат OSA.',
    finalCta: 'Перейти к урокам',
    footer: 'OSGARD WORLD · OSA Learning',
  },
  en: {
    home: 'OSA Learning',
    language: 'Switch language',
    eyebrow: 'OSA LEARNING · PRACTICAL PROGRAM',
    title: 'Understand AI. Check its answers. Make informed decisions.',
    intro: 'A practical path for people who want to use AI at work: from framing a task to a reviewable final project.',
    freeCta: 'Start free lessons',
    detailsCta: 'Explore the program',
    statusLabel: 'Open learning is available · paid enrollment is not open',
    methodEyebrow: 'METHOD',
    methodTitle: 'Three actions that turn an answer into a decision',
    method: [
      { n: '01', title: 'Understand', body: 'Define the task, its context, and what a good result means.' },
      { n: '02', title: 'Verify', body: 'Check the answer against sources, limitations, and a new example.' },
      { n: '03', title: 'Decide', body: 'Keep the reasoning and present the work so others can review it.' },
    ],
    programEyebrow: 'SELF-PACED PATH',
    programTitle: 'Eight practices and a final project',
    programIntro: 'The outline builds on existing OSA lessons and a practical project. Free lessons are available now; the commercial program is not open yet.',
    steps: [
      'Complete eight practical lessons with knowledge checks.',
      'Collect the task, criteria, sources, and a working artifact in a project.',
      'Compare the result on a new example and save the final version.',
    ],
    outcomeTitle: 'What you will keep',
    outcomes: [
      'A structured task brief for working with AI.',
      'Sources and limitations that can be checked again.',
      'A practical artifact and final project in your personal workspace.',
    ],
    boundariesTitle: 'Clear program boundaries',
    boundaries: [
      'Knowledge checks compare answers with lesson material; they do not certify proficiency.',
      'Practical writing and final work are not automatically evaluated.',
      'An instructor, live sessions, a certificate, and guaranteed career or financial outcomes are not part of the currently available product.',
    ],
    offersEyebrow: 'FORMATS',
    offersTitle: 'Start with the open lessons',
    freeLabel: 'Available now',
    freeTitle: 'Open learning path',
    freePrice: 'Free',
    freeBody: 'Explore the OSA format and take the available lessons.',
    freeItems: ['Learning map', 'Interactive lessons', 'Knowledge self-checks'],
    courseLabel: 'Preparing for launch',
    courseTitle: 'Practical program',
    coursePrice: '$79',
    courseCadence: 'test price · not a public offer',
    courseBody: 'Planned self-paced format: eight practices and a final project.',
    courseItems: ['Step-by-step path', 'Practical assignments', 'Saved result in a project'],
    cohortLabel: 'Not open',
    cohortTitle: 'Practice cohort',
    cohortPrice: '$499',
    cohortCadence: 'price hypothesis · no dates set',
    cohortBody: 'A group format is being considered and will only appear after an instructor and schedule are ready.',
    cohortItems: ['Group practice — planned', 'Live reviews — not running', 'Feedback — not confirmed'],
    teamLabel: 'For organizations',
    teamTitle: 'Team pilot',
    teamPrice: 'Discuss',
    teamBody: 'Clarify the team objective, success criteria, and a possible pilot scope.',
    teamItems: ['No published price', 'No automatic order', 'Scope confirmed separately'],
    freeCardCta: 'Open learning',
    statusCta: 'Launch terms',
    teamCta: 'Discuss on Telegram',
    launchTitle: 'Paid enrollment is not open yet',
    launchText: 'This site does not take orders or payments, reserve seats, or grant paid access. The $79 and $499 figures are validation hypotheses, not current offers. Teams can start a conversation through OSGARD’s official Telegram bot; this does not create an order or reserve a place.',
    launchNote: 'Paid launch depends on ready curriculum, learner support, sales terms, and payment infrastructure.',
    finalTitle: 'Test the approach with the free lessons first',
    finalText: 'Try the available path and see whether OSA’s practical format works for you.',
    finalCta: 'Go to lessons',
    footer: 'OSGARD WORLD · OSA Learning',
  },
} as const

const telegramUrl = 'https://t.me/OSGARD_world_bot'
const panel = { border: '1px solid #293640', background: '#182330', borderRadius: 20 }
const secondary = { color: '#aab4bc', lineHeight: 1.7 }

export default function OSAMonetizationPage() {
  const [locale, setLocale] = useState<Locale>('ru')
  const t = copy[locale]
  return (
    <main style={{ minHeight: '100vh', color: '#f3f0e8', background: '#101a27', padding: 'clamp(20px, 5vw, 76px)' }}>
      <div style={{ maxWidth: 1160, margin: '0 auto' }}>
        <header style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 16 }}>
          <a href="/learning" style={{ color: '#f3f0e8', textDecoration: 'none', fontWeight: 700 }}>{t.home}</a>
          <button type="button" aria-label={t.language} onClick={() => setLocale(locale === 'ru' ? 'en' : 'ru')} style={{ color: '#f3f0e8', background: '#182330', border: '1px solid #34434d', borderRadius: 999, padding: '10px 15px', cursor: 'pointer' }}>{locale.toUpperCase()} / {locale === 'ru' ? 'EN' : 'RU'}</button>
        </header>

        <section style={{ maxWidth: 900, margin: 'clamp(68px, 11vw, 132px) auto 88px' }}>
          <p style={{ color: '#83b9ae', letterSpacing: 2.5, fontSize: 12 }}>{t.eyebrow}</p>
          <h1 style={{ maxWidth: 860, fontFamily: 'Cormorant Garamond, Georgia, serif', fontSize: 'clamp(48px, 8vw, 88px)', fontWeight: 500, lineHeight: 0.98, letterSpacing: '-0.025em', margin: '20px 0 24px' }}>{t.title}</h1>
          <p style={{ ...secondary, maxWidth: 700, fontSize: 'clamp(18px, 2.4vw, 22px)' }}>{t.intro}</p>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 12, marginTop: 32 }}>
            <a href="/learning" style={{ color: '#101a27', background: '#83b9ae', padding: '14px 20px', borderRadius: 8, textDecoration: 'none', fontWeight: 750 }}>{t.freeCta} →</a>
            <a href="#program" style={{ color: '#f3f0e8', border: '1px solid #52616a', padding: '13px 20px', borderRadius: 8, textDecoration: 'none', fontWeight: 650 }}>{t.detailsCta}</a>
          </div>
          <p role="status" style={{ color: '#83b9ae', fontSize: 13, marginTop: 28 }}>● {t.statusLabel}</p>
        </section>

        <section aria-labelledby="method-title" style={{ marginBottom: 100 }}>
          <p style={{ color: '#83b9ae', letterSpacing: 2, fontSize: 11 }}>{t.methodEyebrow}</p>
          <h2 id="method-title" style={{ fontSize: 'clamp(30px, 5vw, 48px)', fontWeight: 500, letterSpacing: '-0.03em', maxWidth: 700 }}>{t.methodTitle}</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 220px), 1fr))', gap: 14, marginTop: 30 }}>
            {t.method.map(item => <article key={item.n} style={{ ...panel, padding: 24 }}>
              <span style={{ color: '#83b9ae', fontFamily: 'monospace', fontSize: 12 }}>{item.n}</span>
              <h3 style={{ fontSize: 23, margin: '24px 0 8px' }}>{item.title}</h3>
              <p style={{ ...secondary, marginBottom: 0 }}>{item.body}</p>
            </article>)}
          </div>
        </section>

        <section id="program" aria-labelledby="program-title" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 300px), 1fr))', gap: 40, padding: 'clamp(24px, 5vw, 52px)', ...panel, marginBottom: 100 }}>
          <div>
            <p style={{ color: '#83b9ae', letterSpacing: 2, fontSize: 11 }}>{t.programEyebrow}</p>
            <h2 id="program-title" style={{ fontFamily: 'Cormorant Garamond, Georgia, serif', fontSize: 'clamp(36px, 5vw, 54px)', fontWeight: 500, lineHeight: 1.02, margin: '18px 0' }}>{t.programTitle}</h2>
            <p style={secondary}>{t.programIntro}</p>
            <h3 style={{ marginTop: 32 }}>{t.outcomeTitle}</h3>
            <ul style={{ color: '#f3f0e8', lineHeight: 1.9, paddingLeft: 20 }}>
              {t.outcomes.map(item => <li key={item}>{item}</li>)}
            </ul>
          </div>
          <div>
            <ol style={{ color: '#f3f0e8', lineHeight: 1.9, paddingLeft: 22 }}>
              {t.steps.map(item => <li key={item} style={{ padding: '0 0 14px 8px' }}>{item}</li>)}
            </ol>
            <div style={{ borderTop: '1px solid #34434d', paddingTop: 20, marginTop: 20 }}>
              <h3>{t.boundariesTitle}</h3>
              <ul style={{ ...secondary, paddingLeft: 20 }}>
                {t.boundaries.map(item => <li key={item} style={{ marginBottom: 9 }}>{item}</li>)}
              </ul>
            </div>
          </div>
        </section>

        <section aria-labelledby="offers-title" style={{ marginBottom: 96 }}>
          <p style={{ color: '#83b9ae', letterSpacing: 2, fontSize: 11 }}>{t.offersEyebrow}</p>
          <h2 id="offers-title" style={{ fontSize: 'clamp(30px, 5vw, 48px)', fontWeight: 500, letterSpacing: '-0.03em' }}>{t.offersTitle}</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 245px), 1fr))', gap: 14, marginTop: 28 }}>
            <OfferCard label={t.freeLabel} title={t.freeTitle} price={t.freePrice} body={t.freeBody} items={t.freeItems} cta={t.freeCardCta} href="/learning" primary />
            <OfferCard label={t.courseLabel} title={t.courseTitle} price={t.coursePrice} cadence={t.courseCadence} body={t.courseBody} items={t.courseItems} cta={t.statusCta} href="#launch-status" />
            <OfferCard label={t.cohortLabel} title={t.cohortTitle} price={t.cohortPrice} cadence={t.cohortCadence} body={t.cohortBody} items={t.cohortItems} cta={t.statusCta} href="#launch-status" />
            <OfferCard label={t.teamLabel} title={t.teamTitle} price={t.teamPrice} body={t.teamBody} items={t.teamItems} cta={t.teamCta} href={telegramUrl} external />
          </div>
        </section>

        <section id="launch-status" aria-live="polite" style={{ maxWidth: 920, margin: '0 auto', padding: 'clamp(24px, 5vw, 42px)', borderLeft: '2px solid #83b9ae', background: '#182330' }}>
          <h2 style={{ fontFamily: 'Cormorant Garamond, Georgia, serif', fontSize: 38, fontWeight: 500, marginTop: 0 }}>{t.launchTitle}</h2>
          <p style={secondary}>{t.launchText}</p>
          <p style={{ color: '#778791', fontSize: 12 }}>{t.launchNote}</p>
          <a href={telegramUrl} target="_blank" rel="noreferrer" style={{ color: '#83b9ae', fontWeight: 700 }}>{t.teamCta} ↗</a>
        </section>

        <section style={{ textAlign: 'center', margin: '100px auto 54px' }}>
          <h2 style={{ fontFamily: 'Cormorant Garamond, Georgia, serif', fontSize: 'clamp(34px, 6vw, 60px)', fontWeight: 500, marginBottom: 12 }}>{t.finalTitle}</h2>
          <p style={{ ...secondary, maxWidth: 620, margin: '0 auto 24px' }}>{t.finalText}</p>
          <a href="/learning" style={{ display: 'inline-block', color: '#101a27', background: '#83b9ae', padding: '14px 20px', borderRadius: 8, textDecoration: 'none', fontWeight: 750 }}>{t.finalCta} →</a>
        </section>

        <footer style={{ borderTop: '1px solid #293640', paddingTop: 20, color: '#778791', fontSize: 12, textAlign: 'center' }}>{t.footer}</footer>
      </div>
    </main>
  )
}

function OfferCard({ label, title, price, cadence, body, items, cta, href, primary, external }: {
  label: string
  title: string
  price: string
  cadence?: string
  body: string
  items: readonly string[]
  cta: string
  href: string
  primary?: boolean
  external?: boolean
}) {
  return (
    <article style={{ display: 'flex', flexDirection: 'column', minHeight: 400, padding: 23, border: primary ? '1px solid #83b9ae' : '1px solid #293640', background: primary ? '#1a2a32' : '#141f2b', borderRadius: 16 }}>
      <p style={{ color: '#83b9ae', letterSpacing: 1.4, textTransform: 'uppercase', fontSize: 10 }}>{label}</p>
      <h3 style={{ fontSize: 21, margin: '7px 0' }}>{title}</h3>
      <div style={{ fontSize: 31, fontWeight: 650, letterSpacing: '-0.04em', marginTop: 12 }}>{price}</div>
      {cadence && <p style={{ color: '#aab4bc', fontSize: 11, minHeight: 30, margin: '4px 0' }}>{cadence}</p>}
      <p style={{ color: '#aab4bc', lineHeight: 1.6 }}>{body}</p>
      <ul style={{ color: '#d7dedf', lineHeight: 1.8, fontSize: 13, paddingLeft: 18, flex: 1 }}>
        {items.map(item => <li key={item}>{item}</li>)}
      </ul>
      <a href={href} target={external ? '_blank' : undefined} rel={external ? 'noreferrer' : undefined} style={{ display: 'block', textAlign: 'center', padding: '12px 14px', borderRadius: 8, background: primary ? '#83b9ae' : 'transparent', border: primary ? '1px solid #83b9ae' : '1px solid #52616a', color: primary ? '#101a27' : '#f3f0e8', textDecoration: 'none', fontWeight: 700 }}>{cta}{external ? ' ↗' : ''}</a>
    </article>
  )
}
