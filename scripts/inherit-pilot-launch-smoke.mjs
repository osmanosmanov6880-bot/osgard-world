import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import '../public/games/inherit/research-core.js';
import {aggregate,formatMarkdown} from './inherit-pilot-metrics.mjs';
import {aggregate as browserAggregate} from '../public/games/inherit/pilot-metrics.js';
const core=globalThis.InheritResearchCore;
const read=name=>readFileSync('public/games/inherit/'+name,'utf8');
const at=(day,clock='12:00:00')=>day+'T'+clock+'.000Z';
const ids=['pilot-r4-aaaaaaaaaaaaaaaaaaa','pilot-r4-bbbbbbbbbbbbbbbbbbb','pilot-r4-ccccccccccccccccccc'];
let passed=0;
function test(name,fn){fn();passed++;console.log('PASS '+name)}
const begin=(id,day)=>{
 let r=core.create(id,at(day));
 assert.ok(r);
 return core.record(r,'session_opened',at(day));
};
const event=(r,type,day,data={})=>core.record(r,type,at(day),data);
const exportOf=(r)=>core.exportConsent(r,at('2026-10-31'));
test('pilot landing, local console and research engine ship as static files',()=>{
 const html=read('pilot/index.html'),report=read('pilot/report.html'),sw=read('sw.js');
 for(const file of ['pilot/index.html','pilot/report.html','pilot/landing.js','pilot/report.js','pilot/pilot.css','pilot-metrics.js'])
   assert.ok(sw.includes("'/games/inherit/"+file+"'"),file);
 for(const name of ['pilot/landing.js','pilot/report.js','pilot/pilot.css'])assert.ok(html.includes('./'+name.split('/').pop())||report.includes('./'+name.split('/').pop()),name);
 assert.match(sw,/inherit-shell-v22/);
 assert.match(sw,/mjs\|js\|css/);
 assert.ok(sw.includes("path.endsWith('/report.html')"));
 assert.ok(sw.includes("'/games/inherit/pilot/report.html'"));
});
test('landing has multilingual consent-neutral CTAs and no paid checkout',()=>{
 const source=read('pilot/landing.js'),html=read('pilot/index.html');
 new vm.Script(source);
 for(const word of ['ru:','en:','zh:','pilot=1','setLanguage'])assert.ok(source.includes(word));
 for(const phrase of ['data-lang="ru"','data-lang="en"','data-lang="zh"','id="join"','id="game"'])assert.ok(html.includes(phrase));
 assert.ok(!/Stripe|checkout|Purchase Now|fake players/i.test(source));
 assert.ok(!/\bfetch\s*\(|sendBeacon|XMLHttpRequest|gtag\s*\(/.test(source));
});
test('research deep link opens journal without automatically opting in',()=>{
 const source=read('research-ui.js'),html=read('pilot/index.html');
 assert.match(html,/pilot=1/);
 assert.ok(source.includes("get('pilot')==='1'"));
 assert.ok(source.includes("openJournal.click()"));
 assert.ok(source.includes("if(journal.open)"));
 assert.ok(source.includes("checkbox.checked=false"));
 assert.ok(source.includes("!record"));
});
test('private browser report contains no network or storage writes',()=>{
 const source=read('pilot/report.js'),html=read('pilot/report.html');
 assert.ok(source.includes('file.text()'));assert.ok(source.includes('aggregate(collected,date.value)'));
 assert.ok(!/\bfetch\s*\(|XMLHttpRequest|sendBeacon|localStorage|sessionStorage/.test(source));
 assert.ok(!/action="https?:|method="post"|formaction="https?:/.test(html));
 assert.match(html,/type="file"/);
 assert.match(html,/noindex,nofollow/);
 new vm.Script(read('pilot/landing.js'));
});
test('historical reports strictly censor future session activity and survey answers',()=>{
 let s=begin(ids[0],'2026-10-01');
 s=event(s,'trace_placed','2026-10-02',{pendingCount:1});
 s=event(s,'session_opened','2026-10-08');
 s=event(s,'survey_submitted','2026-10-09',{clarity:5,returnIntent:5,meaning:5,reason:'creation',priceCents:799});
 const old=aggregate([exportOf(s)],'2026-10-03');
 assert.equal(old.retention.d1.eligible,1);assert.equal(old.retention.d1.returned,0);
 assert.equal(old.retention.d1.verifiedNo,1);assert.equal(old.retention.d1.unknown,0);
 assert.equal(old.retention.d1.ratePercent,0);
 assert.equal(old.retention.d7.eligible,0);assert.equal(old.retention.d7.returned,0);
 assert.equal(old.retention.d7.unknown,0);assert.equal(old.retention.d7.ratePercent,null);
 assert.equal(old.funnel.any_trace.participants,1);
 assert.equal(old.survey.count,0);
 const later=aggregate([exportOf(s)],'2026-10-09');
 assert.equal(later.retention.d7.returned,1);
 assert.equal(later.survey.count,1);
});
test('same ISO as-of works identically in Node CLI and browser shared model',()=>{
 let s=begin(ids[1],'2026-10-01');
 s=event(s,'session_opened','2026-10-02');
 s=event(s,'session_opened','2026-10-08');
 const data=[exportOf(s)],a=aggregate(data,'2026-10-08'),b=browserAggregate(data,'2026-10-08');
 assert.deepEqual(a,b);assert.equal(a.retention.d1.ratePercent,100);assert.equal(a.retention.d7.ratePercent,100);
});
test('repeat exports are deduplicated and future action is not mistaken for earlier success',()=>{
 let a=begin(ids[0],'2026-10-01');
 let b=event(a,'session_opened','2026-10-04');
 b=event(b,'survey_submitted','2026-10-08',{clarity:5,returnIntent:3,meaning:4,reason:'story',priceCents:199});
 const report=aggregate([exportOf(a),exportOf(b)],'2026-10-03');
 assert.equal(report.sample.participants,1);
 assert.equal(report.sample.duplicateExports,1);
 assert.equal(report.survey.count,0);assert.equal(report.retention.d1.returned,0);
});
test('no participants remains null retention; no visitor counts fabricated',()=>{
 const report=aggregate([],'2026-10-20');
 assert.equal(report.sample.participants,0);
 assert.equal(report.retention.d1.ratePercent,null);
 assert.equal(report.retention.d7.ratePercent,null);
 assert.ok(!JSON.stringify(report).includes('participantId'));
});
test('console aggregate reports do not contain participants IDs or individual event times',()=>{
 let r=begin(ids[2],'2026-10-03');
 r=event(r,'session_opened','2026-10-04');
 r=event(r,'first_trace_placed','2026-10-04');
 const json=aggregate([exportOf(r)],'2026-10-10'),md=formatMarkdown(json);
 assert.ok(!JSON.stringify(json).includes(ids[2]));
 assert.ok(!md.includes(ids[2]));
 assert.match(md,/D1/);assert.match(md,/D7/);
 assert.match(json.sample.scope,/Self-selected/);
});
test('mobile and reduced motion layouts exist for pilot and console',()=>{
 const css=read('pilot/pilot.css');
 assert.ok(css.includes('max-width:600px'));
 assert.ok(css.includes('prefers-reduced-motion:reduce'));
 assert.ok(css.includes('focus-visible'));
 assert.ok(css.includes('console-scroll'));
});
console.log('INHERIT PILOT LAUNCH: '+passed+' passed');
