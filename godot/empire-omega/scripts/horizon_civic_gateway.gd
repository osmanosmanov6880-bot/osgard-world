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

# R130: one ORIGINAL shared 12-flute, 48-sector fluted shaft source mesh
# for all six existing 10.8m civic entry columns. True radial depth, gradual
# entasis and inset grooves, never six per-column scene objects or fake image.
const R130_SECTORS: int = 48
const R130_FLUTES: int = 12
const R130_SHAFT_SEGMENTS: int = 8
const R130_COLUMN_TRIANGLES: int = 864
const R130_CAPITAL_TRIANGLES: int = 48

static func _flute_radius(height: float, angle: float) -> float:
	var progress: float = clampf(height+0.5,0.0,1.0)
	var taper: float = lerpf(0.54,0.46,progress)
	var entasis: float = 0.032*sin(PI*progress)
	var groove: float = 0.055*pow(0.5+0.5*cos(float(R130_FLUTES)*angle),2)
	return (taper+entasis)*(1.0-groove)

static func _flute_point(y: float, angle: float) -> Vector3:
	var radius: float = _flute_radius(y,angle)
	return Vector3(radius*cos(angle),y,radius*sin(angle))

static func _civic_face(st: SurfaceTool,a: Vector3,b: Vector3,
		c: Vector3,d: Vector3, tint: Color) -> void:
	st.set_color(tint)
	# Godot 4.x clockwise front winding: keep outward-facing physical normals.
	for v in [a,c,b,a,d,c]:
		st.add_vertex(v)

static func _sculpted_fluted_column() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var levels: Array[float] = [-0.50,-0.45,-0.36,-0.18,0.0,0.18,0.36,0.45,0.50]
	for section in range(R130_SHAFT_SEGMENTS):
		var low_y: float = levels[section]
		var high_y: float = levels[section+1]
		for index in range(R130_SECTORS):
			var a: float = TAU*float(index)/float(R130_SECTORS)
			var b: float = TAU*float(index+1)/float(R130_SECTORS)
			var p0: Vector3 = _flute_point(low_y,a)
			var p1: Vector3 = _flute_point(low_y,b)
			var p2: Vector3 = _flute_point(high_y,b)
			var p3: Vector3 = _flute_point(high_y,a)
			# Correct outward side normals so original limestone normal/roughness
			# under Godot sun remains physical instead of inward-facing.
			_civic_face(st,p0,p3,p2,p1,Color.WHITE)
	for index in range(R130_SECTORS):
		var a: float = TAU*float(index)/float(R130_SECTORS)
		var b: float = TAU*float(index+1)/float(R130_SECTORS)
		var bottom: Vector3 = Vector3(0.0,-0.5,0.0)
		var top: Vector3 = Vector3(0.0,0.5,0.0)
		st.set_color(Color.WHITE)
		for v in [bottom,_flute_point(-0.5,b),_flute_point(-0.5,a),
				top,_flute_point(0.5,a),_flute_point(0.5,b)]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()

static func _capital_box(st: SurfaceTool, centre: Vector3,
		half: Vector3, tint: Color) -> void:
	var low: Vector3 = centre-half
	var high: Vector3 = centre+half
	var a:=Vector3(low.x,low.y,low.z)
	var b:=Vector3(high.x,low.y,low.z)
	var c:=Vector3(high.x,low.y,high.z)
	var d:=Vector3(low.x,low.y,high.z)
	var e:=Vector3(low.x,high.y,low.z)
	var f:=Vector3(high.x,high.y,low.z)
	var g:=Vector3(high.x,high.y,high.z)
	var h:=Vector3(low.x,high.y,high.z)
	_civic_face(st,a,b,c,d,tint)
	_civic_face(st,e,h,g,f,tint)
	_civic_face(st,a,e,f,b,tint)
	_civic_face(st,d,c,g,h,tint)
	_civic_face(st,a,d,h,e,tint)
	_civic_face(st,b,f,g,c,tint)

static func _sculpted_stone_capital() -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Four genuinely stepped carved strata, each joined into ONE original
	# six-instance CivicCapitals GPU draw batch.
	_capital_box(st,Vector3(0,-0.37,0),
		Vector3(0.35,0.13,0.35),Color("e6e8e1"))
	_capital_box(st,Vector3(0,-0.14,0),
		Vector3(0.40,0.10,0.40),Color("d6d8d2"))
	_capital_box(st,Vector3(0,0.13,0),
		Vector3(0.45,0.16,0.45),Color("e3e6df"))
	_capital_box(st,Vector3(0,0.39,0),
		Vector3(0.50,0.11,0.50),Color("d0d5cf"))
	st.generate_normals()
	return st.commit()

func _ready() -> void:
	name = "HorizonCivicGatewayR28"
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var limestone: ArrayMesh = _sculpted_fluted_column()
	var carved_capital: ArrayMesh = _sculpted_stone_capital()
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
	_group("CivicCapitals",carved_capital,_positions(capitals,Vector3(1.48,0.29,1.48)),
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
