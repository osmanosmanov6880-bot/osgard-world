extends SceneTree
## R106: actual original Godot texture activation, not just fallback math.
## All three human-reviewed Poly Haven CC0 1K binaries MUST be embedded.
var passed := 0
var failed := 0

func check(ok: bool,why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R106 EMBEDDED ORIGINAL PBR FAILED: " + why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = root.get_node_or_null("GameState")
	check(game != null, "actual GameState autoload is present")
	if game == null:
		quit(1)
		return
	var original_data: Dictionary = (game.get("data") as Dictionary).duplicate(true)
	var dir: String = "res://assets/r90/"
	var maps: Array[String] = [
		"aerial_asphalt_01_diff_1k.jpg",
		"aerial_asphalt_01_nor_gl_1k.jpg",
		"aerial_asphalt_01_rough_1k.jpg"]
	for file_name in maps:
		var asset: String = dir + file_name
		check(FileAccess.file_exists(asset) and ResourceLoader.exists(asset),
			"original original reviewed 1024x1024 CC0 file is EMBEDDED: " + asset)
	var world_source: Variant = load("res://scripts/world_builder.gd")
	check(world_source is Script and world_source.can_instantiate(),
		"original runtime WorldBuilder compiled after autoload")
	if not (world_source is Script and world_source.can_instantiate()):
		quit(1)
		return
	var scene: Node3D = world_source.new()
	root.add_child(scene)
	var road: StandardMaterial3D = scene.get("asphalt_pbr") as StandardMaterial3D
	check(road != null, "original physical road material exists")
	if road != null:
		var base_color: Texture2D = scene.get("r90_original_asphalt_albedo") as Texture2D
		var base_normal: Texture2D = scene.get("r90_original_asphalt_normal") as Texture2D
		scene.call("apply_visual_budget","low")
		check(road.albedo_texture == base_color and road.normal_texture == base_normal,
			"low mobile mode preserves old traffic/performance materials")
		check(road.roughness_texture == null,
			"low mobile tier never allocates extra photographic map")
		scene.call("apply_visual_budget","standard")
		check(road.albedo_texture != null and road.albedo_texture != base_color,
			"STANDARD actually activates authentic photographic road albedo")
		check(road.normal_texture == base_normal and road.roughness_texture == null,
			"STANDARD keeps lightweight pre-existing normal without extra roughness map")
		scene.call("apply_visual_budget","cinematic")
		check(road.albedo_texture != null and road.normal_texture != null and
			road.roughness_texture != null,
			"CINEMATIC activates real albedo, normal and roughness original files")
		if road.normal_texture != null and road.roughness_texture != null:
			check(road.normal_texture != base_normal,
				"CINEMATIC normal actually switches to verified original normal file")
		scene.call("apply_visual_budget","low")
		check(road.albedo_texture == base_color and road.roughness_texture == null,
			"switching back to LOW removes expensive photo maps")
	check(scene.get("r98_facade_ribs") != null,
		"original same-city 3D facades remain authoritative")
	check(game.get("data") == original_data,
		"quality selection never alters missions, money, physics or saved state")
	scene.queue_free()
	await process_frame
	print("EMPIRE OMEGA R106 true embedded PBR maps: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed == 0 else 1)
