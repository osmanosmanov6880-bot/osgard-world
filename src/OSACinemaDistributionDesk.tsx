import { useEffect, useState, type ChangeEvent } from 'react'
import { ArrowLeft, ArrowRight, Check, Download, FileCheck2, Globe2, LockKeyhole, ShieldAlert, ShieldCheck, Trash2, Upload, VideoOff } from 'lucide-react'
import { type StudioLocale } from './osaCinemaStudioRegistry'
import {
  releaseGates,publicReleaseDecision,readReleaseNotes,saveReleaseNotes,
  subscribeReleaseNotes,updateReleaseNote,exportReleaseNotes,importReleaseNotes,
  RELEASE_REVIEW_STATES,MAX_RELEASE_BACKUP_BYTES,
  type DistributionProjectId,type ReviewState,type ReleaseNotes
} from './osaCinemaDistribution'
import './osaCinemaStudio.css'
import './osaCinemaDistributionDesk.css'
const title={
 'zero-window':{ru:'НУЛЕВОЕ ОКНО',en:'ZERO WINDOW'},
 threshold:{ru:'ПОРОГ РЕШЕНИЯ',en:'THRESHOLD'}
}
const reviews:Record<ReviewState,{ru:string,en:string}>={
 not_started:{ru:'Не начато',en:'Not started'},
 preparing:{ru:'Подготовка материалов',en:'Preparing material'},
 review_requested:{ru:'Запрос на проверку (локальная отметка)',en:'Marked for review (local only)'}
}
const evidence={
 verified:{ru:'Документировано',en:'Documented'},
 pending:{ru:'Независимая проверка требуется',en:'Independent verification required'},
 blocked:{ru:'Публичный показ заблокирован',en:'Public screening blocked'}
}
type Draft={status:ReviewState;note:string}
export default function OSACinemaDistributionDesk(){
 const [locale,setLocale]=useState<StudioLocale>(()=>new URLSearchParams(window.location.search).get('lang')==='en'?'en':'ru')
 const [projectId,setProjectId]=useState<DistributionProjectId>('zero-window')
 const [notes,setNotes]=useState<ReleaseNotes>(()=>readReleaseNotes('zero-window'))
 const [drafts,setDrafts]=useState<Record<string,Draft>>({})
 const [message,setMessage]=useState('')
 const [error,setError]=useState('')
 const [clearReady,setClearReady]=useState(false)
 const ru=locale==='ru'
 const tr=(a:string,b:string)=>ru?a:b
 const decision=publicReleaseDecision(projectId)
 useEffect(()=>{const update=()=>setNotes(readReleaseNotes(projectId));update();return subscribeReleaseNotes(projectId,update)},[projectId])
 const selected=(id:string):Draft=>drafts[id]??{
   status:notes.items.find(n=>n.gateId===id)?.status??'not_started',
   note:notes.items.find(n=>n.gateId===id)?.note??''
 }
 const updateDraft=(id:string,patch:Partial<Draft>)=>{
   setDrafts(all=>({...all,[id]:{...selected(id),...patch}}))
 }
 const switchProject=(id:DistributionProjectId)=>{
   setProjectId(id);setDrafts({});setMessage('');setError('');setClearReady(false)
 }
 const switchLocale=()=>{
   const next=ru?'en':'ru'
   const url=new URL(window.location.href)
   url.searchParams.set('lang',next)
   window.history.replaceState(window.history.state,'',url.pathname+url.search+url.hash)
   setLocale(next)
 }
 const store=(next:ReleaseNotes,success:string):boolean=>{
   if(!saveReleaseNotes(next)){
     setError(tr('Невозможно сохранить на устройстве. Данные не изменены.','Unable to save locally. Your notes were not changed.'))
     setMessage('')
     return false
   }
   setNotes(next);setError('');setMessage(success)
   return true
 }
 const save=(id:string)=>{
   const input=selected(id)
   const next=updateReleaseNote(notes,id,input.status,input.note)
   if(!next){setError(tr('Ошибка проверки записи.','Review note validation failed.'));return}
   if(store(next,tr('Локальная отметка сохранена — реальный статус публикации не изменился.','Local note saved. Actual release status remains unchanged.'))){
     setDrafts(all=>{const copy={...all};delete copy[id];return copy})
   }
 }
 const remove=(id:string)=>{
   if(store({projectId,items:notes.items.filter(n=>n.gateId!==id)},tr('Локальная отметка удалена.','Local note removed.'))){
     setDrafts(all=>{const copy={...all};delete copy[id];return copy})
   }
 }
 const clear=()=>{
   if(!clearReady){setClearReady(true);setMessage('');return}
   if(store({projectId,items:[]},tr('Заметки этого проекта удалены из браузера.','This project’s browser-only notes were cleared.'))){
     setClearReady(false);setDrafts({})
   }
 }
 const download=()=>{
   let url:string|undefined
   try{
     const content=exportReleaseNotes(notes)
     url=URL.createObjectURL(new Blob([content],{type:'application/json;charset=utf-8'}))
     const a=document.createElement('a')
     a.href=url;a.download='OSA_CINEMA_'+projectId+'_distribution_notes.json'
     document.body.appendChild(a);a.click();a.remove()
     setError('');setMessage(tr('Резервная копия подготовлена.','Your local backup is ready.'))
   }catch{setError(tr('Не удалось подготовить файл.','Could not prepare backup file.'))}
   finally{if(url){const resource=url;window.setTimeout(()=>URL.revokeObjectURL(resource),1500)}}
 }
 const importFile=async(e:ChangeEvent<HTMLInputElement>)=>{
   const input=e.currentTarget,file=input.files?.[0]
   if(!file)return
   setError('');setMessage('')
   try{
     if(file.size>MAX_RELEASE_BACKUP_BYTES||!file.name.toLowerCase().endsWith('.json'))throw Error('format')
     const parsed=importReleaseNotes(await file.text())
     if(!parsed||parsed.projectId!==projectId)throw Error('format')
     if(!saveReleaseNotes(parsed))throw Error('storage')
     setNotes(parsed);setDrafts({});setClearReady(false)
     setMessage(tr('Заметки успешно восстановлены: ','Review notes restored: ')+parsed.items.length)
   }catch(problem){
     const blocked=problem instanceof Error&&problem.message==='storage'
     setError(blocked?tr('Хранилище недоступно. Старые заметки сохранены.','Storage unavailable. Previous notes remain intact.'):tr('Недопустимый файл или другой проект. Импорт отклонён.','Invalid backup or wrong project. Nothing was imported.'))
   }finally{input.value=''}
 }
 return <main className="osa-studio osa-distribution-page" data-public-release="no-go" lang={locale}>
  <a className="osa-studio-skip" href="#osa-distribution-gates">{tr('К проверкам','Skip to review gates')}</a>
  <header className="osa-studio-header">
   <a href={'/osa-cinema/studio?lang='+locale} className="osa-studio-brand"><span className="osa-studio-symbol" aria-hidden="true">◈</span><span>OSA <b>CINEMA</b><small>RELEASE INTEGRITY DESK</small></span></a>
   <nav aria-label={tr('Навигация кабинета','Desk navigation')}>
    <a href={'/osa-cinema/studio?lang='+locale}><ArrowLeft size={16}/>{tr('Каталог','Catalogue')}</a>
    <a href={'/osa-cinema/studio/press?lang='+locale}>{tr('Публичный пресс-центр','Public pressroom')}</a>
    <a href="#osa-distribution-gates">{tr('Проверки','Review gates')}</a>
   </nav>
   <button className="osa-studio-language" type="button" onClick={switchLocale} aria-label={tr('Switch to English','Переключить на русский')}><Globe2 size={15}/>{locale.toUpperCase()}</button>
  </header>
  <section className="osa-distribution-hero">
   <div className="osa-distribution-hero-inner">
    <p className="osa-studio-eyebrow">OSA CINEMA / V60 / RELEASE GOVERNANCE</p>
    <h1>{tr('ПОКАЗ','RELEASE')}<br/><em>{tr('ТОЛЬКО ПО ФАКТАМ.','REQUIRES PROOF.')}</em></h1>
    <p>{tr('Закрытый по назначению локальный инструмент: планируйте сбор подтверждений по каждому фильму. Данные находятся только в этом браузере и не становятся юридическим разрешением, даже когда все пункты отмечены.','A browser-local planning tool for preparing independent distribution evidence. These notes never become legal authorization, even if every item is marked.')}</p>
    <span className="osa-distribution-privacy"><LockKeyhole size={16}/>{tr('Нет входа, серверной синхронизации и передачи подтверждений','No login, server sync or evidence upload')}</span>
   </div>
   <div className="osa-distribution-stamp" aria-hidden="true">NO<br/>GO</div>
  </section>
  <section className="osa-distribution-selector" aria-label={tr('Выбор проекта','Choose project')}>
   {(['zero-window','threshold'] as const).map(id=><button type="button" key={id} aria-pressed={projectId===id} className={projectId===id?'active':''} onClick={()=>switchProject(id)}><span>{id==='zero-window'?'01':'02'} / OSA ORIGINAL</span><strong>{ru?title[id].ru:title[id].en}</strong><small>{id==='zero-window'?tr('Короткометражный фильм · ещё не снят','Short film · not yet filmed'):tr('Превиз · только у владельца','Previz · owner-local only')}</small></button>)}
  </section>
  <section className="osa-distribution-content" id="osa-distribution-gates">
   <div className="osa-studio-section-head"><div><p className="osa-studio-eyebrow">01 / INDEPENDENT EVIDENCE GATES</p><h2>{tr('Проверки без самообмана.','Evidence. Not self-approval.')}</h2><p>{tr('Здесь можно подготовить документы для независимой проверки. Статусы реальных фактов неизменяемы, а отметки справа — только ваш локальный рабочий план.','Prepare materials for independent assessment. Documented evidence is immutable; the controls below are only your local planning notes.')}</p></div><span className="osa-studio-section-index">V53 / STRICT NO-GO</span></div>
   <div className="osa-distribution-overview" aria-label={tr('Сводка независимых проверок','Independent release gate summary')}>
    <div><strong>{decision.verified}</strong><span>{tr('Документировано','Documented')}</span></div>
    <div><strong>{decision.pending}</strong><span>{tr('Требует проверки','Needs review')}</span></div>
    <div><strong>{decision.blocked}</strong><span>{tr('Заблокировано','Blocked')}</span></div>
    <div className="osa-distribution-overview-no"><VideoOff size={22}/><strong>NO-GO</strong><span>{tr('Разрешение на показ','Public release authorization')}</span></div>
   </div>
   <div className="osa-distribution-gates">
    {decision.gates.map(g=>{
     const draft=selected(g.id)
     const saved=notes.items.some(n=>n.gateId===g.id)
     return <article className="osa-distribution-gate" key={g.id}>
      <div className="osa-distribution-evidence"><span className="osa-distribution-gate-code">{g.id.toUpperCase()}</span><div className={'osa-distribution-evidence-status is-'+g.evidence}>{g.evidence==='verified'?<FileCheck2 size={19}/>:g.evidence==='pending'?<ShieldAlert size={19}/>:<LockKeyhole size={19}/>}<span>{g.evidence==='verified'?tr('Документировано','Documented'):g.evidence==='pending'?tr('Независимая проверка требуется','Independent review required'):tr('Не разрешено','Not cleared')}</span></div><h3>{ru?g.nameRu:g.nameEn}</h3><p>{ru?g.descriptionRu:g.descriptionEn}</p></div>
      <div className="osa-distribution-note"><p className="osa-studio-eyebrow">YOUR DEVICE / NOT AN APPROVAL</p><label>{tr('Подготовка подтверждений','Evidence preparation')}
       <select value={draft.status} onChange={e=>updateDraft(g.id,{status:e.target.value as ReviewState})} aria-label={tr('Статус подготовки: ','Preparation status: ')+(ru?g.nameRu:g.nameEn)}>
        {RELEASE_REVIEW_STATES.map(s=><option value={s} key={s}>{ru?reviews[s].ru:reviews[s].en}</option>)}
       </select></label>
       <label>{tr('Рабочие заметки · до 500 знаков','Planning notes · up to 500 characters')}
        <textarea maxLength={500} rows={3} value={draft.note} onChange={e=>updateDraft(g.id,{note:e.target.value})} placeholder={tr('Что требуется подготовить? Не добавляйте секреты и персональные данные.','What evidence is needed? Do not enter secrets or personal data.')} />
       </label>
       <div className="osa-distribution-note-actions"><button type="button" onClick={()=>save(g.id)}><Check size={15}/>{tr('Сохранить заметку','Save local note')}</button>{saved&&<button type="button" className="osa-distribution-note-delete" onClick={()=>remove(g.id)}><Trash2 size={14}/>{tr('Удалить','Delete')}</button>}</div>
      </div>
     </article>
    })}
   </div>
   <section className="osa-distribution-data" aria-labelledby="osa-distribution-data-title">
    <div><p className="osa-studio-eyebrow">02 / YOUR DATA / YOUR CONTROL</p><h2 id="osa-distribution-data-title">{tr('Сохранить план проверки.','Keep your review notes.')}</h2><p>{tr('Заметки хранятся в localStorage этого устройства. Экспортируйте JSON или восстановите его. Импорт проверяет схему, проект, размер и отсутствие поля разрешения релиза.','Notes are saved in this browser’s localStorage. Export or restore a JSON backup. Import checks schema, project ID, size and rejects forged release approval.')}</p><p className="osa-distribution-data-warning"><ShieldCheck size={17}/>{tr('Отметка «Запрос на проверку» не отправляет ничего проверяющему.','“Marked for review” does not send anything to an auditor.')}</p></div>
    <div className="osa-distribution-tools"><button type="button" onClick={download}><Download size={18}/>{tr('Экспорт JSON','Export JSON')}</button><input type="file" id="osa-release-import" accept=".json,application/json" onChange={e=>{void importFile(e)}}/><label htmlFor="osa-release-import"><Upload size={18}/>{tr('Импорт JSON','Import JSON')}</label><button type="button" className={clearReady?'warning':''} onClick={clear}><Trash2 size={16}/>{clearReady?tr('Подтвердить очистку','Confirm deletion'):tr('Очистить заметки','Clear notes')}</button>{clearReady&&<button type="button" onClick={()=>setClearReady(false)}>{tr('Отмена','Cancel')}</button>}</div>
   </section>
   <div className="osa-distribution-feedback" aria-live="polite">{message&&<p role="status"><Check size={16}/>{message}</p>}{error&&<p role="alert"><ShieldAlert size={16}/>{error}</p>}</div>
   <section className="osa-distribution-reminder"><ShieldAlert size={25}/><div><strong>{tr('Не публиковать фильм на основании этого кабинета.','This desk cannot publish a film.')}</strong><p>{tr('Нужны реальные съёмки, независимые юридические разрешения, финальный мастер, безопасность и технически проверенный публичный показ. Эти условия проверяются отдельно серверным механизмом релиза.','Actual filming, independently verified rights, completed masters, safety and real public playback are separately required. The server-side release system remains closed.')}</p></div></section>
  </section>
  <footer className="osa-studio-footer"><div><span className="osa-studio-symbol" aria-hidden="true">◈</span><strong>OSA CINEMA</strong><p>{tr('Факты не заменяются отметками.','Notes never replace facts.')}</p></div><div className="osa-studio-footer-links"><a href={'/osa-cinema/studio/press?lang='+locale}><ArrowRight size={16}/>{tr('Публичный пресс-центр','Public pressroom')}</a><a href={'/osa-cinema/studio?lang='+locale}><ArrowLeft size={16}/>{tr('Студия','Studio')}</a></div><span>© 2026 OSA ORIGINAL STUDIOS</span></footer>
 </main>
}
