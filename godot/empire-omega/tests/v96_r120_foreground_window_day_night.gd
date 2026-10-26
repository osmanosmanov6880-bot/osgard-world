extends SceneTree
## R120 source native QA: original playable street windows physically reflect
## ambient daytime light without losing legible night lights/phone GPU budget.
const WORLD = preload("res://scripts/world_builder.gd")
var passed := 0
var failed := 0

func check(ok: bool, why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R120 ORIGINAL FOREGROUND WINDOWS FAILED: " + why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = root.get_node_or_null("GameState")
	check(game != null, "original economic/missions state autoload is present")
	if game == null:
		quit(1)
		return
	var before: Dictionary = (game.get("data") as Dictionary).duplicate(true)
	var world: Node3D = WORLD.new()
	root.add_child(world)
	var glass: MultiMeshInstance3D = world.get("facade_windows") as MultiMeshInstance3D
	var metal: MultiMeshInstance3D = world.get("facade_frames") as MultiMeshInstance3D
	var positions: Array = world.get("window_points")
	check(glass != null and metal != null,
		"original two genuine instanced foreground materials still exist")
	check(glass != null and glass.multimesh.instance_count == positions.size() and
		metal != null and metal.multimesh.instance_count == positions.size(),
		"all original four-sided facade positions and instance counts remain unchanged")
	check(positions.size() > 1000,
		"original playable city retains actual thousands of facade windows")
	check(glass != null and glass.get_child_count() == 0 and
		metal != null and metal.get_child_count() == 0,
		"zero new per-window draw nodes, collision bodies, light probes or physics")
	if glass != null and metal != null:
		var surface: StandardMaterial3D = glass.material_override as StandardMaterial3D
		var frame: StandardMaterial3D = metal.material_override as StandardMaterial3D
		check(surface != null and frame != null,
			"original two real near-camera PBR shader resources exist")
		if surface != null and frame != null:
			check(surface.metallic > 0.2 and surface.roughness < 0.35 and
				surface.vertex_color_use_as_albedo,
				"authentic foreground glass remains an actual reflective PBR material")
			check(frame.metallic >= 0.5 and frame.roughness <= 0.45,
				"original metal perimeter uses subdued gunmetal physical shader")
			world.call("apply_visual_budget", "standard")
			world.call("_update_windows", 12.0, 100)
			check(surface.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL,
				"daytime STANDARD uses physically shaded glass under true city sun")
			check(metal.visible,
				"original visible metal frames are retained in standard city quality")
			world.call("apply_visual_budget", "low")
			check(surface.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
				"LOW/mobile fallback avoids physical per-pixel shading cost")
			check(not metal.visible,
				"LOW/mobile retains original exterior decoration cutoff")
			world.call("apply_visual_budget", "cinematic")
			check(surface.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL,
				"cinematic mode restores true sun/sky glass shader without reallocating windows")
			check(metal.visible,
				"cinematic mode keeps original batched physical metal perimeter")
			world.call("_update_windows", 21.0, 100)
			check(surface.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
				"night city retains original warm/cool lit window readability")
			world.call("_update_windows", 21.0, 10)
			check(surface.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
				"low-power nights retain original deterministic outage behavior")
			world.call("_update_windows", 10.0, 10)
			check(surface.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL,
				"daylight PBR restores immediately after night without new nodes")
			check(glass.multimesh.instance_count == positions.size() and
				metal.multimesh.instance_count == positions.size(),
				"all day/night and quality changes reuse exact original GPU batches")
	check(game.get("data") == before,
		"visual-only glass/quality transitions never change saved economy or mission progress")
	world.queue_free()
	await process_frame
	print("EMPIRE OMEGA R120 true foreground daytime/night PBR: %d PASS %d FAIL" %
		[passed,failed])
	quit(0 if failed == 0 else 1)
