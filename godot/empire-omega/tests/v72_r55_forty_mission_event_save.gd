extends SceneTree
## R55: exercise all 40 ORIGINAL mission event transitions, economy and real
## primary+backup save recovery. This does NOT claim a human 40-mission
## gameplay playthrough, physical phone FPS or AAA production.
var passed := 0
var failed := 0
var mission_events: Array[int] = []
var chapter_events: Array[String] = []
var chapter_payouts: Array[int] = []

func verify(ok: bool,reason: String) -> void:
	if ok:
		passed+=1
	else:
		failed+=1
		push_error("EMPIRE OMEGA R55 CAMPAIGN FAILED: "+reason)

func _initialize() -> void:
	call_deferred("_run")

func _on_mission(index: int,_reward: int) -> void:
	mission_events.append(index)

func _on_chapter(id: String,reward: int) -> void:
	chapter_events.append(id)
	chapter_payouts.append(reward)

func _run() -> void:
	var game: Node = root.get_node_or_null("GameState")
	var missions: Node = root.get_node_or_null("MissionManager")
	verify(game!=null and missions!=null,"the actual game state and mission manager autoloads exist")
	if game==null or missions==null:
		quit(1)
		return
	var original_data: Dictionary = game.get("data").duplicate(true)
	var original_locale: String = str(game.get("locale"))
	var original_save: String = str(game.get("save_path"))
	var original_pending: String = str(game.get("pending_save_path"))
	var original_backup: String = str(game.get("backup_save_path"))
	var session: String = "r55_campaign_"+str(OS.get_process_id())
	var save_path: String = "user://"+session+".json"
	var pending_path: String = "user://"+session+".pending"
	var backup_path: String = "user://"+session+".backup.json"
	game.set("save_path",save_path)
	game.set("pending_save_path",pending_path)
	game.set("backup_save_path",backup_path)
	game.set("locale","ru")
	var state: Dictionary = game.call("new_game")
	game.set("data",state)
	missions.connect("mission_completed",Callable(self,"_on_mission"))
	missions.connect("chapter_completed",Callable(self,"_on_chapter"))
	var initial_wallet: int = int(state.get("wallet",0))
	var expected_reward: int = 0
	var expected_science: int = int(state.get("science",0))
	var transition_log: Array[Dictionary] = []
	for stage in range(40):
		var entry: Dictionary = missions.call("get_mission")
		var action: String = str(entry.get("id",""))
		var reward: int = int(entry.get("reward",-1))
		verify(action!="" and action!="complete" and reward>0 and reward<100000,
			"mission %d has a real action contract and bounded reward" % stage)
		verify(not bool(missions.call("register_action","r55_invalid_action")),
			"mission %d refuses an invalid event without changing progress" % stage)
		verify(int(state["mission"])==stage,
			"mission %d remains authoritative before the correct event" % stage)
		var chapter: Dictionary = missions.call("chapter_progress")
		verify(int(chapter.get("percent",-1))>=0 and int(chapter.get("percent",-1))<=100,
			"mission %d has valid chapter progress" % stage)
		for lang in ["ru","en","zh"]:
			verify(str(entry.get(lang,"")).length()>5 and str(missions.call("chapter_title",lang,false)).length()>4,
				"mission %d exists in %s localization" % [stage,lang])
		var old_money: int = int(state["wallet"])
		verify(bool(missions.call("register_action",action)),
			"original gameplay mission %d accepts its documented event" % stage)
		var bonus: int = 300 if stage==5 else (650 if stage==19 else (1200 if stage==39 else 0))
		verify(int(state["mission"])==stage+1,"exactly one stage transition at mission %d" % stage)
		verify(int(state["wallet"])-old_money==reward+bonus,
			"real wallet for mission %d gets only the documented base and chapter bonus" % stage)
		verify(int(mission_events.size())==stage+1 and int(mission_events[-1])==stage,
			"original mission_completed signal emitted exactly once for %d" % stage)
		if action=="contract_deliver":
			expected_science+=30
		verify(int(state["science"])==expected_science,
			"science changes only on completed contract deliveries at %d" % stage)
		expected_reward+=reward+bonus
		transition_log.append({"index":stage,"action":action,"reward":reward,"chapter_bonus":bonus})
	verify(int(state["mission"])==40,"all 40 genuine event transitions completed without direct stage mutation")
	verify(mission_events.size()==40,"exactly 40 completion signals")
	verify(chapter_events==["arrival","builder","world"],"all three chapter final signals appear in order")
	verify(chapter_payouts==[300,650,1200],"three milestone payouts match the official campaign")
	verify(int(state["wallet"])==initial_wallet+expected_reward,
		"entire campaign ledger reconciles with the initial wallet")
	verify(bool(missions.call("chapter_progress")["campaign_finished"]),
		"the 40th completed mission opens permanent free-play")
	for language in ["ru","en","zh"]:
		verify(str(missions.call("chapter_title",language,false)).length()>5,
			"completed campaign remains localized in "+language)
	verify(not bool(missions.call("register_action","neighborhood_deliver")),
		"completed campaign rejects further payouts without changing mission index")
	verify(int(state["wallet"])==initial_wallet+expected_reward,
		"finished campaign cannot repeat its final bonus")
	verify(bool(game.call("_valid_state",state)),"real 40-stage game data fits authoritative save validation")
	verify(bool(game.call("save_game")),"real save_game writes atomic 40-stage primary snapshot")
	var primary: String = ProjectSettings.globalize_path(save_path)
	verify(FileAccess.file_exists(save_path),"actual primary save file exists")
	game.set("data",game.call("new_game"))
	verify(bool(game.call("load_game")),"real load_game restores complete campaign from primary")
	var loaded: Dictionary = game.get("data")
	verify(int(loaded["mission"])==40 and int(loaded["wallet"])==initial_wallet+expected_reward,
		"reload preserves completed campaign and all earned credits")
	verify(str(game.get("last_load_source"))=="primary","primary save is reported as the source")
	verify(bool(game.call("save_game")),"second atomic save generates the verified backup")
	verify(FileAccess.file_exists(backup_path),"a valid primary save is backed up before replacement")
	var corrupt: FileAccess = FileAccess.open(save_path,FileAccess.WRITE)
	if corrupt!=null:
		corrupt.store_string("{intentionally malformed JSON")
		corrupt.close()
	verify(bool(game.call("load_game")),"corrupt primary falls back to intact authoritative backup")
	loaded=game.get("data")
	verify(str(game.get("last_load_source"))=="backup","backup recovery is recorded")
	verify(int(loaded["mission"])==40 and int(loaded["wallet"])==initial_wallet+expected_reward,
		"backup recovery does not reset or duplicate credits")
	var evidence: Dictionary = {
		"schema":"omega-r55-mission-event-save-v1",
		"engine":"Godot 4.4.1",
		"mission_transitions":transition_log,
		"total_missions":40,
		"chapter_endings":chapter_events.duplicate(),
		"earned_in_game_credits":expected_reward,
		"primary_and_backup_save_recovery":true,
		"checks_passed":passed,
		"checks_failed":failed,
		"human_mission_playthrough_attested":false,
		"physical_device_attested":false,
		"full_aaa_release_authorized":false
	}
	var evidence_path: String = ProjectSettings.globalize_path("res://tests/r55-campaign-event-save-evidence.json")
	var evidence_file: FileAccess = FileAccess.open(evidence_path,FileAccess.WRITE)
	verify(evidence_file!=null,"write audit ledger from actual Godot mission events")
	if evidence_file!=null:
		evidence["checks_passed"]=passed
		evidence["checks_failed"]=failed
		evidence_file.store_string(JSON.stringify(evidence,"  "))
		evidence_file.close()
	missions.disconnect("mission_completed",Callable(self,"_on_mission"))
	missions.disconnect("chapter_completed",Callable(self,"_on_chapter"))
	game.set("data",original_data)
	game.set("locale",original_locale)
	game.set("save_path",original_save)
	game.set("pending_save_path",original_pending)
	game.set("backup_save_path",original_backup)
	for file in [save_path,pending_path,backup_path]:
		var absolute: String = ProjectSettings.globalize_path(file)
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(absolute)
	await process_frame
	print("EMPIRE OMEGA R55 EVENT AND SAVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
