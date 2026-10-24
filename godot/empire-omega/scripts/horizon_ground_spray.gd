extends Node3D
## HORIZON R23: bounded tyre mist/dust from real rear-wheel ground contacts.
## Reuses the engine's GPUParticles3D, at most two 24-particle emitters.
## No dependence on cloud textures, new GPU passes, external sound or input.
const SURFACE = preload("res://scripts/horizon_four_wheel_surface.gd")
const TIRE = preload("res://scripts/horizon_tire_model.gd")
const REAR = [1,3]
const PARTICLES_PER_WHEEL: int = 24
const EMITTER_COUNT: int = 2
const MIN_WET_SPEED: float = 8.5
const MIN_DRY_SLIP: float = 6.0
const MAX_ALLOWED: int = PARTICLES_PER_WHEEL*EMITTER_COUNT

var emitters: Array[GPUParticles3D] = []
var _visuals: Array[ParticleProcessMaterial] = []
var emitted_last_tick: int = 0

func _ready() -> void:
	name = "HorizonGroundSpray"
	for side in range(EMITTER_COUNT):
		var spray := GPUParticles3D.new()
		spray.name = "RearWaterOrDust_%d" % side
		spray.amount = PARTICLES_PER_WHEEL
		spray.lifetime = 0.45
		spray.fixed_fps = 30
		spray.local_coords = false
		spray.emitting = false
		spray.visibility_aabb = AABB(Vector3(-2.2,-0.8,-2.2),Vector3(4.4,3.0,4.4))
		var physics := ParticleProcessMaterial.new()
		physics.direction = Vector3(0.0,1.0,0.0)
		physics.spread = 65.0
		physics.initial_velocity_min = 0.35
		physics.initial_velocity_max = 1.65
		physics.gravity = Vector3(0.0,-1.8,0.0)
		physics.scale_min = 0.55
		physics.scale_max = 1.15
		physics.color = Color(0.50,0.56,0.58,0.28)
		spray.process_material = physics
		var particle_mesh := SphereMesh.new()
		particle_mesh.radius = 0.065
		particle_mesh.height = 0.12
		particle_mesh.radial_segments = 6
		particle_mesh.rings = 3
		var smoke_mat := StandardMaterial3D.new()
		smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smoke_mat.albedo_color = Color(0.92,0.94,0.95,0.45)
		particle_mesh.material = smoke_mat
		spray.draw_pass_1 = particle_mesh
		add_child(spray)
		emitters.append(spray)
		_visuals.append(physics)

static func should_emit(speed: float, lateral: float, handbrake: bool, wet: bool) -> bool:
	if not is_finite(speed) or not is_finite(lateral) or absf(speed) < MIN_WET_SPEED:
		return false
	if wet:
		return true
	var slip: float = TIRE.slip_angle_degrees(speed,lateral)
	return slip >= (3.6 if handbrake else MIN_DRY_SLIP)

func _stop() -> void:
	emitted_last_tick = 0
	for spray in emitters:
		spray.emitting = false
		spray.amount_ratio = 0.0

func update_spray(vehicle: CharacterBody3D, driving: bool, quality: String, dt: float) -> int:
	# Native LOW/mobile fallback: both particle emitters are fully off.
	if vehicle == null or not driving or quality == "low":
		_stop()
		return 0
	var speed: float = float(vehicle.get("speed"))
	var lateral: float = float(vehicle.get("lateral_speed"))
	var handbrake: bool = bool(vehicle.get("handbrake_on"))
	var grip: float = float(vehicle.get("traction_factor"))
	var wet: bool = is_finite(grip) and grip < 0.87
	if not should_emit(speed,lateral,handbrake,wet):
		_stop()
		return 0
	# Vehicle already samples four contacts for suspension each physics tick.
	# Read its snapshot and only recast for an isolated test or a stopped
	# physics node. No extra four-ray budget during actual driving.
	var cached: Variant = vehicle.get("last_wheel_support")
	var result: Dictionary = cached if cached is Dictionary and vehicle.is_physics_processing() else {}
	if result.is_empty() or not result.has("points"):
		result = SURFACE.probe(vehicle)
	var grounded: Array[bool] = result["grounded"]
	var points: Array[Vector3] = result["points"]
	var strength: float = clampf(absf(speed)/29.0,0.50,1.0)
	var detail: float = 0.40 if quality == "standard" else 1.0
	var count := 0
	for side in range(EMITTER_COUNT):
		var sample_index: int = REAR[side]
		var spray: GPUParticles3D = emitters[side]
		if grounded.size() <= sample_index or not grounded[sample_index]:
			spray.emitting = false
			spray.amount_ratio = 0.0
			continue
		spray.global_position = points[sample_index] + Vector3(0.0,0.12,0.0)
		# Pale water mist on damp asphalt, subtle grey dust on dry tyres.
		_visuals[side].color = Color(0.72,0.82,0.86,0.32) if wet else Color(0.47,0.50,0.52,0.28)
		spray.amount_ratio = detail*strength
		spray.emitting = true
		count += 1
	emitted_last_tick = count
	return count
