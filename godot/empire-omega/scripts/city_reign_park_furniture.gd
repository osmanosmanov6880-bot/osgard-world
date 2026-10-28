extends Node3D
## CITY REIGN B64 — REAL public park infrastructure accompanies real citizens.
## These are source-made physical 3D benches and lanterns, not image overlays.
## Only the existing "community_park" project's saved COMPLETION enables them.
## Original investment landmark, roads, colliders and all old saves untouched.
const CIVIC = preload("res://scripts/civic_initiatives.gd")
const PROJECTS = preload("res://scripts/project_landmarks.gd")
const PARK_ID: String = "community_park"
const PARK_AT: Vector3 = Vector3(164.0,0.0,-91.0)
const BENCH_COUNT: int = 6
const LANTERN_COUNT: int = 8
const MAX_MESH_VERTICES: int = 600
const BENCH_OFFSETS: Array[Vector3] = [
	Vector3(7.0,0,-4.7),Vector3(7.0,0,4.7),
	Vector3(10.5,0,-4.7),Vector3(10.5,0,4.7),
	Vector3(14.0,0,-4.7),Vector3(14.0,0,4.7)
]
const LIGHT_OFFSETS: Array[Vector3] = [
	Vector3(6.0,0,-6.6),Vector3(6.0,0,6.6),
	Vector3(9.4,0,-6.6),Vector3(9.4,0,6.6),
	Vector3(12.8,0,-6.6),Vector3(12.8,0,6.6),
	Vector3(16.2,0,-6.6),Vector3(16.2,0,6.6)
]
var park_finished: bool = false
var benches: MultiMeshInstance3D
var lanterns: MultiMeshInstance3D
var bench_finish: StandardMaterial3D
var lantern_finish: StandardMaterial3D
var last_hour: float = 12.0
var last_power: int = 100
var graphics: String = "standard"
var built_once: bool = false

static func _face(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,tint: Color) -> void:
	st.set_color(tint)
	for v in [a,b,c,a,c,d]:
		st.add_vertex(v)

static func _box(st: SurfaceTool,center: Vector3,half: Vector3,tint: Color) -> void:
	var p: Vector3 = center-half
	var q: Vector3 = center+half
	_face(st,Vector3(p.x,p.y,p.z),Vector3(q.x,p.y,p.z),
		Vector3(q.x,q.y,p.z),Vector3(p.x,q.y,p.z),tint)
	_face(st,Vector3(q.x,p.y,q.z),Vector3(p.x,p.y,q.z),
		Vector3(p.x,q.y,q.z),Vector3(q.x,q.y,q.z),tint)
	_face(st,Vector3(p.x,p.y,q.z),Vector3(p.x,p.y,p.z),
		Vector3(p.x,q.y,p.z),Vector3(p.x,q.y,q.z),tint)
	_face(st,Vector3(q.x,p.y,p.z),Vector3(q.x,p.y,q.z),
		Vector3(q.x,q.y,q.z),Vector3(q.x,q.y,p.z),tint)
	_face(st,Vector3(p.x,q.y,p.z),Vector3(q.x,q.y,p.z),
		Vector3(q.x,q.y,q.z),Vector3(p.x,q.y,q.z),tint)
	_face(st,Vector3(p.x,p.y,q.z),Vector3(q.x,p.y,q.z),
		Vector3(q.x,p.y,p.z),Vector3(p.x,p.y,p.z),tint)

static func bench_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var anthracite := Color("344b54")
	var oak := Color("a58b65")
	var nickel := Color("8d9b9a")
	var darker := Color("6f5a44")
	# Finite six-sided masonry footplates, real joined wood slats, curved
	# visually stepped seat back, and separate machine-fin metal arms.
	for x in [-0.82,0.82]:
		_box(st,Vector3(float(x),0.17,0),Vector3(0.15,0.16,0.49),anthracite)
		_box(st,Vector3(float(x),0.55,0.11),Vector3(0.085,0.33,0.08),nickel)
		_box(st,Vector3(float(x),0.59,-0.34),Vector3(0.10,0.12,0.13),nickel)
	for slat in range(4):
		var z: float = -0.35+float(slat)*0.22
		_box(st,Vector3(0,0.59,z),Vector3(0.95,0.047,0.093),oak if slat%2==0 else darker)
	for slat in range(4):
		var y: float = 0.73+float(slat)*0.18
		_box(st,Vector3(0,y,0.47+float(slat)*0.065),
			Vector3(0.94,0.071,0.052),oak)
	# Small mechanically meaningful support under central slats.
	_box(st,Vector3(0,0.34,0.06),Vector3(0.65,0.058,0.19),anthracite)
	st.generate_normals()
	return st.commit()

static func lantern_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var titanium := Color("6b7e86")
	var copper := Color("b5a17e")
	var glass := Color("d0eee3")
	var base := Color("354a54")
	_box(st,Vector3(0,0.19,0),Vector3(0.25,0.18,0.25),base)
	_box(st,Vector3(0,1.25,0),Vector3(0.095,1.01,0.095),titanium)
	_box(st,Vector3(0,2.27,0),Vector3(0.26,0.10,0.26),copper)
	_box(st,Vector3(0,2.44,0),Vector3(0.20,0.14,0.20),glass)
	_box(st,Vector3(0,2.62,0),Vector3(0.28,0.07,0.28),copper)
	st.generate_normals()
	return st.commit()

static func _material(roughness: float,metallic: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = Color.WHITE
	result.vertex_color_use_as_albedo = true
	result.metallic = metallic
	result.roughness = roughness
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result

func _ready() -> void:
	name = "CityReignEarnedParkStreetFurniture"
	position = PARK_AT
	_build_once()
	set_quality(graphics)
	_refresh()

func _build_once() -> void:
	if built_once:
		return
	built_once = true
	var wooden_seats: ArrayMesh = bench_mesh()
	bench_finish = _material(0.62,0.21)
	var seat_instances := MultiMesh.new()
	seat_instances.transform_format = MultiMesh.TRANSFORM_3D
	seat_instances.mesh = wooden_seats
	seat_instances.instance_count = BENCH_COUNT
	for i in range(BENCH_COUNT):
		seat_instances.set_instance_transform(i,Transform3D(
			Basis(Vector3.UP,PI*0.5 if i%2==0 else -PI*0.5),
			BENCH_OFFSETS[i]))
	benches = MultiMeshInstance3D.new()
	benches.name = "SixActualMunicipalWoodSteelBenches"
	benches.multimesh = seat_instances
	benches.material_override = bench_finish
	benches.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	benches.custom_aabb = AABB(Vector3(4,-0.4,-9),Vector3(16,2,18))
	add_child(benches)
	var pole_instances := MultiMesh.new()
	pole_instances.transform_format = MultiMesh.TRANSFORM_3D
	pole_instances.mesh = lantern_mesh()
	pole_instances.instance_count = LANTERN_COUNT
	for i in range(LANTERN_COUNT):
		pole_instances.set_instance_transform(i,Transform3D(Basis(),LIGHT_OFFSETS[i]))
	lanterns = MultiMeshInstance3D.new()
	lanterns.name = "EightAuthenticSharedMunicipalPathLanterns"
	lanterns.multimesh = pole_instances
	lanterns.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lanterns.custom_aabb = benches.custom_aabb
	lantern_finish = _material(0.43,0.40)
	lanterns.material_override = lantern_finish
	add_child(lanterns)

func sync_state(state: Dictionary) -> void:
	var finished: Variant = state.get("projects_done",[])
	park_finished = finished is Array and finished.has(PARK_ID)
	last_hour = float(state.get("day_clock",12.0))
	last_power = clampi(int(state.get("energy",100)),0,100)
	_refresh()

func set_quality(tier: String) -> void:
	graphics = tier if ["low","standard","cinematic"].has(tier) else "standard"
	_refresh()

func update_ambience(hour: float,energy: int) -> void:
	last_hour = fposmod(hour,24.0) if is_finite(hour) else 12.0
	last_power = clampi(energy,0,100)
	_refresh()

func _refresh() -> void:
	if not built_once:
		return
	visible = park_finished
	benches.visible = park_finished
	lanterns.visible = park_finished and graphics!="low"
	var dark: bool = last_hour>=19.0 or last_hour<6.0
	# The original municipal grid is the exclusive source of light power.
	var factor: float = clampf(float(last_power)/80.0,0.0,1.0)
	var lit: bool = lanterns.visible and dark and factor>=0.25
	lantern_finish.emission_enabled = lit
	lantern_finish.emission = Color("cbe8d9")
	lantern_finish.emission_energy_multiplier = factor*0.34 if lit else 0.0

func installed() -> bool:
	return built_once and park_finished and visible

func graphics_are_bounded() -> bool:
	if not built_once or get_child_count()!=2:
		return false
	if PARK_AT!=PROJECTS.POSITIONS[PARK_ID]:
		return false
	if benches.multimesh.instance_count!=BENCH_COUNT or (
		lanterns.multimesh.instance_count!=LANTERN_COUNT):
		return false
	if benches.multimesh.mesh.surface_get_array_len(0)>MAX_MESH_VERTICES or (
		lanterns.multimesh.mesh.surface_get_array_len(0)>MAX_MESH_VERTICES):
		return false
	for shape in [benches,lanterns]:
		if shape.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or (
			not shape.find_children("*","CollisionShape3D",true,false).is_empty()):
			return false
	return find_children("*","CollisionShape3D",true,false).is_empty()
