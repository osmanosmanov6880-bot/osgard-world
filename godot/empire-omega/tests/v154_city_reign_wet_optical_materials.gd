extends SceneTree
## R168 physical authored wet PBR and bounded 72-instance rainy surface.
const OPTICS = preload("res://scripts/city_reign_atmospheric_optics.gd")
const ROAD = preload("res://scripts/horizon_road_materials.gd")
const PUDDLES = preload("res://scripts/horizon_rain_puddles.gd")
# World script depends on the live GameState autoload; defer loading until SceneTree initializes.
var passed: int = 0
var failed: int = 0

func check(ok: bool,reason: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error("CITY REIGN R168 WET SURFACE FAIL: "+reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var asphalt: StandardMaterial3D = ROAD.asphalt()
	var original_albedo: Texture2D = asphalt.albedo_texture
	ROAD.apply_weather(asphalt,"rain")
	OPTICS.apply_road_finish(asphalt,"rain","cinematic")
	check(asphalt.clearcoat_enabled and asphalt.clearcoat > 0.5 and
		asphalt.clearcoat_roughness<0.25 and asphalt.roughness<0.50,
		"existing R15 wet asphalt has real environment-lit PBR clearcoat")
	check(asphalt.albedo_texture==original_albedo,
		"original authored road texture is NOT replaced by a static reflection screenshot")
	OPTICS.apply_road_finish(asphalt,"rain","low")
	check(not asphalt.clearcoat_enabled and asphalt.roughness<0.50,
		"LOW disables extra optical computation without changing road wet traction")
	ROAD.apply_weather(asphalt,"clear")
	OPTICS.apply_road_finish(asphalt,"clear","cinematic")
	check(not asphalt.clearcoat_enabled and asphalt.roughness>0.7,
		"dry road returns original physical roughness and no wet coating")
	var puddles: MultiMeshInstance3D = PUDDLES.new()
	root.add_child(puddles)
	var batch: MultiMesh = puddles.multimesh
	var shared_plane: PlaneMesh = batch.mesh as PlaneMesh
	var material: StandardMaterial3D = shared_plane.material as StandardMaterial3D
	puddles.set_conditions("rain","cinematic")
	puddles.set_reflective_grade(12.0,"cinematic")
	var noon_tint: Color = material.albedo_color
	puddles.set_reflective_grade(22.0,"cinematic")
	check(material.albedo_color!=noon_tint and material.clearcoat_enabled,
		"one original pooled puddle surface responds to actual clock and wetness")
	check(puddles.multimesh==batch and batch.instance_count==72 and
		batch.mesh==shared_plane and puddles.material_is_bounded(),
		"all 72 rainy patches remain ONE original instanced draw, no extra reflections")
	puddles.set_conditions("storm","low")
	puddles.set_reflective_grade(22.0,"low")
	check(not puddles.visible and not material.clearcoat_enabled,
		"mobile LOW removes expensive puddle optics and visuals")
	puddles.queue_free()
	var world_script: Variant = load("res://scripts/world_builder.gd")
	check(world_script is Script and world_script.can_instantiate(),
		"existing city loads after SceneTree autoload initialization")
	if not (world_script is Script and world_script.can_instantiate()):
		quit(2)
		return
	var world: Node3D = world_script.new()
	root.add_child(world)
	world.apply_visual_budget("cinematic")
	world.update_weather("rain")
	check(world.asphalt_pbr.clearcoat_enabled and world.asphalt_pbr.roughness<0.5,
		"real live asphalt uses source PBR wet reflection pass")
	world.update_weather("clear")
	check(not world.asphalt_pbr.clearcoat_enabled and world.asphalt_pbr.roughness>0.7,
		"original city weather clears wet specular surface without recreating roads")
	world.queue_free()
	await process_frame
	print("CITY REIGN R168 WET OPTICS: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
