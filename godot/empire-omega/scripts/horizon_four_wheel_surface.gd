extends RefCounted
## HORIZON R21. Four real downward physics-ray wheel probes.
## This is contact-driven VISUAL suspension, not a rigid-body wheel torque solver.
## The CharacterBody3D remains the sole collision and road position authority.
const WHEEL_LATERAL: float = 1.34
const FRONT_Z: float = -1.75
const REAR_Z: float = 1.76
const WHEEL_RADIUS: float = 0.57
const MAX_COMPRESSION: float = 0.18
const MAX_DROOP: float = -0.10
const PROBE_UP: float = 0.75
const PROBE_DOWN: float = -1.35
const TRACK: float = WHEEL_LATERAL * 2.0
const WHEELBASE: float = REAR_Z-FRONT_Z
const WORLD_MASK: int = 1

static func _wheel_origins() -> Array[Vector3]:
	# Matches the order of horizon_vehicle_art.gd wheel rigs exactly:
	# left front, left rear, right front, right rear.
	return [
		Vector3(-WHEEL_LATERAL,0.0,FRONT_Z),
		Vector3(-WHEEL_LATERAL,0.0,REAR_Z),
		Vector3(WHEEL_LATERAL,0.0,FRONT_Z),
		Vector3(WHEEL_LATERAL,0.0,REAR_Z)
	]

static func probe(body: CollisionObject3D) -> Dictionary:
	var travels: Array[float] = []
	var grounded: Array[bool] = []
	var support_normals: Array[Vector3] = []
	var contact_points: Array[Vector3] = []
	if body == null or not body.is_inside_tree():
		for i in range(4):
			travels.append(MAX_DROOP)
			grounded.append(false)
			support_normals.append(Vector3.UP)
			contact_points.append(Vector3.ZERO)
		return {"travel":travels,"grounded":grounded,"normals":support_normals,"points":contact_points,"count":0}
	var state: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	var supported := 0
	for axle in _wheel_origins():
		var origin: Vector3 = body.to_global(axle)
		var begin: Vector3 = body.to_global(axle+Vector3(0.0,PROBE_UP,0.0))
		var end: Vector3 = body.to_global(axle+Vector3(0.0,PROBE_DOWN,0.0))
		var query := PhysicsRayQueryParameters3D.create(begin,end,WORLD_MASK)
		query.exclude = [body.get_rid()]
		query.collide_with_areas = false
		var impact: Dictionary = state.intersect_ray(query)
		var normal: Vector3 = impact.get("normal",Vector3.UP) if not impact.is_empty() else Vector3.UP
		var is_support: bool = not impact.is_empty() and normal.y > 0.45
		grounded.append(is_support)
		support_normals.append(normal if is_support else Vector3.UP)
		if is_support:
			contact_points.append(impact["position"])
			supported += 1
			var height: float = (impact["position"] as Vector3).y
			travels.append(clampf(height+WHEEL_RADIUS-(origin.y-0.28),MAX_DROOP,MAX_COMPRESSION))
		else:
			contact_points.append(origin-Vector3(0.0,WHEEL_RADIUS,0.0))
			# Wheel droops when unsupported instead of looking fully compressed.
			travels.append(MAX_DROOP)
	return {"travel":travels,"grounded":grounded,"normals":support_normals,"points":contact_points,"count":supported}

static func support_ratio(grounded: Array[bool]) -> float:
	if grounded.size()!=4:
		return 0.0
	var total: int = 0
	for value in grounded:
		if value:
			total += 1
	return float(total)/4.0

static func terrain_attitude(travels: Array[float], grounded: Array[bool] = []) -> Vector2:
	# Returns (roll around Z, pitch around X) in radians. Require
	# two opposing real wheel supports; unsupported wheels never
	# invent a road grade.
	if travels.size()!=4 or (not grounded.is_empty() and grounded.size()!=4):
		return Vector2.ZERO
	var support: Array[bool] = [true,true,true,true]
	if grounded.size()==4:
		support = grounded
	var left: float = 0.0
	var right: float = 0.0
	var front: float = 0.0
	var rear: float = 0.0
	var nl := 0
	var nr := 0
	var nf := 0
	var nb := 0
	for i in range(4):
		if not support[i] or not is_finite(travels[i]):
			continue
		var t: float = clampf(travels[i],MAX_DROOP,MAX_COMPRESSION)
		if i < 2:
			left += t
			nl += 1
		else:
			right += t
			nr += 1
		if i==0 or i==2:
			front += t
			nf += 1
		else:
			rear += t
			nb += 1
	var roll: float = atan2(left/float(nl)-right/float(nr),TRACK) if nl>0 and nr>0 else 0.0
	var pitch: float = atan2(front/float(nf)-rear/float(nb),WHEELBASE) if nf>0 and nb>0 else 0.0
	return Vector2(clampf(roll,-0.10,0.10),clampf(pitch,-0.075,0.075))

static func visual_travel(travel: float, supported: bool) -> float:
	return clampf(travel,MAX_DROOP,MAX_COMPRESSION) if supported and is_finite(travel) else MAX_DROOP
