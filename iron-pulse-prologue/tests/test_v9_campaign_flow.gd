extends SceneTree
## V9+V11 native source-bound three-emergency campaign and mechanics QA.
var checks: int = 0
var errors: Array[String] = []
func _initialize() -> void:
    call_deferred("_run")
func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        errors.append(message)

func _win(scenario: String,with_crew: bool,relays: Array[String] = []) -> IPCrisisEngine:
    var e := IPCrisisEngine.new()
    e.reset(scenario)
    e.scan_core()
    e.choose_priority("crew" if with_crew else "core")
    for relay in relays:
        e.activate_relay(relay)
    e.repair_coolant()
    e.cycle_bus(1)
    e.tick(25.0)
    e.cycle_bus(1)
    e.cycle_bus(1)
    e.activate_override()
    e.escape()
    return e

func _run() -> void:
    var flow := IPCampaignFlow.new()
    _check(not flow.active and flow.records.is_empty(), "Legacy standalone run remains the default")
    _check(not flow.advance() and not flow.completed(), "Cannot skip into campaign without opting in")
    flow.begin()
    _check(flow.active and flow.index == 0 and flow.current_scenario() == "blackout",
        "New campaign starts in real GRID operation")
    var not_won := IPCrisisEngine.new()
    not_won.reset("blackout")
    _check(not flow.record_victory(not_won), "Non-winning play never advances campaign")
    var wrong := _win("thermal",true)
    _check(wrong.won and not flow.record_victory(wrong), "Cannot credit the wrong chapter")
    var first := _win("blackout",true,["medbay","quench"])
    _check(first.won, "Actual scenario GRID has a deterministic engine win")
    _check(flow.record_victory(first) and flow.records.size() == 1,
        "Real completed first operation creates exactly one result")
    _check(not flow.record_victory(first), "Duplicating win cannot farm score or skip chapter")
    _check(flow.awaiting_advance() and not flow.completed(), "Second mission locked until genuine first success")
    var partial: Dictionary = flow.checkpoint()
    var invalid: Dictionary = partial.duplicate(true)
    invalid["records"][0]["scenario"] = "breach"
    _check(not flow.restore(invalid) and flow.records.size() == 1,
        "Forged chapter history is rejected atomically")
    _check(flow.advance() and flow.current_scenario() == "thermal", "Second real scenario unlocks")
    _check(not flow.advance(), "Cannot skip HEAT without actually winning")
    var effects: Dictionary = flow.next_modifier()
    _check(effects["crew"] > 0.0 and effects["heat"] <= 5.0,
        "Crew and quench choices transfer real positive and negative consequences")
    var second := IPCrisisEngine.new()
    second.reset("thermal")
    var old_heat: float = second.heat
    var old_crew: float = second.crew_health
    var old_oxygen: float = second.oxygen
    _check(flow.apply_to_next(second), "Consequences apply to actual HEAT scenario")
    _check(second.heat <= old_heat and second.oxygen < old_oxygen and second.crew_health >= old_crew,
        "Crew and suppressor choices preserve crew and cool core but cost oxygen in next scenario")
    var after_once: Dictionary = second.checkpoint()
    _check(not flow.apply_to_next(second) and second.checkpoint() == after_once,
        "Applying campaign modifier twice cannot multiply advantages")
    second.scan_core()
    second.choose_priority("core")
    second.emergency_repair()
    second.cycle_bus(1)
    second.tick(25.0)
    second.cycle_bus(1)
    second.cycle_bus(1)
    _check(second.activate_override() and second.escape() and second.won,
        "Second chapter remains solvable after real transferred consequences")
    _check(flow.record_victory(second) and flow.records.size() == 2,
        "Second victory opens next page of actual campaign dossier")
    _check(flow.advance() and flow.current_scenario() == "breach", "Final AIR scenario unlocks in order")
    var air := IPCrisisEngine.new()
    air.reset("breach")
    _check(flow.apply_to_next(air), "Second chapter choices mechanically change AIR startup")
    air.scan_core()
    air.choose_priority("crew")
    air.repair_coolant()
    air.cycle_bus(1)
    air.tick(25.0)
    air.cycle_bus(1)
    air.cycle_bus(1)
    _check(air.activate_override() and air.escape(), "Third AIR chapter has a true finish")
    _check(flow.record_victory(air), "Three real engine victories produce final dossier")
    _check(flow.completed() and not flow.awaiting_advance() and not flow.advance(),
        "Campaign finishes after three chapters and never invents a fourth")
    _check(flow.records.size() == 3 and flow.summary("ru").contains("ФИНАЛ"),
        "Final localized RU campaign outcome records all 3 real operations")
    _check(flow.summary("en").contains("ENDING") and flow.summary("en").contains("GRID"),
        "English dossier describes three chapters and outcome")
    var restored := IPCampaignFlow.new()
    _check(restored.restore(flow.checkpoint()) and restored.completed(),
        "Full three-chapter result can be restored from a real checkpoint dictionary")
    _check(restored.summary("ru") == flow.summary("ru"), "Reloaded dossier is byte-for-byte equivalent")
    var cheated: Dictionary = flow.checkpoint()
    cheated["records"][1]["grade"] = "GOD"
    _check(not restored.restore(cheated) and restored.completed(),
        "Forged impossible score cannot corrupt already valid campaign")
    var old_standalone := IPCampaignFlow.new()
    _check(old_standalone.restore(old_standalone.checkpoint()) and not old_standalone.active,
        "Standalone default is backward-compatible with unchanged gameplay")
    var store := IPCheckpointStore.new()
    var path: String = "user://iron_pulse_v9_campaign_ci.json"
    store.clear(path)
    _check(store.save(flow.checkpoint(),path), "Actual offline atomic campaign record saves correctly")
    var from_disk := IPCampaignFlow.new()
    _check(from_disk.restore(store.load_checkpoint(path)) and from_disk.completed(),
        "Three real mission records survive encrypted-free SHA256-checked local disk roundtrip")
    _check(store.clear(path), "Native test leaves no shared user checkpoint behind")
    _finish()
func _finish() -> void:
    if errors.is_empty():
        print("IRON PULSE V9 CAMPAIGN PASS: %d native campaign checks" % checks)
        quit(0)
    else:
        for issue in errors:
            push_error("V9 CAMPAIGN FAIL: "+issue)
        quit(1)
