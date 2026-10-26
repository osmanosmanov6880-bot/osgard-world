// R70: prove real CharacterBody3D movement, not camera pixels, HUD changes,
// mock coordinates, CSS transitions or Godot splash screen.
export const PHYSICS_SCHEMA = 'empire-omega-r70-actual-vehicle-physics-v1'

function checkState(value, label) {
  if(!value || typeof value!=='object' || value.schema!==PHYSICS_SCHEMA)
    throw new Error(label+': original Godot R70 telemetry missing')
  if(value.driving!==true || value.car_driving!==true)
    throw new Error(label+': player is NOT driving the actual car')
  if(!Array.isArray(value.position)||value.position.length!==3||
    !value.position.every(x=>typeof x==='number' && Number.isFinite(x)))
    throw new Error(label+': invalid original physics position')
  for(const k of ['speed_mps','mileage_m','fuel','yaw_rad','physics_frame']){
    if(typeof value[k]!=='number' || !Number.isFinite(value[k]))
      throw new Error(label+': invalid original physics '+k)
  }
  if(value.mileage_m<0 || value.fuel<0 || value.fuel>100 ||
     value.physics_frame<0)
    throw new Error(label+': impossible authoritative simulation state')
}

export function physicalDistanceXZ(a,b) {
  return Math.hypot(a.position[0]-b.position[0],a.position[2]-b.position[2])
}

export function signedHeadingDifference(a,b) {
  const diff=b.yaw_rad-a.yaw_rad
  return Math.atan2(Math.sin(diff),Math.cos(diff))
}

export function verifyRealVehicleMovement(before,during,after,{steering=true}={}) {
  checkState(before,'before')
  checkState(during,'during')
  checkState(after,'after')
  if(!(before.physics_frame<during.physics_frame &&
       during.physics_frame<after.physics_frame &&
       after.physics_frame-before.physics_frame>=35))
    throw new Error('Not enough original Godot physics frames: no real timed driving')
  const displacement=physicalDistanceXZ(before,after)
  const distanceDuring=physicalDistanceXZ(before,during)
  const mileageDelta=after.mileage_m-before.mileage_m
  const speedDuring=Math.abs(during.speed_mps)
  const speedAfter=Math.abs(after.speed_mps)
  const yawDelta=Math.abs(signedHeadingDifference(before,after))
  if(speedDuring<=1.2 || speedAfter<=1.2)
    throw new Error('Car did not accelerate to true speed while input was held (not screen animation)')
  if(distanceDuring<=0.4 || displacement<=2)
    throw new Error('Real car never traveled >2m in X/Z (likely blocked by world collider)')
  if(mileageDelta<=1.2)
    throw new Error('Actual authoritative physical odometer did not advance')
  if(displacement>70 || mileageDelta>70)
    throw new Error('Unrealistic jump/teleport counted as physical movement')
  if(steering && yawDelta<=0.055)
    throw new Error('Steering did not cause measured real vehicle heading change')
  if(after.fuel>before.fuel+0.001)
    throw new Error('Driving unexpectedly created fuel')
  return {
    schema: 'empire-omega-r70-real-drive-evidence-v1',
    real_godot_physics_verified:true,
    screenshot_motion_alone_not_accepted:true,
    original_physics_frames:after.physics_frame-before.physics_frame,
    actual_xz_displacement_m:displacement,
    actual_odometer_advance_m:mileageDelta,
    during_throttle_speed_mps:speedDuring,
    after_held_control_speed_mps:speedAfter,
    absolute_steering_yaw_rad:yawDelta,
    remaining_fuel:after.fuel,
    real_position_before:before.position,
    real_position_after:after.position
  }
}
