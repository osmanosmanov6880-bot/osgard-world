extends Node3D
## Low-cost visible citizen proxy following deterministic home/work/leisure routines.
## Route uses the same road topology as the mini-map; offscreen proxies are culled.

const ROUTER = preload("res://scripts/street_router.gd")
const ROUTINE = preload("res://scripts/citizen_routine.gd")
const PARK_VISITORS = preload("res://scripts/city_reign_park_routine.gd")
const TRAJECTORY = preload("res://scripts/horizon_pedestrian_yield.gd")
const STREET_ART = preload("res://scripts/horizon_street_citizen_mesh.gd")
var citizen_id := 0
var speed := 2.15
var activity := ""
# B63: a new genuinely funded community park can change an evening trip
# without changing the old "leisure" activity type. Replan on destination.
var last_destination: Vector3 = Vector3(1000000.0,1000000.0,1000000.0)
var route: Array[Vector3] = []
var next_waypoint := 0
var schedule_timer := 0.0
var traffic_vehicles: Array = []
var player_car: Node3D
var walking_phase := 0.0
# Actual next-route velocity. Traffic AI uses it to anticipate crossings.
var planned_velocity: Vector3 = Vector3.ZERO
var body_mesh: MeshInstance3D

func _ready() -> void:
	# Same single physical MeshInstance3D as the original citizen proxy.
	# Shared source meshes have real faces, jacket, articulated walk poses;
	# this has no collider, terrain change or additional per-person nodes.
	var body := MeshInstance3D.new()
	body.name = "R123RealStreetCitizen"
	body_mesh = body
	body.mesh = STREET_ART.mesh_for(citizen_id,0)
	body.position.y = 0.9
	body.material_override = STREET_ART.shared_material()
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)
	_refresh_schedule()

func _refresh_schedule() -> void:
	var simulation: Variant = get_node_or_null('/root/GameState')
	if simulation == null: return
	var day_clock: float = float(simulation.data.get("day_clock",8.0))
	var plan: Dictionary = ROUTINE.plan(citizen_id,day_clock,int(simulation.data.get("unemployment",40)),int(simulation.data["stability"]))
	# REAL paid civic choice changes an actual lightweight city NPC journey;
	# source route solver still owns all closures and traffic safety.
	plan = PARK_VISITORS.choose(plan,citizen_id,simulation.data)
	var target: Vector3 = plan["destination"]
	if activity == str(plan["activity"]) and last_destination.distance_squared_to(target)<0.01:
		return
	activity = str(plan["activity"])
	last_destination = target
	route = ROUTER.find_route(global_position,target,simulation.data)
	next_waypoint = 1 if route.size() > 1 else 0

func _yield_to_vehicle(walking_velocity: Vector3 = Vector3.ZERO) -> bool:
	# A real relative-trajectory test, not a simple distance freeze. Cars
	# passing in the adjacent lane or heading away never stall the sidewalk.
	for nearby in traffic_vehicles:
		if not is_instance_valid(nearby) or not nearby.visible or absf(float(nearby.get("speed"))) < 1.5:
			continue
		var vehicle_velocity: Vector3 = nearby.velocity
		if TRAJECTORY.should_yield(global_position,walking_velocity,nearby.global_position,vehicle_velocity):
			return true
	if is_instance_valid(player_car) and absf(float(player_car.get("speed"))) >= 1.5:
		var signed_speed: float = float(player_car.get("speed"))
		var heading: float = player_car.global_rotation.y
		var player_velocity := Vector3(-sin(heading),0.0,-cos(heading))*signed_speed
		return TRAJECTORY.should_yield(global_position,walking_velocity,player_car.global_position,player_velocity)
	return false

func _process(delta: float) -> void:
	schedule_timer += delta
	if schedule_timer >= 4.0:
		schedule_timer = 0.0
		_refresh_schedule()
	if route.is_empty() or next_waypoint >= route.size():
		planned_velocity = Vector3.ZERO
		if body_mesh != null:
			body_mesh.mesh = STREET_ART.mesh_for(citizen_id,0)
		return
	var at: Vector3 = route[next_waypoint]
	var travel: Vector3 = at-global_position
	travel.y = 0.0
	if travel.length_squared() <= 2.25:
		planned_velocity = Vector3.ZERO
		next_waypoint += 1
		return
	var velocity: Vector3 = travel.normalized() * speed
	planned_velocity = velocity
	if _yield_to_vehicle(velocity):
		if body_mesh != null:
			body_mesh.mesh = STREET_ART.mesh_for(citizen_id,0)
		return
	global_position += velocity * minf(delta,0.06)
	walking_phase += delta * 9.0
	if body_mesh != null:
		# Four native shared limb poses: actual arm/leg displacement instead of
		# wobbling the old rigid capsule. No per-frame ArrayMesh allocations.
		var pose_index: int = posmod(int(floor(walking_phase*2.0/PI)),STREET_ART.GAIT_FRAMES)
		body_mesh.mesh = STREET_ART.mesh_for(citizen_id,pose_index)
		body_mesh.position.y = 0.9 + sin(walking_phase*2.0)*0.024
		body_mesh.rotation.z = sin(walking_phase)*0.018
	rotation.y = lerp_angle(rotation.y,atan2(-velocity.x,-velocity.z),minf(delta*5.0,1.0))
