extends Node3D
## EMPIRE Omega R38: genuine 3D corner pieces, storm drains, metal bollards.
## Four globally instanced geometry calls, no fake screen overlay or colliders.
## The real 52m road lattice and existing traffic collisions are unchanged.
const HALF_CITY: float = 224.0
const MAX_INSTANCES: int = 1024
const MAX_GRATE_VERTICES: int = 140
const GRID_RADIUS: int = 4
var intersection_count := 0
var batch_count := 0
var curbs: Array[Transform3D] = []
var curb_colors: Array[Color] = []
var drains: Array[Transform3D] = []
var drain_colors: Array[Color] = []
var bollards: Array[Transform3D] = []
var bollard_colors: Array[Color] = []
var caps: Array[Transform3D] = []
var cap_colors: Array[Color] = []

func _ready() -> void:
	name = "R38GenuineStreetInfrastructure"
	_build()
	_finalize()
	set_quality("standard")

func _build() -> void:
	for ix in range(-GRID_RADIUS,GRID_RADIUS+1):
		for iz in range(-GRID_RADIUS,GRID_RADIUS+1):
			var center := Vector3(float(ix)*52.0,0.0,float(iz)*52.0)
			intersection_count += 1
			for sx in [-1.0,1.0]:
				for sz in [-1.0,1.0]:
					var corner := center+Vector3(sx*7.2,0.0,sz*7.2)
					# Actual raised stone transition where the sidewalk begins.
					curbs.append(Transform3D(Basis().scaled(Vector3(1.70,0.18,0.54)),
						corner+Vector3(0,0.17,0)))
					curb_colors.append(Color("7d8586") if (ix+iz)%2==0 else Color("98968b"))
					# Storm drainage sits near the carriageway edge.
					drains.append(Transform3D(Basis().scaled(Vector3(0.82,0.038,0.35)),
						center+Vector3(sx*5.58,0.20,sz*9.2)))
					drain_colors.append(Color("35454e"))
					drains.append(Transform3D(Basis().scaled(Vector3(0.35,0.038,0.82)),
						center+Vector3(sx*9.2,0.20,sz*5.58)))
					drain_colors.append(Color("35454e"))
					# Streetscape fixtures on corner plaza, not in drive lane.
					var where := center+Vector3(sx*8.55,0.0,sz*8.55)
					bollards.append(Transform3D(Basis().scaled(Vector3(0.22,0.80,0.22)),
						where+Vector3(0,0.52,0)))
					bollard_colors.append(Color("3d515e"))
					caps.append(Transform3D(Basis().scaled(Vector3(0.26,0.12,0.26)),
						where+Vector3(0,0.95,0)))
					cap_colors.append(Color("b2aba0"))

func _batch(label: String, geometry: Mesh, poses: Array[Transform3D],
		colors: Array[Color],roughness: float,metal: float) -> void:
	assert(poses.size()==colors.size(),"R38 instance color count mismatch")
	assert(poses.size()<=MAX_INSTANCES,"R38 batch exceeded browser budget")
	if poses.is_empty():
		return
	var instance := MultiMesh.new()
	instance.transform_format = MultiMesh.TRANSFORM_3D
	instance.use_colors = true
	instance.mesh = geometry
	instance.instance_count = poses.size()
	for i in range(poses.size()):
		instance.set_instance_transform(i,poses[i])
		instance.set_instance_color(i,colors[i])
	var mesh := MultiMeshInstance3D.new()
	mesh.name = label
	mesh.multimesh = instance
	mesh.custom_aabb = AABB(Vector3(-235,-1,-235),Vector3(470,9,470))
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = roughness
	mat.metallic = metal
	mesh.material_override = mat
	add_child(mesh)
	batch_count += 1

# Five welded rails form real voids between the drainage ribs.
# A single low-vertex ArrayMesh is instanced 648 times in ONE GPU batch;
# no static colliders or per-grate draw calls are created.
func _drain_grate_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	for x in [-0.34,0.0,0.34]:
		surface.append_from(unit,0,Transform3D(
			Basis().scaled(Vector3(0.075,0.58,0.72)),Vector3(x,0,0)))
	for z in [-0.44,0.44]:
		surface.append_from(unit,0,Transform3D(
			Basis().scaled(Vector3(0.95,0.55,0.12)),Vector3(0,0,z)))
	return surface.commit()

func _finalize() -> void:
	var block := BoxMesh.new()
	block.size = Vector3.ONE
	var post := CylinderMesh.new()
	post.top_radius = 0.40
	post.bottom_radius = 0.50
	post.height = 1.0
	post.radial_segments = 8
	_batch("R38RealCurbStones",block,curbs,curb_colors,0.85,0.025)
	_batch("R38StormDrainGrates",_drain_grate_mesh(),drains,drain_colors,0.48,0.70)
	_batch("R38ProtectiveMetalBollards",post,bollards,bollard_colors,0.40,0.63)
	_batch("R38BollardMetalCaps",block,caps,cap_colors,0.38,0.60)
	assert(batch_count==4,"R38 uses exactly four shared GPU batches")

func set_quality(tier: String) -> void:
	var quality: String = tier if ["low","standard","cinematic"].has(tier) else "standard"
	visible = quality!="low"
	for node in get_children():
		if node is MultiMeshInstance3D:
			node.visible = quality=="cinematic" or node.name!="R38BollardMetalCaps"

func geometry_instances() -> int:
	var count := 0
	for node in get_children():
		if node is MultiMeshInstance3D:
			count += node.multimesh.instance_count
	return count
