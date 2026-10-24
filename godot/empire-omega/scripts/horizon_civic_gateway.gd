extends Node3D
## HORIZON R28: shaded civic-entrance detail on the player's first screen.
## Seven shared GPU batches; no physics bodies, navigation or mission changes.
const FACADE = preload("res://scripts/horizon_facade_materials.gd")
const MAX_BATCHES: int = 7
var batches: int = 0
var pieces: int = 0
var groups: Dictionary = {}

static func _positions(points: Array, size: Vector3) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for point in points:
		out.append(Transform3D(Basis().scaled(size),point))
	return out

static func _colors(count: int, tint: Color) -> Array[Color]:
	var out: Array[Color] = []
	for i in range(count):
		out.append(tint)
	return out

func _group(label: String, mesh: Mesh, poses: Array[Transform3D],
		tints: Array[Color], roughness: float, metal: float,
		stone: bool = false) -> void:
	assert(poses.size()==tints.size(),"Civic instance and tint counts differ")
	if poses.is_empty():
		return
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = mesh
	instances.instance_count = poses.size()
	for i in range(poses.size()):
		instances.set_instance_transform(i,poses[i])
		instances.set_instance_color(i,tints[i])
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = instances
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3(-18.0,-1.0,-19.0),Vector3(36.0,38.0,40.0))
	var finish: StandardMaterial3D = FACADE.facade(Color.WHITE) if stone else StandardMaterial3D.new()
	finish.albedo_color = Color.WHITE
	finish.vertex_color_use_as_albedo = true
	finish.roughness = roughness
	finish.metallic = metal
	finish.emission_enabled = false
	node.material_override = finish
	add_child(node)
	groups[label] = node
	batches += 1
	pieces += poses.size()

func _ready() -> void:
	name = "HorizonCivicGatewayR28"
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var limestone := CylinderMesh.new()
	limestone.top_radius = 0.46
	limestone.bottom_radius = 0.54
	limestone.height = 1.0
	limestone.radial_segments = 14
	limestone.rings = 1
	var pillars: Array[Vector3] = []
	var capitals: Array[Vector3] = []
	var glazing: Array[Vector3] = []
	var frames: Array[Vector3] = []
	var bands: Array[Vector3] = []
	var column_colors: Array[Color] = []
	for column in range(6):
		var x: float = -10.0+float(column)*4.0
		pillars.append(Vector3(x,5.40,14.0))
		capitals.append(Vector3(x,10.93,14.0))
		column_colors.append(Color("bdc1b8") if column%2==0 else Color("aeb6ab"))
	for floor in range(4):
		var y: float = 4.0+float(floor)*4.8
		bands.append(Vector3(0.0,y,0.0))
		for col in range(5):
			var x: float = -8.6+float(col)*4.3
			glazing.append(Vector3(x,y+1.75,12.70))
			frames.append(Vector3(x,y+1.75,12.62))
	var window_colors: Array[Color] = []
	for i in range(glazing.size()):
		window_colors.append(Color("203642") if i%3==0 else Color("2b4653"))
	_group("CivicStonePillars",limestone,_positions(pillars,Vector3(1.0,10.8,1.0)),
		column_colors,0.79,0.015,true)
	_group("CivicCapitals",box,_positions(capitals,Vector3(1.48,0.29,1.48)),
		_colors(6,Color("c0c4b9")),0.77,0.02,true)
	_group("CivicWindowFrames",box,_positions(frames,Vector3(1.99,2.91,0.16)),
		_colors(20,Color("82919c")),0.50,0.21)
	_group("CivicDarkGlass",box,_positions(glazing,Vector3(1.71,2.66,0.09)),
		window_colors,0.28,0.13)
	_group("CivicCornices",box,_positions(bands,Vector3(25.7,0.22,25.7)),
		_colors(4,Color("82939a")),0.83,0.015,true)
	_group("CivicPortico",box,_positions([Vector3(0.0,11.60,14.0)],Vector3(27.0,0.78,5.50)),
		_colors(1,Color("657d88")),0.70,0.035,true)
	_group("CivicPortal",box,_positions([Vector3(0.0,4.10,12.73)],Vector3(4.85,7.84,0.17)),
		_colors(1,Color("203542")),0.34,0.17)
	assert(batches==MAX_BATCHES,"Civic detail must be seven bounded GPU batches")
