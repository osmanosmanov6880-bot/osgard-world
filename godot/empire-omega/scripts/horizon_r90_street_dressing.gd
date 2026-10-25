extends Node3D
## R90 original procedural street dressing, created with instancing.
## All geometry is cosmetic: no collision bodies, no save mutations or AI.
## This deliberately does NOT claim imported photogrammetry/AAA assets.
const SKYLINE_COUNT := 72
const STREET_BOLLARD_COUNT := 144
const R91_ARCHITECTURE = preload("res://scripts/horizon_r91_skyline_detail.gd")
var skyline: MultiMeshInstance3D
var skyline_plan: Array[Transform3D] = []
var bollards: MultiMeshInstance3D
var r91_architecture: Node3D
var quality := "standard"

func _ready() -> void:
	name = "R90UrbanAtmosphere"
	_build_outer_skyline()
	_build_sidewalk_bollards()
	r91_architecture = R91_ARCHITECTURE.new()
	r91_architecture.call("set_source_skyline",skyline,skyline_plan)
	add_child(r91_architecture)
	set_quality("standard")

func _material(tint: Color,metal: float,rough: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.metallic = metal
	mat.roughness = rough
	return mat

func _build_outer_skyline() -> void:
	var block := BoxMesh.new()
	block.size = Vector3.ONE
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
		var shade: float = 0.70+0.09*float(i%5)
		mesh.set_instance_color(i,Color(0.32*shade,0.39*shade,0.48*shade))
	skyline = MultiMeshInstance3D.new()
	skyline.name = "ActualDistantBuildingGeometry"
	skyline.multimesh = mesh
	var building_finish := _material(Color("bac6d2"),0.14,0.57)
	# R90 actual screenshot exposed previous white skyscrapers:
	# per-instance RGB is ignored until enabled on Godot material.
	building_finish.vertex_color_use_as_albedo = true
	skyline.material_override = building_finish
	skyline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skyline.custom_aabb = AABB(Vector3(-340,0,-340),Vector3(680,116,680))
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

func graphics_are_bounded() -> bool:
	return skyline != null and bollards != null and r91_architecture != null and (
		skyline.multimesh.instance_count == SKYLINE_COUNT and
		bollards.multimesh.instance_count == STREET_BOLLARD_COUNT and
		bool(r91_architecture.call("graphics_are_bounded")))
