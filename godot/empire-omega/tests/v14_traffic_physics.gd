extends SceneTree
## Native acceptance: physically colliding ambient traffic, red-light model,
## weather grip, safe speed, and pedestrian interaction.
const SAFETY = preload("res://scripts/traffic_safety.gd")
const TRAFFIC = preload("res://scripts/traffic_agent.gd")
const PEDESTRIAN = preload("res://scripts/pedestrian_agent.gd")
var checked := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failed += 1
		push_error("TRAFFIC FAIL: "+description)
	else:
		print("TRAFFIC PASS: "+description)

func _run() -> void:
	check(SAFETY.safe_speed(3.0,12.0) == 0.0,"stop before safety gap")
	check(SAFETY.safe_speed(15.0,12.0,0.5) <= SAFETY.safe_speed(15.0,12.0,1.0),"rain lengthens stopping distance")
	check(SAFETY.desired_speed(12.0,1000000.0,2.0) == 0.0,"red light blocks travel")
	check(SAFETY.corner_speed(Vector3.RIGHT,Vector3.FORWARD,2.0,14.0)<14.0,"reduce speed for turns")
	check(SAFETY.approach_speed(12.0,0.0,0.1)<11.0,"emergency braking")
	var road := Node3D.new()
	road.name = "TrafficAcceptanceWorld"
	root.add_child(road)
	var traffic = TRAFFIC.new()
	road.add_child(traffic)
	traffic.set_route([Vector3(0,0.8,0),Vector3(0,0.8,-95)],12.0)
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 4
	blocker.collision_mask = 8
	blocker.position = Vector3(0,1.2,-27)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.0,2.0,2.0)
	collider.shape = shape
	blocker.add_child(collider)
	road.add_child(blocker)
	check(traffic is CharacterBody3D,"ambient car has physical collider")
	check((traffic.collision_mask & 4)!=0,"ambient car sees player's collision layer")
	check((traffic.collision_layer & 8)!=0,"player can collide with ambient car")
	check(traffic.wheels.size()==4,"four visible wheels")
	check(traffic.brake_meshes.size()==2,"both brake lights built")
	for frame in range(240):
		await physics_frame
	check(traffic.travelled_metres>3.0,"vehicle moved on route")
	check(traffic.global_position.z>-27.0,"vehicle did not pass through blocked lane")
	print("TRAFFIC DIAGNOSTICS: speed=%.3f stopped=%.3f z=%.3f distance=%.3f" % [traffic.speed,traffic.stopped_seconds,traffic.global_position.z,traffic.travelled_metres])
	check(traffic.speed<1.5,"vehicle braked to a stop")
	check(traffic.stopped_seconds>0.5,"vehicle remained stopped")
	var citizen = PEDESTRIAN.new()
	citizen.citizen_id = 4
	road.add_child(citizen)
	citizen.global_position = traffic.global_position+Vector3(0,0,-2)
	citizen.traffic_vehicles = [traffic]
	check(citizen._yield_to_vehicle()==false,"stopped traffic does not permanently freeze citizen")
	traffic.speed = 7.0
	check(citizen._yield_to_vehicle(),"citizen yields to nearby moving traffic")
	road.queue_free()
	print("Native traffic acceptance: %d checks, %d failures" % [checked,failed])
	quit(0 if failed == 0 else 1)
