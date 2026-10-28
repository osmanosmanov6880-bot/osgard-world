extends SceneTree
## V6: genuinely different story/crew decisions, checkpoint roundtrip, corruption refusal.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, msg: String) -> void:
    checks += 1
    if not ok:
        failures.append(msg)

func _run() -> void:
    var story := IPStoryDirector.new()
    for scenario in IPCrisisEngine.SCENARIOS:
        story.reset(scenario)
        _check(story.scenario == scenario and story.act == 0, "Story opens in the selected emergency")
        _check(story.journal.size() == 1 and story.latest("ru")["text"].length() > 20,
            "Each mission has a distinct original localized introduction")
        _check(story.latest("en")["text"].length() > 20, "English original radio dialogue exists")
        _check(story.latest("en")["text"] != story.latest("ru")["text"], "Languages are genuinely translated")
    story.reset("thermal")
    _check(story.on_game_event("core_scanned",""), "Scanning triggers a meaningful story beat")
    _check(story.act == 1 and story.latest_key == "scan", "Story advances to act one on real gameplay")
    _check(not story.on_game_event("core_scanned",""), "Repeated same event does not flood radio journal")
    _check(story.on_game_event("priority_crew","crew"), "Crew priority causes a unique radio consequence")
    _check(story.latest_key == "priority_crew", "Priority is visible in story")
    _check(story.on_game_event("thermal_stabilized","crew") and story.act == 2,
        "Detailed repair moves the narrative to act two")
    _check(story.enter_sector("service") and not story.enter_sector("service"),
        "One-time physical sector discovery adds an authored radio scene")
    _check(story.enter_sector("evacuation") and story.act == 3,
        "Airlock discovery advances the real narrative to act three")
    _check(story.on_game_event("crew_evacuated","crew"), "Evacuation has a consequence-specific ending")
    _check(story.latest_key == "ending_crew", "Crew-first ending is not generic victory text")
    var crew_ending: String = str(story.latest("en")["text"])
    var saved_story: Dictionary = story.checkpoint()
    var recovered := IPStoryDirector.new()
    _check(recovered.restore(saved_story), "Story journal restores from a validated source-bound checkpoint")
    _check(recovered.latest_key == "ending_crew" and recovered.journal.size() == story.journal.size(),
        "Recovered story retains chosen ending, sequence and history")
    var bad_story: Dictionary = saved_story.duplicate(true)
    bad_story["heard"] = ["tampered-script"]
    _check(not recovered.restore(bad_story), "Unknown script keys are rejected before journal mutation")
    _check(recovered.latest_key == "ending_crew", "Rejected story restore leaves existing journal untouched")
    var alternate := IPStoryDirector.new()
    alternate.reset("thermal")
    alternate.on_game_event("crew_evacuated","core")
    _check(str(alternate.latest("en")["text"]) != crew_ending,
        "Core-first victory actually uses a different authored ending")
    _check(story.journal_localized("ru").contains("МАРА"), "Complete original transcript accessible offline")

    var no_scan := IPCrisisEngine.new()
    no_scan.reset("blackout")
    _check(not no_scan.choose_priority("crew"), "Cannot make a command decision before the real reactor scan")
    _check(no_scan.priority_id == "", "Invalid decision never alters the world")
    var crew := IPCrisisEngine.new()
    crew.reset("thermal")
    crew.scan_core()
    _check(crew.choose_priority("crew"), "Player can choose crew after scan")
    _check(crew.priority_id == "crew" and crew.elapsed >= 8.0, "Crew intervention consumes actual game time")
    _check(crew.oxygen >= 90.0 and crew.heat >= 76.0, "Crew-first has measurable oxygen benefit and thermal cost")
    _check(not crew.choose_priority("core"), "Decision is irreversible within an attempt")
    var core := IPCrisisEngine.new()
    core.reset("thermal")
    core.scan_core()
    _check(core.choose_priority("core"), "Alternate core stabilization is available")
    _check(core.priority_id == "core" and core.heat < crew.heat - 12.0,
        "Core-first actually lowers reactor temperature")
    _check(core.oxygen < crew.oxygen and core.crew_health < crew.crew_health,
        "Core-first truly consumes crew resources")
    var snapshot: Dictionary = core.checkpoint()
    var restored := IPCrisisEngine.new()
    _check(restored.restore_checkpoint(snapshot), "Real deterministic game state can be resumed")
    _check(restored.priority_id == "core" and restored.scenario_id == "thermal" and absf(restored.oxygen-core.oxygen)<0.01,
        "Roundtrip restores decisions, scenario and resources")
    _check(restored.event_log == core.event_log and restored.last_event == core.last_event,
        "Real event chronology survives checkpoint")
    var cheated: Dictionary = snapshot.duplicate(true)
    cheated["door_charge"] = 10000.0
    _check(not restored.restore_checkpoint(cheated), "Out-of-range door charge rejected")
    _check(restored.priority_id == "core" and restored.door_charge == core.door_charge,
        "Invalid checkpoint cannot partially mutate active simulation")
    cheated = snapshot.duplicate(true)
    cheated["override_set"] = true
    cheated["core_scanned"] = false
    _check(not restored.restore_checkpoint(cheated), "Impossible story/game objective states rejected")
    restored.reset("breach")
    _check(restored.priority_id == "" and restored.scenario_id == "breach",
        "Restart clears previous moral choice without replacing active emergency")

    var store := IPCheckpointStore.new()
    var slot: String = "user://iron_pulse_v6_engine_ci_test.json"
    store.clear(slot)
    _check(not store.save({"x":1},"user://../wrong.json"), "Checkpoint API prevents user-folder traversal")
    var payload: Dictionary = {"schema":"IRON_PULSE_CAMPAIGN_V6","engine":snapshot,"story":saved_story}
    _check(store.save(payload,slot), "Offline checkpoint writes fully through atomic replacement")
    var actual: Dictionary = store.load_checkpoint(slot)
    _check(actual.get("schema") == "IRON_PULSE_CAMPAIGN_V6", "Saved game can be loaded in a separate read")
    var engine_again := IPCrisisEngine.new()
    _check(engine_again.restore_checkpoint(actual.get("engine",{})), "Saved replay contains a usable engine snapshot")
    _check(engine_again.priority_id == "core", "Saved player choice actually survived disk roundtrip")
    _check(store.save(payload,slot), "Atomic store safely replaces an existing save")
    var file := FileAccess.open(slot,FileAccess.WRITE)
    _check(file != null, "Can create intentionally corrupted QA fixture")
    if file != null:
        file.store_string("{\"format\":\"IRON_PULSE_OFFLINE_SAVE_V6\",\"version\":1,\"payload_json\":\"{}\",\"sha256\":\"incorrect\"}")
        file.close()
    _check(store.load_checkpoint(slot).is_empty(), "Checksum mismatch refuses corrupted local save")
    _check(store.clear(slot), "Temporary QA save removed after test")
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE V6 STORY CHECKPOINT PASS: %d deterministic checks" % checks)
        quit(0)
    else:
        for item in failures:
            push_error("V6 STORY CHECKPOINT FAIL: "+item)
        quit(1)
