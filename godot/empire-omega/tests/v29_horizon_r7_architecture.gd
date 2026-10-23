extends SceneTree
## R7 native material/geometry regression; no GameState dependency under --script.
const ARCH = preload("res://scripts/horizon_architecture_r7.gd")
const PHOTO = preload("res://scripts/horizon_photoreal_r6.gd")
var tests: int = 0
var failures: int = 0

func check(condition: bool, title: String) -> void:
	tests += 1
	if condition:
		print("R7 ARCH PASS: " + title)
	else:
		failures += 1
		push_error("R7 ARCH FAIL: " + title)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var city := Node3D.new()
	city.set_script(preload("res://tests/horizon_r7_city_contract.gd"))
	root.add_child(city)
	var photo := PHOTO.new()
	root.add_child(photo)
	for name in ["facade","sidewalk"]:
		var slug: String = "painted_plaster_wall" if name=="facade" else "concrete_floor_02"
		var material: StandardMaterial3D = photo._surface(slug,2.0,.37)
		if material != null:
			photo.bundles[name] = material
	var layer := ARCH.new()
	city.add_child(layer)
	layer.bind_world(city,photo)
	var info: Dictionary = layer.diagnostic()
	check(int(info["facade_buildings"])==12,"build 12 real collision-free facade structures")
	check(int(info["mapped_original_windows"])>=240,"map original window geometry without inventing positions")
	check(int(info["gpu_batches"])>=24,"quarter-based PBR architecture batches")
	check(int(info["instanced_meshes"])>=1400,"thousands of authored facade elements uploaded")
	check(int(info["physical_balconies"])>=10,"structurally visible balcony geometry")
	check(city.facade_windows != null,"existing windows remain as fallback")
	layer.set_profile("low")
	var restored: bool = true
	for mesh in layer.replacements:
		if mesh.material_override != layer.replacements[mesh]:
			restored = false
	check(restored,"low quality restores original world materials")
	layer.set_profile("cinematic")
	check(str(layer.profile)=="cinematic","cinematic road and architectural tier activates")
	if OS.get_environment("OSGARD_R6_REQUIRE_PHOTO")=="1":
		check(bool(layer.diagnostic()["authentic_scanned_wall"]),"strict build uses downloaded real CC0 facade scans")
	layer.set_profile("standard")
	check(str(layer.profile)=="standard","standard retains non-premium facade detail")
	city.queue_free()
	photo.queue_free()
	await process_frame
	print("R7 ARCHITECTURE GODOT: %d/%d" % [tests-failures,tests])
	quit(0 if failures==0 else 1)
