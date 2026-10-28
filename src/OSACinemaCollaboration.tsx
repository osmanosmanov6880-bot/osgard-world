import { useEffect,useMemo,useRef,useState,type FormEvent } from 'react'
import { ArrowLeft,ArrowRight,Check,Clapperboard,Download,FileClock,Globe2,LockKeyhole,Plus,RefreshCw,ShieldAlert,ShieldCheck,Trash2,Users,VideoOff } from 'lucide-react'
import { coreRequest,CoreError,downloadCore,type CoreUser } from './coreClient'
import type { StudioLocale } from './osaCinemaStudioRegistry'
import { PRODUCTION_CATEGORIES,PRODUCTION_STATES,PRODUCTION_SCENE_IDS,type ProductionCategory,type ProductionState } from './osaCinemaProductionPlan'
import './osaCinemaStudio.css'
import './osaCinemaCollaboration.css'

type FilmId='zero-window'|'threshold'
type CinemaRole='owner'|'editor'|'viewer'
type Space={id:string;filmId:FilmId;title:string;version:number;role:CinemaRole;updatedAt:string;publicFilmReleaseAuthorized:false;publicVideoUrl:null}
type Task={id:string;sceneId:string;category:ProductionCategory;title:string;status:ProductionState;owner:string;dueDate:string;notes:string;createdAt:string;updatedAt:string}
type Person={id:string;username:string;role:CinemaRole}
type EventLog={id:number;kind:string;detail:Record<string,string|boolean>;actor:string;at:string}
type Detail={space:Space;members:Person[];tasks:Task[];audit:EventLog[];limits:{maxTasks:number;maxTeamMembers:number;noFilmPremiere:true;noPublicVideo:true;serverScope:string}}
type ListResponse={spaces:Space[];truncated:boolean;releaseAuthorized:false}
type WriteResult={workspaceId:string;version:number;releaseAuthorized:false;publicVideoUrl?:null;detail?:{taskId?:string};replayed?:boolean}
type Tab='tasks'|'people'|'audit'
const departments:Record<ProductionCategory,[string,string]>={
 script:['Сценарий','Script'],casting:['Кастинг','Casting'],location:['Локации','Locations'],camera:['Камера','Camera'],
 sound:['Звук','Sound'],rights:['Права','Rights'],safety:['Безопасность','Safety'],post:['Постпродакшн','Postproduction']
}
const states:Record<ProductionState,[string,string]>={
 planned:['Запланировано','Planned'],in_progress:['В работе','In progress'],blocked:['Заблокировано','Blocked'],
 ready_for_review:['На проверке','Ready for review']
}
const films:Record<FilmId,[string,string]>={
 'zero-window':['НУЛЕВОЕ ОКНО','ZERO WINDOW'],threshold:['ПОРОГ РЕШЕНИЯ','THRESHOLD']
}
type TaskDraft={title:string;sceneId:string;category:ProductionCategory;owner:string;dueDate:string;notes:string}
const emptyTask:TaskDraft={title:'',sceneId:'S01',category:'script',owner:'',dueDate:'',notes:''}
const validFilm=(value:string):value is FilmId=>value==='zero-window'||value==='threshold'

export default function OSACinemaCollaboration(){
 const [locale,setLocale]=useState<StudioLocale>(()=>new URLSearchParams(window.location.search).get('lang')==='en'?'en':'ru')
 const ru=locale==='ru'
 const tr=(a:string,b:string)=>ru?a:b
 const [phase,setPhase]=useState<'loading'|'auth'|'offline'|'ready'>('loading')
 const [user,setUser]=useState<CoreUser|null>(null)
 const [spaces,setSpaces]=useState<Space[]>([])
 const [spaceId,setSpaceId]=useState('')
 const [detail,setDetail]=useState<Detail|null>(null)
 const [filmToCreate,setFilmToCreate]=useState<FilmId>('zero-window')
 const [nameToCreate,setNameToCreate]=useState('OSA Production Workspace')
 const [task,setTask]=useState<TaskDraft>(emptyTask)
 const [sceneFilter,setSceneFilter]=useState('all')
 const [statusFilter,setStatusFilter]=useState('all')
 const [memberUsername,setMemberUsername]=useState('')
 const [memberRole,setMemberRole]=useState<'editor'|'viewer'>('editor')
 const [selectedTab,setSelectedTab]=useState<Tab>('tasks')
 const [deleting,setDeleting]=useState('')
 const [removeUsername,setRemoveUsername]=useState('')
 const [error,setError]=useState('')
 const [notice,setNotice]=useState('')
 const [busy,setBusy]=useState(false)
 const [lastUpdated,setLastUpdated]=useState('')
 const pending=useRef<{signature:string;key:string}|null>(null)
 const editable=detail?.space.role==='owner'||detail?.space.role==='editor'
 const owner=detail?.space.role==='owner'
 const filtered=useMemo(()=>detail?.tasks.filter(t=>(sceneFilter==='all'||t.sceneId===sceneFilter)&&
    (statusFilter==='all'||t.status===statusFilter))??[],[detail,sceneFilter,statusFilter])
 const projectScenes=detail?.space.filmId==='threshold'?['PREVIZ']:PRODUCTION_SCENE_IDS
 const switchLocale=()=>{
  const next=ru?'en':'ru',url=new URL(window.location.href)
  url.searchParams.set('lang',next)
  window.history.replaceState(window.history.state,'',url.pathname+url.search+url.hash);setLocale(next)
 }
 function interpret(e:unknown){
  const err=e instanceof CoreError?e:new CoreError('unknown',tr('Неожиданная ошибка.','Unexpected error.'))
  if(err.status===401){setPhase('auth');setUser(null);setSpaces([]);setDetail(null)}
  if(err.code==='server_offline'||err.code==='connection'){setPhase('offline');setDetail(null)}
  return err.code==='version_conflict'
    ?tr('Данные изменены в другом сеансе. Обновите страницу проекта перед повтором.','Another session changed this workspace. Refresh before trying again.')
    :err.message
 }
 async function refresh(preferred=''){
  try{
   const [who,list]=await Promise.all([coreRequest<{user:CoreUser}>('auth/me'),coreRequest<ListResponse>('cinema/spaces')])
   const next=preferred||spaceId||list.spaces[0]?.id||''
   const chosen=list.spaces.some(s=>s.id===next)?next:list.spaces[0]?.id||''
   const fresh=chosen?await coreRequest<Detail>('cinema/spaces/'+chosen):null
   setUser(who.user);setSpaces(list.spaces);setSpaceId(chosen);setDetail(fresh)
   setLastUpdated(new Date().toLocaleTimeString(locale==='ru'?'ru-RU':'en-GB'))
   setPhase('ready')
  }catch(e){setError(interpret(e))}
 }
 useEffect(()=>{void refresh()},[]) // Initial real auth, no demo task injection.
 async function mutate(route:string,payload:Record<string,unknown>,preferred=spaceId){
  const signature=JSON.stringify([route,payload])
  const key=pending.current?.signature===signature?pending.current.key:crypto.randomUUID().replaceAll('-','')
  pending.current={signature,key};setBusy(true);setError('');setNotice('')
  try{
   const result=await coreRequest<WriteResult>(route,payload,key)
   pending.current=null
   await refresh(preferred||result.workspaceId)
   setNotice(result.replayed?tr('Подтверждён ранее сохранённый запрос.','Previously saved request confirmed.'):tr('Сохранено на сервере Core. Это не разрешение на премьеру.','Saved on Core. This does not authorize a film premiere.'))
   return true
  }catch(e){
   if(e instanceof CoreError&&e.code==='version_conflict'){pending.current=null;await refresh(preferred)}
   setError(interpret(e));return false
  }finally{setBusy(false)}
 }
 const create=async(e:FormEvent)=>{
  e.preventDefault()
  await mutate('cinema/spaces',{filmId:filmToCreate,title:nameToCreate},'')
 }
 const write=async(kind:string,extra:Record<string,unknown>={})=>{
  if(!detail)return false
  return mutate('cinema/spaces/'+detail.space.id,{expectedVersion:detail.space.version,kind,...extra},detail.space.id)
 }
 const addTask=async(e:FormEvent)=>{
  e.preventDefault()
  const ok=await write('task.create',task)
  if(ok)setTask({...emptyTask,sceneId:detail?.space.filmId==='threshold'?'PREVIZ':'S01'})
 }
 const updateTask=async(t:Task,status:ProductionState)=>write('task.update',{taskId:t.id,status})
 const removeTask=async(t:Task)=>{
  if(deleting!==t.id){setDeleting(t.id);return}
  if(await write('task.delete',{taskId:t.id}))setDeleting('')
 }
 const invite=async(e:FormEvent)=>{
  e.preventDefault()
  if(await write('member.set',{username:memberUsername,role:memberRole})){setMemberUsername('');setRemoveUsername('')}
 }
 const removeMember=async(username:string)=>{
  if(removeUsername!==username){setRemoveUsername(username);return}
  if(await write('member.remove',{username}))setRemoveUsername('')
 }
 const goSpace=async(id:string)=>{
  setSpaceId(id);setSceneFilter('all');setStatusFilter('all');setSelectedTab('tasks');setDeleting('');setError('');setNotice('')
  setDetail(null)
  try{setDetail(await coreRequest<Detail>('cinema/spaces/'+id))}
  catch(e){setError(interpret(e))}
 }
 const exportSnapshot=()=>{
  if(!detail)return
  downloadCore({format:'OSA_CINEMA_CORE_COLLAB_EXPORT_V1',exportedAt:new Date().toISOString(),
    ownerAccessibleSnapshot:true,doesNotAuthorizeRelease:true,workspace:detail.space,members:detail.members,tasks:detail.tasks,audit:detail.audit},
    'OSA_CINEMA_'+detail.space.filmId+'_server_workspace.json')
  setNotice(tr('Экспортирован снимок доступных данных. Для восстановления на сервере импорт не предусмотрен.','Downloaded an accessible snapshot. Server import is not supported.'))
 }
 return <main className="osa-studio osa-collab-page" lang={locale} data-release-state="no-go">
  <a className="osa-studio-skip" href="#osa-collab-body">{tr('К рабочему центру','Skip to collaboration workspace')}</a>
  <header className="osa-studio-header">
   <a className="osa-studio-brand" href={'/osa-cinema/studio?lang='+locale}><span className="osa-studio-symbol" aria-hidden="true">◈</span><span>OSA <b>CINEMA</b><small>COLLABORATION CORE / PILOT</small></span></a>
   <nav aria-label={tr('Навигация','Navigation')}><a href={'/osa-cinema/studio?lang='+locale}><ArrowLeft size={16}/>{tr('Студия','Studio')}</a><a href={'/osa-cinema/studio/production?lang='+locale}>{tr('Локальный план','Local draft')}</a><a href={'/osa-cinema/studio/distribution?lang='+locale}>{tr('Проверка релиза','Release review')}</a></nav>
   <button className="osa-studio-language" type="button" onClick={switchLocale} aria-label={tr('Switch to English','Переключить на русский')}><Globe2 size={15}/>{locale.toUpperCase()}</button>
  </header>
  <section className="osa-collab-hero">
    <div><p className="osa-studio-eyebrow">OSA CINEMA / V61 / PRODUCTION COORDINATION</p><h1>{tr('РАБОТАЕТ','WORKING')}<br/><em>{tr('КОМАНДА.','TOGETHER.')}</em></h1>
    <p className="osa-collab-lead">{tr('Реальные серверные кинопространства. Разграничение ролей, задачи по сценам, версии изменений и журнал действий. Ни один статус здесь не подтверждает снятый фильм.','Authenticated film workspaces with roles, scene-level tasks, revision controls and an action log. No planning status constitutes proof of filming.')}</p>
    <span className="osa-collab-server-mark"><LockKeyhole size={16}/>{tr('Требуется действующий сервер OSGARD Core и аккаунт','Requires a running self-hosted OSGARD Core server and account')}</span></div>
    <span className="osa-collab-hero-glyph" aria-hidden="true">C / 61</span>
  </section>
  <section className="osa-collab-truth"><ShieldAlert size={23}/><div><strong>{tr('Планирование ≠ выпуск фильма','Planning ≠ public film release')}</strong><p>{tr('ZERO WINDOW: снято 0 из 13 актёрских сцен. Права и реальное воспроизведение не подтверждены. Публикация остаётся закрытой независимо от ролей, отметок и задач.','ZERO WINDOW: 0 of 13 live-action scenes filmed. Rights and actual public playback remain unverified. Film release stays blocked regardless of roles, notes or task states.')}</p></div><span>STRICT NO-GO</span></section>
  <div className="osa-collab-body" id="osa-collab-body">
   {phase==='loading'&&<section className="osa-collab-state" role="status"><RefreshCw size={30}/><h2>{tr('Проверяем серверный доступ…','Checking server access…')}</h2></section>}
   {(phase==='auth'||phase==='offline')&&<section className="osa-collab-state" aria-labelledby="osa-collab-state-title">
    <div className="osa-collab-state-icon">{phase==='auth'?<LockKeyhole size={32}/>:<ShieldAlert size={32}/>}</div>
    <p className="osa-studio-eyebrow">CONNECTED CORE / NOT MOCK DATA</p>
    <h2 id="osa-collab-state-title">{phase==='auth'?tr('Войдите в Core.','Sign in to Core.'):tr('Сервер недоступен.','Core is offline.')}</h2>
    <p>{phase==='auth'?tr('Кинопроекты изолированы по аккаунтам. Используйте существующий вход OSGARD Core, затем вернитесь сюда.','Film workspaces require an authenticated account. Use the existing OSGARD Core account page and return here.'):tr('Это серверный продукт, а не демонстрационная копия. На обычной статической сборке управление командами недоступно. Запустите Core с SQLite через HTTPS reverse proxy.','This is a server product, not a simulated dashboard. Static-only hosting cannot store team data. Run Core with SQLite behind a real HTTPS reverse proxy.')}</p>
    <div className="osa-collab-state-actions"><a className="osa-studio-button" href="/account">{tr('Аккаунт OSGARD','OSGARD account')}<ArrowRight size={17}/></a><button type="button" onClick={()=>{setPhase('loading');void refresh()}}><RefreshCw size={16}/>{tr('Повторить','Retry')}</button></div>
    <a href={'/osa-cinema/studio/production?lang='+locale}>{tr('Продолжить в локальном планировщике','Open the separate local production planner')}</a>
   </section>}
   {phase==='ready'&&<>
    <div className="osa-collab-subhead"><div><p className="osa-studio-eyebrow">01 / AUTHENTICATED ACCOUNT</p><h2>{tr('Координация производства.','Production coordination.')}</h2><p>{tr('Аккаунт: ','Account: ')}<strong>{user?.username??'—'}</strong>. {tr('Последняя загрузка: ','Last loaded: ')}{lastUpdated}</p></div><button type="button" onClick={()=>void refresh(spaceId)} disabled={busy}><RefreshCw size={16}/>{tr('Обновить с сервера','Reload from server')}</button></div>
    <section className="osa-collab-selector" aria-label={tr('Доступные кинопространства','Accessible film workspaces')}>
     {spaces.length===0?<div className="osa-collab-empty"><Clapperboard size={27}/><strong>{tr('Пока нет серверных кинопространств.','No server film workspaces yet.')}</strong><p>{tr('Создайте первое ниже. Никакие задачи не будут выдуманы автоматически.','Create one below. No tasks or fictional team activity will be generated.')}</p></div>:
     spaces.map(space=><button className={space.id===spaceId?'selected':''} aria-pressed={space.id===spaceId} type="button" key={space.id} onClick={()=>void goSpace(space.id)}><span>{space.filmId.toUpperCase()} / {space.role.toUpperCase()}</span><strong>{space.title}</strong><small>VERSION {space.version} · {ru?films[space.filmId][0]:films[space.filmId][1]}</small></button>)}
    </section>
    <div className="osa-collab-columns">
     <section className="osa-collab-new" aria-labelledby="osa-collab-new-title">
      <p className="osa-studio-eyebrow">02 / CREATE WORKSPACE</p><h3 id="osa-collab-new-title">{tr('Новый кинопроект','New workspace')}</h3><p>{tr('Создаётся на настоящем сервере. Один проект каждого фильма на владельца.','Created on the actual server. One space per film per owner.')}</p>
      <form onSubmit={e=>{void create(e)}}>
       <label>{tr('Фильм','Film')}<select value={filmToCreate} onChange={e=>setFilmToCreate(e.target.value as FilmId)}><option value="zero-window">ZERO WINDOW</option><option value="threshold">THRESHOLD</option></select></label>
       <label>{tr('Название пространства','Workspace title')}<input minLength={3} maxLength={120} required value={nameToCreate} onChange={e=>setNameToCreate(e.target.value)}/></label>
       <button type="submit" disabled={busy||spaces.some(s=>s.role==='owner'&&s.filmId===filmToCreate)}><Plus size={17}/>{tr('Создать серверное пространство','Create server workspace')}</button>
      </form>
      <p className="osa-collab-muted">{tr('Для текущего релиза нет внешних приглашений по email, SSO или автоматической синхронизации с локальными черновиками.','No email invitations, SSO or automatic migration of local drafts in this pilot.')}</p>
     </section>
     <section className="osa-collab-workspace" aria-labelledby="osa-collab-workspace-title">
      {!detail?<div className="osa-collab-empty"><RefreshCw size={26}/><h3>{tr('Выберите пространство','Choose a workspace')}</h3></div>:<>
       <div className="osa-collab-workspace-head"><div><p className="osa-studio-eyebrow">03 / REAL SQLITE WORKSPACE</p><h3 id="osa-collab-workspace-title">{detail.space.title}</h3><p>{ru?films[detail.space.filmId][0]:films[detail.space.filmId][1]} · {detail.space.role.toUpperCase()} · v{detail.space.version}</p></div><button type="button" onClick={exportSnapshot} title={tr('Скачать только доступные вам данные','Export only data you can access')}><Download size={16}/>{tr('Экспорт снимка','Export snapshot')}</button></div>
       <div className="osa-collab-kpis"><div><strong>{detail.tasks.length}</strong><span>{tr('Задач в базе','Tasks in database')}</span></div><div><strong>{detail.members.length}</strong><span>{tr('Участников','Participants')}</span></div><div><strong>{detail.audit.length}</strong><span>{tr('Последние события','Recent events')}</span></div><div><strong>NO-GO</strong><span>{tr('Кинопремьера','Film premiere')}</span></div></div>
       <div className="osa-collab-tabs" role="tablist" aria-label={tr('Разделы','Workspace sections')}>{(['tasks','people','audit'] as const).map(t=><button key={t} type="button" role="tab" aria-selected={selectedTab===t} onClick={()=>setSelectedTab(t)}>{t==='tasks'?tr('Задачи','Tasks'):t==='people'?tr('Команда','Team'):tr('Журнал','Audit log')}</button>)}</div>
       {selectedTab==='tasks'&&<div className="osa-collab-tabpanel">
        <div className="osa-collab-filter"><label>{tr('Сцена','Scene')}<select value={sceneFilter} onChange={e=>setSceneFilter(e.target.value)}><option value="all">{tr('Все сцены','All scenes')}</option>{projectScenes.map(s=><option key={s} value={s}>{s}</option>)}</select></label><label>{tr('Статус','Status')}<select value={statusFilter} onChange={e=>setStatusFilter(e.target.value)}><option value="all">{tr('Все статусы','All statuses')}</option>{PRODUCTION_STATES.map(s=><option value={s} key={s}>{ru?states[s][0]:states[s][1]}</option>)}</select></label></div>
        <div className="osa-collab-tasks">{filtered.length===0?<p className="osa-collab-muted">{tr('Задач нет. Записи появятся только после сохранения на сервере.','No tasks. Records appear only after a successful server write.')}</p>:filtered.map(t=><article className="osa-collab-task" key={t.id}>
         <div><small>{t.sceneId} / {ru?departments[t.category][0]:departments[t.category][1]}</small><h4>{t.title}</h4><p>{t.notes}</p><span>{t.owner||tr('Не назначено','Unassigned')}{t.dueDate?' · '+t.dueDate:''}</span></div>
         <div className="osa-collab-task-actions">{editable?<label>{tr('Плановый статус','Planning status')}<select disabled={busy} value={t.status} onChange={e=>void updateTask(t,e.target.value as ProductionState)}>{PRODUCTION_STATES.map(st=><option key={st} value={st}>{ru?states[st][0]:states[st][1]}</option>)}</select></label>:<span>{ru?states[t.status][0]:states[t.status][1]}</span>}{editable&&<button type="button" className="osa-collab-delete" disabled={busy} onClick={()=>void removeTask(t)}><Trash2 size={14}/>{deleting===t.id?tr('Подтвердить удаление','Confirm deletion'):tr('Удалить','Delete')}</button>}</div>
        </article>)}</div>
        {editable&&<form className="osa-collab-task-form" onSubmit={e=>{void addTask(e)}}><p className="osa-studio-eyebrow">NEW TASK / SERVER SAVE</p><h4>{tr('Добавить производственную задачу','Add a production task')}</h4>
         <label>{tr('Название','Title')}<input required minLength={2} maxLength={120} value={task.title} onChange={e=>setTask({...task,title:e.target.value})}/></label>
         <div className="osa-collab-form-grid"><label>{tr('Сцена','Scene')}<select value={projectScenes.includes(task.sceneId)?task.sceneId:projectScenes[0]} onChange={e=>setTask({...task,sceneId:e.target.value})}>{projectScenes.map(s=><option key={s}>{s}</option>)}</select></label><label>{tr('Направление','Department')}<select value={task.category} onChange={e=>setTask({...task,category:e.target.value as ProductionCategory})}>{PRODUCTION_CATEGORIES.map(c=><option key={c} value={c}>{ru?departments[c][0]:departments[c][1]}</option>)}</select></label></div>
         <div className="osa-collab-form-grid"><label>{tr('Ответственный','Owner label')}<input maxLength={80} value={task.owner} onChange={e=>setTask({...task,owner:e.target.value})} placeholder={tr('Роль или инициалы','Role or initials')}/></label><label>{tr('Срок','Due date')}<input type="date" value={task.dueDate} onChange={e=>setTask({...task,dueDate:e.target.value})}/></label></div>
         <label>{tr('План, не сведения о съёмке','Planning notes, not filming evidence')}<textarea maxLength={600} rows={3} value={task.notes} onChange={e=>setTask({...task,notes:e.target.value})}/></label>
         <button type="submit" disabled={busy||detail.tasks.length>=100}><Plus size={16}/>{tr('Записать задачу в SQLite','Save task to SQLite')}</button>
        </form>}
       </div>}
       {selectedTab==='people'&&<section className="osa-collab-tabpanel"><div className="osa-collab-people">{detail.members.map(person=><div key={person.id}><span><Users size={16}/><strong>{person.username}</strong><small>{person.role.toUpperCase()}</small></span>{owner&&person.role!=='owner'&&<button disabled={busy} type="button" onClick={()=>void removeMember(person.username)}>{removeUsername===person.username?tr('Подтвердить исключение','Confirm removal'):tr('Исключить','Remove')}</button>}</div>)}</div>
       {owner&&<form className="osa-collab-task-form" onSubmit={e=>{void invite(e)}}><p className="osa-studio-eyebrow">OWNER ONLY / EXISTING CORE ACCOUNTS</p><h4>{tr('Предоставить доступ','Grant team access')}</h4><p>{tr('Добавить можно только существующего пользователя Core. Внешние письма не отправляются.','Only existing Core usernames may be added. No external invitation email is sent.')}</p><label>{tr('Логин аккаунта','Existing account username')}<input required minLength={3} maxLength={64} pattern="[A-Za-z0-9_.-]{3,64}" value={memberUsername} onChange={e=>setMemberUsername(e.target.value)}/></label><label>{tr('Роль','Role')}<select value={memberRole} onChange={e=>setMemberRole(e.target.value as 'editor'|'viewer')}><option value="editor">{tr('Редактор','Editor')}</option><option value="viewer">{tr('Наблюдатель','Viewer')}</option></select></label><button disabled={busy} type="submit"><Users size={16}/>{tr('Назначить роль на сервере','Save server-side role')}</button></form>}
       </section>}
       {selectedTab==='audit'&&<section className="osa-collab-tabpanel"><div className="osa-collab-audit">{detail.audit.map(evt=><div key={evt.id}><FileClock size={16}/><span><strong>{evt.kind}</strong><small>{evt.actor} · {evt.at}</small></span><code>#{evt.id}</code></div>)}</div><p className="osa-collab-muted">{tr('Показываются последние 100 событий. Это внутренний журнал пилота, не сертифицированное юридическое доказательство.','Shows the latest 100 entries. This is a pilot activity log, not independently certified legal evidence.')}</p></section>}
      </>}
     </section>
    </div>
   </>}
   <div className="osa-collab-feedback" aria-live="polite">{error&&<p role="alert"><ShieldAlert size={17}/>{error}</p>}{notice&&<p role="status"><Check size={17}/>{notice}</p>}</div>
   <div className="osa-collab-legal"><VideoOff size={22}/><p>{tr('Самостоятельно размещённый серверный пилот: не облачный SLA и не защищённое хранилище юридических оригиналов. Не загружайте здесь личные документы или закрытые видеомастера. Права, съёмки и публичные видеорелизы требуют отдельной независимой проверки.','This is a self-hosted server pilot, not a managed cloud SLA or legal evidence vault. Do not upload sensitive documents or private video masters. Filming, rights and public film release still require separate independent verification.')}</p></div>
  </div>
  <footer className="osa-studio-footer"><div><span className="osa-studio-symbol" aria-hidden="true">◈</span><strong>OSA CINEMA</strong><p>{tr('Совместная работа с проверяемыми ограничениями.','Collaboration with verifiable limits.')}</p></div><div className="osa-studio-footer-links"><a href={'/osa-cinema/studio?lang='+locale}><ArrowLeft size={16}/>{tr('В студию','Back to studio')}</a><a href="/account"><ShieldCheck size={16}/>{tr('Настройки аккаунта','Account')}</a></div><span>© 2026 OSA ORIGINAL STUDIOS</span></footer>
 </main>
}
