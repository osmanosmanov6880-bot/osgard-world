extends SceneTree
## R102 native asset-tier test on the original live world and material.
## Never assumes uncommitted photos exist: missing verified assets fail safely.
const WORLD = preload("res://scripts/world_builder.gd")
var passed := 0
var failed := 0

func check(ok: bool, reason: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R102 REVIEWED PBR TIERS FAILED: " + reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = root.get_node_or_null("GameState")
	check(game != null, "real authoritative GameState autoload")
	if game == null:
		quit(1)
		return
	var before: Dictionary = (game.get("data") as Dictionary).duplicate(true)
	var scene: Node3D = WORLD.new()
	root.add_child(scene)
	var asphalt: StandardMaterial3D = scene.get("asphalt_pbr")
	var original_albedo: Texture2D = scene.get("r90_original_asphalt_albedo")
	var original_normal: Texture2D = scene.get("r90_original_asphalt_normal")
	check(asphalt != null and scene.get("r98_facade_ribs") != null,
		"same original road and bounded R98 3D city are fully mounted")
	if asphalt == null:
		quit(1)
		return
	var root_path: String = "res://assets/r90/"
	var available: bool = ResourceLoader.exists(root_path+"aerial_asphalt_01_diff_1k.jpg") and (
		ResourceLoader.exists(root_path+"aerial_asphalt_01_nor_gl_1k.jpg") and
		ResourceLoader.exists(root_path+"aerial_asphalt_01_rough_1k.jpg"))
	scene.call("apply_visual_budget","low")
	check(asphalt.albedo_texture == original_albedo and asphalt.normal_texture == original_normal,
		"mobile low quality preserves fast proven original road material")
	check(asphalt.roughness_texture == null,
		"mobile low never allocates new cinematic roughness map")
	scene.call("apply_visual_budget","standard")
	if available:
		check(asphalt.albedo_texture != null and asphalt.albedo_texture != original_albedo,
			"standard desktop visibly uses real pinned photographic asphalt albedo")
		check(asphalt.normal_texture == original_normal and asphalt.roughness_texture == null,
			"standard tier uses source-truth low-cost normals without full PBR overhead")
	else:
		check(asphalt.albedo_texture == original_albedo and asphalt.normal_texture == original_normal,
			"missing locked assets safely use original road instead of broken texture")
	scene.call("apply_visual_budget","cinematic")
	if available:
		check(asphalt.albedo_texture != null and asphalt.normal_texture != null and asphalt.roughness_texture != null,
			"full cinematic quality receives reviewed CC0 albedo, normal and roughness maps")
	else:
		check(asphalt.albedo_texture == original_albedo and asphalt.roughness_texture == null,
			"cinematic fallback must remain playable if locked binaries are absent")
	scene.call("apply_visual_budget","low")
	check(asphalt.roughness_texture == null and asphalt.albedo_texture == original_albedo,
		"switching down explicitly releases high-tier optional material textures")
	check(game.get("data") == before,"graphics settings never change saves, politics or missions")
	scene.queue_free()
	await process_frame
	print("EMPIRE Omega R102 reviewed authentic PBR road: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed == 0 else 1)
