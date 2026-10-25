extends SceneTree
## R68: a mission about CHANGING policy cannot be completed by a no-op click.
## Runs original GameState, MissionManager, and live HUD callback in Godot 4.4.1.
var passed := 0
var failed := 0
var actual_policy_events := 0

func verify(ok: bool, why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R68 AUTHENTIC POLICY QUEST FAILED: " + why)

func _initialize() -> void:
	call_deferred("_run")

func _on_state_change(reason: String) -> void:
	if reason == "policy":
		actual_policy_events += 1

func _run() -> void:
	var game: Node = root.get_node_or_null("GameState")
	var missions: Node = root.get_node_or_null("MissionManager")
	verify(game != null and missions != null, "original GameState and MissionManager autoloads present")
	if game == null or missions == null:
		quit(1)
		return
	var old_state: Dictionary = game.get("data").duplicate(true)
	var old_locale: String = str(game.get("locale"))
	var initial: Dictionary = game.call("new_game")
	initial["mission"] = 11
	game.set("data", initial)
	game.set("locale", "ru")
	var title: Dictionary = missions.call("get_mission")
	verify(str(title.get("id","")) == "set_course", "actual twelfth authored campaign stage expects set_course")
	verify(str(initial.get("course","")) == "balance", "new game starts in balance policy")
	var before_wallet: int = int(initial["wallet"])
	var reward: int = int(title.get("reward",0))
	verify(reward == 140, "source mission defines the authoritative 140 credit reward")

	game.connect("state_changed",Callable(self,"_on_state_change"))
	# The actual interface method, not a synthetic direct register_action:
	var hud_script: Variant = load("res://scripts/hud.gd")
	verify(hud_script is Script and hud_script.can_instantiate(),
		"real HUD compiles and exposes original governor controls")
	if not (hud_script is Script and hud_script.can_instantiate()):
		game.disconnect("state_changed",Callable(self,"_on_state_change"))
		game.set("data",old_state)
		game.set("locale",old_locale)
		quit(1)
		return
	var hud: CanvasLayer = hud_script.new()
	root.add_child(hud)
	hud.call("_choose_policy","balance")
	verify(int(initial["mission"]) == 11,"reselecting unchanged policy never advances campaign")
	verify(int(initial["wallet"]) == before_wallet,"no-op policy receives no mission reward")
	verify(str(initial["course"]) == "balance", "no-op does not change city strategy")
	verify(actual_policy_events == 0, "no-op does not emit fake successful city-policy event")
	hud.call("_choose_policy","welfare")
	verify(str(initial["course"]) == "welfare", "player's real HUD action changes actual GameState policy")
	verify(int(initial["mission"]) == 12, "real HUD policy change completes exactly one mission")
	verify(int(initial["wallet"]) == before_wallet + reward, "legitimate course transition awards exact quest credits")
	verify(actual_policy_events == 1, "exactly one actual policy state_change event emitted")
	hud.call("_choose_policy","welfare")
	verify(actual_policy_events == 1, "reselecting new policy produces no additional policy event")
	verify(int(initial["mission"]) == 12, "second no-op cannot advance to next mission")
	verify(int(initial["wallet"]) == before_wallet + reward, "second no-op cannot duplicate credits")
	verify(not bool(game.call("set_course","invented_policy")), "unknown policies remain rejected")
	verify(bool(game.call("_valid_state",initial)), "actual save state remains valid after changed policy")
	var source: String = FileAccess.get_file_as_string("res://scripts/hud.gd")
	verify(source.contains("This policy is already active"), "real HUD gives English no-op feedback")
	verify(source.contains("Этот курс уже выбран"), "real HUD gives Russian no-op feedback")
	hud.queue_free()
	game.disconnect("state_changed",Callable(self,"_on_state_change"))
	game.set("data",old_state)
	game.set("locale",old_locale)
	await process_frame
	print("EMPIRE OMEGA R68 POLICY MISSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
