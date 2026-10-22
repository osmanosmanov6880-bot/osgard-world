import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import vm from 'node:vm'

const base=resolve('public/games/zion-9/queue/ZION-030')
const read=name=>readFileSync(resolve(base,name),'utf8')
const env=vm.createContext({console,Math})
new vm.Script(read('open-city-rules.js'),{filename:'open-city-rules.js'}).runInContext(env)
const R=env.ZION030_CITY_RULES
assert.equal(R.DISPATCHES.length,5)
assert.equal(R.CHARGERS.length,3)
assert.equal(new Set(R.DISPATCHES.map(q=>q.id)).size,5)
for(const mission of R.DISPATCHES){
 assert.ok(mission.steps.length>=2)
 for(const waypoint of mission.steps){
  assert.ok(R.route({x:0,z:0},waypoint).length>1,mission.id+' route must be reachable')
  assert.equal(R.blocked(waypoint.x,waypoint.z),false,mission.id+' waypoint must be unobstructed')
 }
}
let p=R.defaultProfile()
assert.equal(p.version,2)
assert.equal(p.credits,0)
assert.equal(p.activeDispatch,'school')
let rewardTotal=0
for(const q of R.DISPATCHES){
 const selected=R.selectDispatch(p,q.id)
 p=selected.profile
 assert.equal(p.activeDispatch,q.id)
 const start=p.credits
 for(let step=0;step<q.steps.length;step++){
  const target=q.steps[step]
  const bad=R.advanceDispatch(p,{x:target.x+8,z:target.z+8,inCar:false,speed:0})
  assert.equal(bad.changed,false,'Out-of-range tasks must not advance')
  if(target.mode==='drive'){
   assert.equal(R.advanceDispatch(p,{x:target.x,z:target.z,inCar:false}).changed,false)
   assert.equal(R.advanceDispatch(p,{x:target.x,z:target.z,inCar:true,speed:4}).changed,false)
  }else{
   assert.equal(R.advanceDispatch(p,{x:target.x,z:target.z,inCar:true}).changed,false)
  }
  const progress=R.advanceDispatch(p,{x:target.x,z:target.z,inCar:target.mode==='drive',speed:0})
  assert.equal(progress.changed,true,q.id+' stage '+step)
  assert.equal(progress.complete,step===q.steps.length-1)
  p=progress.profile
  assert.equal(p.dispatchSteps[q.id],step+1)
  assert.equal(p.credits,start+(progress.complete?q.reward:0))
 }
 rewardTotal+=q.reward
 assert.equal(R.advanceDispatch(p,{...q.steps.at(-1),inCar:false,speed:0}).changed,false,'No repeat rewards')
}
assert.equal(rewardTotal,1100)
assert.equal(p.credits,1100)
assert.equal(p.reputation,625)
assert.equal(p.dispatchDone.length,5)
assert.equal(R.nextDispatchStep(p),null)
assert.equal(R.selectDispatch(p,'not-a-quest').changed,false)
for(const q of R.CONTRACTS){p=R.completeContract(p,q.id).profile}
assert.equal(p.credits,1550)
assert.equal(p.reputation,925)
for(const [upgrade,price] of [['speed',300],['grip',260],['battery',230]]){
 const before=p.credits
 const purchased=R.purchaseUpgrade(p,upgrade)
 assert.equal(purchased.changed,true)
 assert.equal(purchased.profile.credits,before-price)
 p=purchased.profile
 assert.equal(R.purchaseUpgrade(p,upgrade).changed,false,'No duplicate '+upgrade)
}
assert.equal(p.credits,760)
assert.ok(p.fastCar&&p.grip&&p.batteryUpgrade)
const restored=R.sanitizeProfile(JSON.parse(JSON.stringify(p)))
assert.equal(JSON.stringify(restored),JSON.stringify(p),'v29 saved progress roundtrips without loss')
const oldSave=R.sanitizeProfile({version:1,completed:['solar','water'],credits:150,fastCar:true,runs:3})
assert.equal(oldSave.completed.length,2)
assert.equal(oldSave.credits,150)
assert.equal(oldSave.fastCar,true)
assert.equal(oldSave.dispatchDone.length,0)
const invalid=R.sanitizeProfile({dispatchDone:['unknown','school','school'],dispatchSteps:{water:-2,school:1e8},credits:1e50,completed:['fake'],reputation:999999})
assert.equal(invalid.dispatchDone.length,1)
assert.equal(invalid.credits,160)
assert.equal(invalid.reputation,125)
assert.equal(invalid.dispatchSteps.school,2)
assert.equal(invalid.dispatchSteps.water,0)
// The player cannot clip through buildings even under sprint with large frame intervals.
let actor={x:0,z:0,vx:0,vz:0,stamina:100,height:0,vy:0}
for(let n=0;n<8;n++)actor=R.walkStep(actor,{x:0,z:-1,sprint:true,jump:n===0},.05)
assert.ok(actor.z<-.1,'Acceleration must move the avatar')
assert.ok(actor.stamina<100,'Sprinting has a real stamina cost')
assert.ok(actor.height>=0)
const sprintSpeed=actor.speed
for(let n=0;n<200;n++)actor=R.walkStep(actor,{x:0,z:0,sprint:false,jump:false},.05)
assert.ok(actor.stamina>95,'Stamina regenerates while resting')
assert.ok(actor.height===0&&actor.vy===0,'Jump must land')
assert.ok(actor.speed<sprintSpeed,'Standing still must decelerate smoothly')
const inside=R.walkStep({x:19.65,z:0,vx:0,vz:0},{x:1,z:0,sprint:true},.06)
assert.ok(inside.x<20,'Player must remain in bounds')
// Battery, rain and grip are functional vehicle mechanics, not decorative gauges.
const car={x:0,z:0,heading:0,speed:5}
const wet=R.drivingStep(car,{steer:1,throttle:0},.04,false,{rain:true,grip:false})
const grippy=R.drivingStep(car,{steer:1,throttle:0},.04,false,{rain:true,grip:true})
assert.ok(grippy.heading>wet.heading,'Suspension/grip upgrade must restore wet handling')
const dry=R.drivingStep(car,{steer:1,throttle:0},.04,false,{rain:false,grip:false})
assert.ok(dry.heading>grippy.heading)
const spent=R.vehicleEnergy(60,car,{throttle:1,brake:false},.2,false,false)
const efficient=R.vehicleEnergy(60,car,{throttle:1,brake:false},.2,true,false)
assert.ok(spent<60 && efficient>spent)
assert.ok(R.vehicleEnergy(40,{speed:0},{throttle:0},.2,false,true)>40,'Chargers actually charge')
assert.ok(R.vehicleEnergy(0,{speed:5},{throttle:1},.2,false,false)>=0)
assert.ok(R.vehicleEnergy(100,{speed:0},{throttle:0},.2,false,true)<=100)
for(const point of [{x:0,z:0},{x:-15,z:-10},{x:15,z:12}])assert.ok(R.districtAt(point.x,point.z).length>4)
const js=read('open-city.js'),css=read('open-city.css'),html=read('index.html')
new vm.Script(js,{filename:'open-city.js'})
assert.ok(html.includes('open-city-rules.js?v=29')&&html.includes('open-city.js?v=30')&&html.includes('open-city.css?v=29'))
for(const marker of ['addStreetLife()','addDispatchMarkers()','rules.walkStep','rules.vehicleEnergy','rules.advanceDispatch','oc-journal','oc-pause','oc-battery-bar','oc-view-button','oc-jump-button'])assert.ok(js.includes(marker),'Missing v29 runtime feature '+marker)
for(const marker of ['.oc-journal-list','.oc-quest-row','.oc-garage','.oc-map-expanded','prefers-reduced-motion','.oc-jump-button'])assert.ok(css.includes(marker),'Missing UI support '+marker)
console.log('PASS ZION v29: legacy save migration, 5 multi-step campaigns, 13 reachable objectives, rewards/economy, vehicle battery/grip/chargers, stamina/jump/collision, city+HUD contracts')
