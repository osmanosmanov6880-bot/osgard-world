import { useEffect, useMemo, useState } from 'react'
import { ArrowLeft, ArrowRight, ArrowUpRight, BookOpen, CheckCircle2, CircleHelp, ClipboardCheck, ExternalLink, Languages, ListChecks } from 'lucide-react'
import { getOSACinemaLessons, type OSACinemaLocale } from './OSACinema'
import { OSA_LESSON_SLUGS, osaLessonGuides } from './osaLessonGuides'
import { osaLessonReadings } from './osaLessonReading'
import { OsgardLogo } from './OsgardLogo'
import OSAMediaPlayer from './OSAMediaPlayer'
import { getOSALessonMedia } from './osaMediaCatalog'
import { getOSALearningProgress, isOSALearningProgressPersistent, markOSALessonOpened, setOSALessonCompletion, subscribeOSALearningProgress } from './osaProgress'
import './osaLessonPage.css'

const copy = {
  ru: {
    kicker: 'OSA ORIGINAL / ПОДРОБНАЯ ЛЕКЦИЯ',
    back: 'Все лекции',
    academy: 'AI Academy',
    act: 'АКТ',
    minutes: 'Оценка 15–20 минут · в своём темпе',
    objectives: 'После урока вы сможете',
    material: 'Основной учебный материал',
    materialIntro: 'Три последовательных блока связывают ключевую идею, её применение и ограничения.',
    keyTakeaways: 'Ключевые выводы',
    example: 'Пример из практики',
    glossary: 'Словарь',
    check: 'Проверьте понимание',
    choose: 'Выберите один ответ. Это самопроверка, не экзамен.',
    right: 'Верно. ',
    wrong: 'Пока неверно. ',
    exercise: 'Практическое задание',
    sources: 'Источники для дальнейшего изучения',
    sourcesNote: 'Ссылки ведут к материалам первичных организаций и исследовательских ресурсов. Проверяйте даты, методы и ограничения самих источников.',
    complete: 'Отметить урок изученным',
    completed: 'Урок отмечен изученным',
    completionNote: 'Отметка и общий прогресс сохраняются только в этом браузере. Это не сертификат и не синхронизация с аккаунтом.',
    storageWarning: 'Браузер не разрешил сохранять прогресс. Отметка сохранится только до закрытия этой страницы.',
    openInteractive: 'Открыть интерактивную сцену',
    previous: 'Предыдущий урок',
    next: 'Следующий урок',
    finish: 'Вернуться к каталогу',
    mediaTitle: 'Аудио и видеоверсия',
    mediaBody: 'Исходные материалы частично найдены в Runway, но постоянные ссылки и воспроизводимый плеер на сайте пока не опубликованы. Здесь не показываем фиктивную кнопку воспроизведения.',
    mediaLink: 'Статус медиа и реестр',
    notFound: 'Такой урок не найден',
    notFoundBody: 'Откройте каталог и выберите одну из доступных лекций.',
    progress: 'Уроков отмечено',
    locale: 'Переключить язык',
  },
  en: {
    kicker: 'OSA ORIGINAL / LESSON DETAIL',
    back: 'All lectures',
    academy: 'AI Academy',
    act: 'ACT',
    minutes: 'Estimated 15–20 minutes · self-paced',
    objectives: 'By the end of this lesson, you can',
    material: 'Core lesson material',
    materialIntro: 'Three connected sections move from the main idea to application and limitations.',
    keyTakeaways: 'Key takeaways',
    example: 'Practical example',
    glossary: 'Glossary',
    check: 'Check your understanding',
    choose: 'Choose one answer. This is a self-check, not an exam.',
    right: 'Correct. ',
    wrong: 'Not quite. ',
    exercise: 'Practical exercise',
    sources: 'Sources for further study',
    sourcesNote: 'Links lead to primary organisations and research resources. Check each source’s dates, methods and limitations.',
    complete: 'Mark lesson complete',
    completed: 'Lesson marked complete',
    completionNote: 'This mark and the overall progress are stored only in this browser. It is not a certificate or account sync.',
    storageWarning: 'The browser did not allow progress to be saved. This mark will last only until this page is closed.',
    openInteractive: 'Open the interactive scene',
    previous: 'Previous lesson',
    next: 'Next lesson',
    finish: 'Return to catalogue',
    mediaTitle: 'Audio and video version',
    mediaBody: 'Some source assets were found in Runway, but permanent links and a playable site player have not been published yet. No fake play button is shown here.',
    mediaLink: 'Media status and inventory',
    notFound: 'Lesson not found',
    notFoundBody: 'Open the catalogue and choose one of the available lessons.',
    progress: 'Lessons completed',
    locale: 'Switch language',
  },
} as const

export default function OSALessonPage({ slug }: { slug: string }) {
  const [locale, setLocale] = useState<OSACinemaLocale>('ru')
  const [selectedOption, setSelectedOption] = useState<number | null>(null)
  const [completedSlugs, setCompletedSlugs] = useState<string[]>([])
  const [storageUnavailable, setStorageUnavailable] = useState(false)
  const t = copy[locale]
  const lessons = useMemo(() => getOSACinemaLessons(locale), [locale])
  const lessonIndex = (OSA_LESSON_SLUGS as readonly string[]).indexOf(slug)
  const lesson = lessonIndex >= 0 ? lessons[lessonIndex] : null
  const guide = lessonIndex >= 0 ? osaLessonGuides[locale][lessonIndex] : null
  const reading = lessonIndex >= 0 ? osaLessonReadings[locale][OSA_LESSON_SLUGS[lessonIndex]] : null
  const totalLessons = OSA_LESSON_SLUGS.length
  const isComplete = completedSlugs.includes(slug)

  useEffect(() => {
    const refreshProgress = () => {
      setCompletedSlugs(getOSALearningProgress().lessonCompletions)
      setStorageUnavailable(!isOSALearningProgressPersistent())
    }
    refreshProgress()
    const unsubscribeOSAProgress = subscribeOSALearningProgress(refreshProgress)
    return unsubscribeOSAProgress
  }, [])

  useEffect(() => {
    markOSALessonOpened(slug)
  }, [slug])

  useEffect(() => {
    setSelectedOption(null)
  }, [slug, locale])

  const markComplete = () => {
    const persisted = setOSALessonCompletion(slug, !isComplete)
    setCompletedSlugs(getOSALearningProgress().lessonCompletions)
    setStorageUnavailable(!persisted)
  }

  if (!lesson || !guide || !reading) {
    return <main className="osa-lesson-page">
      <header className="osa-lesson-header"><a className="osa-lesson-brand" href="/academy"><OsgardLogo /><span>AI ACADEMY</span></a></header>
      <section className="osa-lesson-not-found"><p className="osa-lesson-eyebrow">OSA ORIGINAL</p><h1>{t.notFound}</h1><p>{t.notFoundBody}</p><a className="osa-lesson-button" href="/lectures"><ArrowLeft size={16} />{t.back}</a></section>
    </main>
  }

  const previousSlug = lessonIndex > 0 ? OSA_LESSON_SLUGS[lessonIndex - 1] : null
  const nextSlug = lessonIndex < totalLessons - 1 ? OSA_LESSON_SLUGS[lessonIndex + 1] : null
  const passed = selectedOption === guide.check.correctIndex

  return <main className="osa-lesson-page">
    <header className="osa-lesson-header">
      <a className="osa-lesson-brand" href="/academy" aria-label="OSGARD AI Academy"><OsgardLogo /><span>AI ACADEMY</span></a>
      <nav aria-label={locale === 'ru' ? 'Навигация урока' : 'Lesson navigation'}>
        <a href="/lectures">{t.back}</a>
        <a href="/academy">{t.academy}</a>
        <button type="button" onClick={() => setLocale(locale === 'ru' ? 'en' : 'ru')} aria-label={t.locale}><Languages size={15} />{locale.toUpperCase()}</button>
      </nav>
    </header>

    <section className="osa-lesson-hero">
      <div className="osa-lesson-hero-copy">
        <p className="osa-lesson-eyebrow"><span />{t.kicker}</p>
        <p className="osa-lesson-number">{String(lessonIndex + 1).padStart(2, '0')} / 08 · {t.act} {lesson.act}</p>
        <h1>{lesson.title}</h1>
        <p className="osa-lesson-lead">{lesson.body}</p>
        <div className="osa-lesson-meta"><span><BookOpen size={15} />{t.minutes}</span><span>{t.progress}: {completedSlugs.length} / {totalLessons}</span></div>
        <div className="osa-lesson-progress" role="progressbar" aria-label={t.progress} aria-valuemin={0} aria-valuemax={totalLessons} aria-valuenow={completedSlugs.length}><span style={{ width: (completedSlugs.length / totalLessons * 100) + '%' }} /></div>
      </div>
      <aside className="osa-lesson-key-insight"><span>KEY INSIGHT</span><p>{lesson.takeaway}</p><div><span>{t.act} {lesson.act}</span><span>{String(lessonIndex + 1).padStart(2, '0')} / 08</span></div></aside>
    </section>

    <div className="osa-lesson-content">
      <section className="osa-lesson-block" aria-labelledby="osa-lesson-objectives">
        <div className="osa-lesson-section-title"><span>01</span><div><p className="osa-lesson-eyebrow">{t.kicker}</p><h2 id="osa-lesson-objectives">{t.objectives}</h2></div></div>
        <ul className="osa-lesson-objectives">{guide.objectives.map((objective, index) => <li key={index}><CheckCircle2 size={17} /><span>{objective}</span></li>)}</ul>
      </section>

      <section className="osa-lesson-block" aria-labelledby="osa-lesson-material">
        <div className="osa-lesson-section-title"><span>02</span><div><p className="osa-lesson-eyebrow">READ / UNDERSTAND</p><h2 id="osa-lesson-material">{t.material}</h2><p>{t.materialIntro}</p></div></div>
        <div className="osa-lesson-reading-sections">
          {reading.sections.map((section, index) => <article className="osa-lesson-reading-section" key={section.heading}>
            <div className="osa-lesson-reading-section-title"><span>0{index + 1}</span><h3>{section.heading}</h3></div>
            <p>{section.body}</p>
            <ul>{section.checkpoints.map((point, pointIndex) => <li key={pointIndex}>{point}</li>)}</ul>
          </article>)}
        </div>
      </section>

      <section className="osa-lesson-block" aria-labelledby="osa-lesson-example">
        <div className="osa-lesson-section-title"><span>03</span><div><p className="osa-lesson-eyebrow">CASE / FIELD NOTE</p><h2 id="osa-lesson-example">{t.example}</h2></div></div>
        <div className="osa-lesson-reading"><p>{guide.example}</p></div>
      </section>

      <section className="osa-lesson-block" aria-labelledby="osa-lesson-glossary">
        <div className="osa-lesson-section-title"><span>04</span><div><p className="osa-lesson-eyebrow">LANGUAGE / CONCEPTS</p><h2 id="osa-lesson-glossary">{t.glossary}</h2></div></div>
        <dl className="osa-lesson-glossary">{guide.glossary.map((item, index) => <div key={index}><dt>{item.term}</dt><dd>{item.definition}</dd></div>)}</dl>
      </section>

      <section className="osa-lesson-block" aria-labelledby="osa-lesson-check">
        <div className="osa-lesson-section-title"><span>05</span><div><p className="osa-lesson-eyebrow">SELF-CHECK / 01</p><h2 id="osa-lesson-check">{t.check}</h2><p>{t.choose}</p></div></div>
        <div className="osa-lesson-quiz">
          <h3>{guide.check.question}</h3>
          <fieldset>
            <legend className="osa-lesson-sr-only">{guide.check.question}</legend>
            {guide.check.options.map((option, index) => <label className={'osa-lesson-option' + (selectedOption === index ? ' is-selected' : '')} key={option}>
              <input type="radio" name="osa-lesson-check" value={index} checked={selectedOption === index} onChange={() => setSelectedOption(index)} />
              <span className="osa-lesson-option-number">0{index + 1}</span><span>{option}</span>
            </label>)}
          </fieldset>
          {selectedOption !== null && <div className={'osa-lesson-feedback ' + (passed ? 'is-correct' : 'is-incorrect')} role="status" aria-live="polite"><strong>{passed ? t.right : t.wrong}</strong>{guide.check.explanation}</div>}
        </div>
      </section>

      <section className="osa-lesson-block" aria-labelledby="osa-lesson-exercise">
        <div className="osa-lesson-section-title"><span>06</span><div><p className="osa-lesson-eyebrow">APPLIED PRACTICE</p><h2 id="osa-lesson-exercise">{t.exercise}</h2></div></div>
        <article className="osa-lesson-exercise"><h3><ClipboardCheck size={19} />{guide.exercise.title}</h3><ol>{guide.exercise.steps.map((step, index) => <li key={index}>{step}</li>)}</ol><div className="osa-lesson-success"><ListChecks size={18} /><p><strong>{locale === 'ru' ? 'Критерий результата' : 'Success criterion'}</strong>{guide.exercise.successCriteria}</p></div></article>
      </section>

      <section className="osa-lesson-block" aria-labelledby="osa-lesson-takeaways">
        <div className="osa-lesson-section-title"><span>07</span><div><p className="osa-lesson-eyebrow">REVIEW / REMEMBER</p><h2 id="osa-lesson-takeaways">{t.keyTakeaways}</h2></div></div>
        <ul className="osa-lesson-summary">{reading.keyTakeaways.map((item, index) => <li key={index}><span>0{index + 1}</span><p>{item}</p></li>)}</ul>
      </section>

      <section className="osa-lesson-block" aria-labelledby="osa-lesson-sources">
        <div className="osa-lesson-section-title"><span>08</span><div><p className="osa-lesson-eyebrow">READ / VERIFY</p><h2 id="osa-lesson-sources">{t.sources}</h2><p>{t.sourcesNote}</p></div></div>
        <div className="osa-lesson-sources">{guide.sources.map(source => <a href={source.url} target="_blank" rel="noopener noreferrer" key={source.url}><span>{source.title}<ExternalLink size={14} /></span><p>{source.context}</p></a>)}</div>
      </section>

      <section className="osa-lesson-media-note" aria-labelledby="osa-lesson-media-title">
        <div><p className="osa-lesson-eyebrow">MEDIA / RELEASE STATUS</p><h2 id="osa-lesson-media-title">{t.mediaTitle}</h2><p>{t.mediaBody}</p><a href="/osa-library/">{t.mediaLink}<ArrowUpRight size={15} /></a></div>
        <CircleHelp size={24} />
      </section>

      <OSAMediaPlayer media={getOSALessonMedia(slug, locale, 'audio')} />
      <OSAMediaPlayer media={getOSALessonMedia(slug, locale, 'video')} />

      <section className="osa-lesson-completion">
        <div><p className="osa-lesson-eyebrow">LEARNING RECORD / LOCAL</p><h2>{isComplete ? t.completed : (locale === 'ru' ? 'Зафиксируйте прохождение' : 'Record this lesson')}</h2><p>{t.completionNote}</p>{storageUnavailable && <p className="osa-lesson-storage-warning" role="status">{t.storageWarning}</p>}</div>
        <button type="button" onClick={markComplete} className={isComplete ? 'is-complete' : ''}>{isComplete ? <CheckCircle2 size={17} /> : <ClipboardCheck size={17} />}{isComplete ? t.completed : t.complete}</button>
      </section>

      <section className="osa-lesson-navigation" aria-label={locale === 'ru' ? 'Переход между уроками' : 'Lesson sequence'}>
        {previousSlug ? <a href={'/lectures/' + previousSlug}><ArrowLeft size={16} /><span><small>{t.previous}</small><strong>{lessons[lessonIndex - 1].title}</strong></span></a> : <a href="/lectures"><ArrowLeft size={16} /><span><small>{t.back}</small><strong>{t.finish}</strong></span></a>}
        <a className="osa-lesson-interactive-link" href={'/osa-cinema?scene=' + lessonIndex}><span><small>{locale === 'ru' ? 'ПРАКТИКА В КУРСЕ' : 'PRACTISE IN COURSE'}</small><strong>{t.openInteractive}</strong></span><ArrowUpRight size={17} /></a>
        {nextSlug ? <a className="osa-lesson-next-link" href={'/lectures/' + nextSlug}><span><small>{t.next}</small><strong>{lessons[lessonIndex + 1].title}</strong></span><ArrowRight size={16} /></a> : <a className="osa-lesson-next-link" href="/lectures"><span><small>{t.finish}</small><strong>{t.back}</strong></span><ArrowRight size={16} /></a>}
      </section>
    </div>
    <footer className="osa-lesson-footer"><a href="/academy"><OsgardLogo /><span>OSGARD WORLD × OSA ORIGINAL</span></a><span>{lesson.tag}</span></footer>
  </main>
}
