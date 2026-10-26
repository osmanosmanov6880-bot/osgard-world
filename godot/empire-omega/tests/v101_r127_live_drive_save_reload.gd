extends SceneTree
## R127 B4: one real shipped Godot 4.4.1 scene, not a mocked UI.
## Actual on-foot -> vehicle entry -> accelerated driving -> governance -> disk
## save -> deliberate corruption of live memory -> genuine disk reload.
## This is a short ENGINE integration test, NOT a 15-20min human playthrough.
var passed: int = 0
var failed: int = 0

func check(ok: bool, reason: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R127 B4 ACTUAL DRIVE/SAVE/RELOAD FAIL: "+reason)

func _initialize() -> void:
	call_deferred("_run")

func _discard(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _run() -> void:
	var state: Node = root.get_node_or_null("GameState")
	var missions: Node = root.get_node_or_null("MissionManager")
	check(state!=null and missions!=null,"original authoritative game and mission autoloads exist")
	if state==null or missions==null:
		quit(1)
		return
	var prior_data: Dictionary = (state.get("data") as Dictionary).duplicate(true)
	var prior_locale: String = str(state.get("locale"))
	var old_primary: String = str(state.get("save_path"))
	var old_pending: String = str(state.get("pending_save_path"))
	var old_backup: String = str(state.get("backup_save_path"))
	var token: String = "omega_r127_%d" % OS.get_process_id()
	var primary: String = "user://"+token+".json"
	var pending: String = "user://"+token+".pending"
	var backup: String = "user://"+token+".backup.json"
	# All writes stay in isolated temporary paths: no existing user save touched.
	state.set("save_path",primary)
	state.set("pending_save_path",pending)
	state.set("backup_save_path",backup)
	for path in [primary,pending,backup]:
		_discard(path)
	state.set("data",state.call("new_game"))
	state.set("locale","ru")
	var err: Error = change_scene_to_file("res://scenes/main.tscn")
	check(err==OK,"authentic shipped 3D scene loads after all autoloads")
	if err != OK:
		_cleanup(state,prior_data,prior_locale,old_primary,old_pending,old_backup,
			primary,pending,backup)
		quit(1)
		return
	await process_frame
	await physics_frame
	var game: Node3D = current_scene as Node3D
	check(game!=null,"a real Godot main scene, not static HTML, is instantiated")
	if game==null:
		_cleanup(state,prior_data,prior_locale,old_primary,old_pending,old_backup,
			primary,pending,backup)
		quit(1)
		return
	var car: CharacterBody3D = game.get("car") as CharacterBody3D
	var player: CharacterBody3D = game.get("player") as CharacterBody3D
	var hud: CanvasLayer = game.get("hud") as CanvasLayer
	var world: Node3D = game.get("world") as Node3D
	var road_agents: Array = game.get("ambient_cars")
	var pedestrians: Array = game.get("pedestrians")
	check(car!=null and player!=null and hud!=null and world!=null,
		"original car, player, native Godot HUD and 3D city all exist")
	check(road_agents.size()==12 and pedestrians.size()==34,
		"full original 12 traffic agents and 34 walking citizens survive R127")
	if car!=null and player!=null and hud!=null and world!=null:
		check(player.global_position.distance_to(car.global_position)<8.0,
			"initial authored playable level starts close enough to enter the car")
		game.call("_enter_or_exit_vehicle")
		check(bool(game.get("driving")) and bool(car.get("driving")) and not player.visible,
			"actual player E interaction transfers physical drive control")
		var before: Vector3 = car.global_position
		var initial_speed: float = absf(float(car.get("speed")))
		Input.action_press("move_forward")
		for i in range(75):
			await physics_frame
		Input.action_release("move_forward")
		var accelerated: float = absf(float(car.get("speed")))
		check(accelerated>initial_speed+1.0 and car.global_position.is_finite(),
			"physical wheel and control source accelerates in the real city")
		check(car.global_position.distance_to(before)>0.2,
			"car traverses an actual distance, not a mocked movement flag")
		var progressed: int = int((state.get("data") as Dictionary)["mission"])
		check(progressed>=1,"genuine enter-vehicle event advances the original campaign")
		hud.call("toggle_strategy")
		check(bool(hud.get("open")) and world.get("r90_urban")!=null,
			"Tab city governance coexists with the live physical urban scene")
		game.call("_save")
		check(bool(state.get("last_save_ok")) and FileAccess.file_exists(primary),
			"original game saved real player/car and mission to isolated disk file")
		var snapshot: Dictionary = (state.get("data") as Dictionary).duplicate(true)
		var saved_coordinates: Array = snapshot.get("vehicle_position",[])
		check(saved_coordinates.size()==3,"real 3D car checkpoint coordinates persisted")
		var written: Dictionary = state.call("_read_valid_save",primary)
		check(not written.is_empty() and int(written.get("version",0))>=4,
			"versioned original integrity-checked native save file exists")
		if not written.is_empty():
			var save_state: Dictionary = written.get("state",{})
			check(int(save_state.get("mission",-1))==progressed and
				int(save_state.get("wallet",-1))==int(snapshot["wallet"]),
				"checkpoint actually contains both campaign stage and real economy")
		var live_data: Dictionary = state.get("data") as Dictionary
		live_data["wallet"] = int(snapshot["wallet"])+33
		car.global_position += Vector3(0,0,10)
		game.call("_load")
		check(str(state.get("last_load_source"))=="primary",
			"the main game performed a real primary-disk load, not a state copy")
		var restored: Dictionary = state.get("data") as Dictionary
		check(int(restored["wallet"])==int(snapshot["wallet"]) and
			int(restored["mission"])==progressed,
			"authoritative economy and campaign restore exactly, with no duplicate reward")
		if saved_coordinates.size()==3:
			var expected := Vector3(float(saved_coordinates[0]),
				float(saved_coordinates[1]),float(saved_coordinates[2]))
			check(car.global_position.distance_to(expected)<0.25,
				"real in-scene car returns to original saved 3D checkpoint position")
		check(not bool(game.get("driving")) and not bool(car.get("driving")),
			"loading returns the real player safely to on-foot control")
		if bool(hud.get("open")):
			hud.call("toggle_strategy")
		check(not bool(hud.get("open")),
			"native governance can close after disk reload without losing gameplay")
		var report: Dictionary = {
			"schema":"empire-omega-r127-joined-b4-v1",
			"actual_scene":"res://scenes/main.tscn",
			"traffic_agents":road_agents.size(),
			"pedestrians":pedestrians.size(),
			"physics_frames_driven":75,
			"car_speed_after_input_mps":accelerated,
			"mission_progress":progressed,
			"verified_saved_checkpoint":saved_coordinates,
			"disk_load_source":str(state.get("last_load_source")),
			"passed":passed,
			"failed":failed,
			"human_15_min_playthrough_completed":false,
			"physical_phone_fps_verified":false,
			"aaa_art_approved":false,
			"production_authorized":false
		}
		var output: FileAccess = FileAccess.open(
			ProjectSettings.globalize_path("res://tests/r127-actual-drive-save-evidence.json"),
			FileAccess.WRITE)
		if output != null:
			output.store_string(JSON.stringify(report,"  "))
			output.close()
		check(output!=null,"machine-readable original engine and disk-save evidence written")
	game.queue_free()
	await process_frame
	_cleanup(state,prior_data,prior_locale,old_primary,old_pending,old_backup,
		primary,pending,backup)
	print("EMPIRE OMEGA R127 LIVE B4 DRIVE/DISK RESTORE: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)

func _cleanup(state: Node, old_data: Dictionary, old_locale: String,
		old_primary: String, old_pending: String, old_backup: String,
		primary: String, pending: String, backup: String) -> void:
	for path in [primary,pending,backup]:
		_discard(path)
	state.set("save_path",old_primary)
	state.set("pending_save_path",old_pending)
	state.set("backup_save_path",old_backup)
	state.set("data",old_data)
	state.set("locale",old_locale)
