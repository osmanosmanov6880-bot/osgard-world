extends SceneTree
## Genuine Godot R41 pedestrian proximity and trajectory regression.
const RULE = preload("res://scripts/horizon_pedestrian_yield.gd")
const WALKER = preload("res://scripts/pedestrian_agent.gd")
const TRAFFIC = preload("res://scripts/traffic_agent.gd")
var passed := 0
var failed := 0
func check(ok: bool,label: String) -> void:
	if ok:
		passed+=1
	else:
		failed+=1
		push_error("EMPIRE R41 PEDESTRIAN SAFETY FAILED: "+label)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var on_road := Vector3.ZERO
	check(RULE.should_yield(on_road,Vector3.ZERO,Vector3(-16,0,0),Vector3(9,0,0)),
		"approaching car predicted across walker in under 2.4s")
	check(not RULE.should_yield(on_road,Vector3.ZERO,Vector3(16,0,0),Vector3(9,0,0)),
		"departing car does not stop sidewalk traffic")
	check(not RULE.should_yield(on_road,Vector3.ZERO,Vector3(-16,0,4.2),Vector3(9,0,0)),
		"cars travelling through adjacent lane never freeze walker")
	check(not RULE.should_yield(on_road,Vector3.ZERO,Vector3(-80.1,0,0),Vector3(30,0,0)),
		"bounded awareness rejects remote objects")
	check(RULE.should_yield(on_road,Vector3.ZERO,Vector3(0,0,1.1),Vector3.ZERO),
		"direct overlap remains protected even if velocity is zero")
	check(RULE.should_yield(on_road,Vector3(0,0,-2),Vector3(-8,0,0),Vector3(8,0,0)),
		"moving walker crossing into passing vehicle triggers prediction")
	check(not RULE.should_yield(on_road,Vector3(0,0,2),Vector3(-12,0,9),Vector3(6,0,0)),
		"separate pedestrian/car paths do not trigger global radius halt")
	check(RULE.should_yield(Vector3(NAN,0,0),Vector3.ZERO,Vector3.ZERO,Vector3.ZERO),
		"non-finite transform cannot authorize unsafe motion")
	check(is_equal_approx(RULE.closest_approach_seconds(on_road,Vector3.ZERO,Vector3(-12,0,0),Vector3(6,0,0)),2.0),
		"relative position and measured velocity yield real impact horizon")
	check(RULE.closest_approach_seconds(on_road,Vector3.ZERO,Vector3(12,0,0),Vector3(6,0,0))==0.0,
		"retreating vehicle has zero future closest approach")
	var legacy: Variant = load("res://tests/v14_traffic_physics.gd")
	check(legacy is Script and legacy.can_instantiate(),
		"legacy traffic physics acceptance parses with R41 default call")
	var citizen: Node3D = WALKER.new()
	root.add_child(citizen)
	var car: CharacterBody3D = TRAFFIC.new()
	root.add_child(car)
	citizen.global_position=on_road
	car.global_position=Vector3(-15,0,0)
	car.set("speed",9.0)
	car.velocity=Vector3(9,0,0)
	citizen.set("traffic_vehicles",[car])
	check(bool(citizen.call("_yield_to_vehicle",Vector3.ZERO)),
		"real citizen agent uses predictive approach on moving traffic")
	car.global_position=Vector3(-15,0,4.2)
	check(not bool(citizen.call("_yield_to_vehicle",Vector3.ZERO)),
		"real agent allows vehicle on neighbouring lane")
	car.global_position=Vector3(-15,0,0)
	car.set("speed",0.0)
	check(not bool(citizen.call("_yield_to_vehicle",Vector3.ZERO)),
		"stopped vehicle does not deadlock crossing forever")
	car.set("speed",9.0)
	car.visible=false
	check(not bool(citizen.call("_yield_to_vehicle",Vector3.ZERO)),
		"culled invisible cars never immobilize active pedestrians")
	citizen.queue_free()
	car.queue_free()
	var live: Variant = load("res://scripts/main.gd")
	check(live is Script and live.can_instantiate(),"real game scene loads with R41 safety module")
	var pedestrian_source: String = FileAccess.get_file_as_string("res://scripts/pedestrian_agent.gd")
	check(pedestrian_source.contains("TRAJECTORY.should_yield("),
		"real active pedestrian logic calls relative-trajectory rule")
	check(pedestrian_source.contains("if _yield_to_vehicle(velocity):"),
		"pedestrian movement uses actual world-route velocity")
	print("EMPIRE OMEGA R41 NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
