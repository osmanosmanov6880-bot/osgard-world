extends SceneTree
## R44 real Godot night lights: pooled, positioned at actual instanced
## lanterns, camera-local and quality-scaled. No fake sky overlay/physics.
const ROAD = preload("res://scripts/horizon_roadscape.gd")
const WORLD = preload("res://scripts/world_builder.gd")
var passed := 0
var failed := 0
func check(ok: bool,why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R44 REAL STREETLIGHT FAILED: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var scenic: Node3D = ROAD.new()
	root.add_child(scenic)
	var poses: Array = scenic.get("lamp_positions")
	var pool: Array = scenic.get("pooled_streetlights")
	check(poses.size()==162,"original 9x9x2 physical lamp geometry is preserved")
	check(pool.size()==ROAD.STREETLIGHT_POOL_LIMIT and pool.size()==4,"exactly four reusable real street lights")
	check(int(scenic.get("scenic_batches"))>=5,"real instanced lamp meshes and roads remain")
	for light in pool:
		check(light is OmniLight3D and light.omni_range <= 13.0,"one real bounded OmniLight3D node")
		check(not light.shadow_enabled and not light.visible,"no expensive shadow pass or daytime light")
		check(light.omni_attenuation>1.0,"real spatial distance attenuation")
	var focus := Vector3(-0.0,0.0,17.0)
	scenic.call("update_streetlights",22.0,"cinematic",focus)
	check(int(scenic.get("active_night_lights"))==4,"CINEMATIC uses only four nearby lights")
	var original_lamps: Array[Vector3] = []
	for light in pool:
		check(light.visible,"real light enabled during dark hours")
		original_lamps.append(light.position)
		var snapped: bool = false
		for pos in poses:
			if light.position.distance_to(pos+Vector3(0,-0.23,0))<0.001:
				snapped=true
				break
		check(snapped,"visible light is attached to original instanced lantern geometry")
		check(light.light_energy<=0.75,"bounded energy protects WebGL from cost explosion")
	scenic.call("update_streetlights",22.0,"standard",focus)
	check(int(scenic.get("active_night_lights"))==2,"STANDARD uses two real area lights")
	check(pool[0].visible and pool[1].visible and not pool[2].visible and not pool[3].visible,
		"STANDARD deliberately disables distant lights instead of drawing them")
	scenic.call("update_streetlights",22.0,"low",focus)
	check(int(scenic.get("active_night_lights"))==0,"LOW disables dynamic local sources")
	scenic.call("update_streetlights",12.0,"cinematic",focus)
	check(int(scenic.get("active_night_lights"))==0,"natural daylight disables all night road lights")
	scenic.call("update_streetlights",19.0,"cinematic",Vector3(10000,0,10000))
	check(int(scenic.get("active_night_lights"))==0,"far away light pool never follows or invents geometry")
	scenic.call("update_streetlights",NAN,"cinematic",focus)
	check(int(scenic.get("active_night_lights"))==0,"invalid clock never causes illegal night lighting")
	scenic.call("update_streetlights",22.0,"cinematic",Vector3(NAN,0,0))
	check(int(scenic.get("active_night_lights"))==0,"invalid world position never corrupts light transform")
	check(pool.size()==4 and poses.size()==162,"repeated settings never leak GPU light nodes")
	scenic.queue_free()
	var world: Node3D = WORLD.new()
	root.add_child(world)
	var live: Node3D = world.get("horizon_scenic")
	check(live!=null and live.is_inside_tree(),"actual drivable world owns the original roadscape")
	world.call("update_chunks",focus,"cinematic")
	world.call("apply_visual_budget","cinematic")
	world.call("update_daynight",22.0)
	check(int(live.get("active_night_lights"))==4,"real city clock makes premium road lights visible")
	world.call("apply_visual_budget","low")
	check(int(live.get("active_night_lights"))==0,"actual mobile budget turns off expensive lights")
	world.call("apply_visual_budget","standard")
	check(int(live.get("active_night_lights"))==2,"actual city restores two bounded street lights")
	world.call("update_daynight",12.0)
	check(int(live.get("active_night_lights"))==0,"actual live day transition switches off lights")
	var source: String=FileAccess.get_file_as_string("res://scripts/world_builder.gd")
	check(source.contains("update_streetlights"),"live world forwards player position, clock and quality")
	var main: Variant=load("res://scripts/main.gd")
	check(main!=null and main is Script and main.can_instantiate(),"real player driving scene continues to parse")
	world.queue_free()
	await process_frame
	print("EMPIRE OMEGA R44 STREETLIGHT NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
