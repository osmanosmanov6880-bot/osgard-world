extends Node3D
## Three non-violent street patrols. Reuses the exact traffic collider and
## road router used by citizens; pursuers never teleport on route refresh.
const TRAFFIC = preload("res://scripts/traffic_agent.gd")
const ROUTER = preload("res://scripts/street_router.gd")
const DEPOTS = [Vector3(-156,0.8,156),Vector3(156,0.8,-156),Vector3(156,0.8,156)]
var vehicles: Array = []
var traffic_signals
var citizens: Array = []
var elapsed := 0.0
var active_level := 0

func _ready() -> void:
	name = "OSGARDCityPatrols"
	for depot in DEPOTS:
		var patrol = TRAFFIC.new()
		patrol.patrol_vehicle = true
		add_child(patrol)
		patrol.set_route([depot,depot+Vector3(0,0,-52.0)],14.0)
		patrol.visible = false
		patrol.collision_layer = 0
		patrol.set_physics_process(false)
		vehicles.append(patrol)

func reset_patrols() -> void:
	active_level = 0
	elapsed = 0.0
	for i in range(vehicles.size()):
		var patrol = vehicles[i]
		patrol.visible = false
		patrol.collision_layer = 0
		patrol.speed = 0.0
		patrol.set_physics_process(false)

func tick(target: Vector3, state: Dictionary, wanted: int, delta: float, wetness: float) -> void:
	var level: int = clampi(wanted,0,vehicles.size())
	if level != active_level:
		active_level = level
		elapsed = 2.0
		for i in range(vehicles.size()):
			var active: bool = i<level
			var patrol = vehicles[i]
			patrol.visible = active
			patrol.collision_layer = 8 if active else 0
			patrol.collision_mask = (1 | 2 | 4 | 8) if active else 0
			patrol.set_physics_process(active)
	elapsed += maxf(0.0,delta)
	if level<=0 or elapsed<1.8: return
	elapsed = 0.0
	for i in range(level):
		var patrol = vehicles[i]
		patrol.signal_controller = traffic_signals
		patrol.citizens = citizens
		patrol.wetness = wetness
		var direction: Vector3 = target-patrol.global_position
		if direction.length_squared()<16.0: continue
		var path: Array[Vector3] = ROUTER.find_route(patrol.global_position,target,state)
		if path.size()>=2:
			patrol.retarget(path)

func closest_distance(target: Vector3) -> float:
	var nearest := 1000000.0
	for i in range(active_level):
		nearest = minf(nearest,vehicles[i].global_position.distance_to(target))
	return nearest

func visible_positions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for i in range(active_level):
		result.append(vehicles[i].global_position)
	return result
