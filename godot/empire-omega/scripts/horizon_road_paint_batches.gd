extends Node3D
## HORIZON R28: one draw batch for lane dashes and one for road edges.
## Replaces 378 individual WorldBuilder RoadDash MeshInstance3D objects,
## each with their own BoxMesh and material, without touching road physics.
## This is visual paint only. No physical colliders, shaders or particles.
const INTERVAL: float = 52.0
const DASH_LIMIT: int = 400
const EDGE_LIMIT: int = 300
const DASH_LENGTH: float = 7.0
const DASH_WIDTH: float = 0.19
const EDGE_LENGTH: float = 42.0
const EDGE_WIDTH: float = 0.085

var dash_transforms: Array[Transform3D] = []
var edge_transforms: Array[Transform3D] = []
var lane_batch: MultiMeshInstance3D
var boundary_batch: MultiMeshInstance3D
var lane_material: StandardMaterial3D
var boundary_material: StandardMaterial3D
var finalized := false

func _ready() -> void:
	name = "RoadMarkingsGPUBatch"

func record_dash(horizontal: bool, along: float, road_at: float) -> void:
	if finalized or not is_finite(along) or not is_finite(road_at):
		return
	if dash_transforms.size() >= DASH_LIMIT:
		return
	var width := Vector3(DASH_LENGTH,0.035,DASH_WIDTH) if horizontal else Vector3(DASH_WIDTH,0.035,DASH_LENGTH)
	var point := Vector3(along,0.195,road_at) if horizontal else Vector3(road_at,0.198,along)
	dash_transforms.append(Transform3D(Basis().scaled(width),point))

func record_road_edges() -> void:
	if finalized:
		return
	# Nine roads in each orientation, eight between-intersection stretches;
	# both shoulders are at +/-4.55m within the existing 10m asphalt width.
	for road in range(-4,5):
		var center: float = float(road)*INTERVAL
		for span in range(-4,4):
			var midpoint: float = (float(span)+0.5)*INTERVAL
			for side in [-1.0,1.0]:
				if edge_transforms.size()+2 > EDGE_LIMIT:
					return
				var shoulder: float = float(side)*4.58
				edge_transforms.append(Transform3D(
					Basis().scaled(Vector3(EDGE_LENGTH,0.020,EDGE_WIDTH)),
					Vector3(midpoint,0.197,center+shoulder)))
				edge_transforms.append(Transform3D(
					Basis().scaled(Vector3(EDGE_WIDTH,0.020,EDGE_LENGTH)),
					Vector3(center+shoulder,0.197,midpoint)))

func _make_batch(id: String, placements: Array[Transform3D], tint: Color) -> MultiMeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var grid := MultiMesh.new()
	grid.transform_format = MultiMesh.TRANSFORM_3D
	grid.mesh = mesh
	grid.instance_count = placements.size()
	for index in range(placements.size()):
		grid.set_instance_transform(index,placements[index])
	var visual := MultiMeshInstance3D.new()
	visual.name = id
	visual.multimesh = grid
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.custom_aabb = AABB(Vector3(-230.0,-0.3,-230.0),Vector3(460.0,1.0,460.0))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.metallic = 0.0
	mat.roughness = 0.82
	visual.material_override = mat
	add_child(visual)
	return visual

func finish() -> void:
	if finalized:
		return
	lane_batch = _make_batch("LaneDashMultiMesh",dash_transforms,Color("c9b78b"))
	boundary_batch = _make_batch("ShoulderLineMultiMesh",edge_transforms,Color("adb0ab"))
	lane_material = lane_batch.material_override as StandardMaterial3D
	boundary_material = boundary_batch.material_override as StandardMaterial3D
	finalized = true

func apply_weather(kind: String) -> void:
	var wet: bool = kind == "rain" or kind == "storm"
	if lane_material != null:
		lane_material.roughness = 0.53 if wet else 0.82
	if boundary_material != null:
		boundary_material.roughness = 0.56 if wet else 0.84

func instance_count() -> int:
	return dash_transforms.size()+edge_transforms.size()
