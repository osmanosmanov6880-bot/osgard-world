export const BRAND_EVENT_KEY='osgard:design-events:v1'
export const BRAND_EVENTS=['course_started','lecture_opened','game_launch_clicked','brief_exported','contact_opened'] as const
export type BrandEvent=typeof BRAND_EVENTS[number]
export type BrandEventRecord={event:BrandEvent;slug:string;at:string}
export type BrandEventRead={status:'ok'|'invalid'|'unavailable';events:BrandEventRecord[]}
function parseEvents(raw:string|null):BrandEventRead{
 if(raw===null)return {status:'ok',events:[]}
 if(raw.length>100000)return {status:'invalid',events:[]}
 let parsed:unknown;try{parsed=JSON.parse(raw)}catch{return {status:'invalid',events:[]}}
 if(!Array.isArray(parsed))return {status:'invalid',events:[]}
 const events=parsed.filter(p=>p&&BRAND_EVENTS.includes(p.event)&&typeof p.slug==='string'&&/^[A-Za-z0-9/_-]{0,80}$/.test(p.slug)&&typeof p.at==='string'&&p.at.length<=128&&Number.isFinite(Date.parse(p.at))).slice(-200).map(p=>({event:p.event as BrandEvent,slug:p.slug,at:p.at}))
 return {status:'ok',events}
}
/** A bounded local observation log. No identifiers, free text or network delivery. */
export function readBrandEventState():BrandEventRead{try{return parseEvents(localStorage.getItem(BRAND_EVENT_KEY))}catch{return {status:'unavailable',events:[]}}}
export function readBrandEvents():BrandEventRecord[]{return readBrandEventState().events}
export function recordBrandEvent(event:BrandEvent,slug=''):boolean{
 if(!BRAND_EVENTS.includes(event)||!/^[A-Za-z0-9/_-]{0,80}$/.test(slug))return false
 try{const events=parseEvents(localStorage.getItem(BRAND_EVENT_KEY)).events.slice(-199);events.push({event,slug,at:new Date().toISOString()});localStorage.setItem(BRAND_EVENT_KEY,JSON.stringify(events));return true}catch{return false}
}
export function clearBrandEvents():boolean{try{localStorage.removeItem(BRAND_EVENT_KEY);return true}catch{return false}}
