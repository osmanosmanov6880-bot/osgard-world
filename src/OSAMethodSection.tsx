type Locale = 'ru' | 'en'

const methodCopy = {
  ru: {
    label: '01 / МЕТОД',
    titleA: 'Три действия.',
    titleB: 'Одно осознанное решение.',
    steps: [
      ['Понять', 'Как устроена модель, что она умеет и где её ограничения.'],
      ['Проверить', 'Что подтверждает утверждение и где находится первоисточник.'],
      ['Решить', 'Что можно применить, что уточнить и где нужен человек.'],
    ],
  },
  en: {
    label: '01 / METHOD',
    titleA: 'Three actions.',
    titleB: 'One considered decision.',
    steps: [
      ['Understand', 'How a model works, what it can do, and where its limits are.'],
      ['Verify', 'What supports a claim and where to find the original source.'],
      ['Decide', 'What to apply, what to clarify, and when a person is needed.'],
    ],
  },
}

export default function OSAMethodSection({ locale }: { locale: Locale }) {
  const t = methodCopy[locale]
  return <section className="brand-section" aria-labelledby="intelligence-method-title">
    <div className="brand-section-heading">
      <p className="brand-eyebrow">{t.label}</p>
      <h2 id="intelligence-method-title">{t.titleA}<br /><em>{t.titleB}</em></h2>
    </div>
    <div className="intelligence-method">
      {t.steps.map(([title, text], index) => <div key={title}>
        <span>0{index + 1}</span><h3>{title}</h3><p>{text}</p>
      </div>)}
    </div>
  </section>
}
