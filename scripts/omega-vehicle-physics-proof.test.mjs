import test from 'node:test'
import assert from 'node:assert/strict'
import {PHYSICS_SCHEMA,verifyRealVehicleMovement} from './omega-vehicle-physics-proof.mjs'

function physics(extra={}) {
  return {
    schema:PHYSICS_SCHEMA,driving:true,car_driving:true,
    position:[-120,1.3,-104],yaw_rad:Math.PI/2,
    speed_mps:0,mileage_m:0,fuel:100,physics_frame:400,
    ...extra
  }
}
const before=physics()
const during=physics({position:[-122,1.3,-104],speed_mps:4.1,mileage_m:2,physics_frame:460,yaw_rad:1.61,fuel:99.9})
const after=physics({position:[-127,1.3,-105.8],speed_mps:6.2,mileage_m:7.7,physics_frame:521,yaw_rad:1.82,fuel:99.5})

test('original physics on a real street passes only for real moved, rotating, fueled car',()=>{
  const proof=verifyRealVehicleMovement(before,during,after)
  assert.equal(proof.real_godot_physics_verified,true)
  assert.ok(proof.actual_xz_displacement_m>7)
  assert.ok(proof.absolute_steering_yaw_rad>0.2)
  assert.ok(proof.original_physics_frames>100)
})
test('R50 false-green: gigantic screenshot scene diff but 0 km/h + N and zero displacement is rejected',()=>{
  assert.throws(()=>verifyRealVehicleMovement(
    before,physics({physics_frame:470}),physics({physics_frame:520})
  ),/speed/)
})
test('legitimate running browser cannot pass with missing original native telemetry',()=>{
  assert.throws(()=>verifyRealVehicleMovement({},during,after),/telemetry missing/)
  assert.throws(()=>verifyRealVehicleMovement({...before,driving:false},during,after),/NOT driving/)
})
test('UI/camera teleport, static car and unchanged odometer never qualify',()=>{
  assert.throws(()=>verifyRealVehicleMovement(before,during,{...after,mileage_m:0}),/odometer/)
  assert.throws(()=>verifyRealVehicleMovement(before,during,{...after,position:before.position}),/never traveled/)
  assert.throws(()=>verifyRealVehicleMovement(before,during,{...after,position:[-999,1,-999]}),/teleport/)
})
test('throttle and steer must be simultaneously reflected in authoritative yaw',()=>{
  assert.throws(()=>verifyRealVehicleMovement(before,during,{...after,yaw_rad:before.yaw_rad}),/Steering/)
  assert.doesNotThrow(()=>verifyRealVehicleMovement(before,during,{...after,yaw_rad:before.yaw_rad},{steering:false}))
})
test('renderer mock or frozen physics counter is not a driven game',()=>{
  assert.throws(()=>verifyRealVehicleMovement(before,{...during,physics_frame:before.physics_frame},after),/frames/)
  assert.throws(()=>verifyRealVehicleMovement(before,during,{...after,physics_frame:460}),/frames/)
})
