import { useEffect,useRef,useState,type FormEvent } from 'react'
import { ArrowUpRight,Check,Download,FileCheck2,FileClock,FilePlus2,Globe2,LockKeyhole,RefreshCw,RotateCcw,ShieldAlert,ShieldCheck,UploadCloud,X } from 'lucide-react'
import { coreRequest,CoreError,downloadCore } from './coreClient'
import type { StudioLocale } from './osaCinemaStudioRegistry'
import './osaCinemaEvidenceRoom.css'

type Role='owner'|'editor'|'viewer'
type EvidenceState='draft'|'review_requested'|'needs_changes'|'internally_reviewed'
type Category='script'|'shotlist'|'casting'|'location'|'safety'|'rights'|'post'|'master'|'delivery'
type Review={id:string;verdict:'needs_changes'|'internally_reviewed';note:string;itemVersion:number;reviewer:string;createdAt:string}
type Item={id:string;sceneId:string;category:Category;title:string;description:string;sourceUrl:string;declaredSha256:string;checksumVerifiedByServer:false;externalRightsVerified:false;state:EvidenceState;version:number;authorId:string;author:string;createdAt:string;updatedAt:string;reviews:Review[]}
type Response={spaceId:string;spaceVersion:number;role:Role;evidence:Item[];releaseAuthorized:false;rightsIndependentlyVerified:false;publicVideoUrl:null;scope:string;verificationLimits:{independentProfessionalAudit:false;checksumCalculatedFromFiles:false;legalRightsClearance:false;actualFilmingCertified:false}}
type Draft={sceneId:string;category:Category;title:string;description:string;sourceUrl:string;declaredSha256:string}
type Props={spaceId:string;role:Role;version:number;filmId:'zero-window'|'threshold';username:string;locale:StudioLocale;onChanged:()=>Promise<void>}
const categories:Record<Category,[string,string]>={
 script:['Сценарий','Script'],shotlist:['Раскадровка','Shotlist'],casting:['Кастинг','Casting'],
 location:['Локации','Locations'],safety:['Безопасность','Safety'],rights:['Права (метаданные)','Rights (metadata)'],
 post:['Монтаж','Post'],master:['Мастер (сведения)','Master (record)'],delivery:['Доставка','Delivery']
}
const states:Record<EvidenceState,[string,string]>={
 draft:['Черновик','Draft'],review_requested:['Внутренняя проверка','Internal review requested'],
 needs_changes:['Требует исправлений','Needs changes'],internally_reviewed:['Внутренне рассмотрено','Internally reviewed']
}
const empty=(filmId:Props['filmId']):Draft=>({sceneId:filmId==='threshold'?'PREVIZ':'S01',category:'script',title:'',description:'',sourceUrl:'',declaredSha256:''})
const CATEGORIES=Object.keys(categories) as Category[]
const SCENES=Array.from({length:13},(_,i)=>'S'+String(i+1).padStart(2,'0'))

export default function OSACinemaEvidenceRoom({spaceId,role,version,filmId,username,locale,onChanged}:Props){
 const ru=locale==='ru'
 const tr=(a:string,b:string)=>ru?a:b
 const [response,setResponse]=useState<Response|null>(null)
 const [loading,setLoading]=useState(true)
 const [busy,setBusy]=useState(false)
 const [error,setError]=useState('')
 const [notice,setNotice]=useState('')
 const [draft,setDraft]=useState<Draft>(()=>empty(filmId))
 const [editing,setEditing]=useState<{id:string;version:number}|null>(null)
 const [filter,setFilter]=useState<'all'|EvidenceState>('all')
 const [reviewing,setReviewing]=useState<{id:string;version:number}|null>(null)
 const [verdict,setVerdict]=useState<'needs_changes'|'internally_reviewed'>('needs_changes')
 const [reviewNote,setReviewNote]=useState('')
 const pending=useRef<{signature:string;key:string}|null>(null)
 const canEdit=role==='owner'||role==='editor'
 const route='cinema/spaces/'+spaceId+'/evidence'
 const items=response?.evidence.filter(x=>filter==='all'||x.state===filter)??[]
 const scenes=filmId==='threshold'?['PREVIZ']:SCENES
 async function load(){
  setLoading(true);setError('')
  try{setResponse(await coreRequest<Response>(route))}
  catch(e){setError(e instanceof Error?e.message:tr('Не удалось получить реестр.','Could not load evidence room.'))}
  finally{setLoading(false)}
 }
 useEffect(()=>{setResponse(null);setDraft(empty(filmId));setEditing(null);setReviewing(null);void load()},[spaceId,version])
 async function write(kind:string,fields:Record<string,unknown>){
  const payload={kind,expectedVersion:response?.spaceVersion??version,...fields}
  const signature=JSON.stringify([spaceId,payload])
  const key=pending.current?.signature===signature?pending.current.key:crypto.randomUUID().replaceAll('-','')
  pending.current={signature,key}
  setBusy(true);setError('');setNotice('')
  try{
   await coreRequest(route,payload,key)
   pending.current=null
   await onChanged()
   await load()
   setNotice(tr('Метаданные сохранены на сервере. Это не юридическая проверка и не разрешение на показ.','Metadata saved on Core. This is neither legal verification nor film release approval.'))
   return true
  }catch(e){
   if(e instanceof CoreError&&e.code==='version_conflict'){
    pending.current=null;await onChanged();await load()
   }
   setError(e instanceof CoreError&&e.code==='version_conflict'
    ?tr('Обнаружено более новое изменение. Данные обновлены. Проверьте поля и повторите действие.','A newer change exists. Data was refreshed. Review the fields and try again.')
    :e instanceof Error?e.message:tr('Не удалось сохранить.','Could not save.'))
   return false
  }finally{setBusy(false)}
 }
 async function save(e:FormEvent){
  e.preventDefault()
  const fields={...draft,sceneId:scenes.includes(draft.sceneId)?draft.sceneId:scenes[0]}
  const ok=editing?await write('evidence.update',{...fields,evidenceId:editing.id,expectedItemVersion:editing.version}):await write('evidence.create',fields)
  if(ok){setDraft(empty(filmId));setEditing(null)}
 }
 function edit(item:Item){
  setDraft({sceneId:item.sceneId,category:item.category,title:item.title,
    description:item.description,sourceUrl:item.sourceUrl,declaredSha256:item.declaredSha256})
  setEditing({id:item.id,version:item.version})
  document.querySelector('#osa-evidence-create')?.scrollIntoView({behavior:'smooth',block:'start'})
 }
 async function submit(item:Item){await write('evidence.request_review',{evidenceId:item.id,expectedItemVersion:item.version})}
 async function review(e:FormEvent){
  e.preventDefault()
  if(!reviewing)return
  if(await write('evidence.review',{evidenceId:reviewing.id,expectedItemVersion:reviewing.version,verdict,note:reviewNote})){
   setReviewing(null);setReviewNote('')
  }
 }
 function snapshot(){
  if(!response)return
  downloadCore({format:'OSA_CINEMA_EVIDENCE_METADATA_V1',exportedAt:new Date().toISOString(),
   workspaceId:spaceId,rightsIndependentlyVerified:false,publicReleaseAuthorized:false,
   sourcesFetched:false,filesUploaded:false,checksumVerifiedFromFile:false,
   evidence:response.evidence},'OSA_CINEMA_EVIDENCE_'+filmId+'.json')
 }
 return <section className="osa-evidence-room" aria-labelledby="osa-evidence-heading" data-evidence-scope="metadata-only">
  <header className="osa-evidence-intro">
   <div><p className="osa-studio-eyebrow">OSA CINEMA / V62 / EVIDENCE ROOM</p>
    <h3 id="osa-evidence-heading">{tr('Досье. С проверкой автора.','Evidence. With peer review.')}</h3>
    <p>{tr('Закрытый серверный реестр заявленных источников и контрольных сумм. Данные не означают, что файл существует, права очищены или фильм снят.','Private registry of declared sources and checksums. No file existence, filming, rights clearance or publication is independently verified.')}</p>
   </div><div className="osa-evidence-toolbar"><button type="button" disabled={busy||loading} onClick={()=>void load()}><RefreshCw size={16}/>{tr('Обновить','Reload')}</button><button type="button" disabled={!response} onClick={snapshot}><Download size={16}/>{tr('Экспорт досье','Export metadata')}</button></div>
  </header>
  <div className="osa-evidence-facts" role="note"><ShieldAlert size={20}/><div><strong>{tr('Внутренняя проверка ≠ независимая экспертиза','Internal review ≠ independent certification')}</strong><span>{tr('Нет загрузки оригиналов, сверки SHA-256 с файлом, проверки лицензий и разрешения MP4-публикации.','No file upload, no hash calculation from files, no professional rights audit and no MP4 release permission.')}</span></div><small>STRICT NO-GO</small></div>
  {loading&&<p className="osa-evidence-status" role="status"><RefreshCw size={17}/>{tr('Загрузка реальных данных Core…','Loading real Core records…')}</p>}
  {!loading&&response&&<>
   <div className="osa-evidence-overview">
     <div><strong>{response.evidence.length}</strong><span>{tr('Записей','Records')}</span></div>
     <div><strong>{response.evidence.filter(x=>x.state==='review_requested').length}</strong><span>{tr('Ждут коллегу','Awaiting peer')}</span></div>
     <div><strong>{response.evidence.filter(x=>x.state==='internally_reviewed').length}</strong><span>{tr('Внутренне рассмотрены','Internally reviewed')}</span></div>
     <div><strong>NO-GO</strong><span>{tr('Публичная премьера','Public premiere')}</span></div>
   </div>
   <div className="osa-evidence-filter"><label>{tr('Показать','Show')}<select value={filter} onChange={e=>setFilter(e.target.value as typeof filter)}>
    <option value="all">{tr('Все записи','All records')}</option>{(Object.keys(states) as EvidenceState[]).map(k=><option key={k} value={k}>{ru?states[k][0]:states[k][1]}</option>)}
   </select></label></div>
   <div className="osa-evidence-list">
    {items.length===0&&<p className="osa-evidence-empty">{tr('Сохранённых записей с таким статусом нет. Ничего не создаётся автоматически.','No actual records match this filter. Nothing is generated automatically.')}</p>}
    {items.map(item=><article key={item.id} className="osa-evidence-card">
     <div className="osa-evidence-card-head"><div><span className="osa-evidence-id">{item.sceneId} · {ru?categories[item.category][0]:categories[item.category][1]} · v{item.version}</span><h4>{item.title}</h4><small>{tr('Автор: ','Author: ')}{item.author} · {item.updatedAt}</small></div><span className={'osa-evidence-pill state-'+item.state}>{ru?states[item.state][0]:states[item.state][1]}</span></div>
     <p className="osa-evidence-description">{item.description||tr('Описание отсутствует.','No description supplied.')}</p>
     <div className="osa-evidence-source">{item.sourceUrl&&<a href={item.sourceUrl} rel="noopener noreferrer" target="_blank"><ArrowUpRight size={15}/>{tr('Заявленная ссылка','Declared URL')}</a>}{item.declaredSha256&&<div><strong>DECLARED SHA-256</strong><code>{item.declaredSha256}</code></div>}{!item.sourceUrl&&!item.declaredSha256&&<span>{tr('Источник ещё не указан.','Source not yet supplied.')}</span>}</div>
     <div className="osa-evidence-actions">
      {canEdit&&(item.state==='draft'||item.state==='needs_changes')&&(item.author===username||role==='owner')&&<>
       <button disabled={busy} type="button" onClick={()=>edit(item)}><FilePlus2 size={16}/>{tr('Изменить черновик','Edit draft')}</button>
       <button disabled={busy||!(item.sourceUrl||item.declaredSha256)} type="button" onClick={()=>void submit(item)}><UploadCloud size={16}/>{tr('Запросить проверку','Request review')}</button>
      </>}
      {canEdit&&item.state==='review_requested'&&item.author!==username&&<button disabled={busy} type="button" onClick={()=>{setReviewing({id:item.id,version:item.version});setReviewNote('');setVerdict('needs_changes')}}><FileCheck2 size={17}/>{tr('Рассмотреть','Review entry')}</button>}
      {item.state==='review_requested'&&item.author===username&&<span>{tr('Самопроверка запрещена. Требуется другой участник.','Self-review is blocked. Another authorized person must review.')}</span>}
     </div>
     {reviewing?.id===item.id&&<form className="osa-evidence-review-form" onSubmit={e=>void review(e)}>
      <div><h5>{tr('Внутреннее заключение','Internal review decision')}</h5><button type="button" aria-label={tr('Закрыть','Close')} onClick={()=>setReviewing(null)}><X size={17}/></button></div>
      <p>{tr('Это оценка записи коллегой, не независимая экспертиза права или подлинности файла.','A peer reviews record metadata, not independently certifies the file or the legal rights.')}</p>
      <label>{tr('Решение','Decision')}<select value={verdict} onChange={e=>setVerdict(e.target.value as typeof verdict)}><option value="needs_changes">{tr('Вернуть на доработку','Request changes')}</option><option value="internally_reviewed">{tr('Внутренне рассмотрено','Internally reviewed')}</option></select></label>
      <label>{tr('Обоснование (20–1000 символов)','Reason (20–1000 characters)')}<textarea minLength={20} maxLength={1000} rows={3} required value={reviewNote} onChange={e=>setReviewNote(e.target.value)}/></label>
      <button type="submit" disabled={busy}><Check size={16}/>{tr('Сохранить заключение','Save review')}</button>
     </form>}
     {item.reviews.length>0&&<details className="osa-evidence-review-history"><summary><FileClock size={15}/>{tr('История рассмотрения','Review history')} · {item.reviews.length}</summary><div>{item.reviews.map(r=><div key={r.id}><strong>{r.reviewer} · v{r.itemVersion} · {ru?states[r.verdict][0]:states[r.verdict][1]}</strong><small>{r.createdAt}</small><p>{r.note}</p></div>)}</div></details>}
    </article>)}
   </div>
   {canEdit&&<form className="osa-evidence-create" id="osa-evidence-create" onSubmit={e=>void save(e)}>
     <div className="osa-evidence-form-title"><FilePlus2 size={24}/><div><p className="osa-studio-eyebrow">SERVER / METADATA ONLY</p><h4>{editing?tr('Изменить запись','Update metadata record'):tr('Новый производственный источник','New production evidence record')}</h4></div></div>
     <p>{tr('Не загружайте конфиденциальные документы, токены или персональные данные. Здесь сохраняются только текстовые реквизиты.','Do not enter confidential documents, tokens or personal data. Only text metadata is stored here.')}</p>
     <div className="osa-evidence-form-grid"><label>{tr('Сцена','Scene')}<select value={scenes.includes(draft.sceneId)?draft.sceneId:scenes[0]} onChange={e=>setDraft({...draft,sceneId:e.target.value})}>{scenes.map(s=><option key={s}>{s}</option>)}</select></label><label>{tr('Категория','Category')}<select value={draft.category} onChange={e=>setDraft({...draft,category:e.target.value as Category})}>{CATEGORIES.map(c=><option key={c} value={c}>{ru?categories[c][0]:categories[c][1]}</option>)}</select></label></div>
     <label>{tr('Название записи','Record title')}<input required minLength={3} maxLength={140} value={draft.title} onChange={e=>setDraft({...draft,title:e.target.value})}/></label>
     <label>{tr('Описание и ограничения','Description and limitations')}<textarea rows={3} maxLength={1000} value={draft.description} onChange={e=>setDraft({...draft,description:e.target.value})}/></label>
     <label>{tr('HTTPS-ссылка (необязательно)','HTTPS source URL (optional)')}<input type="url" pattern="https://.*" maxLength={800} placeholder="https://example.org/document" value={draft.sourceUrl} onChange={e=>setDraft({...draft,sourceUrl:e.target.value})}/></label>
     <label>{tr('Объявленная SHA-256 (не проверяется сервером)','User-declared SHA-256 (not checked against a file)')}<input pattern="[a-fA-F0-9]{64}" maxLength={64} placeholder={tr('64 шестнадцатеричных символа','64 hexadecimal characters')} value={draft.declaredSha256} onChange={e=>setDraft({...draft,declaredSha256:e.target.value})}/></label>
     <div className="osa-evidence-form-actions"><button type="submit" disabled={busy||response.evidence.length>=80&&!editing}><Check size={16}/>{editing?tr('Сохранить новую версию','Save new version'):tr('Создать черновик','Create draft')}</button>{editing&&<button type="button" onClick={()=>{setEditing(null);setDraft(empty(filmId))}}><RotateCcw size={16}/>{tr('Отменить изменение','Cancel editing')}</button>}</div>
   </form>}
  </>}
  {error&&<p className="osa-evidence-error" role="alert"><ShieldAlert size={17}/>{error}</p>}
  {notice&&<p className="osa-evidence-notice" role="status"><ShieldCheck size={17}/>{notice}</p>}
  <div className="osa-evidence-footer"><LockKeyhole size={18}/><span>{tr('Доступен только членам данного кинопространства. Внутреннее рассмотрение не подтверждает юридические права, отснятые сцены, существование MP4 или разрешённый показ.','Accessible to members of this film workspace only. Internal peer review does not verify legal rights, filming, MP4 existence or authorized playback.')}</span><Globe2 size={18}/></div>
 </section>
}
