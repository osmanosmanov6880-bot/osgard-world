extends RefCounted
## CITY REIGN R188 — original actual CharacterBody3D traffic now MOVES
## in the SAME yaw direction as its native chassis. The former source
## jumped the entire velocity vector instantly at every 90-degree corner,
## while the actual 3D body only visually interpolated its facing: a
## physical sideways-slide artifact on R185's true 2m right-hand lanes.
##
## The original A*, 52m road graph, original R178 stop lines, R186 boxed
## intersections, R47 pedestrians and Godot collision response have
## STRICT PRIORITY. This module changes ONLY native ambient-car steering.
## No teleport, new road graph, physics bodies, saved schema or network.
const LANES=preload("res://scripts/city_reign_vehicle_lane_routing.gd")
const SIGNAL=preload("res://scripts/city_reign_intersection_policy.gd")
const SOURCE_ROAD_SPACING_M: float=52.0
const ANTICIPATE_CORNER_M: float=5.6
const CORNER_FORWARD_AIM_M: float=2.35
const MIN_CORNER_ANGLE_RAD: float=0.66
const MAX_CORNER_ANGLE_RAD: float=2.27
const MAX_YAW_RATE_RAD_S: float=1.90
const LATERAL_GRIP_ACCEL_MPS2: float=13.2
const MAX_FRAME_STEP_S: float=0.10
const WHEEL_STEER_SCALE: float=0.62
const MAX_FRONT_WHEEL_RAD: float=0.45
const ORIGINAL_VEHICLE_HALF_WIDTH_M: float=1.125
const ORIGINAL_VEHICLE_HALF_LENGTH_M: float=2.05
const SOURCE_ROAD_CLEAR_HALF_M: float=3.82
const LOOKAHEAD_EPSILON_M2: float=0.0001

static func yaw_of(vector: Vector3) -> float:
	if not vector.is_finite() or Vector2(vector.x,vector.z).length_squared()<0.0001:
		return 0.0
	return atan2(-vector.x,-vector.z)

static func source_road_footprint_safe(point: Vector3,
		facing: Vector3=Vector3.ZERO) -> bool:
	if (not point.is_finite() or not facing.is_finite() or
		not LANES.on_original_asphalt(point)):
		return false
	# Native BoxShape3D 2.25m x 4.1m: BOTH safe body centre margin
	# AND FOUR physical rotated corners must be inside the original
	# 10m cross-shaped asphalt, not merely the wheelbase centre.
	var center_clear: bool=false
	for index in range(9):
		var at: float=-208.0+float(index)*SOURCE_ROAD_SPACING_M
		if (absf(point.x-at)<=SOURCE_ROAD_CLEAR_HALF_M or
				absf(point.z-at)<=SOURCE_ROAD_CLEAR_HALF_M):
			center_clear=true
			break
	if not center_clear:return false
	var axis:=Vector3(facing.x,0.0,facing.z)
	if axis.length_squared()<LOOKAHEAD_EPSILON_M2:
		return true # fixture / waypoint check with no known orientation
	axis=axis.normalized()
	var sideways:=Vector3(-axis.z,0.0,axis.x)
	for front in [-1.0,1.0]:
		for side in [-1.0,1.0]:
			var actual_corner: Vector3=(point+
				axis*ORIGINAL_VEHICLE_HALF_LENGTH_M*front+
				sideways*ORIGINAL_VEHICLE_HALF_WIDTH_M*side)
			if not LANES.on_original_asphalt(actual_corner):
				return false
	return true

static func source_aim(position: Vector3,destination: Vector3,
		next_waypoint: Vector3) -> Vector3:
	if (not position.is_finite() or not destination.is_finite() or
			not next_waypoint.is_finite()):
		return destination
	var approaching: Vector3=destination-position
	approaching.y=0.0
	var remaining: float=approaching.length()
	if remaining<0.25 or remaining>ANTICIPATE_CORNER_M:
		return destination
	var next_leg: Vector3=next_waypoint-destination
	next_leg.y=0.0
	if next_leg.length_squared()<LOOKAHEAD_EPSILON_M2:
		return destination
	# No added target if the original A* source does not provide a
	# true 90-degree turn. Straight and impossible U-turn routes stay
	# exactly the same. The original turn vertex is NOT removed.
	var dot: float=approaching.normalized().dot(next_leg.normalized())
	var bend: float=acos(clampf(dot,-1.0,1.0))
	if bend<MIN_CORNER_ANGLE_RAD or bend>MAX_CORNER_ANGLE_RAD:
		return destination
	if not source_road_footprint_safe(destination):
		return destination
	var part: float=clampf(1.0-remaining/ANTICIPATE_CORNER_M,0.0,1.0)
	var desired: Vector3=destination+next_leg.normalized()*part*CORNER_FORWARD_AIM_M
	if not source_road_footprint_safe(desired):
		return destination
	return desired

static func steer(current_yaw: float,position: Vector3,target: Vector3,
		speed: float,delta: float,wetness: float) -> Dictionary:
	if (not is_finite(current_yaw) or not position.is_finite() or
		not target.is_finite() or not is_finite(speed) or
		not is_finite(delta) or not is_finite(wetness) or delta<=0.0):
		return {"valid":false}
	var intended: Vector3=target-position
	intended.y=0.0
	if intended.length_squared()<LOOKAHEAD_EPSILON_M2:
		return {"valid":false}
	var wanted: float=yaw_of(intended)
	var diff: float=wrapf(wanted-current_yaw,-PI,PI)
	# True wet traction and actual current speed bound lateral turning:
	# a fast native car cannot rotate ninety degrees in one physics tick.
	var grip: float=clampf(wetness,0.4,1.0)
	var permitted: float=minf(MAX_YAW_RATE_RAD_S,
		LATERAL_GRIP_ACCEL_MPS2*grip/maxf(2.0,absf(speed)))
	var max_delta: float=permitted*clampf(delta,0.0,MAX_FRAME_STEP_S)
	var actual_delta: float=clampf(diff,-max_delta,max_delta)
	var new_yaw: float=wrapf(current_yaw+actual_delta,-PI,PI)
	var forward:=Vector3(-sin(new_yaw),0.0,-cos(new_yaw))
	var wheel_angle: float=clampf(diff*WHEEL_STEER_SCALE,
		-MAX_FRONT_WHEEL_RAD,MAX_FRONT_WHEEL_RAD)
	return {"valid":true,"yaw":new_yaw,"direction":forward,
		"wheel_radians":wheel_angle,"actual_yaw_step":actual_delta,
		"source_error":diff,"angular_limit":permitted}

static func safe_next_step(position: Vector3,heading: Vector3,
		speed: float,delta: float) -> bool:
	if (not position.is_finite() or not heading.is_finite() or
		not is_finite(speed) or not is_finite(delta) or
		delta<0.0):
		return false
	if not source_road_footprint_safe(position,heading):
		return false
	var step: Vector3=heading*maxf(0.0,speed)*clampf(delta,0.0,MAX_FRAME_STEP_S)
	return source_road_footprint_safe(position+step,heading)

static func source_integrity() -> bool:
	return (LANES.source_integrity() and SIGNAL.source_grid_valid() and
		LANES.RIGHT_LANE_OFFSET_M>ORIGINAL_VEHICLE_HALF_WIDTH_M and
		SOURCE_ROAD_CLEAR_HALF_M+ORIGINAL_VEHICLE_HALF_WIDTH_M<
			SIGNAL.ROAD_HALF_WIDTH_M+0.01 and
		ANTICIPATE_CORNER_M<LANES.RIGHT_LANE_OFFSET_M*3.0 and
		MAX_FRONT_WHEEL_RAD<0.52 and
		MAX_FRAME_STEP_S==0.1)
