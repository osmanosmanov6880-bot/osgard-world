extends SceneTree
## Execute under Godot 4 headless; exercises GDScript and JSON, not a Python copy.
const CASES = preload("res://scripts/city_cases.gd")
const BEACON = preload("res://scripts/city_case_marker.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _ok(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("CITY-CASE OK: " + message)
	else:
		push_error("CITY-CASE FAILED: " + message)
		failures += 1

func _run() -> void:
	var sim: Variant = root.get_node_or_null("GameState")
	if sim == null:
		push_error("GameState autoload is missing")
		quit(2)
		return
	sim.data = sim.new_game()
	var initial: Dictionary = sim.data
	_ok(CASES.catalog().size() == 16,"all localized case templates load")
	_ok(initial["city_case"].is_empty() and initial["case_history"].is_empty(),"new save fields exist")
	_ok(sim._valid_state(initial),"default save validates")
	_ok(sim.advance_turn(),"turn two advances")
	_ok(initial["city_case"].is_empty(),"no case before turn three")
	_ok(sim.advance_turn(),"turn three advances")
	_ok(not initial["city_case"].is_empty(),"case appears by deterministic schedule")
	_ok(int(initial["city_case"]["due_turn"]) == 5,"case deadline set")
	var case: Dictionary = CASES.current(initial)
	_ok(case.has("site") and case["options"].size() == 2,"template supports two choices")
	var save_object: Variant = JSON.parse_string(JSON.stringify(initial))
	_ok(save_object is Dictionary and sim._valid_state(save_object),"JSON roundtrip preserves active case")
	var marker := BEACON.new()
	root.add_child(marker)
	await process_frame
	_ok(marker.visible and marker.inscription.text.length() > 3,"visible 3D marker attached to active district")
	var treasury: int = int(initial["treasury"])
	var wallet: int = int(initial["wallet"])
	_ok(sim.resolve_city_case("mobilize"),"public response resolves case")
	_ok(int(initial["treasury"]) == treasury,"community route never spends treasury")
	_ok(int(initial["wallet"]) < wallet,"community route spends private funds")
	_ok(not sim.resolve_city_case("mobilize"),"repeat interaction cannot duplicate rewards")
	_ok(initial["case_history"].size() == 1,"case journal recorded once")
	_ok(sim._valid_state(initial),"resolved save validates")
	var malformed: Dictionary = initial.duplicate(true)
	malformed["case_history"][0]["id"] = "unknown_case"
	_ok(not sim._valid_state(malformed),"unknown event in save rejected")
	sim.data = sim.new_game()
	var another: Dictionary = sim.data
	another["turn"] = 3
	_ok(CASES.maybe_open(another),"event can be opened in turn three")
	another["treasury"] = 0
	another["wallet"] = 0
	another["inventories"]["materials"] = 0
	another["inventories"]["goods"] = 0
	_ok(not CASES.resolve(another,"invest") and not CASES.resolve(another,"mobilize"),"no resources prevents both paths")
	_ok(not another["city_case"].is_empty(),"insufficient funds does not close the case")
	another["turn"] = 5
	_ok(CASES.expire(another) != "","expired event triggers deterministic consequences")
	_ok(CASES.expire(another) == "","expired consequences cannot be claimed twice")
	_ok(sim._valid_state(another),"expired event save validates")
	marker.queue_free()
	print("OSGARD NATIVE CITY CASES: %d / %d passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
