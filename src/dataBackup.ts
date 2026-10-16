import { parseProject } from './osaProjects.ts'
import { parseWorkspace } from './osaWorkspace.ts'
import { parseExperiments } from './osaExperiments.ts'
import { parsePlayCollection } from './playCollection.ts'
import { OSA_LESSON_SLUGS } from './osaLessonRegistry.ts'
export const BACKUP_AREAS = [
 {key:'osgard-osa-learning-progress-v1',label:'Прогресс уроков и OSA Original'},
 {key:'osa6-assessment-attempts-v1',label:'История самопроверки'},
 {key:'osa:project:v1',label:'Черновик проекта'},
 {key:'osa:workspace:v1',label:'Мастерская и версии проектов'},
 {key:'osa:experiments:v1',label:'Журнал экспериментов'},
 {key:'osgard:play-collection:v1',label:'Избранное и недавние миры PLAY'},
] as const
export type BackupKey=typeof BACKUP_AREAS[number]['key']
export type Backup={app:'OSGARD';version:1;exportedAt:string;data:Partial<Record<BackupKey,string>>}
export type BackupStorage={getItem:(key:string)=>string|null;setItem:(key:string,value:string)=>void;removeItem:(key:string)=>void}
const ids=['vector-zero','time','swarm','inherit','remix','null-shift']
const validDate=(v:unknown)=>typeof v==='string'&&Number.isFinite(Date.parse(v))
export function validateArea(key:BackupKey,raw:string):string{
 if(!BACKUP_AREAS.some(a=>a.key===key))throw Error('area')
 if(key==='osa:project:v1')return JSON.stringify(parseProject(raw))
 if(key==='osa:workspace:v1')return JSON.stringify(parseWorkspace(raw))
 if(key==='osa:experiments:v1')return JSON.stringify(parseExperiments(raw))
 if(key==='osgard:play-collection:v1')return JSON.stringify(parsePlayCollection(raw,ids))
 if(raw.length>100000)throw Error('size')
 const v=JSON.parse(raw)
 if(key==='osa6-assessment-attempts-v1'){
  if(!Array.isArray(v)||v.length>20)throw Error('attempts')
  return JSON.stringify(v.map(p=>{if(!p||!validDate(p.at)||!Number.isInteger(p.correct)||p.correct<0||p.correct>8||p.total!==8)throw Error('attempt');return {at:p.at,correct:p.correct,total:8}}))
 }
 if(!v||v.version!==1||!Array.isArray(v.lessonCompletions)||v.lessonCompletions.some((x:unknown)=>typeof x!=='string'||!(OSA_LESSON_SLUGS as readonly string[]).includes(x))||!(v.lastLessonSlug===null||(OSA_LESSON_SLUGS as readonly string[]).includes(v.lastLessonSlug))||!(v.updatedAt===null||validDate(v.updatedAt)))throw Error('progress')
 const c=v.cinema
 if(!c||!Number.isInteger(c.index)||c.index<0||c.index>7||!['ru','en'].includes(c.locale)||typeof c.completed!=='boolean'||!c.answers||typeof c.answers!=='object'||Array.isArray(c.answers)||!c.selfChecks||typeof c.selfChecks!=='object'||Array.isArray(c.selfChecks))throw Error('cinema')
 for(const [k,a]of Object.entries(c.answers)){const n=Number(k),limit=[3,0,3,0,3,3,3,0][n];if(!Number.isInteger(n)||n<0||n>7||String(n)!==k||!Number.isInteger(a)||Number(a)<0||Number(a)>=limit)throw Error('answer')}
 for(const [k,a]of Object.entries(c.selfChecks))if(!['0','1','2'].includes(k)||typeof a!=='boolean')throw Error('selfcheck')
 return JSON.stringify({version:1,lessonCompletions:[...new Set(v.lessonCompletions)],lastLessonSlug:v.lastLessonSlug,cinema:{index:c.index,answers:c.answers,locale:c.locale,completed:c.completed,selfChecks:c.selfChecks},updatedAt:v.updatedAt})
}
export function parseBackup(raw:string):Backup{
 if(raw.length>8*1024*1024||new TextEncoder().encode(raw).length>8*1024*1024)throw Error('size')
 const p=JSON.parse(raw)
 if(!p||p.app!=='OSGARD'||p.version!==1||!validDate(p.exportedAt)||!p.data||typeof p.data!=='object'||Array.isArray(p.data))throw Error('format')
 const data:Backup['data']={}
 for(const [key,value]of Object.entries(p.data)){
  if(!BACKUP_AREAS.some(a=>a.key===key)||typeof value!=='string')throw Error('area')
  data[key as BackupKey]=validateArea(key as BackupKey,value)
 }
 return {app:'OSGARD',version:1,exportedAt:p.exportedAt,data}
}
export function captureBackup(storage:BackupStorage,keys:readonly BackupKey[]):Backup{
 const data:Backup['data']={}
 for(const key of keys){const raw=storage.getItem(key);if(raw!==null)data[key]=validateArea(key,raw)}
 return parseBackup(JSON.stringify({app:'OSGARD',version:1,exportedAt:new Date().toISOString(),data}))
}
export function captureBaseline(storage:BackupStorage,keys:readonly BackupKey[]):Partial<Record<BackupKey,string|null>>{
 if(keys.some(key=>!BACKUP_AREAS.some(a=>a.key===key)))throw Error('area')
 return Object.fromEntries(keys.map(key=>[key,storage.getItem(key)]))
}
export function restoreBackup(storage:BackupStorage,backup:Backup,keys:readonly BackupKey[],baseline:Partial<Record<BackupKey,string|null>>):'restored'|'conflict'|'failed'|'partial'{
 const written:BackupKey[]=[];let next:Backup
 try{next=parseBackup(JSON.stringify(backup))}catch{return 'failed'}
 const selected=[...new Set(keys)].filter(k=>next.data[k]!==undefined)
 try{
  if(selected.some(k=>!(k in baseline)||storage.getItem(k)!==baseline[k]))return 'conflict'
  for(const key of selected){if(storage.getItem(key)!==baseline[key])throw Error('concurrent');storage.setItem(key,next.data[key]!);written.push(key)}
  return 'restored'
 }catch{
  let partial=false
  for(const key of written.reverse()){
   try{if(storage.getItem(key)!==next!.data[key]){partial=true;continue}const old=baseline[key];if(old===null)storage.removeItem(key);else if(typeof old==='string')storage.setItem(key,old);else partial=true}catch{partial=true}
  }
  return partial?'partial':'failed'
 }
}
