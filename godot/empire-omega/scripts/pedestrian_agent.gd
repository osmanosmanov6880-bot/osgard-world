extends Node3D
## Low-cost visible citizen proxy following deterministic home/work/leisure routines.
## Route uses the same road topology as the mini-map; offscreen proxies are culled.

const ROUTER = preload("res://scripts/street_router.gd")
const ROUTINE = preload("res://scripts/citizen_routine.gd")
var citizen_id := 0
var speed := 2.15
var activity := ""
var route: Array[Vector3] = []
var next_waypoint := 0
var schedule_timer := 0.0
var traffic_vehicles: Array = []
var player_car: Node3D
var walking_phase := 0.0
var body_mesh: MeshInstance3D

func _ready() -> void:
	var body := MeshInstance3D.new()
	body_mesh = body
	var shape := CapsuleMesh.new()
	shape.radius = 0.35
	shape.height = 1.65
	body.mesh = shape
	body.position.y = 0.9
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("658aa2") if citizen_id % 2 == 0 else Color("9a8b71")
	body.material_override = material
	add_child(body)
	_refresh_schedule()

func _refresh_schedule() -> void:
	var day_clock: float = float(GameState.data.get("day_clock",8.0))
	var plan: Dictionary = ROUTINE.plan(citizen_id,day_clock,int(GameState.data.get("unemployment",40)),int(GameState.data["stability"]))
	if activity == str(plan["activity"]): return
	activity = str(plan["activity"])
	var target: Vector3 = plan["destination"]
	route = ROUTER.find_route(global_position,target,GameState.data)
	next_waypoint = 1 if route.size() > 1 else 0

func _yield_to_vehicle() -> bool:
	# NPC proxies have no physics collision; avoid a visible car passing through them.
	for nearby in traffic_vehicles:
		if not is_instance_valid(nearby) or not nearby.visible or absf(float(nearby.get("speed"))) < 1.5:
			continue
		if nearby.global_position.distance_squared_to(global_position) < 42.0:
			return true
	if is_instance_valid(player_car) and absf(float(player_car.get("speed"))) >= 1.5:
		return player_car.global_position.distance_squared_to(global_position) < 64.0
	return false

func _process(delta: float) -> void:
	schedule_timer += delta
	if schedule_timer >= 4.0:
		schedule_timer = 0.0
		_refresh_schedule()
	if route.is_empty() or next_waypoint >= route.size():
		return
	if _yield_to_vehicle():
		return
	var at: Vector3 = route[next_waypoint]
	var travel: Vector3 = at-global_position
	travel.y = 0.0
	if travel.length_squared() <= 2.25:
		next_waypoint += 1
		return
	var velocity: Vector3 = travel.normalized() * speed
	global_position += velocity * minf(delta,0.06)
	walking_phase += delta * 9.0
	if body_mesh != null:
		body_mesh.position.y = 0.9 + sin(walking_phase)*0.065
	rotation.y = lerp_angle(rotation.y,atan2(-velocity.x,-velocity.z),minf(delta*5.0,1.0))
