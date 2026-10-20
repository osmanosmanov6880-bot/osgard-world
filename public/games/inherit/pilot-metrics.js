/* Operator-only aggregation of manually shared, consented INHERIT research exports.
   Never reads gameplay saves and never sends data to any server. */
import './research-core.js';
const core=globalThis.InheritResearchCore;
const clampRate=(n,d)=>d?Number((100*n/d).toFixed(1)):null;
function average(values){return values.length?Number((values.reduce((s,n)=>s+n,0)/values.length).toFixed(2)):null}
export function aggregate(exports,asOf){
 const date=core.date(asOf);
 if(!date)throw new Error('asOf must be a valid UTC YYYY-MM-DD date');
 const chosen=new Map();
 let rejected=0,duplicates=0;
 for(const raw of exports){
  const payload=raw&&raw.kind==='voluntary-pilot-export'&&raw.product==='INHERIT'?raw:null;
  const value=core.normalize(payload),capturedAt=core.iso(payload?.generatedAt);
  // Export timestamps are part of the capture window. Unknown or contradictory
  // capture dates cannot be used to prove a non-return.
  if(!value||!capturedAt||capturedAt<value.consentedAt||
     value.events.some(event=>event.at>capturedAt)){rejected++;continue}
  if(value.consentedAt.slice(0,10)>date){rejected++;continue}
  const existing=chosen.get(value.participantId);
  if(existing&&existing.state.consentedAt!==value.consentedAt){rejected++;continue}
  if(existing){
   duplicates++;
   // Prefer the fullest journal. With equally many events prefer the later
   // export: only that one can extend negative follow-up coverage.
   if(value.lastSeq>existing.state.lastSeq||
      (value.lastSeq===existing.state.lastSeq&&capturedAt>existing.capturedAt))
     chosen.set(value.participantId,{state:value,capturedAt});
  }else chosen.set(value.participantId,{state:value,capturedAt});
 }
 // Future events must never affect a historical report; the export itself may
 // have been captured later, proving coverage of earlier complete UTC days.
 const participants=[...chosen.values()].map(item=>{
  const state=item.state,asOfState={...state,events:state.events.filter(event=>event.at.slice(0,10)<=date)};
  const summary=core.summarize(asOfState,date);
  // A trimmed journal may have silently lost the very session we are seeking.
  const fullHistory=state.lastSeq===state.events.length&&
    state.events.every((event,index)=>event.seq===index+1);
  return summary?{state,summary,capturedAt:item.capturedAt,fullHistory}:null;
 }).filter(Boolean);
 const summaries=participants.map(item=>item.summary);
 const count=summaries.length;
 function retention(days){
   const eligible=participants.filter(item=>date>=core.dayShift(item.summary.firstDay,days));
   // Core's existing summary exposes d1/d7 outcomes, not individual visit days
   // after normalization. Use the exact marked target-day result for each.
   const positive=eligible.filter(item=>item.summary['d'+days].returned).length;
   const negative=eligible.filter(item=>{
     if(item.summary['d'+days].returned)return false;
     const target=core.dayShift(item.summary.firstDay,days);
     return item.fullHistory&&item.capturedAt.slice(0,10)>target;
   }).length;
   const covered=positive+negative,unknown=eligible.length-covered;
   return {eligible:eligible.length,returned:positive,verifiedNo:negative,unknown,
     covered,coveragePercent:clampRate(covered,eligible.length),
     ratePercent:clampRate(positive,covered),
     observedSharePercent:clampRate(positive,eligible.length)};
 }
 const d1=retention(1),d7=retention(7);
 const funnel={
  first_trace:summaries.filter(s=>s.firstTrace).length,
  any_trace:summaries.filter(s=>s.everPlaced).length,
  generation_advanced_observed:summaries.filter(s=>s.advanced).length,
  legacy_journal_opened:summaries.filter(s=>s.counts.journal_opened>0).length,
  founder_preview_opened:summaries.filter(s=>s.counts.founder_preview_opened>0).length,
  cosmetic_selected:summaries.filter(s=>s.counts.cosmetic_selected>0).length,
  survey_submitted:summaries.filter(s=>s.survey!==null).length
 };
 const surveys=summaries.map(s=>s.survey).filter(Boolean);
 const priceChoices=Object.fromEntries(core.PRICE_OPTIONS.map(x=>[String(x),surveys.filter(s=>s.priceCents===x).length]));
 const answers={
  count:surveys.length,clarity:average(surveys.map(s=>s.clarity)),
  returnIntent:average(surveys.map(s=>s.returnIntent)),meaning:average(surveys.map(s=>s.meaning)),
  priceIntentionCounts:priceChoices,
  reasons:Object.fromEntries(core.REASONS.map(x=>[x,surveys.filter(s=>s.reason===x).length]))
 };
 return {
  product:'INHERIT',reportKind:'voluntary-export-pilot',asOf:date,
  sample:{participants:count,rejectedExports:rejected,duplicateExports:duplicates,scope:'Self-selected voluntary exports only; not MAU or population retention'},
  retention:{d1,d7},
  evidence:{
   status:count===0?'NO_EXPORTS':d7.eligible===0?'AWAIT_D7':d7.unknown>0?'MISSING_FOLLOWUP':d7.covered<30?'SMALL_VOLUNTARY_SAMPLE':'DESCRIPTIVE_ONLY',
   minDescriptiveSample:30,readyForPayments:false,
   note:'Voluntary local exports alone cannot establish population retention, CAC, revenue or purchase demand.'
  },
  funnel:Object.fromEntries(Object.entries(funnel).map(([k,v])=>[k,{participants:v,ratePercent:clampRate(v,count)}])),
  survey:answers,
  limitations:[
   'Self-selected voluntary exports cannot estimate the retention of all game users. Missing uploads and device resets create strong selection bias.',
   'An exported journal captured before a target day ends cannot prove non-return; incomplete follow-up is shown as unknown.',
   'A full journal observed through the entire target UTC day can document the absence of a recorded session on that device, not that the person never returned elsewhere.',
   'D1 and D7 use exact UTC calendar day relative to research consent, not first install or first gameplay. Later events are censored at the report as-of day.',
   'This file includes no purchases, real payments, CAC, LTV or verified server history.',
   'A stated price preference is not evidence of a completed purchase.',
   'World-generation advancement is observed client-side and is not a server-authoritative transfer.'
  ]
 };
}
export function formatMarkdown(report){
 const {sample,retention,funnel,survey}=report;
 const rate=x=>x.ratePercent===null?'n/a':x.ratePercent+'%';
 return [
  '# INHERIT — добровольное исследование',
  '',
  '**Дата отчёта (UTC):** '+report.asOf,
  '**Сфера:** только вручную переданные экспорты участников, не вся аудитория.',
  '**Участников:** '+sample.participants+'; повторных экспортов: '+sample.duplicateExports+'; отклонено: '+sample.rejectedExports,
  '',
  '## Возвраты по добровольным экспортам (не D1/D7 всей аудитории)',
  '| Период | Достигли срока | Зафиксирован возврат | Сессия не обнаружена при полном охвате | Нет достаточных данных | Охват | Доля среди охваченных |',
  '|---|---:|---:|---:|---:|---:|---:|',
  '| D1 | '+retention.d1.eligible+' | '+retention.d1.returned+' | '+retention.d1.verifiedNo+' | '+retention.d1.unknown+' | '+(retention.d1.coveragePercent===null?'н/д':retention.d1.coveragePercent+'%')+' | '+rate(retention.d1)+' |',
  '| D7 | '+retention.d7.eligible+' | '+retention.d7.returned+' | '+retention.d7.verifiedNo+' | '+retention.d7.unknown+' | '+(retention.d7.coveragePercent===null?'н/д':retention.d7.coveragePercent+'%')+' | '+rate(retention.d7)+' |',
  '',
  '**Метод:** «Неизвестно» означает, что экспорт сделан до окончания нужного дня или локальный журнал неполный. Процент считается лишь среди данных с достаточным временным охватом; это не показатель удержания всех пользователей.',
  '**Готовность к монетизации:** '+report.evidence.status+'; автоматическое разрешение принимать платежи отсутствует.',
  '',
  '## Игровая воронка',
  '| Действие | Участники | Доля |',
  '|---|---:|---:|',
  ...Object.entries(funnel).map(([key,v])=>'| '+key+' | '+v.participants+' | '+rate(v)+' |'),
  '',
  '## Добровольный опрос',
  'Ответов: '+survey.count+'; понятность: '+(survey.clarity??'n/a')+'/5; намерение вернуться: '+(survey.returnIntent??'n/a')+'/5; смысл передачи: '+(survey.meaning??'n/a')+'/5.',
  '',
  'Ответы о **гипотетической максимальной цене** (цены в центах США): '+Object.entries(survey.priceIntentionCounts).map(([p,n])=>p+' → '+n).join('; ')+'.',
  '',
  '## Ограничения',
  ...report.limitations.map(s=>'- '+s),
  '',
  '**Вывод:** эта таблица не доказывает рынок, платёжную конверсию, MAU или фактическую доходность. Решение о выпуске платных функций требует дополнительной проверки.',
  ''
 ].join('\n');
}
