import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import '../public/games/inherit/research-core.js';
import {aggregate,formatMarkdown} from './inherit-pilot-metrics.mjs';
import vm from 'node:vm';
const core=globalThis.InheritResearchCore;
const read=name=>readFileSync('public/games/inherit/'+name,'utf8');
const fixed='2026-10-20T12:00:00.000Z';
const idA='aaaa-1111-2222-3333-444444444444',idB='bbbb-1111-2222-3333-444444444444',idC='cccc-1111-2222-3333-444444444444';
let passes=0;
function check(name,fn){fn();console.log('PASS',name);passes++}
function start(id,date){const state=core.create(id,date);assert.ok(state);return core.record(state,'session_opened',date)}
function add(state,type,at,data){const out=core.record(state,type,at,data);assert.ok(out,type);return out}
const exportOf=state=>core.exportConsent(state,fixed);
check('all research and tutorial assets are loaded and versioned in offline shell',()=>{
 const html=read('index.html'),sw=read('sw.js');
 for(const name of ['research-core.js','research-i18n.js','research-ui.js','research.css','first-steps.js','first-steps.css']){
  assert.ok(html.includes('./'+name),'HTML '+name);assert.ok(sw.includes('/games/inherit/'+name),'SW '+name);
 }
 assert.match(sw,/inherit-shell-v15/);
 for(const name of ['research-core.js','research-ui.js','first-steps.js','research-i18n.js'])new vm.Script(read(name));
});
check('consent is required before a research participant can exist',()=>{
 assert.equal(core.normalize(null),null);
 assert.equal(core.normalize({schema:1,consent:false,participantId:idA,consentedAt:fixed,events:[],lastSeq:0}),null);
 assert.equal(core.create('unsafe',fixed),null);
 assert.equal(core.create(idA,'2026-02-30T00:00:00.000Z'),null);
 const state=core.create(idA,fixed);assert.equal(state.events.length,0);
 assert.equal(core.record(null,'session_opened',fixed),null);
});
check('collect only strictly normalized event types and survey values',()=>{
 let state=start(idA,'2026-10-10T12:00:00.000Z');
 assert.equal(core.record(state,'coordinates','2026-10-11T12:00:00.000Z',{x:40,y:40}),null);
 assert.equal(core.record(state,'survey_submitted',fixed,{clarity:1,returnIntent:2,meaning:3,reason:'creation',priceCents:13}),null);
 state=add(state,'trace_placed','2026-10-10T12:10:00.000Z',{pendingCount:1,username:'should-not-export'});
 assert.deepEqual(state.events[1].data,{pendingCount:1});
 state=add(state,'first_trace_placed','2026-10-10T12:10:01.000Z');
 const twice=core.record(state,'first_trace_placed','2026-10-11T12:10:01.000Z');
 assert.equal(twice.lastSeq,state.lastSeq);
 state=add(state,'survey_submitted',fixed,{clarity:5,returnIntent:4,meaning:4,reason:'story',priceCents:499,email:'redacted'});
 const dumped=JSON.stringify(exportOf(state));
 assert.ok(!dumped.includes('email'));assert.ok(!dumped.includes('username'));
 assert.ok(!dumped.includes('should-not-export'));assert.ok(dumped.includes('voluntary-pilot-export'));
});
check('retention is exact UTC calendar-day since consent, and respects eligibility',()=>{
 let a=start(idA,'2026-10-10T07:00:00.000Z');
 a=add(a,'session_opened','2026-10-11T08:00:00.000Z');
 a=add(a,'session_opened','2026-10-17T08:00:00.000Z');
 let b=start(idB,'2026-10-10T08:00:00.000Z');
 let c=start(idC,'2026-10-20T08:00:00.000Z');
 const sa=core.summarize(a,'2026-10-20'),sb=core.summarize(b,'2026-10-20'),sc=core.summarize(c,'2026-10-20');
 assert.equal(sa.d1.returned,true);assert.equal(sa.d7.returned,true);
 assert.equal(sb.d1.eligible,true);assert.equal(sb.d7.returned,false);
 assert.equal(sc.d1.eligible,false);assert.equal(sc.d7.eligible,false);
 assert.equal(sc.d7.returned,null);
});
check('operator tool deduplicates repeated exports, counts real opt-in cohorts and does not infer purchases',()=>{
 let a=start(idA,'2026-10-10T07:00:00.000Z');
 a=add(a,'session_opened','2026-10-11T08:00:00.000Z');
 a=add(a,'session_opened','2026-10-17T09:00:00.000Z');
 a=add(a,'trace_placed','2026-10-17T09:03:00.000Z',{pendingCount:1});
 a=add(a,'first_trace_placed','2026-10-17T09:03:01.000Z');
 a=add(a,'generation_advanced_observed','2026-10-17T09:10:00.000Z',{generation:174});
 a=add(a,'survey_submitted','2026-10-18T08:00:00.000Z',{clarity:5,returnIntent:4,meaning:5,reason:'story',priceCents:499});
 let b=start(idB,'2026-10-10T07:00:00.000Z');
 b=add(b,'survey_submitted','2026-10-10T08:00:00.000Z',{clarity:2,returnIntent:1,meaning:2,reason:'not_interested',priceCents:0});
 let c=start(idC,'2026-10-20T07:00:00.000Z');
 c=add(c,'survey_submitted','2026-10-20T08:00:00.000Z',{clarity:4,returnIntent:5,meaning:4,reason:'visual',priceCents:199});
 const report=aggregate([exportOf(a),exportOf(b),exportOf(c),exportOf(a),{},null], '2026-10-20');
 assert.equal(report.sample.participants,3);assert.equal(report.sample.duplicateExports,1);assert.equal(report.sample.rejectedExports,2);
 assert.deepEqual(report.retention.d1,{eligible:2,returned:1,ratePercent:50});
 assert.deepEqual(report.retention.d7,{eligible:2,returned:1,ratePercent:50});
 assert.equal(report.funnel.first_trace.participants,1);assert.equal(report.funnel.generation_advanced_observed.participants,1);
 assert.equal(report.survey.count,3);assert.equal(report.survey.priceIntentionCounts['499'],1);
 assert.equal(report.survey.priceIntentionCounts['0'],1);
 assert.match(formatMarkdown(report),/D1/);assert.match(formatMarkdown(report),/гипотетической/);
 assert.ok(!JSON.stringify(report).includes(idA));assert.ok(!JSON.stringify(report).includes(idB));
 const empty=aggregate([],'2026-10-20');assert.equal(empty.sample.participants,0);assert.equal(empty.retention.d1.ratePercent,null);
});
check('bounded participant journal preserves early cohort anchor',()=>{
 let s=start(idA,'2026-10-01T01:00:00.000Z');
 s=add(s,'first_trace_placed','2026-10-01T01:00:03.000Z');
 for(let i=0;i<575;i++)s=add(s,'journal_opened','2026-10-02T01:00:00.000Z');
 assert.equal(s.events.length,512);
 assert.equal(s.events[0].type,'session_opened');
 assert.equal(s.events[1].type,'first_trace_placed');
 assert.equal(s.lastSeq,577);
 assert.ok(core.normalize(s));
});
check('UI cannot write to game saves, servers or identity sources',()=>{
 const ui=read('research-ui.js'),guide=read('first-steps.js');
 for(const bad of ['fetch(', 'navigator.sendBeacon','InheritGame.apply(', 'innerHTML=', 'XMLHttpRequest'])assert.ok(!ui.includes(bad),bad);
 for(const bad of ['fetch(', 'InheritGame.apply(', 'innerHTML='])assert.ok(!guide.includes(bad),bad);
 for(const need of ['consentBox','localStorage']){if(need==='consentBox')assert.ok(ui.includes('checkbox'));else assert.ok(ui.includes('localStorage'))}
 for(const l of ['ru:','en:','zh:'])assert.ok(read('research-i18n.js').includes(l));
 assert.match(read('research.css'),/prefers-reduced-motion:reduce/);
 assert.match(read('first-steps.css'),/focus-visible/);
});
console.log('INHERIT RESEARCH:',passes,'passed');
