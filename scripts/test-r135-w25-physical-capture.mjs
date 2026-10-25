#!/usr/bin/env node
import assert from 'node:assert/strict'
import { pinnedRelease, deviceCapturePlan } from './r135-w25-physical-capture.mjs'

const selector = {channel:'w20',
  pin_file:'scripts/r135-w20-release-pin.json',promotion_gate_run_id:40213913376}
const pin = {version:'r135-player-settings-w20-candidate-20261025',
  source_commit:'a'.repeat(40),manifest_sha256:'b'.repeat(64),
  archive_sha256:'c'.repeat(64),physical_phone_fps_verified:false}
const args = ['--platform','android-chrome','--orientation','portrait','--mode','ECO',
  '--cdp','http://127.0.0.1:9222','--out','real-android-eco.json',
  '--seconds','60','--physical-device-attested']
let tests = 0
const reject = (f, part) => {
  assert.throws(f, new RegExp(part), 'Unreviewed physical-device path unexpectedly accepted')
  tests++
}
const result = pinnedRelease(selector,pin)
assert.equal(result.source,pin.source_commit)
assert.equal(result.gate_run,selector.promotion_gate_run_id)
tests++
const plan = deviceCapturePlan(args,selector,pin)
assert.equal(plan.status,'HOLD_REQUIRES_PHYSICAL_INDEPENDENT_REVIEW')
assert.ok(plan.command.includes('--physical-device-attested'))
assert.ok(plan.command.includes(pin.source_commit))
assert.equal(plan.command[0],'scripts/r135-device-evidence.mjs')
tests++

reject(()=>pinnedRelease({...selector,channel:'w21'},pin),'selector')
reject(()=>pinnedRelease({...selector,promotion_gate_run_id:0},pin),'gate')
reject(()=>pinnedRelease({...selector,pin_file:'scripts/../evil.json'},pin),'selector')
reject(()=>pinnedRelease(selector,{...pin,physical_phone_fps_verified:true}),'preclaim')
reject(()=>pinnedRelease(selector,{...pin,source_commit:'malformed'}),'invalid')
reject(()=>deviceCapturePlan(args.filter(s=>s!=='--physical-device-attested'),selector,pin),'emulated')
reject(()=>deviceCapturePlan(args.map(s=>s==='android-chrome'?'iphone-safari':s),selector,pin),'Safari')
reject(()=>deviceCapturePlan(args.map(s=>s==='portrait'?'sideways':s),selector,pin),'orientation')
reject(()=>deviceCapturePlan(args.map(s=>s==='ECO'?'CINEMATIC':s),selector,pin),'orientation')
reject(()=>deviceCapturePlan(args.map(s=>s==='60'?'12':s),selector,pin),'duration')
reject(()=>deviceCapturePlan(args.map(s=>s==='60'?'350':s),selector,pin),'duration')
reject(()=>deviceCapturePlan(args.map(s=>s==='http://127.0.0.1:9222'?'https://127.0.0.1:9222':s),selector,pin),'locally forwarded')
reject(()=>deviceCapturePlan(args.map(s=>s==='http://127.0.0.1:9222'?'http://example.com:9222':s),selector,pin),'locally forwarded')
reject(()=>deviceCapturePlan(args.map(s=>s==='real-android-eco.json'?'real-android-eco.txt':s),selector,pin),'JSON')
reject(()=>deviceCapturePlan([...args,'--upload'],selector,pin),'upload')
assert.ok(!plan.command.some(x=>/w11-20261024|289a14960b/.test(x)),
  'Do not accidentally fall back to obsolete hardcoded W11 metrics')
tests++
console.log('W25 local physical capture selector security PASS:',tests,
  'cases; NO phone, GPU, battery or thermal metrics were measured.')
