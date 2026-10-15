import { useState } from 'react'

type Locale = 'ru' | 'en'

const copy = {
  ru: {
    eyebrow: 'OSA LEARNING / ACCESS',
    title: 'Учитесь так, чтобы результат можно было показать.',
    intro: 'Практические программы по ИИ и технологиям: понятный маршрут, задания и работа, которую можно добавить в портфолио.',
    free: 'Открыть обучение',
    freeLabel: 'Начните без оплаты',
    freeTitle: 'Открытый доступ',
    freePrice: 'Бесплатно',
    freeDescription: 'Познакомьтесь с форматом OSA и пройдите доступные интерактивные лекции.',
    freeItems: ['Учебная карта и доступные уроки', 'Самопроверка знаний', 'Прогресс в браузере'],
    courseLabel: 'Самостоятельный темп',
    courseTitle: 'Практический курс',
    coursePrice: '$79',
    courseCadence: 'за программу · тестовая цена',
    courseDescription: 'Структурированный курс с упражнениями и итоговым проектом для самостоятельного прохождения.',
    courseItems: ['Пошаговая программа', 'Практические задания', 'Шаблон итогового проекта'],
    cohortLabel: 'С сопровождением',
    cohortTitle: 'Практическая когорта',
    cohortPrice: '$499',
    cohortCadence: 'за пилот · тестовая цена',
    cohortDescription: 'Учебный поток с расписанием, групповыми разборами и обратной связью по итоговой работе.',
    cohortItems: ['Всё из практического курса', 'Живые разборы по расписанию', 'Обратная связь по проекту'],
    enterpriseLabel: 'Для организаций',
    enterpriseTitle: 'Командный пилот',
    enterprisePrice: 'По запросу',
    enterpriseDescription: 'Пилотная программа для команды с целями, стартовой диагностикой и итоговым отчётом.',
    enterpriseItems: ['Маршрут для роли или команды', 'Групповая практика', 'Отчёт о прохождении и результатах'],
    featured: 'Рекомендуемый формат',
    headline: 'Не покупайте часы видео. Выбирайте понятный результат.',
    proofTitle: 'Что получает ученик',
    proof: ['Цель и критерии успеха до начала программы', 'Практика на задачах, а не только просмотр материалов', 'Понятная обратная связь и следующий шаг'],
    pilotTitle: 'Набор в пилот ещё не открыт',
    pilotText: 'Эти тарифы и цены — проверяемая продуктовая гипотеза. Сейчас на сайте нет оформления заказа, приёма оплаты или подтверждения места. Мы откроем платный набор после подготовки программы, поддержки и платёжной инфраструктуры.',
    pilotLink: 'Пока изучить бесплатный маршрут',
    language: 'Переключить язык',
    note: 'Предлагаемые цены не являются действующим публичным предложением.',
  },
  en: {
    eyebrow: 'OSA LEARNING / ACCESS',
    title: 'Learn in a way that leaves you with work to show.',
    intro: 'Practical programs in AI and technology: a clear path, hands-on assignments, and work you can add to your portfolio.',
    free: 'Explore learning',
    freeLabel: 'Start at no cost',
    freeTitle: 'Open access',
    freePrice: 'Free',
    freeDescription: 'Explore the OSA format and take the available interactive lessons.',
    freeItems: ['Learning map and available lessons', 'Knowledge self-check', 'Progress in this browser'],
    courseLabel: 'Learn at your pace',
    courseTitle: 'Practical course',
    coursePrice: '$79',
    courseCadence: 'per program · test price',
    courseDescription: 'A structured course with exercises and a final project for self-paced learning.',
    courseItems: ['Step-by-step curriculum', 'Hands-on assignments', 'Final project template'],
    cohortLabel: 'Guided learning',
    cohortTitle: 'Practice cohort',
    cohortPrice: '$499',
    cohortCadence: 'per pilot · test price',
    cohortDescription: 'A scheduled learning group with live reviews and feedback on the final project.',
    cohortItems: ['Everything in the practical course', 'Scheduled live reviews', 'Project feedback'],
    enterpriseLabel: 'For organizations',
    enterpriseTitle: 'Team pilot',
    enterprisePrice: 'By request',
    enterpriseDescription: 'A team pilot with learning goals, an initial assessment, and a final outcomes report.',
    enterpriseItems: ['Role or team learning path', 'Group practice', 'Completion and outcomes report'],
    featured: 'Guided format',
    headline: 'Do not buy hours of video. Choose a clear outcome.',
    proofTitle: 'What learners get',
    proof: ['A goal and success criteria before the program starts', 'Practice with real tasks, not only video lessons', 'Clear feedback and a next step'],
    pilotTitle: 'Pilot enrollment is not open yet',
    pilotText: 'These plans and prices are a product hypothesis under validation. This site does not currently take orders, accept payments, or confirm a seat. Paid enrollment will open after the curriculum, learner support, and payment infrastructure are ready.',
    pilotLink: 'Explore the free learning path',
    language: 'Switch language',
    note: 'Proposed prices are not a current public offer.',
  },
} as const

const plans = [
  { key: 'free', featured: false },
  { key: 'course', featured: false },
  { key: 'cohort', featured: true },
  { key: 'enterprise', featured: false },
] as const

export default function OSAMonetizationPage() {
  const [locale, setLocale] = useState<Locale>('ru')
  const t = copy[locale]

  return (
    <main style={{ minHeight: '100vh', color: '#edf3ff', background: 'radial-gradient(ellipse at 50% -12%, #20365b 0, #0b1220 48%, #080d16 100%)', padding: 'clamp(22px, 5vw, 72px)' }}>
      <div style={{ maxWidth: 1200, margin: '0 auto' }}>
        <header style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 16 }}>
          <a href="/learning" style={{ color: '#c6d8f5', textDecoration: 'none' }}>← OSA Learning</a>
          <button type="button" aria-label={t.language} onClick={() => setLocale(locale === 'ru' ? 'en' : 'ru')} style={{ color: '#edf3ff', background: '#121d30', border: '1px solid #344761', borderRadius: 999, padding: '10px 15px', cursor: 'pointer' }}>{locale.toUpperCase()} / {locale === 'ru' ? 'EN' : 'RU'}</button>
        </header>

        <section style={{ maxWidth: 850, margin: '78px auto 54px', textAlign: 'center' }}>
          <p style={{ color: '#9bb9e8', letterSpacing: 4, fontSize: 12 }}>{t.eyebrow}</p>
          <h1 style={{ fontSize: 'clamp(38px, 7vw, 76px)', lineHeight: 1.02, letterSpacing: '-0.045em', margin: '18px 0' }}>{t.title}</h1>
          <p style={{ color: '#b6c3d8', fontSize: 'clamp(17px, 2.2vw, 21px)', lineHeight: 1.65 }}>{t.intro}</p>
        </section>

        <section aria-label={locale === 'ru' ? 'Варианты обучения' : 'Learning plans'} style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 245px), 1fr))', gap: 16, alignItems: 'stretch' }}>
          {plans.map(plan => {
            const details = t[plan.key]
            return (
              <article key={plan.key} style={{ position: 'relative', display: 'flex', flexDirection: 'column', padding: 24, borderRadius: 22, border: plan.featured ? '1px solid #c8a96b' : '1px solid #29394f', background: plan.featured ? 'linear-gradient(160deg, #1e2a3e, #101827 72%)' : 'linear-gradient(160deg, #141e2e, #0d1420 76%)', boxShadow: plan.featured ? '0 18px 55px #0006, inset 0 1px #ffffff12' : '0 18px 55px #0003' }}>
                {plan.featured && <span style={{ position: 'absolute', top: -12, right: 18, padding: '6px 11px', borderRadius: 999, background: '#c8a96b', color: '#111722', fontSize: 11, fontWeight: 800 }}>{t.featured}</span>}
                <p style={{ color: '#9bb9e8', letterSpacing: 2, textTransform: 'uppercase', fontSize: 11 }}>{details.label}</p>
                <h2 style={{ fontSize: 25, margin: '8px 0' }}>{details.title}</h2>
                <div style={{ fontSize: 34, fontWeight: 750, letterSpacing: '-0.04em', marginTop: 14 }}>{details.price}</div>
                {'cadence' in details && <p style={{ color: '#8f9eb4', fontSize: 12, marginTop: 3 }}>{details.cadence}</p>}
                <p style={{ color: '#b6c3d8', minHeight: 72, lineHeight: 1.55 }}>{details.description}</p>
                <ul style={{ paddingLeft: 19, color: '#d5deec', lineHeight: 1.9, fontSize: 14, flex: 1 }}>
                  {details.items.map(item => <li key={item}>{item}</li>)}
                </ul>
                {plan.key === 'free'
                  ? <a href="/learning" style={{ display: 'block', textAlign: 'center', padding: '13px 16px', borderRadius: 12, background: '#d8e6fa', color: '#111a29', textDecoration: 'none', fontWeight: 750 }}>{t.free}</a>
                  : <a href="#pilot-status" style={{ display: 'block', textAlign: 'center', padding: '12px 16px', borderRadius: 12, border: '1px solid #465a76', color: '#d6e3f6', textDecoration: 'none', fontWeight: 650 }}>{locale === 'ru' ? 'Статус запуска' : 'Launch status'}</a>}
              </article>
            )
          })}
        </section>

        <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 300px), 1fr))', gap: 24, margin: '64px 0 38px', padding: 'clamp(24px, 4vw, 42px)', border: '1px solid #29394f', borderRadius: 24, background: '#0e1725cc' }}>
          <div>
            <p style={{ color: '#9bb9e8', letterSpacing: 3, fontSize: 11 }}>{t.proofTitle.toUpperCase()}</p>
            <h2 style={{ fontSize: 'clamp(25px, 4vw, 38px)', lineHeight: 1.15 }}>{t.headline}</h2>
          </div>
          <ul style={{ color: '#d5deec', lineHeight: 1.9, margin: 0, paddingLeft: 20 }}>
            {t.proof.map(item => <li key={item}>{item}</li>)}
          </ul>
        </section>

        <section id="pilot-status" aria-live="polite" style={{ maxWidth: 900, margin: '0 auto', padding: '26px clamp(20px, 4vw, 38px)', borderLeft: '3px solid #c8a96b', background: '#111a28', borderRadius: '0 16px 16px 0' }}>
          <h2 style={{ marginTop: 0 }}>{t.pilotTitle}</h2>
          <p style={{ color: '#b6c3d8', lineHeight: 1.7 }}>{t.pilotText}</p>
          <p style={{ color: '#8f9eb4', fontSize: 12 }}>{t.note}</p>
          <a href="/learning" style={{ color: '#c6d8f5', fontWeight: 700 }}>{t.pilotLink} →</a>
        </section>

        <footer style={{ margin: '42px auto 0', textAlign: 'center', color: '#75859d', fontSize: 12 }}>OSGARD WORLD · OSA Learning</footer>
      </div>
    </main>
  )
}
