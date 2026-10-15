import { useMemo, useState } from 'react'
import { ArrowLeft, ArrowRight, ArrowUpRight, BookOpen, Clapperboard, CirclePlay, Languages } from 'lucide-react'
import { getOSACinemaLessons, type OSACinemaLocale } from './OSACinema'
import { OsgardLogo } from './OsgardLogo'
import { OSA_LESSON_SLUGS } from './osaLessonGuides'
import './lectureLibrary.css'

const actCopy = {
  ru: [
    { n: '01', title: 'ИИ меняет правила', subtitle: 'Возможности моделей и границы доверия', description: 'Понять, как работают языковые модели, почему они могут ошибаться и как проверять результат.' },
    { n: '02', title: 'Власть знаний', subtitle: 'Источники, влияние и приватность', description: 'Отделять первоисточники от пересказов, проверять утверждения и беречь чувствительный контекст.' },
    { n: '03', title: 'Человек и будущее', subtitle: 'Практика, ответственность и выбор', description: 'Использовать ИИ как помощника, сравнивать варианты и сохранять ответственность за решение.' },
  ],
  en: [
    { n: '01', title: 'AI changes the rules', subtitle: 'Model capabilities and the limits of trust', description: 'Understand language models, why they can fail, and how to verify their output.' },
    { n: '02', title: 'The power of knowledge', subtitle: 'Sources, influence and privacy', description: 'Distinguish primary sources from repetition, verify claims and protect sensitive context.' },
    { n: '03', title: 'Human agency and the future', subtitle: 'Practice, responsibility and choice', description: 'Use AI as an assistant, compare alternatives and retain responsibility for decisions.' },
  ],
} as const

const copy = {
  ru: {
    kicker: 'OSGARD AI ACADEMY / КУРСЫ И ЛЕКЦИИ',
    title: 'Обучение OSA — по порядку, от первой сцены до практики.',
    intro: 'Материалы OSA Intelligence перенесены в единый каталог: три акта и все восемь существующих интерактивных сцен на русском и английском языках.',
    start: 'Начать первую лекцию',
    back: 'В AI Academy',
    order: 'ПРОГРАММА КУРСА',
    acts: 'Три последовательных акта',
    lessons: 'Все лекции и сцены',
    lessonsIntro: 'Открывайте любую тему отдельно или проходите программу последовательно. Прогресс интерактивного курса сохраняется в браузере.',
    available: 'Интерактивный урок доступен',
    open: 'Открыть урок',
    videoTitle: 'О видеоверсии',
    videoBody: 'В исходном репозитории OSA найден реестр видеоматериалов, но у видеозаписей нет постоянных URL, а файлов MP4/WebM в репозитории нет. Поэтому мы не показываем фиктивные видеоплееры: ниже доступны реальные интерактивные лекции; видеозаписи появятся после публикации самих файлов.',
    videoStatus: 'Видеозаписи пока не опубликованы',
    mediaLibrary: 'Открыть реестр 31 медиафайла',
    count: 'сцен',
    actLabel: 'АКТ',
    lessonLabel: 'ИНТЕРАКТИВНАЯ ЛЕКЦИЯ',
    videoLabel: 'ВИДЕО НЕ ОПУБЛИКОВАНО',
    source: 'Источник программы: репозиторий OSA Intelligence',
    note: 'Интерактивная программа доступна сейчас. Это не утверждение, что видеоверсия уже создана.',
  },
  en: {
    kicker: 'OSGARD AI ACADEMY / COURSES & LECTURES',
    title: 'The OSA learning journey — in order, from the first scene to practice.',
    intro: 'OSA Intelligence materials are organised into one catalogue: three acts and all eight existing interactive scenes in Russian and English.',
    start: 'Start the first lecture',
    back: 'Back to AI Academy',
    order: 'COURSE CURRICULUM',
    acts: 'Three ordered acts',
    lessons: 'All lectures and scenes',
    lessonsIntro: 'Open any topic individually or follow the sequence. Interactive course progress is saved in your browser.',
    available: 'Interactive lesson available',
    open: 'Open lesson',
    videoTitle: 'About the video version',
    videoBody: 'The source OSA repository contains a video-asset manifest, but its video entries have no permanent URLs and no MP4/WebM files are stored in the repository. We therefore do not show fake video players. The existing interactive lectures are available below; recordings can appear after the actual files are published.',
    videoStatus: 'Video recordings not published yet',
    mediaLibrary: 'Open the 31-item media register',
    count: 'scenes',
    actLabel: 'ACT',
    lessonLabel: 'INTERACTIVE LECTURE',
    videoLabel: 'VIDEO NOT PUBLISHED',
    source: 'Curriculum source: OSA Intelligence repository',
    note: 'The interactive curriculum is available now. This does not claim that a video version already exists.',
  },
} as const

export default function LectureLibrary() {
  const [locale, setLocale] = useState<OSACinemaLocale>('ru')
  const t = copy[locale]
  const lessons = useMemo(() => getOSACinemaLessons(locale), [locale])
  const acts = actCopy[locale]
  const actCounts = acts.map((act, index) => ({ ...act, count: lessons.filter(lesson => lesson.act === index + 1).length, firstScene: lessons.findIndex(lesson => lesson.act === index + 1) }))

  return <main className="lecture-library">
    <header className="lecture-header">
      <a href="/academy" className="lecture-brand" aria-label="OSGARD AI Academy"><OsgardLogo /><span>AI ACADEMY</span></a>
      <nav aria-label={locale === 'ru' ? 'Навигация по курсам' : 'Course navigation'}>
        <a href="/academy">{t.back}</a>
        <button type="button" onClick={() => setLocale(locale === 'ru' ? 'en' : 'ru')} aria-label={locale === 'ru' ? 'Switch to English' : 'Переключить на русский'}><Languages size={15} /> {locale.toUpperCase()}</button>
      </nav>
    </header>

    <section className="lecture-hero">
      <p className="lecture-eyebrow"><span />{t.kicker}</p>
      <h1>{t.title}</h1>
      <p className="lecture-lead">{t.intro}</p>
      <div className="lecture-hero-meta"><span><BookOpen size={16} /> {lessons.length} {t.count}</span><span><Clapperboard size={16} /> {t.videoStatus}</span></div>
      <a className="lecture-primary" href={`/lectures/${OSA_LESSON_SLUGS[0]}`}><CirclePlay size={17} />{t.start}<ArrowUpRight size={16} /></a>
    </section>

    <section className="lecture-section" aria-labelledby="lecture-acts-title">
      <div className="lecture-section-heading"><div><p className="lecture-eyebrow">{t.order}</p><h2 id="lecture-acts-title">{t.acts}</h2></div><p>{t.source}</p></div>
      <div className="lecture-act-grid">
        {actCounts.map(act => <article className="lecture-act-card" key={act.n}>
          <span className="lecture-index">{act.n} / {t.actLabel}</span>
          <h3>{act.title}</h3><p className="lecture-act-subtitle">{act.subtitle}</p><p>{act.description}</p>
          <div className="lecture-act-foot"><span>{act.count} {t.count}</span><a href={`/lectures/${OSA_LESSON_SLUGS[Math.max(0, act.firstScene)]}`} aria-label={`${t.open}: ${act.title}`}>{t.open}<ArrowRight size={15} /></a></div>
        </article>)}
      </div>
    </section>

    <section className="lecture-section lecture-all" aria-labelledby="lecture-list-title">
      <div className="lecture-section-heading"><div><p className="lecture-eyebrow">OSA ORIGINAL / 001</p><h2 id="lecture-list-title">{t.lessons}</h2></div><p>{t.lessonsIntro}</p></div>
      <div className="lecture-list">
        {lessons.map((lesson, index) => {
          return <article className="lecture-row" key={lesson.id}>
            <span className="lecture-row-number">{String(index + 1).padStart(2, '0')}</span>
            <div className="lecture-row-copy"><span>{lesson.tag}</span><h3>{lesson.title}</h3><p>{lesson.body}</p><small>{lesson.takeaway}</small></div>
            <div className="lecture-row-action"><span>{t.available}</span><a href={`/lectures/${OSA_LESSON_SLUGS[index]}`}>{t.open}<ArrowUpRight size={15} /></a></div>
          </article>
        })}
      </div>
    </section>

    <section className="lecture-video-note" aria-labelledby="lecture-video-title">
      <div className="lecture-video-icon"><Clapperboard size={22} /></div>
      <div><p className="lecture-eyebrow">{t.videoLabel}</p><h2 id="lecture-video-title">{t.videoTitle}</h2><p>{t.videoBody}</p><small>{t.note}</small><a className="lecture-media-link" href="/osa-library/">{t.mediaLibrary}<ArrowUpRight size={15} /></a></div>
    </section>
    <footer className="lecture-footer"><a href="/academy"><ArrowLeft size={15} />{t.back}</a><span>OSGARD WORLD × OSA ORIGINAL</span><a href="/osa-cinema?scene=0">{t.start}<ArrowRight size={15} /></a></footer>
  </main>
}
