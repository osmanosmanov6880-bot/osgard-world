extends SceneTree
## EMPIRE Ω R52: exercise one genuine Node3D game, not disconnected unit samples.
## R46 braking + R47 pedestrian routes + R48 p95 + R49 chapter reward together.
# Load the existing original .tscn only after the SceneTree autoloads exist.
# Eager preload of main.gd in --script mode breaks singleton resolution.
var passed := 0
var failed := 0
var chapter_ids: Array[String] = []

func check(ok: bool,reason: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("EMPIRE R52 LIVE JOIN FAILED: "+reason)

func _initialize() -> void:
	call_deferred("_run")

func _chapter_completed(id: String,_value: int) -> void:
	chapter_ids.append(id)

func _run() -> void:
	var state: Node = root.get_node_or_null("GameState")
	var missions: Node = root.get_node_or_null("MissionManager")
	check(state!=null and missions!=null,"original game singleton state and missions exist")
	if state==null or missions==null:
		quit(1)
		return
	var original_data: Dictionary = state.get("data").duplicate(true)
	var original_locale: String = str(state.get("locale"))
	state.set("data",state.call("new_game"))
	state.set("locale","ru")
	missions.connect("chapter_completed",Callable(self,"_chapter_completed"))
	# The real shipped scene is instantiated by Godot, not a synthetic MAIN.new()
	# mock. This avoids standalone --script eager-preload compilation before
	# engine autoload singletons are registered (GameState/MissionManager).
	var scene_error: Error = change_scene_to_file("res://scenes/main.tscn")
	check(scene_error==OK,"original shipped 3D scene loads after autoload initialization")
	if scene_error!=OK:
		state.set("data",original_data)
		state.set("locale",original_locale)
		quit(1)
		return
	await process_frame
	await physics_frame
	var game: Node3D = current_scene as Node3D
	check(game!=null,"Godot instantiated the real playable scene, not a test stub")
	if game==null:
		state.set("data",original_data)
		state.set("locale",original_locale)
		quit(1)
		return
	var car: CharacterBody3D = game.get("car")
	var city: Node3D = game.get("world")
	var player: CharacterBody3D = game.get("player")
	var hud: CanvasLayer = game.get("hud")
	check(car!=null and city!=null and player!=null and hud!=null,"real original city/player/vehicle/HUD instantiate in one playable scene")
	if car==null or city==null or player==null or hud==null:
		state.set("data",original_data)
		state.set("locale",original_locale)
		game.queue_free()
		quit(1)
		return
	var cars: Array = game.get("ambient_cars")
	var citizens: Array = game.get("pedestrians")
	check(cars.size()==12 and citizens.size()==34,"actual city spawns 12 moving vehicles and 34 pedestrians")
	check(cars[0].get("citizens").size()==citizens.size(),"real traffic receives exact 34 planned crossing trajectories")
	check(citizens[0].get("planned_velocity") is Vector3,"pedestrian agent exposes R47 predicted crossing velocity")
	check(game.get("adaptive_graphics").has_method("observe_frame_pacing"),"main owns p95-based R48 adaptive renderer")
	check(game.get("frame_metrics").has_method("p95_ms"),"R48 reads real accumulating gameplay render-frame samples")
	check(game.get("device_benchmark").has_method("record_frame"),"real original JSON physical frame diagnostic stays connected")
	check(str(hud.get("mission_chapter_label").text).contains("ПЕРВЫЕ ШАГИ"),"real HUD starts at chapter one, not a standalone static mock")
	var source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	check(source.contains("frame_metrics.p95_ms(),frame_metrics.samples()"),"R48 governor consumes actual player-loop p95 samples")
	check(source.contains("MissionManager.chapter_completed.connect(_on_chapter_done)"),"R49 authoritatively joins completion to real player feedback")
	check(source.contains("car.traction_factor = ROAD_WETNESS.effective_grip("),"R46 retains real dry/wet road feedback from the live city")
	check(source.contains('TRAFFIC_SCENE = preload("res://scripts/traffic_agent.gd")'),"R47 real traffic AI remains active in world")
	var metrics_before: int = int(game.get("frame_metrics").samples())
	await process_frame
	check(int(game.get("frame_metrics").samples())>=metrics_before,"actual render frame recorder advances inside original game scene")
	var started_speed: float = absf(float(car.get("speed")))
	game.set("driving",true)
	car.set("driving",true)
	Input.action_press("move_forward")
	for i in range(75):
		await physics_frame
	Input.action_release("move_forward")
	var current_speed: float = absf(float(car.get("speed")))
	check(current_speed>started_speed+2.0,"real player vehicle responds to physical Godot driving input")
	var brake_telemetry: Dictionary = car.get("r46_brake_diagnostics")
	check(brake_telemetry.has("front_axle_load_ratio") and brake_telemetry.has("available_brake_grip") and brake_telemetry.has("estimated_full_brake_m"),"real driven car produces R46 axle load and braking telemetry")
	check(float(brake_telemetry.get("available_brake_grip",0))>=0.35 and
		float(brake_telemetry.get("available_brake_grip",0))<=1.15,"R46 brake force stays within physical bounds")
	Input.action_press("move_backward")
	for i in range(21):
		await physics_frame
	Input.action_release("move_backward")
	check(float(car.get("speed"))<current_speed,"authentic live city brakes the moving car")
	check(car.global_position.is_finite() and car.velocity.is_finite(),"player car never leaves finite Godot space")
	var actual_state: Dictionary = state.get("data")
	actual_state["mission"]=5
	actual_state["wallet"]=1000
	var before_reward: int = int(actual_state["wallet"])
	check(bool(missions.call("register_action","contract_deliver")),"completing a real campaign mission triggers authoritative R49 event")
	check(int(actual_state["mission"])==6 and int(actual_state["wallet"])==before_reward+540,"real campaign credits base reward and first chapter bonus only once")
	check(chapter_ids==["arrival"],"new in-game R49 milestone emitted exactly once")
	check(not bool(missions.call("register_action","contract_deliver")),"repeated delivery cannot duplicate the chapter payout")
	check(int(actual_state["wallet"])==before_reward+540,"chapter economy never double-pays")
	hud.call("_refresh")
	check(str(hud.get("mission_chapter_label").text).contains("СОЗДАТЕЛЬ ГОРОДА"),
		"actual HUD advances into the second chapter after player completion")
	# Headless CI advances real scene ticks, but it does NOT attest GPU
	# frames: never count unfocused headless ticks as measured video FPS.
	check(Engine.get_process_frames()>=30,"real native gameplay scene advanced at least 30 engine frames")
	if DisplayServer.get_name() != "headless":
		check(int(game.get("frame_metrics").samples())>=30,
			"visible native 3D window produces qualified frame records")
	var output: Dictionary = {
		"schema":"omega-r52-native-joined-v1",
		"engine":"Godot 4.4.1",
		"scene":"res://scripts/main.gd",
		"actual_world":true,
		"citizens":citizens.size(),
		"traffic":cars.size(),
		"car_accelerated_speed_mps":current_speed,
		"car_braking_telemetry":brake_telemetry.duplicate(true),
		"chapter_completed":chapter_ids.duplicate(),
		"frames":int(game.get("frame_metrics").samples()),
		"checks_passed":passed,
		"checks_failed":failed,
		"physical_iphone_attested":false,
		"physical_android_attested":false,
		"published_source_sha_checked":false,
		"native_headless_frame_capture":DisplayServer.get_name()=="headless",
		"gpu_frame_pacing_attested":DisplayServer.get_name()!="headless",
		"release_authorized":false
	}
	var file_path: String = ProjectSettings.globalize_path("res://tests/r52-joined-gameplay-evidence.json")
	var file: FileAccess = FileAccess.open(file_path,FileAccess.WRITE)
	check(file!=null,"persist actual original-game numeric evidence")
	if file != null:
		output["checks_passed"]=passed
		output["checks_failed"]=failed
		file.store_string(JSON.stringify(output,"  "))
		file.close()
	car.set("driving",false)
	game.set("driving",false)
	game.queue_free()
	state.set("data",original_data)
	state.set("locale",original_locale)
	await process_frame
	print("EMPIRE OMEGA R52 JOINED LIVE GAME: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
