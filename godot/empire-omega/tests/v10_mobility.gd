extends SceneTree
## Must be executed with the real Godot 4 runtime. Portable tests cannot replace it.
const MOBILITY = preload("res://scripts/city_mobility.gd")
const ROADWORKS = preload("res://scripts/roadworks_visual.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _ok(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("ROAD OK: "+label)
	else:
		push_error("ROAD FAILED: "+label)
		failures += 1

func _run() -> void:
	var sim: Variant = root.get_node_or_null("GameState")
	if sim == null:
		push_error("GameState autoload is missing")
		quit(2)
		return
	sim.data = sim.new_game()
	var data: Dictionary = sim.data
	_ok(sim._valid_state(data),"new game road state valid")
	_ok(int(data["road_quality"]) == 75,"road health initialized")
	_ok(MOBILITY.catalog().get("incidents",[]).size() == 12,"12 incidents loaded from JSON")
	var incident: Dictionary = MOBILITY.active_incidents(data)[0]
	var id: String = str(incident["id"])
	var a: Array = incident["a"]
	var b: Array = incident["b"]
	var start: Vector3 = Vector3(-208.0+float(a[0])*52.0,0.8,-208.0+float(a[1])*52.0)
	var end: Vector3 = Vector3(-208.0+float(b[0])*52.0,0.8,-208.0+float(b[1])*52.0)
	var blocked: Array[Vector3] = MOBILITY.find_route(start,end,data)
	_ok(blocked.size() > 2,"closed street is rerouted")
	var detour: float = MOBILITY.length(blocked)
	_ok(detour > 110.0,"detour is longer than closed edge")
	var treasury: int = int(data["treasury"])
	var materials: int = int(data["inventories"]["materials"])
	var wallet: int = int(data["wallet"])
	var freight_before: float = MOBILITY.freight_efficiency(data)
	_ok(sim.repair_road(id),"first repair allowed")
	_ok(int(data["treasury"]) == treasury-120,"cash deducted from treasury")
	_ok(int(data["inventories"]["materials"]) == materials-6,"materials deducted")
	_ok(int(data["wallet"]) == wallet,"private wallet unaffected")
	_ok(not sim.repair_road(id),"cannot collect repair twice")
	_ok(MOBILITY.freight_efficiency(data) > freight_before,"repair improves logistics")
	var fixed: Array[Vector3] = MOBILITY.find_route(start,end,data)
	_ok(MOBILITY.length(fixed) + 1.0 < detour,"repaired edge shortens route")
	_ok(sim.maintain_roads(),"preventive repair available")
	_ok(int(data["road_quality"]) == 92,"infrastructure health updated")
	_ok(not sim.maintain_roads(),"no extra free actions")
	_ok(sim._valid_state(data),"modified state validates")
	var json_state: Variant = JSON.parse_string(JSON.stringify(sim._save_state_payload()))
	_ok(json_state is Dictionary and sim._valid_state(json_state["state"]),"roundtrip road data valid")
	var malformed: Dictionary = data.duplicate(true)
	malformed["roads_cleared"] = ["made_up_edge"]
	_ok(not sim._valid_state(malformed),"unknown repairs rejected")
	malformed["roads_cleared"] = [id,id]
	_ok(not sim._valid_state(malformed),"repeated repairs rejected")
	# Complete turn should remove the transient traffic block clearing record.
	_ok(sim.advance_turn(),"economic turn advances")
	_ok(data["roads_cleared"].is_empty(),"repair expires after turn")
	_ok(sim._valid_state(data),"post-turn road state valid")
	var visual: Node3D = ROADWORKS.new()
	root.add_child(visual)
	await process_frame
	_ok(visual.get("markers").size() == MOBILITY.active_incidents(data).size(),"visual road blocks match navigation")
	var obstacle: Variant = visual.get("markers").values()[0] if visual.get("markers").size() > 0 else null
	_ok(obstacle != null and obstacle.get_node_or_null("RoadClosureCollider") is StaticBody3D,"road closures have real physics collision")
	var sound_script: Variant = load("res://scripts/city_soundscape.gd")
	_ok(sound_script != null,"procedural soundscape script imports")
	var soundfile: Variant = load("res://assets/audio/city_air.wav")
	_ok(soundfile is AudioStream,"procedural audio is recognized by Godot")
	visual.queue_free()
	print("OSGARD NATIVE MOBILITY: %d / %d passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
