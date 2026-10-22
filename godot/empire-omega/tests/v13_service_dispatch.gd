extends SceneTree
## Godot-native acceptance of public-service mission lifecycle and old saves.
const SERVICE = preload("res://scripts/service_dispatch.gd")
var checked := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	checked += 1
	if ok:
		print("SERVICE OK: " + description)
	else:
		failed += 1
		push_error("SERVICE FAIL: " + description)

func _run() -> void:
	GameState.data = GameState.new_game()
	check(SERVICE.catalog().size() == 12,"request catalog parsed")
	var first: Dictionary = SERVICE.offer(GameState.data)
	check(not first.is_empty(),"deterministic service offered")
	check(SERVICE.required_distance(str(first["destination"])) >= 100.0,"service has a trip")
	check(GameState._valid_state(GameState.data),"new profile validates")
	check(GameState.accept_service() == "accepted","first call accepted")
	check(GameState.accept_service() == "busy","cannot accept second in parallel")
	var active: Dictionary = GameState.data["service_active"]
	check(SERVICE.valid_active(active),"active profile passes strict validation")
	check(GameState._valid_state(GameState.data),"profile with active service validates")
	check(GameState.finish_service(str(active["destination"]),false,0.0) == "wrong_vehicle","on-foot reward blocked")
	check(GameState.finish_service(str(active["destination"]),true,8.0) == "stop","moving car cannot settle")
	check(GameState.finish_service(str(active["destination"]),true,0.0) == "travel_more","teleporting cannot settle")
	GameState.data["wallet"] = 6000
	GameState.data["reputation"] = 100
	check(GameState.buy_vehicle("courier"),"second vehicle can be acquired")
	check(not GameState.select_vehicle("courier"),"cannot swap during service")
	var distance_needed: float = float(active["required"])
	var odometer := 0.0
	for i in range(ceili(distance_needed/5.0)+1):
		odometer += 5.0
		GameState.sync_vehicle_live(80.0,100.0,odometer,true)
	check(SERVICE.ready(active),"actual driving satisfies route")
	var old_wallet: int = int(GameState.data["wallet"])
	var id: String = str(active["id"])
	var outcome: String = GameState.finish_service(str(active["destination"]),true,0.0)
	check(outcome == "completed","service settles at assigned destination")
	check(int(GameState.data["wallet"]) > old_wallet,"private reward paid once")
	check(int(GameState.data["service_completed"]) == 1,"count increases once")
	check(GameState.finish_service(str(active["destination"]),true,0.0) == "not_here","duplicate settlement prevented")
	check(str(GameState.data["service_history"][0]["id"]) == id,"completion audited")
	check(GameState.accept_service() == "used","same-turn farming blocked")
	check(GameState.select_vehicle("courier"),"garage usable again")
	check(GameState._valid_state(GameState.data),"settled profile validates")
	var json_state: Variant = JSON.parse_string(JSON.stringify(GameState.data))
	check(GameState._valid_state(json_state),"new fields roundtrip via JSON")
	var damaged: Dictionary = GameState.data.duplicate(true)
	damaged["service_history"][0]["reward"] = 99999
	check(not GameState._valid_state(damaged),"corrupt reward blocked")
	GameState.data = GameState.new_game()
	check(GameState.accept_service() == "accepted","second profile dispatched")
	var due: int = int(GameState.data["service_active"]["due_turn"])
	GameState.data["turn"] = due
	check(GameState.advance_turn(),"next turn advances without unresolved crisis")
	check(GameState.data["service_active"].is_empty(),"expired service cleared")
	check(int(GameState.data["service_failed"]) == 1,"failed call recorded")
	check(str(GameState.data["service_history"][0]["result"]) == "expired","expiry included in audit")
	check(GameState._valid_state(GameState.data),"expired profile validates")
	var prior: Dictionary = GameState.new_game()
	for key in ["service_active","service_completed","service_failed","service_history","service_last_turn"]:
		prior.erase(key)
	check(GameState._valid_state(prior),"v0.12 save without service fields remains valid")
	var recovered: Dictionary = GameState._upgrade_state(prior)
	check(GameState._valid_state(recovered),"v0.12 save upgrades")
	check(recovered.has("service_active") and recovered.has("service_history"),"legacy save receives new defaults")
	print("OSGARD NATIVE SERVICE: %d / %d" % [checked-failed,checked])
	quit(0 if failed == 0 else 1)
