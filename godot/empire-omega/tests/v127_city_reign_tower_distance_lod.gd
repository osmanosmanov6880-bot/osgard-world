extends SceneTree
## CITY REIGN B55 - source-native CPU/GPU-responsible tower LOD.
## Current original game _update_agent_lod() calls WorldBuilder.update_chunks
## at 1.1 second intervals; actual mesh switches follow original focus.
const POLICY = preload("res://scripts/city_reign_tower_distance_lod.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool,reason: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("CITY REIGN B55 TRUE DISTANCE LOD FAIL: "+reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	check(POLICY.choose("low",1.0,"cinematic")=="low",
		"phone low cannot accidentally enable costly cinematic meshes")
	check(POLICY.choose("standard",10.0,"low")=="standard" and
		POLICY.choose("standard",300.0,"standard")=="low",
		"standard upgrades near city body and degrades far building")
	check(POLICY.choose("cinematic",30.0,"low")=="cinematic" and
		POLICY.choose("cinematic",160.0,"low")=="standard" and
		POLICY.choose("cinematic",350.0,"cinematic")=="low",
		"cinematic has three genuine distance-sensitive mesh tiers")
	check(POLICY.choose("cinematic",120.0,"cinematic")=="cinematic" and
		POLICY.choose("cinematic",120.0,"standard")=="standard",
		"11m hysteresis avoids switching the same live mesh at a boundary")
	check(POLICY.projected_distance(Vector3(0,800,0),Vector3(3,0,4))==5.0,
		"vertical roads/camera height do not affect planar city LOD")
	check(POLICY.projected_distance(Vector3.INF,Vector3.ZERO)==INF and
		POLICY.choose("cinematic",NAN,"cinematic")=="low",
		"invalid focus or distance fails safe to original low geometry")
	var sim: Node = root.get_node_or_null("GameState")
	check(sim!=null,"real authoritative GameState registered")
	if sim==null:
		quit(2)
		return
	var snapshot: Dictionary = (sim.get("data") as Dictionary).duplicate(true)
	var world_source: Variant = load("res://scripts/world_builder.gd")
	check(world_source is Script and world_source.can_instantiate(),
		"real source WorldBuilder imports with native Godot autoloads")
	if not (world_source is Script and world_source.can_instantiate()):
		quit(1)
		return
	var world: Node3D = world_source.new()
	root.add_child(world)
	var original: Array = world.get("city_reign_tower_body_lods")
	var count: int = original.size()
	check(count>70 and count<=POLICY.STANDARD_METRES,
		"96 original colliding towers remain unmodified by distance policy")
	world.call("apply_visual_budget","cinematic")
	var focus := Vector3(-182.0,1.0,-78.0)
	world.call("update_chunks",focus,"cinematic")
	var counts: Dictionary = world.get("city_reign_tower_lod_counts")
	check(bool(POLICY.bounded_counts(count,counts)),
		"all current live original world tower instances are accounted for")
	check(int(counts["cinematic"])>0 and int(counts["standard"])>0 and
		int(counts["low"])>0,
		"live player focus has real near/mid/far LOD distributions")
	var refs: Array[MeshInstance3D] = []
	var shapes: Array[Shape3D] = []
	var selected_near: int = 0
	var selected_far: int = 0
	for entry in original:
		var e: Dictionary = entry
		var body: StaticBody3D = e["physical_body"]
		var visual: MeshInstance3D = e["visual"]
		var box: CollisionShape3D = body.get_node("CollisionShape3D")
		refs.append(visual)
		shapes.append(box.shape)
		var level: String = str(e.get("current_lod",""))
		var mesh: Mesh = e["original_mesh"] if level=="low" else e[level]
		check(visual.mesh==mesh and body.get_child_count()==2,
			"original drawable and original colliding body remain authoritative")
		var distance: float = POLICY.projected_distance(body.global_position,focus)
		if distance<=80.0:
			check(level=="cinematic","near road frontage uses true cinematic material geometry")
			selected_near += 1
		if distance>=260.0:
			check(level=="low","distant visible towers never spend cinematic vertex budget")
			selected_far += 1
	check(selected_near>0 and selected_far>0,
		"sampled physical near/far original scene world")
	var old_counts: Dictionary = counts.duplicate(true)
	world.call("update_chunks",focus+Vector3(0.3,0,0.2),"cinematic")
	check(world.get("city_reign_tower_lod_counts")==old_counts,
		"sub-meter camera jitter does not cause LOD switching")
	world.call("apply_visual_budget","standard")
	world.call("update_chunks",focus,"standard")
	counts = world.get("city_reign_tower_lod_counts")
	check(counts["cinematic"]==0 and counts["standard"]>0 and
		counts["low"]>0 and POLICY.bounded_counts(count,counts),
		"standard device quality genuinely degrades farther buildings")
	world.call("apply_visual_budget","low")
	world.call("update_chunks",focus,"low")
	counts = world.get("city_reign_tower_lod_counts")
	check(int(counts["low"])==count and int(counts["standard"])==0 and
		int(counts["cinematic"])==0,
		"phone LOW always restores all source original 12-triangle tower bodies")
	for i in range(original.size()):
		var e: Dictionary = original[i]
		var visual: MeshInstance3D = e["visual"]
		var body: StaticBody3D = e["physical_body"]
		check(visual==refs[i] and visual.mesh==e["original_mesh"] and
			(body.get_node("CollisionShape3D") as CollisionShape3D).shape==shapes[i],
			"camera LOD never destroys/reallocates original geometry or vehicle collider")
	check(sim.get("data")==snapshot,
		"performance adaptation never mints treasury, advances mission or edits saved game")
	world.queue_free()
	await process_frame
	print("CITY REIGN B55 TRUE SOURCE CAMERA LOD: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
