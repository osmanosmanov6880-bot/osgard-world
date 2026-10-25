extends SceneTree
## EMPIRE OMEGA R47: 200 seeded prediction cases PLUS one real 240-frame Godot traffic collision scene.
const PREDICT = preload("res://scripts/horizon_pedestrian_yield.gd")
const SAFETY = preload("res://scripts/traffic_safety.gd")
const TRAFFIC = preload("res://scripts/traffic_agent.gd")
const WALKER = preload("res://scripts/pedestrian_agent.gd")
const SEEDS: Array[int] = [7,23,61,109,211]
const PER_SEED: int = 40
const PHYSICS_FRAMES: int = 240
var passed: int = 0
var failed: int = 0

func check(ok: bool, reason: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R47 CITY SAFETY FAILED: "+reason)

func _initialize() -> void:
	call_deferred("_run")

func _scenario(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cases: Array[Dictionary] = []
	var false_alerts: int = 0
	var missed_conflicts: int = 0
	for index in range(PER_SEED):
		var kind: int = index % 4
		var dist: float = rng.randf_range(5.0,11.0)
		var car_speed: float = rng.randf_range(8.0,13.0)
		var walker := Vector3.ZERO
		var walking := Vector3.ZERO
		var car := Vector3(-dist,0,0)
		var velocity := Vector3(car_speed,0,0)
		var expected := true
		if kind == 1:
			car = Vector3(dist,0,0)
			expected = false
		elif kind == 2:
			car.z = rng.randf_range(4.8,7.8)
			expected = false
		elif kind == 3:
			walker.z = -1.5
			walking.z = 1.6
		var actual: bool = PREDICT.should_yield(walker,walking,car,velocity)
		var t: float = PREDICT.closest_approach_seconds(walker,walking,car,velocity)
		if actual and not expected: false_alerts += 1
		if expected and not actual: missed_conflicts += 1
		check(actual==expected,"seed %d crossing case %d trajectory" % [seed_value,index])
		check(is_finite(t) and t>=0.0 and t<=PREDICT.LOOK_AHEAD_SECONDS,
			"seed %d case %d closest-approach time" % [seed_value,index])
		var clearance: float = rng.randf_range(4.0,29.0)
		var dry: float = SAFETY.safe_speed(clearance,14.0,1.0)
		var wet: float = SAFETY.safe_speed(clearance,14.0,0.6)
		check(is_finite(dry) and is_finite(wet) and wet>=0 and wet<=dry+0.00001,
			"seed %d case %d wet braking never gets safer falsely" % [seed_value,index])
		cases.append({
			"kind":["incoming","retreating","adjacent","walking_crossing"][kind],
			"expected":expected,"actual":actual,
			"closest_s":snappedf(t,0.0001),
			"speed_mps":snappedf(car_speed,0.0001),
			"clearance_m":snappedf(clearance,0.0001),
			"dry_safe_mps":snappedf(dry,0.0001),
			"wet_safe_mps":snappedf(wet,0.0001)
		})
	return {"seed":seed_value,"cases":cases,"false_alerts":false_alerts,"missed_conflicts":missed_conflicts}

func _real_blocked_lane() -> Dictionary:
	var scene := Node3D.new()
	scene.name = "R47ActualTraffic"
	root.add_child(scene)
	var traffic: CharacterBody3D = TRAFFIC.new()
	scene.add_child(traffic)
	traffic.set_route([Vector3(0,0.8,0),Vector3(0,0.8,-95)],12.0)
	traffic.wetness = 0.65
	var wall := StaticBody3D.new()
	wall.collision_layer = 4
	wall.collision_mask = 8
	wall.position = Vector3(0,1.2,-27)
	var volume := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4,2,2)
	volume.shape = shape
	wall.add_child(volume)
	scene.add_child(wall)
	var nonfinite_frames := 0
	var slide_frames := 0
	for frame in range(PHYSICS_FRAMES):
		await physics_frame
		if not traffic.global_position.is_finite() or not is_finite(traffic.speed):
			nonfinite_frames += 1
		if traffic.get_slide_collision_count()>0:
			slide_frames += 1
	check(traffic is CharacterBody3D and (traffic.collision_mask & 4)!=0,
		"actual traffic uses Godot collision against cars")
	check(traffic.travelled_metres>3.0,"real traffic moves on city path")
	check(traffic.global_position.z>-27.0,"actual barricade stops traffic tunneling")
	check(traffic.speed<1.5 and traffic.stopped_seconds>0.5,"traffic brakes and settles before hazard")
	check(nonfinite_frames==0,"real 240 physics frames remain finite")
	var citizen: Node3D = WALKER.new()
	citizen.citizen_id=4
	scene.add_child(citizen)
	citizen.global_position=traffic.global_position+Vector3(0,0,-2)
	citizen.traffic_vehicles=[traffic]
	check(not bool(citizen.call("_yield_to_vehicle",Vector3.ZERO)),
		"stationary car does not indefinitely trap living pedestrian")
	traffic.speed=7.0
	check(bool(citizen.call("_yield_to_vehicle",Vector3.ZERO)),
		"moving nearby car activates actual pedestrian yield")
	var main: Variant = load("res://scripts/main.gd")
	check(main is Script and main.can_instantiate(),"game scene still compiles with safety agents")
	var result := {
		"real_physics_frames":PHYSICS_FRAMES,
		"collision_shape":volume.shape is BoxShape3D,
		"travelled_m":traffic.travelled_metres,
		"final_z_m":traffic.global_position.z,
		"final_speed_mps":traffic.speed,
		"stopped_seconds":traffic.stopped_seconds,
		"nonfinite_frames":nonfinite_frames,
		"slide_frames":slide_frames,
		"collision_layer":traffic.collision_layer
	}
	scene.queue_free()
	await process_frame
	return result

func _run() -> void:
	var groups: Array[Dictionary] = []
	var case_count: int = 0
	for seed_value in SEEDS:
		var group: Dictionary = _scenario(seed_value)
		groups.append(group)
		case_count += group["cases"].size()
		check(int(group["false_alerts"])==0 and int(group["missed_conflicts"])==0,
			"seed %d has no mistaken geometric yield in controlled cases" % seed_value)
	check(case_count==200,"two hundred genuine Godot prediction cases")
	check(PREDICT.should_yield(Vector3(NAN,0,0),Vector3.ZERO,Vector3.ZERO,Vector3.ZERO),
		"invalid physical state cannot cause unsafe crossing")
	check(not PREDICT.should_yield(Vector3.ZERO,Vector3.ZERO,Vector3(81,0,0),Vector3(-18,0,0)),
		"80m bounded awareness retains NPC frame budget")
	check(SAFETY.desired_speed(14.0,1000000.0,3.0)==0.0,"red signal commands stop")
	var real: Dictionary = await _real_blocked_lane()
	check(real["collision_shape"],"genuine collider in physical traffic scene")
	var result: Dictionary = {
		"engine":"Godot 4.4.1",
		"protocol":"200 seeded analytic trajectory predictions plus one real traffic physics trial",
		"predictive_cases":case_count,
		"real_collision_scenarios":1,
		"seeds":SEEDS,
		"groups":groups,
		"physical_trial":real,
		"full_crowd_simulation":false,
		"device_fps_measured":false,
		"production_agent_changes":false,
		"passed":passed,"failed":failed
	}
	var output: String = ProjectSettings.globalize_path("res://tests/r47-city-safety.json")
	var file: FileAccess = FileAccess.open(output,FileAccess.WRITE)
	check(file!=null,"actual Godot test writes full data report")
	if file!=null:
		result["passed"]=passed
		result["failed"]=failed
		file.store_string(JSON.stringify(result,"  "))
		file.close()
	print("EMPIRE OMEGA R47: %d passed, %d failed; 200 predicted cases and %d real traffic physics frames" %
		[passed,failed,PHYSICS_FRAMES])
	quit(0 if failed==0 else 1)
