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
const RemixLegacyRedirect = React.lazy(() => import('./LegacyCreatorPrototypes').then(async m => { await import('./legacyStyles'); return { default: m.RemixLegacyRedirect } }))
const OnlineGamePrototype = React.lazy(() => import('./OnlineGamePrototype').then(async m => { await import('./legacyStyles'); return { default: m.OnlineGamePrototype } }))
const CoreEvents = React.lazy(() => import('./CoreEvents').then(async m => { await import('./legacyStyles'); return { default: m.CoreEvents } }))
const EcosystemSurface = React.lazy(() => import('./EcosystemSurfaces').then(async m => { await import('./legacyStyles'); return { default: m.EcosystemSurface } }))
const CommunitySurface = React.lazy(() => import('./CommunitySurface').then(async m => { await import('./legacyStyles'); return { default: m.CommunitySurface } }))
const StreamSurface = React.lazy(() => import('./StreamSurface').then(async m => { await import('./legacyStyles'); return { default: m.StreamSurface } }))

import { recordBrandEvent } from './brandTelemetry'
import { BrandShell } from './BrandShell'
import { completeBrowserNavigation, getBrowserSnapshot, getServerSnapshot, subscribeBrowserNavigation } from './browserNavigation'
import { normalizeReactPath } from './osgardRouting'
import OsgardTransitionProvider from './OsgardTransitionProvider'
import OsgardRouteSkeleton from './OsgardRouteSkeleton'
const WorldHome = React.lazy(() => import('./WorldHome'))
const IntelligenceHome = React.lazy(() => import('./IntelligenceHome'))
const PlayHome = React.lazy(() => import('./PlayHome'))
const PlayGameRoute = React.lazy(() => import('./PlayGameRoute'))
const TeamsPage = React.lazy(() => import('./TeamsPage'))
const ClientPortal = React.lazy(() => import('./ClientPortal'))
const PurchasesPage = React.lazy(() => import('./PurchasesPage'))
const ProgramEnrollmentPage = React.lazy(() => import('./ProgramEnrollmentPage'))
const OperationsPage = React.lazy(() => import('./OperationsPage'))
const AccountPage = React.lazy(() => import('./AccountPage'))
const PilotOrganizer = React.lazy(() => import('./PilotOrganizer'))
const LearningCampus = React.lazy(() => import('./LearningCampus'))
const CoreWorkspace = React.lazy(() => import('./CoreWorkspace'))
const DataCenter = React.lazy(() => import('./DataCenter'))
const BrandPages = React.lazy(() => import('./BrandPages'))

/** Initial pages already carry route metadata in their generated HTML shell.
 * The complete metadata registry is fetched only when a SPA destination needs it. */
function Seo({ path }: { path: string }) {
  React.useEffect(() => {
    const canonicalPath = path === '/entertainment' || path === '/games' ? '/play' : path
    const canonical = 'https://osgard.world' + canonicalPath
    if (document.head.querySelector<HTMLLinkElement>('link[rel="canonical"]')?.href === canonical) return
    let cancelled = false
    import('./routeSeo').then(module => { if (!cancelled) module.updateRouteSeo(path) }).catch(() => {
      // Metadata failure must never prevent the actual route from opening.
      if (!cancelled) document.title = 'OSGARD — ' + (path === '/' ? 'Цифровая вселенная' : path.split('/').filter(Boolean).join(' / '))
    })
    return () => { cancelled = true }
  }, [path])
  return null
}

function RoutedContent({ path, href }: { path: string; href: string }) {
  const [locale, setLocale] = React.useState<'ru' | 'en'>('ru')
  const url = new URL(href, 'https://osgard.world')
  if (path === '/' && (url.searchParams.has('project') || url.hash === '#project-studio')) return <><Seo path="/academy" /><AcademyHome /></>
  if (path === '/') return <><Seo path="/" /><WorldHome /></>
  if (path === '/intelligence') return <><Seo path={path} /><IntelligenceHome /></>
  if (path === '/teams') return <><Seo path={path} /><TeamsPage /></>
  if (path === '/deliveries') return <><Seo path={path} /><ClientPortal /></>
  if (path === '/purchases') return <><Seo path={path} /><PurchasesPage /></>
  if (path === '/learning/enrollment') return <><Seo path={path} /><ProgramEnrollmentPage /></>
  if (path === '/workspace/overview') return <><Seo path={path} /><OperationsPage /></>
  if (path === '/account') return <><Seo path={path} /><AccountPage /></>
  if (path === '/workspace') return <><Seo path={path} /><CoreWorkspace /></>
  if (path === '/data') return <><Seo path={path} /><DataCenter /></>
  if (path === '/brand' || path === '/quality') return <><Seo path={path} /><BrandPages quality={path==='/quality'} /></>
  if (path === '/play/partners') return <><Seo path={path} /><PlayHome partners /></>
  if (path.startsWith('/play/world/')) return <><Seo path={path} /><PlayGameRoute gameId={path.slice('/play/world/'.length)} /></>
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
  if (path === '/play/remix') return <RemixLegacyRedirect />
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
function MeasuredRoute({ path, href, revision }: { path: string; href: string; revision: number }){
  React.useEffect(()=>{
    completeBrowserNavigation(revision)
    if(path.startsWith('/lectures/'))recordBrandEvent('lecture_opened',path.slice('/lectures/'.length))
    if(path==='/osa-cinema'||path==='/learning/program')recordBrandEvent('course_started',path)
  },[path, revision])
  return <RoutedContent path={path} href={href} />
}
function RoutedRoot(){
  const { href, revision } = React.useSyncExternalStore(subscribeBrowserNavigation, getBrowserSnapshot, getServerSnapshot)
  const url = new URL(href, 'https://osgard.world')
  const path = normalizeReactPath(url.pathname)
  const theme = path==='/'&&(url.searchParams.has('project')||url.hash==='#project-studio')?'intelligence':path==='/play/partners'?'world':path==='/play'||path.startsWith('/play/')||path==='/games'||path==='/entertainment'||path.startsWith('/games/')?'play':path==='/intelligence'||path.startsWith('/learning')||path==='/academy'||path.startsWith('/lectures')||path==='/osa-cinema'?'intelligence':'world'
  return <OsgardTransitionProvider><BrandShell theme={theme}><RouteBoundary key={revision}><Suspense fallback={<OsgardRouteSkeleton theme={theme} path={path} />}><MeasuredRoute path={path} href={href} revision={revision} /></Suspense></RouteBoundary></BrandShell></OsgardTransitionProvider>
}
createRoot(document.getElementById('root')!).render(<StrictMode><RoutedRoot /></StrictMode>)
