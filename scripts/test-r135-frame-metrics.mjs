import assert from 'node:assert/strict'
import { summarizeRafIntervalsMs } from './r135-frame-metrics.mjs'

// Synthetic fixtures prove the formula, NOT any device performance.
const perfect = summarizeRafIntervalsMs(Array.from({length:300},()=>16.667))
assert.equal(perfect.interval_count,300)
assert.equal(perfect.p99_interval_ms,16.667)
assert.ok(perfect.callback_pacing_one_percent_low_fps > 59)
assert.equal(perfect.fraction_intervals_over_33_3ms,0)
assert.equal(perfect.worst_one_percent_interval_count,3)

const stalls = Array.from({length:199},()=>16.667).concat([80])
const out = summarizeRafIntervalsMs(stalls)
assert.equal(out.interval_count,200)
assert.equal(out.worst_one_percent_interval_count,2)
assert.equal(out.maximum_interval_ms,80)
assert.ok(out.callback_pacing_one_percent_low_fps < 25)
assert.equal(out.fraction_intervals_over_50ms,0.005)

for(const bad of [
  [], Array.from({length:119},()=>16),
  Array.from({length:120},(_,i)=>i===10?NaN:16),
  Array.from({length:120},(_,i)=>i===20?0:16),
  Array.from({length:120},(_,i)=>i===20?Infinity:16),
  Array.from({length:120},(_,i)=>i===20?5001:16),
  Array.from({length:120},(_,i)=>i===20?-1:16),
]) {
  assert.throws(()=>summarizeRafIntervalsMs(bad),/interval|enough/i)
}
assert.equal(typeof perfect.metric_scope,'string')
assert.match(perfect.metric_scope,/NOT actual Godot\/GPU/)
console.log('R135 W12 frame-metric contract PASS: honest rAF pacing, 1% slowest, jank, invalid data rejected')
