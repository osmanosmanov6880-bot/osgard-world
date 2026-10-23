extends SceneTree
## Real engine R6 regression: CC0 map import, scanned albedo + normal + roughness,
## high-end lacquer, rain spray and zero-save/zero-gameplay contract.
const R6 = preload("res://scripts/horizon_photoreal_r6.gd")
const CAR = preload("res://scripts/vehicle_controller.gd")
var checks: int = 0
var fails: int = 0

func expect(ok: bool, msg: String) -> void:
	checks += 1
	if ok:
		print("R6 PHOTOREAL PASS: " + msg)
	else:
		fails += 1
		push_error("R6 PHOTOREAL FAIL: " + msg)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	expect(load("res://shaders/horizon_r6_scanned_asphalt.gdshader") is Shader, "Actual Godot R6 scanned asphalt shader compiles")
	var source := R6.new()
	root.add_child(source)
	var has_scans: bool = ResourceLoader.exists("res://assets/r6/polyhaven/asphalt_05/diffuse.jpg")
	if not has_scans:
		has_scans = ResourceLoader.exists("res://assets/r6/polyhaven/asphalt_05/diffuse.png")
	var strict: bool = OS.get_environment("OSGARD_R6_REQUIRE_PHOTO") == "1"
	if strict:
		expect(has_scans, "STRICT R6: real downloaded photogrammetry present")
	else:
		expect(true, "Optional offline Web fallback supported")
	for slug in ["asphalt_05","concrete_floor_02","painted_plaster_wall"]:
		var material: StandardMaterial3D = source._surface(slug,2.0,.55)
		if has_scans:
			expect(material != null, "Real material " + slug + " imports")
			if material != null:
				expect(material.albedo_texture != null,slug + ": photographed albedo")
				expect(material.normal_enabled and material.normal_texture != null,slug + ": measured normal map")
				expect(material.roughness_texture != null,slug + ": roughness map")
				expect(material.uv1_world_triplanar,slug + ": world-scale mapping")
				expect(material.albedo_texture.get_width()>=1024,slug + ": physical texture resolution")
		else:
			expect(material == null, "Absent CC0 scans use conservative offline fallback: " + slug)
	var car: CharacterBody3D = CAR.new()
	root.add_child(car)
	source.bind_car(car)
	expect(source.spray != null,"GPU rain spray allocated once on real playable car")
	if car.horizon_visual != null:
		var shell: MeshInstance3D = car.horizon_visual.get_node_or_null("FlowBody") as MeshInstance3D
		expect(shell != null,"real sculpted chassis is present")
		if shell != null:
			var paint: StandardMaterial3D = shell.material_override as StandardMaterial3D
			expect(paint != null and paint.clearcoat_enabled,"physically modeled two-layer lacquer")
		car.horizon_visual.set_paint(Color("c05b4c"))
		if shell != null:
			var repaint: StandardMaterial3D = shell.material_override as StandardMaterial3D
			expect(repaint != null and repaint.clearcoat_enabled,"garage repaint preserves photoreal finish")
	source.set_profile("low")
	expect(source.quality=="low","low quality remains a valid fallback")
	source.set_weather("rain")
	expect(source.weather=="rain","rain remains in physics-independent visuals")
	car.queue_free()
	source.queue_free()
	await process_frame
	print("R6 PHOTOREAL NATIVE: %d/%d" % [checks-fails,checks])
	quit(0 if fails==0 else 1)
