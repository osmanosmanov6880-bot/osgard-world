extends Node3D
## OSGARD Empire Omega: procedural 3D vertical slice (city + driving + strategy).
## One authoritative GameState, two interfaces: open world and governor's cabinet.

const WORLD_SCENE = preload("res://scripts/world_builder.gd")
const PLAYER_SCENE = preload("res://scripts/player_controller.gd")
const CAR_SCENE = preload("res://scripts/vehicle_controller.gd")
const HUD_SCENE = preload("res://scripts/hud.gd")
const TOUCH_CONTROLS_SCENE = preload("res://scripts/horizon_touch_controls.gd")
const PEDESTRIAN_SCENE = preload("res://scripts/pedestrian_agent.gd")
const TRAFFIC_SCENE = preload("res://scripts/traffic_agent.gd")
const ROUTER = preload("res://scripts/street_router.gd")
const INTERIOR_SCENE = preload("res://scripts/interior_manager.gd")
const LANDMARKS_SCENE = preload("res://scripts/project_landmarks.gd")
const SIGNALS_SCENE = preload("res://scripts/traffic_signal_controller.gd")
const ROADWORKS_SCENE = preload("res://scripts/roadworks_visual.gd")
const MOBILITY = preload("res://scripts/city_mobility.gd")
const SOUND_SCENE = preload("res://scripts/city_soundscape.gd")
const CASE_MARKER_SCENE = preload("res://scripts/city_case_marker.gd")
const CARGO_VISUAL_SCENE = preload("res://scripts/cargo_visual.gd")
const POLICE_SCENE = preload("res://scripts/police_dispatch.gd")
const TRIAL_MARKER_SCENE = preload("res://scripts/trial_marker.gd")
const DISCOVERY_MARKERS = preload("res://scripts/discovery_markers.gd")

var world
var interiors
var landmarks
var traffic_signals
var roadworks
var soundscape
var city_case_marker
var cargo_visual
var current_weather_kind := "clear"
var player
var car
var camera: Camera3D
var hud
var touch_controls
var cam_yaw := 0.32
var cam_pitch := 0.38
var mouse_sensitivity := 0.003
var driving := false
var autosave_accumulator := 0.0
var last_position := Vector3.ZERO
var route_refresh := 0.0
var last_route_goal := Vector3.ZERO
var pedestrians: Array = []
var ambient_cars: Array = []
var lod_timer := 0.0
var diagnostic_timer := 0.0
var patrols
var previous_vehicle_health := 100.0
var speeding_seconds := 0.0
var near_miss_sample := 0.0
var police_capture_cooldown := 0.0
var trial_marker
var discovery_markers

func _ready() -> void:
	world = WORLD_SCENE.new()
	add_child(world)
	world.update_development()
	city_case_marker = CASE_MARKER_SCENE.new()
	add_child(city_case_marker)
	city_case_marker.sync_state(GameState.data)
	trial_marker = TRIAL_MARKER_SCENE.new()
	add_child(trial_marker)
	discovery_markers = DISCOVERY_MARKERS.new()
	add_child(discovery_markers)
	landmarks = LANDMARKS_SCENE.new()
	add_child(landmarks)
	landmarks.sync_projects(GameState.data.get("projects_done",[]))
	traffic_signals = SIGNALS_SCENE.new()
	add_child(traffic_signals)
	roadworks = ROADWORKS_SCENE.new()
	add_child(roadworks)
	interiors = INTERIOR_SCENE.new()
	add_child(interiors)
	player = PLAYER_SCENE.new()
	add_child(player)
	car = CAR_SCENE.new()
	add_child(car)
	cargo_visual = CARGO_VISUAL_SCENE.new()
	car.add_child(cargo_visual)
	cargo_visual.sync_state(GameState.data,GameState.locale)
	_sync_positions_from_state()
	camera = Camera3D.new()
	camera.name = "ThirdPersonCamera"
	camera.fov = 76
	camera.far = 900.0
	camera.current = true
	add_child(camera)
	camera.global_position = player.global_position + Vector3(4,7,10)
	soundscape = SOUND_SCENE.new()
	add_child(soundscape)
	soundscape.attach_vehicle(car)
	_spawn_traffic()
	_spawn_citizens()
	patrols = POLICE_SCENE.new()
	add_child(patrols)
	patrols.traffic_signals = traffic_signals
	patrols.citizens = pedestrians
	previous_vehicle_health = car.health
	hud = HUD_SCENE.new()
	add_child(hud)
	touch_controls = TOUCH_CONTROLS_SCENE.new()
	add_child(touch_controls)
	world.update_language(GameState.locale)
	_apply_weather()
	hud.strategy_changed.connect(_on_strategy_changed)
	hud.dialogue_changed.connect(_on_dialogue_changed)
	hud.wants_save.connect(_save)
	hud.wants_load.connect(_load)
	hud.wants_reset.connect(_new_game)
	car.drift_reward_earned.connect(_on_drift_reward_earned)
	GameState.state_changed.connect(_on_game_changed)
	GameState.alert_created.connect(_on_alert)
	GameSettings.preferences_changed.connect(_apply_preferences)
	MissionManager.mission_completed.connect(_on_mission_done)
	ContractManager.contract_changed.connect(_on_contract_changed)
	_apply_preferences()
	_sync_trial_marker()
	if GameState.last_load_source == "backup" or GameState.last_load_source == "staged":
		hud.announce(hud.t("save_recovered"))
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if DisplayServer.is_touchscreen_available() else Input.MOUSE_MODE_CAPTURED)

func _on_drift_reward_earned(credits: int, score: int) -> void:
	# Authority uses GameState's existing reward ledger, with a per-chain cap.
	if credits < 1 or credits > 55 or score < 45: return
	if int(GameState.data["wallet"])+credits > 30000000: return
	GameState.add_reward(credits,"horizon_drift")
	hud.announce(_three("ДРИФТ · %d очков · +%d кр." % [score,credits],"DRIFT · %d points · +%d credits" % [score,credits],"漂移 · %d 分 · +%d" % [score,credits]))

func _sync_positions_from_state() -> void:
	var p: Array = GameState.data["player_position"]
	var v: Array = GameState.data["vehicle_position"]
	player.global_position = Vector3(float(p[0]),float(p[1]),float(p[2]))
	car.global_position = Vector3(float(v[0]),float(v[1]),float(v[2]))
	car.rotation.y = float(GameState.data.get("vehicle_heading",0.0))
	car.fuel = float(GameState.data.get("vehicle_fuel",100.0))
	car.health = float(GameState.data.get("vehicle_health",100.0))
	previous_vehicle_health = car.health
	speeding_seconds = 0.0
	near_miss_sample = 0.0
	if patrols != null: patrols.reset_patrols()
	car.mileage = float(GameState.data.get("vehicle_mileage",0.0))
	car.apply_variant(str(GameState.data.get("vehicle_selected","compact")))
	if cargo_visual != null: cargo_visual.sync_state(GameState.data,GameState.locale)
	_update_cargo_physics()
	interiors.active_kind = str(GameState.data.get("interior",""))
	var return_point: Array = GameState.data.get("interior_return",GameState.DEFAULT_POSITION)
	interiors.exit_return = Vector3(float(return_point[0]),float(return_point[1]),float(return_point[2]))
	if driving:
		driving = false
		car.driving = false
		car.speed = 0.0
		player.visible = true
		player.active = true
		player.set_physics_process(true)

func _sync_trial_marker() -> void:
	if trial_marker == null: return
	var active: Dictionary = GameState.data.get("driving_trial",{})
	if active.is_empty():
		trial_marker.visible = false
	else:
		trial_marker.show_at(GameState.TRIALS.target(GameState.data))

func _start_driving_trial() -> void:
	if interiors.is_inside():
		hud.announce(_three("Вернитесь на улицу", "Return outdoors", "请返回室外"))
		return
	var answer: String = GameState.start_driving_trial(car.global_position,car.speed,car.mileage,car.health,driving)
	match answer:
		"started": hud.announce(_three("Автошкола: следуйте через ворота", "Driving academy: follow the gates", "驾驶学院：通过赛道检查点"))
		"busy": hud.announce(_three("Сначала завершите текущий заказ", "Finish your active job first", "请先完成现有任务"))
		"wanted": hud.announce(_three("Сначала снимите розыск", "Clear your wanted level first", "请先解除通缉"))
		"funds": hud.announce(_three("Нужны 35 игровых рублей", "Entry fee is 35 game rubles", "报名需要35游戏卢布"))
		_: hud.announce(_three("T: в машине у дворца, стоя на месте", "T: parked in your car near City Hall", "T：将车停在市政厅附近"))

func _tick_driving_trial(delta: float) -> void:
	if GameState.data.get("driving_trial",{}).is_empty(): return
	if hud.is_strategy_open() or hud.is_pause_open(): return
	var result: Dictionary = GameState.tick_driving_trial(delta,car.global_position,car.mileage,car.health,driving)
	match str(result.get("status","idle")):
		"checkpoint": hud.announce(_three("Контрольная точка пройдена", "Checkpoint cleared", "已通过检查点"))
		"completed":
			hud.announce(_three("Маршрут завершён!", "Driving trial completed!", "驾考完成！") + " +%d" % int(result.get("reward",0)))
			if soundscape != null: soundscape.play_success()
		"expired": hud.announce(_three("Время испытания истекло", "Driving trial time expired", "考核时间已结束"))
		"failed": hud.announce(_three("Испытание прервано", "Driving trial failed", "考核未完成"))

func _update_cargo_physics() -> void:
	if car == null: return
	var current: Dictionary = GameState.data.get("active_contract",{})
	var weight: int = clampi(int(current.get("quantity",0)),0,100)
	car.cargo_speed_factor = maxf(0.75,1.0-float(weight)*0.004)
	car.cargo_fuel_factor = 1.0+float(weight)*0.006

func _save_positions() -> void:
	var p: Vector3 = player.global_position
	var v: Vector3 = car.global_position
	GameState.data["player_position"] = [p.x,p.y,p.z]
	GameState.data["vehicle_position"] = [v.x,v.y,v.z]
	GameState.data["vehicle_heading"] = car.rotation.y
	GameState.sync_vehicle_live(car.fuel,car.health,car.mileage)
	GameState.data["interior"] = interiors.active_kind
	var return_point: Vector3 = interiors.exit_return
	GameState.data["interior_return"] = [return_point.x,return_point.y,return_point.z]

func _save() -> void:
	_save_positions()
	if GameState.save_game(): hud.announce(hud.t("saved"))
	else: hud.announce(hud.t("save_failed"))

func _load() -> void:
	if not GameState.load_game():
		hud.announce(hud.t("load_failed"))
	elif GameState.last_load_source == "backup" or GameState.last_load_source == "staged":
		hud.announce(hud.t("save_recovered"))
	else:
		hud.announce(hud.t("loaded"))

func _new_game() -> void:
	GameState.reset_game()
	_save()

func _road_loop(i: int) -> Array[Vector3]:
	var px: float = float(-156 + (i % 5) * 52)
	var pz: float = float(-156 + int(i / 5) * 52)
	var lane: float = 2.0 if i % 2 == 0 else -2.0
	var corners: Array[Vector3] = [
		Vector3(px+lane,0.8,pz+lane),Vector3(px+52+lane,0.8,pz+lane),
		Vector3(px+52+lane,0.8,pz+52+lane),Vector3(px+lane,0.8,pz+52+lane)
	]
	var loop: Array[Vector3] = []
	for k in range(corners.size()):
		var segment: Array[Vector3] = ROUTER.find_route(corners[k],corners[(k+1)%corners.size()],GameState.data)
		if segment.size() < 2: continue
		if not loop.is_empty(): segment.remove_at(0)
		loop.append_array(segment)
	return loop

func _replan_traffic() -> void:
	for i in range(ambient_cars.size()):
		var traffic = ambient_cars[i]
		var route: Array[Vector3] = _road_loop(i)
		if route.size() < 2: continue
		# Keep the physical position so changing city policy never teleports a car.
		route.insert(0,traffic.global_position)
		traffic.points = route
		traffic.target_index = 1
	for citizen in pedestrians:
		citizen.activity = "" # Invalidate cached commute after road changes.

func _spawn_traffic() -> void:
	for i in range(12):
		var route: Array[Vector3] = _road_loop(i)
		var traffic = TRAFFIC_SCENE.new()
		add_child(traffic)
		traffic.set_route(route,6.5+float(i%4)*2.0)
		traffic.signal_controller = traffic_signals
		traffic.wetness = float(GameState.current_weather()["road_grip"])
		ambient_cars.append(traffic)

func _spawn_citizens() -> void:
	for i in range(34):
		var ix: int = i % 8
		var iz: int = i / 8
		var x := -182.0+ix*52.0+float(i%3)*5.0
		var z := -182.0+iz*52.0
		var citizen = PEDESTRIAN_SCENE.new()
		citizen.position = Vector3(x,0,z)
		citizen.citizen_id = i
		citizen.traffic_vehicles = ambient_cars
		citizen.player_car = car
		add_child(citizen)
		pedestrians.append(citizen)
	for traffic in ambient_cars:
		traffic.citizens = pedestrians

func _stopped_traffic_count() -> int:
	var stopped := 0
	for traffic in ambient_cars:
		if traffic.speed < 0.35 and traffic.visible:
			stopped += 1
	return stopped

func _physics_process(delta: float) -> void:
	if player == null or car == null or camera == null: return
	if touch_controls != null and hud != null:
		var blocked: bool = hud.is_pause_open() or hud.is_strategy_open() or hud.is_citizen_open() or hud.is_city_case_open() or interiors.is_inside()
		touch_controls.set_mode(driving,blocked)
	var focus: Vector3 = car.global_position+Vector3(0,2.0,0) if driving else player.global_position+Vector3(0,2.3,0)
	if driving and (Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED or DisplayServer.is_touchscreen_available()):
		cam_yaw = lerp_angle(cam_yaw,car.rotation.y,clampf(delta*0.35,0.0,1.0))
	var pads: Array[int] = Input.get_connected_joypads()
	if not pads.is_empty() and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var joystick_x: float = Input.get_joy_axis(pads[0],JOY_AXIS_RIGHT_X)
		var joystick_y: float = Input.get_joy_axis(pads[0],JOY_AXIS_RIGHT_Y)
		if absf(joystick_x) > 0.18: cam_yaw -= joystick_x * delta * 2.3
		if absf(joystick_y) > 0.18: cam_pitch = clampf(cam_pitch - joystick_y * delta * 1.6,0.08,1.18)
	player.camera_heading = cam_yaw
	var distance: float = (12.0 + minf(absf(car.speed)*0.12,3.4)) if driving else 7.2
	var ideal := focus + Vector3(sin(cam_yaw)*cos(cam_pitch)*distance,sin(cam_pitch)*distance+1.0,cos(cam_yaw)*cos(cam_pitch)*distance)
	var query := PhysicsRayQueryParameters3D.create(focus,ideal)
	query.exclude = [player.get_rid(),car.get_rid()]
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		ideal = result["position"] + (focus-ideal).normalized()*0.5
	camera.global_position = ideal if GameSettings.reduced_motion else camera.global_position.lerp(ideal,clampf(delta*8.0,0.0,1.0))
	camera.look_at(focus,Vector3.UP)
	# Speed-responsive perspective, disabled for players who request less motion.
	var desired_fov: float = (79.0 + minf(absf(car.speed)*0.27,9.0)) if driving else 76.0
	camera.fov = desired_fov if GameSettings.reduced_motion else lerpf(camera.fov,desired_fov,clampf(delta*2.2,0.0,1.0))
	var protagonist: Vector3 = car.global_position if driving else player.global_position
	_tick_driving_trial(delta)
	if world.weather_particles != null:
		world.weather_particles.global_position = protagonist + Vector3(0,16,0)
	var nearest: String = world.closest_location(protagonist,27.0) if not interiors.is_inside() else ""
	var near_name := str(world.locations[nearest]["name"]) if nearest != "" else ""
	if not driving and not interiors.is_inside() and _closest_citizen(protagonist,8.0) >= 0:
		near_name = "J: ЖИТЕЛЬ" if GameState.locale == "ru" else ("J: CITIZEN" if GameState.locale == "en" else "J: 居民")
	if interiors.is_inside():
		near_name = interiors.room_title(interiors.active_kind,GameState.locale)
	elif near_name == "" and not driving:
		var building_id: String = world.closest_interior(protagonist,16.0)
		if building_id != "": near_name = "I: " + interiors.room_title(building_id,GameState.locale)
	if near_name == "" and not driving and roadworks != null:
		var hazard_id: String = roadworks.closest_hazard(protagonist,9.0)
		if hazard_id != "":
			var site: Dictionary = MOBILITY.incident_by_id(hazard_id)
			near_name = "⚠ " + str(site.get(GameState.locale,site.get("ru",hazard_id)))
	if near_name == "" and not driving and not interiors.is_inside():
		var site_id: String = GameState.DISCOVERY.nearest_unvisited(GameState.data,protagonist,10.0)
		if site_id != "":
			var site: Dictionary = GameState.DISCOVERY.find_site(site_id)
			near_name = "◈ " + GameState.DISCOVERY.title(site,GameState.locale)
	if near_name == "":
		var property_id: String = world.closest_property(protagonist,20.0)
		if property_id != "":
			near_name = str(GameState.REAL_ESTATE.PROPERTIES[property_id]["name"].get(GameState.locale,"Property"))
	var goal: Vector3 = world.objective_position()
	world.update_waypoint(goal)
	lod_timer += delta
	diagnostic_timer += delta
	if diagnostic_timer >= 1.0:
		diagnostic_timer = 0.0
		if cargo_visual != null: cargo_visual.sync_state(GameState.data,GameState.locale)
		if hud != null:
			hud.update_diagnostics(Engine.get_frames_per_second(),world.active_chunk_count,world.building_chunks.size(),pedestrians.size(),ambient_cars.size(),_stopped_traffic_count())
	if lod_timer >= 1.1:
		lod_timer = 0.0
		_update_agent_lod(protagonist)
	route_refresh += delta
	if not interiors.is_inside() and (route_refresh >= 1.25 or last_route_goal.distance_to(goal) > 2.0):
		route_refresh = 0.0
		last_route_goal = goal
		if hud.map != null:
			hud.map.route = ROUTER.find_route(protagonist,goal,GameState.data)
	if hud.map != null:
		if patrols != null: hud.map.police_world = patrols.visible_positions()
		var case_site: String = GameState.CITY_CASES.site(GameState.data)
		hud.map.case_active = case_site != "" and world.locations.has(case_site)
		if hud.map.case_active: hud.map.case_world = world.locations[case_site]["position"]
	if Engine.get_physics_frames() % 3 == 0:
		hud.update_world_context(protagonist,car.global_position,goal,driving,car.speed,car.fuel,near_name,car.health,car.handbrake_on,car.gear_label(),roundi(car.drift_chain_score),car.power_assist_reduction,car.steering_assist_correction)
	# Patrols use shared physical roads and do not warp while pursuing the player.
	if patrols != null:
		var heat: int = int(GameState.data.get("law",{}).get("heat",0))
		patrols.tick(protagonist,GameState.data,heat,delta,float(GameState.current_weather()["road_grip"]))
		var close: bool = patrols.closest_distance(protagonist)<42.0
		GameState.tick_city_law(delta,close)
		police_capture_cooldown = maxf(0.0,police_capture_cooldown-delta)
		if heat>0 and police_capture_cooldown<=0.0 and patrols.closest_distance(protagonist)<10.0 and (not driving or absf(car.speed)<1.0):
			if GameState.resolve_traffic_fines(true):
				police_capture_cooldown = 12.0
				hud.announce(_three("Патруль остановил вас · штраф начислен","Stopped by patrol · citation issued","巡逻队拦截 · 已开罚单"))
	if driving:
		if car.health<previous_vehicle_health-3.0:
			if GameState.register_traffic_offence("collision"):
				hud.announce(_three("Опасное ДТП · объявлен розыск","Serious collision · wanted","严重碰撞 · 已通缉"))
		if absf(car.speed)>25.0:
			speeding_seconds += delta
		else:
			speeding_seconds = maxf(0.0,speeding_seconds-delta*2.0)
		if speeding_seconds>=4.0:
			if GameState.register_traffic_offence("speeding"):
				hud.announce(_three("Превышение скорости · объявлен розыск","Speeding · wanted","超速 · 已通缉"))
			speeding_seconds = 0.0
		# Protect nearby citizens without assigning heavy physics bodies to 34 walkers.
		near_miss_sample += delta
		if near_miss_sample>=0.8:
			near_miss_sample = 0.0
			if absf(car.speed)>17.0:
				var ahead: Vector3 = Vector3(-sin(car.rotation.y),0,-cos(car.rotation.y))
				for citizen in pedestrians:
					if not citizen.visible: continue
					var separation: Vector3 = citizen.global_position-car.global_position
					separation.y = 0.0
					var longitudinal: float = separation.dot(ahead)
					if longitudinal>0.0 and longitudinal<6.0 and (separation-ahead*longitudinal).length()<2.0:
						if GameState.register_traffic_offence("reckless"):
							hud.announce(_three("Опасное вождение рядом с жителями","Reckless driving near pedestrians","靠近行人危险驾驶"))
						break
	else:
		speeding_seconds = 0.0
		near_miss_sample = 0.0
	previous_vehicle_health = car.health
	GameState.sync_vehicle_live(car.fuel,car.health,car.mileage,driving)
	if soundscape != null: soundscape.update_cues(driving,car.speed,current_weather_kind,int(GameState.data.get("law",{}).get("heat",0)))
	GameState.data["day_clock"] = fposmod(float(GameState.data["day_clock"])+delta*0.012,24.0)
	world.update_daynight(float(GameState.data["day_clock"]))
	autosave_accumulator += delta
	if autosave_accumulator > 60.0:
		autosave_accumulator = 0.0
		_save_positions()
		if not GameState.save_game():
			hud.announce(hud.t("autosave_failed"))

func _input(event: InputEvent) -> void:
	if hud == null or hud.is_pause_open() or hud.is_citizen_open() or hud.is_city_case_open():
		return
	if event is InputEventMouseMotion:
		var movement := event as InputEventMouseMotion
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			cam_yaw -= movement.relative.x * GameSettings.mouse_sensitivity
			cam_pitch = clampf(cam_pitch-movement.relative.y * GameSettings.mouse_sensitivity,0.08,1.18)
		return
	if event is InputEventKey and (event as InputEventKey).echo: return
	if event.is_action_pressed("governor"):
		if not GameState.data.get("driving_trial",{}).is_empty():
			hud.announce(_three("Завершите маршрут перед управлением городом", "Complete the trial before governance", "完成驾考后再管理城市"))
			return
		hud.toggle_strategy()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("field_journal") and not hud.is_strategy_open():
		hud.toggle_field_journal()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("language"):
		hud.switch_language()
		world.update_language(GameState.locale)
	elif event.is_action_pressed("save_game"):
		_save()
	elif event.is_action_pressed("load_game"):
		_load()
	elif event.is_action_pressed("advance_turn") and hud.is_strategy_open():
		if GameState.advance_turn():
			MissionManager.register_action("advance_turn")
	elif event.is_action_pressed("drive_trial") and not hud.is_strategy_open():
		_start_driving_trial()
	elif event.is_action_pressed("enter_vehicle") and not hud.is_strategy_open():
		_enter_or_exit_vehicle()
	elif event.is_action_pressed("interact") and not hud.is_strategy_open():
		_interact()
	elif event.is_action_pressed("talk_citizen") and not hud.is_strategy_open():
		_talk_to_citizen()
	elif event.is_action_pressed("city_case") and not hud.is_strategy_open():
		_interact_city_case()
	elif event.is_action_pressed("dispatch_service") and not hud.is_strategy_open():
		_accept_public_service()
	elif event.is_action_pressed("buy_business") and not hud.is_strategy_open():
		_buy_market()
	elif event.is_action_pressed("enter_interior") and not hud.is_strategy_open():
		_toggle_interior()
	elif event.is_action_pressed("diagnostics"):
		hud.toggle_diagnostics()
	elif event.is_action_pressed("pay_traffic_fines"):
		_pay_traffic_fines()
	elif event.is_action_pressed("show_map"):
		if hud.map != null: hud.map.visible = not hud.map.visible

func _pay_traffic_fines() -> void:
	if driving or interiors.is_inside() or player.global_position.distance_to(world.locations["cityhall"]["position"])>35.0:
		hud.announce(_three("Для оплаты штрафа: P пешком у мэрии","To pay fines: P on foot at City Hall","缴纳罚款：市政厅步行按 P"))
		return
	if GameState.resolve_traffic_fines(false):
		hud.announce(_three("Штраф уплачен · розыск снят","Fine paid · wanted level cleared","罚款已缴 · 通缉解除"))
	else:
		hud.announce(_three("Недостаточно средств или штрафов нет","Insufficient funds or no fines","资金不足或无罚款"))

func _apply_weather() -> void:
	if world == null or car == null:
		return
	var conditions: Dictionary = GameState.current_weather()
	current_weather_kind = str(conditions["kind"])
	world.update_weather(current_weather_kind)
	car.traction_factor = float(conditions["road_grip"])
	for traffic in ambient_cars:
		traffic.wetness = float(conditions["road_grip"])

func _apply_preferences() -> void:
	if world == null: return
	world.sun.shadow_enabled = GameSettings.graphics != "low"
	world.update_language(GameState.locale)
	if city_case_marker != null: city_case_marker.sync_state(GameState.data)
	if discovery_markers != null: discovery_markers.sync_state(GameState.data)
	if world.facade_windows != null:
		world.facade_windows.visible = GameSettings.graphics != "low"
	var at: Vector3 = car.global_position if driving else player.global_position
	_update_agent_lod(at)

func _update_agent_lod(player_at: Vector3) -> void:
	if world != null and not interiors.is_inside():
		world.update_chunks(player_at,GameSettings.graphics)
	var distance_limit: float = 75.0 if GameSettings.graphics == "low" else (150.0 if GameSettings.graphics == "standard" else 240.0)
	for person in pedestrians:
		var active: bool = person.global_position.distance_squared_to(player_at) < distance_limit * distance_limit
		person.visible = active
		person.set_process(active)
	for traffic in ambient_cars:
		var active: bool = traffic.global_position.distance_squared_to(player_at) < (distance_limit + 50.0) * (distance_limit + 50.0)
		traffic.visible = active
		traffic.set_physics_process(active)

func _safe_vehicle_exit() -> Variant:
	var side: Vector3 = car.global_transform.basis.x
	var rear: Vector3 = car.global_transform.basis.z
	var collider := CapsuleShape3D.new()
	collider.height = 1.8
	collider.radius = 0.43
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider
	query.exclude = [car.get_rid(),player.get_rid()]
	query.collision_mask = 1 | 8
	for offset in [side*3.3,-side*3.3,rear*4.0,-rear*4.0]:
		var position_at: Vector3 = car.global_position + offset + Vector3(0,0.2,0)
		query.transform = Transform3D(Basis(),position_at)
		if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
			return position_at
	return null

func _enter_or_exit_vehicle() -> void:
	if not driving:
		if player.global_position.distance_to(car.global_position) > 8.0:
			hud.announce(hud.t("too_far"))
			return
		driving = true
		car.driving = true
		player.visible = false
		player.active = false
		player.set_physics_process(false)
		MissionManager.register_action("enter_vehicle")
	else:
		if absf(car.speed) > 3.0:
			hud.announce("Снизьте скорость перед выходом" if GameState.locale == "ru" else "Stop the car first")
			return
		var safe_exit: Variant = _safe_vehicle_exit()
		if safe_exit == null:
			hud.announce(_three("Нет безопасного места для выхода", "No safe space to exit", "没有安全的下车位置"))
			return
		driving = false
		car.driving = false
		player.global_position = safe_exit
		player.visible = true
		player.active = true
		player.set_physics_process(true)

func _closest_citizen(point: Vector3, distance: float) -> int:
	var nearest := -1
	var best: float = distance * distance
	for citizen in pedestrians:
		if citizen == null or not citizen.visible:
			continue
		var distance_sq: float = citizen.global_position.distance_squared_to(point)
		if distance_sq < best:
			best = distance_sq
			nearest = int(citizen.citizen_id)
	return nearest

func _talk_to_citizen() -> void:
	if driving or interiors.is_inside():
		hud.announce(_three("Поговорить можно только пешком на улице","Talk to people on foot outdoors","请下车到室外与居民交谈"))
		return
	var citizen_id: int = _closest_citizen(player.global_position,8.0)
	if citizen_id >= 0:
		hud.show_citizen(citizen_id,world.district_id(player.global_position))
	else:
		hud.announce(_three("Подойдите ближе к жителю","Move closer to a resident","请靠近居民"))

func _toggle_interior() -> void:
	if interiors.is_inside():
		if not interiors.at_exit(player.global_position):
			hud.announce(_three("Подойдите к выходу","Go to the exit","请走到出口"))
			return
		interiors.leave(player)
		GameState.data["interior"] = ""
		hud.announce(_three("Вы вернулись на улицу","Returned to the street","已返回街道"))
	else:
		if driving:
			hud.announce(_three("Сначала выйдите из машины","Leave the car first","请先下车"))
			return
		var nearest: String = world.closest_interior(player.global_position,27.0)
		if nearest == "" or not interiors.enter(nearest,player):
			hud.announce(hud.t("too_far"))
			return
		GameState.data["interior"] = nearest
		var return_point: Vector3 = interiors.exit_return
		GameState.data["interior_return"] = [return_point.x,return_point.y,return_point.z]
		MissionManager.register_action("interior_enter")
		hud.announce(_three("Внутри здания · I у выхода · F у стойки","Inside · I at exit · F at desk","室内 · 出口按 I · 前台按 F"))
	camera.global_position = player.global_position + Vector3(0,5,8)
	if hud.map != null:
		hud.map.visible = not interiors.is_inside()

func _three(ru: String, en: String, zh: String) -> String:
	return ru if GameState.locale == "ru" else (en if GameState.locale == "en" else zh)

func _interact() -> void:
	if interiors.is_inside():
		if interiors.at_exit(player.global_position):
			_toggle_interior()
		elif interiors.at_service_desk(player.global_position):
			if not hud.is_strategy_open():
				hud.toggle_strategy()
		else:
			hud.announce(_three("Подойдите к стойке или выходу","Go to the desk or exit","请前往前台或出口"))
		return
	var position_at: Vector3 = car.global_position if driving else player.global_position
	# Service destinations take precedence over property and trading interactions.
	var service: Dictionary = GameState.data.get("service_active",{})
	if not service.is_empty():
		var service_destination: String = str(service["destination"])
		if world.locations.has(service_destination) and position_at.distance_to(world.locations[service_destination]["position"]) < 28.0:
			var service_result: String = GameState.finish_service(service_destination,driving,car.speed)
			if service_result == "completed": MissionManager.register_action("service_complete")
			hud.announce(GameState.SERVICE.status_message(service_result,GameState.locale))
			return
	if not driving and roadworks != null:
		var blocked_id: String = roadworks.closest_hazard(position_at,9.0)
		if blocked_id != "":
			if GameState.repair_road(blocked_id):
				MissionManager.register_action("road_repair")
				hud.announce(_three("Дорога восстановлена: −120 ₽, −6 материалов","Road restored: −120 ₽, −6 materials","道路修复：−120 ₽，−6 材料"))
			else:
				hud.announce(hud.t("need"))
			return
	# The active errand has priority over property kiosks at a loading bay.
	var local_goal: String = GameState.NEIGHBORHOOD.goal_location(GameState.data)
	if local_goal != "" and world.closest_location(position_at,29.0) == local_goal:
		var local_outcome: String = GameState.neighborhood_interact(local_goal,car.global_position.distance_to(world.locations[local_goal]["position"]) < 35.0,driving,car.speed)
		if local_outcome == "completed": MissionManager.register_action("neighborhood_deliver")
		hud.announce(GameState.NEIGHBORHOOD.status_text(local_outcome,GameState.locale))
		return
	# Distinct street discoveries create an on-foot exploration loop. Every
	# reward is awarded once by GameState, never by a visual marker.
	if not driving and not interiors.is_inside():
		var site_id: String = GameState.DISCOVERY.nearest_unvisited(GameState.data,position_at,8.0)
		if site_id != "":
			var site: Dictionary = GameState.DISCOVERY.find_site(site_id)
			var outcome: Dictionary = GameState.explore_site(site_id,position_at,driving,false)
			if str(outcome.get("status","")) == "discovered":
				var name_text: String = GameState.DISCOVERY.title(site,GameState.locale)
				hud.announce(_three("Открыто: ","Discovered: ","发现：")+name_text+"  +%d ₽" % int(outcome["reward"]))
				if soundscape != null: soundscape.play_success()
			else:
				hud.announce(hud.t("need"))
			return
	var property_id: String = world.closest_property(position_at,18.0)
	if property_id != "":
		var owned_level: int = int(GameState.data["properties"].get(property_id,0))
		var success: bool = GameState.buy_property(property_id) if owned_level == 0 else GameState.renovate_property(property_id)
		if success:
			MissionManager.register_action("property" if owned_level == 0 else "renovation")
			hud.announce(hud.t("success"))
		else:
			hud.announce(hud.t("need"))
		return
	var nearest: String = world.closest_location(position_at,29.0)
	if nearest == "":
		if not driving:
			var nearby_citizen: int = _closest_citizen(position_at,4.0)
			if nearby_citizen >= 0:
				hud.show_citizen(nearby_citizen,world.district_id(position_at))
				return
		hud.announce(hud.t("too_far"))
		return
	GameState.set_district(str(world.locations[nearest]["district"]))
	if nearest == "market" and MissionManager.register_action("deliver"):
		GameState.data["deliveries"] += 1
		hud.announce(hud.t("completed"))
		return
	var offered: Dictionary = ContractManager.current_offer()
	if ContractManager.active_contract().is_empty() and str(offered.get("pickup","")) == nearest:
		if car.global_position.distance_to(world.locations[nearest]["position"]) > 35.0:
			hud.announce(_three("Припаркуйте машину рядом с местом погрузки", "Bring your vehicle to the loading bay", "请把车停在装货点附近"))
			return
	var contract_result: String = ContractManager.interact(nearest,driving,car.speed)
	if contract_result == "accepted":
		MissionManager.register_action("contract_accept")
		hud.announce(hud.t("accepted"))
		return
	if contract_result == "completed":
		MissionManager.register_action("contract_deliver")
		hud.announce(hud.t("completed"))
		return
	if contract_result == "vehicle_required":
		hud.announce(_three("Доставьте груз на той машине, где он был принят", "Use the car assigned when the cargo was loaded", "请使用装货时的车辆送货"))
		return
	if contract_result == "stop_vehicle":
		hud.announce(_three("Полностью остановите автомобиль для разгрузки", "Stop the vehicle before unloading", "卸货前请停车"))
		return
	if contract_result == "travel_more":
		hud.announce(_three("Груз ещё не перевезён: следуйте дорожным маршрутом", "Cargo not transported yet: drive your route", "尚未完成运输里程，请沿路线行驶"))
		return
	if nearest == "depot" and (not driving or absf(car.speed) < 1.5):
		GameState.data["vehicle_health"] = car.health
		GameState.data["vehicle_fuel"] = car.fuel
		if car.health < 65.0:
			if GameState.repair_vehicle():
				car.health = 100.0
				hud.announce(hud.t("repaired"))
			else:
				hud.announce(hud.t("repair_hint") % GameState.repair_cost())
		elif GameState.refuel_vehicle():
			car.fuel = 100.0
			hud.announce(hud.t("refueled"))
		else:
			hud.announce(hud.t("refuel_hint"))
	elif nearest == "cityhall":
		if not hud.is_strategy_open(): hud.toggle_strategy()
	elif nearest == "market":
		hud.announce(hud.t("market_hint"))
	else:
		hud.announce(str(world.locations[nearest]["name"]))

func _accept_public_service() -> void:
	# The dispatch desk exists at City Hall. The car must be parked nearby.
	if interiors.is_inside() or absf(car.speed) > 1.5 or car.global_position.distance_to(world.locations["cityhall"]["position"]) > 33.0:
		hud.announce(GameState.SERVICE.status_message("location",GameState.locale))
		return
	var result: String = GameState.accept_service()
	if result == "accepted": MissionManager.register_action("service_accept")
	hud.announce(GameState.SERVICE.status_message(result,GameState.locale))

func _interact_city_case() -> void:
	if driving or interiors.is_inside():
		hud.announce(_three("Сначала выйдите на улицу", "Return to the street on foot", "请先步行到街道"))
		return
	var site_id: String = GameState.CITY_CASES.site(GameState.data)
	if site_id == "" or not world.locations.has(site_id):
		return
	var site_at: Vector3 = world.locations[site_id]["position"]
	if player.global_position.distance_to(site_at) > 35.0:
		hud.announce(hud.t("too_far"))
		return
	hud.show_city_case()

func _buy_market() -> void:
	var point: Vector3 = car.global_position if driving else player.global_position
	if world.closest_location(point,29.0) != "market":
		hud.announce(hud.t("too_far"))
		return
	if GameState.buy_business("market_stall"):
		MissionManager.register_action("business")
		hud.announce(hud.t("bought"))
	else:
		hud.announce(hud.t("need"))

func _on_dialogue_changed(is_open: bool) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if is_open else Input.MOUSE_MODE_CAPTURED)
	player.active = not is_open and not driving and not hud.is_strategy_open()
	car.driving = not is_open and driving and not hud.is_strategy_open()

func _on_strategy_changed(enabled: bool) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if enabled else Input.MOUSE_MODE_CAPTURED)
	player.active = not enabled and not driving
	car.driving = not enabled and driving

func _on_game_changed(reason: String) -> void:
	_sync_trial_marker()
	if reason == "load" or reason == "migrated" or reason == "reset":
		_sync_positions_from_state()
		if hud.map != null:
			hud.map.visible = not interiors.is_inside()
	elif reason == "garage":
		previous_vehicle_health = float(GameState.data["vehicle_health"])
		# Cosmetic/profile changes never grant free repairs or fuel.
		car.apply_variant(str(GameState.data.get("vehicle_selected","compact")))
		car.fuel = float(GameState.data["vehicle_fuel"])
		car.health = float(GameState.data["vehicle_health"])
		car.mileage = float(GameState.data["vehicle_mileage"])
	elif reason == "refuel" or reason == "vehicle_repair":
		previous_vehicle_health = float(GameState.data["vehicle_health"])
		car.fuel = float(GameState.data["vehicle_fuel"])
		car.health = float(GameState.data["vehicle_health"])
	world.update_development()
	if city_case_marker != null: city_case_marker.sync_state(GameState.data)
	if discovery_markers != null: discovery_markers.sync_state(GameState.data)
	if cargo_visual != null: cargo_visual.sync_state(GameState.data,GameState.locale)
	_update_cargo_physics()
	if roadworks != null: roadworks.sync_state(GameState.data)
	if reason == "road_repair" or reason == "road_maintenance" or reason == "turn" or reason == "load" or reason == "reset":
		_replan_traffic()
		route_refresh = 100.0
	landmarks.sync_projects(GameState.data.get("projects_done",[]))
	landmarks.update_language(GameState.locale)
	world.update_language(GameState.locale)
	_apply_weather()

func _on_alert(message: String) -> void:
	if str(GameState.data["incident"]) != "":
		var id: String = str(GameState.data["incident"])
		hud.announce(hud.t("crisis") + ": " + hud.incident_name(id))
	else:
		hud.announce(message)

func _on_contract_changed(_message_id: String) -> void:
	world.update_waypoint(world.objective_position())

func _on_mission_done(_stage: int, reward: int) -> void:
	if soundscape != null: soundscape.play_success()
	hud.announce("ЗАДАНИЕ ВЫПОЛНЕНО · +%d ₽" % reward if GameState.locale == "ru" else "MISSION COMPLETE · +%d ₽" % reward)
