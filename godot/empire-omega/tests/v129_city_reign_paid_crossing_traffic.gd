extends SceneTree
## CITY REIGN B62: original fully financed crossing makes actual NPC slow.
## Both original traffic/pedestrian predictive safety and physical vehicle
## controllers remain, with zero new collision bodies or new save fields.
const SPEED = preload("res://scripts/city_reign_civic_traffic_safety.gd")
const AGENT = preload("res://scripts/traffic_agent.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool,why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("CITY REIGN B62 REAL FINANCED CROSSWALK TRAFFIC FAIL: "+why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim: Node = root.get_node_or_null("GameState")
	check(sim!=null,"actual Godot GameState autoload is present")
	if sim==null:
		quit(1)
		return
	var original: Dictionary = sim.get("data").duplicate(true)
	var original_locale: String = str(sim.get("locale"))
	var state: Dictionary = sim.call("new_game")
	check(SPEED.geometry_matches_installed_city(),
		"traffic safety uses same four REAL painted/reflector crossings")
	check(SPEED.PUBLIC_WORKS.CROSSINGS.size()==4,
		"only original built four crosswalk installations exist")
	var at := Vector3(104.0,0.0,-100.0)
	var forward := Vector3(0.0,0.0,1.0)
	var original_speed: float = 8.5
	check(is_equal_approx(SPEED.speed_cap(state,at,forward,original_speed,false),
			original_speed),
		"new city NEVER penalizes drivers before the public actually funds the work")
	check(is_equal_approx(SPEED.speed_cap(state,at,forward,original_speed,true),
			original_speed),
		"police/emergency services stay unimpeded by the civilian safety cap")
	check(not SPEED.funded(state),"unpaid project cannot claim built infrastructure")
	var start_state: Dictionary = state.duplicate(true)
	# Real original authoritative API, NOT test-imagined project activation.
	sim.set("data",state)
	check(bool(sim.call("start_initiative","safe_crossings")),
		"original game debits real funds/materials/goods for safer crossings")
	state = sim.get("data")
	check(not SPEED.funded(state) and
		SPEED.speed_cap(state,at,forward,original_speed,false)==original_speed,
		"an unfinished real construction site cannot slow traffic yet")
	for i in range(2):
		check(bool(sim.call("advance_turn")),
			"original city advances funded construction tick "+str(i))
	state = sim.get("data")
	check(SPEED.funded(state) and
		(state["projects_done"] as Array).has("safe_crossings"),
		"only a genuinely completed and saved project enables traffic calming")
	check(int(state["treasury"])<int(start_state["treasury"])+3000,
		"the original city treasury and project ledger, not any fake payout, owns construction")
	var cap: float = SPEED.speed_cap(state,at,forward,original_speed,false)
	check(cap>4.0 and cap<=SPEED.SPEED_LIMIT_MPS,
		"actual moving NPC slows to a realistic source-set crossing speed")
	check(SPEED.speed_cap(state,Vector3(104,0,-111),forward,
			original_speed,false) <= original_speed and
		SPEED.speed_cap(state,Vector3(104,0,-111),forward,
			original_speed,false) > SPEED.SPEED_LIMIT_MPS,
		"genuine approach ramp decelerates gradually BEFORE crossing")
	check(SPEED.speed_cap(state,Vector3(104,0,-140),-forward,
			original_speed,false)==original_speed,
		"cars moving away from completed crossing are not artificially braked")
	check(SPEED.speed_cap(state,Vector3(126,0,-100),forward,
			original_speed,false)==original_speed,
		"unrelated parallel lane is not blocked by paid safety art")
	check(SPEED.speed_cap(state,Vector3(104,0,-100),forward,
			original_speed,true)==original_speed,
		"actual patrol driving retains original emergency transit priority")
	check(SPEED.speed_cap(state,Vector3.INF,forward,
			original_speed,false)==0.0 and
		SPEED.speed_cap(state,at,Vector3.INF,original_speed,false)==0.0,
		"corrupt world coordinates fail safe to a bounded zero-speed cap")
	check(SPEED.speed_cap(state,at,forward,original_speed,false)==cap,
		"civic crossing speed policy is deterministic and state/read-only")
	# Run the TRUE original NPC physics with an actual source-car class.
	var npc: CharacterBody3D = AGENT.new()
	root.add_child(npc)
	var line: Array[Vector3] = [
		Vector3(104.0,0.8,-115.0),Vector3(104.0,0.8,-65.0)]
	npc.call("set_route",line,8.5)
	npc.global_position = Vector3(104.0,0.8,-100.0)
	npc.set("speed",5.8)
	npc.call("_physics_process",0.12)
	var funded_speed: float = float(npc.get("speed"))
	check(funded_speed<5.8,
		"REAL traffic CharacterBody3D brakes on funded civic crossing")
	var paid: Dictionary = state.duplicate(true)
	state["projects_done"] = []
	npc.global_position = Vector3(104.0,0.8,-100.0)
	npc.set("speed",5.8)
	npc.call("_physics_process",0.12)
	var unfunded_speed: float = float(npc.get("speed"))
	check(unfunded_speed>funded_speed and unfunded_speed<=8.5,
		"the SAME real NPC accelerates normally when project absent")
	state["projects_done"] = paid["projects_done"].duplicate(true)
	var source_text: String = FileAccess.get_file_as_string(
		"res://scripts/traffic_agent.gd")
	check(source_text.contains("CIVIC_CROSSING.speed_cap(") and
		source_text.contains("R47_CROSSING.clearance("),
		"real source car applies civic limit and still predicts actual pedestrians")
	check(sim.get("data")==paid,
		"no new mission/save/economy fields or passenger profits minted by traffic")
	npc.queue_free()
	await process_frame
	sim.set("data",original)
	sim.set("locale",original_locale)
	print("CITY REIGN B62 PAID ROAD SAFETY ORIGINAL NPC: %d PASS %d FAIL" %
		[passed,failed])
	quit(0 if failed==0 else 1)
