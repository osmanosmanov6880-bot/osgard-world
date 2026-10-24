extends MultiMeshInstance3D
## HORIZON R25. Single-batch architectural cornices, geometry not billboards.
## A 4-piece roof crown per building; visible on standard/cinematic WebGL.
## No shadows, no collisions and no new draw call for each building.
const LIMIT: int = 1024
var placements: Array[Transform3D] = []
var source_buildings: int = 0

func record(center: Vector3, width: float, building_height: float) -> void:
	if not center.is_finite() or not is_finite(width) or not is_finite(building_height):
		return
	if width<4.0 or building_height<4.0 or placements.size()+4>LIMIT:
		return
	var roof_y: float = center.y+building_height*0.5+0.13
	var half: float = width*0.5
	var trim: float = 0.26
	var h: float = 0.24
	# Top and bottom edge strips on x faces; 4 solid cornice beams total.
	for side in [-1.0,1.0]:
		placements.append(Transform3D(Basis().scaled(Vector3(width+trim*2.0,h,trim)),
			Vector3(center.x,roof_y,center.z+side*(half+0.08))))
		placements.append(Transform3D(Basis().scaled(Vector3(trim,h,width+trim*2.0)),
			Vector3(center.x+side*(half+0.08),roof_y,center.z)))
	source_buildings+=1

func _ready() -> void:
	name="ArchitecturalCorniceBatch"

func finalize() -> void:
	var cube := BoxMesh.new()
	cube.size=Vector3.ONE
	var grid:=MultiMesh.new()
	grid.transform_format=MultiMesh.TRANSFORM_3D
	grid.mesh=cube
	grid.instance_count=placements.size()
	for i in range(placements.size()):
		grid.set_instance_transform(i,placements[i])
	multimesh=grid
	var paint:=StandardMaterial3D.new()
	paint.albedo_color=Color("89929a")
	paint.roughness=0.70
	paint.metallic=0.10
	material_override=paint
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# For the fixed 460m-wide city. Avoid per-chunk mesh allocations.
	custom_aabb=AABB(Vector3(-240.0,-4.0,-240.0),Vector3(480.0,80.0,480.0))
