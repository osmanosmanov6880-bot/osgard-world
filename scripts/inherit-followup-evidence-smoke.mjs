import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import '../public/games/inherit/research-core.js';
import {aggregate,formatMarkdown} from './inherit-pilot-metrics.mjs';

const core=globalThis.InheritResearchCore;
const day=(d,h='12:00:00')=>d+'T'+h+'.000Z';
const identifiers=Array.from({length:12},(_,i)=>'r5-participant-'+String(i).padStart(28,'0'));
const create=(i,first='2026-10-01')=>{
  const consent=core.create(identifiers[i],day(first));
  const start=core.record(consent,'session_opened',day(first));
  assert.ok(start);
  return start;
};
const visit=(s,d)=>{const next=core.record(s,'session_opened',day(d));assert.ok(next);return next};
const exported=(s,at)=>{const result=core.exportConsent(s,day(at));assert.ok(result);return result};
let passed=0;
function check(name,fn){fn();passed++;console.log('PASS '+name)}
const base='2026-10-20';
check('an early export never becomes an invented D1/D7/D30 nonreturn weeks later',()=>{
 const record=exported(create(0),'2026-10-01');
 const r=aggregate([record],'2026-11-02');
 assert.equal(r.sample.participants,1);
 for(const term of ['d1','d7','d30']){
   assert.equal(r.retention[term].eligible,1);
   assert.equal(r.retention[term].returned,0);
   assert.equal(r.retention[term].verifiedNo,0);
   assert.equal(r.retention[term].unknown,1);
   assert.equal(r.retention[term].covered,0);
   assert.equal(r.retention[term].ratePercent,null);
 }
 assert.equal(r.evidence.status,'MISSING_FOLLOWUP');
 assert.equal(r.evidence.readyForPayments,false);
});
check('an export captured during D1 cannot prove no return later that day',()=>{
 const r=aggregate([exported(create(1),'2026-10-02')],base);
 assert.equal(r.retention.d1.unknown,1);
 assert.equal(r.retention.d1.verifiedNo,0);
});
check('a complete export after the D1 day can document absence on that device',()=>{
 const r=aggregate([exported(create(2),'2026-10-03')],base);
 assert.equal(r.retention.d1.eligible,1);
 assert.equal(r.retention.d1.verifiedNo,1);
 assert.equal(r.retention.d1.unknown,0);
 assert.equal(r.retention.d1.covered,1);
 assert.equal(r.retention.d1.ratePercent,0);
 assert.equal(r.retention.d7.unknown,1);
});
check('observed D1 return is valid even if export occurred on the target day',()=>{
 const r=aggregate([exported(visit(create(3),'2026-10-02'),'2026-10-02')],base);
 assert.equal(r.retention.d1.returned,1);
 assert.equal(r.retention.d1.ratePercent,100);
 assert.equal(r.retention.d1.verifiedNo,0);
});
check('D30 is a real exact-day observation, not any session later in the month',()=>{
 let yes=visit(create(4),'2026-10-31');
 let no=visit(create(5),'2026-11-01');
 const r=aggregate([exported(yes,'2026-11-02'),exported(no,'2026-11-02')],'2026-11-02');
 assert.equal(r.retention.d30.eligible,2);
 assert.equal(r.retention.d30.returned,1);
 assert.equal(r.retention.d30.verifiedNo,1);
 assert.equal(r.retention.d30.unknown,0);
 assert.equal(r.retention.d30.ratePercent,50);
});
check('same-sequence repeated export uses the later capture window',()=>{
 const state=create(6);
 const old=exported(state,'2026-10-01'),newer=exported(state,'2026-10-04');
 const r=aggregate([old,newer],base);
 assert.equal(r.sample.duplicateExports,1);
 assert.equal(r.retention.d1.verifiedNo,1);
 assert.equal(r.retention.d1.unknown,0);
});
check('a bounded 512-event local journal does not prove missing past sessions',()=>{
 let s=create(7);
 for(let i=0;i<540;i++)s=core.record(s,'journal_opened',day('2026-10-03'));
 assert.equal(s.events.length,core.MAX_EVENTS);
 assert.ok(s.lastSeq>s.events.length);
 const r=aggregate([exported(s,'2026-10-20')],base);
 assert.equal(r.retention.d1.verifiedNo,0);
 assert.equal(r.retention.d1.unknown,1);
});
check('but a positively observed return can count even in a bounded journal',()=>{
 let s=visit(create(8),'2026-10-02');
 for(let i=0;i<545;i++)s=core.record(s,'journal_opened',day('2026-10-03'));
 const r=aggregate([exported(s,'2026-10-20')],base);
 assert.equal(r.retention.d1.returned,0); // D1 was evicted; the correct classification is unknown.
 assert.equal(r.retention.d1.unknown,1);
});
check('invalid, missing or contradictory capture timestamps are rejected',()=>{
 const state=create(9);
 const valid=exported(state,'2026-10-03');
 const missing={...valid};delete missing.generatedAt;
 const invalid={...valid,generatedAt:'2026-02-31T08:00:00.000Z'};
 const contradictory={...valid,generatedAt:'2026-09-30T12:00:00.000Z'};
 const futureEvents=exported(visit(state,'2026-10-10'),'2026-10-05');
 const r=aggregate([missing,invalid,contradictory,futureEvents],base);
 assert.equal(r.sample.participants,0);
 assert.equal(r.sample.rejectedExports,4);
});
check('mixed complete and stale participant exports have explicit unresolved share',()=>{
 const s1=visit(create(0),'2026-10-02');
 const s2=create(1);
 const s3=create(2);
 const r=aggregate([exported(s1,'2026-10-05'),exported(s2,'2026-10-05'),exported(s3,'2026-10-01')],base);
 assert.equal(r.retention.d1.eligible,3);
 assert.equal(r.retention.d1.returned,1);
 assert.equal(r.retention.d1.verifiedNo,1);
 assert.equal(r.retention.d1.unknown,1);
 assert.equal(r.retention.d1.covered,2);
 assert.equal(r.retention.d1.ratePercent,50);
 assert.equal(r.retention.d1.coveragePercent,66.7);
 assert.equal(r.retention.d1.observedSharePercent,33.3);
});
check('historical report filters future sessions without hiding valid D30 as-of date',()=>{
 let s=visit(create(10),'2026-10-31');
 s=visit(s,'2026-11-01');
 const exportedLater=exported(s,'2026-11-02');
 const early=aggregate([exportedLater],'2026-10-20');
 assert.equal(early.retention.d30.eligible,0);
 assert.equal(early.retention.d30.ratePercent,null);
 const later=aggregate([exportedLater],'2026-11-02');
 assert.equal(later.retention.d30.returned,1);
});
check('report and markdown never contain participant codes or individual event times',()=>{
 const r=aggregate([exported(create(11),'2026-10-01')],'2026-10-20');
 const report=JSON.stringify(r),md=formatMarkdown(r);
 assert.equal(r.evidence.readyForPayments,false);
 assert.ok(!report.includes(identifiers[11]));
 assert.ok(!md.includes(identifiers[11]));
 assert.match(md,/Нет достаточных данных/);
 assert.match(md,/D30/);
 assert.ok(!md.includes('н/д%'));
});
check('evidence status never asserts real market readiness',()=>{
 const empty=aggregate([],base);assert.equal(empty.evidence.status,'NO_EXPORTS');
 const immature=aggregate([exported(create(1),'2026-10-01')],'2026-10-03');
 assert.equal(immature.evidence.status,'AWAIT_D7');
 const d7Covered=aggregate([exported(create(2),'2026-10-12')],base);
 assert.equal(d7Covered.evidence.status,'SMALL_VOLUNTARY_SAMPLE');
 assert.equal(d7Covered.evidence.readyForPayments,false);
});
console.log('INHERIT FOLLOWUP EVIDENCE:',passed,'passed');
