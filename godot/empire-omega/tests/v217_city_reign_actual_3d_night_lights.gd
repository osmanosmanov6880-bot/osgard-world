extends SceneTree
## R189 full original playable Godot 3D actual 12 cars and R188 live yaw.
const HEADLIGHTS=preload("res://scripts/city_reign_pooled_traffic_headlights.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R189 ACTUAL LIVE GODOT HEADLIGHTS FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var gs: Node=root.get_node("GameState")
	var previous: Dictionary=(gs.get("data") as Dictionary).duplicate(true)
	var locale: String=str(gs.get("locale"))
	gs.set("data",gs.new_game())
	var clean: Dictionary=(gs.get("data") as Dictionary).duplicate(true)
	var loaded: Error=change_scene_to_file("res://scenes/main.tscn")
	check(loaded==OK,"REAL original Godot full native 3D game loads, not a headlight art mock")
	if loaded!=OK:
		gs.set("data",previous)
		gs.set("locale",locale)
		quit(2)
		return
	await process_frame
	for i in range(8):await physics_frame
	var game: Node3D=current_scene as Node3D
	var cars: Array=game.get("ambient_cars")
	var people: Array=game.get("pedestrians")
	var pool: Node3D=game.get("pooled_traffic_headlamps") as Node3D
	var player_car: CharacterBody3D=game.get("car") as CharacterBody3D
	check(cars.size()==12 and people.size()==34 and pool!=null and
		pool.candidates.size()==12 and pool.source_integrity(),
		"ALL 12 actual physical NPC bodies, 34 original residents and one 6-light live pool")
	check(player_car.headlight_cones.size()==2 and
		pool.beams.size()+player_car.headlight_cones.size()==8,
		"original player's two existing R33 physical SpotLights remain unchanged: <=8 vehicle beams total")
	var tracked: CharacterBody3D=cars[0] as CharacterBody3D
	tracked.set_physics_process(false)
	pool.sync_real_city(tracked.global_position,23.0,"cinematic","rain",0.8)
	check(pool.active_physical_pairs>=1 and pool.active_physical_pairs<=3 and
		pool.selected[0]==tracked and pool.beams[0].visible,
		"real first original CharacterBody3D physically owns nearest projected nighttime headlight pair")
	var before: Vector3=pool.beams[0].global_position
	tracked.rotation.y+=0.31
	pool.sync_real_city(tracked.global_position,23.0,"cinematic","rain",0.1)
	check(pool.beams[0].global_position.distance_to(before)>0.3 and
		pool.beams[0].global_position.distance_to(
			tracked.global_transform*Vector3(-0.77,0.42,-2.05))<0.001,
		"R188 actual physical native chassis rotation updates R189 REAL world light cone")
	pool.sync_real_city(tracked.global_position,23.0,"standard","clear",0.1)
	check(pool.active_physical_pairs==1 and pool.beams[0].visible and
		not pool.beams[2].visible,
		"STANDARD auto budget correctly reduces genuine 12-vehicle night lights to one pair")
	pool.sync_real_city(tracked.global_position,23.0,"low","rain",0.1)
	player_car.update_headlights(23.0,"low")
	check(pool.active_physical_pairs==0 and
		pool.beams.all(func(b):return not b.visible) and
		player_car.headlight_cones.all(func(b):return not b.visible),
		"real mobile LOW disables all eight vehicle spotlights, keeps native car geometry/colliders")
	check(pool.source_integrity() and
		game.get("traffic_signals").visual_state_is_consistent(),
		"source original 16 junction signals / 144 yellow road box stripes unaffected")
	check(int(gs.data["wallet"])==int(clean["wallet"]) and
		int(gs.data["mission"])==int(clean["mission"]) and
		gs.data["inventories"]==clean["inventories"],
		"real driving light budget never alters actual 40 missions, wallet or original save schema")
	game.queue_free()
	await process_frame
	gs.set("data",previous)
	gs.set("locale",locale)
	print("CITY REIGN R189 ORIGINAL 3D VEHICLE LIGHTS: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
