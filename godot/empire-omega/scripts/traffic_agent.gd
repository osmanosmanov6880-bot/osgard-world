extends CharacterBody3D
## v0.14: physically colliding traffic proxies with safe distance, real red-light
## braking, deterministic routes and visible brake lights. Arcade, not AAA AI.
const SAFETY = preload("res://scripts/traffic_safety.gd")
const CAR_LENGTH := 4.1
const DETECTION_RANGE := 27.0
const ROAD_HEIGHT := 0.8
var points: Array[Vector3] = []
var target_index := 0
var cruising_speed := 8.5
var speed := 0.0
var signal_controller
var brake_meshes: Array[MeshInstance3D] = []
var wheels: Array[MeshInstance3D] = []
var stopped_seconds := 0.0
var travelled_metres := 0.0
var emergency_stops := 0
var wetness := 1.0
var citizens: Array = []
var _last_braking := true
var patrol_vehicle := false
var siren_left: MeshInstance3D
var siren_right: MeshInstance3D
var siren_timer := 0.0

func _ready() -> void:
	name = "CityPatrol" if patrol_vehicle else "CitizenTraffic"
	# 8: ambient car, 4: player car, 2: pedestrian, 1: world geometry.
	collision_layer = 8
	collision_mask = 1 | 2 | 4 | 8
	floor_snap_length = 0.25
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.25,1.15,CAR_LENGTH)
	collider.shape = shape
	collider.position.y = 0.45
	add_child(collider)
	_part("CarBody",Vector3(2.26,0.8,4.05),Vector3(0,0.35,0),Color("182d56") if patrol_vehicle else (Color("5d8198") if get_instance_id()%2==0 else Color("89685b")))
	_part("Cabin",Vector3(1.9,0.65,2.1),Vector3(0,0.98,0.1),Color("f2f2e6") if patrol_vehicle else Color("3c5262"))
	if patrol_vehicle:
		siren_left = _part("PatrolBlue",Vector3(0.45,0.18,0.46),Vector3(-0.35,1.4,0.0),Color("16469c"),true)
		siren_right = _part("PatrolRed",Vector3(0.45,0.18,0.46),Vector3(0.35,1.4,0.0),Color("a13241"),true)
	for x in [-1.16,1.16]:
		for z in [-1.28,1.28]:
			var wheel := _part("Wheel",Vector3(0.36,0.68,0.72),Vector3(x,-0.01,z),Color("111922"))
			wheels.append(wheel)
		_part("Headlamp",Vector3(0.32,0.16,0.06),Vector3(x*0.67,0.3,-2.05),Color("c2eadc"),true)
		var lamp := _part("BrakeLamp",Vector3(0.34,0.2,0.06),Vector3(x*0.67,0.3,2.05),Color("4a181f"),true)
		brake_meshes.append(lamp)
	_update_brake_lights(false)

func _part(label: String, dimensions: Vector3, at: Vector3, color: Color, emit: bool = false) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	var geometry := BoxMesh.new()
	geometry.size = dimensions
	part.mesh = geometry
	part.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.42
	material.metallic = 0.23
	material.emission_enabled = emit
	material.emission = color
	part.material_override = material
	add_child(part)
	return part

func _update_brake_lights(braking: bool) -> void:
	if _last_braking == braking and not brake_meshes.is_empty():
		return
	_last_braking = braking
	for lamp in brake_meshes:
		var material := lamp.material_override as StandardMaterial3D
		var color: Color = Color("ff3549") if braking else Color("4a181f")
		material.albedo_color = color
		material.emission = color
		material.emission_energy_multiplier = 2.4 if braking else 0.25

func set_route(waypoints: Array[Vector3], road_speed: float) -> void:
	points = waypoints.duplicate()
	cruising_speed = clampf(road_speed,2.0,18.0)
	speed = 0.0
	if not points.is_empty():
		global_position = points[0]
		target_index = 1 % points.size()

func retarget(waypoints: Array[Vector3]) -> void:
	# Preserve physical position/velocity. set_route would teleport a pursuer.
	if waypoints.size()<2: return
	points = waypoints.duplicate()
	points[0] = global_position
	target_index = 1

func _flash_patrol(delta: float) -> void:
	if not patrol_vehicle or siren_left == null or siren_right == null: return
	siren_timer = fposmod(siren_timer + delta,0.7)
	var left_on: bool = siren_timer < 0.35
	var blue: StandardMaterial3D = siren_left.material_override as StandardMaterial3D
	var red: StandardMaterial3D = siren_right.material_override as StandardMaterial3D
	blue.emission_energy_multiplier = 3.0 if left_on else 0.12
	red.emission_energy_multiplier = 0.12 if left_on else 3.0

func _obstacle_distance(direction: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = global_position + Vector3.UP * 0.8
	var look: float = minf(DETECTION_RANGE,maxf(12.0,speed*1.7+SAFETY.MIN_GAP))
	var query := PhysicsRayQueryParameters3D.create(from,from+direction*look,2|4|8)
	query.exclude = [get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	var nearest: float = 1000000.0
	if not hit.is_empty():
		# Body ray is centre-to-centre; reserve half a vehicle length as space.
		nearest = maxf(0.0,from.distance_to(hit["position"])-CAR_LENGTH*0.5)
	# Ambient citizens are lightweight Node3D proxies (not physics bodies).
	# Treat walkers in our lane as genuine hazards without 34*12 heavy colliders.
	for person in citizens:
		if not is_instance_valid(person) or not person.visible:
			continue
		var delta_position: Vector3 = person.global_position-global_position
		delta_position.y = 0.0
		var forward_distance: float = delta_position.dot(direction)
		if forward_distance <= 0.0 or forward_distance >= minf(nearest,look):
			continue
		var lateral_distance: float = (delta_position-direction*forward_distance).length()
		if lateral_distance < 2.2:
			nearest = maxf(0.0,forward_distance-1.5)
	return nearest

func _physics_process(delta: float) -> void:
	_flash_patrol(delta)
	if points.size() < 2:
		velocity = Vector3.ZERO
		return
	var destination: Vector3 = points[target_index]
	var displacement: Vector3 = destination-global_position
	displacement.y = 0.0
	if displacement.length_squared() < 2.25:
		target_index = (target_index+1)%points.size()
		return
	var heading: Vector3 = displacement.normalized()
	var obstacle: float = _obstacle_distance(heading)
	var signal_distance: float = 1000000.0
	if signal_controller != null and displacement.length() < 22.0 and not signal_controller.permitted(destination,heading):
		signal_distance = displacement.length()
	var corner_index: int = (target_index+1)%points.size()
	var after_corner: Vector3 = points[corner_index]-destination
	after_corner.y = 0.0
	var bend_limit: float = SAFETY.corner_speed(heading,after_corner,displacement.length(),cruising_speed)
	var goal: float = minf(bend_limit,SAFETY.desired_speed(cruising_speed,obstacle,signal_distance,wetness))
	# A conservative full stop prevents perpetual low-speed creep into road barriers.
	if obstacle <= SAFETY.MIN_GAP + 4.0: goal = 0.0
	var previous_speed: float = speed
	speed = SAFETY.approach_speed(speed,goal,delta)
	var braking: bool = SAFETY.should_brake(cruising_speed,speed) or previous_speed-speed > 0.2
	_update_brake_lights(braking)
	if speed < SAFETY.STOP_EPSILON:
		stopped_seconds += delta
	else:
		stopped_seconds = 0.0
	rotation.y = lerp_angle(rotation.y,atan2(-heading.x,-heading.z),clampf(delta*4.8,0.0,1.0))
	var before: Vector3 = global_position
	velocity = Vector3(heading.x*speed,0.0,heading.z*speed)
	move_and_slide()
	var travelled: float = Vector2(global_position.x-before.x,global_position.z-before.z).length()
	travelled_metres += travelled
	for wheel in wheels:
		wheel.rotate_x(travelled/0.34)
	if get_slide_collision_count()>0 and speed>3.5:
		emergency_stops += 1
		speed *= 0.3
