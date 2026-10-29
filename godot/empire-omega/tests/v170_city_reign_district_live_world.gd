extends SceneTree
## R173 full source city and actual physical original gameplay invariant.
const ID=preload("res://scripts/city_reign_district_identity.gd")
var pass_count: int=0
var fail_count: int=0
func check(ok: bool,why: String) -> void:
	if ok: pass_count+=1
	else:
		fail_count+=1
		push_error("CITY REIGN R173 ORIGINAL WORLD FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sim: Node=root.get_node_or_null("GameState")
	var old: Dictionary=sim.data.duplicate(true)
	var lang: String=sim.locale
	sim.data=sim.new_game()
	var initial: Dictionary=sim.data.duplicate(true)
	var changed: Error=change_scene_to_file("res://scenes/main.tscn")
	check(changed==OK,"original full Godot 3D city loads without replacement")
	if changed!=OK:
		sim.data=old
		sim.locale=lang
		quit(2)
		return
	await process_frame
	for i in range(8): await physics_frame
	var game: Node3D=current_scene as Node3D
	var world: Node3D=game.get("world")
	var art: Node3D=world.get("city_reign_street_identity")
	check(art!=null and art.graphics_are_bounded(),
		"new original 3D district art actually attached to physical world")
	check(int(art.get("count"))==int(world.get("building_count")),
		"every existing building has exactly one source-authored visible identity")
	check(art.get_child_count()<=ID.MAX_DRAWS,
		"true original-world GPU budget stays <=5 additional shared batches")
	var actual_bodies: int=0
	for chunk in world.get("building_chunks").values():
		for child in (chunk["node"] as Node3D).get_children():
			if child is StaticBody3D: actual_bodies+=1
	check(actual_bodies==int(world.get("building_count")),
		"source skyline preserves all real physical building colliders")
	for child in art.get_children():
		check(child is MultiMeshInstance3D and child.get_child_count()==0,
			"R173 art has no independent physics or mission-altering nodes")
	check((game.get("ambient_cars") as Array).size()==12 and
		(game.get("pedestrians") as Array).size()==34,
		"all original 12 moving cars and 34 pedestrians remain playable")
	world.apply_visual_budget("low")
	for child in art.get_children():
		check(not (child as Node3D).visible,
			"LOW hides original authored optional batches for actual mobile game")
	world.apply_visual_budget("cinematic")
	world.update_daynight(22.0)
	check((art.get_node("PoweredDistrictSigns") as Node3D).visible,
		"actual full 3D world's clock lights the new real district signs")
	world.update_daynight(12.0)
	check(not (art.get_node("PoweredDistrictSigns") as Node3D).visible,
		"real world noon disables all optional signs' expensive emission")
	check(int(sim.data["mission"])==0 and
		int(sim.data["wallet"])==int(initial["wallet"]) and
		int(sim.data["treasury"])==int(initial["treasury"]) and
		sim.data.get("buildings",{})==initial.get("buildings",{}),
		"no wallet, treasury, building purchases or mission authority modified by street art")
	current_scene.queue_free()
	await process_frame
	sim.data=old
	sim.locale=lang
	print("CITY REIGN R173 REAL GODOT WORLD: %d PASS %d FAIL" % [pass_count,fail_count])
	quit(0 if fail_count==0 else 1)
