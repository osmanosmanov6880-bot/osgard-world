extends SceneTree
## CITY REIGN B63-B65: genuine funded community park, true resident
## walking route diversion, power-aware original 3D and durable save recovery.
const PARK = preload("res://scripts/city_reign_park_furniture.gd")
const PLANNER = preload("res://scripts/city_reign_park_routine.gd")
const CITIZEN = preload("res://scripts/pedestrian_agent.gd")
const ROUTINE = preload("res://scripts/citizen_routine.gd")
const WORLD = preload("res://scripts/world_builder.gd")
const SAVE = "user://city-reign-b64-park-save.dat"
const STAGED = "user://city-reign-b64-park-save.pending"
const BACKUP = "user://city-reign-b64-park-save.bak"
var passed: int = 0
var failed: int = 0

func verify(ok: bool,reason: String) -> void:
	if ok:
		passed+=1
	else:
		failed+=1
		push_error("CITY REIGN B64 REAL PUBLIC PARK FAIL: "+reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim: Node = root.get_node_or_null("GameState")
	verify(sim!=null,"original authoritative saved simulation exists")
	if sim==null:
		quit(2)
		return
	var original: Dictionary = sim.get("data").duplicate(true)
	var old_lang: String = str(sim.get("locale"))
	var paths: Array[String] = [
		str(sim.get("save_path")),str(sim.get("pending_save_path")),
		str(sim.get("backup_save_path"))]
	sim.set("save_path",SAVE)
	sim.set("pending_save_path",STAGED)
	sim.set("backup_save_path",BACKUP)
	for file in [SAVE,STAGED,BACKUP]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	sim.set("data",sim.call("new_game"))
	var world: Node3D = WORLD.new()
	root.add_child(world)
	var park: Node3D = world.get("city_reign_park_furniture")
	verify(park!=null and park.is_inside_tree(),
		"real source WorldBuilder installs genuine 3D paid municipal park")
	if park==null:
		quit(1)
		return
	verify(bool(park.call("graphics_are_bounded")),
		"one shared bench and lantern MultiMesh, no extra park colliders")
	verify(park.get_child_count()==2,
		"exactly two GPU instance batches support the real community park")
	verify(PLANNER.sourced_and_bounded(),
		"evening pedestrian destinations refer to the original funded plot and safe sidewalk")
	var baseline_plan: Dictionary = ROUTINE.plan(3,18.0,45,70)
	verify(str(baseline_plan["activity"])=="leisure",
		"true 17-21h source citizen routine already schedules leisure")
	var future: Dictionary = PLANNER.choose(baseline_plan,3,sim.get("data"))
	verify(future==baseline_plan and not future.has("municipal_attraction"),
		"unfunded park never attracts fictitious visitors")
	verify(not park.call("installed"),
		"empty new campaign never starts with purchased benches or lights")
	var state_before: Dictionary = sim.get("data").duplicate(true)
	verify(bool(sim.call("start_initiative","community_park")),
		"original GameState DEBITS park construction from real city funds")
	var active: Dictionary = sim.get("data")
	verify(int(active["treasury"])==int(state_before["treasury"])-460 and
		int(active["inventories"]["materials"])==
			int(state_before["inventories"]["materials"])-18 and
		int(active["inventories"]["goods"])==
			int(state_before["inventories"]["goods"])-12,
		"original real published price and material/goods inventory are obeyed")
	verify((active["projects_active"] as Dictionary).has("community_park"),
		"paid park is UNDER CONSTRUCTION, not falsely opened")
	world.call("update_development")
	verify(not park.call("installed"),
		"one player click cannot instantly spawn completed park furnishings")
	verify(PLANNER.choose(baseline_plan,3,active)==baseline_plan,
		"construction phase never reroutes pedestrians to an inaccessible park")
	for turn in range(3):
		verify(bool(sim.call("advance_turn")),
			"original city turn "+str(turn+1)+" legitimately advances the park")
		world.call("update_development")
		if turn<2:
			verify(not park.call("installed"),
				"incomplete public park stays shut until the real 3rd construction turn")
	var paid: Dictionary = sim.get("data")
	verify((paid["projects_done"] as Array).has("community_park") and
		park.call("installed"),
		"real 3-turn completed construction installs saved physical civic furniture")
	verify((paid["projects_active"] as Dictionary).is_empty(),
		"after construction completion no duplicate ongoing site remains")
	var chosen: Dictionary = PLANNER.choose(baseline_plan,3,paid)
	verify(str(chosen.get("municipal_attraction",""))=="community_park" and
		(chosen["destination"] as Vector3)==PLANNER.park_target(3),
		"resident leisure actually chooses the BUILT public park's world location")
	verify(not baseline_plan.has("municipal_attraction"),
		"existing citizen routine is read-only and unmodified by new park")
	verify(PLANNER.choose(ROUTINE.plan(3,10.0,45,70),3,paid).get(
		"municipal_attraction","")=="",
		"genuine work/daytime routines remain untouched even with an installed park")
	verify(not PLANNER.choose(baseline_plan,0,paid).has("municipal_attraction"),
		"only a bounded group of the existing citizens chooses the new destination")
	var visitor_count: int = 0
	for cid in range(34):
		var mapped: Dictionary = PLANNER.choose(ROUTINE.plan(cid,18.0,45,70),cid,paid)
		if mapped.has("municipal_attraction"):
			visitor_count+=1
			verify((mapped["destination"] as Vector3).x>161 and
				(mapped["destination"] as Vector3).z>-98,
				"real park visitors target safe 3D sidewalk, not the driven roadway")
	verify(visitor_count>0 and visitor_count<=PLANNER.MAX_PARK_VISITORS,
		"park animates only a strictly limited number of the real 34 walking agents")
	var walker: Node3D = CITIZEN.new()
	walker.set("citizen_id",3)
	root.add_child(walker)
	walker.position = Vector3(104.0,0.7,-104.0)
	paid["day_clock"]=18.0
	walker.call("_refresh_schedule")
	var actual_route: Array = walker.get("route")
	verify(actual_route.size()>2 and
		(actual_route.back() as Vector3)==PLANNER.park_target(3),
		"live original A* closure-aware pedestrian route ENDS at newly funded park")
	verify(str(walker.get("activity"))=="leisure" and
		walker.get_child_count()==1,
		"source NPC walking animation still has ONE physical body mesh and normal routine")
	var actual_position: Vector3 = walker.global_position
	walker.call("_process",0.03)
	verify(walker.global_position.distance_to(actual_position)>0.00001 and
		(walker.get("planned_velocity") as Vector3).length()>1.0,
		"real 3D resident physically starts WALKING toward paid public park")
	park.call("set_quality","low")
	verify(park.call("installed") and
		(park.get("benches") as MultiMeshInstance3D).visible and
		not (park.get("lanterns") as MultiMeshInstance3D).visible,
		"mobile LOW keeps actual benches but removes optional 3D lamps")
	park.call("set_quality","cinematic")
	park.call("update_ambience",22.0,95)
	var finish: StandardMaterial3D = park.get("lantern_finish")
	verify(finish.emission_enabled and finish.emission_energy_multiplier>0.0,
		"after funding, evening park light derives from real municipal power")
	park.call("update_ambience",22.0,0)
	verify(not finish.emission_enabled,
		"original blackout physically switches off actual park lamps")
	park.call("update_ambience",12.0,100)
	verify(not finish.emission_enabled,"true noon has no fake electric glow")
	var snapshot: Dictionary = sim.get("data").duplicate(true)
	verify(bool(sim.call("save_game")),"original 3-turn park investment persists in REAL disk save")
	sim.set("data",sim.call("new_game"))
	world.call("update_development")
	verify(not park.call("installed") and
		not PLANNER.park_exists(sim.get("data")),
		"starting a different campaign removes park buildings and visitor routes")
	verify(bool(sim.call("load_game")),"true original civic project loads back from disk")
	world.call("update_development")
	verify(park.call("installed") and
		PLANNER.park_exists(sim.get("data")) and
		PLANNER.choose(baseline_plan,3,sim.get("data")).has("municipal_attraction"),
		"one original save restores genuine 3D furniture AND resident park journeys")
	verify(int(sim.get("data")["treasury"])==int(snapshot["treasury"]) and
		int(sim.get("data")["turn"])==int(snapshot["turn"]),
		"original saved budget and build time survive reload without fake credits")
	var node_count: int = park.get_child_count()
	var true_money: int = int(sim.get("data")["treasury"])
	for i in range(10):
		world.call("update_development")
		park.call("set_quality","cinematic")
		park.call("update_ambience",22.0,95)
	verify(park.get_child_count()==node_count and
		int(sim.get("data")["treasury"])==true_money,
		"repeat quality/state refresh creates NO extra meshes, game payouts or saved fields")
	walker.queue_free()
	world.queue_free()
	await process_frame
	for file in [SAVE,STAGED,BACKUP]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	sim.set("save_path",paths[0])
	sim.set("pending_save_path",paths[1])
	sim.set("backup_save_path",paths[2])
	sim.set("data",original)
	sim.set("locale",old_lang)
	print("CITY REIGN B63-B65 ORIGINAL FUNDED PARK AND LIVE CITIZEN ROUTE: %d PASS %d FAIL" %
		[passed,failed])
	quit(0 if failed==0 else 1)
