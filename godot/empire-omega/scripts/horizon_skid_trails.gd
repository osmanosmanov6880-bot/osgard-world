extends Node3D
## HORIZON R22: inexpensive grounded rear-tyre skid trails in real game world.
## One recycled MultiMesh with bounded 96 quads, no per-frame mesh allocation.
## Effects have zero authority over physics, scoring, controls or persistence.
const SURFACE = preload("res://scripts/horizon_four_wheel_surface.gd")
const TIRE = preload("res://scripts/horizon_tire_model.gd")
const CAPACITY: int = 96
const LIFETIME: float = 14.0
const MIN_SEGMENT: float = 0.22
const MAX_SEGMENT: float = 1.65
const WHEEL_INDICES = [1,3] # Rear left and rear right, aligned with R21 contact order.

var marks_mesh: MultiMeshInstance3D
var _ring: MultiMesh
var _write: int = 0
var _filled: int = 0
var _lifetimes: Array[float] = []
var _opacity: Array[float] = []
var _has_last: Array[bool] = [false,false]
var _last: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
var _age_accumulator: float = 0.0
var emitted_segments: int = 0

func _ready() -> void:
	name = "HorizonSkidMarkPool"
	var track := PlaneMesh.new()
	track.size = Vector2(0.17,1.0)
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color("18232b")
	rubber.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rubber.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rubber.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring = MultiMesh.new()
	_ring.transform_format = MultiMesh.TRANSFORM_3D
	_ring.use_colors = true
	_ring.mesh = track
	_ring.instance_count = CAPACITY
	_ring.visible_instance_count = 0
	_ring.custom_aabb = AABB(Vector3(-320.0,-10.0,-320.0),Vector3(640.0,30.0,640.0))
	marks_mesh = MultiMeshInstance3D.new()
	marks_mesh.name = "GroundedRearTyreMultiMesh"
	marks_mesh.multimesh = _ring
	marks_mesh.material_override = rubber
	add_child(marks_mesh)
	for i in range(CAPACITY):
		_lifetimes.append(0.0)
		_opacity.append(0.0)

static func drift_eligible(speed: float, lateral: float, handbrake: bool) -> bool:
	if not is_finite(speed) or not is_finite(lateral) or absf(speed) < 8.0:
		return false
	var slip: float = TIRE.slip_angle_degrees(speed,lateral)
	return slip >= (4.0 if handbrake else 9.0)

static func mark_opacity(road_grip: float) -> float:
	var safe_grip: float = clampf(road_grip if is_finite(road_grip) else 1.0,0.35,1.15)
	return 0.25 if safe_grip < 0.75 else (0.31 if safe_grip < 0.92 else 0.42)

func _break_streak() -> void:
	_has_last[0] = false
	_has_last[1] = false

func _age_marks(dt: float) -> void:
	if not is_finite(dt) or dt <= 0.0:
		return
	_age_accumulator += minf(dt,0.5)
	if _age_accumulator < 0.22:
		return
	var elapsed: float = _age_accumulator
	_age_accumulator = 0.0
	for i in range(_filled):
		if _lifetimes[i] <= 0.0:
			continue
		_lifetimes[i] = maxf(0.0,_lifetimes[i]-elapsed)
		var fade: float = clampf(_lifetimes[i]/1.7,0.0,1.0)
		_ring.set_instance_color(i,Color(1.0,1.0,1.0,_opacity[i]*fade))

func active_marks() -> int:
	var total := 0
	for i in range(_filled):
		if _lifetimes[i] > 0.0:
			total += 1
	return total

func _record_track(side: int, world_contact: Vector3, strength: float, spacing: float,
		road_normal: Vector3 = Vector3.UP) -> bool:
	if not world_contact.is_finite():
		_has_last[side] = false
		return false
	var normal: Vector3 = road_normal.normalized() if road_normal.is_finite() and road_normal.length_squared()>0.25 else Vector3.UP
	if normal.y<0.45:
		normal = Vector3.UP
	var next: Vector3 = world_contact+normal*0.028
	if not _has_last[side]:
		_last[side] = next
		_has_last[side] = true
		return false
	var previous: Vector3 = _last[side]
	var travel: Vector3 = next-previous
	var distance: float = Vector2(travel.x,travel.z).length()
	if distance < spacing:
		return false
	_last[side] = next
	if distance > MAX_SEGMENT:
		# A teleport, respawn or physics jump must never draw a long rubber line.
		return false
	var center: Vector3 = previous.lerp(next,0.5)
	# R166: align original pooled skid quads to the measured physical
	# asphalt normal, rather than drawing horizontal floating decals on
	# sloped roads. Keep the exact original instance ring and quad mesh.
	var projected: Vector3 = travel-normal*travel.dot(normal)
	if projected.length_squared()<0.0001:
		return false
	var forward: Vector3 = projected.normalized()
	var lateral: Vector3 = normal.cross(forward).normalized()
	var transform := Transform3D(Basis(lateral,normal,forward*distance),center)
	_ring.set_instance_transform(_write,transform)
	_ring.set_instance_color(_write,Color(1.0,1.0,1.0,strength))
	_lifetimes[_write] = LIFETIME
	_opacity[_write] = strength
	_write = (_write+1)%CAPACITY
	_filled = mini(_filled+1,CAPACITY)
	_ring.visible_instance_count = _filled
	emitted_segments += 1
	return true

func update_trails(vehicle: CharacterBody3D, driving: bool, quality: String, dt: float) -> int:
	if _ring == null:
		return 0
	_age_marks(dt)
	if marks_mesh != null:
		marks_mesh.visible = quality != "low"
	if not driving or vehicle == null or quality == "low":
		_break_streak()
		return 0
	var speed: float = float(vehicle.get("speed"))
	var lateral: float = float(vehicle.get("lateral_speed"))
	var handbrake: bool = bool(vehicle.get("handbrake_on"))
	if not drift_eligible(speed,lateral,handbrake):
		_break_streak()
		return 0
	var cached: Variant = vehicle.get("last_wheel_support")
	var sampled: Dictionary = cached if cached is Dictionary and vehicle.is_physics_processing() else {}
	if sampled.is_empty() or not sampled.has("points"):
		sampled = SURFACE.probe(vehicle)
	var grounded: Array[bool] = sampled["grounded"]
	var points: Array[Vector3] = sampled["points"]
	var normals: Array[Vector3] = sampled["normals"]
	var strength: float = mark_opacity(float(vehicle.get("traction_factor")))
	var spacing: float = 0.30 if quality == "standard" else MIN_SEGMENT
	var count := 0
	for side in range(2):
		var wheel_index: int = WHEEL_INDICES[side]
		if wheel_index>=grounded.size() or not grounded[wheel_index]:
			_has_last[side] = false
			continue
		var normal: Vector3 = normals[wheel_index] if normals.size()>wheel_index else Vector3.UP
		if _record_track(side,points[wheel_index],strength,spacing,normal):
			count += 1
	return count
