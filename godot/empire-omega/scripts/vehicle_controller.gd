extends CharacterBody3D
## Arcade vehicle with smooth acceleration, reverse, tire friction and steering.
## Production upgrade: replace with calibrated VehicleBody3D / suspension and traffic collision.

signal mileage_changed(meters: float)
signal drift_reward_earned(credits: int, score: int)

const DYNAMICS = preload("res://scripts/driving_dynamics.gd")
const HORIZON_BODY = preload("res://scripts/horizon_vehicle_art.gd")
const TIRE_MODEL = preload("res://scripts/horizon_tire_model.gd")
const DRIVER_ASSISTS = preload("res://scripts/horizon_driver_assists.gd")
const YAW_INERTIA = preload("res://scripts/horizon_yaw_inertia.gd")
const WHEEL_SURFACE = preload("res://scripts/horizon_four_wheel_surface.gd")
const R46_LOAD_TRANSFER = preload("res://scripts/horizon_r46_load_transfer.gd")
const MAX_FORWARD = 29.0
const MAX_REVERSE = 9.0
const ACCELERATION = 9.5
const BRAKING = 10.5
const DRAG = 2.4

var driving := false
var horizon_visual: Node3D
var last_wheel_support: Dictionary = {}
## R46 — real four-wheel probe load estimate; false if called a certified tyre test.
var r46_brake_diagnostics: Dictionary = {}
var r46_front_load_ratio: float = 0.52
var r46_brake_grip: float = 1.0
var rear_traction_factor := 1.0
var axle_grip_active := false
var headlight_cones: Array[SpotLight3D] = []
var wheel_nodes: Array[MeshInstance3D] = []
var brake_lamp_nodes: Array[MeshInstance3D] = []
var brake_lights_on := false
var handbrake_on := false
var steering_filter := 0.0
var speed := 0.0
var mileage := 0.0
var fuel := 100.0
var health := 100.0
var traction_factor := 1.0
var collision_cooldown := 0.0
var lateral_speed := 0.0
var current_yaw_rate := 0.0
## Arcade driving aids can be disabled for unassisted handling; no fake full ESP/ABS claim.
var assists_enabled := true
var power_assist_reduction := 0.0
var steering_assist_correction := 0.0
var drift_chain_score := 0.0
var drift_chain_duration := 0.0
var drift_release_clock := 0.0
const FUEL_COST_PER_METER = 0.033
const CATALOG = preload("res://scripts/vehicle_catalog.gd")
var variant_id := "compact"
var speed_factor := 1.0
var acceleration_factor := 1.0
var handling_factor := 1.0
var fuel_factor := 1.0
var cargo_speed_factor := 1.0
var cargo_fuel_factor := 1.0

func _ready() -> void:
	name = "PrototypeVehicle"
	collision_layer = 4
	collision_mask = 1 | 8
	var collider := CollisionShape3D.new()
	var size := BoxShape3D.new()
	size.size = Vector3(2.7,1.5,5.4)
	collider.shape = size
	add_child(collider)
	_add_part("LowerChassis",Vector3(2.7,0.7,5.2),Vector3(0,-0.33,0),Color("203849"))
	_add_part("UpperCabin",Vector3(2.3,0.9,2.8),Vector3(0,0.42,0.25),Color("335770"))
	_add_part("Windscreen",Vector3(2.18,0.45,0.06),Vector3(0,0.5,-1.17),Color("8eced2"))
	for x in [-1.35,1.35]:
		for z in [-1.75,1.75]:
			_add_part("Wheel",Vector3(0.42,0.88,0.85),Vector3(x,-0.23,z),Color("0b1218"))
	for x in [-0.82,0.82]:
		_add_part("Headlight",Vector3(0.45,0.22,0.07),Vector3(x,-0.22,-2.63),Color("cbe9dc"),true)
		_add_part("Taillight",Vector3(0.45,0.22,0.07),Vector3(x,-0.22,2.63),Color("e35d54"),true)
	# Keep original named prototype nodes for compatibility with existing saves/tests,
	# but use the original PBR Horizon silhouette and real cylindrical wheels.
	horizon_visual = HORIZON_BODY.new()
	add_child(horizon_visual)
	for part in get_children():
		if part is MeshInstance3D and (part.name == "LowerChassis" or part.name == "UpperCabin" or part.name == "Windscreen" or part.name == "Wheel"):
			part.visible = false
	brake_lights_on = true
	_set_brake_lights(false)
	_make_headlight_beams()

func _make_headlight_beams() -> void:
	# Only two bounded unshadowed punctual lights; LOW quality disables them.
	# The emissive lamp geometry stays visible in every graphics tier.
	for x in [-0.87,0.87]:
		var beam := SpotLight3D.new()
		beam.name = "R33BeamLeft" if x < 0.0 else "R33BeamRight"
		beam.position = Vector3(x,-0.12,-2.70)
		beam.rotation_degrees = Vector3(-7.0,0.0,0.0)
		# R56 genuine headlamp throws light ahead along the real road surface.
		# Only two existing shadow-free punctual lights, never an 8K post effect.
		beam.spot_range = 31.0
		beam.spot_angle = 35.0
		beam.spot_attenuation = 1.12
		beam.light_color = Color("fff1d5")
		beam.light_energy = 1.52
		beam.shadow_enabled = false
		beam.visible = false
		add_child(beam)
		headlight_cones.append(beam)

func update_headlights(hour: float,quality: String) -> void:
	if horizon_visual != null:
		horizon_visual.call("set_detail_quality",quality)
	var safe_hour: float = fposmod(hour if is_finite(hour) else 12.0,24.0)
	var active: bool = (safe_hour < 6.75 or safe_hour >= 18.75) and quality != "low"
	for light in headlight_cones:
		light.visible = active
		light.light_energy = 0.85 if quality == "standard" else 1.52
		light.spot_range = 22.0 if quality == "standard" else 31.0

func _add_part(id: String, size: Vector3, at: Vector3, color: Color, emissive: bool = false) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = id
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.55
	mat.roughness = 0.33
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
	mesh.material_override = mat
	add_child(mesh)
	if id == "Wheel": wheel_nodes.append(mesh)
	if id == "Taillight": brake_lamp_nodes.append(mesh)

func apply_variant(id: String) -> void:
	if not CATALOG.available(id):
		return
	variant_id = id
	var profile: Dictionary = CATALOG.VEHICLES[id]
	speed_factor = float(profile["speed"])
	acceleration_factor = float(profile["acceleration"])
	handling_factor = float(profile["handling"])
	fuel_factor = float(profile["fuel"])
	var paint := Color(str(profile["paint"]))
	for piece in get_children():
		if piece is MeshInstance3D and (piece.name == "LowerChassis" or piece.name == "UpperCabin"):
			var material: StandardMaterial3D = (piece.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			material.albedo_color = paint if piece.name == "LowerChassis" else paint.lightened(0.16)
			piece.material_override = material
	if horizon_visual != null:
		horizon_visual.call("set_paint",paint)

func gear_label() -> String:
	return DYNAMICS.gear(speed)

func _set_brake_lights(enabled: bool) -> void:
	if enabled == brake_lights_on:
		return
	brake_lights_on = enabled
	if horizon_visual != null:
		horizon_visual.call("set_brake_lights",enabled)
	for lamp in brake_lamp_nodes:
		var material: StandardMaterial3D = lamp.material_override as StandardMaterial3D
		if material == null:
			continue
		material.emission_energy_multiplier = 2.6 if enabled else 0.25
		material.albedo_color = Color("ff4058") if enabled else Color("e35d54")

func _sample_wheel_contacts() -> Dictionary:
	# R21 four real Godot world-ray hits; explicitly distinguish a
	# suspended wheel from a supported spring at neutral travel.
	return WHEEL_SURFACE.probe(self)

func _update_drift_score(delta: float) -> void:
	var gain: float = TIRE_MODEL.drift_gain(speed,lateral_speed,handbrake_on,delta) if driving else 0.0
	if gain > 0.0:
		drift_chain_score = minf(900.0,drift_chain_score+gain)
		drift_chain_duration += minf(delta,0.1)
		drift_release_clock = 0.0
	elif drift_chain_score > 0.0:
		drift_release_clock += minf(delta,0.1)
		if drift_release_clock >= 0.9:
			var credits: int = TIRE_MODEL.bank_reward(drift_chain_score,drift_chain_duration)
			if credits > 0:
				drift_reward_earned.emit(credits,roundi(drift_chain_score))
			drift_chain_score = 0.0
			drift_chain_duration = 0.0
			drift_release_clock = 0.0

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = -0.2
	var throttle: float = 0.0
	var steering: float = 0.0
	handbrake_on = false
	if driving:
		throttle = Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
		steering = Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
		# SPACE is jump on foot and the handbrake while inside a vehicle.
		handbrake_on = Input.is_action_pressed("jump")
	if fuel < 0.1:
		throttle = 0.0
	collision_cooldown = maxf(0.0,collision_cooldown-delta)
	steering_filter = YAW_INERTIA.steer_step(steering_filter,steering,speed,traction_factor,delta)
	var prior_speed: float = speed
	var condition: float = clampf(health/100.0,0.32,1.0)
	var forward_limit: float = MAX_FORWARD * speed_factor * cargo_speed_factor
	var reverse_limit: float = MAX_REVERSE * speed_factor
	var forward_accel: float = ACCELERATION * acceleration_factor
	var applied_throttle: float = DRIVER_ASSISTS.drive_power(throttle,speed,lateral_speed,traction_factor,handbrake_on) if driving and assists_enabled else throttle
	if applied_throttle > 0.0:
		applied_throttle *= YAW_INERTIA.corner_power_factor(speed,current_yaw_rate,traction_factor,handbrake_on)
	power_assist_reduction = maxf(0.0,throttle-applied_throttle)
	# R46: baseline driving remains identical with four planted wheels. Only
	# true braking while contacts are missing loses available normal-force grip.
	var braking_now: bool = handbrake_on or (speed>0.25 and applied_throttle< -0.05) or (speed< -0.25 and applied_throttle>0.05)
	var prior_support: Array[bool] = [true,true,true,true]
	# Dictionary defaults are plain Array, not Array[bool] in Godot 4.4.
	# Explicitly copy and type-check the real four-raycast contact mask.
	if last_wheel_support.has("grounded"):
		var saved_support: Array = last_wheel_support["grounded"]
		if saved_support.size()==4:
			for wheel_index in range(4):
				prior_support[wheel_index] = bool(saved_support[wheel_index])
	r46_brake_grip = R46_LOAD_TRANSFER.braking_grip(traction_factor,prior_support,r46_front_load_ratio)
	var drive_grip: float = r46_brake_grip if braking_now else traction_factor
	speed = DYNAMICS.speed_step(speed,applied_throttle,drive_grip,condition,forward_limit,reverse_limit,forward_accel,BRAKING,DRAG,handbrake_on,delta)
	if not driving and absf(speed) < 0.35:
		speed = 0.0
	var applied_steering: float = DRIVER_ASSISTS.stabilize_steering(steering_filter,speed,lateral_speed,traction_factor,handbrake_on) if driving and assists_enabled else steering_filter
	steering_assist_correction = absf(steering_filter-applied_steering)
	var desired_yaw_rate: float = DYNAMICS.yaw_rate(speed,applied_steering*handling_factor,traction_factor,handbrake_on)
	current_yaw_rate = YAW_INERTIA.yaw_step(current_yaw_rate,desired_yaw_rate,speed,traction_factor,handbrake_on,delta)
	rotation.y += current_yaw_rate * minf(delta,0.1)
	var lateral_grip: float = rear_traction_factor if axle_grip_active else traction_factor
	lateral_speed = TIRE_MODEL.step_lateral(lateral_speed,speed,current_yaw_rate,lateral_grip,handbrake_on,delta)
	_set_brake_lights(DYNAMICS.brake_lamps(speed,throttle,handbrake_on))
	var forward: Vector3 = Vector3(-sin(rotation.y),0.0,-cos(rotation.y))
	var right: Vector3 = Vector3(cos(rotation.y),0.0,-sin(rotation.y))
	velocity.x = forward.x * speed + right.x * lateral_speed
	velocity.z = forward.z * speed + right.z * lateral_speed
	var pre_position: Vector3 = global_position
	var pre_collision_speed: float = absf(speed)
	move_and_slide()
	var hit_wall := false
	for impact_index in range(get_slide_collision_count()):
		var contact: KinematicCollision3D = get_slide_collision(impact_index)
		if absf(contact.get_normal().y) < 0.45:
			hit_wall = true
	if hit_wall and pre_collision_speed > 3.0:
		if driving and collision_cooldown <= 0.0:
			var collision_damage: float = clampf(pre_collision_speed*0.56,2.0,18.0)
			health = maxf(5.0,health-collision_damage)
			collision_cooldown = 0.7
		speed *= 0.7
	# Wave 2: only count movement produced by realistic car speeds, never an
	# unexpected position jump (teleport or physics correction) as delivery mileage.
	var covered: float = Vector2(global_position.x-pre_position.x,global_position.z-pre_position.z).length()
	var physical_limit: float = maxf(MAX_FORWARD * speed_factor,MAX_REVERSE * speed_factor) * delta * 1.35 + 0.35
	if covered > physical_limit:
		covered = 0.0
	mileage += covered
	var spin: float = covered / 0.44 * signf(speed)
	var longitudinal_acceleration: float = (speed-prior_speed)/maxf(delta,0.001)
	var wheel_support: Dictionary = _sample_wheel_contacts()
	last_wheel_support = wheel_support
	r46_brake_diagnostics = R46_LOAD_TRANSFER.diagnostics(speed,longitudinal_acceleration,traction_factor,wheel_support["grounded"])
	r46_front_load_ratio = float(r46_brake_diagnostics["front_axle_load_ratio"])
	if horizon_visual != null:
		horizon_visual.call("roll_wheels",covered * signf(speed),applied_steering)
		horizon_visual.call("simulate_chassis",speed,current_yaw_rate,longitudinal_acceleration,traction_factor,handbrake_on,wheel_support["travel"],delta,wheel_support["grounded"])
	_update_drift_score(delta)
	for wheel in wheel_nodes:
		wheel.rotate_x(spin)
		if wheel.position.z < 0.0:
			wheel.rotation.y = applied_steering*0.24
	if driving:
		fuel = maxf(0.0,fuel-covered*FUEL_COST_PER_METER*fuel_factor*cargo_fuel_factor)
	mileage_changed.emit(mileage)
	if position.y < -20:
		global_position = Vector3(-120,1.2,-104)
		speed = 0.0
