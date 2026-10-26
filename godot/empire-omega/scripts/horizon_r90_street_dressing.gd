extends Node3D
## R90 original procedural street dressing, created with instancing.
## All geometry is cosmetic: no collision bodies, no save mutations or AI.
## This deliberately does NOT claim imported photogrammetry/AAA assets.
const SKYLINE_COUNT := 72
const STREET_BOLLARD_COUNT := 144
const R91_ARCHITECTURE = preload("res://scripts/horizon_r91_skyline_detail.gd")
const FACADE_PACK = preload("res://scripts/horizon_facade_material_pack.gd")
const R127_SHELTERS = preload("res://scripts/horizon_r127_street_shelters.gd")
var skyline: MultiMeshInstance3D
var skyline_plan: Array[Transform3D] = []
var bollards: MultiMeshInstance3D
var r91_architecture: Node3D
var r127_shelters: MultiMeshInstance3D
var quality := "standard"

func _ready() -> void:
	name = "R90UrbanAtmosphere"
	_build_outer_skyline()
	_build_sidewalk_bollards()
	r91_architecture = R91_ARCHITECTURE.new()
	r91_architecture.call("set_source_skyline",skyline,skyline_plan)
	add_child(r91_architecture)
	# R127: nest one additional actual PBR street-detail GPU batch under the
	# existing visible facade-detail grouping. Preserve all original R91 root
	# node counts, 72 tower transforms, road traffic and 3D mission colliders.
	var facade: MultiMeshInstance3D = r91_architecture.get("facade_glass") as MultiMeshInstance3D
	r127_shelters = R127_SHELTERS.new()
	facade.add_child(r127_shelters)
	set_quality("standard")

func _material(tint: Color,metal: float,rough: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.metallic = metal
	mat.roughness = rough
	return mat

# R116: one shared physical building body surface for every original R90 tower.
# All seven architectural masses belong to ONE ArrayMesh draw batch, instanced
# by the original 72 MultiMesh transforms. Roof R114 + window R91 coordinates
# remain anchored to the original unmodified normalized building footprint.
static func _body_box(st: SurfaceTool, minimum: Vector3, maximum: Vector3) -> void:
	var v: Array[Vector3] = [
		Vector3(minimum.x,minimum.y,minimum.z),
		Vector3(maximum.x,minimum.y,minimum.z),
		Vector3(maximum.x,minimum.y,maximum.z),
		Vector3(minimum.x,minimum.y,maximum.z),
		Vector3(minimum.x,maximum.y,minimum.z),
		Vector3(maximum.x,maximum.y,minimum.z),
		Vector3(maximum.x,maximum.y,maximum.z),
		Vector3(minimum.x,maximum.y,maximum.z)]
	var quads: Array = [
		[0,1,2,3],[4,7,6,5],[0,4,5,1],
		[1,5,6,2],[2,6,7,3],[3,7,4,0]]
	for quad in quads:
		var a: Vector3 = v[int(quad[0])]
		var b: Vector3 = v[int(quad[1])]
		var c: Vector3 = v[int(quad[2])]
		var d: Vector3 = v[int(quad[3])]
		var normal: Vector3 = (b-a).cross(c-a).normalized()
		for vertex in [a,b,c,a,c,d]:
			st.set_normal(normal)
			st.add_vertex(vertex)

static func _structural_tower_body() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The original wall extent stays exactly +-0.5, preserving R91 windows.
	_body_box(st,Vector3(-0.50,-0.50,-0.50),Vector3(0.50,0.50,0.50))
	# Four physically protruding corner piers. No separate scene nodes.
	for sx in [-1.0,1.0]:
		for sz in [-1.0,1.0]:
			var cx: float = float(sx)*0.485
			var cz: float = float(sz)*0.485
			_body_box(st,Vector3(cx-0.036,-0.48,cz-0.036),
				Vector3(cx+0.036,0.45,cz+0.036))
	# Architectural podium and parapet: distinct real depth and silhouette.
	_body_box(st,Vector3(-0.528,-0.50,-0.528),Vector3(0.528,-0.45,0.528))
	_body_box(st,Vector3(-0.526,0.46,-0.526),Vector3(0.526,0.50,0.526))
	return st.commit()

func _build_outer_skyline() -> void:
	var block := _structural_tower_body()
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.use_colors = true
	mesh.mesh = block
	mesh.instance_count = SKYLINE_COUNT
	var rng := RandomNumberGenerator.new()
	rng.seed = 9042026
	skyline_plan.clear()
	for i in range(SKYLINE_COUNT):
		var angle: float = TAU*(float(i)+0.15*float(i%3))/float(SKYLINE_COUNT)
		var radius: float = 248.0 + float(i%6)*16.5
		var height: float = rng.randf_range(27.0,89.0)
		var w: float = rng.randf_range(10.0,24.0)
		var d: float = rng.randf_range(10.0,22.0)
		var center := Vector3(cos(angle)*radius,height*0.5,sin(angle)*radius)
		var original_tower := Transform3D(Basis().scaled(Vector3(w,height,d)),center)
		skyline_plan.append(original_tower)
		mesh.set_instance_transform(i,original_tower)
		# Deterministic architectural palette; same original R90 building index.
		var shades: Array[Color] = [
			Color("627385"),Color("879098"),Color("6f756f"),
			Color("9b998e"),Color("526676"),Color("78818b")]
		mesh.set_instance_color(i,shades[i%shades.size()])
	skyline = MultiMeshInstance3D.new()
	skyline.name = "ActualDistantBuildingGeometry"
	skyline.multimesh = mesh
	# R116 real shared mineral PBR: cached 128px limestone colour, OpenGL
	# normal and red-channel roughness. ZERO per-building texture allocation.
	var building_finish: StandardMaterial3D = FACADE_PACK.facade(Color("c5c4bf"),1)
	building_finish.vertex_color_use_as_albedo = true
	skyline.material_override = building_finish
	skyline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skyline.custom_aabb = AABB(Vector3(-356,0,-356),Vector3(712,116,712))
	add_child(skyline)

func _build_sidewalk_bollards() -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.10
	cylinder.bottom_radius = 0.12
	cylinder.height = 0.90
	cylinder.radial_segments = 8
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.mesh = cylinder
	mesh.instance_count = STREET_BOLLARD_COUNT
	for i in range(STREET_BOLLARD_COUNT):
		var road: int = (i/16)%9-4
		var along: int = i%16
		var distance: float = -204.0 + float(along)*27.0
		var offset: float = 7.35 if (i/8)%2==0 else -7.35
		var lane: float = float(road)*52.0
		var at := Vector3(distance,0.53,lane+offset) if (i/16)%2==0 else Vector3(lane+offset,0.53,distance)
		mesh.set_instance_transform(i,Transform3D(Basis(),at))
	bollards = MultiMeshInstance3D.new()
	bollards.name = "RealMeshInstancedSidewalkBollards"
	bollards.multimesh = mesh
	bollards.material_override = _material(Color("344351"),0.70,0.36)
	bollards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bollards.custom_aabb = AABB(Vector3(-230,0,-230),Vector3(460,2,460))
	add_child(bollards)

func set_quality(tier: String) -> void:
	quality = tier if ["low","standard","cinematic"].has(tier) else "standard"
	if skyline != null:
		skyline.visible = quality != "low"
	if bollards != null:
		bollards.visible = quality == "cinematic"
	if r91_architecture != null:
		r91_architecture.call("set_quality",quality)
	if r127_shelters != null:
		r127_shelters.call("set_budget",quality)

func graphics_are_bounded() -> bool:
	return skyline != null and bollards != null and r91_architecture != null and r127_shelters != null and (
		skyline.multimesh.instance_count == SKYLINE_COUNT and
		bollards.multimesh.instance_count == STREET_BOLLARD_COUNT and
		bool(r91_architecture.call("graphics_are_bounded")) and
		bool(r127_shelters.call("bounded")))
