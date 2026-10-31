type Locale = 'ru' | 'en'

const filmCopy = {
  ru: {
    label: 'OSA CINEMA / НАУЧНО-ДОКУМЕНТАЛЬНЫЙ ФИЛЬМ',
    title: 'За пределами модели',
    description: 'Понять ИИ. Проверить ответ. Оставить решение человеку. Интерактивная история о том, как сохранять ясность, когда ответ звучит убедительно.',
    free: 'Трейлер и глава I доступны бесплатно',
    prepared: 'Главы II–III · подписной выпуск готовится',
    cta: 'Смотреть фильм и открыть главы',
    alt: 'Кинематографичный кадр: исследователь в глубине старинной библиотеки',
  },
  en: {
    label: 'OSA CINEMA / SCIENTIFIC DOCUMENTARY',
    title: 'Beyond the Model',
    description: 'Understand AI. Check its answer. Keep the decision human. An interactive story about staying clear-minded when an answer sounds convincing.',
    free: 'Trailer and chapter I are free',
    prepared: 'Chapters II–III · subscription release in preparation',
    cta: 'Watch the film and explore chapters',
    alt: 'Cinematic still of a researcher inside a monumental library',
  },
}

export default function OSACinemaFeature({ locale }: { locale: Locale }) {
  const t = filmCopy[locale]
  return <section className="intelligence-cinema-feature" aria-labelledby="intelligence-cinema-title">
    <div className="intelligence-cinema-poster">
      <img
        src="https://osa-cinema-beyond-the-model.osman-absolu-5357.chatgpt.site/media/reference/library.webp"
        alt={t.alt}
        loading="lazy"
        decoding="async"
        width="1200"
        height="800"
      />
      <span className="intelligence-cinema-poster-mark" aria-hidden="true">OSA <i>◉</i> CINEMA</span>
      <span className="intelligence-cinema-poster-index" aria-hidden="true">01—03</span>
    </div>
    <div className="intelligence-cinema-copy">
      <p className="brand-eyebrow">{t.label}</p>
      <h2 id="intelligence-cinema-title">{t.title}</h2>
      <p className="intelligence-cinema-description">{t.description}</p>
      <div className="intelligence-cinema-status" aria-label={locale === 'ru' ? 'Доступность фильма' : 'Film availability'}>
        <span><i aria-hidden="true" />{t.free}</span>
        <span>{t.prepared}</span>
      </div>
      <a
        className="intelligence-cinema-button"
        href={locale === 'en'
          ? 'https://osa-cinema-beyond-the-model.osman-absolu-5357.chatgpt.site/?lang=en#watch'
          : 'https://osa-cinema-beyond-the-model.osman-absolu-5357.chatgpt.site/?lang=ru#watch'}
        target="_blank"
        rel="noopener noreferrer"
      >{t.cta}<span aria-hidden="true">↗</span></a>
    </div>
  </section>
}
