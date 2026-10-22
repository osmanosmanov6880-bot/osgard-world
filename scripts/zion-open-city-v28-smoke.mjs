import assert from 'node:assert/strict'
import { readFileSync, existsSync } from 'node:fs'
import { resolve } from 'node:path'
import vm from 'node:vm'

const root = resolve('public/games/zion-9/queue/ZION-030')
const read = name => readFileSync(resolve(root, name), 'utf8')
const context = vm.createContext({ console, Math })
const rulesSource = read('open-city-rules.js')
new vm.Script(rulesSource, { filename: 'open-city-rules.js' }).runInContext(context)
const R = context.ZION030_CITY_RULES
assert.ok(R, 'Deterministic rules must expose a browser-safe API')
assert.equal(R.HOTSPOTS.length, 3)
assert.equal(R.CONTRACTS.length, 3)
for (const p of [...R.HOTSPOTS, ...R.CONTRACTS]) {
  assert.equal(R.blocked(p.x, p.z), false, p.name + ' must be walkable')
  assert.ok(R.route({ x: 0, z: 0 }, p).length > 1, p.name + ' must be reachable')
}
// The original cooling puzzle has an exact deterministic building footprint.
const legacyRand = (x, z) => { const n = Math.sin(x * 127.1 + z * 311.7 + 74.7) * 43758.5453; return n - Math.floor(n) }
for (let x = -7; x <= 7; x++) for (let z = -7; z <= 7; z++) {
  const original = Math.abs(x) > 2 || Math.abs(z) > 2
    ? Math.abs(x) <= 6 && Math.abs(z) <= 6 && R.HOTSPOTS.every(h => Math.hypot(h.x - x, h.z - z) >= 1.55) && legacyRand(x, z) >= .49
    : false
  assert.equal(R.buildingAt(x, z), original, `Original map changed at ${x},${z}`)
}
for (const [x, z] of [[-25, 0], [0, -25], [25, 0], [0, 25], [NaN, 1]]) assert.equal(R.blocked(x, z), true)
for (const [x, z] of [[0, 10], [-10, 0], [15, 5], [5, -15]]) assert.equal(R.buildingAt(x, z), false, 'Arterial streets must be clear')
// Driving is deterministic, frames are capped, steering and collision cannot leave the level.
let car = { x: 10, z: 10, heading: 0, speed: 0 }
for (let n = 0; n < 80; n++) car = R.drivingStep(car, { throttle: 1, steer: 0 }, .05)
assert.ok(car.speed > 4.0)
assert.ok(car.z < 4 && car.z > -20, `Vehicle moved ${car.z}`)
car = { x: 0, z: 0, heading: 0, speed: 2 }
const turned = R.drivingStep(car, { throttle: 1, steer: 1 }, .05)
assert.ok(turned.heading > 0, 'Steering must change heading')
const stop = R.drivingStep(car, { throttle: 0, steer: 0, brake: true }, .05)
assert.ok(stop.speed < car.speed, 'Brake must decelerate')
const crash = R.drivingStep({ x: 0, z: -19.50, heading: 0, speed: 8 }, { throttle: 1, steer: 0 }, .06)
assert.ok(crash.collision && crash.speed === 0, 'Out-of-world collision must stop vehicle')
const economical = R.drivingStep({ x: 0, z: 0, heading: 0, speed: 8 }, { throttle: 1, steer: 0 }, .06)
assert.ok(economical.speed <= 7.1)
const upgraded = R.drivingStep({ x: 0, z: 0, heading: 0, speed: 8 }, { throttle: 1, steer: 0 }, .06, true)
assert.ok(upgraded.speed > economical.speed, 'Purchased upgrade improves top speed')
// Rewards are idempotent; corrupted/stale storage cannot invent completed contracts.
let profile = R.defaultProfile()
assert.equal(profile.credits, 0)
for (const contract of R.CONTRACTS) {
  const award = R.completeContract(profile, contract.id)
  assert.equal(award.changed, true)
  profile = award.profile
  const duplicate = R.completeContract(profile, contract.id)
  assert.equal(duplicate.changed, false)
  assert.equal(duplicate.profile.credits, profile.credits)
}
assert.equal(profile.completed.length, 3)
assert.equal(profile.credits, 450)
assert.equal(profile.reputation, 300)
const purchase = R.purchaseUpgrade(profile)
assert.equal(purchase.changed, true)
assert.equal(purchase.profile.credits, 150)
assert.equal(purchase.profile.fastCar, true)
assert.equal(R.purchaseUpgrade(purchase.profile).changed, false)
assert.equal(R.completeContract(purchase.profile, 'not-a-contract').changed, false)
const malicious = R.sanitizeProfile({ completed: ['fake', 'solar', 'solar'], credits: 1e99, reputation: 1e99, fastCar: true })
assert.equal(malicious.completed.length, 1)
assert.equal(malicious.reputation, 100)
assert.ok(malicious.credits <= 450)
// Asset wiring and minimum functioning scenes, never a painted screenshot.
const script = read('open-city.js'), css = read('open-city.css'), html = read('index.html')
new vm.Script(script, { filename: 'open-city.js' })
assert.ok(html.includes('open-city-rules.js?v=28') && html.includes('open-city.js?v=28') && html.includes('open-city.css?v=28'))
assert.ok(script.includes('new THREE.WebGLRenderer') && script.includes('new THREE.PerspectiveCamera'))
assert.ok(script.includes('new THREE.InstancedMesh') && script.includes('createCar(') && script.includes('makePerson('))
assert.ok(script.includes('rules.drivingStep') && script.includes('rules.route('))
assert.ok(script.includes('person.nextPlanAt'), 'NPC replanning must be throttled if a route fails')
assert.ok(script.includes('toggleNavigation') && script.includes('oc-nav-mode'), 'Players must be able to route toward side contracts')
assert.ok(script.includes("world.quality === 'eco' ? .64"), 'ECO render scaling must work on touch devices')
assert.ok(script.includes('game().place(dest.x, dest.z, state.selected)'), 'Original cooling action must remain authoritative')
assert.ok(script.includes('localStorage.setItem') && script.includes('completeNearbyContract'))
assert.ok(css.includes('.oc-contract') && css.includes('.oc-drive-hud') && css.includes('@media(max-width:760px)'))
assert.ok(css.includes('prefers-reduced-motion:reduce'))
assert.ok(existsSync(resolve(root, 'open-city-rules.js')))
console.log('PASS ZION-030 v28: legacy grid preserved, all six locations reachable, driving/collisions, rewards/upgrade persistence, source parsing and asset wiring')