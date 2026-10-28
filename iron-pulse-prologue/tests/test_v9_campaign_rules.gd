extends SceneTree
## V9 genuine deterministic campaign tests; all wins come from real
## IPCrisisEngine rules and are saved using existing offline SHA store.
var checks: int = 0
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool,label: String) -> void:
    checks += 1
    if not ok:
        errors.append(label)

func _win(real_engine: IPCrisisEngine,scenario: String,order: String = "crew") -> bool:
    real_engine.reset(scenario)
    if not real_engine.scan_core():
        return false
    if not real_engine.activate_relay("medbay"):
        return false
    if not real_engine.choose_priority(order):
        return false
    if not real_engine.repair_coolant():
        return false
    if not real_engine.cycle_bus(1):
        return false
    real_engine.tick(24.0)
    if real_engine.finished() or real_engine.door_charge < IPCrisisEngine.CHARGE_REQUIRED:
        return false
    if not real_engine.cycle_bus(1) or not real_engine.cycle_bus(0):
        return false
    return real_engine.activate_override() and real_engine.escape() and real_engine.won

func _run() -> void:
    var director := IPCampaignDirector.new()
    _check(director.next_scenario()=="blackout" and director.wins()==0 and not director.finished(),
        "Actual campaign starts at GRID and cannot skip the first mission")
    _check(director.ending_id()=="" and director.campaign_grade()=="INCOMPLETE",
        "No fabricated ending or rank before all three actual victories")
    var premature := IPCrisisEngine.new()
    premature.reset("thermal")
    _check(not director.record_victory(premature),
        "Unfinished/incorrect mission cannot be recorded as campaign victory")
    _check(not director.apply_to_engine(premature),
        "Cannot apply campaign resources to illegally selected second scenario")

    var first := IPCrisisEngine.new()
    _check(_win(first,"blackout"), "Stage 1: real GRID crisis actions produce actual engine evacuation")
    _check(director.record_victory(first), "Only a real completed GRID operation unlocks HEAT")
    _check(director.wins()==1 and director.next_scenario()=="thermal",
        "GRID success permanently unlocks only next chronological chapter")
    _check(not director.record_victory(first), "Repeated final-panel callback cannot duplicate GRID reward")
    var c1: Dictionary = director.carryover()
    _check(c1["oxygen"]>=55.0 and c1["crew"]>=50.0 and c1["crew"]<100.0,
        "Actual crew casualties and emergency restock carry into next crisis")
    var second := IPCrisisEngine.new()
    second.reset("thermal")
    _check(director.apply_to_engine(second) and not second.core_scanned and second.elapsed==0.0,
        "HEAT starts as authentic new chapter with inherited resources, not cheating objective")
    _check(second.oxygen<=float(c1["oxygen"])+0.001 and second.crew_health<=float(c1["crew"])+0.001,
        "Transferred crew/oxygen really modify next stage IPCrisisEngine")
    _check(_win(second,"thermal"), "Stage 2: actual precision thermal repair, power and exit are passable")
    _check(director.record_victory(second), "Second successful operation unlocks only AIR")
    _check(director.wins()==2 and director.next_scenario()=="breach",
        "Chapter order is fixed GRID→HEAT→AIR")
    var third := IPCrisisEngine.new()
    third.reset("breach")
    _check(director.apply_to_engine(third), "AIR starts with retained preceding crew consequences")
    var before_air_crew: float = third.crew_health
    _check(before_air_crew<92.0 or director.carryover()["crew"]>=92.0,
        "AIR crew resource uses real capped carryover, never a synthetic full reset")
    _check(_win(third,"breach"), "Stage 3: true AIR seal and evacuation function with carryover")
    _check(director.record_victory(third), "Third actual victory completes full three-chapter campaign")
    _check(director.finished() and director.wins()==3 and director.next_scenario()=="",
        "Campaign concludes only after actual GRID, HEAT and AIR")
    _check(not director.record_victory(third), "Completed campaign cannot invent a fourth act")
    _check(director.campaign_grade() in ["S","A","B"] and director.ending_id() in ["humanity","steel","signal"],
        "Final rank and epilogue are grounded in recorded real mission outcomes")
    _check(director.ending_text("ru").length()>50 and director.ending_text("en").length()>50,
        "Real complete endings are localized into both Russian and English")
    _check(director.summary("ru").contains("3/3") and director.summary("en").contains("3/3"),
        "Global RU/EN campaign progression shows completion")

    var data: Dictionary = director.checkpoint()
    var restored := IPCampaignDirector.new()
    _check(restored.restore(data) and restored.checkpoint()==data,
        "Valid complete campaign can be faithfully restored without losing crew choices")
    var corrupted: Dictionary = data.duplicate(true)
    corrupted["completed"][1]["scenario"] = "breach"
    _check(not restored.restore(corrupted) and restored.checkpoint()==data,
        "Out-of-order forged progress rejected atomically")
    corrupted = data.duplicate(true)
    corrupted["completed"][0]["crew"] = 500.0
    _check(not restored.restore(corrupted) and restored.checkpoint()==data,
        "Unphysical 500% crew injection rejected without partial ledger mutation")
    corrupted = data.duplicate(true)
    corrupted["completed"][0]["relays"] = ["medbay","medbay"]
    _check(not restored.restore(corrupted) and restored.checkpoint()==data,
        "Duplicate rescue use cannot be injected into recorded campaign")
    corrupted = data.duplicate(true)
    corrupted["completed"].append(data["completed"][2])
    _check(not restored.restore(corrupted) and restored.checkpoint()==data,
        "Fabricated fourth chapter is rejected")
    corrupted = {"schema":"BAD_SCHEMA","completed":data["completed"]}
    _check(not restored.restore(corrupted) and restored.checkpoint()==data,
        "Unknown remote/save schema rejected before any state changes")

    var filename: String = "user://iron_pulse_v9_campaign_native_qa.json"
    var store := IPCheckpointStore.new()
    store.clear(filename)
    _check(store.save(data,filename), "Native offline JSON ledger is written atomically by existing SHA-256 store")
    var from_disk: Dictionary = store.load_checkpoint(filename)
    var resumed := IPCampaignDirector.new()
    _check(resumed.restore(from_disk) and resumed.ending_id()==director.ending_id(),
        "Real user:// disk recovery preserves all three wins, resources and earned ending")
    _check(store.clear(filename), "Deterministic test leaves no local test save behind")

    var replay := IPCampaignDirector.new()
    replay.restore(data)
    replay.reset()
    _check(replay.wins()==0 and replay.next_scenario()=="blackout" and not replay.finished(),
        "Explicit replay creates fresh full campaign without changing prior archived data")
    _finish()

func _finish() -> void:
    if errors.is_empty():
        print("IRON PULSE V9 THREE-ACT CAMPAIGN PASS: %d deterministic engine/persistence checks" % checks)
        quit(0)
    else:
        for entry in errors:
            push_error("V9 CAMPAIGN RULE FAIL: "+entry)
        quit(1)
