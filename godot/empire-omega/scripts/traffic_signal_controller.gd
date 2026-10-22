extends Node3D
## Simplified coordinated traffic signal network, governing ambient NPC cars.
## Signals are deterministic; real lane-aware driving AI is a later milestone.
const INTERSECTIONS = [-156.0, -52.0, 52.0, 156.0]
const CYCLE_SECONDS = 24.0
const CHANGE_SECONDS = 12.0
const SIGNAL_REACH = 9.0

var elapsed := 0.0
var lights: Array[Dictionary] = []
var last_phase := -1

func _ready() -> void:
	name = "TrafficSignalGrid"
	for x in INTERSECTIONS:
		for z in INTERSECTIONS:
			var junction := Node3D.new()
			junction.name = "Signal_%d_%d" % [int(x),int(z)]
			junction.position = Vector3(x + 7.5,0.0,z + 7.5)
			add_child(junction)
			_add_mesh(junction,Vector3(0.25,3.7,0.25),Vector3(0,1.9,0),Color("687784"))
			_add_mesh(junction,Vector3(0.78,1.3,0.58),Vector3(0,3.9,0),Color("12222c"))
			var green: MeshInstance3D = _add_mesh(junction,Vector3(0.38,0.3,0.16),Vector3(0,3.6,-0.36),Color("2a7e68"))
			var red: MeshInstance3D = _add_mesh(junction,Vector3(0.38,0.3,0.16),Vector3(0,4.2,-0.36),Color("822b36"))
			lights.append({"green":green,"red":red})
	_update_lights()

func _add_mesh(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.45
	material.metallic = 0.12
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _phase() -> int:
	return int(floor(fposmod(elapsed,CYCLE_SECONDS) / CHANGE_SECONDS))

func _process(delta: float) -> void:
	elapsed += delta
	if _phase() != last_phase:
		_update_lights()

func _update_lights() -> void:
	last_phase = _phase()
	for record in lights:
		var green: MeshInstance3D = record["green"]
		var red: MeshInstance3D = record["red"]
		var green_mat: StandardMaterial3D = green.material_override as StandardMaterial3D
		var red_mat: StandardMaterial3D = red.material_override as StandardMaterial3D
		green_mat.albedo_color = Color("30dfb4") if last_phase == 0 else Color("174e42")
		red_mat.albedo_color = Color("802c34") if last_phase == 0 else Color("ff5965")

func permitted(waypoint: Vector3, direction: Vector3) -> bool:
	var closest: float = INF
	for x in INTERSECTIONS:
		for z in INTERSECTIONS:
			closest = minf(closest,Vector2(waypoint.x-x,waypoint.z-z).length())
	if closest > SIGNAL_REACH:
		return true
	if absf(direction.x) + absf(direction.z) < 0.001:
		return true
	var along_z: bool = absf(direction.z) > absf(direction.x)
	return along_z if _phase() == 1 else not along_z
