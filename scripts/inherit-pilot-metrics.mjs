/* Operator-only aggregation of manually shared, consented INHERIT research exports.
   Never reads gameplay saves and never sends data to any server. */
import '../public/games/inherit/research-core.js';
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
  const value=core.normalize(payload);
  if(!value){rejected++;continue}
  if(value.consentedAt.slice(0,10)>date){rejected++;continue}
  const existing=chosen.get(value.participantId);
  if(existing&&existing.consentedAt!==value.consentedAt){rejected++;continue}
  if(existing){
   duplicates++;
   if(value.lastSeq>existing.lastSeq)chosen.set(value.participantId,value);
  }else chosen.set(value.participantId,value);
 }
 const summaries=[...chosen.values()].map(x=>core.summarize(x,date)).filter(Boolean);
 const count=summaries.length,eligD1=summaries.filter(s=>s.d1.eligible),eligD7=summaries.filter(s=>s.d7.eligible);
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
 const d1Returned=eligD1.filter(s=>s.d1.returned).length,d7Returned=eligD7.filter(s=>s.d7.returned).length;
 return {
  product:'INHERIT',reportKind:'voluntary-export-pilot',asOf:date,
  sample:{participants:count,rejectedExports:rejected,duplicateExports:duplicates,scope:'Self-selected voluntary exports only; not MAU or population retention'},
  retention:{
   d1:{eligible:eligD1.length,returned:d1Returned,ratePercent:clampRate(d1Returned,eligD1.length)},
   d7:{eligible:eligD7.length,returned:d7Returned,ratePercent:clampRate(d7Returned,eligD7.length)}
  },
  funnel:Object.fromEntries(Object.entries(funnel).map(([k,v])=>[k,{participants:v,ratePercent:clampRate(v,count)}])),
  survey:answers,
  limitations:[
   'Exporters are self-selected; missing exports and incomplete event journals bias every rate.',
   'D1 and D7 use exact UTC calendar day relative to research consent, not first install or first gameplay.',
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
  '## Удержание (после согласия)',
  '| Метрика | Достигли срока | Вернулись | Доля |',
  '|---|---:|---:|---:|',
  '| D1 | '+retention.d1.eligible+' | '+retention.d1.returned+' | '+rate(retention.d1)+' |',
  '| D7 | '+retention.d7.eligible+' | '+retention.d7.returned+' | '+rate(retention.d7)+' |',
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
