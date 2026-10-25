#!/usr/bin/env node
// Synthetic CI fixtures exercise the actual shipped HTML; NOT phone benchmarks.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const path=process.argv[2]||'public/games/remix/arena-v2/nebula-3d/performance-report.html';
const html=fs.readFileSync(path,'utf8');
assert.match(html,/<html lang="ru">/);
assert.match(html,/viewport-fit=cover/);
assert.match(html,/aria-live="polite"/);
const match=html.match(/<script id="nebula-r37-comparator">([\s\S]*?)<\/script>/);
assert.ok(match,'real exported comparison source missing');
assert.ok(!/\bfetch\s*\(|XMLHttpRequest|sendBeacon\s*\(|new\s+WebSocket\b/.test(match[1]),
  'performance uploads must remain disabled');
assert.ok(!/\.innerHTML\s*=/.test(match[1]),'never inject user filenames as HTML');
const sandbox={window:{},document:{getElementById(){return null;}},console};
vm.runInNewContext(match[1],sandbox,{timeout:3500});
const {parseReport,makeCSV,thresholds,summarizeRuns,compareBuilds,r40CandidateBuildId}=sandbox.window.NebulaR37;
assert.equal(r40CandidateBuildId,'NEBULA_R40_BRIDGE_BATCH_3X32');
assert.equal(thresholds.length,3);
const report=values=>({
  schema:'NEBULA_R12_HARDWARE_BENCHMARK',quality:1,quality_changed:false,
  quality_gate:'MEETS_TARGET',sample_seconds:20,valid_frames:800,
  excluded_long_frames:0,adapter_reported:'Browser-reported graphics',
  runtime:'Web',resolution_width:390,resolution_height:844,
  avg_fps:50,one_percent_low_fps:35,
  p95_frame_ms:24,p99_frame_ms:28,r36_browser_dom_to_engine_avg_ms:12,
  ...values
});
const normal=parseReport(report({}),'device-one.json');
assert.equal(normal.status,'ЦЕЛЬ');
assert.equal(normal.profile,'HIGH');
assert.equal(normal.touch,12);
assert.equal(normal.targetFps,40);
assert.equal(parseReport(report({avg_fps:38}),'slow.json').status,'НИЖЕ ЦЕЛИ');
assert.equal(parseReport(report({p95_frame_ms:40}),'stutter.json').status,'НИЖЕ ЦЕЛИ');
assert.equal(parseReport(report({quality:0,avg_fps:62,p95_frame_ms:18}),'max.json').status,'ЦЕЛЬ');
assert.equal(parseReport(report({quality:2,avg_fps:34,p95_frame_ms:34}),'eco.json').status,'ЦЕЛЬ');
assert.equal(parseReport(report({adapter_reported:'ANGLE SwiftShader'}),'ci.json').status,'SOFTWARE GPU');
assert.equal(parseReport(report({quality_changed:true}),'changed.json').status,'НЕНАДЁЖНЫЙ');
assert.equal(parseReport(report({quality_gate:'UNRELIABLE'}),'bad.json').status,'НЕНАДЁЖНЫЙ');
assert.equal(parseReport(report({excluded_long_frames:3}),'paused.json').status,'НЕНАДЁЖНЫЙ');
assert.equal(parseReport(report({valid_frames:12}),'short.json').status,'НЕНАДЁЖНЫЙ');
assert.equal(parseReport(report({sample_seconds:4}),'too-short.json').status,'НЕНАДЁЖНЫЙ');
assert.equal(parseReport(report({r36_browser_dom_to_engine_avg_ms:null}),'no-touch.json').touch,null);
assert.throws(()=>parseReport(report({schema:'UNKNOWN'}),'bad.json'),/схема/);
assert.throws(()=>parseReport(report({avg_fps:NaN}),'bad.json'),/avg_fps/);
assert.throws(()=>parseReport(report({quality:99}),'bad.json'),/профиль/);
assert.throws(()=>parseReport(report({sample_seconds:-1}),'bad.json'),/sample_seconds/);
const hostile=parseReport(report({}),'=HYPERLINK("https://phishing.invalid")\n.csv');
assert.equal(hostile.name.includes('\n'),false);
const csv=makeCSV([normal,hostile]);
assert.ok(csv.startsWith('"Устройство","Сборка","Метка JSON","Размер","Файл","Профиль"'));
assert.ok(csv.includes('"\'=HYPERLINK'),'CSV formula injection must be escaped');
assert.ok(!csv.includes('\n.csv'),'CSV line breaks must be sanitized');
let syntheticTimestamp=1790000000;
const phone=(fps,p95,filename='trial.json',device='Android QA')=>
  parseReport(report({date_unix:++syntheticTimestamp,avg_fps:fps,p95_frame_ms:p95}),filename,device);
const stable=summarizeRuns([phone(48,24),phone(50,22),phone(52,23)]);
assert.equal(stable.length,1);
assert.equal(stable[0].valid,3);
assert.equal(stable[0].medianFps,50);
assert.equal(stable[0].medianP95,23);
assert.equal(stable[0].status,'ЦЕЛЬ');
const jitter=summarizeRuns([phone(30,24),phone(50,22),phone(70,23)]);
assert.equal(jitter[0].status,'НЕСТАБИЛЬНО');
const incomplete=summarizeRuns([phone(50,22),phone(51,23)]);
assert.equal(incomplete[0].status,'НЕ ХВАТАЕТ ДАННЫХ');
const mix=summarizeRuns([
  phone(49,22,'a','Phone A'),phone(50,22,'b','Phone A'),phone(51,22,'c','Phone A'),
  phone(49,22,'a','Phone B'),phone(50,22,'b','Phone B')]);
assert.equal(mix.length,2);
assert.equal(mix[1].status,'НЕ ХВАТАЕТ ДАННЫХ');
const invalid=summarizeRuns([phone(51,22),phone(52,22),
  parseReport(report({adapter_reported:'SwiftShader'}),'fake.json','Android QA')]);
assert.equal(invalid[0].valid,2);
assert.equal(invalid[0].status,'НЕ ХВАТАЕТ ДАННЫХ');
const original=phone(50,22,'origin.json');
const duplicates=summarizeRuns([original,original,original]);
assert.equal(duplicates[0].total,3);
assert.equal(duplicates[0].valid,1);
assert.equal(duplicates[0].duplicates,2);
assert.equal(duplicates[0].status,'НЕ ХВАТАЕТ ДАННЫХ');
const noStamp=summarizeRuns([parseReport(report({date_unix:null}),'x','Android QA')]);
assert.equal(noStamp[0].valid,0);
const noSize=summarizeRuns([parseReport(report({date_unix:1790000009,resolution_width:null}),'x','Android QA')]);
assert.equal(noSize[0].valid,0);
assert.ok(makeCSV([phone(49,22,'ok','=CMD()')]).includes('"\'=CMD()"'));
const deviceRun=(fps,p95,variant,device='AB Device',filename='run.json')=>
  parseReport(report({date_unix:++syntheticTimestamp,avg_fps:fps,p95_frame_ms:p95,
      ...(variant==='R40'?{build_variant:r40CandidateBuildId}:{})}),
    filename,device,variant);
const paired=compareBuilds(summarizeRuns([
  deviceRun(35,28,'R38'),deviceRun(36,27,'R38'),deviceRun(34,28,'R38'),
  deviceRun(46,21,'R40'),deviceRun(47,21,'R40'),deviceRun(45,22,'R40')
]));
assert.equal(paired.length,1);
assert.equal(paired[0].baselineFps,35);
assert.equal(paired[0].candidateFps,46);
assert.ok(paired[0].deltaFps>30);
assert.equal(paired[0].status,'ЛУЧШЕ');
const regressed=compareBuilds(summarizeRuns([
  deviceRun(60,17,'R38'),deviceRun(61,17,'R38'),deviceRun(59,18,'R38'),
  deviceRun(43,26,'R40'),deviceRun(44,27,'R40'),deviceRun(42,26,'R40')
]));
assert.equal(regressed[0].status,'ХУЖЕ');
const originals=[deviceRun(50,20,'R38'),deviceRun(51,20,'R38'),deviceRun(52,20,'R38')];
const mislabeled=originals.map(x=>({...x,variant:'R40'}));
const crossCopies=compareBuilds(summarizeRuns([...originals,...mislabeled]));
assert.equal(crossCopies[0].status,'ПОВТОРНЫЕ JSON');
assert.equal(crossCopies[0].deltaFps,null);
const noPair=compareBuilds(summarizeRuns([
  deviceRun(40,24,'R38'),deviceRun(41,24,'R38'),deviceRun(42,24,'R38')
]));
assert.equal(noPair[0].status,'НЕ ХВАТАЕТ ДАННЫХ');
const mixedDevices=compareBuilds(summarizeRuns([
  deviceRun(50,20,'R38','Android A'),deviceRun(51,20,'R38','Android A'),
  deviceRun(52,20,'R38','Android A'),
  deviceRun(50,20,'R40','Android B'),deviceRun(51,20,'R40','Android B'),
  deviceRun(52,20,'R40','Android B')
]));
assert.equal(mixedDevices.length,2);
assert.ok(mixedDevices.every(x=>x.status==='НЕ ХВАТАЕТ ДАННЫХ'));
assert.throws(()=>parseReport(report({}),'x','AB Device','IMPOSTOR'),/версия/);
assert.throws(()=>parseReport(report({}),'x','AB Device','R40'),/R40/);
assert.throws(()=>parseReport(report({build_variant:r40CandidateBuildId}),'x','AB Device','R38'),/R40/);
assert.throws(()=>parseReport(report({build_variant:'OTHER_BUILD'}),'x','AB Device','R40'),/идентификац/);
assert.equal(parseReport(report({build_variant:r40CandidateBuildId}),'r40.json','AB Device','R40').reportedBuild,r40CandidateBuildId);
assert.equal(parseReport(report({}),'r38.json','AB Device','R38').reportedBuild,'R38_LEGACY');
console.log('NEBULA_R40_AB_LOCAL_QA_SUCCESS measured_physical_devices=0 paired_synthetic=4');
console.log('NEBULA_R39_REPEATABILITY_QA_SUCCESS synthetic_groups=6 real_hardware_claims=0');
console.log('NEBULA_R37_OFFLINE_COMPARISON_SUCCESS actual_html_script=executed synthetic_fixtures=17 local_only=true');
