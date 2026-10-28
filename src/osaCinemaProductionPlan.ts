/** Owner-local production planning for ZERO WINDOW.
 * This is NOT evidence of filmed scenes, cleared rights, payment or release approval.
 */
export const PRODUCTION_PROJECT_ID = 'zero-window'
export const PRODUCTION_SCHEMA = 'OSA_CINEMA_PRODUCTION_DRAFT_V1'
export const PRODUCTION_STORAGE_KEY = 'osa-cinema-production-plan-v1'
export const PRODUCTION_EVENT = 'osa-cinema-production-plan-changed'
export const MAX_PRODUCTION_IMPORT_BYTES = 64 * 1024
export const MAX_PRODUCTION_TASKS = 100
export const VERIFIED_ACTOR_SCENES_FILMED = 0
export const PROPOSED_SHOTS = 78
export const TARGET_FILM_SECONDS = 1080
export const PLANNED_SCENES = 13
export const PRODUCTION_SCENE_IDS: readonly string[] = Array.from({ length: PLANNED_SCENES },(_,i)=>'S'+String(i+1).padStart(2,'0'))
const sceneIds = new Set(PRODUCTION_SCENE_IDS)
export const PRODUCTION_CATEGORIES = ['script','casting','location','camera','sound','rights','safety','post'] as const
export type ProductionCategory = typeof PRODUCTION_CATEGORIES[number]
export const PRODUCTION_STATES = ['planned','in_progress','blocked','ready_for_review'] as const
export type ProductionState = typeof PRODUCTION_STATES[number]
export type ProductionTask = {
  id:string
  sceneId:string
  category:ProductionCategory
  status:ProductionState
  title:string
  owner:string
  dueDate:string
  notes:string
  createdAt:string
  updatedAt:string
}
export type ProductionStatistics = {
  total:number
  readyForReview:number
  inProgress:number
  blocked:number
  planned:number
  verifiedActorScenesFilmed:0
  publicReleaseApproved:false
}
const categories = new Set<string>(PRODUCTION_CATEGORIES)
const statuses = new Set<string>(PRODUCTION_STATES)
const asString = (v:unknown,max:number) => typeof v==='string' && v.length<=max && !/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(v)
const validTimestamp = (v:unknown) => typeof v==='string' && v.length<=40 && /^\d{4}-\d{2}-\d{2}T/.test(v) && Number.isFinite(Date.parse(v))
const validDate = (v:unknown) => v==='' || (typeof v==='string' && /^\d{4}-\d{2}-\d{2}$/.test(v) && !Number.isNaN(Date.parse(v)) && new Date(v).toISOString().slice(0,10)===v)
function cleanTask(input:unknown):ProductionTask|null {
  if (!input || typeof input!=='object' || Array.isArray(input)) return null
  const t=input as Record<string,unknown>
  if(typeof t.id!=='string'||!/^t-[a-z0-9-]{8,64}$/.test(t.id)||!sceneIds.has(String(t.sceneId))||
     !categories.has(String(t.category))||!statuses.has(String(t.status))||
     !asString(t.title,120)||!(t.title as string).trim()||
     !asString(t.owner,80)||!asString(t.notes,600)||!validDate(t.dueDate)||
     !validTimestamp(t.createdAt)||!validTimestamp(t.updatedAt)) return null
  return {
    id:t.id,sceneId:t.sceneId as string,category:t.category as ProductionCategory,
    status:t.status as ProductionState,title:(t.title as string).trim(),
    owner:(t.owner as string).trim(),dueDate:t.dueDate as string,notes:t.notes as string,
    createdAt:t.createdAt as string,updatedAt:t.updatedAt as string
  }
}
export function validateProductionPlan(input:unknown):ProductionTask[]|null {
  if(!Array.isArray(input)||input.length>MAX_PRODUCTION_TASKS) return null
  const output:ProductionTask[]=[]
  const ids=new Set<string>()
  for(const value of input){
    const t=cleanTask(value)
    if(!t||ids.has(t.id))return null
    ids.add(t.id)
    output.push(t)
  }
  return output
}
function storage():Storage|null {
  try{return typeof window==='undefined'?null:window.localStorage}catch{return null}
}
export function readProductionPlan():ProductionTask[]{
  try{
    const raw=storage()?.getItem(PRODUCTION_STORAGE_KEY)
    if(!raw||raw.length>MAX_PRODUCTION_IMPORT_BYTES) return []
    return validateProductionPlan(JSON.parse(raw) as unknown)??[]
  }catch{return []}
}
export function saveProductionPlan(input:unknown):boolean{
  const tasks=validateProductionPlan(input)
  const store=storage()
  if(!tasks||!store)return false
  const serialized=JSON.stringify(tasks)
  if(serialized.length>MAX_PRODUCTION_IMPORT_BYTES)return false
  try{
    store.setItem(PRODUCTION_STORAGE_KEY,serialized)
    window.dispatchEvent(new Event(PRODUCTION_EVENT))
    return true
  }catch{return false}
}
export function subscribeProductionPlan(callback:()=>void):()=>void{
  if(typeof window==='undefined')return()=>undefined
  const storageChanged=(e:StorageEvent)=>{
    if(e.key===PRODUCTION_STORAGE_KEY||e.key===null)callback()
  }
  window.addEventListener(PRODUCTION_EVENT,callback)
  window.addEventListener('storage',storageChanged)
  return()=>{
    window.removeEventListener(PRODUCTION_EVENT,callback)
    window.removeEventListener('storage',storageChanged)
  }
}
export function productionStatistics(input:unknown):ProductionStatistics{
  const items=validateProductionPlan(input)??[]
  return {
    total:items.length,
    planned:items.filter(x=>x.status==='planned').length,
    inProgress:items.filter(x=>x.status==='in_progress').length,
    blocked:items.filter(x=>x.status==='blocked').length,
    readyForReview:items.filter(x=>x.status==='ready_for_review').length,
    verifiedActorScenesFilmed:VERIFIED_ACTOR_SCENES_FILMED,
    publicReleaseApproved:false
  }
}
export function exportProductionBackup(input:unknown,generatedAt:string=new Date().toISOString()):string{
  const tasks=validateProductionPlan(input)
  if(!tasks||!validTimestamp(generatedAt))throw Error('Invalid production draft')
  return JSON.stringify({
    schema:PRODUCTION_SCHEMA,version:1,project:PRODUCTION_PROJECT_ID,storage:'local_device_only',
    dataIsNotFilmingEvidence:true,publicReleaseAuthorized:false,
    generatedAt,tasks
  },null,2)+'\n'
}
export function parseProductionBackup(source:string):ProductionTask[]|null{
  if(typeof source!=='string'||source.length<1||source.length>MAX_PRODUCTION_IMPORT_BYTES)return null
  try{
    const v:unknown=JSON.parse(source)
    if(!v||typeof v!=='object'||Array.isArray(v))return null
    const x=v as Record<string,unknown>
    if(x.schema!==PRODUCTION_SCHEMA||x.version!==1||x.project!==PRODUCTION_PROJECT_ID||
       x.storage!=='local_device_only'||x.dataIsNotFilmingEvidence!==true||
       x.publicReleaseAuthorized!==false||!validTimestamp(x.generatedAt))return null
    return validateProductionPlan(x.tasks)
  }catch{return null}
}
function csvCell(value:string):string {
  // Spreadsheet formula injection remains unsafe even if a CSV is local-only.
  const escaped=/^\s*[=+@\-\t\r]/.test(value)?"'"+value:value
  return '"'+escaped.replaceAll('"','""')+'"'
}
export function exportProductionCsv(input:unknown):string{
  const tasks=validateProductionPlan(input)
  if(!tasks)throw Error('Invalid production draft')
  const columns=['scene_id','department','planning_status','task_title','owner','planned_date','notes','created_at','updated_at']
  const lines=[columns.map(csvCell).join(',')]
  for(const t of tasks)lines.push([t.sceneId,t.category,t.status,t.title,t.owner,t.dueDate,t.notes,t.createdAt,t.updatedAt].map(csvCell).join(','))
  return '\uFEFF'+lines.join('\r\n')+'\r\n'
}
export function createProductionTask(params:{
  sceneId:string;title:string;category:ProductionCategory;owner:string;dueDate:string;notes:string
},now:string=new Date().toISOString(),id:string='t-'+Date.now().toString(36)+'-'+Math.random().toString(36).slice(2,10)):ProductionTask|null{
  return cleanTask({...params,id,status:'planned',createdAt:now,updatedAt:now})
}
export function updateProductionTask(tasks:ProductionTask[],id:string,status:ProductionState,now:string=new Date().toISOString()):ProductionTask[]|null {
  if(!statuses.has(status)||!validTimestamp(now))return null
  const next=tasks.map(t=>t.id===id?{...t,status,updatedAt:now}:t)
  return next.some(t=>t.id===id)?validateProductionPlan(next):null
}
