/** OSA CINEMA V60. Immutable publication facts and editable *local planning* are separate domains.
 * No browser note may authorize film distribution, rights clearance or public media.
 */
export type DistributionProjectId = 'zero-window' | 'threshold'
export type PublicationEvidenceState = 'verified' | 'pending' | 'blocked'
export type ReviewState = 'not_started' | 'preparing' | 'review_requested'
export const DISTRIBUTION_PROJECTS: readonly DistributionProjectId[] = ['zero-window','threshold']
export const RELEASE_REVIEW_STATES: readonly ReviewState[] = ['not_started','preparing','review_requested']
export const RELEASE_NOTES_SCHEMA = 'OSA_CINEMA_DISTRIBUTION_NOTES_V1'
export const RELEASE_NOTES_KEY = 'osa-cinema-release-review-v1'
export const RELEASE_NOTES_EVENT = 'osa-cinema-release-review-changed'
export const MAX_RELEASE_BACKUP_BYTES = 32 * 1024
export type ReleaseGate = {
  id:string;projectId:DistributionProjectId;nameRu:string;nameEn:string;
  descriptionRu:string;descriptionEn:string;evidence:PublicationEvidenceState;
}
export type ReleaseNote = {gateId:string;status:ReviewState;note:string;updatedAt:string}
export type ReleaseNotes = {projectId:DistributionProjectId;items:ReleaseNote[]}
export const releaseGates:readonly ReleaseGate[] = [
  {id:'zw-script',projectId:'zero-window',nameRu:'Сценарная разработка',nameEn:'Screenplay development',descriptionRu:'Материалы V51/V52 существуют; это не подтверждение съёмки.',descriptionEn:'V51/V52 creative materials exist. This does not attest to filming.',evidence:'verified'},
  {id:'zw-shotplan',projectId:'zero-window',nameRu:'План 13 сцен и 78 кадров',nameEn:'13-scene, 78-shot plan',descriptionRu:'Подтверждён производственный план; снято 0 актёрских сцен.',descriptionEn:'The production plan exists; zero actor scenes are filmed.',evidence:'verified'},
  {id:'zw-casting',projectId:'zero-window',nameRu:'Кастинг и актёрская читка',nameEn:'Casting and table read',descriptionRu:'Нужна подтверждённая читка и пробная съёмка.',descriptionEn:'An independently recorded table read and filmed test remain required.',evidence:'pending'},
  {id:'zw-safety',projectId:'zero-window',nameRu:'Безопасность площадки',nameEn:'On-set safety',descriptionRu:'В акте V53 безопасность не утверждена.',descriptionEn:'The V53 record has no on-set safety clearance.',evidence:'blocked'},
  {id:'zw-rights',projectId:'zero-window',nameRu:'Независимая проверка прав',nameEn:'Independent rights clearance',descriptionRu:'Самостоятельная декларация владельца недостаточна.',descriptionEn:'Owner attestation does not constitute independent clearance.',evidence:'pending'},
  {id:'zw-filming',projectId:'zero-window',nameRu:'Подтверждённые съёмки',nameEn:'Verified photography',descriptionRu:'Снято 0 из 13 запланированных сцен.',descriptionEn:'Zero of thirteen planned scenes are filmed.',evidence:'blocked'},
  {id:'zw-post',projectId:'zero-window',nameRu:'Монтаж, звук и мастер',nameEn:'Picture, sound and master',descriptionRu:'Готовый фильм и финальный мастер отсутствуют.',descriptionEn:'No finished short film or final picture master exists.',evidence:'blocked'},
  {id:'zw-web',projectId:'zero-window',nameRu:'Проверенное публичное воспроизведение',nameEn:'Verified public playback',descriptionRu:'Публичный MP4 и проверенный HTTPS-показ отсутствуют.',descriptionEn:'No verified public movie playback or hosted film master.',evidence:'blocked'},
  {id:'th-masters',projectId:'threshold',nameRu:'Локальные концепт-мастера',nameEn:'Local concept masters',descriptionRu:'Четыре владельческих RU/EN 720p/1080p мастера проверены декодированием.',descriptionEn:'Four owner-local RU/EN 720p/1080p masters were decoded.',evidence:'verified'},
  {id:'th-subtitles',projectId:'threshold',nameRu:'Двуязычные материалы',nameEn:'Bilingual concept assets',descriptionRu:'Зафиксированы 2 дорожки субтитров и титры.',descriptionEn:'Two subtitle tracks and title graphics are recorded.',evidence:'verified'},
  {id:'th-rights',projectId:'threshold',nameRu:'Независимая проверка прав',nameEn:'Independent rights clearance',descriptionRu:'Декларация владельца не подтверждена независимым аудитом.',descriptionEn:'Rights are owner-attested and not independently cleared.',evidence:'pending'},
  {id:'th-https',projectId:'threshold',nameRu:'Публичная доставка HTTPS',nameEn:'Public HTTPS media delivery',descriptionRu:'Воспроизведение реальных файлов на публичном адресе не подтверждено.',descriptionEn:'Real public HTTPS video playback has not been verified.',evidence:'blocked'},
  {id:'th-qa',projectId:'threshold',nameRu:'Независимая приёмка показа',nameEn:'Independent screening acceptance',descriptionRu:'Потребуется реальная браузерная проверка публикации и прав.',descriptionEn:'Independent browser delivery and rights verification remain required.',evidence:'blocked'},
]
const projects=new Set<string>(DISTRIBUTION_PROJECTS)
const reviewStates=new Set<string>(RELEASE_REVIEW_STATES)
const gateIdByProject=new Map(DISTRIBUTION_PROJECTS.map(id=>[id,new Set(releaseGates.filter(g=>g.projectId===id).map(g=>g.id))]))
function byteCount(text:string){return new TextEncoder().encode(text).byteLength}
const iso=(v:unknown)=>typeof v==='string'&&/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(v)&&Number.isFinite(Date.parse(v))
export function validateReleaseNotes(value:unknown):ReleaseNotes|null{
  if(!value||typeof value!=='object'||Array.isArray(value))return null
  const record=value as Record<string,unknown>
  if(!projects.has(String(record.projectId))||!Array.isArray(record.items)||record.items.length>13)return null
  const projectId=record.projectId as DistributionProjectId
  const allowed=gateIdByProject.get(projectId)
  const seen=new Set<string>()
  const items:ReleaseNote[]=[]
  for(const raw of record.items){
    if(!raw||typeof raw!=='object'||Array.isArray(raw))return null
    const item=raw as Record<string,unknown>
    if(typeof item.gateId!=='string'||!allowed?.has(item.gateId)||seen.has(item.gateId)||
       !reviewStates.has(String(item.status))||typeof item.note!=='string'||item.note.length>500||
       /[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(item.note)||!iso(item.updatedAt))return null
    seen.add(item.gateId)
    items.push({gateId:item.gateId,status:item.status as ReviewState,note:item.note,updatedAt:item.updatedAt as string})
  }
  return {projectId,items}
}
function storage():Storage|null {try{return typeof window==='undefined'?null:window.localStorage}catch{return null}}
export function readReleaseNotes(projectId:DistributionProjectId):ReleaseNotes{
  const empty:ReleaseNotes={projectId,items:[]}
  if(!projects.has(projectId))return empty
  try{
    const value=storage()?.getItem(RELEASE_NOTES_KEY+'-'+projectId)
    if(!value||byteCount(value)>MAX_RELEASE_BACKUP_BYTES)return empty
    return validateReleaseNotes(JSON.parse(value) as unknown)??empty
  }catch{return empty}
}
export function saveReleaseNotes(data:ReleaseNotes):boolean{
  const validated=validateReleaseNotes(data),store=storage()
  if(!validated||!store)return false
  const text=JSON.stringify(validated)
  if(byteCount(text)>MAX_RELEASE_BACKUP_BYTES)return false
  try{
    store.setItem(RELEASE_NOTES_KEY+'-'+validated.projectId,text)
    window.dispatchEvent(new CustomEvent(RELEASE_NOTES_EVENT,{detail:validated.projectId}))
    return true
  }catch{return false}
}
export function subscribeReleaseNotes(projectId:DistributionProjectId,cb:()=>void):()=>void{
  if(typeof window==='undefined')return()=>undefined
  const onLocal=(e:Event)=>{if((e as CustomEvent).detail===projectId)cb()}
  const onStorage=(e:StorageEvent)=>{if(e.key===null||e.key===RELEASE_NOTES_KEY+'-'+projectId)cb()}
  window.addEventListener(RELEASE_NOTES_EVENT,onLocal);window.addEventListener('storage',onStorage)
  return()=>{window.removeEventListener(RELEASE_NOTES_EVENT,onLocal);window.removeEventListener('storage',onStorage)}
}
export function updateReleaseNote(data:ReleaseNotes,gateId:string,status:ReviewState,note:string,updatedAt:string=new Date().toISOString()):ReleaseNotes|null{
  if(!reviewStates.has(status)||typeof note!=='string'||note.length>500||!iso(updatedAt))return null
  if(!gateIdByProject.get(data.projectId)?.has(gateId))return null
  const other=data.items.filter(i=>i.gateId!==gateId)
  const next:ReleaseNotes={projectId:data.projectId,items:[...other,{gateId,status,note,updatedAt}]}
  return validateReleaseNotes(next)
}
export function publicReleaseDecision(projectId:DistributionProjectId){
  const gates=releaseGates.filter(x=>x.projectId===projectId)
  return {
    projectId,releaseAuthorized:false,publicVideoUrl:null,readyForRelease:false,
    verified:gates.filter(x=>x.evidence==='verified').length,
    pending:gates.filter(x=>x.evidence==='pending').length,
    blocked:gates.filter(x=>x.evidence==='blocked').length,
    gates
  } as const
}
export function exportReleaseNotes(data:ReleaseNotes,at:string=new Date().toISOString()):string{
  const valid=validateReleaseNotes(data)
  if(!valid||!iso(at))throw Error('Invalid release planning notes')
  const text=JSON.stringify({
    schema:RELEASE_NOTES_SCHEMA,version:1,generatedAt:at,storage:'local_device_only',
    ownerPlanningOnly:true,releaseAuthorized:false,publicVideoUrl:null,...valid
  },null,2)+'\n'
  if(byteCount(text)>MAX_RELEASE_BACKUP_BYTES)throw Error('Release backup too large')
  return text
}
export function importReleaseNotes(text:string):ReleaseNotes|null{
  if(typeof text!=='string'||text.length<1||byteCount(text)>MAX_RELEASE_BACKUP_BYTES)return null
  try{
    const x:unknown=JSON.parse(text)
    if(!x||typeof x!=='object'||Array.isArray(x))return null
    const r=x as Record<string,unknown>
    if(r.schema!==RELEASE_NOTES_SCHEMA||r.version!==1||!iso(r.generatedAt)||
       r.storage!=='local_device_only'||r.ownerPlanningOnly!==true||
       r.releaseAuthorized!==false||r.publicVideoUrl!==null)return null
    return validateReleaseNotes(r)
  }catch{return null}
}
