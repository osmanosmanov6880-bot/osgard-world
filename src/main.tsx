import React, { StrictMode, Suspense } from 'react'
import { createRoot } from 'react-dom/client'
const AcademyHome = React.lazy(() => import('./AcademyHome'))
const OSACinema = React.lazy(() => import('./OSACinema'))
const LectureLibrary = React.lazy(() => import('./LectureLibrary'))
const OSAExperimentPage = React.lazy(() => import('./OSAExperimentPage'))
const OSAProgramPage = React.lazy(() => import('./OSAProgramPage'))
const OSAWorkspacePage = React.lazy(() => import('./OSAWorkspacePage'))
const OSAProjectPage = React.lazy(() => import('./OSAProjectPage'))
const OSALearningDashboard = React.lazy(() => import('./OSALearningDashboard'))
const OSAAssessmentPage = React.lazy(() => import('./OSAAssessmentPage'))
const OSAMonetizationPage = React.lazy(() => import('./OSAMonetizationPage'))
const OSALessonPage = React.lazy(() => import('./OSALessonPage'))
const MiniApp = React.lazy(() => import('./MiniApp').then(async m => { await import('./legacyStyles'); return m }))
const AurumPage = React.lazy(() => import('./Sections').then(async m => { await import('./legacyStyles'); return { default: m.AurumPage } }))
const CatalogPage = React.lazy(() => import('./Sections').then(async m => { await import('./legacyStyles'); return { default: m.CatalogPage } }))
const ChroniclePage = React.lazy(() => import('./Sections').then(async m => { await import('./legacyStyles'); return { default: m.ChroniclePage } }))
const ClubPage = React.lazy(() => import('./Sections').then(async m => { await import('./legacyStyles'); return { default: m.ClubPage } }))
const DevelopmentPage = React.lazy(() => import('./Sections').then(async m => { await import('./legacyStyles'); return { default: m.DevelopmentPage } }))
const MastersPage = React.lazy(() => import('./Sections').then(async m => { await import('./legacyStyles'); return { default: m.MastersPage } }))
const TimeCoinPage = React.lazy(() => import('./Sections').then(async m => { await import('./legacyStyles'); return { default: m.TimeCoinPage } }))
const WorldsPage = React.lazy(() => import('./Sections').then(async m => { await import('./legacyStyles'); return { default: m.WorldsPage } }))
const EntertainmentCatalog = React.lazy(() => import('./EntertainmentCatalog').then(async m => { await import('./legacyStyles'); return { default: m.EntertainmentCatalog } }))
const ResultPage = React.lazy(() => import('./ResultPage').then(async m => { await import('./legacyStyles'); return { default: m.ResultPage } }))
const BusinessDiagnostic = React.lazy(() => import('./BusinessDiagnostic').then(async m => { await import('./legacyStyles'); return { default: m.BusinessDiagnostic } }))
const CreatePrototype = React.lazy(() => import('./CreatePrototype').then(async m => { await import('./legacyStyles'); return { default: m.CreatePrototype } }))
const MobilityPrototype = React.lazy(() => import('./MobilityPrototype').then(async m => { await import('./legacyStyles'); return { default: m.MobilityPrototype } }))
const TimePrototype = React.lazy(() => import('./TimePrototype').then(async m => { await import('./legacyStyles'); return { default: m.TimePrototype } }))
const WeekSurface = React.lazy(() => import('./WeekSurface').then(async m => { await import('./legacyStyles'); return { default: m.WeekSurface } }))
const Recommendations = React.lazy(() => import('./Recommendations').then(async m => { await import('./legacyStyles'); return { default: m.Recommendations } }))
const ArchiveSurface = React.lazy(() => import('./ArchiveSurface').then(async m => { await import('./legacyStyles'); return { default: m.ArchiveSurface } }))
const ProfileSurface = React.lazy(() => import('./ProfileSurface').then(async m => { await import('./legacyStyles'); return { default: m.ProfileSurface } }))
const InheritPrototype = React.lazy(() => import('./LegacyCreatorPrototypes').then(async m => { await import('./legacyStyles'); return { default: m.InheritPrototype } }))
const RemixPrototype = React.lazy(() => import('./LegacyCreatorPrototypes').then(async m => { await import('./legacyStyles'); return { default: m.RemixPrototype } }))
const OnlineGamePrototype = React.lazy(() => import('./OnlineGamePrototype').then(async m => { await import('./legacyStyles'); return { default: m.OnlineGamePrototype } }))
const CoreEvents = React.lazy(() => import('./CoreEvents').then(async m => { await import('./legacyStyles'); return { default: m.CoreEvents } }))
const EcosystemSurface = React.lazy(() => import('./EcosystemSurfaces').then(async m => { await import('./legacyStyles'); return { default: m.EcosystemSurface } }))
const CommunitySurface = React.lazy(() => import('./CommunitySurface').then(async m => { await import('./legacyStyles'); return { default: m.CommunitySurface } }))
const StreamSurface = React.lazy(() => import('./StreamSurface').then(async m => { await import('./legacyStyles'); return { default: m.StreamSurface } }))

import { recordBrandEvent } from './brandTelemetry'
import { BrandShell } from './BrandShell'
const WorldHome = React.lazy(() => import('./WorldHome'))
const IntelligenceHome = React.lazy(() => import('./IntelligenceHome'))
const PlayHome = React.lazy(() => import('./PlayHome'))
const TeamsPage = React.lazy(() => import('./TeamsPage'))
const ClientPortal = React.lazy(() => import('./ClientPortal'))
const OperationsPage = React.lazy(() => import('./OperationsPage'))
const AccountPage = React.lazy(() => import('./AccountPage'))
const PilotOrganizer = React.lazy(() => import('./PilotOrganizer'))
const LearningCampus = React.lazy(() => import('./LearningCampus'))
const CoreWorkspace = React.lazy(() => import('./CoreWorkspace'))
const DataCenter = React.lazy(() => import('./DataCenter'))
const BrandPages = React.lazy(() => import('./BrandPages'))

const seo: Record<string, { title: string; description: string }> = {
  '/': { title: 'OSGARD WORLD � �������� ����������', description: 'OSGARD WORLD ���������� �������� ��� ������, �����������, �������, ������� � �������� �������� �������.' },
  '/worlds': { title: '���� OSGARD � ���� ��������� ����� ����������', description: '���� ������� ����� OSGARD: ������, �����������, ������, ���� ��� � ������ ����� ���������.' },
  '/catalog': { title: '������� OSGARD � ����������� � ���������', description: '������� �������� ������������ � ���������� OSGARD � ��������� ���������� � �������.' },
  '/chronicle': { title: '������� OSGARD � ������� ����������', description: '������� �������, ��������� � ������ �������� ���������� OSGARD.' },
  '/masters': { title: '���������� OSGARD � ����, ��������� ������', description: '���������� OSGARD � �� ������� � ������, ���������, �������� � ��������.' },
  '/club': { title: '���� OSGARD � �������� ������ �������', description: '�������� ���� OSGARD ��� ������� �������, ������ ����������� � ������� ������� � ��������.' },
  '/aurum': { title: 'AURUM � ����������� ���������� OSGARD', description: 'AURUM ��������� �������� OSGARD � ������ ������� � �������� ������� ��������� ���.' },
  '/timecoin': { title: 'TimeCoin OSGARD � ������ � �������', description: 'TimeCoin � ���������� ������� ����������, ������� � ����������� ������� OSGARD.' },
  '/development': { title: 'OSGARD Development � ���������� �������� ���������', description: '���������� ������, �������� � �������� ��������� OSGARD: �� ������ �� �������.' },
  '/entertainment': { title: 'OSGARD Entertainment � ������������� ����', description: '������������� ������� ��� OSGARD. �������� ���� � ��������� � ��� ��������� ���.' },
}

const cleanSeo: Record<string, { title: string; description: string }> = {
  '/osa-cinema': { title: 'OSA Original — интерактивный фильм об ИИ и власти знаний', description: 'Три акта об искусственном интеллекте, власти информации и будущем человека. Интерактивные решения, источники и прогресс на устройстве.' },
  '/': { title: 'OSA Intelligence — понимать, проверять, решать', description: 'Интерактивная среда OSA: изучайте возможности ИИ, проверяйте доказательства и принимайте ответственные решения.' },
  '/academy': { title: 'OSGARD AI Academy — понимать, проверять, применять ИИ', description: 'Учебные маршруты, интерактивный курс и практическая студия по применению искусственного интеллекта.' },
  '/learning/assessment': { title: 'OSA Learning — проверка знаний', description: 'Восемь проверочных вопросов по интерактивным урокам OSA.' },
  '/learning/program': { title: 'OSA — Практическая программа | OSGARD', description: 'Восемь уроков, практический проект и рубрика проверки.' },
  '/learning/workspace': { title: 'OSA — Мастерская проектов | OSGARD', description: 'Коллекция практических проектов и история версий.' },
  '/learning/portfolio': { title: 'OSA — Локальное портфолио | OSGARD', description: 'Практические работы ученика на этом устройстве.' },
  '/learning/experiments': { title: 'OSA — журнал экспериментов | OSGARD', description: 'Сравнение времени и качества работы с ИИ и без него.' },
  '/learning/project': { title: 'OSA — учебный проект | OSGARD', description: 'Цель, план, практическая работа и самооценка учебного проекта OSA.' },
  '/learning/pricing': { title: 'OSA Learning — программы и доступ', description: 'Практические программы OSA по ИИ и технологиям: самостоятельное обучение, сопровождение и командные пилоты.' },
  '/learning': { title: 'OSA Learning — карта знаний | OSGARD', description: 'Учебные маршруты, результаты и следующий урок OSA Learning.' },
  '/lectures': { title: 'OSA Original — курсы и интерактивные лекции | OSGARD', description: 'Упорядоченная программа OSA Original: три акта и все существующие интерактивные лекции об ИИ, власти знаний и человеческом выборе. Видеозаписи отмечены отдельно от доступных интерактивных сцен.' },
  '/portal': { title: 'OSGARD World — портал экосистемы', description: 'Продукты, игры, проекты и направления цифровой экосистемы OSGARD.' },
  '/worlds': { title: 'Миры OSGARD — семь самостоятельных продуктов', description: 'Выберите мир OSGARD: защита, мобильность, бизнес, время и создание цифровых продуктов.' },
  '/catalog': { title: 'Каталог OSGARD — продукты и решения', description: 'Каталог самостоятельных продуктов OSGARD с понятными условиями и маршрутами.' },
  '/chronicle': { title: 'Хроника OSGARD — история экосистемы', description: 'События, продукты и ключевые этапы развития OSGARD.' },
  '/masters': { title: 'Мастера OSGARD — люди и команды', description: 'Команды OSGARD и их работа над продуктами, играми и цифровыми решениями.' },
  '/club': { title: 'Клуб OSGARD — закрытое пространство', description: 'Клуб OSGARD для раннего доступа, общения и совместного развития продуктов.' },
  '/aurum': { title: 'AURUM — координационный интеллект OSGARD', description: 'AURUM связывает продукты OSGARD в единую картину и помогает выбрать следующий шаг.' },
  '/timecoin': { title: 'TimeCoin OSGARD — правила и условия', description: 'Правила внутренней бонусной единицы OSGARD для доступа, статуса и специальных условий.' },
  '/development': { title: 'OSGARD Development — создание цифровых продуктов', description: 'Разработка сайтов, приложений и MVP-платформ от идеи до запуска.' },
  '/entertainment': { title: 'OSGARD Entertainment — интерактивные игры', description: 'Игры OSGARD: выбирайте мир, запускайте сессию и сохраняйте результат.' },
  '/skillcred': { title: 'SkillCred — навыки, которые остаются с вами | OSGARD', description: 'Переносимые цифровые подтверждения навыков. Проверка Ed25519 в браузере.' },
  '/games/time': { title: 'Империя времени — стратегия живого города | OSGARD PLAY', description: 'Управляйте казной, энергией, районами и политическими фракциями. Каждое решение меняет летопись города.' },
}

Object.assign(cleanSeo, {
 '/':{title:'OSGARD WORLD — цифровые продукты, построенные как системы',description:'Стратегия, структура, дизайн и разработка цифровых продуктов. OSA Intelligence, Development и OSGARD PLAY.'},
 '/intelligence':{title:'OSA Intelligence — понимать ИИ, проверять, решать',description:'Интеллектуальная среда OSA: метод проверки, интерактивный пример, восемь уроков и практические проекты.'},
 '/play':{title:'OSGARD PLAY — каталог игровых миров',description:'Стратегии, платформеры и кооперативные эксперименты. Фильтры, управление и честные статусы сохранения и онлайна.'},
 '/games':{title:'OSGARD PLAY — каталог игровых миров',description:'Каталог игр OSGARD: платформы, управление и статусы доступности.'},
 '/entertainment':{title:'OSGARD PLAY — игровые миры',description:'Каталог игр OSGARD с платформами, управлением и статусами доступности.'},
 '/development':{title:'OSGARD Development — цифровые продукты и кейсы',description:'PHANTOM, TEDES, MERAKKI и ESSENTIA. Концепты, демо и прототипы с обозначенными стадиями.'},
 '/play/partners':{title:'OSGARD PLAY — партнёрам',description:'Обсуждение игровых интеграций, брендированных миров и испытаний. Условия и техническая проверка до запуска.'},
 '/brand':{title:'OSGARD — фирменная система открытого портала',description:'Мастер-знак, версии для OSA и PLAY, монохромные варианты, favicon и правила движения.'},
 '/learning/organizer':{title:'OSA — организация пилота и очередь разборов',description:'Доступные учебные проекты, назначения проверяющих, сроки и отчёты по сохранённым данным.'},
 '/learning/campus':{title:'OSA Learning — практика, итоговый проект и расписание',description:'Серверные учебные записи, снимки итоговой работы, разбор по рубрике и расписание пилота.'},
 '/teams':{title:'OSGARD Core — команды',description:'Командные пространства, роли и явное подключение проектов.'},
 '/deliveries':{title:'OSGARD — полученные материалы',description:'Изолированная передача выпуска и обсуждение без доступа к внутреннему проекту.'},
 '/workspace/overview':{title:'OSGARD Core — рабочий центр',description:'Состояние доступных проектов, очередь проверок, расходы и следующий шаг.'},
 '/account':{title:'OSGARD Core — аккаунт и доступ',description:'Сессии, смена пароля и резервные коды для восстановления доступа к серверному аккаунту.'},
 '/workspace':{title:'OSGARD Core — от цели к результату',description:'Контракт, серверные проекты, Learning, Studio и Business. Версии, разрешения и контроль бюджета.'},
 '/data':{title:'OSGARD — резервные копии ваших данных',description:'Экспорт и восстановление локального прогресса, проектов и коллекции PLAY.'},
 '/quality':{title:'OSGARD — состояние локальной сборки',description:'Фактические возможности, ограничения, локальные события и критерии качества OSGARD.'},
})

function Seo({ path }: { path: string }) {
  React.useEffect(() => {
    const game = path.startsWith('/play/world/') ? path.slice('/play/world/'.length) : null
    const lessonTitles: Record<string,string> = {'intelligence-and-imitation':'Интеллект и имитация','how-language-models-work':'Как работают языковые модели','power-of-knowledge':'Власть знаний','signal-and-noise':'Сигнал и шум','verify-an-ai-answer':'Проверьте ответ ИИ','privacy-before-prompting':'Приватность до запроса','human-in-the-loop':'Человек в контуре','investigate-the-future':'Исследуйте будущее'}
    const lessonTitle = path.startsWith('/lectures/') ? lessonTitles[path.slice('/lectures/'.length)] : null
    const data = lessonTitle ? {title:'OSA — '+lessonTitle,description:'Урок OSA: '+lessonTitle+'. Цели, материал, практика, самопроверка и источники.'} : (game ? { title: 'OSGARD PLAY — '+game.toUpperCase(), description: 'Инструкция, платформа, управление и статусы игрового мира '+game+'.' } : cleanSeo[path]) ?? (path.startsWith('/lectures/') ? { title: 'OSA Original — подробная лекция | OSGARD', description: 'Учебные цели, материал, словарь, самопроверка, практика и проверяемые источники OSA Original.' } : cleanSeo['/'])
    const canonicalPath = path==='/entertainment'||path==='/games'?'/play':path
    const canonical = `https://osgard.world${canonicalPath === '/' ? '/' : canonicalPath}`
    document.title = data.title
    const setMeta = (selector: string, attribute: string, value: string) => {
      let element = document.head.querySelector<HTMLMetaElement>(selector)
      if (!element) { element = document.createElement('meta'); document.head.appendChild(element) }
      element.setAttribute(attribute, value)
    }
    setMeta('meta[name="description"]', 'content', data.description)
    setMeta('meta[property="og:title"]', 'content', data.title)
    setMeta('meta[property="og:description"]', 'content', data.description)
    setMeta('meta[property="og:url"]', 'content', canonical)
    const theme = path==='/'&&(new URLSearchParams(location.search).has('project')||location.hash==='#project-studio')?'intelligence':path==='/play/partners'?'world':path==='/play'||path.startsWith('/play/')||path==='/games'||path==='/entertainment'?'play':path==='/intelligence'||path.startsWith('/learning')||path.startsWith('/lectures')||path==='/academy'||path==='/osa-cinema'?'intelligence':'world'
    const preview = `https://osgard.world/brand/preview-${theme}.png`
    setMeta('meta[property="og:image"]', 'content', preview)
    setMeta('meta[property="og:image:alt"]', 'content', data.title)
    setMeta('meta[name="twitter:title"]', 'content', data.title)
    setMeta('meta[name="twitter:description"]', 'content', data.description)
    setMeta('meta[name="twitter:image"]', 'content', preview)
    setMeta('meta[name="theme-color"]', 'content', theme==='world'?'#F3F4F1':theme==='intelligence'?'#101A27':'#080B12')
    let link = document.head.querySelector<HTMLLinkElement>('link[rel="canonical"]')
    if (!link) { link = document.createElement('link'); link.rel = 'canonical'; document.head.appendChild(link) }
    link.href = canonical
    const jsonLd = { '@context': 'https://schema.org', '@type': 'WebPage', name: data.title, description: data.description, url: canonical, isPartOf: { '@type': 'WebSite', name: 'OSGARD WORLD', url: 'https://osgard.world/' } }
    let script = document.head.querySelector<HTMLScriptElement>('script[data-route-seo]')
    if (!script) { script = document.createElement('script'); script.type = 'application/ld+json'; script.dataset.routeSeo = 'true'; document.head.appendChild(script) }
    script.textContent = JSON.stringify(jsonLd)
  }, [path])
  return null
}

const path = location.pathname.replace(/\/+$/, '') || '/'
function RoutedContent() {
  const [locale, setLocale] = React.useState<'ru' | 'en'>('ru')
  if (path === '/' && (new URLSearchParams(location.search).has('project') || location.hash === '#project-studio')) return <><Seo path="/academy" /><AcademyHome /></>
  if (path === '/') return <><Seo path="/" /><WorldHome /></>
  if (path === '/intelligence') return <><Seo path={path} /><IntelligenceHome /></>
  if (path === '/teams') return <><Seo path={path} /><TeamsPage /></>
  if (path === '/deliveries') return <><Seo path={path} /><ClientPortal /></>
  if (path === '/workspace/overview') return <><Seo path={path} /><OperationsPage /></>
  if (path === '/account') return <><Seo path={path} /><AccountPage /></>
  if (path === '/workspace') return <><Seo path={path} /><CoreWorkspace /></>
  if (path === '/data') return <><Seo path={path} /><DataCenter /></>
  if (path === '/brand' || path === '/quality') return <><Seo path={path} /><BrandPages quality={path==='/quality'} /></>
  if (path === '/play/partners') return <><Seo path={path} /><PlayHome partners /></>
  if (path.startsWith('/play/world/')) return <><Seo path={path} /><PlayHome gameId={path.slice('/play/world/'.length)} /></>
  if (path === '/play' || path === '/games' || path === '/entertainment') return <><Seo path={path} /><PlayHome /></>
  if (path === '/development') return <><Seo path={path} /><WorldHome development /></>
  if (path === '/academy') return <><Seo path="/academy" /><AcademyHome /></>
  if (path === '/learning/organizer') return <><Seo path={path} /><PilotOrganizer /></>
  if (path === '/learning/campus') return <><Seo path={path} /><LearningCampus /></>
  if (path === '/learning/experiments') return <><Seo path={path} /><OSAExperimentPage /></>
  if (path === '/learning/program') return <><Seo path={path} /><OSAProgramPage /></>
  if (path === '/learning/workspace') return <><Seo path={path} /><OSAWorkspacePage /></>
  if (path === '/learning/portfolio') return <><Seo path={path} /><OSAWorkspacePage portfolio /></>
  if (path === '/learning/project') return <><Seo path={path} /><OSAProjectPage /></>
  if (path === '/learning/assessment') return <><Seo path="/learning/assessment" /><OSAAssessmentPage /></>
  if (path === '/learning/pricing') return <><Seo path="/learning/pricing" /><OSAMonetizationPage /></>
  if (path === '/learning') return <><Seo path="/learning" /><OSALearningDashboard /></>
  if (path === '/lectures') return <><Seo path="/lectures" /><LectureLibrary /></>
  if (path.startsWith('/lectures/')) return <><Seo path={path} /><OSALessonPage slug={path.slice('/lectures/'.length)} /></>
  if (path === '/portal') return <><Seo path="/" /><WorldHome /></>
  if (path === '/osa-cinema') return <><Seo path={path} /><OSACinema /></>
  if (path === '/miniapp') return <MiniApp />
  if (path === '/games/time' || path === '/games/time-empire') return <><Seo path="/games/time" /><TimePrototype /></>
  if (path === '/play/swarm') return <OnlineGamePrototype game="swarm" />
  if (path === '/play/null-shift') return <OnlineGamePrototype game="null" />
  if (path === '/play/inherit') return <InheritPrototype />
  if (path === '/play/remix') return <RemixPrototype />
  if (path === '/week') return <WeekSurface />
  if (path === '/next') return <Recommendations />
  if (path === '/archive') return <ArchiveSurface />
  if (path === '/profile') return <ProfileSurface />
  if (path === '/community') return <CommunitySurface />
  if (path === '/stream') return <StreamSurface />
  if (path === '/archive') return <ArchiveSurface />
  const page = path === '/marcosa' ? <EcosystemSurface kind="marcosa" /> : path === '/media' ? <EcosystemSurface kind="media" /> : path === '/core-events' ? <CoreEvents /> : path === '/mobility' ? <MobilityPrototype /> : path === '/create' ? <CreatePrototype /> : path === '/business' ? <BusinessDiagnostic /> : path.startsWith('/r/') ? <ResultPage id={path.split('/')[2] || '1842'} /> : path === '/worlds' ? <WorldsPage locale={locale} setLocale={setLocale} /> : path === '/aurum' ? <AurumPage locale={locale} setLocale={setLocale} /> : path === '/timecoin' ? <TimeCoinPage locale={locale} setLocale={setLocale} /> : path === '/development' ? <DevelopmentPage locale={locale} setLocale={setLocale} /> : path === '/catalog' ? <CatalogPage locale={locale} setLocale={setLocale} /> : path === '/chronicle' ? <EcosystemSurface kind="chronicle" /> : path === '/masters' ? <MastersPage locale={locale} setLocale={setLocale} /> : path === '/club' ? <ClubPage locale={locale} setLocale={setLocale} /> : path === '/entertainment' ? <EntertainmentCatalog locale={locale} setLocale={setLocale} /> : <NotFound />
  return <><Seo path={path} />{page}</>
}
function NotFound(){return <main className="brand-container brand-not-found"><p className="brand-eyebrow">OSGARD / 404</p><h1>Этот маршрут не найден.</h1><p>Проверьте адрес или выберите один из продуктов.</p><div className="brand-actions"><a className="brand-button primary" href="/">OSGARD WORLD →</a><a className="brand-button" href="/intelligence">OSA Intelligence</a><a className="brand-button" href="/play">OSGARD PLAY</a></div></main>}
class RouteBoundary extends React.Component<{children:React.ReactNode},{failed:boolean}> {
  state={failed:false}
  static getDerivedStateFromError(){return {failed:true}}
  render(){return this.state.failed?<main className="route-loading" role="alert"><h1>Страница не загрузилась.</h1><p>Проверьте соединение и повторите попытку.</p><button className="brand-button" onClick={()=>location.reload()}>Повторить</button><a href="/">Вернуться в OSGARD</a></main>:this.props.children}
}
function MeasuredRoute(){
  React.useEffect(()=>{
    if(path.startsWith('/lectures/'))recordBrandEvent('lecture_opened',path.slice('/lectures/'.length))
    if(path==='/osa-cinema'||path==='/learning/program')recordBrandEvent('course_started',path)
  },[])
  return <RoutedContent />
}
function RoutedRoot(){
  const theme = path==='/'&&(new URLSearchParams(location.search).has('project')||location.hash==='#project-studio')?'intelligence':path==='/play/partners'?'world':path==='/play'||path.startsWith('/play/')||path==='/games'||path==='/entertainment'||path.startsWith('/games/')?'play':path==='/intelligence'||path.startsWith('/learning')||path==='/academy'||path.startsWith('/lectures')||path==='/osa-cinema'?'intelligence':'world'
  return <BrandShell theme={theme}><RouteBoundary><Suspense fallback={<main className="route-loading" role="status"><p>Загружаем {theme==='world'?'OSGARD':theme==='intelligence'?'OSA Intelligence':'OSGARD PLAY'}…</p><a href="/">На главную</a></main>}><MeasuredRoute /></Suspense></RouteBoundary></BrandShell>
}
createRoot(document.getElementById('root')!).render(<StrictMode><RoutedRoot /></StrictMode>)
