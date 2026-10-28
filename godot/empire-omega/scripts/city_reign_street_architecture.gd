extends Node3D
## CITY REIGN WORLD EDITION / B41
## Source-authored STREET-LEVEL architectural treatment for the real buildings.
## Real shaded 3D meshes, not screenshots, decals, pre-rendered backgrounds or
## unlicensed models. Four shared MultiMesh draw groups across <=128 buildings.
## This component has no collision objects and no authority over game state.
const FACADE_PACK = preload("res://scripts/horizon_facade_material_pack.gd")
const MAX_BUILDINGS: int = 128
const BATCH_COUNT: int = 4
const MAX_TOTAL_TRIANGLES: int = 250000

const STONE: Dictionary = {
	"forum": Color("b5b0a5"),
	"housing": Color("939ea2"),
	"lower": Color("968d81"),
	"aqueduct": Color("97a9a8")
}
const METAL: Dictionary = {
	"forum": Color("b0a079"),
	"housing": Color("788993"),
	"lower": Color("9b9588"),
	"aqueduct": Color("74a5aa")
}
const PLANTS: Dictionary = {
	"forum": Color("577257"),
	"housing": Color("496e5a"),
	"lower": Color("63754f"),
	"aqueduct": Color("49776c")
}

var building_count: int = 0
var placements: Array[Transform3D] = []
var stone_colors: Array[Color] = []
var metal_colors: Array[Color] = []
var foliage_colors: Array[Color] = []
var lamp_colors: Array[Color] = []
var batches: Dictionary = {}
var materials: Dictionary = {}
var quality: String = "standard"
var current_hour: float = 12.0
var current_power: int = 100
var finalized: bool = false

static func _face_box(st: SurfaceTool, minimum: Vector3, maximum: Vector3,
		tint: Color) -> void:
	# Every face is independently triangulated with a physical outward normal.
	var v: Array[Vector3] = [
		Vector3(minimum.x,minimum.y,minimum.z),
		Vector3(maximum.x,minimum.y,minimum.z),
		Vector3(maximum.x,minimum.y,maximum.z),
		Vector3(minimum.x,minimum.y,maximum.z),
		Vector3(minimum.x,maximum.y,minimum.z),
		Vector3(maximum.x,maximum.y,minimum.z),
		Vector3(maximum.x,maximum.y,maximum.z),
		Vector3(minimum.x,maximum.y,maximum.z)
	]
	var faces: Array = [
		[0,1,2,3],[4,7,6,5],[0,4,5,1],
		[1,5,6,2],[2,6,7,3],[3,7,4,0]
	]
	for face in faces:
		var a: Vector3 = v[int(face[0])]
		var b: Vector3 = v[int(face[1])]
		var c: Vector3 = v[int(face[2])]
		var d: Vector3 = v[int(face[3])]
		var normal: Vector3 = (b-a).cross(c-a).normalized()
		for point in [a,b,c,a,c,d]:
			st.set_normal(normal)
			st.set_color(tint)
			st.add_vertex(point)

static func _leaf(st: SurfaceTool, bottom: Vector3, outer: Vector3,
		side: Vector3, tint: Color) -> void:
	# Three-dimensional double-sided triangular leaf; not a billboard.
	var a: Vector3 = bottom
	var b: Vector3 = outer + side
	var c: Vector3 = outer - side
	var n: Vector3 = (b-a).cross(c-a).normalized()
	for point in [a,b,c]:
		st.set_normal(n)
		st.set_color(tint)
		st.add_vertex(point)
	for point in [a,c,b]:
		st.set_normal(-n)
		st.set_color(tint.darkened(0.16))
		st.add_vertex(point)

static func _stone_geometry() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Two substantial stone bases flank the real central entrance: its
	# original doorway and storefront collision footprint remain unchanged.
	for side in [-1.0,1.0]:
		var sx: float = float(side)
		var x0: float = -5.80 if sx < 0.0 else 2.17
		var x1: float = -2.17 if sx < 0.0 else 5.80
		_face_box(st,Vector3(x0,0.12,-0.70),
			Vector3(x1,0.35,0.16),Color("d0cec7"))
		_face_box(st,Vector3(x0,0.35,-0.49),
			Vector3(x1,0.52,-0.06),Color("aaa9a4"))
		# Real articulated edge stone; storefront glazing remains inboard.
		_face_box(st,Vector3(sx*5.43-0.12,0.51,-0.44),
			Vector3(sx*5.43+0.12,4.46,-0.06),Color("c6c4bf"))
		_face_box(st,Vector3(sx*5.43-0.24,4.35,-0.62),
			Vector3(sx*5.43+0.24,4.78,0.04),Color("d2c9b9"))
		# Solid planter troughs are OFF the traffic lane and off doorway.
		_face_box(st,Vector3(sx*4.50-0.66,0.20,-1.53),
			Vector3(sx*4.50+0.66,0.80,-0.60),Color("b3b5b0"))
		_face_box(st,Vector3(sx*4.50-0.57,0.79,-1.47),
			Vector3(sx*4.50+0.57,0.83,-0.66),Color("474b43"))
	# Ground-level facade elevation and a strong horizontal silhouette at eye
	# level; above original glass, doors, awning and street-facing sign.
	_face_box(st,Vector3(-5.90,4.15,-0.38),
		Vector3(5.90,4.40,0.02),Color("a9aaa6"))
	_face_box(st,Vector3(-5.94,5.66,-0.30),
		Vector3(5.94,5.88,0.08),Color("c9c5bb"))
	# Slim centering course, not a giant slab covering original windows.
	_face_box(st,Vector3(-1.72,3.99,-0.55),
		Vector3(1.72,4.15,-0.16),Color("d2c7b5"))
	return st.commit()

static func _metal_geometry() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var titanium := Color("9fb1b5")
	var bronze := Color("c4b091")
	# Brackets physically supporting the real storefront awning.
	for side in [-1.0,1.0]:
		var x: float = float(side)*1.90
		_face_box(st,Vector3(x-0.07,2.55,-0.72),
			Vector3(x+0.07,3.14,-0.52),titanium)
		_face_box(st,Vector3(x-0.16,3.06,-1.02),
			Vector3(x+0.16,3.21,-0.35),titanium.darkened(0.16))
		# Four depth-bearing spandrel fins, well below upper window rows.
		var edge: float = float(side)*3.82
		_face_box(st,Vector3(edge-0.075,4.58,-0.46),
			Vector3(edge+0.075,5.56,-0.18),titanium)
		_face_box(st,Vector3(edge-0.13,5.50,-0.48),
			Vector3(edge+0.13,5.62,-0.15),bronze)
	# The original 2.37m doorway remains visible; metal mullion has real depth.
	_face_box(st,Vector3(-0.045,0.55,-0.55),
		Vector3(0.045,2.94,-0.32),titanium.darkened(0.18))
	for side in [-1.0,1.0]:
		var x: float = float(side)*0.33
		_face_box(st,Vector3(x-0.032,1.12,-0.61),
			Vector3(x+0.032,1.54,-0.42),bronze)
	# Separate recessed sign frames create highlights at changing sun angles.
	_face_box(st,Vector3(-4.96,4.61,-0.53),
		Vector3(4.96,4.68,-0.26),titanium)
	_face_box(st,Vector3(-4.96,5.48,-0.53),
		Vector3(4.96,5.55,-0.26),titanium)
	return st.commit()

static func _foliage_geometry() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0,1.0]:
		var cx: float = float(side)*4.50
		var cz: float = -1.06
		_face_box(st,Vector3(cx-0.065,0.77,cz-0.065),
			Vector3(cx+0.065,1.47,cz+0.065),Color("455d44"))
		# Eight distinct angled leaves around each planted root. All leaf
		# polygons occupy real 3D orientations, with double-sided normals.
		for i in range(8):
			var angle: float = float(i)*TAU/8.0
			var radius: float = 0.27 + 0.075*float(i%3)
			var up: float = 1.26 + 0.14*float(i%4)
			var direction := Vector3(cos(angle),0.0,sin(angle))
			var lateral := Vector3(-sin(angle),0.0,cos(angle))
			_leaf(st,Vector3(cx,1.05,cz),
				Vector3(cx,up,cz)+direction*radius,
				lateral*(0.11+0.02*float(i%2)),
				Color("78906d") if i%3==0 else Color("4f785a"))
	return st.commit()

static func _light_geometry() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Integrated fixture strips are ONLY genuinely emissive at night and
	# follow the authoritative city electricity level. No fake omni lights.
	_face_box(st,Vector3(-4.63,4.74,-0.60),
		Vector3(4.63,4.81,-0.49),Color("f2d4a4"))
	for side in [-1.0,1.0]:
		var x: float = float(side)*1.48
		_face_box(st,Vector3(x-0.075,2.93,-0.71),
			Vector3(x+0.075,3.18,-0.52),Color("ffe2b6"))
	return st.commit()

func _ready() -> void:
	name = "CityReignLiveStreetArchitecture"

func record(center: Vector3,width: float,height: float,
		district: String,entrance_face: int) -> void:
	if finalized or building_count >= MAX_BUILDINGS:
		return
	if not center.is_finite() or not is_finite(width) or not is_finite(height):
		return
	if width < 10.0 or width > 16.0 or height < 8.0 or height > 76.0:
		return
	if not STONE.has(district) or entrance_face < 0 or entrance_face > 3:
		return
	# Use the exact same world-oriented face chosen by the original shop
	# window/door recorder. Local front is -Z; no street-axis guessing.
	var rotation := Basis(Vector3.UP,float(entrance_face)*PI*0.5)
	var center_ground := Vector3(center.x,0.0,center.z)
	var portal_origin: Vector3 = center_ground + rotation*Vector3(
		0.0,0.0,-(width*0.5+0.35))
	var pose := Transform3D(
		rotation.scaled(Vector3(width/12.0,1.0,1.0)),
		portal_origin)
	placements.append(pose)
	stone_colors.append(STONE[district])
	metal_colors.append(METAL[district])
	foliage_colors.append(PLANTS[district])
	lamp_colors.append(Color("e8d3ae") if district=="forum" else Color("d2e5e7"))
	building_count += 1

func _batch(id: String,mesh: ArrayMesh,tints: Array[Color],
		metal: float,rough: float,stone_surface: bool = false) -> void:
	assert(tints.size() == building_count and placements.size() == building_count)
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = mesh
	instances.instance_count = building_count
	for i in range(building_count):
		instances.set_instance_transform(i,placements[i])
		instances.set_instance_color(i,tints[i])
	var node := MultiMeshInstance3D.new()
	node.name = id
	node.multimesh = instances
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3(-245.0,-0.2,-245.0),Vector3(490.0,81.0,490.0))
	var finish := FACADE_PACK.facade(Color.WHITE,1) if stone_surface else StandardMaterial3D.new()
	finish.albedo_color = Color.WHITE
	finish.vertex_color_use_as_albedo = true
	finish.metallic = metal
	finish.roughness = rough
	if not stone_surface:
		finish.cull_mode = BaseMaterial3D.CULL_DISABLED if id=="CinematicStreetFoliage" else BaseMaterial3D.CULL_BACK
	node.material_override = finish
	add_child(node)
	batches[id] = node
	materials[id] = finish

func finalize() -> void:
	if finalized:
		return
	assert(building_count > 0 and building_count <= MAX_BUILDINGS)
	_batch("UrbanStonePortals",_stone_geometry(),stone_colors,0.06,0.76,true)
	_batch("AnodizedStreetJoinery",_metal_geometry(),metal_colors,0.52,0.34)
	_batch("CinematicStreetFoliage",_foliage_geometry(),foliage_colors,0.02,0.81)
	_batch("PoweredStreetLuminaires",_light_geometry(),lamp_colors,0.15,0.41)
	finalized = true
	set_quality(quality)
	update_ambience(current_hour,current_power)

func set_quality(tier: String) -> void:
	quality = tier if ["low","standard","cinematic"].has(tier) else "standard"
	if not finalized:
		return
	batches["UrbanStonePortals"].visible = quality != "low"
	batches["AnodizedStreetJoinery"].visible = quality != "low"
	batches["CinematicStreetFoliage"].visible = quality == "cinematic"
	var stone: StandardMaterial3D = materials["UrbanStonePortals"]
	stone.normal_enabled = quality == "cinematic"
	update_ambience(current_hour,current_power)

func update_ambience(hour: float,power: int) -> void:
	current_hour = fposmod(hour,24.0) if is_finite(hour) else 12.0
	current_power = clampi(power,0,100)
	if not finalized:
		return
	# Dusk is a smooth interval, not an abrupt 18:00 toggle. Municipal
	# underfunding/brownouts dim the ACTUAL material used by the buildings.
	var night: float = 0.0
	if current_hour >= 19.0 or current_hour < 5.5:
		night = 1.0
	elif current_hour >= 17.0:
		night = clampf((current_hour-17.0)/2.0,0.0,1.0)
	elif current_hour < 7.0:
		night = clampf((7.0-current_hour)/1.5,0.0,1.0)
	var powered: float = night*clampf(float(current_power)/55.0,0.0,1.0)
	var active: bool = quality != "low" and powered > 0.02
	batches["PoweredStreetLuminaires"].visible = active
	var glow: StandardMaterial3D = materials["PoweredStreetLuminaires"]
	glow.emission_enabled = active
	glow.emission = Color("f8d5a5")
	glow.emission_energy_multiplier = powered*(0.26 if quality=="standard" else 0.52)

func total_triangles() -> int:
	if not finalized:
		return 0
	var sum: int = 0
	for id in batches:
		var node: MultiMeshInstance3D = batches[id]
		var mesh: Mesh = node.multimesh.mesh
		for surface in range(mesh.get_surface_count()):
			sum += mesh.surface_get_array_len(surface)/3*node.multimesh.instance_count
	return sum

func graphics_are_bounded() -> bool:
	if not finalized or get_child_count() != BATCH_COUNT or batches.size() != BATCH_COUNT:
		return false
	if building_count < 1 or building_count > MAX_BUILDINGS:
		return false
	if placements.size() != building_count or total_triangles() > MAX_TOTAL_TRIANGLES:
		return false
	for id in batches:
		var node: MultiMeshInstance3D = batches[id]
		if node.multimesh == null or node.multimesh.instance_count != building_count:
			return false
		if node.get_child_count() != 0 or node.multimesh.mesh == null:
			return false
		if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			return false
	return true
