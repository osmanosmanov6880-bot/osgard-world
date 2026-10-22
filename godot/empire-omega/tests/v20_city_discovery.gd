extends SceneTree
## Native Godot 4 execution test; NOT passed until run with real Godot.
var passed := 0
var failed := 0
const DISCOVERY = preload("res://scripts/city_discovery.gd")
const MARKERS = preload("res://scripts/discovery_markers.gd")

func _initialize() -> void:
	call_deferred("_verify")

func check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("v20 OK: "+title)
	else:
		failed += 1
		push_error("v20 FAIL: "+title)

func _verify() -> void:
	var state: Variant = root.get_node_or_null("GameState")
	check(state != null,"autoload ready")
	if state == null:
		quit(2)
		return
	state.data = state.new_game()
	check(DISCOVERY.sites().size() == 12,"twelve translated city sites")
	check(state._valid_state(state.data),"v4 new campaign validates")
	var entries: Array = DISCOVERY.sites()
	var first: Dictionary = entries[0]
	var at: Vector3 = DISCOVERY.position(first)
	var wallet_before: int = int(state.data["wallet"])
	check(state.explore_site(str(first["id"]),at,true,false)["status"] == "on_foot","driver cannot collect")
	check(state.explore_site(str(first["id"]),at,false,true)["status"] == "on_foot","indoor cannot collect")
	check(state.explore_site(str(first["id"]),Vector3.ZERO,false,false)["status"] == "distance","far away cannot collect")
	check(state.explore_site(str(first["id"]),at,false,false)["status"] == "discovered","on-foot discovery succeeds")
	check(int(state.data["wallet"]) == wallet_before + DISCOVERY.WALLET_REWARD,"wallet credited exactly once")
	check(state.explore_site(str(first["id"]),at,false,false)["status"] == "already","repeated claim blocked")
	check(state.data["discovered_sites"].size() == 1,"unique record stored")
	check(state._valid_state(state.data),"post-discovery save validates")
	var json_payload: Variant = JSON.parse_string(JSON.stringify(state._save_state_payload()))
	check(json_payload is Dictionary and state._valid_state(json_payload["state"]),"round-trip save validation")
	var old_state: Dictionary = state.new_game()
	old_state.erase("discovered_sites")
	old_state.erase("discovery_history")
	check(state._valid_state(old_state),"older version-four snapshot still accepted")
	var upgraded: Dictionary = state._upgrade_state(old_state)
	check(upgraded.has("discovered_sites") and upgraded.has("discovery_history"),"legacy fields added")
	var scene: Variant = MARKERS.new()
	root.add_child(scene)
	await process_frame
	check(scene.monuments.size() == 12,"twelve 3D monuments instantiate")
	scene.sync_state(state.data)
	var monument: Node3D = scene.monuments[str(first["id"])]
	check(monument.get_node_or_null("MemoryCore") is MeshInstance3D,"discovered monument updates")
	scene.queue_free()
	print("OSGARD v0.20 NATIVE: %d passed / %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
