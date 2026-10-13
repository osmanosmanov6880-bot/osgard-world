import { ArrowRight, ArrowUpRight, BookOpen, BrainCircuit, Compass, ShieldCheck, Sparkles } from 'lucide-react'
import { useMemo, useState } from 'react'
import { getOSACinemaLessons, type OSACinemaLocale } from './OSACinema'
import { OsgardLogo } from './OsgardLogo'
import './academyHome.css'

const contentByLocale = {
  ru: {
    brand:'AI ACADEMY', paths:'Маршруты', products:'Продукты', games:'Игры', portal:'Портал OSGARD',
    switchLanguage:'Switch to English', kicker:'OSGARD · AI ACADEMY',
    hero1:'Понимайте ИИ.', hero2:'Проверяйте ответы.', hero3:'Действуйте осознанно.',
    lead:'Практическое знакомство с искусственным интеллектом: как работают модели, почему убедительный ответ ещё не доказательство и как использовать ИИ, сохраняя человеческую ответственность.',
    start:'Начать обучение', explore:'Выбрать маршрут', signals:['Интерактивное обучение','На русском и английском','Прогресс на устройстве'],
    pathsEyebrow:'ВХОД С ВАШЕЙ ЦЕЛЬЮ', pathsTitle:'Выберите, с чего начать',
    pathsIntro:'Одна существующая учебная история — три фокуса, которые помогают связать её с вашей задачей.',
    path1:'Новичкам: основы ИИ', path1Body:'Разберитесь, как работают языковые модели, и почему важно проверять их ответы.',
    path2:'Для предпринимателей', path2Body:'Оценивайте идеи через конкретную задачу, ограничения и цену ошибки.',
    path3:'Для профессионалов', path3Body:'Отличайте факты от интерпретаций, проверяйте источники и сохраняйте ответственность за решение.',
    pathAction:'Открыть учебную историю', available:'УЖЕ ДОСТУПНО',
    courseTitle:'OSA Original: ИИ, власть знаний и будущее человека',
    courseBody:'Три акта интерактивного обучения — о возможностях моделей, доступе к знаниям и решениях человека. Выборы, пояснения и прогресс уже реализованы в существующем опыте.',
    scenes:'учебных сцен', verification:'Проверка источников', continue:'Продолжить в OSA Original',
    lessonsEyebrow:'СОДЕРЖАНИЕ КУРСА', lessonsTitle:'Темы внутри существующей программы',
    lessonsIntro:'Названия и описания берутся из реальных сцен OSA Original.', lessonAction:'Изучить в курсе',
    practicalEyebrow:'ПЕРЕЙДИТЕ К ПРАКТИКЕ',
    practicalTitle:'Используйте ИИ как помощника, а не как источник истины',
    practicalIntro:'Три привычки, отражённые в текущей учебной программе.',
    practical1:'Сформулируйте задачу', practical1Body:'Определите цель, ограничения и то, что будет считаться хорошим результатом.',
    practical2:'Попросите черновик', practical2Body:'Используйте модель для вариантов и первого прохода, а не как замену собственному суждению.',
    practical3:'Проверьте важное', practical3Body:'Найдите первоисточники для значимых утверждений, обозначьте неопределённость и проверьте последствия.',
    ecosystemEyebrow:'ОДИН БРЕНД · НЕСКОЛЬКО НАПРАВЛЕНИЙ', ecosystemTitle:'Продолжайте исследовать OSGARD',
    productsBody:'Просмотрите каталог и выберите цифровое решение для своей задачи.', productsAction:'Открыть каталог',
    gamesBody:'Перейдите в игровой архив и запустите доступный интерактивный мир.', gamesAction:'Открыть игры',
    portalBody:'К прежнему порталу OSGARD сохранён отдельный маршрут.', portalAction:'Перейти в портал',
    finalEyebrow:'СДЕЛАЙТЕ СЛЕДУЮЩИЙ ШАГ', finalTitle:'Начните с вопроса. Завершите проверенным решением.',
    finalBody:'Пройдите интерактивную историю и выберите одну привычку, которую примените в своей следующей задаче с ИИ.',
    footer:'Учитесь понимать. Проверяйте источники. Решайте осознанно.'
  },
  en: {
    brand:'AI ACADEMY', paths:'Learning paths', products:'Products', games:'Games', portal:'OSGARD portal',
    switchLanguage:'Переключить на русский', kicker:'OSGARD · AI ACADEMY',
    hero1:'Understand AI.', hero2:'Verify its answers.', hero3:'Act with intention.',
    lead:'A practical introduction to artificial intelligence: how models work, why a convincing answer is not proof, and how to use AI while keeping human responsibility in view.',
    start:'Start learning', explore:'Choose a path', signals:['Interactive learning','English and Russian','Progress on this device'],
    pathsEyebrow:'START WITH YOUR GOAL', pathsTitle:'Choose where to begin',
    pathsIntro:'One existing learning experience, with three starting points to connect it to your own work.',
    path1:'AI fundamentals for beginners', path1Body:'Understand how language models work and why their answers need verification.',
    path2:'For entrepreneurs', path2Body:'Evaluate ideas against a real task, limitations, and the cost of getting it wrong.',
    path3:'For professionals', path3Body:'Separate facts from interpretation, check sources, and keep responsibility for decisions.',
    pathAction:'Explore the learning experience', available:'AVAILABLE NOW',
    courseTitle:'OSA Original: AI, knowledge, and human agency',
    courseBody:'Three acts of interactive learning about model capabilities, access to knowledge, and human decisions. Choices, explanations, and progress are already part of the existing experience.',
    scenes:'learning scenes', verification:'Source verification', continue:'Continue in OSA Original',
    lessonsEyebrow:'COURSE CONTENT', lessonsTitle:'Inside the current curriculum',
    lessonsIntro:'Titles and summaries are sourced from the existing OSA Original scenes.', lessonAction:'Explore in the course',
    practicalEyebrow:'PUT LEARNING INTO PRACTICE',
    practicalTitle:'Use AI as an assistant, not as a source of truth',
    practicalIntro:'Three habits reflected in the current learning content.',
    practical1:'Define the task', practical1Body:'Set the goal, constraints, and what a good result would look like.',
    practical2:'Ask for a draft', practical2Body:'Use a model for options and a first pass, not as a replacement for your judgement.',
    practical3:'Verify what matters', practical3Body:'Find primary sources for consequential claims, identify uncertainty, and consider the impact.',
    ecosystemEyebrow:'ONE BRAND · MULTIPLE DIRECTIONS', ecosystemTitle:'Keep exploring OSGARD',
    productsBody:'Browse the catalogue and choose a digital product for your needs.', productsAction:'Browse products',
    gamesBody:'Open the game archive and launch an available interactive world.', gamesAction:'Explore games',
    portalBody:'The previous OSGARD portal remains available on its own route.', portalAction:'Open the portal',
    finalEyebrow:'TAKE THE NEXT STEP', finalTitle:'Start with a question. Finish with a verified decision.',
    finalBody:'Complete the interactive story and choose one habit to use in your next AI-assisted task.',
    footer:'Understand the system. Verify the sources. Decide with care.'
  }
} as const

export default function AcademyHome() {
  const [locale, setLocale] = useState<OSACinemaLocale>('ru')
  const [activeAct, setActiveAct] = useState<number | null>(null)
  const t = contentByLocale[locale]
  const lessons = getOSACinemaLessons(locale)
  const visibleLessons = useMemo(() => activeAct === null ? lessons : lessons.filter(lesson => lesson.act === activeAct), [activeAct, lessons])
  const lessonFilters = [{ value:null as number | null, label:t.lessonAll }, { value:1, label:t.lessonAct1 }, { value:2, label:t.lessonAct2 }, { value:3, label:t.lessonAct3 }]
  const pathways = [
    { number:'01', title:t.path1, body:t.path1Body, Icon:BrainCircuit },
    { number:'02', title:t.path2, body:t.path2Body, Icon:Compass },
    { number:'03', title:t.path3, body:t.path3Body, Icon:ShieldCheck }
  ]
  const habits = [
    { number:'01', title:t.practical1, body:t.practical1Body },
    { number:'02', title:t.practical2, body:t.practical2Body },
    { number:'03', title:t.practical3, body:t.practical3Body }
  ]

  return <main className="academy-home">
    <header className="academy-header">
      <a className="academy-brand" href="/" aria-label="OSGARD AI Academy home">
        <OsgardLogo className="academy-logo" /><span>{t.brand}</span>
      </a>
      <nav className="academy-nav" aria-label={locale === 'ru' ? 'Основная навигация' : 'Main navigation'}>
        <a href="#paths">{t.paths}</a><a href="/catalog">{t.products}</a><a href="/games/">{t.games}</a><a href="/portal">{t.portal}</a>
      </nav>
      <div className="academy-header-actions">
        <button className="academy-language" type="button" onClick={() => setLocale(locale === 'ru' ? 'en' : 'ru')} aria-label={t.switchLanguage}>{locale.toUpperCase()}</button>
        <a className="academy-header-cta" href="/osa-cinema">{t.start}<ArrowUpRight size={15} aria-hidden="true" /></a>
      </div>
    </header>

    <section className="academy-hero">
      <div className="academy-hero-copy">
        <p className="academy-eyebrow"><span className="academy-eyebrow-dot" />{t.kicker}</p>
        <h1>{t.hero1}<br /><span>{t.hero2}</span><br />{t.hero3}</h1>
        <p className="academy-lead">{t.lead}</p>
        <div className="academy-hero-actions">
          <a className="academy-button academy-button-primary" href="/osa-cinema"><BookOpen size={17} aria-hidden="true" />{t.start}<ArrowUpRight size={16} aria-hidden="true" /></a>
          <a className="academy-button academy-button-secondary" href="#paths">{t.explore}<ArrowRight size={16} aria-hidden="true" /></a>
        </div>
        <div className="academy-proof-row" aria-label={locale === 'ru' ? 'Возможности обучения' : 'Learning details'}>
          {t.signals.map(signal => <span key={signal}><i aria-hidden="true" />{signal}</span>)}
        </div>
      </div>
      <div className="academy-hero-art" aria-hidden="true">
        <div className="academy-art-grid" /><div className="academy-art-orbit academy-art-orbit-one" />
        <div className="academy-art-orbit academy-art-orbit-two" />
        <div className="academy-art-core"><Sparkles size={32} /><strong>AI</strong><small>LEARN / VERIFY / APPLY</small></div>
        <div className="academy-art-label academy-art-label-one">MODEL / 01</div>
        <div className="academy-art-label academy-art-label-two">EVIDENCE / 02</div>
        <div className="academy-art-label academy-art-label-three">HUMAN / 03</div>
      </div>
    </section>

    <section className="academy-section academy-paths" id="paths">
      <div className="academy-section-heading"><div><p className="academy-eyebrow">{t.pathsEyebrow}</p><h2>{t.pathsTitle}</h2></div><p>{t.pathsIntro}</p></div>
      <div className="academy-path-grid">
        {pathways.map(({ number, title, body, Icon }) => <article className="academy-path-card" key={number}>
          <div className="academy-path-top"><span>{number}</span><Icon size={22} aria-hidden="true" /></div>
          <h3>{title}</h3><p>{body}</p><a href="/osa-cinema">{t.pathAction}<ArrowRight size={15} aria-hidden="true" /></a>
        </article>)}
      </div>
    </section>

    <section className="academy-section academy-course" id="learning">
      <div className="academy-course-feature">
        <div className="academy-course-copy">
          <p className="academy-eyebrow">{t.available}</p><h2>{t.courseTitle}</h2><p>{t.courseBody}</p>
          <div className="academy-course-meta"><span><BookOpen size={15} aria-hidden="true" />{lessons.length} {t.scenes}</span><span><ShieldCheck size={15} aria-hidden="true" />{t.verification}</span></div>
          <a className="academy-button academy-button-primary" href="/osa-cinema">{t.continue}<ArrowUpRight size={16} aria-hidden="true" /></a>
        </div>
        <div className="academy-course-art" aria-hidden="true"><div className="academy-course-ring" /><div className="academy-course-mark">OSA<span>×</span>AI</div><div className="academy-course-art-caption">ORIGINAL LEARNING EXPERIENCE</div></div>
      </div>
      <div className="academy-section-heading academy-lessons-heading">
        <div><p className="academy-eyebrow">{t.lessonsEyebrow}</p><h2>{t.lessonsTitle}</h2></div><p>{t.lessonsIntro}</p>
      </div>
      <div className="academy-lesson-filters" role="group" aria-label={locale === 'ru' ? 'Фильтр тем курса' : 'Filter course topics'}>
        {lessonFilters.map(filter => <button key={filter.value ?? 'all'} type="button" aria-pressed={activeAct === filter.value} className={activeAct === filter.value ? 'active' : ''} onClick={() => setActiveAct(filter.value)}>{filter.label}</button>)}
        <span aria-live="polite">{visibleLessons.length} {t.lessonCount}</span>
      </div>
      <div className="academy-lesson-grid">
        {visibleLessons.map((lesson, index) => <a className="academy-lesson-card" href={`/osa-cinema?scene=${Number(lesson.id.split('-').at(-1))}`} key={lesson.id}>
          <span>{lesson.tag}</span><h3>{lesson.title}</h3><p>{lesson.body}</p><strong>{t.lessonAction}<ArrowUpRight size={15} aria-hidden="true" /></strong>
        </a>)}
      </div>
    </section>

    <section className="academy-section academy-practice">
      <div className="academy-section-heading"><div><p className="academy-eyebrow">{t.practicalEyebrow}</p><h2>{t.practicalTitle}</h2></div><p>{t.practicalIntro}</p></div>
      <div className="academy-practice-grid">
        {habits.map(item => <article className="academy-practice-card" key={item.number}><span>{item.number}</span><h3>{item.title}</h3><p>{item.body}</p></article>)}
      </div>
    </section>

    <section className="academy-section academy-ecosystem">
      <div className="academy-section-heading"><div><p className="academy-eyebrow">{t.ecosystemEyebrow}</p><h2>{t.ecosystemTitle}</h2></div></div>
      <div className="academy-ecosystem-grid">
        <a className="academy-ecosystem-card" href="/catalog"><span className="academy-ecosystem-number">01 / PRODUCTS</span><h3>{t.products}</h3><p>{t.productsBody}</p><strong>{t.productsAction}<ArrowUpRight size={15} aria-hidden="true" /></strong></a>
        <a className="academy-ecosystem-card academy-ecosystem-games" href="/games/"><span className="academy-ecosystem-number">02 / PLAY</span><h3>{t.games}</h3><p>{t.gamesBody}</p><strong>{t.gamesAction}<ArrowUpRight size={15} aria-hidden="true" /></strong></a>
        <a className="academy-ecosystem-card academy-ecosystem-portal" href="/portal"><span className="academy-ecosystem-number">03 / OSGARD</span><h3>{t.portal}</h3><p>{t.portalBody}</p><strong>{t.portalAction}<ArrowUpRight size={15} aria-hidden="true" /></strong></a>
      </div>
    </section>

    <section className="academy-final-cta">
      <p className="academy-eyebrow">{t.finalEyebrow}</p><h2>{t.finalTitle}</h2><p>{t.finalBody}</p>
      <a className="academy-button academy-button-primary" href="/osa-cinema"><BookOpen size={17} aria-hidden="true" />{t.start}<ArrowUpRight size={16} aria-hidden="true" /></a>
    </section>

    <footer className="academy-footer">
      <a href="/" className="academy-footer-brand"><OsgardLogo variant="footer" className="academy-logo" /><span>{t.brand}</span></a>
      <p>{t.footer}</p><div><a href="/catalog">{t.products}</a><a href="/games/">{t.games}</a><a href="/portal">{t.portal}</a></div>
    </footer>
  </main>
}
