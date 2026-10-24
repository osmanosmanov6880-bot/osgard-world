extends RefCounted
## HORIZON R14: one camera target and a true collision-safe follow step.
## The existing R10 world, player and car own their physics; this module
## changes only the viewing position and never modifies vehicle velocity.
const MASK_STATIC_WORLD: int = 1
const WALL_CLEARANCE: float = 0.48
const MIN_FOCUS_DISTANCE: float = 0.08
const MIN_VIEW_DISTANCE: float = 0.10
const MAX_FRAME_SECONDS: float = 1.0 / 20.0

static func portrait(viewport: Vector2) -> bool:
	return viewport.x >= 280.0 and viewport.y > viewport.x * 1.12

static func follow_rate(speed: float, portrait_mode: bool) -> float:
	# A 0.35/sec mobile chase yaw let the car leave portrait framing after a
	# turn. Catch up in roughly half a second while avoiding snap rotations.
	var v: float = absf(speed) if is_finite(speed) else 0.0
	return (1.75 if portrait_mode else 1.30) + minf(v/28.0,1.0)*0.95

static func desired_position(focus: Vector3, yaw: float, pitch: float,
		speed: float, driving: bool, viewport: Vector2) -> Vector3:
	var is_phone: bool = portrait(viewport)
	var raw_speed: float = absf(speed) if is_finite(speed) else 0.0
	var distance: float = (10.2 if is_phone else 12.0) + minf(raw_speed * 0.12, 3.4) if driving else (6.3 if is_phone else 7.2)
	var angle: float = clampf(pitch,0.08,1.18)
	return focus + Vector3(sin(yaw) * cos(angle) * distance,
		sin(angle) * distance + 1.0,
		cos(yaw) * cos(angle) * distance)

static func _cast(focus: Vector3, endpoint: Vector3, space: PhysicsDirectSpaceState3D,
		excludes: Array[RID]) -> Dictionary:
	if focus.distance_squared_to(endpoint) < 0.000001:
		return {}
	var query := PhysicsRayQueryParameters3D.create(focus,endpoint)
	query.collision_mask = MASK_STATIC_WORLD
	query.exclude = excludes
	query.collide_with_areas = false
	query.hit_from_inside = false
	return space.intersect_ray(query)

static func _safe_point(focus: Vector3, wanted: Vector3, hit: Dictionary) -> Vector3:
	if hit.is_empty():
		return wanted
	var delta: Vector3 = wanted - focus
	var direction: Vector3 = delta.normalized()
	var hit_distance: float = focus.distance_to(hit["position"])
	var safe_distance: float = maxf(MIN_FOCUS_DISTANCE,hit_distance-WALL_CLEARANCE)
	return focus + direction * safe_distance

static func solve(focus: Vector3, ideal: Vector3, previous: Vector3,
		space: PhysicsDirectSpaceState3D, excludes: Array[RID], dt: float,
		reduced_motion: bool = false) -> Dictionary:
	if not focus.is_finite() or not ideal.is_finite() or not previous.is_finite():
		return {"position":focus,"occluded":true,"distance":0.0}
	var first: Dictionary = _cast(focus,ideal,space,excludes)
	var safe: Vector3 = _safe_point(focus,ideal,first)
	# Contraction must be prompt to avoid buildings sweeping through camera.
	# Expansion is slower and has a separate final visibility check.
	var seconds: float = clampf(dt,0.0,MAX_FRAME_SECONDS)
	var follow: float = 1.0 if reduced_motion else clampf(seconds * (24.0 if not first.is_empty() else 7.0),0.0,1.0)
	var next: Vector3 = previous.lerp(safe,follow)
	# Even when the TARGET is collision free, interpolation from an older
	# chase direction can tunnel across a wall. This second ray is essential.
	var second: Dictionary = _cast(focus,next,space,excludes)
	if not second.is_empty():
		next = _safe_point(focus,next,second)
	# Floating point clamp to prevent degenerate look-at positions.
	if next.distance_squared_to(focus) < MIN_VIEW_DISTANCE * MIN_VIEW_DISTANCE:
		var direction: Vector3 = (ideal-focus).normalized()
		if direction.length_squared() < 0.0001:
			direction = Vector3(0,0,1)
		next = focus + direction * MIN_VIEW_DISTANCE
	var blocked: bool = not first.is_empty() or not second.is_empty()
	return {"position":next,"occluded":blocked,"distance":focus.distance_to(next)}

## HORIZON R20: composition and motion control, with no physics authority.
## Give the road a little more screen room at speed without making the car
## disappear from the tall-phone viewport. The lookahead is capped in metres.
static func look_ahead_focus(vehicle_position: Vector3, heading: float,
		speed: float, yaw_rate: float, viewport: Vector2, reduced_motion: bool) -> Vector3:
	var base: Vector3 = vehicle_position + Vector3(0.0,2.0,0.0)
	if not base.is_finite() or not is_finite(heading) or not is_finite(speed) or not is_finite(yaw_rate):
		return base if base.is_finite() else Vector3(0.0,2.0,0.0)
	if reduced_motion:
		return base
	var ahead: float = clampf((absf(speed)-5.0)*0.060,0.0,1.40)
	if portrait(viewport):
		ahead *= 0.75
	var lateral: float = clampf(yaw_rate*absf(speed)*0.030,-0.45,0.45)
	var forward: Vector3 = Vector3(-sin(heading),0.0,-cos(heading))
	var right: Vector3 = Vector3(cos(heading),0.0,-sin(heading))
	var travel_direction: float = -1.0 if speed < -0.35 else 1.0
	return base + forward*ahead*travel_direction + right*lateral

static func target_fov(speed: float, driving: bool, portrait_mode: bool,
		reduced_motion: bool) -> float:
	if not driving or reduced_motion:
		return 76.0
	var safe_speed: float = absf(speed) if is_finite(speed) else 0.0
	var base: float = 75.0 if portrait_mode else 77.0
	# Earlier chase view reached 88 degrees and exaggerated peripheral motion.
	# Keep a restrained speed cue without a fish-eye view or motion sickness.
	return clampf(base+minf(safe_speed*0.20,6.0),75.0,83.0)

static func time_alpha(response: float, dt: float) -> float:
	if not is_finite(response) or not is_finite(dt) or dt <= 0.0:
		return 0.0
	return 1.0-exp(-clampf(dt,0.0,0.10)*clampf(response,0.0,25.0))
