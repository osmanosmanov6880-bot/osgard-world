extends Node3D
## HORIZON R35. Actual solid exterior balcony assemblies for original buildings.
## Four globally instanced GPU batches, independent of per-building collisions.
## Only street-facing upper floors receive balconies; no fictitious interior.
const BUILDING_LIMIT: int = 256
const MAX_FLOORS: int = 3
const MAX_INSTANCES_PER_GROUP: int = 1024

var source_buildings: int = 0
var balcony_count: int = 0
var batch_count: int = 0
var slab_poses: Array[Transform3D] = []
var guard_poses: Array[Transform3D] = []
var rail_poses: Array[Transform3D] = []
var post_poses: Array[Transform3D] = []
var slab_tints: Array[Color] = []
var guard_tints: Array[Color] = []
var rail_tints: Array[Color] = []
var post_tints: Array[Color] = []

static func _pose(center: Vector3, width: float, yaw: float, x: float,
		level: float, exterior: float, dimensions: Vector3) -> Transform3D:
	var direction := Basis(Vector3.UP,yaw)
	var position := Vector3(center.x,level,center.z)
	position += direction*Vector3(x,0.0,-(width*0.5+exterior))
	return Transform3D(direction.scaled(dimensions),position)

func record(center: Vector3, width: float, height: float,
		variation: int, face: int) -> void:
	if not center.is_finite() or not is_finite(width) or not is_finite(height):
		return
	if width < 10.0 or height < 12.0 or source_buildings >= BUILDING_LIMIT:
		return
	source_buildings += 1
	# Alternating buildings avoid copy-pasted slabs across a whole boulevard.
	if variation % 2 != 0:
		return
	var yaw: float = float(posmod(face,4))*PI*0.5
	var offset_x: float = -2.8 if variation % 4 == 0 else 2.8
	var front_color := Color("b6b7ad") if variation % 4 == 0 else Color("8c9c9e")
	var face_color := Color("364b58") if variation % 3 == 0 else Color("4b5b64")
	for floor_index in range(1,MAX_FLOORS+1):
		var window_y: float = 2.9+float(floor_index)*4.4
		if window_y+1.1 > height or post_poses.size()+2>MAX_INSTANCES_PER_GROUP:
			continue
		var slab_y: float = window_y-1.17
		slab_poses.append(_pose(center,width,yaw,offset_x,slab_y,0.69,
			Vector3(3.75,0.16,1.26)))
		slab_tints.append(front_color)
		guard_poses.append(_pose(center,width,yaw,offset_x,slab_y+0.53,1.30,
			Vector3(3.50,0.94,0.075)))
		guard_tints.append(face_color)
		rail_poses.append(_pose(center,width,yaw,offset_x,slab_y+1.05,1.32,
			Vector3(3.65,0.12,0.14)))
		rail_tints.append(Color("9ba6a9"))
		for side in [-1.0,1.0]:
			post_poses.append(_pose(center,width,yaw,offset_x+side*1.76,
				slab_y+0.54,1.31,Vector3(0.12,1.09,0.14)))
			post_tints.append(Color("7b858b"))
		balcony_count += 1

func _batch(id: String, poses: Array[Transform3D], colors: Array[Color],
		roughness: float, metallic: float) -> void:
	assert(poses.size()==colors.size(),"R35 geometry and tint instance arrays differ")
	if poses.is_empty():
		return
	assert(poses.size()<=MAX_INSTANCES_PER_GROUP,"R35 geometry budget exceeded")
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = unit
	instances.instance_count = poses.size()
	for i in range(poses.size()):
		instances.set_instance_transform(i,poses[i])
		instances.set_instance_color(i,colors[i])
	var mesh := MultiMeshInstance3D.new()
	mesh.name = id
	mesh.multimesh = instances
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.custom_aabb = AABB(Vector3(-240,-2,-240),Vector3(480,90,480))
	var finish := StandardMaterial3D.new()
	finish.vertex_color_use_as_albedo = true
	finish.albedo_color = Color.WHITE
	finish.roughness = roughness
	finish.metallic = metallic
	mesh.material_override = finish
	add_child(mesh)
	batch_count += 1

func finalize() -> void:
	name = "HorizonFacadeBalconiesR35"
	_batch("R35StoneSlabs",slab_poses,slab_tints,0.82,0.015)
	_batch("R35SolidBalconyGuards",guard_poses,guard_tints,0.54,0.11)
	_batch("R35MetalHandrails",rail_poses,rail_tints,0.34,0.62)
	_batch("R35MetalCornerPosts",post_poses,post_tints,0.40,0.55)
	assert(batch_count<=4,"R35 geometry must use at most four shared GPU batches")
	set_quality("standard")

func set_quality(tier: String) -> void:
	var quality: String = tier if ["low","standard","cinematic"].has(tier) else "standard"
	visible = quality!="low"
	for node in get_children():
		if node is MultiMeshInstance3D:
			node.visible = quality=="cinematic" or node.name!="R35MetalCornerPosts"

func surface_instance_count() -> int:
	var total := 0
	for node in get_children():
		if node is MultiMeshInstance3D:
			total += node.multimesh.instance_count
	return total
