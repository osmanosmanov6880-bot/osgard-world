extends SceneTree
## R189: true native 6-SpotLight3D pool, pure nearest source-culling
## tests via 12 ordinary Node3D fixtures (not a physical phone FPS test).
const HEADLIGHTS=preload("res://scripts/city_reign_pooled_traffic_headlights.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R189 REAL NPC HEADLIGHTS POOL FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var fixtures:=Node3D.new()
	root.add_child(fixtures)
	var vehicles: Array=[]
	for i in range(12):
		var body:=Node3D.new()
		body.name="OriginalTrafficSourceFixture%d" % i
		body.position=Vector3(float(i)*8.0,0.8,0)
		fixtures.add_child(body)
		vehicles.append(body)
	var pool=HEADLIGHTS.new()
	root.add_child(pool)
	pool.set_sources(vehicles)
	check(pool.source_integrity() and pool.candidates.size()==12 and
		pool.beams.size()==6 and pool.get_child_count()==6,
		"actual exactly SIX Godot SpotLight3D objects for 12 source vehicle positions")
	check(HEADLIGHTS.source_budget_for("low")==0 and
		HEADLIGHTS.source_budget_for("standard")==1 and
		HEADLIGHTS.source_budget_for("cinematic")==3,
		"LOW 0, STANDARD 2, CINEMATIC 6 actual night NPC light sources (not 24)")
	check(not HEADLIGHTS.is_actual_night(12.0) and
		HEADLIGHTS.is_actual_night(23.0) and
		HEADLIGHTS.is_actual_night(5.0),
		"road lights share original player's 18:45 to 06:45 night window")
	pool.sync_real_city(Vector3(0,0.8,0),23.0,"standard","clear",0.1)
	check(pool.active_physical_pairs==1 and pool.selected.size()==1 and
		pool.selected[0]==vehicles[0] and
		pool.beams[0].visible and pool.beams[1].visible and not pool.beams[2].visible,
		"STANDARD renders only original closest true car's TWO physical headlamps")
	var first: Vector3=pool.beams[0].global_position
	check(first.distance_to(
		vehicles[0].global_transform*Vector3(-0.77,0.42,-2.05))<0.001,
		"original real SpotLight3D attaches to actual native front-left vehicle headlamp")
	vehicles[0].rotation.y=PI/2.0
	pool.sync_real_city(Vector3(0,0.8,0),23.0,"standard","clear",0.1)
	check(pool.beams[0].global_position.distance_to(first)>0.4 and
		pool.beams[0].global_position.distance_to(
			vehicles[0].global_transform*Vector3(-0.77,0.42,-2.05))<0.001,
		"actual dynamically rotated original chassis moves the real light cone in 3D")
	pool.sync_real_city(Vector3(0,0.8,0),23.0,"cinematic","storm",0.1)
	check(pool.active_physical_pairs==3 and
		pool.beams[5].visible and
		pool.beams[0].light_energy>1.05 and pool.beams[0].spot_range==21.0,
		"cinematic rain renders at most six physically wet-road light sources, no shadow copies")
	for lamp in pool.beams:
		check(lamp is SpotLight3D and not lamp.shadow_enabled and
			lamp.spot_range<=21.0 and lamp.get_child_count()==0,
			"native original GPU budget: no shadows, no extra node children or far light leaks")
	pool.sync_real_city(Vector3(0,0.8,0),12.0,"cinematic","rain",0.1)
	check(pool.active_physical_pairs==0 and pool.beams.all(func(x):return not x.visible),
		"real DAYTIME disables all NPC SpotLights instead of casting fictitious night beams")
	pool.sync_real_city(Vector3(0,0.8,0),23.0,"low","rain",0.1)
	check(pool.active_physical_pairs==0 and pool.source_integrity(),
		"original low-tier mobile world retains true cars but strictly zero extra dynamic lights")
	pool.sync_real_city(Vector3(NAN,0,0),23.0,"cinematic","rain",0.1)
	check(pool.active_physical_pairs==0 and pool.beams.all(func(x):return not x.visible),
		"corrupt camera/tracking never creates phantom source headlights")
	pool.queue_free()
	fixtures.queue_free()
	await process_frame
	print("CITY REIGN R189 REAL SIX GPU HEADLIGHTS: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
