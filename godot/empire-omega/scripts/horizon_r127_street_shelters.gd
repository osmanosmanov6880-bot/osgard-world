extends MultiMeshInstance3D
## R127 ORIGINAL authored walkable-city street furniture. These are *rendered*
## Godot volumetric meshes, not generated screenshots, external models or decals.
## Cosmetic only: no collision, pathfinding, missions, input or save mutation.
## One shared ArrayMesh / StandardMaterial3D across 24 deterministic shelters.
const SHELTER_COUNT: int = 24
static var _shared_mesh: ArrayMesh
static var _shared_finish: StandardMaterial3D

static func _triangle(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,tint: Color) -> void:
	st.set_color(tint)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

static func _quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,tint: Color) -> void:
	_triangle(st,a,b,c,tint)
	_triangle(st,a,c,d,tint)

static func _box(st: SurfaceTool,c: Vector3,h: Vector3,tint: Color) -> void:
	var x0: float = c.x-h.x
	var x1: float = c.x+h.x
	var y0: float = c.y-h.y
	var y1: float = c.y+h.y
	var z0: float = c.z-h.z
	var z1: float = c.z+h.z
	_quad(st,Vector3(x0,y0,z0),Vector3(x1,y0,z0),Vector3(x1,y1,z0),Vector3(x0,y1,z0),tint)
	_quad(st,Vector3(x1,y0,z1),Vector3(x0,y0,z1),Vector3(x0,y1,z1),Vector3(x1,y1,z1),tint)
	_quad(st,Vector3(x0,y0,z1),Vector3(x0,y0,z0),Vector3(x0,y1,z0),Vector3(x0,y1,z1),tint)
	_quad(st,Vector3(x1,y0,z0),Vector3(x1,y0,z1),Vector3(x1,y1,z1),Vector3(x1,y1,z0),tint)
	_quad(st,Vector3(x0,y1,z0),Vector3(x1,y1,z0),Vector3(x1,y1,z1),Vector3(x0,y1,z1),tint)
	_quad(st,Vector3(x0,y0,z1),Vector3(x1,y0,z1),Vector3(x1,y0,z0),Vector3(x0,y0,z0),tint)

static func geometry() -> ArrayMesh:
	if _shared_mesh != null:
		return _shared_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var graphite := Color("273139")
	var dark := Color("172126")
	var brass := Color("c4a578")
	var glass := Color("436570")
	var frame := Color("72838b")
	var seat := Color("665d52")
	var route := Color("2b9f9c")
	# PBR canopy and folded two-sided rain lip; authentic mesh depth, not billboards.
	_box(st,Vector3(0.0,2.41,0.0),Vector3(0.90,0.095,1.98),graphite)
	_box(st,Vector3(-0.84,2.29,0.0),Vector3(0.045,0.09,1.98),brass)
	_box(st,Vector3(0.84,2.29,0.0),Vector3(0.045,0.09,1.98),brass)
	_box(st,Vector3(0.0,2.30,-1.88),Vector3(0.83,0.065,0.055),frame)
	_box(st,Vector3(0.0,2.30,1.88),Vector3(0.83,0.065,0.055),frame)
	# Actual bounded columns, dark tempered 3D glass, no transparency sorting.
	for x in [-0.71,0.71]:
		for z in [-1.69,1.69]:
			_box(st,Vector3(float(x),1.17,float(z)),Vector3(0.052,1.14,0.053),frame)
			_box(st,Vector3(float(x),0.085,float(z)),Vector3(0.115,0.085,0.118),dark)
	_box(st,Vector3(0.72,1.31,0.0),Vector3(0.025,0.91,1.51),glass)
	for z in [-1.72,1.72]:
		_box(st,Vector3(0.02,1.31,float(z)),Vector3(0.63,0.91,0.024),glass)
	# A real bench with steel frame, substantial back, under-seat footings.
	_box(st,Vector3(0.15,0.55,0.0),Vector3(0.43,0.06,1.10),seat)
	_box(st,Vector3(0.54,0.91,0.0),Vector3(0.05,0.38,1.10),graphite)
	for z in [-0.90,0.90]:
		_box(st,Vector3(0.16,0.29,float(z)),Vector3(0.05,0.23,0.065),frame)
	# Route sign and champagne edge are in the same native volumetric batch.
	_box(st,Vector3(-0.71,1.81,-1.72),Vector3(0.115,0.31,0.027),dark)
	_box(st,Vector3(-0.71,1.85,-1.751),Vector3(0.071,0.115,0.014),route)
	_box(st,Vector3(0.0,2.52,0.0),Vector3(0.52,0.018,1.38),brass)
	st.generate_normals()
	_shared_mesh = st.commit()
	return _shared_mesh

static func finish() -> StandardMaterial3D:
	if _shared_finish == null:
		_shared_finish = StandardMaterial3D.new()
		_shared_finish.albedo_color = Color.WHITE
		_shared_finish.vertex_color_use_as_albedo = true
		_shared_finish.metallic = 0.27
		_shared_finish.roughness = 0.43
		_shared_finish.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _shared_finish

static func position_for(index: int) -> Vector3:
	# Existing physical roads are centred on multiples of 52 m and 10 m wide.
	# All 24 shelters live 8.35 m off a road axis, in mid-block frontage gaps;
	# never inside the original road collider or at the vehicle spawn point.
	var along: float = float(-156 + (index % 6)*52)
	var cross: float = float(-130 + int(index / 6)*104)
	var side: float = 1.0 if (index % 2)==0 else -1.0
	return Vector3(along+side*8.35,0.0,cross)

func _init() -> void:
	name = "R127ActualStreetShelters"
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = geometry()
	batch.instance_count = SHELTER_COUNT
	for i in range(SHELTER_COUNT):
		batch.set_instance_transform(i,Transform3D(Basis(),position_for(i)))
	multimesh = batch
	material_override = finish()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-225.0,-0.1,-220.0),Vector3(450.0,3.5,450.0))

func set_budget(tier: String) -> void:
	visible = tier != "low"

func bounded() -> bool:
	return multimesh != null and multimesh.instance_count == SHELTER_COUNT and (
		multimesh.mesh == geometry() and material_override == finish())
