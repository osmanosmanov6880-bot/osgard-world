extends SceneTree
## Native Godot 4.4.1 acceptance for original Horizon scenery and PBR coupe.
const CAR = preload("res://scripts/vehicle_controller.gd")
const SCENIC = preload("res://scripts/horizon_roadscape.gd")
var ok_count := 0
var error_count := 0

func check(value: bool, reason: String) -> void:
	if value:
		ok_count += 1
	else:
		error_count += 1
		push_error("HORIZON VISUAL FAILED: "+reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var car: CharacterBody3D = CAR.new()
	root.add_child(car)
	var art: Node3D = car.get_node_or_null("HorizonCoupe") as Node3D
	check(art != null,"coupe mesh is attached to real game vehicle")
	if art != null:
		var wheels: Array = art.get("wheel_rigs")
		var panels: Array = art.get("painted_parts")
		check(wheels.size()==4,"sports car has four independently animated wheel pivots")
		check(panels.size()>=6,"PBR paint touches at least six sculpted body panels")
		check(art.get_node_or_null("SlopedWindshield") != null,"actual sloped windshield geometry exists")
		check(art.get_node_or_null("RearSpoiler") != null,"aerodynamic rear spoiler exists")
		check(art.get_node_or_null("FullWidthRearLight") != null,"brake light strip exists")
		art.call("roll_wheels",2.8,0.45)
		art.call("set_brake_lights",true)
		art.call("set_paint",Color("67aab3"))
		check(car.brake_lamp_nodes.size()==2,"existing game brake light contract survives")
		car.apply_variant("compact")
		check(car.get("variant_id")=="compact","existing garage vehicle selection survives")
	var environment: Node3D = SCENIC.new()
	root.add_child(environment)
	check(int(environment.get("tree_count"))>=180,"native environment contains instanced greenery")
	check(int(environment.get("marking_count"))>=800,"real intersection stripes are rendered")
	check(int(environment.get("scenic_batches"))>=6,"visual objects are batched for browser rendering")
	var zebra := environment.get_node_or_null("CrosswalkBatch") as MultiMeshInstance3D
	check(zebra != null and zebra.multimesh.instance_count>800,"real GPU-instanced lane markings")
	check(environment.get_node_or_null("SurroundingMountainRange") != null,"scenic distant mountain skyline")
	check(environment.get_node_or_null("FestivalRoof") != null,"festival entrance geometry")
	print("HORIZON NATIVE VISUAL: %d checks passed, %d failed" % [ok_count,error_count])
	environment.queue_free()
	car.queue_free()
	quit(0 if error_count==0 else 1)
