extends SceneTree
## R49 original 40 real mission actions grouped into 3 replay-safe campaign arcs.
## This tests single authoritative GameState and real HUD; no new save schema.
var passed := 0
var failed := 0
var chapters_signaled: Array[String] = []
var rewards_signaled: Array[int] = []
func verify(ok: bool,label: String) -> void:
	if ok:
		passed+=1
	else:
		failed+=1
		push_error("R49 CAMPAIGN FAILED: "+label)
func _initialize() -> void:
	call_deferred("_run")
func _on_chapter(id: String, reward: int) -> void:
	chapters_signaled.append(id)
	rewards_signaled.append(reward)
func _run() -> void:
	var game_state: Node = root.get_node_or_null("GameState")
	var mission: Node = root.get_node_or_null("MissionManager")
	verify(game_state!=null and mission!=null,"real authoritative GameState and 40-mission manager autoload initialized")
	if game_state==null or mission==null:
		quit(1)
		return
	mission.connect("chapter_completed",Callable(self,"_on_chapter"))
	var original: Dictionary = game_state.get("data").duplicate(true)
	var test_state: Dictionary = game_state.call("new_game")
	game_state.set("data",test_state)
	var intro: Dictionary = mission.call("chapter_progress",0)
	verify(str(intro["id"])=="arrival" and int(intro["number"])==1 and int(intro["count"])==3,"campaign starts at first of exactly three real chapters")
	verify(int(intro["percent"])==0 and int(intro["total"])==6,"chapter one uses six real existing career missions")
	verify(str(mission.call("chapter_title","ru",false)).contains("ГЛАВА 1/3"),"Russian chapter heading visible")
	verify(str(mission.call("chapter_title","en",true)).contains("FIRST STEPS"),"English mobile chapter heading localized")
	verify(str(mission.call("chapter_title","zh",false)).contains("第一步"),"Chinese chapter heading localized")
	var second: Dictionary = mission.call("chapter_progress",6)
	verify(str(second["id"])=="builder" and int(second["total"])==14,"second campaign chapter uses civic and economic mission actions")
	var third: Dictionary = mission.call("chapter_progress",20)
	verify(str(third["id"])=="world" and int(third["total"])==20,"third chapter includes transit, infrastructure, services and residents")
	for scenario in [
		{"stage":5,"action":"contract_deliver","id":"arrival","mission_reward":240,"chapter_reward":300},
		{"stage":19,"action":"contract_deliver","id":"builder","mission_reward":800,"chapter_reward":650},
		{"stage":39,"action":"neighborhood_deliver","id":"world","mission_reward":640,"chapter_reward":1200}
	]:
		test_state=game_state.call("new_game")
		test_state["mission"]=int(scenario["stage"])
		game_state.set("data",test_state)
		var before_wallet: int = int(test_state["wallet"])
		var completed: bool = bool(mission.call("register_action",str(scenario["action"])))
		verify(completed,"real mission action completes proper chapter "+str(scenario["id"]))
		verify(int(test_state["mission"])==int(scenario["stage"])+1,"authoritative mission index advanced exactly once")
		verify(int(test_state["wallet"])-before_wallet==int(scenario["mission_reward"])+int(scenario["chapter_reward"]),"chapter earns exact ordinary and one-time milestone rewards")
		var again: bool = bool(mission.call("register_action",str(scenario["action"])))
		verify(not again and int(test_state["wallet"])-before_wallet==int(scenario["mission_reward"])+int(scenario["chapter_reward"]),"repeating action after stage transition cannot farm chapter reward")
	verify(chapters_signaled==["arrival","builder","world"],"three independently completed chapter-finale signals fired in correct order")
	verify(rewards_signaled==[300,650,1200],"authoritative payouts match original chapter contracts")
	verify(bool(mission.call("chapter_progress",40)["campaign_finished"]),"forty missions complete campaign without new save property")
	verify(str(mission.call("chapter_title","ru",false))=="КАМПАНИЯ ПРОЙДЕНА","endgame shows completion rather than fake endless campaign")
	var authored: String = FileAccess.get_file_as_string("res://scripts/mission_manager.gd")
	verify(authored.contains("GameState.data[\"mission\"] = stage + 1") and authored.contains("GameState.add_reward("),"actual missions remain authoritative and reward through existing state")
	var actual: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	verify(actual.contains("MissionManager.chapter_completed.connect(_on_chapter_done)") and actual.contains("hud.announce("),"real playable game displays mission chapter completion")
	var interface_src: String = FileAccess.get_file_as_string("res://scripts/hud.gd")
	verify(interface_src.contains("MissionManager.chapter_title(GameState.locale,compact_hud)"),"real 3D HUD displays active localized chapter progress")
	var hud_script: Variant = load("res://scripts/hud.gd")
	verify(hud_script is Script and hud_script.can_instantiate(),"original campaign HUD compiles")
	if hud_script is Script and hud_script.can_instantiate():
		var hud: CanvasLayer = hud_script.new()
		root.add_child(hud)
		var chapter_title_node: Label = hud.get("mission_chapter_label")
		verify(chapter_title_node!=null and chapter_title_node.text.contains("КАМПАНИЯ"),"actual HUD shows completed campaign in live objective panel")
		test_state["mission"]=0
		hud.call("_refresh")
		# Compact mobile UI deliberately shortens "ГЛАВА" to "1/3".
		# Assert the exact player-visible title for the current layout, rather
		# than wrongly rejecting a real working compact chapter label.
		var expected_title: String = str(mission.call("chapter_title",game_state.get("locale"),hud.get("compact_hud")))
		verify(chapter_title_node.text == expected_title and chapter_title_node.text.contains("ПЕРВЫЕ ШАГИ"),
			"HUD switches to the correct first chapter on both compact and desktop layouts")
		verify(int(mission.call("chapter_progress")["percent"])==0,
			"restarted playable campaign chapter resets to zero progress")
		hud.queue_free()
	game_state.set("data",original)
	await process_frame
	print("EMPIRE OMEGA R49 NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
