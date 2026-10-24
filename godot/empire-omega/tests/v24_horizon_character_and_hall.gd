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
	# R28 migrated from dozens of standalone box meshes to seven shaded
	# GPU batches. Validate the playable geometry, not deleted legacy names.
	# WorldBuilder with GameState autoload is covered by v52's native scene.
	var world_source: String = FileAccess.get_file_as_string("res://scripts/world_builder.gd")
	check(world_source.contains("cityhall_gateway = CIVIC_GATEWAY.new()"),"real city attaches civic gateway R28")
	check(world_source.contains("wall.material_override = FACADE_MATERIALS.facade("),"landmark shell uses shared PBR wall material")
	check(not world_source.contains("CivicLightRibbon"),"bright old civic neon is intentionally removed")
	var gateway_script: Variant = load("res://scripts/horizon_civic_gateway.gd")
	check(gateway_script != null,"new civic gateway script loads in actual Godot runtime")
	if gateway_script != null:
		var gateway: Node3D = gateway_script.new()
		root.add_child(gateway)
		check(int(gateway.get("batches"))==7,"new civic gateway uses seven GPU-instanced material groups")
		for id in ["CivicStonePillars","CivicDarkGlass","CivicWindowFrames","CivicPortal"]:
			var mesh: MultiMeshInstance3D = gateway.get_node_or_null(id) as MultiMeshInstance3D
			check(mesh != null and mesh.multimesh.instance_count>0,"actual civic geometry: "+id)
			if mesh != null:
				var material: StandardMaterial3D = mesh.material_override as StandardMaterial3D
				check(material != null and not material.emission_enabled,"civic materials are not overbright neon: "+id)
		gateway.queue_free()
	print("HORIZON DETAIL NATIVE: %d pass, %d failures" % [passed,failed])
	citizen.queue_free()
	quit(0 if failed==0 else 1)
