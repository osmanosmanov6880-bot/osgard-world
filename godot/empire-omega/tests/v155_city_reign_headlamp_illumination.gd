extends SceneTree
## R168 real original four-wheel player-car dual-lens source optical response.
const CAR = preload("res://scripts/vehicle_controller.gd")
const OPTICS = preload("res://scripts/city_reign_atmospheric_optics.gd")
const ART = preload("res://scripts/horizon_vehicle_art.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool,reason: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error("CITY REIGN R168 LENS FAIL: "+reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var car: CharacterBody3D = CAR.new()
	root.add_child(car)
	var art: Node3D = car.get("horizon_visual") as Node3D
	var left: MeshInstance3D = art.get_node("LeftLED") as MeshInstance3D
	var right: MeshInstance3D = art.get_node("RightLED") as MeshInstance3D
	var original_mesh: Mesh = left.mesh
	var children: int = art.get_child_count()
	check(left.mesh==right.mesh and left.mesh.surface_get_array_len(0)==108,
		"unchanged R167 physical triple-band optics reused by exact original driveable car")
	car.update_headlights(12.0,"standard")
	var left_finish: StandardMaterial3D = left.material_override as StandardMaterial3D
	var right_finish: StandardMaterial3D = right.material_override as StandardMaterial3D
	var daytime: float = left_finish.emission_energy_multiplier
	car.update_headlights(22.0,"cinematic")
	var nighttime: float = left_finish.emission_energy_multiplier
	check(nighttime>daytime*2.0 and is_equal_approx(nighttime,right_finish.emission_energy_multiplier),
		"native source lens becomes brighter after physical clock-driven night")
	check(car.get("headlight_cones").size()==2 and car.get("headlight_cones")[0].visible,
		"original TWO bounded dynamic road spotlights remain nighttime authority")
	car.update_headlights(22.0,"low")
	check(not car.get("headlight_cones")[0].visible and
		is_equal_approx(left_finish.emission_energy_multiplier,OPTICS.headlamp_energy(22.0,"low")),
		"mobile LOW retains readable emissive lenses with ZERO dynamic light cones")
	for i in range(80):
		car.update_headlights(12.0 if i%2==0 else 22.0,
			"standard" if i%2==0 else "cinematic")
	check(art.get_child_count()==children and left.mesh==original_mesh and right.mesh==original_mesh,
		"80 day/night quality switches do not allocate new meshes/nodes")
	var collisions: int = 0
	for piece in car.get_children():
		if piece is CollisionShape3D: collisions += 1
	check(collisions==1 and car.get("horizon_visual") is Node3D,
		"unchanged real car collision and actual moving vehicle art")
	check(OPTICS.headlamp_energy(NAN,"standard")>0.0 and
		OPTICS.headlamp_energy(22.0,"cinematic") <= 2.25,
		"invalid hours and mobile lenses have bounded light energy")
	car.queue_free()
	await process_frame
	print("CITY REIGN R168 REAL LENS: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
