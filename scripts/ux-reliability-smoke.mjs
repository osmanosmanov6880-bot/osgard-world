import assert from 'node:assert/strict'
import { readPlayFilters,playCatalogHref,playWorldHref,playReturnHref } from '../src/playFilters.ts'
import { brandBreadcrumbs,globalNavigationState } from '../src/brandNavigation.ts'
import { formatEnquiry,validateEnquiry } from '../src/projectEnquiry.ts'
import { BRAND_EVENT_KEY,recordBrandEvent,readBrandEventState,readBrandEvents,clearBrandEvents } from '../src/brandTelemetry.ts'
const genres=['Стратегия','Арена']
const filters=readPlayFilters('?q=TIME&genre=Стратегия&mode=solo&view=favorites',genres)
assert.equal(filters.query,'TIME');assert.equal(filters.genre,'Стратегия')
const world=playWorldHref('time',filters)
assert.equal(playReturnHref(new URL(world,'https://osgard.local').search,genres),playCatalogHref(filters))
for(const value of ['https://evil.example/play','//evil.example/play','javascript:alert(1)','/data','/play/world/time'])assert.equal(playReturnHref('?back='+encodeURIComponent(value),genres),'/play#catalog')
assert.deepEqual(readPlayFilters('?q='+('x'.repeat(100))+'&genre=Other&view=bad&mode=unknown',genres),{query:'x'.repeat(80),genre:'all',view:'all',mode:'all'})
assert.equal(globalNavigationState('/learning/project','intelligence','/intelligence'),'location')
assert.equal(globalNavigationState('/intelligence','intelligence','/intelligence'),'page')
assert.equal(globalNavigationState('/development/phantom','world','/'),undefined)
assert.equal(globalNavigationState('/development/phantom','world','/development'),'location')
assert.deepEqual(brandBreadcrumbs('/learning/project','intelligence').map(x=>x.label),['OSGARD','OSA Intelligence','Мой прогресс','Редактор проекта'])
assert.equal(brandBreadcrumbs('/','world').length,0)
assert.ok(validateEnquiry(' '.repeat(30),'')!==null)
assert.ok(validateEnquiry('a'.repeat(5001),'')!==null)
assert.ok(validateEnquiry('a'.repeat(30),'x'.repeat(251))!==null)
assert.throws(()=>formatEnquiry('short',''))
assert.ok(formatEnquiry('  Система для поиска и проверки учебных источников  ','').includes('Не указан'))
const values=new Map();globalThis.localStorage={getItem:k=>values.get(k)??null,setItem:(k,v)=>values.set(k,v),removeItem:k=>values.delete(k)}
for(let i=0;i<230;i++)assert.equal(recordBrandEvent('course_started','/learning/program'),true)
assert.equal(readBrandEvents().length,200)
assert.equal(recordBrandEvent('contact_opened','secret@example.com'),false)
values.set(BRAND_EVENT_KEY,JSON.stringify([{event:'contact_opened',slug:'',at:new Date().toISOString(),secret:'MUST_NOT_EXPORT'},{event:'invented',slug:'',at:new Date().toISOString()}]))
assert.equal(readBrandEvents().length,1);assert.ok(!JSON.stringify(readBrandEvents()).includes('MUST_NOT_EXPORT'))
values.set(BRAND_EVENT_KEY,'{broken');assert.equal(readBrandEventState().status,'invalid')
assert.equal(clearBrandEvents(),true);assert.equal(readBrandEvents().length,0)
globalThis.localStorage={getItem:()=>{throw Error('blocked')},setItem:()=>{throw Error('blocked')},removeItem:()=>{throw Error('blocked')}}
assert.equal(readBrandEventState().status,'unavailable');assert.equal(clearBrandEvents(),false);assert.equal(recordBrandEvent('course_started'),false)
console.log('UX checks passed: filter return URLs, safe back links, breadcrumb state, brief validation, bounded private events and failed deletion')
