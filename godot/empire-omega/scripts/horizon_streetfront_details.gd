extends Node3D
## HORIZON R27 — actual solid storefront geometry in the procedural city.
## Reuses five MultiMeshes for the entire map, never one draw call per shop.
## Visuals only: no new collision bodies, economy items or fictitious shops.

const BUILDING_LIMIT: int = 256
# Facade order in WorldBuilder: front(-Z), back(+Z), left(-X), right(+X).
# Entrances rotate 90 degrees every fourth building.
const DOOR_FACE_ORDER = [0,2,1,3]

static func window_allowed(floor_index: int, facade_index: int, building_variation: int) -> bool:
	if floor_index>0:
		return true
	var yaw_index: int = posmod(building_variation,4)
	return facade_index != DOOR_FACE_ORDER[yaw_index]
var frontage_count: int = 0
var batches: int = 0
var glass_poses: Array[Transform3D] = []
var door_poses: Array[Transform3D] = []
var frame_poses: Array[Transform3D] = []
var awning_poses: Array[Transform3D] = []
var sign_poses: Array[Transform3D] = []
var glass_colors: Array[Color] = []
var door_colors: Array[Color] = []
var frame_colors: Array[Color] = []
var awning_colors: Array[Color] = []
var sign_colors: Array[Color] = []

func _ready() -> void:
	name = "HorizonStreetfrontBatch"

static func _pose(center: Vector3, width: float, yaw: float,
		offset_x: float, height: float, push_out: float, scale: Vector3) -> Transform3D:
	var orientation := Basis(Vector3.UP,yaw)
	# Front wall is local -Z; rotation chooses one of four usable facades.
	var location := Vector3(center.x,0.0,center.z)
	location += orientation*Vector3(offset_x,height,-(width*0.5+push_out))
	return Transform3D(orientation.scaled(scale),location)

func record(center: Vector3, width: float, height: float, variation: int) -> void:
	if frontage_count>=BUILDING_LIMIT or not center.is_finite() or not is_finite(width) or not is_finite(height):
		return
	if width<9.5 or height<7.0:
		return
	var yaw: float = float(posmod(variation,4))*PI*0.5
	var side_glass: float = maxf(1.1,(width-3.2)*0.5-0.65)
	var side_x: float = width*0.5-side_glass*0.5-0.34
	for side in [-1.0,1.0]:
		glass_poses.append(_pose(center,width,yaw,side*side_x,1.62,0.094,
			Vector3(side_glass,2.40,0.072)))
		glass_colors.append(Color("253843") if variation%2==0 else Color("314651"))
		frame_poses.append(_pose(center,width,yaw,side*1.28,1.55,0.15,
			Vector3(0.16,2.90,0.17)))
		frame_colors.append(Color("727f86"))
	door_poses.append(_pose(center,width,yaw,0.0,1.50,0.14,Vector3(2.37,2.78,0.08)))
	door_colors.append(Color("1a2932") if variation%3==0 else Color("2b4050"))
	frame_poses.append(_pose(center,width,yaw,0.0,3.035,0.18,Vector3(2.75,0.18,0.18)))
	frame_colors.append(Color("849099"))
	awning_poses.append(_pose(center,width,yaw,0.0,3.22,0.55,Vector3(4.1,0.19,1.19)))
	awning_colors.append(Color("667a82") if variation%2==0 else Color("77838d"))
	sign_poses.append(_pose(center,width,yaw,0.0,3.73,0.15,Vector3(width*0.75,0.38,0.16)))
	sign_colors.append(Color("627078") if variation%3==0 else Color("89939b"))
	frontage_count += 1

func _batch(id: String, poses: Array[Transform3D], colors: Array[Color],
		roughness: float, metallic: float) -> void:
	assert(poses.size()==colors.size(),"Streetfront geometry and tint arrays must match")
	if poses.is_empty():
		return
	var cuboid := BoxMesh.new()
	cuboid.size = Vector3.ONE
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = cuboid
	instances.instance_count = poses.size()
	for i in range(poses.size()):
		instances.set_instance_transform(i,poses[i])
		instances.set_instance_color(i,colors[i])
	var visual := MultiMeshInstance3D.new()
	visual.name = id
	visual.multimesh = instances
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.custom_aabb = AABB(Vector3(-245.0,-1.0,-245.0),Vector3(490.0,70.0,490.0))
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = roughness
	material.metallic = metallic
	material.albedo_color = Color.WHITE
	visual.material_override = material
	add_child(visual)
	batches += 1

func finalize() -> void:
	# At most five GPU batches regardless of the number of facades.
	_batch("ShopfrontGlassBatch",glass_poses,glass_colors,0.18,0.14)
	_batch("EntranceDoorBatch",door_poses,door_colors,0.25,0.10)
	_batch("MetalJambBatch",frame_poses,frame_colors,0.44,0.42)
	_batch("SatinAwningBatch",awning_poses,awning_colors,0.63,0.16)
	_batch("StreetSignBandBatch",sign_poses,sign_colors,0.71,0.15)

func surface_instance_count() -> int:
	var total := 0
	for child in get_children():
		if child is MultiMeshInstance3D:
			total += (child as MultiMeshInstance3D).multimesh.instance_count
	return total
