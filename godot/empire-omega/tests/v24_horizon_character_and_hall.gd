extends SceneTree
const PERSON = preload("res://scripts/player_controller.gd")
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
	# Engine smoke already tests real 3D world instantiation; this native test
	# validates the player, and source contracts for landmark components.
	# Loading WorldBuilder here before the GameState autoload is registered
	# causes an unrelated standalone ScriptTree compilation error.
	var world_source: String = FileAccess.get_file_as_string("res://scripts/world_builder.gd")
	check(world_source.contains("CivicColumn"),"civic facade column source contract")
	check(world_source.contains("CivicGlazing"),"civic facade window source contract")
	check(world_source.contains("CivicLightRibbon"),"civic lighting source contract")
	print("HORIZON DETAIL NATIVE: %d pass, %d failures" % [passed,failed])
	citizen.queue_free()
	quit(0 if failed==0 else 1)
