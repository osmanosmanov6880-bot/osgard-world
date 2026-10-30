extends CharacterBody3D
## v0.14: physically colliding traffic proxies with safe distance, real red-light
## braking, deterministic routes and visible brake lights. Arcade, not AAA AI.
const SAFETY = preload("res://scripts/traffic_safety.gd")
const R47_CROSSING = preload("res://scripts/horizon_r47_crosswalk_prediction.gd")
const CIVIC_CROSSING = preload("res://scripts/city_reign_civic_traffic_safety.gd")
const SEDAN_SURFACE = preload("res://scripts/horizon_traffic_sedan_surface.gd")
const SIGNAL_LOGIC = preload("res://scripts/city_reign_turn_signals.gd")
const FOLLOW = preload("res://scripts/city_reign_traffic_following.gd")
const R178_SIGNAL = preload("res://scripts/city_reign_intersection_policy.gd")
const R182_CROSSING = preload("res://scripts/city_reign_crosswalk_occupancy.gd")
const R186_BOX = preload("res://scripts/city_reign_junction_box_clearance.gd")
const R188_STEER = preload("res://scripts/city_reign_physical_corner_steering.gd")
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
var front_steer_wheels: Array[MeshInstance3D] = []
# R188 actual physical body direction and in-world steering, source only.
var last_steer_command_rad: float = 0.0
var last_steer_yaw_step: float = 0.0
var last_steer_fallback: bool = false
var lateral_safety_rejections: int = 0
var stopped_seconds := 0.0
var travelled_metres := 0.0
var emergency_stops := 0
var wetness := 1.0
var citizens: Array = []
var neighbors: Array = []
var last_follow_speed: float = 18.0
var last_signal_speed: float = 18.0
var last_signal_phase: String = "none"
# R182 actual physical crosswalk occupancy diagnostics; gameplay only,
# non-persistent, never sent to a server or fabricated from a HUD state.
var last_crosswalk_occupied: bool = false
var last_crosswalk_clearance: float = R182_CROSSING.INF_CLEARANCE_M
var crosswalk_activations: int = 0
var crosswalk_yield_seconds: float = 0.0
# Source-only live R186 safe-box measurements, not player surveillance
# or a new save field. Original physical 12 cars / R178 clock only.
var last_junction_guard_active: bool = false
var last_junction_guard_reason: String = ""
var junction_yield_activations: int = 0
var junction_hold_seconds: float = 0.0
var _last_braking := true
var indicator_lamps: Dictionary = {}
var _indicator_lit: Dictionary = {"left":true,"right":true}
var indicator_mode: String = "off"
var indicator_phase: float = 0.0
var patrol_vehicle := false
# CITY REIGN A5: authored visual model family. This affects ONLY the
# original two existing cached 3D chassis meshes, never AI or physical box.
var visual_style: String = "sedan"
var visual_quality: String = "standard"
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
	var body_tint: Color = Color("182d56") if patrol_vehicle else (
		Color("b89453") if visual_style=="taxi" else (
		Color("647884") if visual_style=="courier" else (
		Color("273c50") if visual_style=="executive" else (
		Color("5d8198") if get_instance_id()%2==0 else Color("89685b")))))
	_part("CarBody",Vector3(2.26,0.8,4.05),Vector3(0,0.35,0),body_tint)
	_part("Cabin",Vector3(1.9,0.65,2.1),Vector3(0,0.98,0.1),Color("f2f2e6") if patrol_vehicle else Color("3c5262"))
	# R126: visually replace original two rigid cuboids with actual cached,
	# curved PBR closed 3D car/greenhouse meshes without adding ANY nodes.
	var sculpted_body: MeshInstance3D = get_node("CarBody") as MeshInstance3D
	var sculpted_cabin: MeshInstance3D = get_node("Cabin") as MeshInstance3D
	# The pre-approved default patrol/original car still uses R126's exact
	# shared mesh. City-owned 12 traffic agents may select a visual model.
	set_visual_quality(visual_quality)
	var body_finish: StandardMaterial3D = sculpted_body.material_override as StandardMaterial3D
	body_finish.vertex_color_use_as_albedo = true
	body_finish.metallic = 0.57
	body_finish.roughness = 0.29
	body_finish.clearcoat_enabled = true
	body_finish.clearcoat = 0.48
	body_finish.clearcoat_roughness = 0.14
	body_finish.cull_mode = BaseMaterial3D.CULL_DISABLED
	var glass_finish: StandardMaterial3D = sculpted_cabin.material_override as StandardMaterial3D
	glass_finish.albedo_color = Color.WHITE
	glass_finish.vertex_color_use_as_albedo = true
	glass_finish.metallic = 0.29
	glass_finish.roughness = 0.27
	glass_finish.cull_mode = BaseMaterial3D.CULL_DISABLED
	if patrol_vehicle:
		siren_left = _part("PatrolBlue",Vector3(0.45,0.18,0.46),Vector3(-0.35,1.4,0.0),Color("16469c"),true)
		siren_right = _part("PatrolRed",Vector3(0.45,0.18,0.46),Vector3(0.35,1.4,0.0),Color("a13241"),true)
	for x in [-1.16,1.16]:
		for z in [-1.28,1.28]:
			var wheel := _part("Wheel",Vector3(0.36,0.68,0.72),Vector3(x,-0.01,z),Color("111922"))
			# True circular wheel with concentric PBR rubber/metal in ONE
			# original node. Axis is local X so existing rotate_x spins it.
			wheel.mesh = SEDAN_SURFACE.wheel_mesh()
			wheel.material_override = SEDAN_SURFACE.wheel_finish()
			wheels.append(wheel)
			if z<0.0:
				front_steer_wheels.append(wheel)
		_part("Headlamp",Vector3(0.32,0.16,0.06),Vector3(x*0.67,0.3,-2.05),Color("c2eadc"),true)
		var lamp := _part("BrakeLamp",Vector3(0.34,0.2,0.06),Vector3(x*0.67,0.3,2.05),Color("4a181f"),true)
		brake_meshes.append(lamp)
	indicator_lamps["left"] = _part("R161LeftIndicator",Vector3(0.22,0.15,0.065),
		Vector3(-1.05,0.31,2.08),Color("b97725"),true)
	indicator_lamps["right"] = _part("R161RightIndicator",Vector3(0.22,0.15,0.065),
		Vector3(1.05,0.31,2.08),Color("b97725"),true)
	_sync_indicator_lamps()
	_update_brake_lights(false)

func set_visual_quality(tier: String) -> void:
	visual_quality = tier if ["low","standard","cinematic"].has(tier) else "standard"
	var chassis: MeshInstance3D = get_node_or_null("CarBody") as MeshInstance3D
	var roof: MeshInstance3D = get_node_or_null("Cabin") as MeshInstance3D
	if chassis == null or roof == null: return
	# LOW reuses only three original R126 physical source meshes globally.
	# STANDARD/CINEMATIC gain 3 more cached model families, still only
	# two real draw nodes per vehicle; no runtime SurfaceTool allocations.
	var desired: String = "sedan" if patrol_vehicle or visual_quality=="low" else visual_style
	chassis.mesh = SEDAN_SURFACE.body_mesh_for(desired)
	roof.mesh = SEDAN_SURFACE.cabin_mesh_for(desired)

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

func _sync_indicator_lamps() -> void:
	for side_name in ["left","right"]:
		var lit: bool = SIGNAL_LOGIC.side_on(indicator_mode,side_name,indicator_phase)
		if bool(_indicator_lit[side_name])==lit: continue
		_indicator_lit[side_name]=lit
		var lamp: MeshInstance3D = indicator_lamps[side_name] as MeshInstance3D
		var paint: StandardMaterial3D = lamp.material_override as StandardMaterial3D
		paint.albedo_color = Color("ffb13c") if lit else Color("795121")
		paint.emission = Color("ffb13c") if lit else Color("795121")
		paint.emission_energy_multiplier = 2.8 if lit else 0.16

func set_route(waypoints: Array[Vector3], road_speed: float) -> void:
	points = waypoints.duplicate()
	cruising_speed = clampf(road_speed,2.0,18.0)
	speed = 0.0
	if not points.is_empty():
		global_position = points[0]
		target_index = 1 % points.size()
		if not patrol_vehicle and points.size()>1:
			# Initial authentic traffic cars face their ACTUAL source
			# right-hand R185 lane. No 90° sideways slide on first tick.
			var first_leg: Vector3=points[1]-points[0]
			first_leg.y=0.0
			if first_leg.length_squared()>0.001:
				rotation.y=R188_STEER.yaw_of(first_leg)

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
	# This samples the real R178 16-junction stop bar ONCE per vehicle
	# physics step, using the SAME original source clock as 34 residents.
	# No separate raycasts, AI objects, saved data or forced teleport.
	var crossing_gate: Dictionary=R182_CROSSING.gate(global_position,
		direction,float(signal_controller.get("elapsed"))) if signal_controller!=null else {}
	last_crosswalk_occupied=false
	last_crosswalk_clearance=R182_CROSSING.INF_CLEARANCE_M
	if not hit.is_empty():
		# Body ray is centre-to-centre; reserve half a vehicle length as space.
		nearest = maxf(0.0,from.distance_to(hit["position"])-CAR_LENGTH*0.5)
	# Ambient citizens are lightweight Node3D proxies (not physics bodies).
	# Treat walkers in our lane as genuine hazards without 34*12 heavy colliders.
	for person in citizens:
		if not is_instance_valid(person) or not person.visible:
			continue
		# R47: the visible citizen's route velocity predicts where they will
		# cross this lane before the vehicle arrives, not only where they are.
		var walker_velocity: Vector3 = person.get("planned_velocity") if person.get("planned_velocity") is Vector3 else Vector3.ZERO
		var predicted: float = R47_CROSSING.clearance(global_position,direction,speed,
			person.global_position,walker_velocity,minf(nearest,look))
		nearest = minf(nearest,predicted)
		if R182_CROSSING.occupied(crossing_gate,direction,
				person.global_position,walker_velocity,speed):
			# Real 3D citizen physically occupies / will enter the
			# ORIGINAL car lane at this very junction. Yield BEFORE the
			# source stop bar; no phantom stop for a sidewalk parallel walk.
			last_crosswalk_occupied=true
			last_crosswalk_clearance=R182_CROSSING.stop_clearance(crossing_gate)
			nearest=minf(nearest,last_crosswalk_clearance)
	return nearest

func _physics_process(delta: float) -> void:
	_flash_patrol(delta)
	if points.size() < 2:
		last_junction_guard_active = false
		last_junction_guard_reason = ""
		last_steer_command_rad = 0.0
		last_steer_yaw_step = 0.0
		last_steer_fallback = false
		indicator_mode = "off"
		_sync_indicator_lamps()
		velocity = Vector3.ZERO
		return
	var destination: Vector3 = points[target_index]
	var displacement: Vector3 = destination-global_position
	displacement.y = 0.0
	if displacement.length_squared() < 2.25:
		target_index = (target_index+1)%points.size()
		return
	var heading: Vector3 = displacement.normalized()
	var prior_occupancy: bool=last_crosswalk_occupied
	var obstacle: float = _obstacle_distance(heading)
	if last_crosswalk_occupied and not prior_occupancy:
		crosswalk_activations+=1
	var signal_distance: float = 1000000.0
	var signal_elapsed: float=float(signal_controller.get("elapsed")) if signal_controller!=null else 0.0
	var source_stop: Dictionary=R178_SIGNAL.approach(global_position,heading,signal_elapsed) if signal_controller!=null else {}
	last_signal_phase=str(source_stop.get("phase","none"))
	last_signal_speed=R178_SIGNAL.speed_cap(global_position,heading,speed,
		cruising_speed,wetness,signal_elapsed) if signal_controller!=null else cruising_speed
	# If it is already physically impossible to stop safely on AMBER, the
	# conservative dilemma-zone rule commits the car to clearing the line.
	# Do not let the legacy signal-gap limiter secretly override that.
	if (signal_controller!=null and not source_stop.is_empty() and
			last_signal_speed<cruising_speed-0.001):
		signal_distance=float(source_stop["stop_distance"])+SAFETY.MIN_GAP
	# R186 authentic box clearance: source R178 stop bar, R185 real
	# right-hand exit, actual 12 moving/stopped native neighbors.
	# NEVER enters a physically full junction just because it is green.
	# Cars already inside the junction retain priority and can clear.
	var was_guarded: bool=last_junction_guard_active
	var box_guard: Dictionary=R186_BOX.scan(self,neighbors,heading,
		speed,cruising_speed,wetness,source_stop)
	last_junction_guard_active=not box_guard.is_empty()
	last_junction_guard_reason=str(box_guard.get("reason",""))
	if last_junction_guard_active and not was_guarded:
		junction_yield_activations+=1
	var corner_index: int = (target_index+1)%points.size()
	var after_corner: Vector3 = points[corner_index]-destination
	after_corner.y = 0.0
	# R161: physical rear lamps indicate the genuine upcoming graph turn.
	# Lights have NO influence on intersection permissions or braking limits.
	indicator_mode = SIGNAL_LOGIC.upcoming(heading,after_corner,displacement.length())
	indicator_phase = SIGNAL_LOGIC.phase_after(indicator_phase,delta)
	_sync_indicator_lamps()
	var bend_limit: float = SAFETY.corner_speed(heading,after_corner,displacement.length(),cruising_speed)
	var goal: float = minf(bend_limit,SAFETY.desired_speed(cruising_speed,obstacle,signal_distance,wetness))
	# A real cross-vehicle cannot create right of way or exceed the
	# old obstacle, R178 signal, corner and wet-braking constraints.
	if last_junction_guard_active:
		goal=minf(goal,float(box_guard["limit_mps"]))
	# R163: a physical neighboring convoy can only REDUCE the legacy
	# raycast/signal/pedestrian target, never grant passage or extra speed.
	last_follow_speed = FOLLOW.scan(self,neighbors,heading,speed,cruising_speed,wetness)
	goal = minf(goal,last_follow_speed)
	# Real phase + existing wet braking. Can only LOWER the original
	# convoy, obstacle, pedestrian, civic and corner safety limits.
	goal=minf(goal,last_signal_speed)
	# B62: fund the real city's zebra crossings to actually calm ordinary
	# resident traffic. One source-locked speed constraint, AFTER original
	# pedestrian and signal safety. No change to physics, route or payout.
	# Emergency patrols keep the original response behavior.
	var real_city: Node = get_node_or_null("/root/GameState")
	if real_city != null and not patrol_vehicle:
		var saved_state: Dictionary = real_city.get("data")
		goal = minf(goal,CIVIC_CROSSING.speed_cap(saved_state,
			global_position,heading,cruising_speed,patrol_vehicle))
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
	if last_crosswalk_occupied and speed<2.0 and is_finite(delta):
		crosswalk_yield_seconds=minf(86400.0,
			crosswalk_yield_seconds+clampf(delta,0.0,0.1))
	if last_junction_guard_active and speed<2.0 and is_finite(delta):
		junction_hold_seconds=minf(86400.0,
			junction_hold_seconds+clampf(delta,0.0,0.1))
	# R188: in the original 12 non-patrol traffic NPCs, the physical
	# CharacterBody3D movement vector now matches the VISIBLE chassis yaw.
	# The old controller smoothly rotated the body but instantly snapped
	# velocity 90°, creating severe sideways traffic sliding at R185 turns.
	# Original A* path points, R178 signal phase, R186 box, R47 walker scan
	# and all other source speed caps above are intentionally unchanged.
	var actual_direction: Vector3=heading
	last_steer_command_rad=0.0
	last_steer_yaw_step=0.0
	last_steer_fallback=false
	if not patrol_vehicle:
		var actual_aim: Vector3=R188_STEER.source_aim(
			global_position,destination,points[corner_index])
		var steer: Dictionary=R188_STEER.steer(
			rotation.y,global_position,actual_aim,speed,delta,wetness)
		if bool(steer.get("valid",false)):
			var candidate: Vector3=steer["direction"]
			rotation.y=float(steer["yaw"])
			last_steer_command_rad=float(steer["wheel_radians"])
			last_steer_yaw_step=float(steer["actual_yaw_step"])
			if R188_STEER.safe_next_step(global_position,candidate,speed,delta):
				actual_direction=candidate
			else:
				# Road edge or corrupt route: physically STOP the car rather
				# than cut its box collider through an original building or
				# teleport to the correct side. Steering may still turn in place.
				last_steer_fallback=true
				lateral_safety_rejections+=1
				speed=0.0
				_update_brake_lights(true)
	else:
		# Original actual patrol chases are deliberately unchanged. Their
		# pursuit may be off the 9×9 civilian traffic road graph.
		rotation.y = lerp_angle(rotation.y,
			atan2(-heading.x,-heading.z),clampf(delta*4.8,0.0,1.0))
	# The real FRONT wheel meshes steer around their vertical axes
	# before rolling; rear wheels stay straight. No new meshes or nodes.
	for front_wheel in front_steer_wheels:
		front_wheel.rotation.y=last_steer_command_rad
	var before: Vector3 = global_position
	velocity = Vector3(actual_direction.x*speed,0.0,actual_direction.z*speed)
	move_and_slide()
	var travelled: float = Vector2(global_position.x-before.x,global_position.z-before.z).length()
	travelled_metres += travelled
	for wheel in wheels:
		wheel.rotate_x(travelled/0.34)
	if get_slide_collision_count()>0 and speed>3.5:
		emergency_stops += 1
		speed *= 0.3
