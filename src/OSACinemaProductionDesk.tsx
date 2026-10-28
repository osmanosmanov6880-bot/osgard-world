import { useEffect, useMemo, useState, type ChangeEvent, type FormEvent } from 'react'
import { ArrowLeft, ArrowRight, CalendarDays, Check, ClipboardList, Download, Film, Globe2, LockKeyhole, Plus, Search, ShieldAlert, ShieldCheck, Trash2, Upload } from 'lucide-react'
import { getStudioWork, type StudioLocale } from './osaCinemaStudioRegistry'
import {
  PRODUCTION_SCENE_IDS, PRODUCTION_CATEGORIES, PRODUCTION_STATES,
  PROPOSED_SHOTS, PLANNED_SCENES, VERIFIED_ACTOR_SCENES_FILMED, TARGET_FILM_SECONDS,
  MAX_PRODUCTION_IMPORT_BYTES,
  createProductionTask, exportProductionBackup, exportProductionCsv, parseProductionBackup,
  productionStatistics, readProductionPlan, saveProductionPlan, subscribeProductionPlan,
  updateProductionTask, type ProductionCategory, type ProductionState, type ProductionTask
} from './osaCinemaProductionPlan'
import './osaCinemaStudio.css'
import './osaCinemaProductionDesk.css'

const departmentNames:Record<ProductionCategory,{ru:string,en:string}>={
 script:{ru:'Сценарий',en:'Script'},
 casting:{ru:'Кастинг',en:'Casting'},
 location:{ru:'Локация',en:'Location'},
 camera:{ru:'Камера',en:'Camera'},
 sound:{ru:'Звук',en:'Sound'},
 rights:{ru:'Права',en:'Rights'},
 safety:{ru:'Безопасность',en:'Safety'},
 post:{ru:'Постпродакшн',en:'Post'}
}
const statusNames:Record<ProductionState,{ru:string,en:string}>={
 planned:{ru:'Запланировано',en:'Planned'},
 in_progress:{ru:'В работе',en:'In progress'},
 blocked:{ru:'Заблокировано',en:'Blocked'},
 ready_for_review:{ru:'Готово к проверке',en:'Ready for review'}
}
type SceneChoice='all'|string
type StateChoice='all'|ProductionState
const emptyForm={title:'',category:'script' as ProductionCategory,owner:'',dueDate:'',notes:''}
const film=getStudioWork('zero-window')

export default function OSACinemaProductionDesk() {
  const [locale,setLocale]=useState<StudioLocale>(()=>new URLSearchParams(window.location.search).get('lang')==='en'?'en':'ru')
  const [tasks,setTasks]=useState<ProductionTask[]>(readProductionPlan)
  const [scene,setScene]=useState<SceneChoice>('S01')
  const [stateFilter,setStateFilter]=useState<StateChoice>('all')
  const [query,setQuery]=useState('')
  const [form,setForm]=useState(emptyForm)
  const [message,setMessage]=useState('')
  const [error,setError]=useState('')
  const [confirmClear,setConfirmClear]=useState(false)
  const ru=locale==='ru'
  const tr=(a:string,b:string)=>ru?a:b
  useEffect(()=>subscribeProductionPlan(()=>setTasks(readProductionPlan())),[])
  const stats=useMemo(()=>productionStatistics(tasks),[tasks])
  const filtered=useMemo(()=>tasks.filter(t=>
    (scene==='all'||t.sceneId===scene) &&
    (stateFilter==='all'||t.status===stateFilter) &&
    (t.title+' '+t.notes+' '+t.owner+' '+t.category).toLowerCase().includes(query.trim().toLowerCase())
  ),[tasks,scene,stateFilter,query])
  const setLanguage=()=>{
    const next=ru?'en':'ru'
    const url=new URL(window.location.href)
    url.searchParams.set('lang',next)
    window.history.replaceState(window.history.state,'',url.pathname+url.search+url.hash)
    setLocale(next)
  }
  const persist=(next:ProductionTask[],success:string)=>{
    if(!saveProductionPlan(next)){
      setError(tr('Сохранение недоступно: лимит данных или доступ к хранилищу. Ничего не изменено.','Unable to save: data limit or unavailable device storage. No change was made.'))
      setMessage('')
      return false
    }
    setTasks(next)
    setError('')
    setMessage(success)
    return true
  }
  const add=(e:FormEvent<HTMLFormElement>)=>{
    e.preventDefault()
    const selectedScene=scene==='all'?'S01':scene
    const task=createProductionTask({...form,sceneId:selectedScene})
    if(!task){setError(tr('Заполните название и проверьте дату.','Enter a task name and verify the date.'));setMessage('');return}
    if(persist([...tasks,task],tr('Задача добавлена в локальный производственный план.','Task added to your local production plan.'))){
      setForm(emptyForm)
      setConfirmClear(false)
    }
  }
  const changeState=(task:ProductionTask,status:ProductionState)=>{
    const next=updateProductionTask(tasks,task.id,status)
    if(!next){setError(tr('Невозможно изменить эту задачу.','Could not update this task.'));return}
    persist(next,tr('План обновлён. Это не подтверждение состоявшейся съёмки.','Plan updated. This is not filming evidence.'))
  }
  const remove=(id:string)=>{
    persist(tasks.filter(t=>t.id!==id),tr('Задача удалена с устройства.','Task removed from this device.'))
  }
  const clear=()=>{
    if(!confirmClear){setConfirmClear(true);setMessage('');return}
    if(persist([],tr('Локальный план очищен.','Local plan cleared.')))setConfirmClear(false)
  }
  const download=(format:'json'|'csv')=>{
    setError('')
    let url:string|undefined
    try{
      const content=format==='json'?exportProductionBackup(tasks):exportProductionCsv(tasks)
      const mime=format==='json'?'application/json;charset=utf-8':'text/csv;charset=utf-8'
      url=URL.createObjectURL(new Blob([content],{type:mime}))
      const anchor=document.createElement('a')
      anchor.href=url
      anchor.download='OSA-CINEMA-production-draft-v1.'+format
      document.body.appendChild(anchor)
      anchor.click()
      anchor.remove()
      setMessage(tr('Файл подготовлен для сохранения браузером.','The file is ready for your browser to download.'))
    }catch{setError(tr('Не удалось подготовить экспорт.','Could not prepare the export.'))}
    finally{if(url){const resource=url;window.setTimeout(()=>URL.revokeObjectURL(resource),1500)}}
  }
  const importJson=async(event:ChangeEvent<HTMLInputElement>)=>{
    const control=event.currentTarget
    const file=control.files?.[0]
    if(!file)return
    setError('');setMessage('')
    try{
      if(file.size>MAX_PRODUCTION_IMPORT_BYTES||!file.name.toLowerCase().endsWith('.json'))throw Error('invalid')
      const validated=parseProductionBackup(await file.text())
      if(validated===null)throw Error('invalid')
      if(!saveProductionPlan(validated))throw Error('storage')
      setTasks(validated);setConfirmClear(false)
      setMessage(tr('Черновик восстановлен. Задач: ','Draft restored. Tasks: ')+validated.length)
    }catch(e){
      setError(e instanceof Error&&e.message==='storage'?
        tr('Нет доступа к локальному хранилищу. Предыдущий план не менялся.','Device storage unavailable. Existing plan was not changed.'):
        tr('Неверный формат черновика. Предыдущий план не менялся.','Invalid production draft. Existing plan was not changed.'))
    }finally{control.value=''}
  }
  return <main className="osa-studio osa-production-page" lang={locale} data-studio-release="no-go">
    <a className="osa-studio-skip" href="#osa-production-board">{tr('К плану производства','Skip to production plan')}</a>
    <header className="osa-studio-header">
      <a className="osa-studio-brand" href={'/osa-cinema/studio?lang='+locale}><span className="osa-studio-symbol" aria-hidden="true">◈</span><span>OSA <b>CINEMA</b><small>PRODUCTION OFFICE</small></span></a>
      <nav aria-label={tr('Навигация студии','Studio navigation')}>
        <a href={'/osa-cinema/studio?lang='+locale}><ArrowLeft size={16}/>{tr('Каталог','Catalogue')}</a>
        <a href={'/osa-cinema/studio/films/zero-window?lang='+locale}>{tr('Фильм','Film dossier')}</a>
        <a href="#osa-production-evidence">{tr('Контроль','Release gates')}</a>
      </nav>
      <button type="button" className="osa-studio-language" onClick={setLanguage} aria-label={tr('Switch to English','Переключить на русский')}><Globe2 size={15}/>{locale.toUpperCase()}</button>
    </header>
    <section className="osa-production-hero" aria-labelledby="osa-production-title">
      <div className="osa-production-hero-grid" aria-hidden="true" />
      <div className="osa-production-hero-inner">
        <p className="osa-studio-eyebrow">OSA CINEMA / ORIGINAL PRODUCTION / V59</p>
        <h1 id="osa-production-title">{tr('ПРОИЗВОДСТВО.','PRODUCTION.')}<br/><em>{tr('ПОД КОНТРОЛЕМ.','WITH CLARITY.')}</em></h1>
        <p className="osa-production-intro">{tr('Производственный кабинет короткометражного фильма «Нулевое окно». Планируйте работу по сценам, отслеживайте задачи и выгружайте черновики. Подтверждённые сведения отделены от ваших записей.','The working desk for the short film Zero Window. Plan scene-by-scene work, track tasks and export drafts. Verified evidence stays separate from your local notes.')}</p>
        <div className="osa-production-local"><LockKeyhole size={16}/>{tr('Только этот браузер · без сервера и командной синхронизации','This browser only · no server or team sync')}</div>
      </div>
      <div className="osa-production-mark" aria-hidden="true">OSA<br/>59</div>
    </section>
    <section className="osa-production-scoreboard" aria-label={tr('Факты о производстве','Production facts')}>
      <div><span>{tr('Запланированные сцены','Planned scenes')}</span><strong>{PLANNED_SCENES.toString().padStart(2,'0')}</strong><small>{tr('по документу V53','from V53 evidence')}</small></div>
      <div><span>{tr('Предложенные кадры','Proposed shots')}</span><strong>{PROPOSED_SHOTS}</strong><small>{tr('без распределения по сценам','not allocated per scene')}</small></div>
      <div><span>{tr('Подтверждено снятых','Verified filmed')}</span><strong>{VERIFIED_ACTOR_SCENES_FILMED}</strong><small>{tr('актёрские игровые сцены','live-action scenes')}</small></div>
      <div><span>{tr('Целевая длительность','Target runtime')}</span><strong>{Math.round(TARGET_FILM_SECONDS/60)}<span> MIN</span></strong><small>{tr('план, не готовый фильм','planned, not a finished film')}</small></div>
    </section>
    <section className="osa-production-gate" id="osa-production-evidence" aria-labelledby="osa-production-gate-title">
      <div className="osa-production-gate-icon"><ShieldAlert size={25}/></div>
      <div><p className="osa-studio-eyebrow">PUBLIC RELEASE / STRICT NO-GO</p><h2 id="osa-production-gate-title">{tr('Никаких ложных премьер.','No unverified premieres.')}</h2><p>{tr('Локальные задачи не подтверждают съёмки, права, безопасность и публичную видеодоставку. Данные V53 неизменны: снято 0 сцен, публичный релиз не разрешён.','Local tasks do not prove filming, rights, safety or public playback. The V53 record remains unchanged: zero scenes filmed and no authorized film release.')}</p></div>
      <a href="https://github.com/osmanosmanov6880-bot/osgard-world/blob/master/docs/OSA_CINEMA_V53_CONCEPT_EVIDENCE_20261028.json" target="_blank" rel="noopener noreferrer">{tr('Акт V53','V53 record')}<ArrowRight size={15}/></a>
    </section>
    <section className="osa-production-body" id="osa-production-board">
      <div className="osa-studio-section-head"><div><p className="osa-studio-eyebrow">01 / LOCAL PRODUCTION WORKSPACE</p><h2>{tr('Кадры начинаются с плана.','Every frame starts with a plan.')}</h2><p>{tr('Статусы ниже относятся только к выполнению задач планирования — не к снятым сценам.','Statuses below are for planning tasks only, never completed filming.')}</p></div><span className="osa-studio-section-index">ZERO WINDOW / {film?.year??'2026'}</span></div>
      <div className="osa-production-summary" aria-label={tr('Локальные задачи','Local task summary')}>
        <div><strong>{stats.total}</strong><span>{tr('Всего задач','Total tasks')}</span></div>
        <div><strong>{stats.inProgress}</strong><span>{tr('В работе','In progress')}</span></div>
        <div><strong>{stats.blocked}</strong><span>{tr('Заблокировано','Blocked')}</span></div>
        <div><strong>{stats.readyForReview}</strong><span>{tr('На проверке','Ready for review')}</span></div>
      </div>
      <div className="osa-production-workspace">
        <aside className="osa-production-scenes" aria-labelledby="osa-scenes-title"><p className="osa-studio-eyebrow">SCENE INDEX / 13</p><h3 id="osa-scenes-title">{tr('Сцены','Scenes')}</h3><div className="osa-production-scene-grid">
          <button type="button" aria-pressed={scene==='all'} className={scene==='all'?'active':''} onClick={()=>setScene('all')}>{tr('Все','All')}</button>
          {PRODUCTION_SCENE_IDS.map(id=><button key={id} type="button" aria-pressed={scene===id} className={scene===id?'active':''} onClick={()=>{setScene(id);setConfirmClear(false)}}>{id}<small>{tasks.filter(t=>t.sceneId===id).length}</small></button>)}
        </div><p className="osa-production-scene-note">{tr('Нумерация соответствует 13 запланированным сценам. Названия и количество кадров каждой сцены не выдумываются.','Numbering follows the 13 planned scenes. Scene titles and per-scene shot counts are not fabricated.')}</p></aside>
        <div className="osa-production-panel">
          <div className="osa-production-panel-heading"><div><p className="osa-studio-eyebrow">TASKS / LOCAL DRAFT</p><h3>{scene==='all'?tr('Все сцены','All scenes'):tr('Сцена ','Scene ')+scene.slice(1)}</h3></div><span>{filtered.length} / {stats.total}</span></div>
          <div className="osa-production-filters"><label className="osa-production-search"><Search size={17}/><span className="sr-only">{tr('Поиск задач','Search tasks')}</span><input value={query} onChange={e=>setQuery(e.target.value)} placeholder={tr('Поиск задач…','Search tasks…')} maxLength={100}/></label><label className="osa-production-select"><span className="sr-only">{tr('Фильтр статуса','Status filter')}</span><select value={stateFilter} onChange={e=>setStateFilter(e.target.value as StateChoice)}><option value="all">{tr('Все статусы','All statuses')}</option>{PRODUCTION_STATES.map(x=><option key={x} value={x}>{ru?statusNames[x].ru:statusNames[x].en}</option>)}</select></label></div>
          <div className="osa-production-tasks">
            {filtered.length===0?<div className="osa-production-empty"><ClipboardList size={31}/><h4>{tr('Нет задач по выбранным условиям.','No tasks match these filters.')}</h4><p>{tr('Добавьте первую постановочную задачу ниже. Это не изменит подтверждённый статус фильма.','Add a planning task below. It will not change the film’s verified status.')}</p></div>:
            filtered.map(t=><article key={t.id} className={'osa-production-task osa-production-task-'+t.status}>
              <div className="osa-production-task-top"><span className="osa-production-task-id">{t.sceneId} / {ru?departmentNames[t.category].ru:departmentNames[t.category].en}</span><span className="osa-production-state">{ru?statusNames[t.status].ru:statusNames[t.status].en}</span></div>
              <h4>{t.title}</h4>{t.notes&&<p className="osa-production-task-notes">{t.notes}</p>}
              <div className="osa-production-task-meta">{t.owner&&<span>{tr('Ответственный: ','Owner: ')}{t.owner}</span>}{t.dueDate&&<span><CalendarDays size={14}/>{t.dueDate}</span>}</div>
              <div className="osa-production-task-controls"><label><span>{tr('Статус задачи','Task status')}</span><select aria-label={tr('Статус задачи: ','Task status: ')+t.title} value={t.status} onChange={e=>changeState(t,e.target.value as ProductionState)}>{PRODUCTION_STATES.map(s=><option key={s} value={s}>{ru?statusNames[s].ru:statusNames[s].en}</option>)}</select></label><button type="button" onClick={()=>remove(t.id)} aria-label={tr('Удалить задачу: ','Delete task: ')+t.title}><Trash2 size={16}/>{tr('Удалить','Delete')}</button></div>
            </article>)}
          </div>
        </div>
      </div>
      <section className="osa-production-create" aria-labelledby="osa-production-create-title">
        <div><p className="osa-studio-eyebrow">02 / BUILD THE WORK</p><h2 id="osa-production-create-title">{tr('Добавить задачу.','Add a task.')}</h2><p>{tr('Создавайте реальные рабочие пункты: кастинг, локации, камера, звук, права и безопасность. Это личный черновик без подтверждения производства.','Plan casting, locations, camera, sound, rights and safety. This is a local personal draft, not evidence that filming has happened.')}</p></div>
        <form className="osa-production-form" onSubmit={add}>
          <label>{tr('Название задачи','Task title')}<input required maxLength={120} value={form.title} onChange={e=>setForm({...form,title:e.target.value})} placeholder={tr('Например: согласовать площадку','Example: confirm a location')}/></label>
          <div className="osa-production-form-row"><label>{tr('Направление','Department')}<select value={form.category} onChange={e=>setForm({...form,category:e.target.value as ProductionCategory})}>{PRODUCTION_CATEGORIES.map(id=><option key={id} value={id}>{ru?departmentNames[id].ru:departmentNames[id].en}</option>)}</select></label><label>{tr('Плановая дата','Planned date')}<input type="date" value={form.dueDate} onChange={e=>setForm({...form,dueDate:e.target.value})}/></label></div>
          <label>{tr('Ответственный (необязательно)','Owner (optional)')}<input maxLength={80} value={form.owner} onChange={e=>setForm({...form,owner:e.target.value})} placeholder={tr('Роль или инициалы','Role or initials')}/></label>
          <label>{tr('Примечания','Notes')}<textarea rows={3} maxLength={600} value={form.notes} onChange={e=>setForm({...form,notes:e.target.value})} placeholder={tr('Краткий рабочий план, без секретов и персональных данных','Brief action plan; do not include secrets or private data')}/></label>
          <p className="osa-production-form-scene"><Film size={15}/>{tr('Добавить к: ','Assign to: ')}<strong>{scene==='all'?'S01':scene}</strong><span>{scene==='all'?tr('(из общего списка — сцена 01)','(from All scenes, defaults to scene 01)'):''}</span></p>
          <button type="submit" className="osa-studio-button"><Plus size={18}/>{tr('Добавить в локальный план','Add to local plan')}<ArrowRight size={17}/></button>
        </form>
      </section>
      <section className="osa-production-portability" aria-labelledby="osa-production-portability-title">
        <div><p className="osa-studio-eyebrow">03 / DATA OWNERSHIP</p><h2 id="osa-production-portability-title">{tr('План принадлежит вам.','Own your planning data.')}</h2><p>{tr('Экспорт JSON для сохранения и восстановления, CSV для таблиц. Импорт заменяет текущий локальный план только после полной проверки. Не храните здесь секреты и чувствительные персональные данные.','Export JSON for backup and restore; CSV for spreadsheets. Import replaces the local plan only after full validation. Do not store secrets or sensitive personal information here.')}</p><p className="osa-production-data-warning"><ShieldCheck size={18}/>{tr('Данные остаются в вашем браузере. Это не защищённый корпоративный кабинет.','Data stays in your browser. This is not an access-controlled company workspace.')}</p></div>
        <div className="osa-production-tools"><button type="button" onClick={()=>download('json')}><Download size={18}/>{tr('Экспорт JSON','Export JSON')}</button><button type="button" onClick={()=>download('csv')}><Download size={18}/>{tr('Экспорт CSV','Export CSV')}</button><input id="osa-production-import" className="osa-production-file" type="file" accept=".json,application/json" onChange={e=>{void importJson(e)}}/><label htmlFor="osa-production-import"><Upload size={18}/>{tr('Импорт черновика','Import draft')}</label><button type="button" className={confirmClear?'osa-production-danger':''} onClick={clear}><Trash2 size={17}/>{confirmClear?tr('Подтвердить очистку','Confirm clear'):tr('Очистить план','Clear plan')}</button>{confirmClear&&<button type="button" onClick={()=>setConfirmClear(false)}>{tr('Отмена','Cancel')}</button>}</div>
      </section>
      <div className="osa-production-feedback" aria-live="polite">{message&&<p role="status"><Check size={16}/>{message}</p>}{error&&<p role="alert"><ShieldAlert size={16}/>{error}</p>}</div>
    </section>
    <footer className="osa-studio-footer"><div><span className="osa-studio-symbol" aria-hidden="true">◈</span><strong>OSA CINEMA</strong><p>{tr('Реальные факты. Проверяемое производство.','Real records. Verifiable production.')}</p></div><div className="osa-studio-footer-links"><a href={'/osa-cinema/studio/films/zero-window?lang='+locale}><ArrowRight size={16}/>{tr('Досье фильма','Film dossier')}</a><a href={'/osa-cinema/studio?lang='+locale}><ArrowLeft size={16}/>{tr('В каталог','Catalogue')}</a></div><span>© 2026 OSA ORIGINAL STUDIOS</span></footer>
  </main>
}
