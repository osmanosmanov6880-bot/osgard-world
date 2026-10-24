extends SceneTree
const PERSON = preload("res://scripts/player_controller.gd")
const CIVIC = preload("res://scripts/horizon_civic_gateway.gd")
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
	# R28 intentionally removed obsolete per-mesh CivicColumn / CivicGlazing
	# and the fluorescent CivicLightRibbon. Assert the live successor instead.
	check(world_source.contains("CIVIC_GATEWAY.new()"),"world actually instantiates the R28 civic gateway")
	check(world_source.contains("city_root.add_child(cityhall_gateway)"),"civic gateway is attached to the playable city")
	var civic: Node3D = CIVIC.new()
	root.add_child(civic)
	check(int(civic.get("batches"))==7,"civic landmark uses seven bounded real GPU draw batches")
	var columns: MultiMeshInstance3D = civic.get_node_or_null("CivicStonePillars") as MultiMeshInstance3D
	check(columns!=null and columns.multimesh.instance_count==6,"civic has six real rounded stone columns")
	var glass: MultiMeshInstance3D = civic.get_node_or_null("CivicDarkGlass") as MultiMeshInstance3D
	check(glass!=null and glass.multimesh.instance_count==20,"civic has twenty real dark-glass windows")
	var old_ribbon: Node = civic.get_node_or_null("CivicLightRibbon")
	check(old_ribbon==null,"old harsh neon ribbon was deliberately removed")
	if columns!=null:
		var stone: StandardMaterial3D = columns.material_override as StandardMaterial3D
		check(stone!=null and stone.normal_enabled and stone.normal_texture!=null,"stone columns have genuine PBR normal surface")
		check(stone!=null and not stone.emission_enabled,"civic surface does not use fake fullbright emission")
	civic.queue_free()
	print("HORIZON DETAIL NATIVE: %d pass, %d failures" % [passed,failed])
	citizen.queue_free()
	quit(0 if failed==0 else 1)
