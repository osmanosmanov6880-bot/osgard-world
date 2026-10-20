/* INHERIT R3: research participation requires explicit player consent.
   Pure, bounded event model. Nothing in this module performs storage, IO or telemetry. */
(function(root){
'use strict';
const KEY='inherit:pilot-research:v1';
const VERSION=1;
const MAX_EVENTS=512;
const PRICE_OPTIONS=Object.freeze([0,199,499,799]);
const REASONS=Object.freeze(['creation','story','sharing','visual','not_interested']);
const TYPES=Object.freeze(['session_opened','trace_placed','first_trace_placed','generation_advanced_observed','journal_opened','founder_preview_opened','cosmetic_selected','survey_submitted']);
const TYPESET=new Set(TYPES);
function iso(value){
 if(typeof value!=='string'||!/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,3})?Z$/.test(value))return null;
 const parsed=new Date(value);
 return Number.isFinite(parsed.getTime())&&parsed.toISOString().slice(0,19)===value.slice(0,19)?parsed.toISOString():null;
}
function date(value){
 if(typeof value!=='string'||!/^\d{4}-\d\d-\d\d$/.test(value))return null;
 const parsed=new Date(value+'T00:00:00.000Z');
 return Number.isFinite(parsed.getTime())&&parsed.toISOString().slice(0,10)===value?value:null;
}
function participantId(value){return typeof value==='string'&&/^[a-z0-9-]{20,60}$/i.test(value)?value:null}
function integer(v,min,max){return Number.isSafeInteger(v)&&v>=min&&v<=max?v:null}
function cleanPayload(type,payload){
 const p=payload&&typeof payload==='object'&&!Array.isArray(payload)?payload:{};
 if(type==='survey_submitted'){
   const clarity=integer(p.clarity,1,5),returnIntent=integer(p.returnIntent,1,5),meaning=integer(p.meaning,1,5),
     priceCents=integer(p.priceCents,0,10000);
   if(clarity===null||returnIntent===null||meaning===null||!REASONS.includes(p.reason)||!PRICE_OPTIONS.includes(priceCents))return null;
   return {clarity,returnIntent,meaning,reason:p.reason,priceCents};
 }
 if(type==='generation_advanced_observed'){
   const count=integer(p.generation,0,100000);
   return count===null?null:{generation:count};
 }
 if(type==='trace_placed'){
   const count=integer(p.pendingCount,1,100);
   return count===null?null:{pendingCount:count};
 }
 if(type==='cosmetic_selected'){
   return ['night','fern','aurora','copper'].includes(p.skin)?{skin:p.skin}:null;
 }
 return {};
}
function cleanEvent(raw){
 if(!raw||typeof raw!=='object'||!TYPESET.has(raw.type))return null;
 const at=iso(raw.at),seq=integer(raw.seq,1,10000000),payload=cleanPayload(raw.type,raw.data);
 return at&&seq!==null&&payload?{seq,at,type:raw.type,data:payload}:null;
}
function normalize(raw){
 if(!raw||typeof raw!=='object'||raw.schema!==VERSION||raw.consent!==true)return null;
 const id=participantId(raw.participantId),consentedAt=iso(raw.consentedAt);
 if(!id||!consentedAt||!Array.isArray(raw.events)||raw.events.length>MAX_EVENTS)return null;
 const events=[];let previous=0;
 for(const event of raw.events){
  const clean=cleanEvent(event);
  if(!clean||clean.seq<=previous||clean.at<consentedAt)return null;
  previous=clean.seq;events.push(clean);
 }
 const lastSeq=integer(raw.lastSeq,0,10000000);
 if(lastSeq===null||lastSeq<previous)return null;
 return {schema:VERSION,consent:true,participantId:id,consentedAt,lastSeq,events};
}
function create(id,at){
 if(!participantId(id)||!iso(at))return null;
 return {schema:VERSION,consent:true,participantId:id,consentedAt:iso(at),lastSeq:0,events:[]};
}
function record(state,type,at,data){
 const old=normalize(state),now=iso(at);
 if(!old||!now||now<old.consentedAt||!TYPESET.has(type))return null;
 const payload=cleanPayload(type,data);
 if(!payload||old.lastSeq>=10000000)return null;
 if(type==='first_trace_placed'&&old.events.some(e=>e.type===type))return old;
 const event={seq:old.lastSeq+1,at:now,type,data:payload};
 const next=[...old.events,event];
 if(next.length>MAX_EVENTS){
   // Keep the earliest consented session, recent actions, and monotone sequence.
   const first=next.find(e=>e.type==='session_opened')||next[0];
   const tail=next.slice(-(MAX_EVENTS-1)).filter(e=>e.seq!==first.seq);
   next.splice(0,next.length,first,...tail.slice(-(MAX_EVENTS-1)));
 }
 return {...old,lastSeq:event.seq,events:next};
}
function dayShift(day,amount){
 const time=Date.parse(day+'T00:00:00.000Z');
 if(!Number.isFinite(time))return null;
 return new Date(time+amount*86400000).toISOString().slice(0,10);
}
function summarize(raw,asOf){
 const state=normalize(raw),today=date(asOf);
 if(!state||!today)return null;
 const first=state.consentedAt.slice(0,10);
 const sessions=state.events.filter(e=>e.type==='session_opened');
 const visitDays=[...new Set(sessions.map(e=>e.at.slice(0,10)))].sort();
 const d1Day=dayShift(first,1),d7Day=dayShift(first,7);
 const eligibility=d=>today>=d?{eligible:true,returned:visitDays.includes(d)}:{eligible:false,returned:null};
 const counts=Object.fromEntries(TYPES.map(type=>[type,state.events.filter(e=>e.type===type).length]));
 const surveys=state.events.filter(e=>e.type==='survey_submitted');
 const latestSurvey=surveys.length?surveys[surveys.length-1].data:null;
 return {participantId:state.participantId,firstDay:first,days:visitDays.length,sessions:sessions.length,
  counts,firstTrace:counts.first_trace_placed>0,everPlaced:counts.trace_placed>0,advanced:counts.generation_advanced_observed>0,
  d1:eligibility(d1Day),d7:eligibility(d7Day),survey:latestSurvey,
  bounded:state.events.length===MAX_EVENTS};
}
function exportConsent(state,at){
 const record=normalize(state),generatedAt=iso(at);
 if(!record||!generatedAt)return null;
 return {product:'INHERIT',kind:'voluntary-pilot-export',notice:'Explicitly exported by the participant. No automatic server transmission.',
  generatedAt,...record};
}
const api=Object.freeze({KEY,VERSION,MAX_EVENTS,PRICE_OPTIONS,REASONS,TYPES,create,normalize,record,summarize,exportConsent,iso,date,dayShift});
root.InheritResearchCore=api;
if(typeof module!=='undefined'&&module.exports)module.exports=api;
})(typeof window==='object'?window:globalThis);
