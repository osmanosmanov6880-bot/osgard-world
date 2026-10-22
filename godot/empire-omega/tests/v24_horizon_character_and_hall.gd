extends SceneTree
const PERSON = preload("res://scripts/player_controller.gd")
const WORLD = preload("res://scripts/world_builder.gd")
var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("HORIZON DETAIL FAILED: "+label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var citizen: CharacterBody3D = PERSON.new()
	root.add_child(citizen)
	var visual := citizen.get_node_or_null("HorizonCitizen")
	check(visual != null,"human silhouette is attached to actual player controller")
	if visual != null:
		check(visual.get_node_or_null("Head") != null,"character has a modeled head")
		check(visual.get_node_or_null("LeftLeg") != null,"left leg animation rig")
		check(visual.get_node_or_null("RightLeg") != null,"right leg animation rig")
		check(int(visual.get("detail_nodes"))>=16,"premium clothing silhouette has distinct parts")
		visual.call("animate_walk",7.0,0.2)
		check(visual.get_node("LeftLeg").rotation.x != 0.0,"walk animation responds to velocity")
	var city: Node3D = WORLD.new()
	root.add_child(city)
	var civic: Node3D = city.get_node("ProceduralDistricts")
	check(civic.find_child("CivicColumn",true,false) != null,"civic landmark includes facade columns")
	check(civic.find_child("CivicGlazing",true,false) != null,"civic landmark has repeated real windows")
	check(civic.find_child("CivicLightRibbon",true,false) != null,"night-visible roof details")
	print("HORIZON DETAIL NATIVE: %d pass, %d failures" % [passed,failed])
	city.queue_free()
	citizen.queue_free()
	quit(0 if failed==0 else 1)
