extends MultiMeshInstance3D
## R98: original real 3D facade articulation for the native city, NOT decals.
## One deterministic GPU batch, no bodies, collision changes or RNG draws.
## Eight restrained mineral-metal vertical fins per original building.
const MAX_BUILDINGS := 128
const FINS_PER_BUILDING := 8
const MAX_INSTANCES := MAX_BUILDINGS * FINS_PER_BUILDING
const TRIANGLES_PER_INSTANCE := 12
const DISTRICT_METALS := {
	"forum": Color("a49782"),
	"housing": Color("8b979d"),
	"lower": Color("988f85"),
	"aqueduct": Color("8b9b9b")
}
var placements: Array[Transform3D] = []
var tint: Array[Color] = []
var source_buildings := 0

func record(center: Vector3, width: float, height: float, district: String) -> void:
	if not center.is_finite() or not is_finite(width) or not is_finite(height):
		return
	if width < 8.0 or width > 20.0 or height < 9.0 or height > 75.0:
		return
	if not DISTRICT_METALS.has(district) or placements.size() + FINS_PER_BUILDING > MAX_INSTANCES:
		return
	# Windows remain fully visible: fins sit at +/-42% of facade width,
	# outside the three existing window columns at 0 and +/-27%.
	var half: float = width * 0.5
	var effective_height: float = height - 3.7
	var middle_y: float = center.y - height*0.5 + 3.0 + effective_height*0.5
	var color: Color = DISTRICT_METALS[district]
	for side in [-1.0,1.0]:
		for lane in [-0.42,0.42]:
			var along: float = float(lane) * width
			var outer: float = float(side) * (half+0.17)
			placements.append(Transform3D(
				Basis().scaled(Vector3(0.23,effective_height,0.17)),
				Vector3(center.x+along,middle_y,center.z+outer)))
			tint.append(color)
			placements.append(Transform3D(
				Basis().scaled(Vector3(0.17,effective_height,0.23)),
				Vector3(center.x+outer,middle_y,center.z+along)))
			tint.append(color)
	source_buildings += 1

func finalize() -> void:
	assert(placements.size() == tint.size(), "R98 fins must have one material color per original geometry")
	assert(placements.size() <= MAX_INSTANCES, "R98 per-building GPU budget")
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var grid := MultiMesh.new()
	grid.transform_format = MultiMesh.TRANSFORM_3D
	grid.use_colors = true
	grid.mesh = box
	grid.instance_count = placements.size()
	for i in range(placements.size()):
		grid.set_instance_transform(i,placements[i])
		grid.set_instance_color(i,tint[i])
	multimesh = grid
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color.WHITE
	metal.vertex_color_use_as_albedo = true
	metal.metallic = 0.34
	metal.roughness = 0.49
	material_override = metal
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-240.0,0.0,-240.0),Vector3(480.0,80.0,480.0))

func _ready() -> void:
	name = "R98NativeFacadeFins"
	set_quality("standard")

func set_quality(mode: String) -> void:
	visible = mode != "low"

func graphics_are_bounded() -> bool:
	return multimesh != null and source_buildings >= 0 and source_buildings <= MAX_BUILDINGS and (
		multimesh.instance_count == source_buildings * FINS_PER_BUILDING and
		multimesh.instance_count <= MAX_INSTANCES and
		multimesh.instance_count * TRIANGLES_PER_INSTANCE <= MAX_INSTANCES * TRIANGLES_PER_INSTANCE and
		get_child_count() == 0)
