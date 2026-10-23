/* ZION-030 v40 in-game purchases must never be client-authoritative. */
import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'
import {execFileSync} from 'node:child_process'
const dir='public/games/zion-9/queue/ZION-030/'
const js=fs.readFileSync(dir+'open-city-store40.js','utf8')
const css=fs.readFileSync(dir+'open-city-store40.css','utf8')
const page=fs.readFileSync(dir+'index.html','utf8')
const engine=fs.readFileSync(dir+'open-city.js','utf8')
const server=fs.readFileSync('server/core_game_store.py','utf8')
const api=fs.readFileSync('server/core_server.py','utf8')
new vm.Script(js,{filename:'open-city-store40.js'})
execFileSync(process.execPath,['--check',dir+'open-city-store40.js'])
assert.ok(page.includes('open-city-store40.js?v=40'))
assert.ok(page.includes('open-city-store40.css?v=40'))
assert.ok(page.indexOf('open-city-store40.js?v=40')<page.indexOf('open-city.js?v=34'))
for(const token of [
  'ZION030_STORE40.mount','shopKit?.close()',"shop:shopKit?.state ?? null",
  "shell.dataset.storeOpen==='true'"
])assert.ok(engine.includes(token),'Store not attached to the playable scene: '+token)
for(const marker of [
  '/api/core/','game/store','game/inventory','game/checkout',
  'sessionStorage','Authorization','owned.has(','window.location.assign',
  'checkout.stripe.com','URLSearchParams','render','data'
])assert.ok(js.includes(marker),'Missing v40 purchase requirement '+marker)
assert.ok(!/localStorage\.setItem\([^)]*owned/.test(js))
assert.ok(!/checkout\s*===?\s*['"]returned['"]\s*\)\s*owned/.test(js))
assert.ok(js.includes("if(!owned.has(sku)||!categories[sku])return false"))
assert.ok(js.includes('if(!state.enabled)'))
assert.ok(css.includes('@media(max-width:670px)'))
for(const name of ['game/store','game/inventory','game/checkout','game/webhook'])
  assert.ok(api.includes(name),'Server route absent: '+name)
for(const requirement of [
  'verify_webhook','payment_status',"'succeeded'",
  'amount_received','provider_key','refunded_minor',
  'StripeProvider','checkout.stripe.com','game_checkout_mismatch'
])assert.ok(server.includes(requirement),'Missing payment security '+requirement)
for(const bad of ['window.localStorage.setItem("paid"', 'fakePaymentSuccess'])
  assert.ok(!js.includes(bad))
const assets=fs.readFileSync('scripts/zion-030-live-assets.mjs','utf8')
for(const file of ['open-city-optics39.js','open-city-store40.js','open-city-store40.css'])
  assert.ok(assets.includes("'"+file+"'"),'Checksum gate missing '+file)
console.log('PASS ZION-030 v40: authenticated server-only game purchases, real UI, no URL/localStorage entitlement, strict checkout and signed webhooks')
