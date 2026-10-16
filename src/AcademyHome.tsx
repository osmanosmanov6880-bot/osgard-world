import { ArrowRight, ArrowUpRight, BookOpen, BrainCircuit, Compass, ShieldCheck, Sparkles } from 'lucide-react'
import { useEffect, useState } from 'react'
import { getOSACinemaLessons, type OSACinemaLocale } from './OSACinema'
import { OSA_LESSON_SLUGS } from './osaLessonRegistry'
import { getOSALearningProgress, subscribeOSALearningProgress } from './osaProgress'
import { OsgardLogo } from './OsgardLogo'
import AcademyStudio from './AcademyStudio'
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
    scenes:'учебных сцен', verification:'Проверка источников', continue:'Продолжить в OSA Original', lessonPractice:'Применить на практике', progressEyebrow:'ВАШ МАРШРУТ', progressTitle:'Продолжите с того места, где остановились', progressIntro:'Прогресс хранится в этом браузере. Можно вернуться к сцене или продолжить практический проект.', progressCourse:'OSA Original', progressScene:'Текущая сцена', progressChoices:'Ваши решения', progressComplete:'Курс завершён', progressNotStarted:'Вы ещё не начали курс', progressResume:'Продолжить обучение', progressStudio:'Продолжить проект', skillsEyebrow:'КАРТА НАВЫКОВ', skillsTitle:'От обучения к подтверждённой практике', skillsIntro:'Это не сертификат: карта показывает, какие практические результаты вы отметили на этом устройстве.', skillEvidence:'Проверка источников', skillPrivacy:'Защита данных', skillDecision:'Ответственные решения с ИИ', skillNotStarted:'Ещё не начато', skillInProgress:'Практика начата', skillComplete:'Чек-лист завершён', skillChecks:'результатов отмечено', skillSelfCheck:'Самопроверка курса', progressDrafts:'Черновики проектов', progressSelfCheck:'Самопроверка', lessonDetailCount:'Подробных уроков изучено', lessonDetailCatalog:'Открыть каталог уроков', actionStartTitle:'Начните с учебной истории', actionStartBody:'Пройдите первую сцену, чтобы познакомиться с принципами работы с ИИ и проверки ответов.', actionResumeTitle:'Продолжите курс', actionResumeBody:'Вернитесь к следующей сцене. После курса отметьте навыки в самопроверке.', actionChecksTitle:'Завершите самопроверку курса', actionChecksBody:'Курс пройден, но ещё не все три пункта самопроверки отмечены. Откройте итог курса и завершите чек-лист.', actionProjectTitle:'Перенесите знания в практику', actionProjectBody:'Самопроверка курса завершена. Следующий шаг — завершить чек-лист практического проекта.', actionStartLabel:'Начать курс', actionResumeLabel:'Продолжить сцену', actionChecksLabel:'Открыть итог курса', actionProjectLabel:'Продолжить проект', actionEyebrow:'СЛЕДУЮЩИЙ ШАГ', lessonAll:'Все темы', lessonAct1:'Акт I · Основы', lessonAct2:'Акт II · Знания', lessonAct3:'Акт III · Человек', lessonCount:'тем',
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
    labEyebrow:'МИНИ-ПРАКТИКУМ', labTitle:'Превратите задачу в проверяемый запрос', labIntro:'Опишите реальную задачу, выберите тип работы и отметьте критерии качества. Академия соберёт основу задания, которую можно скопировать в ваш ИИ-инструмент.', labResearch:'Исследование', labWriting:'Текст или материал', labPlanning:'План действий', labTaskLabel:'Какую задачу нужно решить?', labTaskPlaceholder:'Например: сравнить три варианта выхода продукта на рынок…', labCriteria:'Критерии качества', labEvidence:'Ключевые факты должны опираться на проверяемые источники.', labPrivacy:'Не использовать секреты и лишние персональные данные.', labLimits:'Явно указать допущения, ограничения и что нужно проверить человеку.', labOutputTitle:'Черновик задания', labOutputEmpty:'Введите задачу выше — здесь появится структурированный запрос.', labCopy:'Скопировать запрос', labCopied:'Скопировано', labCopyError:'Не удалось скопировать — выделите текст вручную.', labNeedTask:'Сначала опишите задачу.', labLevel:'Уровень сложности', levelBeginner:'Начальный', levelIntermediate:'Средний', levelAdvanced:'Продвинутый', labRubric:'Рубрика оценки', rubricAccuracy:'Точность и подтверждаемость · 40%', rubricUsefulness:'Практическая применимость · 30%', rubricClarity:'Ясность и структура · 20%', rubricSafety:'Ограничения и риски · 10%', labFeedback:'Попросите оценить результат по шкале 0–4 для каждого критерия, привести доказательства оценки и предложить конкретные улучшения.', footer:'Учитесь понимать. Проверяйте источники. Решайте осознанно.'
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
    scenes:'learning scenes', verification:'Source verification', continue:'Continue in OSA Original', lessonPractice:'Apply in a project', progressEyebrow:'YOUR LEARNING PATH', progressTitle:'Pick up where you left off', progressIntro:'Your progress stays in this browser. Return to a scene or continue a practical project.', progressCourse:'OSA Original', progressScene:'Current scene', progressChoices:'Your decisions', progressComplete:'Course completed', progressNotStarted:'You have not started the course yet', progressResume:'Resume learning', progressStudio:'Continue project', skillsEyebrow:'SKILL MAP', skillsTitle:'From learning to practical evidence', skillsIntro:'This is not a certification: the map shows which practical outcomes you have checked off on this device.', skillEvidence:'Source verification', skillPrivacy:'Data privacy', skillDecision:'Responsible AI-assisted decisions', skillNotStarted:'Not started yet', skillInProgress:'Practice started', skillComplete:'Checklist complete', skillChecks:'outcomes checked', skillSelfCheck:'Course self-check', progressDrafts:'Project drafts', progressSelfCheck:'Self-check', lessonDetailCount:'Detailed lessons completed', lessonDetailCatalog:'Open lesson catalogue', actionStartTitle:'Start with the learning story', actionStartBody:'Begin with the first scene to explore how AI works and why answers need verification.', actionResumeTitle:'Continue the course', actionResumeBody:'Return to the next scene. Complete the self-check after finishing the course.', actionChecksTitle:'Finish the course self-check', actionChecksBody:'You reached the end of the course, but fewer than three self-check items are marked. Reopen the course summary to finish.', actionProjectTitle:'Turn learning into practice', actionProjectBody:'Your course self-check is complete. Next, finish the checklist for a practical project.', actionStartLabel:'Start course', actionResumeLabel:'Resume scene', actionChecksLabel:'Open course summary', actionProjectLabel:'Continue project', actionEyebrow:'YOUR NEXT STEP', lessonAll:'All topics', lessonAct1:'Act I · Foundations', lessonAct2:'Act II · Knowledge', lessonAct3:'Act III · Humanity', lessonCount:'topics',
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
    labEyebrow:'PRACTICE LAB', labTitle:'Turn a task into a verifiable prompt', labIntro:'Describe a real task, choose a work mode, and select quality criteria. The Academy builds a task brief you can copy into your AI tool.', labResearch:'Research', labWriting:'Writing or content', labPlanning:'Action plan', labTaskLabel:'What task do you need to solve?', labTaskPlaceholder:'For example: compare three go-to-market options for a product…', labCriteria:'Quality criteria', labEvidence:'Key factual claims must rely on verifiable sources.', labPrivacy:'Do not include secrets or unnecessary personal data.', labLimits:'State assumptions, limitations, and what a human must verify.', labOutputTitle:'Task brief', labOutputEmpty:'Describe your task above to generate a structured prompt here.', labCopy:'Copy prompt', labCopied:'Copied', labCopyError:'Could not copy — select the text manually.', labNeedTask:'Describe the task first.', labLevel:'Difficulty level', levelBeginner:'Beginner', levelIntermediate:'Intermediate', levelAdvanced:'Advanced', labRubric:'Assessment rubric', rubricAccuracy:'Accuracy and verifiability · 40%', rubricUsefulness:'Practical usefulness · 30%', rubricClarity:'Clarity and structure · 20%', rubricSafety:'Limits and risks · 10%', labFeedback:'Score each criterion from 0–4, justify the score with evidence, and suggest concrete improvements.', footer:'Understand the system. Verify the sources. Decide with care.'
  }
} as const

export default function AcademyHome() {
  const [locale, setLocale] = useState<OSACinemaLocale>('ru')
  const [activeAct, setActiveAct] = useState<number | null>(null)
  const [taskType, setTaskType] = useState<'research'|'writing'|'planning'>('research')
  const [difficulty, setDifficulty] = useState<'beginner'|'intermediate'|'advanced'>('intermediate')
  const [task, setTask] = useState('')
  const [qualityChecks, setQualityChecks] = useState([true, true, true])
  const [copyStatus, setCopyStatus] = useState<'idle'|'copied'|'error'>('idle')
  const [learningProgress, setLearningProgress] = useState({ index:0, completed:false, answers:0, selfChecks:0, lessonCompletions:0, drafts:0, projectChecks:0, projectsCompleted:0, evidenceChecks:0, privacyChecks:0, decisionChecks:0, criteriaRated:0, reviewedProjects:0, nextProject:'evidence', started:false })
  useEffect(() => {
    const refreshProgress = () => {
      try {
        const learning = getOSALearningProgress()
        const course = learning.cinema
        const studio = (() => { try { return JSON.parse(localStorage.getItem('osgard-academy-studio-v1') || 'null') } catch { return null } })()
        const lessonCompletions = learning.lessonCompletions.length
        const projectIds = ['evidence','privacy','decision'] as const
        const validStudio = studio && typeof studio === 'object' && !Array.isArray(studio) ? studio : {}
        const projectState = projectIds.map(id => {
          const item = validStudio[id]
          const entries = item && Array.isArray(item.deliverables) ? item.deliverables : []
          const deliverables = [...new Set(entries.filter((entry:any) => typeof entry === 'string' && entry.trim().length > 0 && entry.length <= 300))]
          const scores = item && Array.isArray(item.scores) ? item.scores : []
          const criteriaRated = scores.slice(0,4).filter((score:any) => Number.isInteger(score) && score >= 1 && score <= 4).length
          return { id, deliverables:deliverables.slice(0,4), hasDraft:Boolean(item && typeof item.response === 'string' && item.response.trim()), criteriaRated, reviewed:criteriaRated===4 }
        })
        const drafts = projectState.filter(item => item.hasDraft).length
        const projectChecks = projectState.reduce((sum,item) => sum + item.deliverables.length, 0)
        const projectsCompleted = projectState.filter(item => item.deliverables.length === 4).length
        const nextProject = projectState.find(item => item.deliverables.length < 4)?.id || 'evidence'
        const index = course && Number.isInteger(course.index) && course.index >= 0 && course.index < lessons.length ? course.index : 0
        const validAnswers = course?.answers && typeof course.answers === 'object' && !Array.isArray(course.answers)
          ? Object.entries(course.answers).filter(([key,value]:[string,any]) => /^\d+$/.test(key) && Number(key) >= 0 && Number(key) < lessons.length && Number.isInteger(value) && value >= 0).length
          : 0
        const validSelfChecks = course?.selfChecks && typeof course.selfChecks === 'object' && !Array.isArray(course.selfChecks)
          ? Object.entries(course.selfChecks).filter(([key,value]:[string,any]) => /^[0-2]$/.test(key) && value === true).length
          : 0
        const completed = course?.completed === true
        setLearningProgress({
          index, completed, answers:validAnswers, selfChecks:Math.min(3,validSelfChecks), lessonCompletions, drafts, projectChecks, projectsCompleted,
          evidenceChecks:projectState[0].deliverables.length, privacyChecks:projectState[1].deliverables.length,
          decisionChecks:projectState[2].deliverables.length, nextProject,
          criteriaRated:projectState.reduce((sum,item)=>sum+item.criteriaRated,0),
          reviewedProjects:projectState.filter(item=>item.reviewed).length,
          started:Boolean(course && (index > 0 || validAnswers > 0 || validSelfChecks > 0 || completed))
        })
      } catch {
        setLearningProgress({ index:0, completed:false, answers:0, selfChecks:0, lessonCompletions:0, drafts:0, projectChecks:0, projectsCompleted:0, evidenceChecks:0, privacyChecks:0, decisionChecks:0, criteriaRated:0, reviewedProjects:0, nextProject:'evidence', started:false })
      }
    }
    refreshProgress()
    const unsubscribeOSAProgress = subscribeOSALearningProgress(refreshProgress)
    window.addEventListener('osgard-academy-progress', refreshProgress)
    return () => {
      window.removeEventListener('osgard-academy-progress', refreshProgress)
      unsubscribeOSAProgress()
    }
  }, [])
  const t = contentByLocale[locale]
  const nextLearningAction = !learningProgress.started && !learningProgress.completed
    ? { title:t.actionStartTitle, body:t.actionStartBody, label:t.actionStartLabel, href:'/osa-cinema' }
    : !learningProgress.completed
      ? { title:t.actionResumeTitle, body:t.actionResumeBody, label:t.actionResumeLabel, href:`/osa-cinema?scene=${learningProgress.index}` }
      : learningProgress.selfChecks < 3
        ? { title:t.actionChecksTitle, body:t.actionChecksBody, label:t.actionChecksLabel, href:'/osa-cinema' }
        : { title:t.actionProjectTitle, body:t.actionProjectBody, label:t.actionProjectLabel, href:`/?project=${learningProgress.nextProject}#project-studio` }
  const lessons = getOSACinemaLessons(locale)
  const visibleLessons = activeAct === null ? lessons : lessons.filter(lesson => lesson.act === activeAct)
  const lessonFilters = [{ value:null as number | null, label:t.lessonAll }, { value:1, label:t.lessonAct1 }, { value:2, label:t.lessonAct2 }, { value:3, label:t.lessonAct3 }]
  const pathways = [
    { number:'01', title:t.path1, body:t.path1Body, Icon:BrainCircuit },
    { number:'02', title:t.path2, body:t.path2Body, Icon:Compass },
    { number:'03', title:t.path3, body:t.path3Body, Icon:ShieldCheck }
  ]
  const taskModes = [{value:'research' as const,label:t.labResearch},{value:'writing' as const,label:t.labWriting},{value:'planning' as const,label:t.labPlanning}]
  const qualityLabels = [t.labEvidence,t.labPrivacy,t.labLimits]
  const difficultyLabels = {beginner:t.levelBeginner,intermediate:t.levelIntermediate,advanced:t.levelAdvanced}
  const rubricLabels = [t.rubricAccuracy,t.rubricUsefulness,t.rubricClarity,t.rubricSafety]
  const taskBrief = task.trim() ? `${taskModes.find(mode=>mode.value===taskType)?.label}\nDifficulty: ${difficultyLabels[difficulty]}\n\nTask: ${task.trim()}\n\nProduce a useful first draft appropriate to this difficulty; do not present unsupported claims as facts.\n${qualityChecks[0] ? `- Evidence: ${t.labEvidence}` : ''}\n${qualityChecks[1] ? `- Privacy: ${t.labPrivacy}` : ''}\n${qualityChecks[2] ? `- Review: ${t.labLimits}` : ''}\n\nAssessment rubric (weights total 100%):\n- ${t.rubricAccuracy}\n- ${t.rubricUsefulness}\n- ${t.rubricClarity}\n- ${t.rubricSafety}\n${t.labFeedback}\n\nSeparate facts from assumptions. Mark unknowns explicitly. End with a short checklist of what the human should verify before using the result.` : ''
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
        <a href="#paths">{t.paths}</a><a href="/lectures">{locale === 'ru' ? 'Лекции' : 'Lectures'}</a><a href="/catalog">{t.products}</a><a href="/games/">{t.games}</a><a href="/portal">{t.portal}</a>
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
          <a className="academy-button academy-button-secondary" href="/lectures"><BookOpen size={16} aria-hidden="true" />{locale === 'ru' ? 'Курсы и лекции' : 'Courses & lectures'}<ArrowRight size={16} aria-hidden="true" /></a>
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

    <section className="academy-section academy-progress" aria-labelledby="academy-progress-title">
      <div className="academy-progress-heading"><div><p className="academy-eyebrow">{t.progressEyebrow}</p><h2 id="academy-progress-title">{t.progressTitle}</h2><p>{t.progressIntro}</p></div><a className="academy-button academy-button-secondary" href={learningProgress.started ? `/osa-cinema?scene=${learningProgress.index}` : '/osa-cinema'}>{t.progressResume}<ArrowUpRight size={15} aria-hidden="true" /></a></div>
      <article className="academy-next-action" aria-labelledby="academy-next-action-title"><div><p className="academy-eyebrow">{t.actionEyebrow}</p><h3 id="academy-next-action-title">{nextLearningAction.title}</h3><p>{nextLearningAction.body}</p></div><a className="academy-button academy-button-primary" href={nextLearningAction.href}>{nextLearningAction.label}<ArrowRight size={15} aria-hidden="true" /></a></article>
      <div className="academy-progress-grid">
        <article className="academy-progress-card"><div className="academy-progress-card-top"><BookOpen size={18} aria-hidden="true" /><span>{t.progressCourse}</span></div><strong>{learningProgress.completed ? t.progressComplete : learningProgress.started ? `${learningProgress.index + 1} / ${lessons.length}` : t.progressNotStarted}</strong><div className="academy-progress-track" aria-label={`${Math.round((learningProgress.completed ? lessons.length : learningProgress.index) / Math.max(1, lessons.length) * 100)}%`}><span style={{width:`${learningProgress.completed ? 100 : Math.round(learningProgress.index / Math.max(1, lessons.length) * 100)}%`}} /></div><p>{learningProgress.answers} · {t.progressChoices} · {learningProgress.selfChecks}/3 {t.progressSelfCheck}</p><p>{learningProgress.lessonCompletions}/{OSA_LESSON_SLUGS.length} {t.lessonDetailCount}</p><a href="/lectures">{t.lessonDetailCatalog}<ArrowRight size={14} aria-hidden="true" /></a></article>
        <article className="academy-progress-card"><div className="academy-progress-card-top"><Sparkles size={18} aria-hidden="true" /><span>{t.progressDrafts}</span></div><strong>{learningProgress.drafts} / 3</strong><p>{locale === 'ru' ? 'Проектов с черновиками на этом устройстве' : 'Projects with drafts on this device'}</p><p className="academy-progress-project-detail">{learningProgress.projectChecks} {locale === 'ru' ? 'пунктов чек-листа выполнено' : 'checklist items completed'} · {learningProgress.projectsCompleted}/3 {locale === 'ru' ? 'проектов с полным чек-листом' : 'projects with complete checklists'}</p><a href={`/?project=${learningProgress.nextProject}#project-studio`}>{locale === 'ru' ? `Продолжить: ${learningProgress.nextProject === 'evidence' ? 'проверка источников' : learningProgress.nextProject === 'privacy' ? 'защита данных' : 'решение с ИИ'}` : `Continue: ${learningProgress.nextProject === 'evidence' ? 'source verification' : learningProgress.nextProject === 'privacy' ? 'data privacy' : 'AI-assisted decision'}`}<ArrowRight size={14} aria-hidden="true" /></a></article>
      </div>
    </section>

    <section className="academy-section academy-journey" aria-labelledby="academy-journey-title">
      <div className="academy-section-heading"><div><p className="academy-eyebrow">{locale==='ru'?'ОТ ТЕОРИИ К ПРИМЕНЕНИЮ':'FROM THEORY TO PRACTICE'}</p><h2 id="academy-journey-title">{locale==='ru'?'Ваш путь обучения':'Your learning pathway'}</h2></div><p>{locale==='ru'?'Четыре этапа объединяют курс, самопроверку и практические проекты. Отметки обновляются по мере работы.':'Four stages connect the course, self-check and practical projects. Progress updates as you work.'}</p></div>
      <ol className="academy-journey-steps">
        {([
          {title:locale==='ru'?'Изучить основы':'Learn the foundations',body:locale==='ru'?'Пройдите интерактивный курс OSA Original.':'Complete the OSA Original interactive course.',done:learningProgress.completed,href:'/osa-cinema',status:learningProgress.completed?(locale==='ru'?'Курс завершён':'Course complete'):(learningProgress.started?(locale==='ru'?'В процессе':'In progress'):(locale==='ru'?'Не начато':'Not started'))},
          {title:locale==='ru'?'Проверить понимание':'Check your understanding',body:locale==='ru'?'Отметьте три пункта самопроверки после курса.':'Complete the three post-course self-checks.',done:learningProgress.selfChecks===3,href:'/osa-cinema',status:`${learningProgress.selfChecks}/3 ${locale==='ru'?'отмечено':'completed'}`},
          {title:locale==='ru'?'Создать практический результат':'Create a practical deliverable',body:locale==='ru'?'Заполните проект и отметьте необходимые результаты.':'Write a project draft and check off the required deliverables.',done:learningProgress.projectsCompleted>0,href:`/?project=${learningProgress.nextProject}#project-studio`,status:`${learningProgress.projectChecks}/12 ${locale==='ru'?'пунктов':'items'}`},
          {title:locale==='ru'?'Оценить качество':'Assess the quality',body:locale==='ru'?'Оцените точность, пользу, ясность и риски по рубрике.':'Rate accuracy, usefulness, clarity and risks with the rubric.',done:learningProgress.reviewedProjects>0,href:`/?project=${learningProgress.nextProject}#project-studio`,status:`${learningProgress.criteriaRated}/12 ${locale==='ru'?'критериев':'criteria'}`}
        ]).map((step,index)=><li className={step.done?'is-complete':''} key={step.title}><span className="academy-journey-number" aria-hidden="true">{step.done?'✓':String(index+1).padStart(2,'0')}</span><div className="academy-journey-copy"><h3>{step.title}</h3><p>{step.body}</p><span>{step.status}</span></div><a href={step.href} aria-label={`${locale==='ru'?'Перейти к этапу':'Go to step'}: ${step.title}`}>{step.done?(locale==='ru'?'Повторить':'Review'):(locale==='ru'?'Продолжить':'Continue')}<ArrowRight size={14} aria-hidden="true" /></a></li>)}
      </ol>
    </section>

    <section className="academy-section academy-skills" aria-labelledby="academy-skills-title">
      <div className="academy-section-heading"><div><p className="academy-eyebrow">{t.skillsEyebrow}</p><h2 id="academy-skills-title">{t.skillsTitle}</h2></div><p>{t.skillsIntro}</p></div>
      <div className="academy-skills-grid">
        {([
          {id:'evidence',title:t.skillEvidence,count:learningProgress.evidenceChecks,href:'/?project=evidence#project-studio',icon:'01'},
          {id:'privacy',title:t.skillPrivacy,count:learningProgress.privacyChecks,href:'/?project=privacy#project-studio',icon:'02'},
          {id:'decision',title:t.skillDecision,count:learningProgress.decisionChecks,href:'/?project=decision#project-studio',icon:'03'}
        ]).map(skill=><article className="academy-skill-card" key={skill.id}>
          <div className="academy-skill-card-top"><span>{skill.icon}</span><span>{skill.count>=4?t.skillComplete:skill.count>0?t.skillInProgress:t.skillNotStarted}</span></div>
          <h3>{skill.title}</h3>
          <div className="academy-progress-track" role="progressbar" aria-label={skill.title} aria-valuemin={0} aria-valuemax={4} aria-valuenow={Math.min(4,skill.count)}><span style={{width:`${Math.min(100,skill.count/4*100)}%`}} /></div>
          <p>{skill.count}/4 {t.skillChecks}</p>
          <a href={skill.href}>{t.progressStudio}<ArrowRight size={14} aria-hidden="true" /></a>
        </article>)}
      </div>
      <p className="academy-skills-footnote">{t.skillSelfCheck}: {learningProgress.selfChecks}/3</p>
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
        {visibleLessons.map(lesson => {
          const sceneIndex = Number(lesson.id.split('-').pop())
          const project = sceneIndex === 5 ? 'privacy' : sceneIndex === 3 || sceneIndex === 4 ? 'evidence' : 'decision'
          return <article className="academy-lesson-card" key={lesson.id}>
            <span>{lesson.tag}</span><h3>{lesson.title}</h3><p>{lesson.body}</p>
            <a className="academy-lesson-link" href={`/osa-cinema?scene=${sceneIndex}`}>{t.lessonAction}<ArrowUpRight size={15} aria-hidden="true" /></a>
            <a className="academy-lesson-practice" href={`/?project=${project}#project-studio`}>{t.lessonPractice}<ArrowUpRight size={15} aria-hidden="true" /></a>
          </article>
        })}
      </div>
    </section>

    <AcademyStudio locale={locale} />

    <section className="academy-section academy-practice">
      <div className="academy-section-heading"><div><p className="academy-eyebrow">{t.practicalEyebrow}</p><h2>{t.practicalTitle}</h2></div><p>{t.practicalIntro}</p></div>
      <div className="academy-practice-grid">
        {habits.map(item => <article className="academy-practice-card" key={item.number}><span>{item.number}</span><h3>{item.title}</h3><p>{item.body}</p></article>)}
      </div>
    </section>

    <section className="academy-section academy-lab" id="practice-lab">
      <div className="academy-section-heading"><div><p className="academy-eyebrow">{t.labEyebrow}</p><h2>{t.labTitle}</h2></div><p>{t.labIntro}</p></div>
      <div className="academy-lab-panel">
        <div className="academy-lab-inputs">
          <div className="academy-lab-modes" role="group" aria-label={t.labTitle}>{taskModes.map(mode=><button key={mode.value} type="button" className={taskType===mode.value?'active':''} aria-pressed={taskType===mode.value} onClick={()=>setTaskType(mode.value)}>{mode.label}</button>)}</div>
          <label className="academy-lab-task-label" htmlFor="academy-task">{t.labTaskLabel}</label>
          <textarea id="academy-task" value={task} onChange={event=>{setTask(event.target.value);setCopyStatus('idle')}} placeholder={t.labTaskPlaceholder} rows={4} maxLength={1000} />
          <div className="academy-lab-counter">{task.length} / 1000</div>
          <fieldset className="academy-lab-difficulty"><legend>{t.labLevel}</legend><div role="group" aria-label={t.labLevel}>{(Object.keys(difficultyLabels) as Array<keyof typeof difficultyLabels>).map(level=><button key={level} type="button" className={difficulty===level?'active':''} aria-pressed={difficulty===level} onClick={()=>setDifficulty(level)}>{difficultyLabels[level]}</button>)}</div></fieldset>
          <fieldset className="academy-lab-checks"><legend>{t.labCriteria}</legend>{qualityLabels.map((label,i)=><label key={label}><input type="checkbox" checked={qualityChecks[i]} onChange={event=>setQualityChecks(previous=>previous.map((checked,index)=>index===i?event.target.checked:checked))}/><span>{label}</span></label>)}</fieldset>
          <fieldset className="academy-lab-rubric"><legend>{t.labRubric}</legend>{rubricLabels.map(label=><div key={label}>{label}</div>)}<p>{t.labFeedback}</p></fieldset>
        </div>
        <div className="academy-lab-output"><p className="academy-eyebrow">{t.labOutputTitle}</p><textarea aria-label={t.labOutputTitle} value={taskBrief || t.labOutputEmpty} readOnly rows={10} onFocus={event=>event.currentTarget.select()} /><button type="button" className="academy-button academy-button-primary" disabled={!task.trim()} onClick={async()=>{try{await navigator.clipboard.writeText(taskBrief);setCopyStatus('copied')}catch{setCopyStatus('error')}}}>{copyStatus==='copied'?t.labCopied:t.labCopy}<ArrowUpRight size={15} aria-hidden="true"/></button>{copyStatus==='error'&&<p role="status" className="academy-lab-status">{t.labCopyError}</p>}</div>
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
