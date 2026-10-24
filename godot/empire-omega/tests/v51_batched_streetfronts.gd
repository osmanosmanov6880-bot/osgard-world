extends SceneTree
## HORIZON R27: actual street-level 3D architectural details, one GPU
## MultiMesh per facade material; zero new colliders or vehicle actions.
const FRONT = preload("res://scripts/horizon_streetfront_details.gd")
# Load WorldBuilder when SceneTree is running, consistent with R25 world tests.
var passed := 0
var failed := 0

func verify(ok: bool, reason: String) -> void:
	if ok:
		passed+=1
	else:
		failed+=1
		push_error("HORIZON R27 FAILED: "+reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for variant in range(4):
		var ground_blocked := 0
		for facade in range(4):
			if not FRONT.window_allowed(0,facade,variant):
				ground_blocked += 1
			verify(FRONT.window_allowed(1,facade,variant),"upper windows remain intact regardless of entrance direction")
		verify(ground_blocked==1,"exactly one street-facing ground-floor window band is replaced by the new storefront")
	verify(not FRONT.window_allowed(0,0,0) and not FRONT.window_allowed(0,2,1) and not FRONT.window_allowed(0,1,2) and not FRONT.window_allowed(0,3,3),
		"entry facade orientation agrees with four rotated storefront models")
		verify(FRONT.road_facing_variant(Vector3(17,0,23),52.0)==1,"storefront on negative X road side faces that road")
	verify(FRONT.road_facing_variant(Vector3(-17,0,23),52.0)==3,"storefront on positive X road side faces that road")
	verify(FRONT.road_facing_variant(Vector3(23,0,17),52.0)==0,"storefront on negative Z road side faces that road")
	verify(FRONT.road_facing_variant(Vector3(23,0,-17),52.0)==2,"storefront on positive Z road side faces that road")
	verify(FRONT.road_facing_variant(Vector3(-17,0,-17),52.0,true)==3,"street-corner tie-break can face X avenue")
	verify(FRONT.road_facing_variant(Vector3(-17,0,-17),52.0,false)==2,"street-corner tie-break can face Z avenue")
	var detail: Node3D = FRONT.new()
	detail.record(Vector3(10,9,8),12.0,18.0,0)
	detail.record(Vector3(-20,13,-12),14.0,26.0,1)
	detail.record(Vector3(40,6,24),10.0,12.0,2)
	detail.finalize()
	verify(int(detail.get("frontage_count"))==3,"three independent full-sized facades registered")
	verify(int(detail.get("batches"))==5,"all storefront geometry requires exactly five material batches")
	verify(detail.get_child_count()==5,"no hidden per-shop scene nodes or textures")
	verify(int(detail.call("surface_instance_count"))==24,"each facade uses exactly eight solid decorative pieces")
	for id in ["ShopfrontGlassBatch","EntranceDoorBatch","MetalJambBatch","SatinAwningBatch","StreetSignBandBatch"]:
		var obj: MultiMeshInstance3D = detail.get_node_or_null(id) as MultiMeshInstance3D
		verify(obj!=null,"real 3D GPU mesh group exists: "+id)
		if obj!=null:
			var mat: StandardMaterial3D = obj.material_override as StandardMaterial3D
			verify(obj.multimesh.instance_count>0 and mat!=null,"batched material and instances available: "+id)
			verify(not mat.emission_enabled,"storefront uses physical shading rather than decorative fullbright neon")
			verify(obj.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"mobile shadow GPU budget unchanged: "+id)
	var glass: MultiMeshInstance3D = detail.get_node("ShopfrontGlassBatch")
	var front_glass: Transform3D = (detail.get("glass_poses") as Array)[0]
	verify(front_glass.origin.z < 8.0-6.0,"first shop glass sits on exterior street-facing wall")
	verify(absf(front_glass.origin.y-1.62)<0.01,"shopfront glazing located at plausible pedestrian eye level")
	verify(glass.multimesh.instance_count==6,"two storefront glass windows per building")
	var gpu_source: String = FileAccess.get_file_as_string("res://scripts/horizon_streetfront_details.gd")
	verify(gpu_source.contains("instances.set_instance_transform(i,poses[i])"),"original measured transforms are uploaded into GPU instances")
	verify((detail.get_node("MetalJambBatch") as MultiMeshInstance3D).multimesh.instance_count==9,"three entrance frame pieces per building")
	var variation: Transform3D = (detail.get("door_poses") as Array)[1]
	verify(variation.origin.x < -20.0-6.0,"second facade rotates door toward a different street")
	var collider_count := 0
	for node in detail.get_children():
		if node is CollisionObject3D:
			collider_count += 1
	verify(collider_count==0,"decorative storefronts never block a car or pedestrian")
	var impossible: Node3D = FRONT.new()
	impossible.record(Vector3(0,5,0),12,9,0)
	impossible.record(Vector3(NAN,0,0),12,9,2)
	impossible.record(Vector3(0,0,0),-12,9,2)
	verify(int(impossible.get("frontage_count"))==1,"malformed building measurements cannot create broken geometry")
	var world_script: Variant = load("res://scripts/world_builder.gd")
	verify(world_script!=null,"full WorldBuilder script loads under native Godot")
	var world: Node3D = world_script.new()
	root.add_child(world)
	var live: Node3D = world.get("streetfront")
	verify(live!=null,"original playable WorldBuilder creates new details inside game scene")
	verify(live.is_inside_tree(),"actual level, not a detached mock scene, contains storefront GPU batches")
	verify(int(live.get("frontage_count"))==int(world.get("building_count")),"every generated city building gets exactly one real frontage")
	verify(int(live.get("batches"))==5,"live complete city preserves five GPU material batches")
	verify(int(live.call("surface_instance_count"))==8*int(world.get("building_count")),"all real shopfronts instanced without extra draw calls")
	verify(int(live.get("frontage_count"))<=FRONT.BUILDING_LIMIT,"full city stays within bounded instance pool")
	# Verify each generated ground-floor entrance is on the side
	# facing the nearest public road, not buried in a courtyard.
	var checked_facades := 0
	var all_doors_face_roads := true
	var facade_poses: Array = live.get("door_poses")
	var city_chunks: Dictionary = world.get("building_chunks")
	for chunk_id in city_chunks:
		var section: Node3D = city_chunks[chunk_id]["node"]
		for building in section.get_children():
			if not String(building.name).begins_with("Building_"):
				continue
			var number: int = String(building.name).trim_prefix("Building_").to_int()
			if number >= facade_poses.size():
				all_doors_face_roads = false
				continue
			var center: Vector3 = building.position
			var door: Vector3 = (facade_poses[number] as Transform3D).origin
			var center_road_distance: float = minf(
				absf(center.x-roundf(center.x/52.0)*52.0),
				absf(center.z-roundf(center.z/52.0)*52.0))
			var door_road_distance: float = minf(
				absf(door.x-roundf(door.x/52.0)*52.0),
				absf(door.z-roundf(door.z/52.0)*52.0))
			if door_road_distance>=center_road_distance-1.0:
				all_doors_face_roads = false
			checked_facades += 1
	verify(checked_facades==int(world.get("building_count")),"tested road-facing entrance on every existing city building")
	verify(all_doors_face_roads,"all real city shopfronts face public roads rather than inaccessible interior walls")

	world.apply_visual_budget("low")
	verify(not live.visible,"low-quality mobile GPU hides optional street-level facade geometry")
	world.apply_visual_budget("standard")
	verify(live.visible,"standard mode restores attractive real architectural geometry")
	world.apply_visual_budget("cinematic")
	verify(live.visible,"cinematic mode retains street-level architecture")
	verify(world.get_node_or_null("ProceduralDistricts/InstancedFacadeWindows")!=null,"original real window batches survive")
	var source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	verify(source.contains("TOUCH_CONTROLS_SCENE.new()"),"native phone commands remain wired into actual game")
	verify(source.contains("SAFE_CAMERA.solve("),"collision-safe camera still drives real car")
	verify(source.contains("ground_spray.call(\"update_spray\""),"R23 wet weather particle effects retained")
	detail.queue_free()
	impossible.queue_free()
	world.queue_free()
	print("HORIZON R27 NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
