import assert from 'node:assert/strict'
import { captureBackup,captureBaseline,parseBackup,restoreBackup,validateArea } from '../src/dataBackup.ts'
import { emptyProject } from '../src/osaProjects.ts'
class MemoryStorage{data=new Map();getItem(k){return this.data.get(k)??null}setItem(k,v){this.data.set(k,v)}removeItem(k){this.data.delete(k)}}
const storage=new MemoryStorage(),key='osa:project:v1',other='osa:workspace:v1'
storage.setItem(key,JSON.stringify({...emptyProject(),title:'Original'}));storage.setItem('auth.token','SECRET')
const backup=captureBackup(storage,[key]);assert.equal(Object.keys(backup.data).length,1);assert.ok(!JSON.stringify(backup).includes('SECRET'))
assert.throws(()=>captureBackup(storage,['auth.token']));assert.throws(()=>parseBackup(JSON.stringify({...backup,data:{'auth.token':'SECRET'}})))
assert.throws(()=>parseBackup(JSON.stringify({...backup,data:{[key]:'{broken'}})))
assert.throws(()=>parseBackup(JSON.stringify({...backup,version:2})))
assert.throws(()=>validateArea('osgard-osa-learning-progress-v1','{"version":1,"lessonCompletions":["fake"]}'))
const current=captureBaseline(storage,[key]);backup.data[key]=JSON.stringify({...emptyProject(),title:'Imported'});assert.equal(restoreBackup(storage,backup,[key],current),'restored');assert.equal(JSON.parse(storage.getItem(key)).title,'Imported');assert.equal(storage.getItem('auth.token'),'SECRET')
assert.equal(restoreBackup(storage,backup,[key],current),'conflict')
const noOld=captureBaseline(storage,[other]);const extra={...backup,data:{[other]:JSON.stringify({version:1,items:[]})}};assert.equal(restoreBackup(storage,extra,[other],noOld),'restored')
const before=captureBaseline(storage,[key,other]);const both={...backup,data:{[key]:JSON.stringify({...emptyProject(),title:'New'}),[other]:JSON.stringify({version:1,items:[]})}}
let failed=false;const failOnce={getItem:k=>storage.getItem(k),removeItem:k=>storage.removeItem(k),setItem:(k,v)=>{if(k===other&&!failed){failed=true;throw Error('quota')}storage.setItem(k,v)}}
assert.equal(restoreBackup(failOnce,both,[key,other],before),'failed');assert.equal(storage.getItem(key),before[key])
let calls=0;const failRollback={getItem:k=>storage.getItem(k),removeItem:k=>storage.removeItem(k),setItem:(k,v)=>{calls++;if(calls>1)throw Error('blocked');storage.setItem(k,v)}}
assert.equal(restoreBackup(failRollback,both,[key,other],before),'partial')
const progress={version:1,lessonCompletions:['intelligence-and-imitation'],lastLessonSlug:'intelligence-and-imitation',cinema:{index:0,answers:{0:1},locale:'ru',completed:false,selfChecks:{0:true}},updatedAt:null}
assert.deepEqual(JSON.parse(validateArea('osgard-osa-learning-progress-v1',JSON.stringify(progress))),progress)
assert.throws(()=>validateArea('osgard-osa-learning-progress-v1',JSON.stringify({...progress,cinema:{...progress.cinema,answers:{1:0}}})))
console.log('Backup checks passed: allowlist, validation, restore, conflict, rollback and partial failure disclosure')
