extends Node3D
## 3D warning barricades for the SAME active closures used by navigation.
## Generated art avoids external asset/license dependencies.
const MOBILITY = preload("res://scripts/city_mobility.gd")
var markers: Dictionary = {}

func _ready() -> void:
	var simulation: Variant = get_node_or_null('/root/GameState')
	if simulation != null: sync_state(simulation.data)

func _paint(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.55
	return material

func _box(parent: Node3D, mesh_name: String, size: Vector3, at: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = mesh_name
	var cube := BoxMesh.new()
	cube.size = size
	node.mesh = cube
	node.position = at
	node.material_override = material
	parent.add_child(node)

func sync_state(state: Dictionary) -> void:
	for marker in markers.values():
		if is_instance_valid(marker):
			marker.queue_free()
	markers.clear()
	for incident in MOBILITY.active_incidents(state):
		var id: String = str(incident["id"])
		var a: Array = incident["a"]
		var b: Array = incident["b"]
		var root := Node3D.new()
		root.name = "RoadClosure_" + id
		root.position = MOBILITY.incident_at(id) + Vector3(0,0.12,0)
		if int(a[1]) != int(b[1]):
			root.rotation.y = PI * 0.5
		add_child(root)
		markers[id] = root
		# Vehicles and pedestrians physically stop, unless they navigate around.
		var body := StaticBody3D.new()
		body.name = "RoadClosureCollider"
		body.collision_layer = 1
		body.collision_mask = 0
		body.position.y = 0.92
		root.add_child(body)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(10.0,1.75,0.8)
		collision.shape = shape
		body.add_child(collision)
		var amber: Material = _paint(Color("ffd36d"))
		var red: Material = _paint(Color("bc493c"))
		var black: Material = _paint(Color("181f25"))
		_box(root,"HazardBase",Vector3(10,0.25,1.0),Vector3(0,0.06,0),black)
		_box(root,"Crossbar",Vector3(10,0.72,0.32),Vector3(0,1.2,0),amber)
		for i in range(7):
			_box(root,"WarningStripe_%d" % i,Vector3(0.54,0.75,0.35),Vector3(float(i-3)*1.42,1.2,0.02),red)
		for side in [-4.0,4.0]:
			_box(root,"Post",Vector3(0.36,1.5,0.36),Vector3(side,0.65,0),black)
		var light := OmniLight3D.new()
		light.light_color = Color("fdbb5e")
		light.light_energy = 0.65
		light.omni_range = 12.0
		light.position.y = 2.1
		root.add_child(light)

func closest_hazard(point: Vector3, radius: float = 9.0) -> String:
	var chosen := ""
	var nearest: float = radius * radius
	for id in markers:
		var distance: float = markers[id].global_position.distance_squared_to(point)
		if distance < nearest:
			chosen = str(id)
			nearest = distance
	return chosen
