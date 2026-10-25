extends SceneTree
## R98 native geometry / physics invariants: never a flat image facade.
const FINS = preload("res://scripts/horizon_r98_architectural_fins.gd")
var passed := 0
var failed := 0

func check(ok: bool,why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R98 ORIGINAL FACADES FAIL: " + why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fins: MultiMeshInstance3D = FINS.new()
	fins.call("record",Vector3(0.0,15.0,0.0),13.0,30.0,"forum")
	fins.call("record",Vector3(20.0,22.0,22.0),12.0,44.0,"housing")
	# Must reject invalid, out-of-budget or suspicious geometry.
	fins.call("record",Vector3(NAN,0.0,0.0),13.0,30.0,"forum")
	fins.call("record",Vector3(0.0,7.0,0.0),13.0,14.0,"unknown")
	fins.call("record",Vector3.ZERO,45.0,30.0,"forum")
	fins.call("finalize")
	root.add_child(fins)
	check(fins.multimesh != null and fins.multimesh.instance_count == 16,
		"two authentic buildings produce exactly 16 instanced 3D fins")
	check(bool(fins.call("graphics_are_bounded")),"finite draw/triangle budget")
	check(fins.get_child_count() == 0,
		"no physics, script lights, camera nodes or colliders added")
	check(fins.material_override is StandardMaterial3D,
		"true lit PBR surfaces rather than unshaded CSS/billboards")
	if fins.material_override is StandardMaterial3D:
		var paint: StandardMaterial3D = fins.material_override
		check(paint.metallic >= 0.2 and paint.roughness >= 0.35 and paint.roughness <= 0.7,
			"controlled physical metal and roughness response")
	var body: MultiMesh = fins.multimesh
	# --headless uses Godot's dummy renderer. Its RenderingServer API can
	# return identity for Multimesh.get_instance_transform() even when a
	# valid authored transform is present and set_instance_transform() ran.
	# Source geometry is the authoritative CPU artifact for native tests;
	# actual GPU raster output must still be validated in WebGL Chromium.
	var authored: Array = fins.get("placements")
	var span: float = 0.0
	check(body != null and authored.size() == body.instance_count,
		"GPU instance count exactly matches original authored fin transforms")
	if body != null and body.instance_count == 16 and authored.size() == 16:
		for i in range(body.instance_count):
			var mesh_position: Transform3D = authored[i]
			check(mesh_position.origin.is_finite(),
				"each authored 3D beam has finite world coordinates: %d" % i)
			span = maxf(span,mesh_position.basis.y.length())
	print("R98 authored CPU world-space vertical span: %.5f" % span)
	check(span >= 26.0,"authored true multi-floor 3D mullion geometry, not screen-space texture")
	fins.call("set_quality","low")
	check(not fins.visible,"mobile low tier hides optional city detail")
	fins.call("set_quality","cinematic")
	check(fins.visible,"cinematic tier shows actual native geometry")
	fins.queue_free()
	var at_cap: MultiMeshInstance3D = FINS.new()
	for i in range(FINS.MAX_BUILDINGS):
		at_cap.call("record",Vector3(float(i%16)*13.0,15.0,float(i/16)*13.0),
			13.0,30.0,"aqueduct")
	at_cap.call("record",Vector3.ZERO,13.0,30.0,"aqueduct")
	at_cap.call("finalize")
	root.add_child(at_cap)
	check(at_cap.multimesh.instance_count == FINS.MAX_INSTANCES,
		"hard GPU instancing limit remains fixed at 1024")
	check(bool(at_cap.call("graphics_are_bounded")),
		"full budget includes all instance and triangle invariants")
	at_cap.queue_free()
	var original: String = FileAccess.get_file_as_string("res://scripts/world_builder.gd")
	check(original.contains("r98_facade_ribs.call(\"record\",pos,width,height,id)"),
		"world records fins at original real building coordinates")
	check(original.contains("r98_facade_ribs.call(\"finalize\")"),
		"same native city scene owns one finished GPU batch")
	check(original.contains("R95_MASSING.height_for(id,rng.randf(),ix,iz,n)"),
		"R95 authoritative skyline height and RNG consumption remain unchanged")
	check(original.contains("_box(chunk,\"Building_%03d\""),
		"the original collision shapes and physical building footprints remain")
	check(original.contains("r98_facade_ribs.call(\"set_quality\",visual_budget)"),
		"GPU detail respects real player visual-quality settings")
	await process_frame
	print("EMPIRE Omega R98 original PBR facade fins: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed == 0 else 1)
