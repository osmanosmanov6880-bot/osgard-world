extends SceneTree
## CITY REIGN B67: original physical citizens must not stop one frame
## per duplicated A* waypoint. Tests actual source pedestrian movement,
## speed bounds, correctly reached endpoint, zero financial side effects.
const WALKER = preload("res://scripts/pedestrian_agent.gd")
const MESH = preload("res://scripts/horizon_street_citizen_mesh.gd")
var passed: int = 0
var failed: int = 0

func check(value: bool, label: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error("CITY REIGN B67 WAYPOINT PROGRESSION FAILED: "+label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim: Node = root.get_node_or_null("GameState")
	check(sim!=null,"native source GameState autoload installed")
	if sim==null:
		quit(2)
		return
	var state: Dictionary = (sim.get("data") as Dictionary).duplicate(true)
	var person: Node3D = WALKER.new()
	person.set("citizen_id",3)
	root.add_child(person)
	var original: Vector3 = Vector3(104,0.7,-104)
	person.global_position = original
	var path: Array[Vector3] = [
		original,original,original,original+Vector3(24,0,0)
	]
	person.set("route",path)
	person.set("next_waypoint",1)
	person.call("_process",0.030)
	var moved: Vector3 = person.global_position-original
	check(moved.length()>0.05 and moved.length()<0.072,
		"original source walker MOVES in one tick despite two duplicate start nodes")
	check(int(person.get("next_waypoint"))==3 and (
		person.get("planned_velocity") as Vector3).length()>2.0,
		"real A* walker skips only reached repeated nodes, not the distant goal")
	check((person.get("body_mesh") as MeshInstance3D).mesh!=null,
		"one original articulated pedestrian body remains active, not a fake pose")
	check(person.get_child_count()==1 and
		(person.get("body_mesh") as MeshInstance3D).material_override==MESH.shared_material(),
		"existing single-mesh original citizen renderer and PBR still authoritative")
	var at: Vector3 = person.global_position
	path = [at,at]
	person.set("route",path)
	person.set("next_waypoint",1)
	person.call("_process",0.030)
	check(person.global_position==at and
		int(person.get("next_waypoint"))==2 and
		(person.get("planned_velocity") as Vector3)==Vector3.ZERO,
		"terminal duplicate route never moves or overreads beyond last waypoint")
	check((person.get("body_mesh") as MeshInstance3D).mesh==
		MESH.mesh_for(3,0),
		"idle source citizen returns to physically modeled resting pose")
	path=[at,at+Vector3(5.0,0,0)]
	person.set("route",path)
	person.set("next_waypoint",1)
	person.call("_process",0.030)
	check(person.global_position.x>at.x and
		int(person.get("next_waypoint"))==1,
		"real source citizen still follows a genuinely distant goal")
	# Rendering/movement and re-planning never create city credits or
	# mutate the original GameState, including saved construction progress.
	check(sim.get("data")==state,
		"native pedestrian bug fix cannot change money/mission/city trust")
	person.queue_free()
	await process_frame
	print("CITY REIGN B67 REAL ORIGINAL A-STAR PEDESTRIAN CONTINUITY: %d PASS %d FAIL" %
		[passed,failed])
	quit(0 if failed==0 else 1)
