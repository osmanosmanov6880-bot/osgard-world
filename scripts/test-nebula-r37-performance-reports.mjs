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
const {parseReport,makeCSV,thresholds}=sandbox.window.NebulaR37;
assert.equal(thresholds.length,3);
const report=values=>({
  schema:'NEBULA_R12_HARDWARE_BENCHMARK',quality:1,quality_changed:false,
  quality_gate:'MEETS_TARGET',sample_seconds:20,valid_frames:800,
  excluded_long_frames:0,adapter_reported:'Browser-reported graphics',
  runtime:'Web',avg_fps:50,one_percent_low_fps:35,
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
assert.ok(csv.startsWith('"Файл","Профиль"'));
assert.ok(csv.includes('"\'=HYPERLINK'),'CSV formula injection must be escaped');
assert.ok(!csv.includes('\n.csv'),'CSV line breaks must be sanitized');
console.log('NEBULA_R37_OFFLINE_COMPARISON_SUCCESS actual_html_script=executed synthetic_fixtures=17 local_only=true');
