extends SceneTree
## V9: actual secure offline career records, multiple emergency classes and
## achievements, migration-safe independent profile storage and corruption QA.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool,description: String) -> void:
    checks += 1
    if not ok:
        failures.append(description)

func _engine(scenario: String,success: bool,grade: String="S") -> IPCrisisEngine:
    var engine := IPCrisisEngine.new()
    engine.reset(scenario)
    engine.elapsed = 108.0 if grade=="S" else 185.0
    engine.heat = 53.0 if grade=="S" else 79.0
    engine.oxygen = 84.0
    engine.crew_health = 95.0
    engine.faults = 0 if grade=="S" else 1
    engine.won = success
    engine.lost = not success
    return engine

func _run() -> void:
    var path: String = "user://iron_pulse_v9_profile_rules_ci.json"
    var store := IPCheckpointStore.new()
    store.clear(path)
    var career := IPCareerProfile.new()
    _check(career.operations==0 and career.victories==0,"Brand-new offline career starts genuinely empty")
    _check(career.recent.is_empty() and career.achievements.is_empty(),
        "No fake achievements or leaderboard/players shown")
    _check(career.recommended_scenario()=="blackout","First recommended mission is the original GRID emergency")
    var invalid := IPCrisisEngine.new()
    invalid.reset()
    _check(career.record_finished(invalid,[]).is_empty() and career.operations==0,
        "Unfinished mission cannot award progress or fake a best time")

    var grid := _engine("blackout",true)
    grid.priority_id = "crew"
    grid.repair_method = "standard"
    var first: Dictionary = career.record_finished(grid,["reactor","service","evacuation"])
    _check(not first.is_empty() and career.operations==1 and career.victories==1,
        "First real successful run increments exact offline career counters")
    _check(career.mission_records["blackout"]["best_grade"]=="S",
        "Real S-grade is saved per original emergency")
    _check(career.mission_records["blackout"]["best_seconds"]==108.0,
        "Fastest successful operation time is preserved")
    _check(career.achievements.has("FIRST_EXTRACTION") and career.achievements.has("ZERO_FAULT"),
        "First-win and zero-fault achievements require real successful run")
    _check(career.achievements.has("CREW_GUARDIAN") and career.achievements.has("SOLO_OPERATOR"),
        "Crew-first decision and no relay rewards are correctly earned")
    _check(career.achievement_title("FIRST_EXTRACTION","ru")=="ПЕРВАЯ ЭВАКУАЦИЯ" and
        career.achievement_title("FIRST_EXTRACTION","en")=="FIRST EXTRACTION",
        "Earning one achievement creates real human-readable RU and EN names")
    _check(career.recommended_scenario()=="thermal",
        "Recommendation immediately switches to next unfinished emergency")

    var thermal := _engine("thermal",true,"A")
    thermal.repair_method = "deep_stabilize"
    thermal.priority_id = "core"
    thermal.relays_activated = ["medbay","quench"]
    thermal.thermal_shield = true
    career.record_finished(thermal,["reactor","service"])
    _check(career.achievements.has("RELAY_ARCHITECT"),
        "Choosing both rescue relays creates a separate strategic achievement")
    _check(career.mission_records["thermal"]["best_grade"]=="A",
        "Thermal mission mastery remains independent of GRID best result")
    _check(not career.achievements.has("THREE_FRONTS"),
        "Third-scenario mastery is NOT awarded prematurely")

    var loss := _engine("breach",false)
    loss.oxygen = 4.0
    career.record_finished(loss,["reactor"])
    _check(career.operations==3 and career.victories==2,
        "Lost runs are counted without pretending the player extracted crew")
    _check(career.mission_records["breach"]["best_grade"]=="-",
        "No winning grade or best time is fabricated for losses")
    var breach := _engine("breach",true)
    breach.repair_method = "full_seal"
    career.record_finished(breach,["reactor","service","evacuation"])
    _check(career.achievements.has("THREE_FRONTS") and career.victories==3,
        "Three fronts unlocks only after actual wins in GRID, HEAT and AIR")
    _check(career.recommended_scenario()=="breach",
        "Operator is guided to the least-completed mission, without paid gating")

    _check(career.save(path), "Dedicated V9 profile saves into true atomic offline user storage")
    var reloaded := IPCareerProfile.new()
    _check(reloaded.load(path),"Versioned V9 profile loads through actual file+SHA256 wrapper")
    _check(reloaded.snapshot()==career.snapshot(),
        "Full mission mastery, achievement set, counters and history survive disk")
    _check(reloaded.recent.size()==4 and reloaded.recent[0]["scenario"]=="breach",
        "Latest operation appears first in saved career history")
    var stable: Dictionary = reloaded.snapshot()
    var corrupted: Dictionary = stable.duplicate(true)
    corrupted["operations"] = 42
    _check(not reloaded.restore(corrupted) and reloaded.snapshot()==stable,
        "Internally inconsistent lifetime totals rejected transactionally")
    corrupted = stable.duplicate(true)
    corrupted["achievements"] = ["FIRST_EXTRACTION","FIRST_EXTRACTION"]
    _check(not reloaded.restore(corrupted) and reloaded.snapshot()==stable,
        "Fabricated duplicate achievements rejected without partial mutation")
    corrupted = stable.duplicate(true)
    corrupted["recent"][0]["relays"] = ["medbay","quench","uplink"]
    _check(not reloaded.restore(corrupted) and reloaded.snapshot()==stable,
        "Three-relay save cheating is refused and active career is preserved")
    corrupted = stable.duplicate(true)
    corrupted["recent"][0]["elapsed"] = -1.0
    _check(not reloaded.restore(corrupted) and reloaded.snapshot()==stable,
        "Negative/corrupt run time cannot appear in leaderboards")
    corrupted = stable.duplicate(true)
    corrupted["mission_records"]["thermal"]["best_grade"] = "AAA"
    _check(not reloaded.restore(corrupted) and reloaded.snapshot()==stable,
        "Impossible fabricated ratings are rejected")
    corrupted = stable.duplicate(true)
    corrupted["schema"] = "IRON_PULSE_OPERATIONS_PROFILE_V999"
    _check(not reloaded.restore(corrupted) and reloaded.snapshot()==stable,
        "Unknown future/foreign profile versions are refused")

    var forged_wrapper: Dictionary = store.load_checkpoint(path)
    forged_wrapper["mission_records"]["blackout"]["wins"] = 999
    _check(store.save(forged_wrapper,path),"QA writes a syntactically valid hash-wrapped but semantically corrupt file")
    _check(not reloaded.load(path) and reloaded.snapshot()==stable,
        "Even valid SHA256 wrappers cannot bypass offline semantic validation")
    _check(career.save(path),"Original valid profile replaces corrupted test fixture")

    for index in range(30):
        var repeated := _engine("thermal",index%3==0,"A")
        repeated.elapsed = 180.0+float(index)
        career.record_finished(repeated,["reactor"])
    _check(career.operations==34 and career.recent.size()==IPCareerProfile.MAX_HISTORY,
        "Run history capped at 24 entries even after dozens of operations")
    _check(career.recent[0]["id"]==34 and career.recent[23]["id"]==11,
        "Bounded history retains exactly the newest real serial-numbered runs")
    _check(career.achievements.has("VETERAN"),
        "Veteran badge requires five genuine successful operations")
    _check(career.save(path) and reloaded.load(path),
        "Long career remains serializable and recoverable through disk")
    _check(reloaded.snapshot()==career.snapshot(),
        "Long-term cumulative counters survive history trimming")
    _check(store.clear(path),"All temporary profile test files cleaned after QA")
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE V9 OPERATIONS PROFILE PASS: %d real career/save assertions" % checks)
        quit(0)
    else:
        for failure in failures:
            push_error("V9 PROFILE FAIL: "+failure)
        quit(1)
