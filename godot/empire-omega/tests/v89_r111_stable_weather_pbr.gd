extends SceneTree
## R111 native source regression: material identity must be stable regardless
## of CC0 photographic road UV scale, display quality or actual rain state.
const MATERIALS = preload("res://scripts/horizon_road_materials.gd")
var passed := 0
var failed := 0

func check(ok: bool, why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R111 PHOTO/RAIN MATERIAL FAILURE: " + why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var asphalt: StandardMaterial3D = MATERIALS.asphalt()
	var concrete: StandardMaterial3D = MATERIALS.concrete()
	check(asphalt.resource_name == "HORIZON_ROAD_ASPHALT",
		"original asphalt has explicit semantic identity")
	check(concrete.resource_name == "HORIZON_ROAD_CONCRETE",
		"original concrete has explicit semantic identity")
	for uv in [0.12,0.38,0.85]:
		asphalt.uv1_scale = Vector3.ONE * uv
		MATERIALS.apply_weather(asphalt,"rain")
		check(is_equal_approx(asphalt.roughness,0.36),
			"wet PHOTO asphalt stays asphalt at UV %.2f" % uv)
		MATERIALS.apply_weather(asphalt,"clear")
		check(is_equal_approx(asphalt.roughness,0.81),
			"dry PHOTO asphalt restores true R15 roughness at UV %.2f" % uv)
		MATERIALS.apply_weather(asphalt,"storm")
		MATERIALS.apply_weather(asphalt,"clear")
		check(is_equal_approx(asphalt.roughness,0.81),
			"storm then clear restores the original grip budget at UV %.2f" % uv)
	for uv in [0.12,0.22,0.90]:
		concrete.uv1_scale = Vector3.ONE * uv
		MATERIALS.apply_weather(concrete,"storm")
		check(is_equal_approx(concrete.roughness,0.46),
			"true concrete stays concrete at UV %.2f" % uv)
		MATERIALS.apply_weather(concrete,"clear")
		check(is_equal_approx(concrete.roughness,0.90),
			"true dry concrete restores after storm at UV %.2f" % uv)
	# Confirm standard/cinematic original visuals are never allowed to
	# silently change road weather coefficients in the ACTUAL native game.
	var game: Node = root.get_node_or_null("GameState")
	check(game != null, "true GameState autoload available")
	if game == null:
		quit(1)
		return
	var original_state: Dictionary = (game.get("data") as Dictionary).duplicate(true)
	var world_source: Variant = load("res://scripts/world_builder.gd")
	check(world_source is Script and world_source.can_instantiate(),
		"WorldBuilder compiles after real autoload initialization")
	if not (world_source is Script and world_source.can_instantiate()):
		quit(1)
		return
	var world: Node3D = world_source.new()
	root.add_child(world)
	var source: StandardMaterial3D = world.get("asphalt_pbr") as StandardMaterial3D
	check(source != null and source.resource_name == "HORIZON_ROAD_ASPHALT",
		"original playable city's weather applies to actual asphalt identity")
	if source != null:
		for tier in ["low","standard","cinematic","standard","low"]:
			world.call("apply_visual_budget",tier)
			world.call("update_weather","rain")
			check(is_equal_approx(source.roughness,0.36),
				"native road rain at tier " + tier)
			world.call("update_weather","clear")
			check(is_equal_approx(source.roughness,0.81),
				"native original dry road restore at tier " + tier)
	check(game.get("data") == original_state,
		"native graphics/weather regression does not alter player funds or saved mission state")
	world.queue_free()
	await process_frame
	print("EMPIRE OMEGA R111 original photo rain/grip identity: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed == 0 else 1)
